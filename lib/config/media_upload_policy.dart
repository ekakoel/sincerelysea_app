import 'dart:io';

class MediaValidationException implements Exception {
  const MediaValidationException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => message;
}

class MediaUploadPolicy {
  const MediaUploadPolicy._();

  static const int profileMaxBytes = 5 * 1024 * 1024;
  static const int postMaxBytes = 10 * 1024 * 1024;
  static const int supportMaxBytes = 8 * 1024 * 1024;

  static const Set<String> supportedContentTypes = <String>{
    'image/jpeg',
    'image/png',
    'image/webp',
  };

  static String contentTypeForPath(String path) {
    final String lower = path.trim().toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    throw const MediaValidationException(
      code: 'unsupported-media',
      message: 'Unsupported image format. Use JPG, PNG, or WebP.',
    );
  }

  static String extensionForPath(String path) {
    final String contentType = contentTypeForPath(path);
    return switch (contentType) {
      'image/png' => '.png',
      'image/webp' => '.webp',
      _ => '.jpg',
    };
  }

  static Future<String> validateImage(
    File file, {
    required int maxBytes,
    required String label,
  }) async {
    if (!await file.exists()) {
      throw MediaValidationException(
        code: 'missing-media',
        message: '$label could not be found. Please choose it again.',
      );
    }
    final String contentType = contentTypeForPath(file.path);
    final int size = await file.length();
    if (size <= 0) {
      throw MediaValidationException(
        code: 'empty-media',
        message: '$label is empty. Please choose another image.',
      );
    }
    if (size > maxBytes) {
      final int maxMegabytes = maxBytes ~/ (1024 * 1024);
      throw MediaValidationException(
        code: 'file-too-large',
        message: '$label is too large. Maximum size is $maxMegabytes MB.',
      );
    }
    return contentType;
  }
}
