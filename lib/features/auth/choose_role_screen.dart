import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/models/models.dart';
import '../../core/providers/app_state.dart';
import 'auth_background.dart';
import 'auth_service.dart';

/// Shown once after a first Google sign-in, when the account has not chosen
/// whether it belongs to a patient or a caregiver.
class ChooseRoleScreen extends ConsumerStatefulWidget {
  const ChooseRoleScreen({super.key});

  @override
  ConsumerState<ChooseRoleScreen> createState() => _ChooseRoleScreenState();
}

class _ChooseRoleScreenState extends ConsumerState<ChooseRoleScreen> {
  late UserRole? _role = ref.read(pendingSignupRoleProvider);
  bool _isSaving = false;

  Future<void> _continue() async {
    final role = _role;
    if (role == null) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(sessionProvider.notifier).chooseRole(role);
      ref.read(pendingSignupRoleProvider.notifier).state = null;
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(readableAuthError(error))));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _useAnotherAccount() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(sessionProvider.notifier).signOut();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: AuthCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Who will use this account?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'This sets up the right screens for you. '
                        'It cannot be changed later.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 24),
                      _RoleOption(
                        icon: Icons.person_outline,
                        title: 'I am the patient',
                        description:
                            'See my medicines and routines, and call for help.',
                        selected: _role == UserRole.patient,
                        onTap: _isSaving
                            ? null
                            : () => setState(() => _role = UserRole.patient),
                      ),
                      const SizedBox(height: 12),
                      _RoleOption(
                        icon: Icons.favorite_outline,
                        title: 'I am a caregiver',
                        description:
                            'Look after someone, manage schedules, and get '
                            'their alerts.',
                        selected: _role == UserRole.caregiver,
                        onTap: _isSaving
                            ? null
                            : () => setState(() => _role = UserRole.caregiver),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _isSaving || _role == null
                            ? null
                            : _continue,
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Continue'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _isSaving ? null : _useAnotherAccount,
                        child: const Text('Use a different account'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppTheme.primaryContainer : AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? AppTheme.primaryColor : AppTheme.outlineColor,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 30, color: AppTheme.primaryColor),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
