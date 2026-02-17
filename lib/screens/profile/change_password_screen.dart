import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sincerelysea/services/auth_service.dart';
import 'package:sincerelysea/utils/auth_exception_handler.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AuthService authService = context.read<AuthService>();
    final User? currentUser = FirebaseAuth.instance.currentUser;
    final bool supportsPasswordChange =
        currentUser != null && authService.usesPasswordProvider(currentUser);

    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: <Widget>[
            if (!supportsPasswordChange) ...<Widget>[
              const Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Your account is currently signed in with a social provider. '
                    'Set a password by using "Forgot password" from the login screen.',
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Form(
              key: _formKey,
              child: Column(
                children: <Widget>[
                  TextFormField(
                    controller: _currentPasswordController,
                    obscureText: _obscureCurrent,
                    enabled: supportsPasswordChange && !_isLoading,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Current password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: supportsPasswordChange && !_isLoading
                            ? () => setState(
                                  () => _obscureCurrent = !_obscureCurrent,
                                )
                            : null,
                        icon: Icon(
                          _obscureCurrent
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (String? value) {
                      if (!supportsPasswordChange) {
                        return null;
                      }
                      if (value == null || value.trim().isEmpty) {
                        return 'Current password is required.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: _obscureNew,
                    enabled: supportsPasswordChange && !_isLoading,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'New password',
                      prefixIcon: const Icon(Icons.lock_reset_outlined),
                      suffixIcon: IconButton(
                        onPressed: supportsPasswordChange && !_isLoading
                            ? () =>
                                  setState(() => _obscureNew = !_obscureNew)
                            : null,
                        icon: Icon(
                          _obscureNew
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (String? value) {
                      if (!supportsPasswordChange) {
                        return null;
                      }
                      final String pass = value?.trim() ?? '';
                      if (pass.isEmpty) {
                        return 'New password is required.';
                      }
                      if (pass.length < 8) {
                        return 'Use at least 8 characters.';
                      }
                      if (pass == _currentPasswordController.text.trim()) {
                        return 'New password must be different.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirm,
                    enabled: supportsPasswordChange && !_isLoading,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(supportsPasswordChange),
                    decoration: InputDecoration(
                      labelText: 'Confirm new password',
                      prefixIcon: const Icon(Icons.lock_person_outlined),
                      suffixIcon: IconButton(
                        onPressed: supportsPasswordChange && !_isLoading
                            ? () => setState(
                                  () => _obscureConfirm = !_obscureConfirm,
                                )
                            : null,
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (String? value) {
                      if (!supportsPasswordChange) {
                        return null;
                      }
                      if ((value ?? '').trim() !=
                          _newPasswordController.text.trim()) {
                        return 'Password confirmation does not match.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (!supportsPasswordChange || _isLoading)
                    ? null
                    : () => _submit(supportsPasswordChange),
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Update password'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(bool supportsPasswordChange) async {
    if (!supportsPasswordChange || _isLoading) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      final AuthService authService = context.read<AuthService>();
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await authService.reauthenticateForSensitiveAction(
        password: _currentPasswordController.text.trim(),
      );
      await user.updatePassword(_newPasswordController.text.trim());

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthExceptionHandler.handleException(e))),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
