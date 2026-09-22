import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sincerelysea/services/social_post_query_service.dart';

class DiscoveryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SocialPostQueryService _socialQueries = SocialPostQueryService();

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
        .collection('users_public')
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

  Future<List<SocialPostDocument>> searchByHashtagPage(
    String hashtag, {
    int offset = 0,
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

    return _socialQueries.loadVisiblePosts(
      hashtag: normalized,
      offset: offset,
      limit: limit,
    );
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

    return searchByHashtagPage(normalized, limit: 30);
  }

  Future<List<SocialPostDocument>> searchByLocationPage(
    String locationQuery, {
    int offset = 0,
    int limit = 20,
  }) async {
    final String normalized = locationQuery.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw Exception('Location query cannot be empty');
    }

    return _socialQueries.loadVisiblePosts(
      locationKeyword: normalized,
      offset: offset,
      limit: limit,
    );
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> searchByLocation(
    String locationQuery,
  ) async {
    final String normalized = locationQuery.trim().toLowerCase();
    if (normalized.isEmpty) {
      return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    }

    return searchByLocationPage(normalized, limit: 30);
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  suggestedUsers() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('users_public')
        .orderBy('updatedAt', descending: true)
        .limit(12)
        .get();
    return snapshot.docs;
  }
}
