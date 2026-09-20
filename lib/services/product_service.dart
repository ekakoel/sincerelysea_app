import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sincerelysea/config/official_store.dart';
import 'package:sincerelysea/models/product.dart';

enum ProductSortOption { newest, bestSelling, priceLowToHigh, priceHighToLow }

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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<String>? _categoryCache;
  DateTime? _categoryCacheAt;

  CollectionReference<Map<String, dynamic>> get _productsRef =>
      _firestore.collection('products');

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
    Query<Map<String, dynamic>> query = _productsRef.where(
      'ownerId',
      isEqualTo: OfficialStore.id,
    );

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
        .where('ownerId', isEqualTo: OfficialStore.id)
        .get();
    final Set<String> categorySet = <String>{};
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
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

  Future<List<Product>> getOfficialStoreProducts() async {
    QuerySnapshot<Map<String, dynamic>> snapshot = await _productsRef
        .where('ownerId', isEqualTo: OfficialStore.id)
        .get();
    if (snapshot.docs.isEmpty) {
      snapshot = await _productsRef.get();
    }
    final List<Product> products = snapshot.docs
        .map(Product.fromFirestore)
        .where(
          (Product product) =>
              product.ownerId == OfficialStore.id || product.managedByAdmins,
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
}
