import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sincerelysea/screens/auth/email_verification_screen.dart';
import 'package:sincerelysea/screens/auth/login_screen.dart';
import 'package:sincerelysea/screens/main_navigation_screen.dart';
import 'package:sincerelysea/services/auth_service.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final User? firebaseUser = context.watch<User?>();
    final AuthService authService = context.read<AuthService>();

    if (firebaseUser != null) {
      final bool requiresEmailActivation =
          authService.usesPasswordProvider(firebaseUser) &&
          !firebaseUser.emailVerified;
      if (requiresEmailActivation) {
        return const EmailVerificationScreen();
      }
      return const MainNavigationScreen();
    }
    return const LoginScreen();
  }
}
