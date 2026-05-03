import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:sincerelysea/services/telemetry_service.dart';

class PostService {
  static const int _maxHashtagCount = 8;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Stream of posts
  Stream<QuerySnapshot<Map<String, dynamic>>> getPosts() {
    return _firestore
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Paginated posts fetch
  Future<QuerySnapshot<Map<String, dynamic>>> getPostsPaginated({
    required int limit,
    DocumentSnapshot? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query.get();
  }

  // Get single post stream (for real-time updates of likes/comments count)
  Stream<DocumentSnapshot<Map<String, dynamic>>> getPost(String postId) {
    return _firestore.collection('posts').doc(postId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getUserPosts(String uid) {
    // Avoid composite-index requirement (uid + timestamp) by sorting in client.
    return _firestore
        .collection('posts')
        .where('uid', isEqualTo: uid)
        .snapshots();
  }

  // Add a new post
  Future<void> addPost(
    String content, {
    String? imageUrl,
    String? location,
    GeoPoint? geo,
    List<String>? hashtags,
    String visibility = 'public',
    String type = 'post',
    String? productId,
  }) async {
    final user = _auth.currentUser;
    if (user != null && (content.trim().isNotEmpty || imageUrl != null)) {
      final String normalizedVisibility =
          <String>{'public', 'followers', 'private'}.contains(visibility)
          ? visibility
          : 'public';
      String username =
          user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : (user.email?.split('@')[0] ?? 'Anonymous');
      try {
        final DocumentSnapshot<Map<String, dynamic>> userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get()
            .timeout(const Duration(seconds: 3));
        final Map<String, dynamic> userData =
            userDoc.data() ?? <String, dynamic>{};
        final String? profileUsername = userData['username']?.toString().trim();
        if (profileUsername != null && profileUsername.isNotEmpty) {
          username = profileUsername;
        }
      } catch (_) {
        // Firestore profile lookup is best-effort only. Post creation should
        // still proceed using Firebase Auth fallback identity data.
      }
      final List<String> locationKeywords = _buildLocationKeywords(
        location?.trim() ?? '',
      );
      final List<String> sanitizedHashtags = _sanitizeHashtags(hashtags);
      final String normalizedType =
          type.trim().toLowerCase() == 'product' ? 'product' : 'post';
      final String normalizedProductId = productId?.trim() ?? '';
      final Map<String, dynamic> payload = <String, dynamic>{
        'content': content.trim(),
        'username': username,
        'imageUrl': imageUrl?.trim(),
        'location': location?.trim(),
        'locationName': location?.trim(),
        'locationKeywords': locationKeywords,
        'geo': geo,
        'hashtags': sanitizedHashtags,
        'uid': user.uid,
        'visibility': normalizedVisibility,
        'allowComments': 'everyone',
        'type': normalizedType,
        'productId': normalizedProductId.isEmpty ? null : normalizedProductId,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': [],
        'commentCount': 0,
        'shareCount': 0,
      };
      try {
        await _createPostDocument(payload);
      } on FirebaseException catch (e) {
        if (e.code != 'unavailable') {
          rethrow;
        }
        try {
          await _firestore.enableNetwork();
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 600));
        await _createPostDocument(payload);
      }
      try {
        await TelemetryService.instance.logPostCreated();
      } catch (_) {
        // Telemetry must never block post creation success.
      }
    }
  }

  Future<void> _createPostDocument(Map<String, dynamic> payload) {
    return _firestore.collection('posts').add(payload);
  }

  // Upload image to Firebase Storage
  Future<String?> uploadImage(
    File imageFile, {
    void Function(double progress)? onProgress,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final File optimizedFile = await _optimizeImageBeforeUpload(imageFile);
    final bool shouldDeleteTempFile = optimizedFile.path != imageFile.path;

    final String fileName =
        '${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final Reference ref = _storage.ref().child('post_images/$fileName');

    StreamSubscription<TaskSnapshot>? subscription;
    try {
      onProgress?.call(0);
      final UploadTask uploadTask = ref.putFile(
        optimizedFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      subscription = uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final int totalBytes = snapshot.totalBytes;
        if (totalBytes <= 0) {
          return;
        }
        final double progress = snapshot.bytesTransferred / totalBytes;
        onProgress?.call(progress.clamp(0, 1));
      });

      final TaskSnapshot snapshot = await uploadTask;
      await subscription.cancel();
      onProgress?.call(1);
      return await snapshot.ref.getDownloadURL();
    } finally {
      await subscription?.cancel();
      if (shouldDeleteTempFile) {
        try {
          await optimizedFile.delete();
        } catch (_) {}
      }
    }
  }

  Future<File> _optimizeImageBeforeUpload(File imageFile) async {
    final int originalSize = await imageFile.length();
    if (originalSize <= 300 * 1024) {
      return imageFile;
    }

    int quality = 85;
    if (originalSize > 8 * 1024 * 1024) {
      quality = 60;
    } else if (originalSize > 4 * 1024 * 1024) {
      quality = 70;
    } else if (originalSize > 2 * 1024 * 1024) {
      quality = 78;
    }

    final String targetPath =
        '${Directory.systemTemp.path}/post_optimized_${DateTime.now().microsecondsSinceEpoch}.jpg';

    final XFile? compressed = await FlutterImageCompress.compressAndGetFile(
      imageFile.absolute.path,
      targetPath,
      quality: quality,
      format: CompressFormat.jpeg,
      keepExif: true,
      autoCorrectionAngle: true,
    );

    if (compressed == null) {
      return imageFile;
    }

    final File compressedFile = File(compressed.path);
    final int compressedSize = await compressedFile.length();
    if (compressedSize >= originalSize) {
      try {
        await compressedFile.delete();
      } catch (_) {}
      return imageFile;
    }

    return compressedFile;
  }

  // Update a post (owner only, validated by Firestore security rules)
  Future<void> updatePost(
    String postId, {
    required String content,
    String? location,
    List<String>? hashtags,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final List<String> sanitizedHashtags = _sanitizeHashtags(hashtags);

    await _firestore.collection('posts').doc(postId).update({
      'content': content.trim(),
      'location': location?.trim() ?? '',
      'locationName': location?.trim() ?? '',
      'hashtags': sanitizedHashtags,
    });
  }

  // Delete a post (owner only, validated client-side and by Firestore rules).
  Future<void> deletePost(String postId) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'unauthenticated',
        message: 'Please login again.',
      );
    }

    final DocumentReference<Map<String, dynamic>> postRef = _firestore
        .collection('posts')
        .doc(postId);
    final DocumentSnapshot<Map<String, dynamic>> postSnapshot =
        await postRef.get();
    if (!postSnapshot.exists) {
      return;
    }

    final Map<String, dynamic> data = postSnapshot.data() ?? <String, dynamic>{};
    final String ownerUid = data['uid']?.toString() ?? '';
    final String imageUrl = data['imageUrl']?.toString().trim() ?? '';
    if (ownerUid != user.uid) {
      throw FirebaseAuthException(
        code: 'permission-denied',
        message: 'Only post owner can delete this post.',
      );
    }

    await _deleteCommentsTree(postRef);
    await postRef.delete();
    await _deleteImageIfFirebaseUrl(imageUrl);
  }

  List<String> _sanitizeHashtags(List<String>? hashtags) {
    if (hashtags == null || hashtags.isEmpty) {
      return <String>[];
    }
    final Set<String> seen = <String>{};
    final List<String> sanitized = <String>[];
    for (final String rawTag in hashtags) {
      final String trimmed = rawTag.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final String normalized = trimmed.startsWith('#') ? trimmed : '#$trimmed';
      final String lower = normalized.toLowerCase();
      if (lower.length <= 1 || !seen.add(lower)) {
        continue;
      }
      sanitized.add(lower);
      if (sanitized.length >= _maxHashtagCount) {
        break;
      }
    }
    return sanitized;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getPostsForMap({
    String? hashtag,
  }) {
    final String normalized = hashtag == null || hashtag.trim().isEmpty
        ? ''
        : (hashtag.trim().startsWith('#')
              ? hashtag.trim()
              : '#${hashtag.trim()}');

    Query<Map<String, dynamic>> query = _firestore
        .collection('posts')
        .orderBy('timestamp', descending: true);
    if (normalized.isNotEmpty) {
      query = query.where('hashtags', arrayContains: normalized);
    }

    // Keep dataset bounded for map performance while still wide enough
    // to support Top 10/20/50 in the visible area.
    return query.limit(500).snapshots();
  }

  // Like a post
  Future<void> toggleLike(String postId, bool isLiked) async {
    final user = _auth.currentUser;
    if (user != null) {
      final postRef = _firestore.collection('posts').doc(postId);
      if (isLiked) {
        await postRef.update({
          'likes': FieldValue.arrayRemove([user.uid]),
        });
      } else {
        await postRef.update({
          'likes': FieldValue.arrayUnion([user.uid]),
        });
      }
    }
  }

  // Increment share count for post insights
  Future<void> incrementShareCount(
    String postId, {
    String method = 'system_share',
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return;
    }
    await _firestore.collection('posts').doc(postId).update({
      'shareCount': FieldValue.increment(1),
      'lastShareActorUid': user.uid,
    });
    await TelemetryService.instance.logSharePost(method: method, postId: postId);
  }

  // Add a comment
  Future<void> addComment(String postId, String content) async {
    final User? user = _auth.currentUser;
    if (user == null || content.trim().isEmpty) {
      return;
    }

    final Map<String, dynamic> commentPayload = <String, dynamic>{
      'content': content.trim(),
      'username': user.displayName ?? user.email?.split('@')[0] ?? 'Anonymous',
      'uid': user.uid,
      'timestamp': FieldValue.serverTimestamp(),
      'likes': <String>[],
    };

    await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .add(commentPayload);
  }

  List<String> _buildLocationKeywords(String location) {
    final String lower = location.trim().toLowerCase();
    if (lower.isEmpty) {
      return <String>[];
    }
    final List<String> parts = lower
        .split(RegExp(r'[,\\s]+'))
        .where((String part) => part.isNotEmpty)
        .toList();
    final Set<String> keywords = <String>{lower, ...parts};
    return keywords.take(10).toList();
  }

  // Delete a comment
  Future<void> deleteComment(String postId, String commentId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .delete();
  }

  // Update a comment
  Future<void> updateComment(
    String postId,
    String commentId,
    String newContent,
  ) async {
    final user = _auth.currentUser;
    if (user != null && newContent.trim().isNotEmpty) {
      await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .update({'content': newContent.trim()});
    }
  }

  // Like a comment
  Future<void> toggleCommentLike(
    String postId,
    String commentId,
    bool isLiked,
  ) async {
    final user = _auth.currentUser;
    if (user != null) {
      final commentRef = _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId);

      if (isLiked) {
        await commentRef.update({
          'likes': FieldValue.arrayRemove([user.uid]),
        });
      } else {
        await commentRef.update({
          'likes': FieldValue.arrayUnion([user.uid]),
        });
      }
    }
  }

  // Add a reply under a comment
  Future<void> addReply(String postId, String commentId, String content) async {
    final User? user = _auth.currentUser;
    if (user != null && content.trim().isNotEmpty) {
      await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .add({
            'content': content.trim(),
            'username':
                user.displayName ?? user.email?.split('@')[0] ?? 'Anonymous',
            'uid': user.uid,
            'timestamp': FieldValue.serverTimestamp(),
            'likes': <String>[],
          });
    }
  }

  // Get replies stream for one comment
  Stream<QuerySnapshot<Map<String, dynamic>>> getReplies(
    String postId,
    String commentId,
  ) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .orderBy('timestamp')
        .snapshots();
  }

