import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:sincerelysea/theme/app_colors.dart';
import 'package:sincerelysea/theme/app_semantic_colors.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sincerelysea/l10n/app_localizations.dart';
import 'package:sincerelysea/services/account_lifecycle_service.dart';
import 'package:sincerelysea/services/auth_service.dart';
import 'package:sincerelysea/services/deep_link_service.dart';
import 'package:sincerelysea/services/discovery_service.dart';
import 'package:sincerelysea/services/follow_service.dart';
import 'package:sincerelysea/services/local_notification_service.dart';
import 'package:sincerelysea/services/moderation_service.dart';
import 'package:sincerelysea/services/notification_center_service.dart';
import 'package:sincerelysea/services/post_service.dart';
import 'package:sincerelysea/services/theme_service.dart';
import 'package:sincerelysea/services/user_profile_service.dart';
import 'package:sincerelysea/services/wishlist_service.dart';
import 'screens/splash/splash_redirect.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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
        ChangeNotifierProvider<DeepLinkService>(
          create: (_) => DeepLinkService()..start(),
        ),
        Provider<PostService>(create: (_) => PostService()),
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
