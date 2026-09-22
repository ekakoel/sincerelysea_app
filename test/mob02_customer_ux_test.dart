import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('MOB-02 customer navigation and UX', () {
    test('primary navigation is stable and returns to Home on back', () {
      final String source = _read('lib/screens/main_navigation_screen.dart');
      for (final String label in <String>[
        'Home',
        'Search',
        'Explore',
        'Shop',
        'Profile',
      ]) {
        expect(source, contains("label: '$label'"));
      }
      expect(source, contains('IndexedStack(index: _currentIndex'));
      expect(source, contains('bool _exploreInitialized = false'));
      expect(source, contains('if (!didPop && _currentIndex != 0)'));
      expect(source, contains('_selectTab(0)'));
      expect(source, isNot(contains("label: 'Create'")));
    });

    test('Create Post is prominent and remains community-only', () {
      final String home = _read('lib/screens/home/home_screen.dart');
      final String postService = _read('lib/services/post_service.dart');
      expect(home, contains('FloatingActionButton.extended'));
      expect(home, contains("label: const Text('Create post')"));
      expect(home, contains("tooltip: 'Create a community post'"));
      expect(postService, contains("'type': 'post'"));
      expect(postService, contains("'productId': null"));
      expect(postService, isNot(contains('String type =')));
    });

    test('settings group customer destinations without duplicate export', () {
      final String settings = _read(
        'lib/screens/profile/profile_settings_menu_screen.dart',
      );
      for (final String section in <String>[
        'Account',
        'Privacy & Security',
        'Notifications',
        'Shopping',
        'Support',
        'Legal',
        'Application',
      ]) {
        expect(settings, contains("title: '$section'"));
      }
      for (final String destination in <String>[
        'CartScreen',
        'OrderHistoryScreen',
        'SavedProductsScreen',
        'ContactSupportScreen',
        'TermsOfServiceScreen',
        'PrivacyPolicyScreen',
      ]) {
        expect(settings, contains(destination));
      }
      expect(settings, isNot(contains("title: 'Export Data'")));
      expect(settings, isNot(contains("title: 'Commerce'")));
      expect(settings, isNot(contains("title: 'Support & Legal'")));
    });

    test('primary screen names are customer-facing', () {
      expect(
        _read('lib/screens/discovery/discovery_screen.dart'),
        contains("title: const Text('Search')"),
      );
      expect(
        _read('lib/screens/map/map_posts_screen.dart'),
        contains("title: const Text('Explore')"),
      );
      expect(
        _read('lib/screens/product/product_catalog_screen.dart'),
        contains("title: const Text('SincerelySea Store')"),
      );
    });

    test('major customer screens use neutral reusable error states', () {
      final String customerScreens = <String>[
        'lib/screens/discovery/discovery_screen.dart',
        'lib/screens/home/home_screen.dart',
        'lib/screens/map/map_posts_screen.dart',
        'lib/screens/notifications/notifications_screen.dart',
        'lib/screens/orders/order_history_screen.dart',
        'lib/screens/product/product_catalog_screen.dart',
        'lib/screens/product/product_detail_screen.dart',
        'lib/screens/product/saved_products_screen.dart',
        'lib/screens/profile/profile_screen.dart',
        'lib/screens/support/contact_support_screen.dart',
      ].map(_read).join('\n');
      expect(customerScreens, contains('CustomerStateView'));
      expect(customerScreens, isNot(contains(r'${snapshot.error}')));
      expect(customerScreens, isNot(contains(r'${ticketSnapshot.error}')));
      expect(customerScreens, isNot(contains(r'${msgSnapshot.error}')));
    });

    test('support covers community, store, privacy, and deletion needs', () {
      final String support = _read(
        'lib/screens/support/contact_support_screen.dart',
      );
      for (final String category in <String>[
        "value: 'account'",
        "value: 'order'",
        "value: 'product'",
        "value: 'community'",
        "value: 'privacy'",
        "value: 'account_deletion'",
        "value: 'technical'",
      ]) {
        expect(support, contains(category));
      }
    });

    test('legacy management destinations remain absent', () {
      final String surface = <String>[
        _read('lib/screens/main_navigation_screen.dart'),
        _read('lib/screens/profile/profile_settings_menu_screen.dart'),
      ].join('\n');
      for (final String forbidden in <String>[
        'Admin Dashboard',
        'Developer Console',
        'Manage Products',
        'Store Orders',
        'Seller Orders',
        'Finance',
        'Role Management',
      ]) {
        expect(surface, isNot(contains(forbidden)));
      }
    });
  });
}
