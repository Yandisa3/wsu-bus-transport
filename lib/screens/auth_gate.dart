import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'complete_profile_screen.dart';
import 'welcome_screen.dart';
import 'register_screen.dart';

import 'student_dashboard.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/user_profile_service.dart';
import 'login_screen.dart';
import 'driver_screen.dart';
import 'manager_screen.dart';

enum AuthPage { welcome, login, register }

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _authService = AuthService();
  late final Stream<User?> _authChanges;

  bool _signingOut = false;
  UserRole? _requestedRole;
  AuthPage _currentPage = AuthPage.welcome;

  @override
  void initState() {
    super.initState();
    _authChanges = _authService.authStateChanges;
  }

  Future<void> _signOut() async {
    if (_signingOut) return;

    setState(() => _signingOut = true);

    try {
      await _authService.signOut();

      if (mounted) {
        setState(() {
          _requestedRole = null;
          _currentPage = AuthPage.welcome;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to sign out. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _signingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authChanges,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Unable to check your sign-in. Please restart the app.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          switch (_currentPage) {
            case AuthPage.login:
              return LoginScreen(
                onRoleSelected: (role) {
                  setState(() => _requestedRole = role);
                },
              );

            case AuthPage.register:
              return RegisterScreen(
                onSignIn: () {
                  setState(() {
                    _requestedRole = null;
                    _currentPage = AuthPage.login;
                  });
                },
              );

            case AuthPage.welcome:
              return WelcomeScreen(
                onSignIn: () {
                  setState(() {
                    _requestedRole = null;
                    _currentPage = AuthPage.login;
                  });
                },
                onRegister: () {
                  setState(() {
                    _requestedRole = null;
                    _currentPage = AuthPage.register;
                  });
                },
              );
          }
        }

        return _ProfileGate(
          key: ValueKey(user.uid),
          uid: user.uid,
          requestedRole: _requestedRole,
          onUseAssignedRole: () => setState(() => _requestedRole = null),
          signingOut: _signingOut,
          onSignOut: _signOut,
        );
      },
    );
  }
}

class _ProfileGate extends StatefulWidget {
  final String uid;
  final UserRole? requestedRole;
  final VoidCallback onUseAssignedRole;
  final bool signingOut;
  final VoidCallback onSignOut;

  const _ProfileGate({
    super.key,
    required this.uid,
    required this.requestedRole,
    required this.onUseAssignedRole,
    required this.signingOut,
    required this.onSignOut,
  });

  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  final _profileService = UserProfileService();
  late Stream<UserProfile?> _profileChanges;

  @override
  void initState() {
    super.initState();
    _profileChanges = _profileService.watchProfile(widget.uid);
  }

  void _retry() {
    setState(() {
      _profileChanges = _profileService.watchProfile(widget.uid);
    });
  }

  Widget _status({
    required String title,
    required String message,
    IconData icon = Icons.info_outline,
    bool loading = false,
    bool retry = false,
    String? continueLabel,
  }) {
    return Scaffold(
      appBar: AppBar(title: const Text('WSU Bus Transport')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  const CircularProgressIndicator()
                else
                  Icon(
                    icon,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                if (retry) ...[
                  OutlinedButton(
                    onPressed: widget.signingOut ? null : _retry,
                    child: const Text('Try again'),
                  ),
                  const SizedBox(height: 12),
                ],
                if (continueLabel != null) ...[
                  OutlinedButton(
                    onPressed: widget.signingOut
                        ? null
                        : widget.onUseAssignedRole,
                    child: Text(continueLabel),
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  onPressed: widget.signingOut ? null : widget.onSignOut,
                  child: Text(
                    widget.signingOut ? 'Signing out...' : 'Sign out',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: _profileChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _status(
            title: 'Loading your profile',
            message: 'Checking your account details.',
            loading: true,
          );
        }

        if (snapshot.hasError) {
          final error = snapshot.error;
          String message =
              'Unable to load your profile. Check your connection '
              'and try again.';

          if (error is FirebaseException && error.code == 'permission-denied') {
            message =
                'Your account does not have permission to read this '
                'profile. Contact the transport administrator.';
          } else if (error is FormatException) {
            message =
                'Your profile contains missing or invalid information. '
                'Contact the transport administrator.';
          }

          return _status(
            title: 'Profile unavailable',
            message: message,
            icon: Icons.error_outline,
            retry: true,
          );
        }

        final profile = snapshot.data;

        if (profile == null) {
          return CompleteProfileScreen(
            key: ValueKey('complete-profile-${widget.uid}'),
            uid: widget.uid,
            signingOut: widget.signingOut,
            onSignOut: widget.onSignOut,
          );
        }

        if (!profile.isActive) {
          return _status(
            title: 'Account inactive',
            message:
                'Your transport access is inactive. '
                'Contact the transport administrator.',
            icon: Icons.lock_outline,
          );
        }
        if (widget.requestedRole != null &&
            widget.requestedRole != profile.role) {
          return _status(
            title: 'Use your assigned portal',
            message:
                'This account is registered as a ${profile.role.label}. '
                'Choosing another portal does not change your access.',
            continueLabel: 'Continue as ${profile.role.label}',
          );
        }

        return switch (profile.role) {
          UserRole.student => StudentDashboard(
            key: ValueKey('${profile.uid}-student'),
            profile: profile,
            signingOut: widget.signingOut,
            onSignOut: widget.onSignOut,
          ),
          UserRole.driver => DriverScreen(
            key: ValueKey('${profile.uid}-driver'),
            profile: profile,
            signingOut: widget.signingOut,
            onSignOut: widget.onSignOut,
          ),
          UserRole.manager => ManagerScreen(
            key: ValueKey('${profile.uid}-manager'),
            profile: profile,
            signingOut: widget.signingOut,
            onSignOut: widget.onSignOut,
          ),
        };
      },
    );
  }
}
