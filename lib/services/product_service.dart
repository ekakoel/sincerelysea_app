import 'dart:io';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:sincerelysea/models/product.dart';
import 'package:sincerelysea/services/admin_service.dart';
import 'package:sincerelysea/services/sales_reporting_service.dart';
import 'package:sincerelysea/services/telemetry_service.dart';

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
  bestSelling,
  priceLowToHigh,
  priceHighToLow,
}

class ProductQueryOptions {
  const ProductQueryOptions({
    this.category,
    this.inventoryType = 'all',
    this.minPrice,
    this.maxPrice,
    this.sort = ProductSortOption.newest,
    this.requirePurchasable = true,
  });

  final String? category;
  final String inventoryType;
  final double? minPrice;
  final double? maxPrice;
  final ProductSortOption sort;
  final bool requirePurchasable;
}

class ProductService {
  static const String storeId = SalesReportingService.storeId;
  static const String storeName = SalesReportingService.storeName;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final AdminService _adminService = AdminService();

  List<String>? _categoryCache;
  DateTime? _categoryCacheAt;

  CollectionReference<Map<String, dynamic>> get _productsRef =>
      _firestore.collection('products');

  Future<bool> isCurrentUserAdmin() async {
    return _adminService.hasCurrentUserScope('products');
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
    ProductQueryOptions options = const ProductQueryOptions(),
  }) async {
    Query<Map<String, dynamic>> query = _productsRef
        .where('ownerId', isEqualTo: storeId);

    if (options.requirePurchasable) {
      query = query.where('availableForPurchase', isEqualTo: true);
    }
    if (options.category != null && options.category!.trim().isNotEmpty) {
      query = query.where('category', isEqualTo: options.category!.trim());
    }
    if (options.inventoryType == 'ready_stock' ||
        options.inventoryType == 'preorder') {
      query = query.where('inventoryType', isEqualTo: options.inventoryType);
    }
    if (options.minPrice != null) {
      query = query.where('price', isGreaterThanOrEqualTo: options.minPrice);
    }
    if (options.maxPrice != null) {
      query = query.where('price', isLessThanOrEqualTo: options.maxPrice);
    }

    switch (options.sort) {
      case ProductSortOption.newest:
        query = query.orderBy('createdAt', descending: true);
        break;
      case ProductSortOption.bestSelling:
        query = query.orderBy('salesCount', descending: true);
        break;
      case ProductSortOption.priceLowToHigh:
        query = query.orderBy('price');
        break;
      case ProductSortOption.priceHighToLow:
        query = query.orderBy('price', descending: true);
        break;
    }

    query = query.limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query.get();
  }

  Future<List<String>> getProductCategories({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _categoryCache != null &&
        _categoryCacheAt != null &&
        DateTime.now().difference(_categoryCacheAt!).inMinutes < 15) {
      return _categoryCache!;
    }
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _productsRef
        .where('ownerId', isEqualTo: storeId)
        .get();
    final Set<String> categorySet = <String>{};
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snapshot.docs) {
      final String category = doc.data()['category']?.toString().trim() ?? '';
      if (category.isNotEmpty) {
        categorySet.add(category);
      }
    }
    final List<String> categories = categorySet.toList()..sort();
    _categoryCache = categories;
    _categoryCacheAt = DateTime.now();
    return categories;
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
    return _productsRef
        .where('ownerId', isEqualTo: storeId)
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
    String? name,
    double? price,
    String? category,
    String? description,
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

    final Map<String, dynamic> payload = <String, dynamic>{
      'inventoryType': normalizedType,
      'stock': normalizedType == 'preorder' ? 0 : stock,
      'preorderDays': normalizedType == 'preorder' ? preorderDays : 0,
      'preorderNote': normalizedType == 'preorder' ? preorderNote.trim() : '',
      'availableForPurchase': availableForPurchase,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (name != null && name.trim().isNotEmpty) {
      payload['name'] = name.trim();
    }
    if (price != null && price >= 0) {
      payload['price'] = price;
    }
    if (category != null && category.trim().isNotEmpty) {
      payload['category'] = category.trim();
    }
    if (description != null) {
      payload['description'] = description.trim();
    }
    await _productsRef.doc(productId).update(payload);
  }

  Future<void> deleteProduct(String productId) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    if (!await isCurrentUserAdmin()) {
      throw Exception('Only admin can delete products.');
    }
    await _productsRef.doc(productId).delete();
  }

  Future<void> updateProductImages({
    required String productId,
    required List<String> keepImageUrls,
    required List<File> newImages,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    if (!await isCurrentUserAdmin()) {
      throw Exception('Only admin can update product images.');
    }

    final DocumentReference<Map<String, dynamic>> productRef = _productsRef.doc(
      productId,
    );
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await productRef.get();
    if (!snapshot.exists) {
      throw Exception('Product not found.');
    }

    final List<String> currentImages =
        (snapshot.data()?['images'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic value) => value.toString())
            .where((String value) => value.trim().isNotEmpty)
            .toList(growable: false);
    final List<String> normalizedKeep = keepImageUrls
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
    final List<String> removedImages = currentImages
        .where((String url) => !normalizedKeep.contains(url))
        .toList(growable: false);

    final List<String> uploadedUrls = <String>[];
    try {
      final int startIndex = normalizedKeep.length;
      for (int i = 0; i < newImages.length; i++) {
        final File imageFile = newImages[i];
        final String extension = _extensionFor(imageFile.path);
        final String contentType = switch (extension) {
          'png' => 'image/png',
          'webp' => 'image/webp',
          _ => 'image/jpeg',
        };
        final Reference ref = _storage.ref().child(
          'users/${user.uid}/products/$productId/image_${startIndex + i}.$extension',
        );
        await ref.putFile(imageFile, SettableMetadata(contentType: contentType));
        uploadedUrls.add(await ref.getDownloadURL());
      }

      final List<String> nextImages = <String>[
        ...normalizedKeep,
        ...uploadedUrls,
      ];
      if (nextImages.isEmpty) {
        throw Exception('Product requires at least one image.');
      }

      await productRef.update(<String, dynamic>{
        'images': nextImages,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      for (final String url in removedImages) {
        try {
          await _storage.refFromURL(url).delete();
        } catch (_) {}
      }
    } catch (_) {
      for (final String url in uploadedUrls) {
        try {
          await _storage.refFromURL(url).delete();
        } catch (_) {}
      }
      rethrow;
    }
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
        try {
          await ref.putFile(
            imageFile,
            SettableMetadata(contentType: contentType),
          );
        } on FirebaseException catch (e) {
          throw Exception(
            'Image upload blocked (${e.code}). Check Firebase Storage rules / App Check config.',
          );
        }
        downloadUrls.add(await ref.getDownloadURL());
      }

      try {
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
          'salesCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } on FirebaseException catch (e) {
        throw Exception(
          'Product write blocked (${e.code}). Ensure role has products scope and Firestore rules are deployed.',
        );
      }
      unawaited(
        TelemetryService.instance.logShopProductCreated(
          productId: productRef.id,
          category: input.category.trim(),
        ),
      );

      final DocumentSnapshot<Map<String, dynamic>> created = await productRef
          .get();
      return Product.fromFirestore(created);
    } catch (e) {
      debugPrint('createProduct failed: $e');
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