  // Get comments stream
  Stream<QuerySnapshot<Map<String, dynamic>>> getComments(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> _deleteCommentsTree(
    DocumentReference<Map<String, dynamic>> postRef,
  ) async {
    final QuerySnapshot<Map<String, dynamic>> commentsSnapshot = await postRef
        .collection('comments')
        .get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> commentDoc
        in commentsSnapshot.docs) {
      final QuerySnapshot<Map<String, dynamic>> repliesSnapshot =
          await commentDoc.reference.collection('replies').get();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> replyDoc
          in repliesSnapshot.docs) {
        await replyDoc.reference.delete();
      }
      await commentDoc.reference.delete();
    }
  }

  bool _isLikelyHttpImageUrl(String value) {
    final Uri? uri = Uri.tryParse(value.trim());
    if (uri == null) {
      return false;
    }
    return (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  bool _isFirebaseStorageHttpUrl(String value) {
    final String url = value.trim();
    return url.startsWith('https://firebasestorage.googleapis.com/') ||
        url.startsWith('https://storage.googleapis.com/');
  }

  Future<void> _deleteImageIfFirebaseUrl(String imageUrl) async {
    final String trimmed = imageUrl.trim();
    if (trimmed.isEmpty) {
      return;
    }
    if (!_isFirebaseStorageHttpUrl(trimmed) && !trimmed.startsWith('gs://')) {
      return;
    }
    try {
      await _storage.refFromURL(trimmed).delete();
    } catch (_) {
      // Ignore storage cleanup errors so post deletion still succeeds.
    }
  }

  /// Audit posts imageUrl values to find invalid or legacy URL patterns.
  /// Returns counts and sample post IDs for quick investigation.
  Future<Map<String, dynamic>> auditPostImageUrls({int limit = 500}) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    int total = 0;
    int empty = 0;
    int invalidFormat = 0;
    int gsScheme = 0;
    int nonFirebaseHost = 0;
    int valid = 0;

    final List<String> sampleInvalidPostIds = <String>[];
    final List<String> sampleGsPostIds = <String>[];

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      total += 1;
      final String imageUrl = doc.data()['imageUrl']?.toString().trim() ?? '';

      if (imageUrl.isEmpty) {
        empty += 1;
        continue;
      }

      if (imageUrl.startsWith('gs://')) {
        gsScheme += 1;
        if (sampleGsPostIds.length < 20) {
          sampleGsPostIds.add(doc.id);
        }
        continue;
      }

      if (!_isLikelyHttpImageUrl(imageUrl)) {
        invalidFormat += 1;
        if (sampleInvalidPostIds.length < 20) {
          sampleInvalidPostIds.add(doc.id);
        }
        continue;
      }

      if (!_isFirebaseStorageHttpUrl(imageUrl)) {
        nonFirebaseHost += 1;
      }

      valid += 1;
    }

    return <String, dynamic>{
      'scanned': total,
      'valid': valid,
      'empty': empty,
      'invalidFormat': invalidFormat,
      'gsScheme': gsScheme,
      'nonFirebaseHost': nonFirebaseHost,
      'sampleInvalidPostIds': sampleInvalidPostIds,
      'sampleGsPostIds': sampleGsPostIds,
    };
  }

  /// Convert legacy gs:// URLs to HTTPS download URLs.
  /// Returns number of updated documents.
  Future<int> repairLegacyGsImageUrls({int limit = 500}) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    int updated = 0;

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      final String imageUrl = doc.data()['imageUrl']?.toString().trim() ?? '';
      if (!imageUrl.startsWith('gs://')) {
        continue;
      }

      try {
        final String downloadUrl = await _storage
            .refFromURL(imageUrl)
            .getDownloadURL();
        await doc.reference.update({'imageUrl': downloadUrl});
        updated += 1;
      } catch (_) {
        // Ignore failed conversion and continue scanning next docs.
      }
    }

    return updated;
  }
}
