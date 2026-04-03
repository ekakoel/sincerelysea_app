import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sincerelysea/models/cart_item.dart';
import 'package:sincerelysea/models/order.dart' as app_order;

class CartService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _cartRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('cart');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> cartStream() {
    final User? user = _auth.currentUser;
    if (user == null) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    return _cartRef(user.uid).snapshots();
  }

  Stream<int> cartItemCountStream() {
    final User? user = _auth.currentUser;
    if (user == null) {
      return Stream<int>.value(0);
    }
    return _cartRef(user.uid).snapshots().map(
      (QuerySnapshot<Map<String, dynamic>> snapshot) {
        int total = 0;
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in snapshot.docs) {
          final int quantity = doc.data()['quantity'] is num
              ? (doc.data()['quantity'] as num).toInt()
              : 0;
          total += quantity;
        }
        return total;
      },
    );
  }

  Future<List<CartItem>> getCartItems() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _cartRef(
      user.uid,
    ).get();
    return snapshot.docs
        .map(CartItem.fromFirestore)
        .where((CartItem item) => item.productId.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> addToCart({
    required String productId,
    int quantity = 1,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    if (productId.trim().isEmpty) {
      throw Exception('Product id is required.');
    }
    if (quantity <= 0) {
      throw Exception('Quantity must be greater than zero.');
    }

    final DocumentReference<Map<String, dynamic>> doc = _cartRef(
      user.uid,
    ).doc(productId);
    await _firestore.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await tx.get(doc);
      final int currentQuantity = snapshot.data()?['quantity'] is num
          ? (snapshot.data()!['quantity'] as num).toInt()
          : 0;
      tx.set(doc, <String, dynamic>{
        'productId': productId,
        'quantity': currentQuantity + quantity,
      }, SetOptions(merge: true));
    });
  }

  Future<void> updateQuantity({
    required String cartId,
    required int quantity,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    if (quantity <= 0) {
      await removeItem(cartId);
      return;
    }
    await _cartRef(user.uid).doc(cartId).set(<String, dynamic>{
      'productId': cartId,
      'quantity': quantity,
    }, SetOptions(merge: true));
  }

  Future<void> removeItem(String cartId) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    await _cartRef(user.uid).doc(cartId).delete();
  }

  Future<void> clearCart() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _cartRef(
      user.uid,
    ).get();
    final WriteBatch batch = _firestore.batch();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> addOrderItemsToCart(List<app_order.OrderItem> items) async {
    for (final app_order.OrderItem item in items) {
      if (item.productId.trim().isEmpty || item.quantity <= 0) {
        continue;
      }
      await addToCart(productId: item.productId, quantity: item.quantity);
    }
  }
}
