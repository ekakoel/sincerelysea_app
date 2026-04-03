import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationCenterService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const Set<String> _allowedTypes = <String>{
    'like',
    'comment',
    'follow',
    'follow_request',
    'share',
    'back_in_stock',
    'activity',
  };

  CollectionReference<Map<String, dynamic>> _notificationRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('notifications');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> notificationsStream() {
    final User? user = _auth.currentUser;
    if (user == null) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    return _notificationRef(
      user.uid,
    ).orderBy('createdAt', descending: true).limit(100).snapshots();
  }

  Stream<int> unreadCountStream() {
    final User? user = _auth.currentUser;
    if (user == null) {
      return Stream<int>.value(0);
    }
    return _notificationRef(
      user.uid,
    ).where('read', isEqualTo: false).snapshots().map((s) => s.docs.length);
  }

  Future<void> markAsRead(String notificationId) async {
    final User? user = _auth.currentUser;
    if (user == null) return;
    await _notificationRef(user.uid).doc(notificationId).update({
      'read': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAllAsRead() async {
    final User? user = _auth.currentUser;
    if (user == null) return;

    final QuerySnapshot<Map<String, dynamic>> unread = await _notificationRef(
      user.uid,
    ).where('read', isEqualTo: false).get();

    if (unread.docs.isEmpty) {
      return;
    }

    const int chunkSize = 400;
    for (int i = 0; i < unread.docs.length; i += chunkSize) {
      final int end = (i + chunkSize > unread.docs.length)
          ? unread.docs.length
          : i + chunkSize;
      final WriteBatch batch = _firestore.batch();
      for (int j = i; j < end; j++) {
        batch.update(unread.docs[j].reference, {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  Future<void> createNotification({
    required String targetUid,
    required String type,
    required String actorUid,
    required String actorUsername,
    String? postId,
    String? productId,
    String? message,
  }) async {
    if (targetUid.isEmpty || actorUid.isEmpty || targetUid == actorUid) {
      return;
    }
    final String normalizedType = _allowedTypes.contains(type)
        ? type
        : 'activity';
    final String safeActorUsername = actorUsername.trim().isEmpty
        ? 'user'
        : actorUsername.trim();
    final String safeMessage = (message ?? '').trim();
    final String? safePostId = postId?.trim().isNotEmpty == true
        ? postId!.trim()
        : null;
    final String? safeProductId = productId?.trim().isNotEmpty == true
        ? productId!.trim()
        : null;

    if (await _isDuplicateRecentNotification(
      targetUid: targetUid,
      type: normalizedType,
      actorUid: actorUid,
      postId: safePostId,
      productId: safeProductId,
    )) {
      return;
    }

    await _notificationRef(targetUid).add(<String, dynamic>{
      'type': normalizedType,
      'actorUid': actorUid,
      'actorUsername': safeActorUsername,
      'postId': safePostId,
      'productId': safeProductId,
      'message': safeMessage.length <= 240
          ? safeMessage
          : '${safeMessage.substring(0, 240)}...',
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> _isDuplicateRecentNotification({
    required String targetUid,
    required String type,
    required String actorUid,
    required String? postId,
    required String? productId,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> recent = await _notificationRef(
      targetUid,
    ).orderBy('createdAt', descending: true).limit(15).get();
    final DateTime now = DateTime.now();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in recent.docs) {
      final Map<String, dynamic> data = doc.data();
      if (data['type']?.toString() != type) {
        continue;
      }
      if (data['actorUid']?.toString() != actorUid) {
        continue;
      }
      if ((data['postId']?.toString() ?? '') != (postId ?? '')) {
        continue;
      }
      if ((data['productId']?.toString() ?? '') != (productId ?? '')) {
        continue;
      }
      final Timestamp? createdAt = data['createdAt'] as Timestamp?;
      if (createdAt == null) {
        continue;
      }
      final Duration diff = now.difference(createdAt.toDate());
      if (diff.inSeconds <= 30) {
        return true;
      }
    }
    return false;
  }
}
