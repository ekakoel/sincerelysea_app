import 'package:flutter/material.dart';
import 'package:sincerelysea/theme/app_colors.dart';
import '../../utils/onboarding_helper.dart';
import '../onboarding/onboarding_screen.dart';
import '../auth/auth_wrapper.dart';

class SplashRedirect extends StatefulWidget {
  const SplashRedirect({super.key});

  @override
  State<SplashRedirect> createState() => _SplashRedirectState();
}

class _SplashRedirectState extends State<SplashRedirect> {
  @override
  void initState() {
    super.initState();
    checkFlow();
  }

  Future<void> checkFlow() async {
    final seen = await OnboardingHelper.hasSeenOnboarding();

    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    if (seen) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Image(image: AssetImage('assets/splash/logo-dark.png'), width: 150),
            SizedBox(height: 24),
            CircularProgressIndicator(strokeWidth: 2),
          ],
        ),
      ),
    );
  }
}
