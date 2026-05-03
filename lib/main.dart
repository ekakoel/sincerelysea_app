import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:sincerelysea/theme/app_colors.dart';
import 'package:sincerelysea/theme/app_semantic_colors.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sincerelysea/l10n/app_localizations.dart';
import 'package:sincerelysea/services/account_lifecycle_service.dart';
import 'package:sincerelysea/services/admin_service.dart';
import 'package:sincerelysea/services/auth_service.dart';
import 'package:sincerelysea/services/deep_link_service.dart';
import 'package:sincerelysea/services/discovery_service.dart';
import 'package:sincerelysea/services/follow_service.dart';
import 'package:sincerelysea/services/local_notification_service.dart';
import 'package:sincerelysea/services/moderation_service.dart';
import 'package:sincerelysea/services/notification_center_service.dart';
import 'package:sincerelysea/services/post_service.dart';
import 'package:sincerelysea/services/product_service.dart';
import 'package:sincerelysea/services/support_service.dart';
import 'package:sincerelysea/services/app_check_header_service.dart';
import 'package:sincerelysea/services/sales_reporting_service.dart';
import 'package:sincerelysea/services/shop_settings_service.dart';
import 'package:sincerelysea/services/theme_service.dart';
import 'package:sincerelysea/services/user_profile_service.dart';
import 'package:sincerelysea/services/wishlist_service.dart';
import 'package:sincerelysea/services/cart_service.dart';
import 'package:sincerelysea/services/community_management_service.dart';
import 'package:sincerelysea/services/order_service.dart';
import 'screens/splash/splash_redirect.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:sincerelysea/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseApp firebaseApp;
  try {
    firebaseApp = await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on UnsupportedError {
    // Fallback for platforms that still use native config files.
    firebaseApp = await Firebase.initializeApp();
  }
  if (kDebugMode) {
    debugPrint(
      'Firebase initialized: projectId=${firebaseApp.options.projectId}, appId=${firebaseApp.options.appId}, platform=${defaultTargetPlatform.name}',
    );
  }
  try {
    await AppCheckHeaderService.instance.initialize();
  } catch (_) {
    // Keep app booting even when App Check can't initialize.
  }
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  await LocalNotificationService.instance.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<AdminService>(create: (_) => AdminService()),
        ChangeNotifierProvider<DeepLinkService>(
          create: (_) => DeepLinkService()..start(),
        ),
        Provider<PostService>(create: (_) => PostService()),
        Provider<ProductService>(create: (_) => ProductService()),
        Provider<CartService>(create: (_) => CartService()),
        Provider<CommunityManagementService>(
          create: (_) => CommunityManagementService(),
        ),
        Provider<OrderService>(create: (_) => OrderService()),
        Provider<SalesReportingService>(create: (_) => SalesReportingService()),
        Provider<ShopSettingsService>(create: (_) => ShopSettingsService()),
        Provider<SupportService>(create: (_) => SupportService()),
        Provider<FollowService>(create: (_) => FollowService()),
        Provider<UserProfileService>(create: (_) => UserProfileService()),
        Provider<WishlistService>(create: (_) => WishlistService()),
        Provider<ModerationService>(create: (_) => ModerationService()),
        Provider<NotificationCenterService>(
          create: (_) => NotificationCenterService(),
        ),
        Provider<DiscoveryService>(create: (_) => DiscoveryService()),
        Provider<AccountLifecycleService>(
          create: (_) => AccountLifecycleService(),
        ),
        ChangeNotifierProvider<ThemeService>(
          create: (_) => ThemeService()..loadThemeMode(),
        ),
        StreamProvider<User?>(
          create: (context) => context.read<AuthService>().user,
          initialData: null,
        ),
      ],
      child: Consumer<ThemeService>(
        builder:
            (BuildContext context, ThemeService themeService, Widget? child) {
              return MaterialApp(
                debugShowCheckedModeBanner: false,
                localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: const <Locale>[Locale('en')],
                locale: const Locale('en'),
                themeMode: themeService.themeMode,
                theme: _buildAppTheme(Brightness.light),
                darkTheme: _buildAppTheme(Brightness.dark),
                home: const SplashRedirect(),
              );
            },
      ),
    );
  }
}

ThemeData _buildAppTheme(Brightness brightness) {
  final bool isDark = brightness == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: isDark ? AppColors.black : AppColors.white,
    dividerTheme: DividerThemeData(
      color: isDark ? AppColors.gray700 : AppColors.gray200,
      thickness: 1,
    ),
    extensions: <ThemeExtension<dynamic>>[
      isDark ? AppSemanticColors.dark : AppSemanticColors.light,
    ],
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: isDark ? AppColors.white : AppColors.black,
      onPrimary: isDark ? AppColors.black : AppColors.white,
      secondary: isDark ? AppColors.gray300 : AppColors.gray700,
      onSecondary: isDark ? AppColors.black : AppColors.white,
      error: isDark ? AppColors.white : AppColors.black,
      onError: isDark ? AppColors.black : AppColors.white,
      surface: isDark ? AppColors.black : AppColors.white,
      onSurface: isDark ? AppColors.white : AppColors.black,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? AppColors.black : AppColors.white,
      foregroundColor: isDark ? AppColors.white : AppColors.black,
      surfaceTintColor: AppColors.transparent,
    ),
  );
}
