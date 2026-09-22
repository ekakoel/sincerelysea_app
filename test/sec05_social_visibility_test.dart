import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) =>
    File(path).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  group('SEC-05 social visibility boundary', () {
    test(
      'Rules use one post policy with symmetric blocks and parent gates',
      () {
        final String rules = _read('firestore.rules');

        expect(rules, contains('function canReadPostData(post)'));
        expect(
          rules,
          contains('function isBlockedBetween(firstUid, secondUid)'),
        );
        expect(rules, contains('function canCommentOnPost(postId)'));
        expect(
          rules,
          contains("post.get('visibility', 'legacy') == 'followers'"),
        );
        expect(rules, contains('allow read: if canReadPostById(postId);'));
      },
    );

    test('feed search map and profile share author-scoped queries', () {
      final String queryService = _read(
        'lib/services/social_post_query_service.dart',
      );
      final String posts = _read('lib/services/post_service.dart');
      final String discovery = _read('lib/services/discovery_service.dart');

      expect(queryService, contains("where('uid', isEqualTo: authorUid)"));
      expect(
        queryService,
        contains("where('visibility', isEqualTo: 'public')"),
      );
      expect(
        queryService,
        contains("where('visibility', isEqualTo: 'followers')"),
      );
      expect(queryService, contains("error.code != 'permission-denied'"));
      expect(posts, contains('_socialQueries.watchVisiblePosts'));
      expect(posts, contains('_socialQueries.watchAuthorPosts'));
      expect(discovery, contains('_socialQueries.loadVisiblePosts'));
    });

    test('block menu observes only the signed-in owner block record', () {
      final String moderation = _read('lib/services/moderation_service.dart');
      expect(
        moderation,
        contains("_userBlocksRef(\n      user.uid,\n    ).doc(uid)"),
      );
      expect(
        moderation,
        isNot(contains("_userBlocksRef(\n      uid,\n    ).doc(user.uid)")),
      );
    });
  });
}
