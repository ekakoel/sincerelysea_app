import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sincerelysea/models/cart_item.dart';
import 'package:sincerelysea/models/order.dart' as app_order;
import 'package:sincerelysea/models/product.dart';
import 'package:sincerelysea/services/sales_reporting_service.dart';

class CheckoutInfo {
  const CheckoutInfo({
    required this.customerName,
    required this.phone,
    required this.address,
  });

  final String customerName;
  final String phone;
  final String address;
}

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SalesReportingService _salesReportingService = SalesReportingService();
  static const Set<String> _allowedStatuses = <String>{
    'pending',
    'cancelled',
    'paid',
    'processing',
    'shipped',
    'completed',
  };

  CollectionReference<Map<String, dynamic>> get _ordersRef =>
      _firestore.collection('orders');

  Future<bool> _isCurrentUserAdmin() async {
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
    return scopes.map((dynamic scope) => scope.toString()).contains('orders');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> myOrdersStream() {
    final User? user = _auth.currentUser;
    if (user == null) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    return _ordersRef
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> sellerOrdersStream() {
    if (_auth.currentUser == null) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    return _ordersRef
        .where('storeId', isEqualTo: SalesReportingService.storeId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    final String normalizedStatus = status.trim().toLowerCase();
    if (!_allowedStatuses.contains(normalizedStatus)) {
      throw Exception('Invalid order status.');
    }

    final DocumentReference<Map<String, dynamic>> orderRef = _ordersRef.doc(
      orderId,
    );
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await orderRef.get();
    if (!snapshot.exists) {
      throw Exception('Order not found.');
    }

    if (!await _isCurrentUserAdmin()) {
      throw Exception('Only store admins can update this order.');
    }
    final app_order.Order order = app_order.Order.fromFirestore(snapshot);
    await _firestore.runTransaction((Transaction tx) async {
      tx.update(orderRef, <String, dynamic>{
        'status': normalizedStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final DateTime now = DateTime.now();
      if (order.status != 'paid' && normalizedStatus == 'paid') {
        _salesReportingService.recordOrderPaid(
          tx: tx,
          orderId: order.id,
          totalPrice: order.totalPrice,
          occurredAt: now,
        );
      }
      if (order.status != 'completed' && normalizedStatus == 'completed') {
        _salesReportingService.recordOrderCompleted(
          tx: tx,
          occurredAt: now,
        );
      }
    });
  }

  Future<void> cancelOrder(String orderId) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final DocumentReference<Map<String, dynamic>> orderRef = _ordersRef.doc(
      orderId,
    );

    await _firestore.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> orderSnapshot = await tx.get(
        orderRef,
      );
      if (!orderSnapshot.exists) {
        throw Exception('Order not found.');
      }

      final app_order.Order order = app_order.Order.fromFirestore(orderSnapshot);
      if (order.userId != user.uid) {
        throw Exception('Only the buyer can cancel this order.');
      }
      if (order.status != 'pending') {
        throw Exception('Only pending orders can be cancelled.');
      }

      for (final app_order.OrderItem item in order.items) {
        if (item.inventoryType == 'preorder' ||
            item.productId.trim().isEmpty ||
            item.quantity <= 0) {
          continue;
        }
        final DocumentReference<Map<String, dynamic>> productRef = _firestore
            .collection('products')
            .doc(item.productId);
        final DocumentSnapshot<Map<String, dynamic>> productSnapshot =
            await tx.get(productRef);
        if (!productSnapshot.exists) {
          continue;
        }

        final int currentStock = productSnapshot.data()?['stock'] is num
            ? (productSnapshot.data()!['stock'] as num).toInt()
            : 0;
        tx.update(productRef, <String, dynamic>{
          'stock': currentStock + item.quantity,
        });
      }

      tx.update(orderRef, <String, dynamic>{
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _salesReportingService.recordOrderCancelled(
        tx: tx,
        orderId: order.id,
        totalPrice: order.totalPrice,
        occurredAt: DateTime.now(),
      );
    });
  }

  Future<String> placeOrder({
    required List<CartItem> cartItems,
    required Map<String, Product> productsById,
    required CheckoutInfo checkoutInfo,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    if (cartItems.isEmpty) {
      throw Exception('Cart is empty.');
    }

    final DocumentReference<Map<String, dynamic>> orderRef = _ordersRef.doc();
    await _firestore.runTransaction((Transaction tx) async {
      final List<app_order.OrderItem> orderItems = <app_order.OrderItem>[];
      double totalPrice = 0;

      for (final CartItem cartItem in cartItems) {
        final Product? product = productsById[cartItem.productId];
        if (product == null) {
          throw Exception('Product not found for ${cartItem.productId}.');
        }
        if (!product.availableForPurchase) {
          throw Exception('${product.name} is currently unavailable.');
        }
        if (product.isReadyStock && product.stock < cartItem.quantity) {
          throw Exception('Not enough stock for ${product.name}.');
        }

        final DocumentReference<Map<String, dynamic>> productRef = _firestore
            .collection('products')
            .doc(product.id);
        final DocumentSnapshot<Map<String, dynamic>> freshProduct = await tx.get(
          productRef,
        );
        final String inventoryType =
            freshProduct.data()?['inventoryType']?.toString() == 'preorder'
            ? 'preorder'
            : 'ready_stock';
        final bool availableForPurchase =
            freshProduct.data()?['availableForPurchase'] is bool
            ? freshProduct.data()!['availableForPurchase'] as bool
            : true;
        final int currentStock = freshProduct.data()?['stock'] is num
            ? (freshProduct.data()!['stock'] as num).toInt()
            : 0;
        if (!availableForPurchase) {
          throw Exception('${product.name} is currently unavailable.');
        }
        if (inventoryType == 'ready_stock' && currentStock < cartItem.quantity) {
          throw Exception('Not enough stock for ${product.name}.');
        }
        if (inventoryType == 'ready_stock') {
          tx.update(productRef, <String, dynamic>{
            'stock': currentStock - cartItem.quantity,
          });
        }

        final app_order.OrderItem orderItem = app_order.OrderItem(
          productId: product.id,
          sellerId: product.userId,
          productName: product.name,
          productImageUrl: product.images.isNotEmpty ? product.images.first : '',
          inventoryType: product.inventoryType,
          preorderDays: product.preorderDays,
          quantity: cartItem.quantity,
          price: product.price,
        );
        orderItems.add(orderItem);
        totalPrice += product.price * cartItem.quantity;
      }

      tx.set(orderRef, <String, dynamic>{
        'userId': user.uid,
        'storeId': SalesReportingService.storeId,
        'storeName': SalesReportingService.storeName,
        'items': orderItems.map((app_order.OrderItem item) => item.toMap()).toList(),
        'totalPrice': totalPrice,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'sellerIds': <String>[],
        'customerName': checkoutInfo.customerName.trim(),
        'phone': checkoutInfo.phone.trim(),
        'address': checkoutInfo.address.trim(),
        'fulfillmentMode': 'admin_managed',
      });
      _salesReportingService.recordOrderPlaced(
        tx: tx,
        orderId: orderRef.id,
        totalPrice: totalPrice,
        occurredAt: DateTime.now(),
      );
    });

    return orderRef.id;
  }
}
