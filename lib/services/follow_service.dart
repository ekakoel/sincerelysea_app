import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sincerelysea/services/telemetry_service.dart';

class FollowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _followersRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('followers');
  }

  CollectionReference<Map<String, dynamic>> _followingRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('following');
  }

  CollectionReference<Map<String, dynamic>> _savedPostsRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('saved_posts');
  }

  CollectionReference<Map<String, dynamic>> _followRequestRef(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('follow_requests');
  }

  Stream<bool> isFollowingStream(String targetUid) {
    final User? user = _auth.currentUser;
    if (user == null || targetUid.isEmpty || user.uid == targetUid) {
      return Stream<bool>.value(false);
    }
    return _followingRef(
      user.uid,
    ).doc(targetUid).snapshots().map((doc) => doc.exists);
  }

  Stream<bool> isFollowRequestedStream(String targetUid) {
    final User? user = _auth.currentUser;
    if (user == null || targetUid.isEmpty || user.uid == targetUid) {
      return Stream<bool>.value(false);
    }
    return _followRequestRef(
      targetUid,
    ).doc(user.uid).snapshots().map((doc) => doc.exists);
  }

  Stream<bool> isFollowingYouStream(String targetUid) {
    final User? user = _auth.currentUser;
    if (user == null || targetUid.isEmpty || user.uid == targetUid) {
      return Stream<bool>.value(false);
    }
    return _followersRef(
      user.uid,
    ).doc(targetUid).snapshots().map((doc) => doc.exists);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> followersStream(String uid) {
    return _followersRef(uid).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> followingStream(String uid) {
    return _followingRef(uid).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> savedPostsStream(String uid) {
    return _savedPostsRef(uid).snapshots();
  }

  Stream<bool> isPostSavedStream(String postId) {
    final User? user = _auth.currentUser;
    if (user == null || postId.isEmpty) {
      return Stream<bool>.value(false);
    }
    return _savedPostsRef(
      user.uid,
    ).doc(postId).snapshots().map((doc) => doc.exists);
  }

  Future<void> followUser({
    required String targetUid,
    required String targetUsername,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null || targetUid.isEmpty || user.uid == targetUid) {
      return;
    }

    final DocumentSnapshot<Map<String, dynamic>> currentUserProfile =
        await _firestore.collection('users').doc(user.uid).get();
    final DocumentSnapshot<Map<String, dynamic>> targetProfile =
        await _firestore.collection('users').doc(targetUid).get();
    final String currentUsername =
        currentUserProfile.data()?['username']?.toString() ??
        user.displayName ??
        user.email?.split('@').first ??
        'user';
    final bool targetIsPrivate = targetProfile.data()?['isPrivate'] == true;

    if (targetIsPrivate) {
      await _followRequestRef(targetUid).doc(user.uid).set(<String, dynamic>{
        'uid': user.uid,
        'username': currentUsername,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      }, SetOptions(merge: true));
      return;
    }

    final WriteBatch batch = _firestore.batch();
    final DocumentReference<Map<String, dynamic>> followingDoc = _followingRef(
      user.uid,
    ).doc(targetUid);
    final DocumentReference<Map<String, dynamic>> followerDoc = _followersRef(
      targetUid,
    ).doc(user.uid);

    batch.set(followingDoc, <String, dynamic>{
      'uid': targetUid,
      'username': targetUsername,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(followerDoc, <String, dynamic>{
      'uid': user.uid,
      'username': currentUsername,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
    await TelemetryService.instance.logFollowUser();
  }

  Future<void> unfollowUser(String targetUid) async {
    final User? user = _auth.currentUser;
    if (user == null || targetUid.isEmpty || user.uid == targetUid) {
      return;
    }

    final WriteBatch batch = _firestore.batch();
    batch.delete(_followingRef(user.uid).doc(targetUid));
    batch.delete(_followersRef(targetUid).doc(user.uid));
    await batch.commit();
  }

  Future<void> respondToFollowRequest({
    required String requesterUid,
    required bool accept,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null || requesterUid.isEmpty || requesterUid == user.uid) {
      return;
    }

    final DocumentReference<Map<String, dynamic>> requestRef =
        _followRequestRef(user.uid).doc(requesterUid);
    final DocumentSnapshot<Map<String, dynamic>> requestDoc = await requestRef
        .get();
    if (!requestDoc.exists) {
      return;
    }

    if (!accept) {
      await requestRef.delete();
      return;
    }

    final DocumentSnapshot<Map<String, dynamic>> currentUserProfile =
        await _firestore.collection('users').doc(user.uid).get();
    final DocumentSnapshot<Map<String, dynamic>> requesterProfile =
        await _firestore.collection('users').doc(requesterUid).get();

    final String currentUsername =
        currentUserProfile.data()?['username']?.toString() ??
        user.displayName ??
        user.email?.split('@').first ??
        'user';
    final String requesterUsername =
        requesterProfile.data()?['username']?.toString() ?? 'user';

    final WriteBatch batch = _firestore.batch();
    batch.set(_followingRef(requesterUid).doc(user.uid), <String, dynamic>{
      'uid': user.uid,
      'username': currentUsername,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(_followersRef(user.uid).doc(requesterUid), <String, dynamic>{
      'uid': requesterUid,
      'username': requesterUsername,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.delete(requestRef);
    await batch.commit();
  }

  Future<void> toggleSavePost({
    required String postId,
    required String postOwnerUid,
    required String caption,
    String? imageUrl,
    Timestamp? timestamp,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null || postId.isEmpty) {
      return;
    }

    final DocumentReference<Map<String, dynamic>> docRef = _savedPostsRef(
      user.uid,
    ).doc(postId);
    final DocumentSnapshot<Map<String, dynamic>> existing = await docRef.get();

    if (existing.exists) {
      await docRef.delete();
      return;
    }

    await docRef.set(<String, dynamic>{
      'postId': postId,
      'postOwnerUid': postOwnerUid,
      'caption': caption,
      'imageUrl': imageUrl?.trim() ?? '',
      'postTimestamp': timestamp,
      'savedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
