import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

class AppCheckHeaderService {
  AppCheckHeaderService._();

  static final AppCheckHeaderService instance = AppCheckHeaderService._();

  String? _token;
  DateTime? _expiresAt;
  bool _initialized = false;
  bool _disabled = false;
  Future<void>? _initializing;

  bool _isFirebaseStorageHttpUrl(String value) {
    final String url = value.trim();
    return url.startsWith('https://firebasestorage.googleapis.com/') ||
        url.startsWith('https://storage.googleapis.com/');
  }

  bool requiresHeaderFor(String imageUrl) {
    return _isFirebaseStorageHttpUrl(imageUrl);
  }

  static AndroidAppCheckProvider androidProviderFor({required bool isDebug}) {
    return isDebug
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider();
  }

  static AppleAppCheckProvider appleProviderFor({required bool isDebug}) {
    return isDebug
        ? const AppleDebugProvider()
        : const AppleAppAttestWithDeviceCheckFallbackProvider();
  }

  Future<void> initialize({bool? debugMode}) async {
    if (_initialized || _disabled) {
      return;
    }
    if (_initializing != null) {
      return _initializing!;
    }

    _initializing = _initializeInternal(isDebug: debugMode ?? kDebugMode);
    try {
      await _initializing!;
    } finally {
      _initializing = null;
    }
  }

  Future<void> _initializeInternal({required bool isDebug}) async {
    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: androidProviderFor(isDebug: isDebug),
        providerApple: appleProviderFor(isDebug: isDebug),
      );

      await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
      _initialized = true;
      await _refreshToken(force: true);
    } on FirebaseException catch (e) {
      if (isDebug && _isUnsupportedFirebaseAppCheckError(e)) {
        _disableService();
        debugPrint(
          'AppCheckHeaderService disabled: App Check provider unsupported on this platform/OS.',
        );
        return;
      }
      rethrow;
    }
  }

  Future<void> _refreshToken({bool force = false}) async {
    if (!_initialized || _disabled) {
      return;
    }

    final DateTime now = DateTime.now();
    if (!force &&
        _token != null &&
        _expiresAt != null &&
        now.isBefore(_expiresAt!)) {
      return;
    }

    String? token;
    try {
      token = await FirebaseAppCheck.instance.getToken(force);
    } on FirebaseException catch (e) {
      if (kDebugMode && _isUnsupportedFirebaseAppCheckError(e)) {
        _disableService();
        if (kDebugMode) {
          debugPrint(
            'AppCheckHeaderService disabled while fetching token: provider unsupported on this platform/OS.',
          );
        }
        return;
      }
      rethrow;
    }

    if (token == null || token.isEmpty) {
      _token = null;
      _expiresAt = null;
      return;
    }

    _token = token;
    _expiresAt = now.add(const Duration(minutes: 45));
  }

  Future<Map<String, String>> headersFor(String imageUrl) async {
    if (!_isFirebaseStorageHttpUrl(imageUrl) || _disabled) {
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

  bool _isUnsupportedFirebaseAppCheckError(FirebaseException e) {
    if (e.plugin != 'firebase_app_check') {
      return false;
    }
    return e.code == 'unsupported' || e.code == 'code-unsupported';
  }

  void _disableService() {
    _disabled = true;
    _initialized = false;
    _token = null;
    _expiresAt = null;
  }
}
