import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:sincerelysea/models/cart_item.dart';

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
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  CollectionReference<Map<String, dynamic>> get _ordersRef =>
      _firestore.collection('orders');

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

  Future<void> cancelOrder(String orderId) async {
    if (_auth.currentUser == null) {
      throw Exception('User not authenticated');
    }
    final HttpsCallable callable = _functions.httpsCallable(
      'cancelCustomerOrder',
    );
    await callable.call(<String, dynamic>{'orderId': orderId});
  }

  String createCheckoutRequestId() => _ordersRef.doc().id;

  Future<String> placeOrder({
    required List<CartItem> cartItems,
    required CheckoutInfo checkoutInfo,
    required String checkoutRequestId,
  }) async {
    if (_auth.currentUser == null) {
      throw Exception('User not authenticated');
    }
    if (cartItems.isEmpty) {
      throw Exception('Cart is empty.');
    }
    final HttpsCallable callable = _functions.httpsCallable(
      'createCustomerOrder',
    );
    final HttpsCallableResult<dynamic> result = await callable.call(
      <String, dynamic>{
        'checkoutRequestId': checkoutRequestId,
        'items': cartItems
            .map(
              (CartItem item) => <String, dynamic>{
                'productId': item.productId,
                'quantity': item.quantity,
              },
            )
            .toList(growable: false),
        'customerName': checkoutInfo.customerName.trim(),
        'phone': checkoutInfo.phone.trim(),
        'address': checkoutInfo.address.trim(),
      },
    );
    final dynamic response = result.data;
    if (response is! Map) {
      throw Exception('Invalid create-order response.');
    }
    final String orderId = response['orderId']?.toString() ?? '';
    if (orderId.isEmpty) {
      throw Exception('Create-order response did not include an order ID.');
    }
    return orderId;
  }
}
