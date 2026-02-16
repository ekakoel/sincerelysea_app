import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sincerelysea/services/auth_service.dart';
import 'dart:async';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  static const int _resendCooldownSeconds = 30;
  bool _sending = false;
  bool _checking = false;
  int _resendRemaining = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startResendCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _resendRemaining = _resendCooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendRemaining <= 1) {
        timer.cancel();
        setState(() => _resendRemaining = 0);
        return;
      }
      setState(() => _resendRemaining -= 1);
    });
  }

  Future<void> _resendVerification() async {
    if (_sending || _resendRemaining > 0) {
      return;
    }
    setState(() => _sending = true);
    try {
      await context.read<AuthService>().sendCurrentUserVerificationEmail();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification email has been sent.')),
      );
      _startResendCooldown();
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }
      final String message = switch (e.code) {
        'too-many-requests' =>
          'Too many requests. Please wait a moment and try again.',
        _ => e.message ?? 'Failed to send verification email.',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send verification email.')),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _checkActivation() async {
    if (_checking) {
      return;
    }
    setState(() => _checking = true);
    try {
      final bool verified = await context
          .read<AuthService>()
          .reloadAndCheckEmailVerified();
      if (!mounted) {
        return;
      }
      if (!verified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your email is not verified yet. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = context.watch<User?>();
    final String email = user?.email ?? '-';
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activate Account'),
        actions: <Widget>[
          TextButton(
            onPressed: () => context.read<AuthService>().signOut(),
            child: const Text('Log out'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Icon(
                  Icons.mark_email_unread_outlined,
                  size: 72,
                  color: colors.primary,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Verify Your Email First',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  'We sent an activation link to:\n$email\n\nPlease verify your email before using the app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: colors.onSurface),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _checking ? null : _checkActivation,
                  child: _checking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('I Have Verified'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: (_sending || _resendRemaining > 0)
                      ? null
                      : _resendVerification,
                  child: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _resendRemaining > 0
                              ? 'Resend in ${_resendRemaining}s'
                              : 'Resend Verification Email',
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
