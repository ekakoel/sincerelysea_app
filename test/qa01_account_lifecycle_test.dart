import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sincerelysea/services/account_lifecycle_service.dart';

void main() {
  group('QA-01 account lifecycle', () {
    test('data export encodes Firestore values as portable JSON', () {
      final String json = AccountLifecycleService.encodeExportPayload(
        <String, dynamic>{
          'createdAt': Timestamp.fromDate(DateTime.utc(2026, 9, 22, 10, 30)),
          'location': const GeoPoint(-8.65, 115.22),
          'nested': <String, dynamic>{
            'updatedAt': Timestamp.fromMillisecondsSinceEpoch(0),
          },
        },
      );
      final Map<String, dynamic> decoded = jsonDecode(json);

      expect(decoded['createdAt'], '2026-09-22T10:30:00.000Z');
      expect(decoded['location'], <String, dynamic>{
        'latitude': -8.65,
        'longitude': 115.22,
      });
      expect(decoded['nested']['updatedAt'], '1970-01-01T00:00:00.000Z');
    });

    test('export and trusted deletion cover active customer data domains', () {
      final String lifecycle = FileContent.accountLifecycle;
      final String backend = FileContent.backend;

      for (final String collection in <String>[
        'collection(\'cart\')',
        'collection(\'saved_posts\')',
        'collection(\'collections\')',
        'collection(\'wishlists\')',
        'collection(\'support_tickets\')',
        'collectionGroup(\'reviews\')',
        'collection(\'orders\')',
        'collection(\'reports\')',
      ]) {
        expect(lifecycle, contains(collection));
      }
      for (final String cleanup in <String>[
        'collectionGroup(\'replies\')',
        'collectionGroup(\'reviews\')',
        'collectionGroup(\'follow_requests\')',
        r'users/${uid}/cart',
        r'users/${uid}/collections',
        r'users/${uid}/support_tickets',
        r'support_attachments/${uid}/',
      ]) {
        expect(backend, contains(cleanup));
      }
    });

    test('filtered collection-group queries declare deployable indexes', () {
      final Map<String, dynamic> config = jsonDecode(
        File('firestore.indexes.json').readAsStringSync(),
      );
      final List<dynamic> indexes = config['indexes'] as List<dynamic>;
      final List<dynamic> overrides = config['fieldOverrides'] as List<dynamic>;

      expect(
        indexes.whereType<Map<String, dynamic>>().any(
          (Map<String, dynamic> item) =>
              item['collectionGroup'] == 'wishlists' &&
              item['queryScope'] == 'COLLECTION_GROUP',
        ),
        isTrue,
      );
      final Set<String> indexedFields = overrides
          .whereType<Map<String, dynamic>>()
          .map(
            (Map<String, dynamic> item) =>
                '${item['collectionGroup']}.${item['fieldPath']}',
          )
          .toSet();
      expect(
        indexedFields,
        containsAll(<String>[
          'comments.uid',
          'replies.uid',
          'reviews.userId',
          'followers.uid',
          'following.uid',
          'follow_requests.uid',
        ]),
      );
    });
  });
}

class FileContent {
  static final String accountLifecycle = _read(
    'lib/services/account_lifecycle_service.dart',
  );
  static final String backend = _read('functions/src/index.js');

  static String _read(String path) {
    return File(path).readAsStringSync();
  }
}
