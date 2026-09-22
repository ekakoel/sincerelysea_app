import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('SEC-04 privacy and legal/support alignment', () {
    test('public and private profile boundaries are explicit', () {
      final String rules = _read('firestore.rules');
      final String profiles = _read('lib/services/user_profile_service.dart');
      final String checkout = _read(
        'lib/screens/checkout/checkout_screen.dart',
      );

      expect(rules, contains('match /users_public/{uid}'));
      expect(rules, contains('match /users_private/{uid}'));
      expect(rules, contains('allow read: if isOwner(uid);'));
      expect(profiles, contains("collection('users_public')"));
      expect(checkout, contains("collection('users_private')"));
    });

    test('registration and settings resolve canonical legal/support pages', () {
      final String registration = _read(
        'lib/screens/auth/register_screen.dart',
      );
      final String settings = _read(
        'lib/screens/profile/profile_settings_menu_screen.dart',
      );

      for (final String screen in <String>[
        'TermsOfServiceScreen',
        'PrivacyPolicyScreen',
      ]) {
        expect(registration, contains(screen));
        expect(settings, contains(screen));
      }
      expect(settings, contains('ContactSupportScreen'));
      expect(registration, contains('Terms & Conditions'));
      expect(registration, contains('Privacy Policy'));
    });

    test('legal pages use one metadata source and required sections', () {
      final String terms = _read(
        'lib/screens/legal/terms_of_service_screen.dart',
      );
      final String privacy = _read(
        'lib/screens/legal/privacy_policy_screen.dart',
      );
      final String metadata = _read('lib/config/legal_content.dart');

      expect(terms, contains('LegalContent.termsVersion'));
      expect(privacy, contains('LegalContent.privacyVersion'));
      expect(metadata, contains("officialStoreName = 'SincerelySea Store'"));
      for (final String heading in <String>[
        'Orders and Checkout',
        'Pricing and Availability',
        'Order Cancellation',
        'Content Reporting and Moderation',
        'Support and Contact',
      ]) {
        expect(terms, contains(heading));
      }
      for (final String heading in <String>[
        'Account Information',
        'Public and Community Information',
        'Commerce and Support Information',
        'Account Deletion',
        'Privacy and Data Requests',
      ]) {
        expect(privacy, contains(heading));
      }
    });

    test(
      'active legal/support copy has no obsolete mobile management claims',
      () {
        final String activeContent = <String>[
          _read('lib/screens/legal/terms_of_service_screen.dart'),
          _read('lib/screens/legal/privacy_policy_screen.dart'),
          _read('lib/screens/support/contact_support_screen.dart'),
        ].join('\n').toLowerCase();

        for (final String forbidden in <String>[
          'seller',
          'multi-seller',
          'admin dashboard',
          'manage products',
          'manage orders',
          'sales reports',
          'developer console',
          'mobile management',
          'payment/billing',
          'firestore write',
          '24-48 hours',
        ]) {
          expect(activeContent, isNot(contains(forbidden)));
        }
      },
    );
  });
}
