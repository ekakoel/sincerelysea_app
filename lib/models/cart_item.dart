import 'package:cloud_firestore/cloud_firestore.dart';

class CartItem {
  const CartItem({
    required this.id,
    required this.productId,
    required this.quantity,
  });

  final String id;
  final String productId;
  final int quantity;

  factory CartItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    return CartItem(
      id: doc.id,
      productId: data['productId']?.toString() ?? '',
      quantity: _toInt(data['quantity']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'productId': productId,
      'quantity': quantity,
    };
  }

  static int _toInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
