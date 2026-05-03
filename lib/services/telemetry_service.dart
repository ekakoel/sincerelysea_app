import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class TelemetryService {
  TelemetryService._();

  static final TelemetryService instance = TelemetryService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  Future<void> logRegisterSuccess({required String method}) async {
    await _analytics.logEvent(
      name: 'register_success',
      parameters: <String, Object>{'method': method},
    );
  }

  Future<void> logPostCreated() async {
    await _analytics.logEvent(name: 'post_created');
  }

  Future<void> logFollowUser() async {
    await _analytics.logEvent(name: 'follow_user');
  }

  Future<void> logShopProductCreated({
    required String productId,
    required String category,
  }) async {
    await _analytics.logEvent(
      name: 'shop_product_created',
      parameters: <String, Object>{
        'product_id': productId,
        'category': category,
      },
    );
  }

  Future<void> logSharePost({
    required String method,
    String? postId,
  }) async {
    await _analytics.logEvent(
      name: 'share_post',
      parameters: <String, Object>{
        'share_method': method,
        if (postId != null && postId.isNotEmpty) 'post_id': postId,
      },
    );
  }

  Future<void> recordError(Object error, StackTrace stackTrace) async {
    await FirebaseCrashlytics.instance.recordError(
      error,
      stackTrace,
      fatal: false,
    );
  }
}
