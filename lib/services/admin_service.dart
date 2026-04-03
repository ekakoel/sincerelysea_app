import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminService {
  AdminService();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<bool> isCurrentUserAdmin() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return false;
    }
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();
    return snapshot.data()?['role']?.toString().trim().toLowerCase() == 'admin';
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> usersStream() {
    return _firestore
        .collection('users')
        .orderBy('usernameLower')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> roleAuditLogsStream() {
    return _firestore
        .collection('admin_audit_logs')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots();
  }

  Future<void> updateUserRole({
    required String userId,
    required String role,
  }) async {
    final String normalizedRole = role.trim().toLowerCase();
    if (!<String>{'user', 'admin'}.contains(normalizedRole)) {
      throw ArgumentError.value(role, 'role', 'Unsupported role.');
    }
    if (!await isCurrentUserAdmin()) {
      throw Exception('Only admin accounts can manage roles.');
    }
    final User? actor = _auth.currentUser;
    if (actor == null) {
      throw Exception('User not authenticated.');
    }

    final DocumentSnapshot<Map<String, dynamic>> actorSnapshot = await _firestore
        .collection('users')
        .doc(actor.uid)
        .get();
    final DocumentSnapshot<Map<String, dynamic>> targetSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .get();
    if (!targetSnapshot.exists) {
      throw Exception('Target user not found.');
    }

    final Map<String, dynamic> actorData =
        actorSnapshot.data() ?? <String, dynamic>{};
    final Map<String, dynamic> targetData =
        targetSnapshot.data() ?? <String, dynamic>{};
    final String previousRole =
        targetData['role']?.toString().trim().toLowerCase() == 'admin'
        ? 'admin'
        : 'user';
    if (previousRole == normalizedRole) {
      return;
    }

    final WriteBatch batch = _firestore.batch();
    final DocumentReference<Map<String, dynamic>> userRef = _firestore
        .collection('users')
        .doc(userId);
    final DocumentReference<Map<String, dynamic>> logRef = _firestore
        .collection('admin_audit_logs')
        .doc();

    batch.set(userRef, {
      'role': normalizedRole,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(logRef, {
      'action': 'role_updated',
      'actorUid': actor.uid,
      'actorUsername': actorData['username']?.toString() ?? '',
      'actorDisplayName': actorData['displayName']?.toString() ?? '',
      'targetUid': userId,
      'targetUsername': targetData['username']?.toString() ?? '',
      'targetDisplayName': targetData['displayName']?.toString() ?? '',
      'previousRole': previousRole,
      'newRole': normalizedRole,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }
}
