import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CommunityManagementService {
  CommunityManagementService();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<bool> canCurrentUserManageCommunity() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return false;
    }
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();
    final Map<String, dynamic> data = snapshot.data() ?? <String, dynamic>{};
    if (data['role']?.toString().trim().toLowerCase() != 'admin') {
      return false;
    }
    final List<dynamic>? scopes = data['adminScopes'] as List<dynamic>?;
    if (scopes == null || scopes.isEmpty) {
      return true;
    }
    return scopes.map((dynamic scope) => scope.toString()).contains('community');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> reportsStream({
    String status = 'all',
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('reports')
        .orderBy('createdAt', descending: true);
    if (status != 'all') {
      query = query.where('status', isEqualTo: status);
    }
    return query.snapshots();
  }

  Future<void> updateReportStatus({
    required String reportId,
    required String status,
    String note = '',
  }) async {
    if (!await canCurrentUserManageCommunity()) {
      throw Exception('Only community admins can update reports.');
    }
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated.');
    }
    await _firestore.collection('reports').doc(reportId).update(<String, dynamic>{
      'status': status.trim().toLowerCase(),
      'handledByUid': user.uid,
      'resolutionNote': note.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
