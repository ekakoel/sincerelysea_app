import 'package:cloud_firestore/cloud_firestore.dart';

class DiscoveryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<QuerySnapshot<Map<String, dynamic>>> searchUsersPage(
    String query, {
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 20,
  }) async {
    final String normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw Exception('Query cannot be empty');
    }

    Query<Map<String, dynamic>> queryRef = _firestore
        .collection('users')
        .orderBy('usernameLower')
        .startAt(<String>[normalized])
        .endAt(<String>['$normalized\uf8ff'])
        .limit(limit);

    if (startAfter != null) {
      queryRef = queryRef.startAfterDocument(startAfter);
    }

    return queryRef.get();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> searchUsers(
    String query,
  ) async {
    final String normalized = query.trim();
    if (normalized.isEmpty) {
      return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    }
    final QuerySnapshot<Map<String, dynamic>> snapshot = await searchUsersPage(
      normalized,
      limit: 20,
    );
    return snapshot.docs;
  }

  Future<QuerySnapshot<Map<String, dynamic>>> searchByHashtagPage(
    String hashtag, {
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 20,
  }) async {
    final String normalized = hashtag.trim().isEmpty
        ? ''
        : (hashtag.trim().startsWith('#')
              ? hashtag.trim().toLowerCase()
              : '#${hashtag.trim().toLowerCase()}');
    if (normalized.isEmpty) {
      throw Exception('Hashtag query cannot be empty');
    }

    Query<Map<String, dynamic>> queryRef = _firestore
        .collection('posts')
        .where('hashtags', arrayContains: normalized)
        .limit(limit);

    if (startAfter != null) {
      queryRef = queryRef.startAfterDocument(startAfter);
    }
    return queryRef.get();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> searchByHashtag(
    String hashtag,
  ) async {
    final String normalized = hashtag.trim().isEmpty
        ? ''
        : (hashtag.trim().startsWith('#')
              ? hashtag.trim().toLowerCase()
              : '#${hashtag.trim().toLowerCase()}');
    if (normalized.isEmpty) {
      return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await searchByHashtagPage(normalized, limit: 30);
    return snapshot.docs;
  }

  Future<QuerySnapshot<Map<String, dynamic>>> searchByLocationPage(
    String locationQuery, {
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 20,
  }) async {
    final String normalized = locationQuery.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw Exception('Location query cannot be empty');
    }

    Query<Map<String, dynamic>> queryRef = _firestore
        .collection('posts')
        .where('locationKeywords', arrayContains: normalized)
        .limit(limit);

    if (startAfter != null) {
      queryRef = queryRef.startAfterDocument(startAfter);
    }
    return queryRef.get();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> searchByLocation(
    String locationQuery,
  ) async {
    final String normalized = locationQuery.trim().toLowerCase();
    if (normalized.isEmpty) {
      return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await searchByLocationPage(normalized, limit: 30);
    return snapshot.docs;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  suggestedUsers() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('users')
        .orderBy('updatedAt', descending: true)
        .limit(12)
        .get();
    return snapshot.docs;
  }
}
