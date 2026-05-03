import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminService {
  AdminService();

  static const List<String> supportedRoles = <String>[
    'user',
    'admin',
    'developer',
  ];

  static const List<String> supportedScopes = <String>[
    'products',
    'orders',
    'finance',
    'community',
    'roles',
  ];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<bool> isCurrentUserAdmin() async {
    final Map<String, dynamic>? data = await _currentUserData();
    return isAdminData(data);
  }

  Future<bool> isCurrentUserDeveloper() async {
    final Map<String, dynamic>? data = await _currentUserData();
    return isDeveloperData(data);
  }

  String roleFromData(Map<String, dynamic>? data) {
    final String role = data?['role']?.toString().trim().toLowerCase() ?? 'user';
    return supportedRoles.contains(role) ? role : 'user';
  }

  bool isAdminData(Map<String, dynamic>? data) {
    final String role = roleFromData(data);
    return role == 'admin' || role == 'developer';
  }

  bool isDeveloperData(Map<String, dynamic>? data) {
    return roleFromData(data) == 'developer';
  }

  List<String> adminScopesFromData(Map<String, dynamic>? data) {
    if (isDeveloperData(data)) {
      return List<String>.from(supportedScopes);
    }
    final List<dynamic>? rawScopes = data?['adminScopes'] as List<dynamic>?;
    if (rawScopes == null || rawScopes.isEmpty) {
      return List<String>.from(supportedScopes);
    }
    final List<String> scopes = rawScopes
        .map((dynamic scope) => scope.toString().trim().toLowerCase())
        .where((String scope) => supportedScopes.contains(scope))
        .toSet()
        .toList(growable: false);
    return scopes.isEmpty ? List<String>.from(supportedScopes) : scopes;
  }

  Future<List<String>> currentUserScopes() async {
    final Map<String, dynamic>? data = await _currentUserData();
    if (!isAdminData(data)) {
      return const <String>[];
    }
    return adminScopesFromData(data);
  }

  Future<bool> hasCurrentUserScope(String scope) async {
    final String normalizedScope = scope.trim().toLowerCase();
    if (!supportedScopes.contains(normalizedScope)) {
      return false;
    }
    final List<String> scopes = await currentUserScopes();
    return scopes.contains(normalizedScope);
  }

  Future<bool> canCurrentUserManageAdminAccess() {
    return hasCurrentUserScope('roles');
  }

  Future<Map<String, dynamic>?> _currentUserData() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return null;
    }
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();
    return snapshot.data();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> usersStream() {
    return _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
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
    final Map<String, dynamic>? targetData = await _getUserData(userId);
    await updateUserAccess(
      userId: userId,
      role: role,
      adminScopes: role.trim().toLowerCase() == 'user'
          ? const <String>[]
          : role.trim().toLowerCase() == 'developer'
          ? List<String>.from(supportedScopes)
          : role.trim().toLowerCase() == 'admin'
          ? adminScopesFromData(targetData)
          : const <String>[],
    );
  }

  Future<void> updateUserAccess({
    required String userId,
    required String role,
    required List<String> adminScopes,
  }) async {
    final String normalizedRole = role.trim().toLowerCase();
    if (!supportedRoles.contains(normalizedRole)) {
      throw ArgumentError.value(role, 'role', 'Unsupported role.');
    }
    if (!await canCurrentUserManageAdminAccess()) {
      throw Exception('Only authorized admins can manage admin access.');
    }
    final User? actor = _auth.currentUser;
    if (actor == null) {
      throw Exception('User not authenticated.');
    }

    final DocumentSnapshot<Map<String, dynamic>> actorSnapshot =
        await _firestore.collection('users').doc(actor.uid).get();
    final DocumentSnapshot<Map<String, dynamic>> targetSnapshot =
        await _firestore.collection('users').doc(userId).get();
    if (!targetSnapshot.exists) {
      throw Exception('Target user not found.');
    }

    final Map<String, dynamic> actorData =
        actorSnapshot.data() ?? <String, dynamic>{};
    final Map<String, dynamic> targetData =
        targetSnapshot.data() ?? <String, dynamic>{};
    final String previousRole = roleFromData(targetData);
    final List<String> previousScopes = previousRole == 'user'
        ? const <String>[]
        : adminScopesFromData(targetData);
    final List<String> normalizedScopes = normalizedRole == 'user'
        ? const <String>[]
        : _normalizeScopes(adminScopes);
    if (normalizedRole == 'developer' &&
        normalizedScopes.length != supportedScopes.length) {
      throw Exception('Developer accounts must keep all admin scopes enabled.');
    }
    if (previousRole == normalizedRole &&
        _sameScopes(previousScopes, normalizedScopes)) {
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
      'adminScopes': normalizedRole == 'developer'
          ? List<String>.from(supportedScopes)
          : normalizedScopes,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(logRef, {
      'action': 'admin_access_updated',
      'actorUid': actor.uid,
      'actorUsername': actorData['username']?.toString() ?? '',
      'actorDisplayName': actorData['displayName']?.toString() ?? '',
      'targetUid': userId,
      'targetUsername': targetData['username']?.toString() ?? '',
      'targetDisplayName': targetData['displayName']?.toString() ?? '',
      'previousRole': previousRole,
      'newRole': normalizedRole,
      'previousScopes': previousScopes,
      'newScopes': normalizedRole == 'developer'
          ? List<String>.from(supportedScopes)
          : normalizedScopes,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  List<String> _normalizeScopes(List<String> scopes) {
    final List<String> normalized = scopes
        .map((String scope) => scope.trim().toLowerCase())
        .where((String scope) => supportedScopes.contains(scope))
        .toSet()
        .toList(growable: false);
    return normalized.isEmpty ? List<String>.from(supportedScopes) : normalized;
  }

  bool _sameScopes(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    final Set<String> first = a.toSet();
    final Set<String> second = b.toSet();
    return first.containsAll(second) && second.containsAll(first);
  }

  Future<Map<String, dynamic>?> _getUserData(String userId) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .get();
    return snapshot.data();
  }
}
