import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/providers/app_state.dart';
import '../auth/auth_service.dart';

/// Change password, sign out and delete account, for patients and caregivers.
class AccountSettingsSection extends ConsumerWidget {
  const AccountSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final isEmailAccount = ref.read(sessionProvider.notifier).isEmailAccount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Account',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              if (isEmailAccount) ...[
                ListTile(
                  leading: const Icon(
                    Icons.lock_reset_rounded,
                    color: AppTheme.primaryColor,
                  ),
                  title: const Text(
                    'Change password',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () => _changePassword(context, ref),
                ),
                const Divider(height: 1),
              ],
              ListTile(
                leading: const Icon(
                  Icons.logout_rounded,
                  color: AppTheme.primaryColor,
                ),
                title: const Text(
                  'Sign out',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () async {
                  await ref.read(sessionProvider.notifier).signOut();
                  if (context.mounted) context.go('/login');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.delete_forever_rounded,
                  color: AppTheme.alertRed,
                ),
                title: const Text(
                  'Delete account',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.alertRed,
                  ),
                ),
                onTap: () => _deleteAccount(
                  context,
                  ref,
                  isPatient: session.canAccessPatient,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final formKey = GlobalKey<FormState>();
    final password = TextEditingController();
    final confirm = TextEditingController();
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('Change password'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: password,
                  obscureText: true,
                  enabled: !saving,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: const InputDecoration(labelText: 'New password'),
                  validator: (value) => (value ?? '').length < 8
                      ? 'Use at least 8 characters'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirm,
                  obscureText: true,
                  enabled: !saving,
                  decoration: const InputDecoration(
                    labelText: 'Confirm new password',
                  ),
                  validator: (value) =>
                      value != password.text ? 'Passwords do not match' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      setDialogState(() => saving = true);
                      try {
                        await ref
                            .read(sessionProvider.notifier)
                            .changePassword(password.text);
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Password changed')),
                          );
                        }
                      } catch (error) {
                        setDialogState(() => saving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(readableAuthError(error))),
                          );
                        }
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    password.dispose();
    confirm.dispose();
  }

  Future<void> _deleteAccount(
    BuildContext context,
    WidgetRef ref, {
    required bool isPatient,
  }) async {
    final confirmController = TextEditingController();
    var deleting = false;

    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: AppTheme.alertRed,
            size: 40,
          ),
          title: const Text('Delete your account?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPatient
                      ? 'This permanently deletes your account and all your '
                            'care information: profile and photo, '
                            'medicines and dose history, routines, location '
                            'history, safe zone, alerts and emergency '
                            'contacts. Your caregivers will no longer be '
                            'connected to you.'
                      : 'This permanently deletes your caregiver account '
                            'and photo, and disconnects you from your '
                            "patients. The patients' own information is "
                            'kept.',
                  style: const TextStyle(fontSize: 15, height: 1.4),
                ),
                const SizedBox(height: 12),
                const Text(
                  'This cannot be undone. Type DELETE to confirm.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmController,
                  enabled: !deleting,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(hintText: 'DELETE'),
                  onChanged: (_) => setDialogState(() {}),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: deleting
                  ? null
                  : () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.alertRed),
              onPressed: deleting || confirmController.text.trim() != 'DELETE'
                  ? null
                  : () async {
                      setDialogState(() => deleting = true);
                      try {
                        await ref
                            .read(sessionProvider.notifier)
                            .deleteAccount();
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop(true);
                        }
                      } catch (error) {
                        setDialogState(() => deleting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(readableAuthError(error))),
                          );
                        }
                      }
                    },
              child: deleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Delete forever'),
            ),
          ],
        ),
      ),
    );
    confirmController.dispose();
    if (deleted == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your account has been deleted.')),
      );
      context.go('/login');
    }
  }
}
