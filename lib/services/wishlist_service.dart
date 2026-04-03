import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sincerelysea/models/product.dart';

class WishlistService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _wishlistRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('wishlists');
  }

  String _productWishlistDocId(String productId) => 'product_$productId';

  Stream<QuerySnapshot<Map<String, dynamic>>> getWishlistStream(String uid) {
    return _wishlistRef(uid).orderBy('createdAt', descending: true).snapshots();
  }

  Stream<Set<String>> productWishlistIdsStream() {
    final User? user = _auth.currentUser;
    if (user == null) {
      return Stream<Set<String>>.value(<String>{});
    }
    return _wishlistRef(user.uid)
        .where('type', isEqualTo: 'product')
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          return snapshot.docs
              .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
                return doc.data()['productId']?.toString() ?? '';
              })
              .where((String productId) => productId.trim().isNotEmpty)
              .toSet();
        });
  }

  Future<void> addWishlist({
    required String title,
    String? notes,
    String? category,
    DateTime? targetDate,
    int priority = 2,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    await _wishlistRef(user.uid).add({
      'uid': user.uid,
      'type': 'manual',
      'title': title.trim(),
      'notes': notes?.trim() ?? '',
      'category': category?.trim() ?? '',
      'priority': priority,
      'targetDate': targetDate != null ? Timestamp.fromDate(targetDate) : null,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'fulfilledAt': null,
    });
  }

  Stream<bool> isProductWishlistedStream(String productId) {
    final User? user = _auth.currentUser;
    if (user == null || productId.trim().isEmpty) {
      return Stream<bool>.value(false);
    }
    return _wishlistRef(user.uid)
        .doc(_productWishlistDocId(productId))
        .snapshots()
        .map((DocumentSnapshot<Map<String, dynamic>> doc) => doc.exists);
  }

  Future<void> addProductWishlist(Product product) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    if (product.id.trim().isEmpty) {
      throw Exception('Product id is required');
    }

    await _wishlistRef(user.uid).doc(_productWishlistDocId(product.id)).set({
      'uid': user.uid,
      'type': 'product',
      'productId': product.id,
      'productUserId': product.userId,
      'productImageUrl': product.images.isNotEmpty ? product.images.first : '',
      'productPrice': product.price,
      'title': product.name.trim(),
      'notes': product.description.trim(),
      'category': product.category.trim(),
      'priority': 2,
      'targetDate': null,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'fulfilledAt': null,
    }, SetOptions(merge: true));
  }

  Future<void> removeProductWishlist(String productId) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    if (productId.trim().isEmpty) {
      throw Exception('Product id is required');
    }

    await _wishlistRef(user.uid).doc(_productWishlistDocId(productId)).delete();
  }

  Future<void> toggleProductWishlist(Product product) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final DocumentReference<Map<String, dynamic>> docRef = _wishlistRef(
      user.uid,
    ).doc(_productWishlistDocId(product.id));
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await docRef.get();
    if (snapshot.exists) {
      await docRef.delete();
      return;
    }
    await addProductWishlist(product);
  }

  Future<void> updateWishlist({
    required String wishlistId,
    required String title,
    String? notes,
    String? category,
    DateTime? targetDate,
    int? priority,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'title': title.trim(),
      'notes': notes?.trim() ?? '',
      'category': category?.trim() ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
      'targetDate': targetDate != null ? Timestamp.fromDate(targetDate) : null,
    };
    if (priority != null) {
      payload['priority'] = priority;
    }

    await _wishlistRef(user.uid).doc(wishlistId).update(payload);
  }

  Future<void> toggleWishlistStatus({
    required String wishlistId,
    required bool fulfilled,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    await _wishlistRef(user.uid).doc(wishlistId).update({
      'status': fulfilled ? 'fulfilled' : 'active',
      'fulfilledAt': fulfilled ? FieldValue.serverTimestamp() : null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteWishlist(String wishlistId) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    await _wishlistRef(user.uid).doc(wishlistId).delete();
  }
}
