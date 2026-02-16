import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ModerationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get _currentUser => _auth.currentUser;

  CollectionReference<Map<String, dynamic>> _userBlocksRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('blocks');
  }

  CollectionReference<Map<String, dynamic>> _hiddenPostsRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('hidden_posts');
  }

  Stream<bool> isPostHiddenStream(String postId) {
    final User? user = _currentUser;
    if (user == null || postId.isEmpty) {
      return Stream<bool>.value(false);
    }
    return _hiddenPostsRef(
      user.uid,
    ).doc(postId).snapshots().map((doc) => doc.exists);
  }

  Future<bool> isPostHidden(String postId) async {
    final User? user = _currentUser;
    if (user == null || postId.isEmpty) {
      return false;
    }
    final DocumentSnapshot<Map<String, dynamic>> doc = await _hiddenPostsRef(
      user.uid,
    ).doc(postId).get();
    return doc.exists;
  }

  Stream<bool> isUserBlockedStream(String uid) {
    final User? user = _currentUser;
    if (user == null || uid.isEmpty) {
      return Stream<bool>.value(false);
    }
    return _userBlocksRef(
      uid,
    ).doc(user.uid).snapshots().map((doc) => doc.exists);
  }

  Future<bool> isUserBlocked(String uid) async {
    final User? user = _currentUser;
    if (user == null || uid.isEmpty) {
      return false;
    }
    final DocumentSnapshot<Map<String, dynamic>> doc = await _userBlocksRef(
      user.uid,
    ).doc(uid).get();
    return doc.exists;
  }

  Future<void> blockUser({
    required String targetUid,
    required String targetUsername,
  }) async {
    final User? user = _currentUser;
    if (user == null || targetUid.isEmpty || targetUid == user.uid) {
      return;
    }

    await _userBlocksRef(user.uid).doc(targetUid).set(<String, dynamic>{
      'uid': targetUid,
      'username': targetUsername,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> unblockUser(String targetUid) async {
    final User? user = _currentUser;
    if (user == null || targetUid.isEmpty) {
      return;
    }
    await _userBlocksRef(user.uid).doc(targetUid).delete();
  }

  Future<void> hidePost({
    required String postId,
    required String postOwnerUid,
  }) async {
    final User? user = _currentUser;
    if (user == null || postId.isEmpty) {
      return;
    }
    await _hiddenPostsRef(user.uid).doc(postId).set(<String, dynamic>{
      'postId': postId,
      'postOwnerUid': postOwnerUid,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> unhidePost(String postId) async {
    final User? user = _currentUser;
    if (user == null || postId.isEmpty) {
      return;
    }
    await _hiddenPostsRef(user.uid).doc(postId).delete();
  }

  Future<void> reportPost({
    required String postId,
    required String postOwnerUid,
    required String reason,
  }) async {
    final User? user = _currentUser;
    if (user == null || postId.isEmpty) {
      return;
    }

    await _firestore.collection('reports').add(<String, dynamic>{
      'type': 'post',
      'targetId': postId,
      'targetOwnerUid': postOwnerUid,
      'reason': reason.trim(),
      'reporterUid': user.uid,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> reportUser({
    required String targetUid,
    required String reason,
  }) async {
    final User? user = _currentUser;
    if (user == null || targetUid.isEmpty || targetUid == user.uid) {
      return;
    }

    await _firestore.collection('reports').add(<String, dynamic>{
      'type': 'user',
      'targetId': targetUid,
      'reason': reason.trim(),
      'reporterUid': user.uid,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
