import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

typedef SocialPostDocument = QueryDocumentSnapshot<Map<String, dynamic>>;

/// Builds only author-scoped post queries that Firestore Rules can prove safe.
class SocialPostQueryService {
  SocialPostQueryService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<List<SocialPostDocument>> loadVisiblePosts({
    String? hashtag,
    String? locationKeyword,
    int offset = 0,
    int? limit,
  }) async {
    final List<String> authorIds = await _loadAuthorIds();
    final List<List<SocialPostDocument>> pages = await Future.wait(
      authorIds.map(_loadAuthorPosts),
    );
    final List<SocialPostDocument> posts = _filterSortAndDedupe(
      pages.expand((List<SocialPostDocument> page) => page),
      hashtag: hashtag,
      locationKeyword: locationKeyword,
    );
    if (offset >= posts.length) {
      return <SocialPostDocument>[];
    }
    final int end = limit == null
        ? posts.length
        : (offset + limit).clamp(offset, posts.length);
    return posts.sublist(offset, end);
  }

  Stream<List<SocialPostDocument>> watchVisiblePosts({
    String? hashtag,
    String? locationKeyword,
    int? limit,
  }) async* {
    final List<String> authorIds = await _loadAuthorIds();
    final List<Query<Map<String, dynamic>>> queries =
        <Query<Map<String, dynamic>>>[];
    for (final String authorId in authorIds) {
      queries.addAll(await _queriesForAuthor(authorId));
    }
    yield* _combineQueries(
      queries,
      hashtag: hashtag,
      locationKeyword: locationKeyword,
      limit: limit,
    );
  }

  Stream<List<SocialPostDocument>> watchAuthorPosts(String authorUid) async* {
    if (authorUid.isEmpty || _auth.currentUser == null) {
      yield <SocialPostDocument>[];
      return;
    }
    final List<Query<Map<String, dynamic>>> queries = await _queriesForAuthor(
      authorUid,
    );
    yield* _combineQueries(queries);
  }

  Future<List<String>> _loadAuthorIds() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return <String>[];
    }
    final QuerySnapshot<Map<String, dynamic>> profiles = await _firestore
        .collection('users_public')
        .get();
    final Set<String> ids = profiles.docs.map((doc) => doc.id).toSet();
    ids.add(user.uid);
    return ids.toList(growable: false);
  }

  Future<List<Query<Map<String, dynamic>>>> _queriesForAuthor(
    String authorUid,
  ) async {
    final User? user = _auth.currentUser;
    if (user == null || authorUid.isEmpty) {
      return <Query<Map<String, dynamic>>>[];
    }
    final Query<Map<String, dynamic>> authorPosts = _firestore
        .collection('posts')
        .where('uid', isEqualTo: authorUid);
    if (authorUid == user.uid) {
      return <Query<Map<String, dynamic>>>[authorPosts];
    }

    final List<Query<Map<String, dynamic>>> queries =
        <Query<Map<String, dynamic>>>[
          authorPosts.where('visibility', isEqualTo: 'public'),
          authorPosts.where('type', isEqualTo: 'product'),
        ];
    try {
      final DocumentSnapshot<Map<String, dynamic>> follower = await _firestore
          .collection('users')
          .doc(authorUid)
          .collection('followers')
          .doc(user.uid)
          .get();
      if (follower.exists) {
        queries.add(authorPosts.where('visibility', isEqualTo: 'followers'));
      }
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') {
        rethrow;
      }
    }
    return queries;
  }

  Future<List<SocialPostDocument>> _loadAuthorPosts(String authorUid) async {
    final List<Query<Map<String, dynamic>>> queries = await _queriesForAuthor(
      authorUid,
    );
    final List<SocialPostDocument> posts = <SocialPostDocument>[];
    for (final Query<Map<String, dynamic>> query in queries) {
      try {
        posts.addAll((await query.get()).docs);
      } on FirebaseException catch (error) {
        if (error.code != 'permission-denied') {
          rethrow;
        }
      }
    }
    return posts;
  }

  Stream<List<SocialPostDocument>> _combineQueries(
    List<Query<Map<String, dynamic>>> queries, {
    String? hashtag,
    String? locationKeyword,
    int? limit,
  }) {
    if (queries.isEmpty) {
      return Stream<List<SocialPostDocument>>.value(<SocialPostDocument>[]);
    }
    late final StreamController<List<SocialPostDocument>> controller;
    final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
    subscriptions = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    final Map<int, List<SocialPostDocument>> latest =
        <int, List<SocialPostDocument>>{};

    void emit() {
      final List<SocialPostDocument> posts = _filterSortAndDedupe(
        latest.values.expand((List<SocialPostDocument> page) => page),
        hashtag: hashtag,
        locationKeyword: locationKeyword,
      );
      controller.add(
        limit == null || posts.length <= limit
            ? posts
            : posts.take(limit).toList(growable: false),
      );
    }

    controller = StreamController<List<SocialPostDocument>>(
      onListen: () {
        for (int index = 0; index < queries.length; index++) {
          subscriptions.add(
            queries[index].snapshots().listen(
              (QuerySnapshot<Map<String, dynamic>> snapshot) {
                latest[index] = snapshot.docs;
                emit();
              },
              onError: (Object error) {
                latest[index] = <SocialPostDocument>[];
                emit();
              },
            ),
          );
        }
      },
      onCancel: () async {
        for (final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
            subscription
            in subscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }

  List<SocialPostDocument> _filterSortAndDedupe(
    Iterable<SocialPostDocument> documents, {
    String? hashtag,
    String? locationKeyword,
  }) {
    final String normalizedHashtag = hashtag == null || hashtag.trim().isEmpty
        ? ''
        : (hashtag.trim().startsWith('#')
              ? hashtag.trim().toLowerCase()
              : '#${hashtag.trim().toLowerCase()}');
    final String normalizedLocation =
        locationKeyword?.trim().toLowerCase() ?? '';
    final Map<String, SocialPostDocument> unique =
        <String, SocialPostDocument>{};
    for (final SocialPostDocument document in documents) {
      final Map<String, dynamic> data = document.data();
      final List<String> hashtags =
          (data['hashtags'] as List<dynamic>? ?? <dynamic>[])
              .map((dynamic value) => value.toString().toLowerCase())
              .toList(growable: false);
      final List<String> locations =
          (data['locationKeywords'] as List<dynamic>? ?? <dynamic>[])
              .map((dynamic value) => value.toString().toLowerCase())
              .toList(growable: false);
      if (normalizedHashtag.isNotEmpty &&
          !hashtags.contains(normalizedHashtag)) {
        continue;
      }
      if (normalizedLocation.isNotEmpty &&
          !locations.contains(normalizedLocation)) {
        continue;
      }
      unique[document.id] = document;
    }
    final List<SocialPostDocument> posts = unique.values.toList();
    posts.sort((SocialPostDocument first, SocialPostDocument second) {
      final Timestamp? firstTimestamp = first.data()['timestamp'] as Timestamp?;
      final Timestamp? secondTimestamp =
          second.data()['timestamp'] as Timestamp?;
      if (firstTimestamp == null && secondTimestamp == null) return 0;
      if (firstTimestamp == null) return 1;
      if (secondTimestamp == null) return -1;
      return secondTimestamp.compareTo(firstTimestamp);
    });
    return posts;
  }
}
