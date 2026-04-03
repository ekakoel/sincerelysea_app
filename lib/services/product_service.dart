import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:sincerelysea/models/product.dart';
import 'package:sincerelysea/services/sales_reporting_service.dart';

class CreateProductInput {
  const CreateProductInput({
    required this.category,
    required this.inventoryType,
    required this.preorderDays,
    required this.preorderNote,
    required this.availableForPurchase,
    required this.name,
    required this.price,
    required this.description,
    required this.stock,
    required this.images,
  });

  final String category;
  final String inventoryType;
  final int preorderDays;
  final String preorderNote;
  final bool availableForPurchase;
  final String name;
  final double price;
  final String description;
  final int stock;
  final List<File> images;
}

enum ProductSortOption {
  newest,
  priceLowToHigh,
  priceHighToLow,
}

class ProductService {
  static const String storeId = SalesReportingService.storeId;
  static const String storeName = SalesReportingService.storeName;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _productsRef =>
      _firestore.collection('products');

  Future<bool> isCurrentUserAdmin() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return false;
    }
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();
    final Map<String, dynamic> data = snapshot.data() ?? <String, dynamic>{};
    if (data['role']?.toString().trim().toLowerCase() != 'admin') {
      return false;
    }
    final List<dynamic>? scopes = data['adminScopes'] as List<dynamic>?;
    if (scopes == null || scopes.isEmpty) {
      return true;
    }
    return scopes.map((dynamic scope) => scope.toString()).contains('products');
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getProduct(String productId) {
    return _productsRef.doc(productId).snapshots();
  }

  Future<Product?> getProductOnce(String productId) async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await _productsRef
        .doc(productId)
        .get();
    if (!doc.exists) {
      return null;
    }
    return Product.fromFirestore(doc);
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getProductsPage({
    int limit = 12,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    ProductSortOption sort = ProductSortOption.newest,
  }) async {
    Query<Map<String, dynamic>> query;
    switch (sort) {
      case ProductSortOption.priceLowToHigh:
        query = _productsRef.orderBy('price').limit(limit);
      case ProductSortOption.priceHighToLow:
        query = _productsRef.orderBy('price', descending: true).limit(limit);
      case ProductSortOption.newest:
        query = _productsRef.orderBy('createdAt', descending: true).limit(limit);
    }
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query.get();
  }

  Future<List<Product>> getSellerProducts(String userId) async {
    return getStoreProducts(userId);
  }

  Future<List<Product>> getStoreProducts(String ownerId) async {
    QuerySnapshot<Map<String, dynamic>> snapshot = await _productsRef
        .where('ownerId', isEqualTo: ownerId)
        .get();
    if (snapshot.docs.isEmpty && ownerId == storeId) {
      snapshot = await _productsRef.get();
    }
    final List<Product> products = snapshot.docs
        .map(Product.fromFirestore)
        .where(
          (Product product) =>
              ownerId != storeId ||
              product.ownerId == storeId ||
              product.managedByAdmins,
        )
        .where((Product product) => product.id.isNotEmpty)
        .toList(growable: false);
    products.sort((Product a, Product b) {
      final DateTime aDate = a.createdAt?.toDate() ?? DateTime(1970);
      final DateTime bDate = b.createdAt?.toDate() ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });
    return products;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> myProductsStream() {
    if (_auth.currentUser == null) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    return _productsRef
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> updateProduct({
    required String productId,
    required String inventoryType,
    required int stock,
    required int preorderDays,
    required String preorderNote,
    required bool availableForPurchase,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    if (!await isCurrentUserAdmin()) {
      throw Exception('Only admin can manage products.');
    }
    final String normalizedType =
        inventoryType.trim().toLowerCase() == 'preorder'
        ? 'preorder'
        : 'ready_stock';

    await _productsRef.doc(productId).update(<String, dynamic>{
      'inventoryType': normalizedType,
      'stock': normalizedType == 'preorder' ? 0 : stock,
      'preorderDays': normalizedType == 'preorder' ? preorderDays : 0,
      'preorderNote': normalizedType == 'preorder' ? preorderNote.trim() : '',
      'availableForPurchase': availableForPurchase,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Product> createProduct(CreateProductInput input) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    if (!await isCurrentUserAdmin()) {
      throw Exception('Only admin can create products.');
    }
    if (input.images.isEmpty) {
      throw Exception('Product requires at least one image.');
    }

    final DocumentReference<Map<String, dynamic>> productRef = _productsRef.doc();
    final List<String> downloadUrls = <String>[];
    try {
      for (int i = 0; i < input.images.length; i++) {
        final File imageFile = input.images[i];
        final String extension = _extensionFor(imageFile.path);
        final String contentType = switch (extension) {
          'png' => 'image/png',
          'webp' => 'image/webp',
          _ => 'image/jpeg',
        };
        final Reference ref = _storage.ref().child(
          'users/${user.uid}/products/${productRef.id}/image_$i.$extension',
        );
        await ref.putFile(
          imageFile,
          SettableMetadata(contentType: contentType),
        );
        downloadUrls.add(await ref.getDownloadURL());
      }

      await productRef.set(<String, dynamic>{
        'userId': user.uid,
        'ownerType': 'business',
        'ownerId': storeId,
        'storeName': storeName,
        'managedByAdmins': true,
        'category': input.category.trim(),
        'inventoryType': input.inventoryType.trim().toLowerCase() == 'preorder'
            ? 'preorder'
            : 'ready_stock',
        'preorderDays': input.preorderDays,
        'preorderNote': input.preorderNote.trim(),
        'availableForPurchase': input.availableForPurchase,
        'name': input.name.trim(),
        'price': input.price,
        'description': input.description.trim(),
        'stock': input.stock,
        'images': downloadUrls,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final DocumentSnapshot<Map<String, dynamic>> created = await productRef
          .get();
      return Product.fromFirestore(created);
    } catch (_) {
      for (final String url in downloadUrls) {
        try {
          await _storage.refFromURL(url).delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  String _extensionFor(String path) {
    final String lower = path.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'png';
    }
    if (lower.endsWith('.webp')) {
      return 'webp';
    }
    return 'jpg';
  }
}
