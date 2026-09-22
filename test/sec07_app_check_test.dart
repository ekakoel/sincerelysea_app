import 'dart:io';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sincerelysea/services/app_check_header_service.dart';

String _read(String path) =>
    File(path).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  group('SEC-07 App Check readiness', () {
    test('debug and production providers are selected by build mode', () {
      expect(
        AppCheckHeaderService.androidProviderFor(isDebug: true),
        isA<AndroidDebugProvider>(),
      );
      expect(
        AppCheckHeaderService.androidProviderFor(isDebug: false),
        isA<AndroidPlayIntegrityProvider>(),
      );
      expect(
        AppCheckHeaderService.appleProviderFor(isDebug: true),
        isA<AppleDebugProvider>(),
      );
      expect(
        AppCheckHeaderService.appleProviderFor(isDebug: false),
        isA<AppleAppAttestWithDeviceCheckFallbackProvider>(),
      );
    });

    test('Firebase initializes before fail-closed release App Check', () {
      final String mainSource = _read('lib/main.dart');
      final int firebaseInit = mainSource.indexOf('Firebase.initializeApp(');
      final int appCheckInit = mainSource.indexOf(
        'AppCheckHeaderService.instance.initialize',
      );

      expect(firebaseInit, greaterThanOrEqualTo(0));
      expect(appCheckInit, greaterThan(firebaseInit));
      expect(mainSource, contains('if (kDebugMode)'));
      expect(mainSource, contains('initialize(debugMode: false)'));
      expect(
        mainSource,
        isNot(contains('Keep app booting even when App Check')),
      );
    });

    test('platform configuration contains no debug token', () {
      final String android = _read('android/app/build.gradle.kts');
      final String entitlements = _read('ios/Runner/Runner.entitlements');
      final String combined = '$android\n$entitlements'.toLowerCase();

      expect(combined, isNot(contains('firebase_app_check_debug_token')));
      expect(
        entitlements,
        contains('com.apple.developer.devicecheck.appattest-environment'),
      );
    });
  });
}
