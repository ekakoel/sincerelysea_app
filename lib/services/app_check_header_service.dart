import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

class AppCheckHeaderService {
  AppCheckHeaderService._();

  static final AppCheckHeaderService instance = AppCheckHeaderService._();

  String? _token;
  DateTime? _expiresAt;
  bool _initialized = false;
  Future<void>? _initializing;

  bool _isFirebaseStorageHttpUrl(String value) {
    final String url = value.trim();
    return url.startsWith('https://firebasestorage.googleapis.com/') ||
        url.startsWith('https://storage.googleapis.com/');
  }

  bool requiresHeaderFor(String imageUrl) {
    return _isFirebaseStorageHttpUrl(imageUrl);
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    if (_initializing != null) {
      return _initializing!;
    }

    _initializing = _initializeInternal();
    try {
      await _initializing!;
    } finally {
      _initializing = null;
    }
  }

  Future<void> _initializeInternal() async {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );

    await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
    _initialized = true;
    await _refreshToken(force: true);
  }

  Future<void> _refreshToken({bool force = false}) async {
    if (!_initialized) {
      return;
    }

    final DateTime now = DateTime.now();
    if (!force &&
        _token != null &&
        _expiresAt != null &&
        now.isBefore(_expiresAt!)) {
      return;
    }

    final String? token = await FirebaseAppCheck.instance.getToken(force);
    if (token == null || token.isEmpty) {
      _token = null;
      _expiresAt = null;
      return;
    }

    _token = token;
    _expiresAt = now.add(const Duration(minutes: 45));
  }

  Future<Map<String, String>> headersFor(String imageUrl) async {
    if (!_isFirebaseStorageHttpUrl(imageUrl)) {
      return const <String, String>{};
    }

    try {
      if (!_initialized) {
        await initialize();
      }
      await _refreshToken();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AppCheckHeaderService headersFor error: $e');
      }
      return const <String, String>{};
    }

    final String? token = _token?.trim();
    if (token == null || token.isEmpty) {
      return const <String, String>{};
    }

    return <String, String>{'X-Firebase-AppCheck': token};
  }
}
