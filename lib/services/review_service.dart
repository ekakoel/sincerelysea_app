import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sincerelysea/models/product_review.dart';

class ReviewService {
  ReviewService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  static const int maxReviewLength = 1000;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String? get currentUserId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _reviewsRef(String productId) =>
      _firestore.collection('products').doc(productId).collection('reviews');

  Stream<List<ProductReview>> watchReviews(String productId) {
    return _reviewsRef(productId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
              .map(ProductReview.fromFirestore)
              .toList(growable: false),
        );
  }

  Future<ProductReviewAuthor> getPublicAuthor(String userId) async {
    if (userId.trim().isEmpty) {
      return ProductReviewAuthor.fallback;
    }
    final DocumentSnapshot<Map<String, dynamic>> profile = await _firestore
        .collection('users_public')
        .doc(userId)
        .get();
    return ProductReviewAuthor.fromPublicProfile(profile.data());
  }

  Future<void> createReview({
    required String productId,
    required int rating,
    required String reviewText,
  }) async {
    final User user = _requireUser();
    final String text = _validate(rating: rating, reviewText: reviewText);
    final DocumentReference<Map<String, dynamic>> reviewRef = _reviewsRef(
      productId,
    ).doc(user.uid);
    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> existing = await transaction
          .get(reviewRef);
      if (existing.exists) {
        throw StateError('Review already exists.');
      }
      transaction.set(reviewRef, <String, dynamic>{
        'productId': productId,
        'userId': user.uid,
        'rating': rating,
        'reviewText': text,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> updateReview({
    required String productId,
    required int rating,
    required String reviewText,
  }) async {
    final User user = _requireUser();
    final String text = _validate(rating: rating, reviewText: reviewText);
    await _reviewsRef(productId).doc(user.uid).update(<String, dynamic>{
      'rating': rating,
      'reviewText': text,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteReview(String productId) async {
    final User user = _requireUser();
    await _reviewsRef(productId).doc(user.uid).delete();
  }

  User _requireUser() {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw StateError('Authentication required.');
    }
    return user;
  }

  String _validate({required int rating, required String reviewText}) {
    final String text = reviewText.trim();
    if (rating < 1 || rating > 5) {
      throw ArgumentError.value(rating, 'rating', 'Rating must be 1 to 5.');
    }
    if (text.length < 2 || text.length > maxReviewLength) {
      throw ArgumentError.value(
        reviewText,
        'reviewText',
        'Review must be 2 to $maxReviewLength characters.',
      );
    }
    return text;
  }
}
