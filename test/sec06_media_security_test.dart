import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sincerelysea/config/media_upload_policy.dart';

void main() {
  group('SEC-06 Flutter media policy', () {
    test('supports only JPG PNG and WebP extensions', () {
      expect(MediaUploadPolicy.contentTypeForPath('photo.JPG'), 'image/jpeg');
      expect(MediaUploadPolicy.contentTypeForPath('photo.png'), 'image/png');
      expect(MediaUploadPolicy.contentTypeForPath('photo.webp'), 'image/webp');
      expect(
        () => MediaUploadPolicy.contentTypeForPath('payload.html'),
        throwsA(
          isA<MediaValidationException>().having(
            (MediaValidationException e) => e.code,
            'code',
            'unsupported-media',
          ),
        ),
      );
    });

    test('rejects images over the selected upload limit', () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'sincerelysea_sec06_',
      );
      final File image = File('${directory.path}/avatar.jpg');
      try {
        await image.writeAsBytes(<int>[1, 2]);
        await expectLater(
          MediaUploadPolicy.validateImage(
            image,
            maxBytes: 1,
            label: 'Profile image',
          ),
          throwsA(
            isA<MediaValidationException>().having(
              (MediaValidationException e) => e.code,
              'code',
              'file-too-large',
            ),
          ),
        );
      } finally {
        await directory.delete(recursive: true);
      }
    });
  });
}
