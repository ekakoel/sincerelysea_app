import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sincerelysea/theme/app_colors.dart';
import 'package:sincerelysea/theme/app_semantic_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:sincerelysea/utils/username_text_input_formatter.dart';
import 'package:sincerelysea/utils/auth_exception_handler.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final AuthService _auth = AuthService();
  Timer? _usernameDebounce;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _usernameChecking = false;
  bool? _usernameAvailable;
  String? _usernameStatusText;
  int _usernameCheckRequestId = 0;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _usernameController.removeListener(_onUsernameChanged);
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    _usernameDebounce?.cancel();
    _usernameCheckRequestId++;
    final int currentRequestId = _usernameCheckRequestId;
    final String normalized = _auth.normalizeUsername(_usernameController.text);
    if (normalized.isEmpty) {
      setState(() {
        _usernameChecking = false;
        _usernameAvailable = null;
        _usernameStatusText = null;
      });
      return;
    }
    if (!_auth.isUsernameFormatValid(normalized)) {
      setState(() {
        _usernameChecking = false;
        _usernameAvailable = false;
        _usernameStatusText = 'Use 3-20 chars: a-z, 0-9, _';
      });
      return;
    }

    setState(() {
      _usernameChecking = true;
      _usernameAvailable = null;
      _usernameStatusText = 'Checking...';
    });
    _usernameDebounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final bool available = await _auth.isUsernameAvailable(normalized);
        if (!mounted) {
          return;
        }
        final String latestNormalized = _auth.normalizeUsername(
          _usernameController.text,
        );
        if (currentRequestId != _usernameCheckRequestId ||
            latestNormalized != normalized) {
          return;
        }
        setState(() {
          _usernameChecking = false;
          _usernameAvailable = available;
          _usernameStatusText = available
              ? 'Username available'
              : 'Username already in use';
        });
      } catch (_) {
        if (!mounted) {
          return;
        }
        if (currentRequestId != _usernameCheckRequestId) {
          return;
        }
        setState(() {
          _usernameChecking = false;
          _usernameAvailable = false;
          _usernameStatusText = 'Failed to check username';
        });
      }
    });
  }

  Future<bool> _ensureUsernameAvailableForSubmit() async {
    final String normalized = _auth.normalizeUsername(_usernameController.text);
    if (!_auth.isUsernameFormatValid(normalized)) {
      setState(() {
        _usernameAvailable = false;
        _usernameStatusText = 'Use 3-20 chars: a-z, 0-9, _';
      });
      return false;
    }
    setState(() => _usernameChecking = true);
    final bool available = await _auth.isUsernameAvailable(normalized);
    if (!mounted) {
      return false;
    }
    setState(() {
      _usernameChecking = false;
      _usernameAvailable = available;
      _usernameStatusText = available
          ? 'Username available'
          : 'Username already in use';
    });
    return available;
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_usernameChecking) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for username check')),
      );
      return;
    }
    if (!await _ensureUsernameAvailableForSubmit()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please use another username')),
        );
      }
      return;
    }

    setState(() => _loading = true);
    try {
      // 1. Create User
      final user = await _auth.signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        username: _usernameController.text.trim(),
      );

      if (user != null) {
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Verification Sent'),
              content: Text(
                'We have sent a verification link to ${_emailController.text.trim()}.\n\nPlease check your email and click the link to activate your account before logging in.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          if (!mounted) {
            return;
          }
          _goToLogin();
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = AuthExceptionHandler.handleException(e);
      if (e.code == 'username-already-in-use') {
        message = 'Username already in use.';
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signUpWithGoogle() async {
    setState(() => _loading = true);
    try {
      final UserCredential? credential = await _auth.signInWithGoogle();
      if (credential == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google sign-up cancelled')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Google sign-up failed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goToLogin() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final AppSemanticColors semantic = context.semanticColors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: AppColors.transparent,
        foregroundColor: isDark ? AppColors.white : AppColors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Join SincerelySea',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start your journey with us',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.gray600),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _usernameController,
                    textInputAction: TextInputAction.next,
                    inputFormatters: <TextInputFormatter>[
                      LengthLimitingTextInputFormatter(20),
                      UsernameTextInputFormatter(),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Username',
                      prefixIcon: const Icon(Icons.alternate_email),
                      suffixIcon: _usernameChecking
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : _usernameAvailable == true
                          ? const Icon(
                              Icons.check_circle,
                              color: AppColors.black,
                            )
                          : _usernameAvailable == false
                          ? const Icon(Icons.cancel, color: AppColors.gray500)
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      helperText:
                          _usernameStatusText ?? '3-20 chars: a-z, 0-9, _',
                      helperStyle: TextStyle(
                        color: _usernameAvailable == true
                            ? AppColors.black
                            : _usernameAvailable == false
                            ? AppColors.gray500
                            : AppColors.gray600,
                      ),
                    ),
                    validator: (String? value) {
                      final String username = value?.trim().toLowerCase() ?? '';
                      if (username.isEmpty) {
                        return 'Please enter username';
                      }
                      if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(username)) {
                        return 'Use 3-20 chars: a-z, 0-9, _';
                      }
                      if (_usernameChecking) {
                        return 'Checking username availability...';
                      }
                      if (_usernameAvailable == false) {
                        return 'Username already in use';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => setState(
                          () => _obscureConfirmPassword =
                              !_obscureConfirmPassword,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (_loading || _usernameChecking)
                          ? null
                          : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.black,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: AppColors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Register',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: <Widget>[
                      Expanded(child: Divider(color: semantic.divider)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('OR'),
                      ),
                      Expanded(child: Divider(color: semantic.divider)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _signUpWithGoogle,
                      icon: const Icon(Icons.g_mobiledata, size: 24),
                      label: const Text('Continue with Google'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Already have an account?'),
                      TextButton(
                        onPressed: _goToLogin,
                        child: const Text('Login'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
