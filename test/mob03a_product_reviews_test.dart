import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('MOB-03A product reviews', () {
    test('Product Detail exposes complete review states and actions', () {
      final String detail = _read(
        'lib/screens/product/product_detail_screen.dart',
      );

      expect(detail, contains('Reviews'));
      expect(detail, contains('No reviews yet'));
      expect(detail, contains('Reviews are unavailable'));
      expect(detail, contains('Retry'));
      expect(detail, contains('Write a Review'));
      expect(detail, contains('Edit Review'));
      expect(detail, contains('Delete Review'));
      expect(detail, contains('ReviewEditorScreen'));
    });

    test('review service uses deterministic ownership and public identity', () {
      final String service = _read('lib/services/review_service.dart');

      expect(service, contains('reviews'));
      expect(service, contains('doc(user.uid)'));
      expect(service, contains('users_public'));
      expect(service, contains('runTransaction'));
      expect(service, isNot(contains('users_private')));
      expect(service, isNot(contains('email')));
    });

    test('editor validates rating text and prevents duplicate submission', () {
      final String editor = _read(
        'lib/screens/reviews/review_editor_screen.dart',
      );
      final String service = _read('lib/services/review_service.dart');

      expect(editor, contains('List<Widget>.generate(5'));
      expect(editor, contains('ReviewService.maxReviewLength'));
      expect(editor, contains('value?.trim()'));
      expect(editor, contains('_submitting ? null : _submit'));
      expect(service, contains('rating < 1 || rating > 5'));
      expect(service, contains('existing.exists'));
    });

    test('review records contain no private identity or client aggregates', () {
      final String model = _read('lib/models/product_review.dart');
      final String service = _read('lib/services/review_service.dart');
      final String reviewDomain = <String>[
        model,
        service,
      ].join(String.fromCharCode(10));

      for (final String forbidden in <String>[
        'email',
        'phone',
        'address',
        'averageRating',
        'reviewCount',
        'ratingTotal',
      ]) {
        expect(reviewDomain, isNot(contains(forbidden)));
      }
      expect(model, contains('SincerelySea Member'));
    });

    test('review UI has no moderation media or verified purchase claims', () {
      final String editor = _read(
        'lib/screens/reviews/review_editor_screen.dart',
      );
      final String service = _read('lib/services/review_service.dart');
      final String reviewSurface = <String>[
        editor,
        service,
      ].join(String.fromCharCode(10));

      for (final String forbidden in <String>[
        'Approve Review',
        'Reject Review',
        'Moderate Review',
        'Verified Purchase',
        'FirebaseStorage',
        'ImagePicker',
      ]) {
        expect(reviewSurface, isNot(contains(forbidden)));
      }
    });
  });
}
