import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/user_profile_service.dart';

class CompleteProfileScreen extends StatefulWidget {
  final String uid;
  final bool signingOut;
  final VoidCallback onSignOut;

  const CompleteProfileScreen({
    super.key,
    required this.uid,
    required this.signingOut,
    required this.onSignOut,
  });

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  final _profileService = UserProfileService();

  bool _saving = false;
  String? _error;

  bool get _busy => _saving || widget.signingOut;

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _profileService.createStudentProfile(
        uid: widget.uid,
        fullName: _nameController.text,
        studentNumber: _numberController.text,
      );

      // AuthGate watches the profile and opens the assigned dashboard.
    } on FirebaseException catch (error) {
      final message = switch (error.code) {
        'permission-denied' =>
          'Your profile could not be saved because access was denied. '
              'Contact the transport administrator.',
        'unavailable' || 'deadline-exceeded' =>
          'We could not confirm your profile was saved. '
              'Check your connection and try again.',
        'unauthenticated' =>
          'Your session has expired. Sign out and sign in again.',
        _ => 'Unable to save your profile. Please try again.',
      };

      if (mounted) {
        setState(() => _error = message);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Unable to save your profile. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('WSU Bus Transport'),
        actions: [
          TextButton(
            onPressed: _busy ? null : widget.onSignOut,
            child: Text(widget.signingOut ? 'Signing out...' : 'Sign out'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.person_outline, size: 56, color: colors.primary),
                    const SizedBox(height: 20),
                    Text(
                      'Complete your student profile',
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your login is ready. Add your details to access '
                      'the student portal.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _nameController,
                      readOnly: _busy,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        final name = value?.trim() ?? '';

                        if (name.isEmpty) {
                          return 'Enter your full name.';
                        }

                        if (name.length > 100) {
                          return 'Use no more than 100 characters.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _numberController,
                      readOnly: _busy,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Student number',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: (value) {
                        final number = value?.trim() ?? '';

                        if (number.isEmpty) {
                          return 'Enter your student number.';
                        }

                        if (number.length > 32) {
                          return 'Use no more than 32 characters.';
                        }

                        return null;
                      },
                      onFieldSubmitted: (_) => _save(),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Transport funding is verified separately. '
                      'Creating this profile does not activate a bus pass.',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Driver or manager? Contact the transport '
                      'administrator to have your staff profile assigned.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _save,
                      child: Text(
                        _saving ? 'Saving profile...' : 'Open student portal',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
