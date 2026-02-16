import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

class DeepLinkService extends ChangeNotifier {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;
  String? _pendingPostId;
  bool _started = false;

  String? get pendingPostId => _pendingPostId;

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;

    try {
      final Uri? initialUri = await _appLinks.getInitialLink();
      _handleUri(initialUri);
    } catch (_) {}

    _subscription = _appLinks.uriLinkStream.listen(
      (Uri uri) => _handleUri(uri),
      onError: (_) {},
    );
  }

  String? consumePendingPostId() {
    final String? postId = _pendingPostId;
    _pendingPostId = null;
    return postId;
  }

  void _handleUri(Uri? uri) {
    if (uri == null) {
      return;
    }
    final String? postId = _extractPostId(uri);
    if (postId == null || postId.isEmpty) {
      return;
    }
    _pendingPostId = postId;
    notifyListeners();
  }

  String? _extractPostId(Uri uri) {
    // https://sincerelysea.app/post/{postId}
    if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'post') {
      return uri.pathSegments[1];
    }
    // sincerelysea://post/{postId}
    if (uri.host == 'post' && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.first;
    }
    return null;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
