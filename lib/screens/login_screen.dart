import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'dart:async';

import '../services/auth_service.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  final ValueChanged<UserRole> onRoleSelected;
  const LoginScreen({super.key, required this.onRoleSelected});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _navy = AppColors.primary;
  static const _gold = AppColors.gold;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  final _authService = AuthService();

  UserRole _selectedRole = UserRole.student;
  bool _loading = false;
  bool _hidePassword = true;
  String? _error;

  Future<void> _signIn() async {
    if (_loading || !_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      widget.onRoleSelected(_selectedRole);
      await _authService.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } on FirebaseAuthException catch (error) {
      const messages = {
        'invalid-email': 'Enter a valid email address.',
        'invalid-credential': 'Incorrect email or password.',
        'wrong-password': 'Incorrect email or password.',
        'user-not-found': 'Incorrect email or password.',
        'user-disabled': 'This account has been disabled.',
        'too-many-requests': 'Too many attempts. Please try again later.',
        'network-request-failed': 'Check your internet connection.',
      };

      if (mounted) {
        setState(() {
          _error =
              messages[error.code] ?? 'Unable to sign in. Please try again.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Something went wrong. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        if (_error != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_loading) {
              _passwordFocus.requestFocus();
            }
          });
        }
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_loading) return;

    final email = _emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _error = 'Enter your email address above, then tap Forgot password.';
      });
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _error = null;
    });

    const confirmation =
        'If an account exists for this email, you will receive a '
        'password-reset link. Check your inbox and spam folder.';

    String message;

    try {
      await _authService
          .sendPasswordResetEmail(email: email)
          .timeout(const Duration(seconds: 25));

      message = confirmation;
    } on TimeoutException {
      message =
          'The request is taking longer than expected. '
          'An email may still arrive. Check your inbox and connection '
          'before trying again.';
    } on FirebaseAuthException catch (error) {
      debugPrint('Password reset Firebase code: ${error.code}');

      const messages = {
        'invalid-email': 'Please check your email address.',
        'too-many-requests':
            'Too many requests. Please wait before trying again.',
        'network-request-failed':
            'Unable to connect. Check your internet connection.',
        'operation-not-allowed':
            'Email/password authentication is not enabled for this project.',
      };

      message = error.code == 'user-not-found'
          ? confirmation
          : messages[error.code] ??
                'Unable to request a reset link. Error code: ${error.code}';
    } catch (error) {
      debugPrint('Password reset error type: ${error.runtimeType}');
      message = 'An unexpected error occurred. Please try again.';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Password reset'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Widget _brandMark() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: _gold,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.directions_bus_outlined, color: _navy, size: 28),
    );
  }

  Widget _branding({required bool compact}) {
    if (compact) {
      return Row(
        children: [
          _brandMark(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WSU Bus Transport',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  'Walter Sisulu University',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _brandMark(),
          const SizedBox(height: 56),
          const Text(
            'WSU Bus\nTransport',
            style: TextStyle(
              color: Colors.white,
              fontSize: 44,
              height: 1.12,
              letterSpacing: -1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          Container(width: 44, height: 4, color: _gold),
          const SizedBox(height: 24),
          const Text(
            'One place for students, drivers\n'
            'and transport managers.',
            style: TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 16,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 64),
          const Text(
            'Walter Sisulu University',
            style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration(String label, bool dark) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: dark ? const Color(0xFF334155) : const Color(0xFFD5DDE5),
      ),
    );

    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: dark ? const Color(0xFF172334) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: dark ? _gold : _navy, width: 2),
      ),
    );
  }

  Widget _loginForm(bool dark) {
    final colors = Theme.of(context).colorScheme;

    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sign in',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.8,
                color: dark ? Colors.white : _navy,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Enter the email and password linked to your account.',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 15,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Choose your portal',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: UserRole.values.map((role) {
                return ChoiceChip(
                  label: Text(role.label),
                  selected: _selectedRole == role,
                  onSelected: _loading
                      ? null
                      : (_) {
                          setState(() {
                            _selectedRole = role;
                            _error = null;
                          });
                        },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              'Use the role assigned to your account.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _emailController,
              readOnly: _loading,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              autocorrect: false,
              enableSuggestions: false,
              decoration: _decoration('Email address', dark),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty || !email.contains('@')) {
                  return 'Enter your email address.';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              readOnly: _loading,
              obscureText: _hidePassword,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              decoration: _decoration('Password', dark).copyWith(
                suffixIcon: IconButton(
                  tooltip: _hidePassword ? 'Show password' : 'Hide password',
                  onPressed: _loading
                      ? null
                      : () {
                          setState(() {
                            _hidePassword = !_hidePassword;
                          });
                        },
                  icon: Icon(
                    _hidePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 21,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Enter your password.';
                }
                return null;
              },
              onFieldSubmitted: (_) => _signIn(),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _loading ? null : _resetPassword,
                style: TextButton.styleFrom(
                  foregroundColor: dark ? _gold : _navy,
                  minimumSize: const Size(48, 48),
                ),
                child: const Text('Forgot password?'),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 20),
              Semantics(
                liveRegion: true,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: colors.onErrorContainer,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _loading ? null : _signIn,
              style: FilledButton.styleFrom(
                backgroundColor: dark ? _gold : _navy,
                foregroundColor: dark ? _navy : Colors.white,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _loading
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Please wait...'),
                      ],
                    )
                  : const Text(
                      'Sign in',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0B1220) : const Color(0xFFF5F7FA),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 860;
            final padding = wide ? 40.0 : 24.0;
            final availableHeight = constraints.maxHeight - padding * 2;

            return SingleChildScrollView(
              padding: EdgeInsets.all(padding),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: availableHeight > 0 ? availableHeight : 0,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: wide ? 1040 : 440),
                    child: wide
                        ? Row(
                            children: [
                              Expanded(child: _branding(compact: false)),
                              const SizedBox(width: 64),
                              Expanded(child: _loginForm(dark)),
                            ],
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _branding(compact: true),
                              const SizedBox(height: 48),
                              _loginForm(dark),
                            ],
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
