import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<bool> isCurrentUserAdmin({bool forceRefresh = false}) async {
    final Map<String, dynamic> claims = await _currentUserClaims(
      forceRefresh: forceRefresh,
    );
    return claims['admin'] == true || claims['developer'] == true;
  }

  Future<bool> isCurrentUserDeveloper({bool forceRefresh = false}) async {
    final Map<String, dynamic> claims = await _currentUserClaims(
      forceRefresh: forceRefresh,
    );
    return claims['developer'] == true;
  }

  String roleFromData(Map<String, dynamic>? data) {
    final String role =
        data?['role']?.toString().trim().toLowerCase() ?? 'user';
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
    final Map<String, dynamic> claims = await _currentUserClaims();
    if (claims['admin'] != true && claims['developer'] != true) {
      return const <String>[];
    }
    if (claims['developer'] == true) {
      return List<String>.from(supportedScopes);
    }
    final dynamic rawScopes = claims['adminScopes'];
    if (rawScopes is! List<dynamic> || rawScopes.isEmpty) {
      return List<String>.from(supportedScopes);
    }
    return rawScopes
        .map((dynamic scope) => scope.toString().trim().toLowerCase())
        .where((String scope) => supportedScopes.contains(scope))
        .toSet()
        .toList(growable: false);
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

  Future<Map<String, dynamic>> _currentUserClaims({
    bool forceRefresh = false,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return const <String, dynamic>{};
    }
    final IdTokenResult token = await user.getIdTokenResult(forceRefresh);
    return token.claims ?? const <String, dynamic>{};
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
    if (_auth.currentUser == null) {
      throw Exception('User not authenticated.');
    }
    final List<String> normalizedScopes = normalizedRole == 'user'
        ? const <String>[]
        : _normalizeScopes(adminScopes);
    if (normalizedRole == 'developer' &&
        normalizedScopes.length != supportedScopes.length) {
      throw Exception('Developer accounts must keep all admin scopes enabled.');
    }
    final HttpsCallable callable = _functions.httpsCallable(
      'setUserAdminAccess',
    );
    await callable.call<void>(<String, dynamic>{
      'userId': userId,
      'role': normalizedRole,
      'adminScopes': normalizedRole == 'developer'
          ? List<String>.from(supportedScopes)
          : normalizedScopes,
    });
  }

  List<String> _normalizeScopes(List<String> scopes) {
    final List<String> normalized = scopes
        .map((String scope) => scope.trim().toLowerCase())
        .where((String scope) => supportedScopes.contains(scope))
        .toSet()
        .toList(growable: false);
    return normalized.isEmpty ? List<String>.from(supportedScopes) : normalized;
  }

  Future<Map<String, dynamic>?> _getUserData(String userId) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .get();
    return snapshot.data();
  }
}
