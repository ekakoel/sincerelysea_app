class ShareConfig {
  const ShareConfig._();

  // Ganti dengan domain universal link milik aplikasi Anda.
  static const String postDeepLinkBase = 'https://sincerelysea.app/post';

  // Ganti dengan URL store yang benar saat production.
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.example.sincerelysea';
  static const String appStoreUrl = 'https://apps.apple.com/app/id0000000000';

  static String buildPostLink(String postId) {
    final String safePostId = Uri.encodeComponent(postId.trim());
    return '$postDeepLinkBase/$safePostId';
  }

  static String buildTrackablePostLink(
    String postId, {
    String source = 'app',
    String medium = 'share',
    String campaign = 'post_share',
  }) {
    final Uri base = Uri.parse(buildPostLink(postId));
    return base.replace(
      queryParameters: <String, String>{
        ...base.queryParameters,
        'utm_source': source,
        'utm_medium': medium,
        'utm_campaign': campaign,
      },
    ).toString();
  }
}
