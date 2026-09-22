import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

String _customerSurface() => <String>[
  _read('lib/screens/main_navigation_screen.dart'),
  _read('lib/screens/profile/profile_settings_menu_screen.dart'),
  _read('lib/screens/notifications/notifications_screen.dart'),
].join('\n');

void main() {
  group('MOB-03 customer feature completeness', () {
    test('authentication and onboarding routes are reachable', () {
      final String main = _read('lib/main.dart');
      final String splash = _read('lib/screens/splash/splash_redirect.dart');
      final String auth = _read('lib/screens/auth/auth_wrapper.dart');
      final String login = _read('lib/screens/auth/login_screen.dart');
      final String register = _read('lib/screens/auth/register_screen.dart');

      expect(main, contains('home: const SplashRedirect()'));
      expect(splash, contains('const OnboardingScreen()'));
      expect(splash, contains('const AuthWrapper()'));
      expect(auth, contains('const EmailVerificationScreen()'));
      expect(auth, contains('const MainNavigationScreen()'));
      expect(login, contains('const ForgotPasswordScreen()'));
      expect(login, contains('const RegisterPage()'));
      expect(login, contains('signInWithGoogle()'));
      expect(register, contains('TermsOfServiceScreen'));
      expect(register, contains('PrivacyPolicyScreen'));
      expect(login, isNot(contains('not available yet')));
      expect(login, isNot(contains('SHA-1/SHA-256')));
    });

    test('registration writes split profiles without authority fields', () {
      final String authService = _read('lib/services/auth_service.dart');
      expect(authService, contains("collection('users_public')"));
      expect(authService, contains("collection('users_private')"));
      expect(authService, contains("collection('usernames')"));
      for (final String authority in <String>[
        "'admin':",
        "'developer':",
        "'adminScopes':",
        "'role': 'admin'",
      ]) {
        expect(authService, isNot(contains(authority)));
      }
    });

    test('community and social entry points remain active and post-only', () {
      final String navigation = _read(
        'lib/screens/main_navigation_screen.dart',
      );
      final String postService = _read('lib/services/post_service.dart');
      final String profile = _read(
        'lib/screens/profile/user_profile_preview_screen.dart',
      );
      final String home = _read('lib/screens/home/home_screen.dart');

      expect(navigation, contains('const HomeScreen()'));
      expect(navigation, contains('SharedPostDetailScreen'));
      expect(home, contains('CommentsSheet'));
      expect(postService, contains("'type': 'post'"));
      expect(postService, contains("'productId': null"));
      expect(postService, isNot(contains('String type =')));
      expect(profile, contains('followUser('));
      expect(profile, contains("value: 'report'"));
      expect(profile, contains("value: isBlocked ? 'unblock' : 'block'"));
    });

    test('store wishlist cart and product detail are reachable', () {
      final String navigation = _read(
        'lib/screens/main_navigation_screen.dart',
      );
      final String shop = _read(
        'lib/screens/product/product_catalog_screen.dart',
      );
      final String product = _read(
        'lib/screens/product/product_detail_screen.dart',
      );
      final String settings = _read(
        'lib/screens/profile/profile_settings_menu_screen.dart',
      );

      expect(navigation, contains('const ProductCatalogScreen()'));
      expect(shop, contains('ProductDetailScreen'));
      expect(shop, contains('SavedProductsScreen'));
      expect(product, contains('toggleProductWishlist'));
      expect(product, contains('addToCart'));
      expect(product, contains('CheckoutScreen.buyNow'));
      expect(settings, contains('const CartScreen()'));
    });

    test('cart checkout and cancellation preserve trusted authority', () {
      final String cart = _read('lib/screens/cart/cart_screen.dart');
      final String checkout = _read(
        'lib/screens/checkout/checkout_screen.dart',
      );
      final String orders = _read('lib/services/order_service.dart');
      final String detail = _read(
        'lib/screens/orders/order_detail_screen.dart',
      );

      expect(cart, contains('Product unavailable'));
      expect(cart, contains('checkoutEnabled'));
      expect(checkout, contains('currentProduct'));
      expect(checkout, contains('unavailableItems'));
      expect(checkout, contains('OrderDetailScreen'));
      expect(orders, contains("'createCustomerOrder'"));
      expect(orders, contains("'cancelCustomerOrder'"));
      expect(orders, isNot(contains('_ordersRef.add')));
      expect(detail, contains('getProductOnce'));
      expect(detail, contains('const CartScreen()'));
      expect(detail, isNot(contains('addOrderItemsToCart')));
    });

    test('product reviews use the completed customer review domain', () {
      final String product = _read(
        'lib/screens/product/product_detail_screen.dart',
      );
      expect(Directory('lib/screens/reviews').existsSync(), isTrue);
      expect(File('lib/services/review_service.dart').existsSync(), isTrue);
      expect(product, contains('Write a Review'));
      expect(product, contains('Edit Review'));
      expect(product, contains('Delete Review'));
    });

    test('notifications route only to customer destinations', () {
      final String notifications = _read(
        'lib/screens/notifications/notifications_screen.dart',
      );
      expect(notifications, contains('SharedPostDetailScreen'));
      expect(notifications, contains('ProductDetailScreen'));
      expect(notifications, contains('UserProfilePreviewScreen'));
      expect(notifications, contains('markAsRead'));
      for (final String forbidden in <String>[
        'AdminDashboard',
        'ManageProducts',
        'SellerOrders',
      ]) {
        expect(notifications, isNot(contains(forbidden)));
      }
    });

    test('profile settings and account lifecycle keep privacy boundaries', () {
      final String profile = _read(
        'lib/screens/profile/profile_settings_screen.dart',
      );
      final String lifecycle = _read(
        'lib/services/account_lifecycle_service.dart',
      );
      expect(profile, contains("'your-profile'"));
      expect(profile, isNot(contains('_emailPrefixLower')));
      expect(lifecycle, contains("collection('users_public')"));
      expect(lifecycle, contains("collection('users_private')"));
      expect(lifecycle, contains("'hardDeleteAccount'"));
      expect(lifecycle, isNot(contains('deleteMyAccountDataOnly')));
    });

    test('settings support and legal rows are working destinations', () {
      final String settings = _read(
        'lib/screens/profile/profile_settings_menu_screen.dart',
      );
      for (final String destination in <String>[
        'NotificationPreferencesScreen',
        'ContactSupportScreen',
        'TermsOfServiceScreen',
        'PrivacyPolicyScreen',
      ]) {
        expect(settings, contains(destination));
      }
      final String notificationSettings = _read(
        'lib/screens/settings/notification_preferences_screen.dart',
      );
      expect(notificationSettings, contains('requestNotificationPermission'));
      expect(notificationSettings, isNot(contains('notif_pref_')));
      expect(settings, isNot(contains('notif_pref_')));
    });

    test('customer errors are safe and management UI stays absent', () {
      final String errorHandler = _read(
        'lib/utils/auth_exception_handler.dart',
      );
      expect(errorHandler, isNot(contains("return 'Error: \$e'")));
      expect(errorHandler, isNot(contains("return e.message ??")));

      final String surface = _customerSurface();
      for (final String forbidden in <String>[
        'Admin Dashboard',
        'Developer Console',
        'Manage Products',
        'Seller Orders',
        'Role Management',
      ]) {
        expect(surface, isNot(contains(forbidden)));
      }
    });
  });
}
