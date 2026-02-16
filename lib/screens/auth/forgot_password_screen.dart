import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sincerelysea/l10n/app_localizations.dart';
import 'package:sincerelysea/services/auth_service.dart';
import 'package:sincerelysea/utils/auth_exception_handler.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  Timer? _timer;
  int _remainingTime = 0;
  static const int _cooldownDuration = 30;
  static const String _lastResetTimeKey = 'last_reset_time';
  bool _autoResend = false;

  @override
  void initState() {
    super.initState();
    _checkCooldown();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    final lastTime = prefs.getInt(_lastResetTimeKey);
    if (lastTime != null) {
      final lastDateTime = DateTime.fromMillisecondsSinceEpoch(lastTime);
      final diff = DateTime.now().difference(lastDateTime).inSeconds;
      if (diff < _cooldownDuration) {
        setState(() {
          _remainingTime = _cooldownDuration - diff;
        });
        _startTimer();
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime == 0) {
        setState(() {
          timer.cancel();
        });
        if (_autoResend && mounted) {
          _resetPassword();
        }
      } else {
        setState(() {
          _remainingTime--;
        });
      }
    });
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Memanggil method sendPasswordResetEmail dari AuthService
      await context.read<AuthService>().sendPasswordResetEmail(
        _emailController.text.trim(),
      );

      if (mounted) {
        final AppLocalizations l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.resetPasswordLinkSent)));
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
          _lastResetTimeKey,
          DateTime.now().millisecondsSinceEpoch,
        );
        setState(() => _remainingTime = _cooldownDuration);
        _startTimer();
      }
    } catch (e) {
      if (mounted) {
        final message = AuthExceptionHandler.handleException(e);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).forgotPasswordTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppLocalizations.of(context).forgotPasswordDescription,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return AppLocalizations.of(context).pleaseEnterEmail;
                  }
                  final emailRegex = RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                  );
                  if (!emailRegex.hasMatch(value)) {
                    return AppLocalizations.of(context).invalidEmailFormat;
                  }
                  return null;
                },
              ),
              CheckboxListTile(
                title: Text(
                  AppLocalizations.of(context).autoResendIfNotReceived,
                ),
                value: _autoResend,
                onChanged: (val) => setState(() => _autoResend = val ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: (_isLoading || _remainingTime > 0)
                    ? null
                    : _resetPassword,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _remainingTime > 0
                            ? AppLocalizations.of(
                                context,
                              ).resendButton(_remainingTime)
                            : AppLocalizations.of(context).sendResetLink,
                      ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context).backToLogin),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
