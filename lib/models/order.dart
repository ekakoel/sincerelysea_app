import 'package:cloud_firestore/cloud_firestore.dart';

class OrderItem {
  const OrderItem({
    required this.productId,
    required this.sellerId,
    required this.productName,
    required this.productImageUrl,
    required this.inventoryType,
    required this.preorderDays,
    required this.quantity,
    required this.price,
  });

  final String productId;
  final String sellerId;
  final String productName;
  final String productImageUrl;
  final String inventoryType;
  final int preorderDays;
  final int quantity;
  final double price;

  factory OrderItem.fromMap(Map<String, dynamic> data) {
    return OrderItem(
      productId: data['productId']?.toString() ?? '',
      sellerId: data['sellerId']?.toString() ?? '',
      productName: data['productName']?.toString() ?? '',
      productImageUrl: data['productImageUrl']?.toString() ?? '',
      inventoryType: data['inventoryType']?.toString() == 'preorder'
          ? 'preorder'
          : 'ready_stock',
      preorderDays: _toInt(data['preorderDays']),
      quantity: _toInt(data['quantity']),
      price: _toDouble(data['price']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'productId': productId,
      'sellerId': sellerId,
      'productName': productName,
      'productImageUrl': productImageUrl,
      'inventoryType': inventoryType,
      'preorderDays': preorderDays,
      'quantity': quantity,
      'price': price,
    };
  }
}

class Order {
  const Order({
    required this.id,
    required this.userId,
    required this.items,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
    required this.sellerIds,
    required this.customerName,
    required this.phone,
    required this.address,
  });

  final String id;
  final String userId;
  final List<OrderItem> items;
  final double totalPrice;
  final String status;
  final Timestamp? createdAt;
  final List<String> sellerIds;
  final String customerName;
  final String phone;
  final String address;

  factory Order.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    return Order(
      id: doc.id,
      userId: data['userId']?.toString() ?? '',
      items: (data['items'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(OrderItem.fromMap)
          .toList(growable: false),
      totalPrice: _toDouble(data['totalPrice']),
      status: data['status']?.toString() ?? 'pending',
      createdAt: data['createdAt'] as Timestamp?,
      sellerIds: (data['sellerIds'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic item) => item.toString())
          .where((String item) => item.trim().isNotEmpty)
          .toList(growable: false),
      customerName: data['customerName']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      address: data['address']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'userId': userId,
      'items': items.map((OrderItem item) => item.toMap()).toList(),
      'totalPrice': totalPrice,
      'status': status,
      'createdAt': createdAt,
      'sellerIds': sellerIds,
      'customerName': customerName.trim(),
      'phone': phone.trim(),
      'address': address.trim(),
    };
  }
}

double _toDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _toInt(dynamic value) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
