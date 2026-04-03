import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  const Product({
    required this.id,
    required this.userId,
    required this.ownerType,
    required this.ownerId,
    required this.storeName,
    required this.managedByAdmins,
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
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String ownerType;
  final String ownerId;
  final String storeName;
  final bool managedByAdmins;
  final String category;
  final String inventoryType;
  final int preorderDays;
  final String preorderNote;
  final bool availableForPurchase;
  final String name;
  final double price;
  final String description;
  final int stock;
  final List<String> images;
  final Timestamp? createdAt;

  bool get isPreorder => inventoryType == 'preorder';
  bool get isReadyStock => !isPreorder;
  bool get inStock => isPreorder ? availableForPurchase : stock > 0;
  bool get canPurchase => availableForPurchase && (isPreorder || stock > 0);
  String get inventoryLabel => isPreorder ? 'Preorder' : 'Ready Stock';

  factory Product.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    return Product(
      id: doc.id,
      userId: data['userId']?.toString() ?? '',
      ownerType: data['ownerType']?.toString() == 'business'
          ? 'business'
          : 'business',
      ownerId: data['ownerId']?.toString().trim().isNotEmpty == true
          ? data['ownerId'].toString().trim()
          : 'sincerelysea',
      storeName: data['storeName']?.toString().trim().isNotEmpty == true
          ? data['storeName'].toString().trim()
          : 'SincerelySea Store',
      managedByAdmins: data['managedByAdmins'] is bool
          ? data['managedByAdmins'] as bool
          : true,
      category: data['category']?.toString() ?? '',
      inventoryType: _normalizeInventoryType(data['inventoryType']),
      preorderDays: _toInt(data['preorderDays']),
      preorderNote: data['preorderNote']?.toString() ?? '',
      availableForPurchase: data['availableForPurchase'] is bool
          ? data['availableForPurchase'] as bool
          : true,
      name: data['name']?.toString() ?? '',
      price: _toDouble(data['price']),
      description: data['description']?.toString() ?? '',
      stock: _toInt(data['stock']),
      images: (data['images'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic image) => image.toString())
          .where((String image) => image.trim().isNotEmpty)
          .toList(growable: false),
      createdAt: data['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'userId': userId,
      'ownerType': ownerType,
      'ownerId': ownerId,
      'storeName': storeName.trim(),
      'managedByAdmins': managedByAdmins,
      'category': category.trim(),
      'inventoryType': inventoryType,
      'preorderDays': preorderDays,
      'preorderNote': preorderNote.trim(),
      'availableForPurchase': availableForPurchase,
      'name': name.trim(),
      'price': price,
      'description': description.trim(),
      'stock': stock,
      'images': images,
      'createdAt': createdAt,
    };
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _toInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _normalizeInventoryType(dynamic value) {
    final String normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized == 'preorder' ? 'preorder' : 'ready_stock';
  }
}
