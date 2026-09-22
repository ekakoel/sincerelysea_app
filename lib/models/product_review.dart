import 'package:cloud_firestore/cloud_firestore.dart';

class ProductReview {
  const ProductReview({
    required this.id,
    required this.productId,
    required this.userId,
    required this.rating,
    required this.reviewText,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String productId;
  final String userId;
  final int rating;
  final String reviewText;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory ProductReview.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data() ?? <String, dynamic>{};
    return ProductReview(
      id: document.id,
      productId: data['productId']?.toString() ?? '',
      userId: data['userId']?.toString() ?? '',
      rating: (data['rating'] as num?)?.toInt() ?? 0,
      reviewText: data['reviewText']?.toString() ?? '',
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }
}

class ProductReviewAuthor {
  const ProductReviewAuthor({
    required this.displayName,
    required this.username,
  });

  static const ProductReviewAuthor fallback = ProductReviewAuthor(
    displayName: 'SincerelySea Member',
    username: '',
  );

  final String displayName;
  final String username;

  factory ProductReviewAuthor.fromPublicProfile(Map<String, dynamic>? profile) {
    if (profile == null) {
      return fallback;
    }
    final String username = profile['username']?.toString().trim() ?? '';
    final String displayName = profile['displayName']?.toString().trim() ?? '';
    if (displayName.isEmpty && username.isEmpty) {
      return fallback;
    }
    return ProductReviewAuthor(
      displayName: displayName.isNotEmpty ? displayName : username,
      username: username,
    );
  }
}
