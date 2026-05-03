import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sincerelysea/services/admin_service.dart';

class CommunityManagementService {
  CommunityManagementService();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AdminService _adminService = AdminService();

  Future<bool> canCurrentUserManageCommunity() async {
    return _adminService.hasCurrentUserScope('community');
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
