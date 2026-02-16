import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WishlistService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _wishlistRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('wishlists');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getWishlistStream(String uid) {
    return _wishlistRef(uid).orderBy('createdAt', descending: true).snapshots();
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
