import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

String _readDartTree(String root) => Directory(root)
    .listSync(recursive: true)
    .whereType<File>()
    .where((File file) => file.path.endsWith('.dart'))
    .map((File file) => file.readAsStringSync())
    .join('\n');

void main() {
  group('MOB-01 customer-only mobile surface', () {
    test('navigation is customer only', () {
      final String navigation = _read(
        'lib/screens/main_navigation_screen.dart',
      );
      for (final String label in <String>[
        'Home',
        'Search',
        'Explore',
        'Shop',
        'Profile',
      ]) {
        expect(navigation, contains('label: \'$label\''));
      }
      expect(navigation, isNot(contains('Admin Dashboard')));
    });

    test('settings expose customer destinations only', () {
      final String settings = _read(
        'lib/screens/profile/profile_settings_menu_screen.dart',
      );
      expect(settings, contains('title: \'My Orders\''));
      expect(settings, contains('title: \'Saved Products\''));
      for (final String forbidden in <String>[
        'Admin Dashboard',
        'Admin Access',
        'Manage Products',
        'Store Orders',
        'Seller Orders',
        'Community Reports',
        'Transaction Reports',
        'Sales Reports',
        'Journal Entries',
        'Developer Console',
      ]) {
        expect(settings, isNot(contains(forbidden)));
      }
    });

    test('admin and developer claims cannot enable management UI', () {
      final String customerSurface = <String>[
        _read('lib/main.dart'),
        _readDartTree('lib/screens'),
      ].join('\n');
      for (final String claimGate in <String>[
        'adminScopes',
        'isAdmin',
        'isDeveloper',
        'setUserAdminAccess',
      ]) {
        expect(customerSurface, isNot(contains(claimGate)));
      }
      for (final String removedPath in <String>[
        'lib/screens/admin/admin_dashboard_screen.dart',
        'lib/screens/admin/admin_user_roles_screen.dart',
        'lib/screens/admin/community_reports_screen.dart',
        'lib/screens/admin/developer_console_screen.dart',
        'lib/screens/admin/sales_reports_screen.dart',
        'lib/screens/orders/seller_orders_screen.dart',
        'lib/screens/product/manage_products_screen.dart',
      ]) {
        expect(File(removedPath).existsSync(), isFalse);
      }
    });

    test('post creation is community-only but product posts stay readable', () {
      final String postService = _read('lib/services/post_service.dart');
      final String home = _read('lib/screens/home/home_screen.dart');
      final String sharedDetail = _read(
        'lib/screens/post/shared_post_detail_screen.dart',
      );
      expect(postService, isNot(contains('String type =')));
      expect(postService, isNot(contains('String? productId')));
      expect(postService, contains('\'type\': \'post\''));
      expect(postService, contains('\'productId\': null'));
      expect(home, isNot(contains('type: \'product\'')));
      expect(home, contains('postType == \'product\''));
      expect(sharedDetail, contains('postType == \'product\''));
    });

    test('storefront is the single official store', () {
      final String officialStore = _read('lib/config/official_store.dart');
      final String storefront = _read(
        'lib/screens/product/official_store_screen.dart',
      );
      expect(officialStore, contains('id = \'sincerelysea\''));
      expect(officialStore, contains('name = \'SincerelySea Store\''));
      expect(storefront, contains('class OfficialStoreScreen'));
      expect(storefront, contains('getOfficialStoreProducts()'));
      expect(
        File('lib/screens/product/seller_storefront_screen.dart').existsSync(),
        isFalse,
      );
    });

    test('SEC-01 backend authority remains present', () {
      final String functions = _read('functions/src/index.js');
      final String rules = _read('firestore.rules');
      expect(functions, contains('exports.setUserAdminAccess'));
      expect(rules, contains('request.auth.token.get(\'admin\', false)'));
      expect(rules, contains('request.auth.token.get(\'developer\', false)'));
      expect(rules, contains('request.auth.token.adminScopes'));
      expect(rules, contains('match /admin_audit_logs/{logId}'));
    });
  });
}
