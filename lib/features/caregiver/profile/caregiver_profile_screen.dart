import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/app_state.dart';

enum _ContactAction { edit, delete }

class CaregiverProfileScreen extends ConsumerStatefulWidget {
  const CaregiverProfileScreen({super.key});

  @override
  ConsumerState<CaregiverProfileScreen> createState() =>
      _CaregiverProfileScreenState();
}

class _CaregiverProfileScreenState
    extends ConsumerState<CaregiverProfileScreen> {
  bool _pushNotifications = true;
  bool _smsAlerts = true;
  bool _soundAlerts = true;

  @override
  Widget build(BuildContext context) {
    final patient = ref.watch(patientProvider);
    final caregiver = ref.watch(currentCaregiverProvider);
    final emergencyContacts = ref.watch(emergencyContactsProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          children: [
            // Profile Header Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: AppTheme.primaryContainer,
                      child: Icon(
                        Icons.shield_rounded,
                        size: 36,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            caregiver.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            caregiver.email,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          if (caregiver.phone.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              caregiver.phone,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Linked Patient Info
            const Text(
              'Patient',
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
              child: ListTile(
                leading: const Icon(
                  Icons.badge_rounded,
                  color: AppTheme.primaryColor,
                ),
                title: Text(
                  patient.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Age: ${patient.age} • Status: ${patient.isDeviceOnline ? "Device Online" : "Offline"}',
                ),
                trailing: const Icon(
                  Icons.check_circle,
                  color: AppTheme.successGreen,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Notification & Escalation Rules
            const Text(
              'Notifications',
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
                  SwitchListTile(
                    value: _pushNotifications,
                    activeThumbColor: AppTheme.primaryColor,
                    title: const Text(
                      'Push notifications',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onChanged: (val) =>
                        setState(() => _pushNotifications = val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: _smsAlerts,
                    activeThumbColor: AppTheme.primaryColor,
                    title: const Text(
                      'Emergency SMS',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onChanged: (val) => setState(() => _smsAlerts = val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: _soundAlerts,
                    activeThumbColor: AppTheme.primaryColor,
                    title: const Text(
                      'Critical alerts',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onChanged: (val) => setState(() => _soundAlerts = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Escalation Emergency Contacts
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Emergency contacts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showContactDialog(patient.id),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 19),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  if (emergencyContacts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No emergency contacts added yet.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  ...emergencyContacts.map(
                    (contact) => ListTile(
                      leading: const Icon(
                        Icons.phone_in_talk_rounded,
                        color: AppTheme.primaryColor,
                      ),
                      title: Text(
                        contact.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${contact.relationship} • ${contact.phone}',
                      ),
                      trailing: PopupMenuButton<_ContactAction>(
                        tooltip: 'Contact options for ${contact.name}',
                        onSelected: (action) {
                          switch (action) {
                            case _ContactAction.edit:
                              _showContactDialog(patient.id, contact: contact);
                              break;
                            case _ContactAction.delete:
                              _confirmContactDeletion(contact);
                              break;
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: _ContactAction.edit,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit_outlined,
                                  color: AppTheme.primaryColor,
                                ),
                                SizedBox(width: 10),
                                Text('Edit contact'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: _ContactAction.delete,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  color: AppTheme.alertRed,
                                ),
                                SizedBox(width: 10),
                                Text('Remove contact'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.alertRed,
                side: const BorderSide(color: AppTheme.alertRed),
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () async {
                await ref.read(sessionProvider.notifier).signOut();
                if (context.mounted) context.go('/login');
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text(
                'Sign Out',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _showContactDialog(
    String patientId, {
    EmergencyContact? contact,
  }) async {
    final nameController = TextEditingController(text: contact?.name ?? '');
    final relationshipController = TextEditingController(
      text: contact?.relationship ?? '',
    );
    final phoneController = TextEditingController(text: contact?.phone ?? '');
    final priorityController = TextEditingController(
      text:
          contact?.priority.toString() ??
          '${ref.read(emergencyContactsProvider).length + 1}',
    );
    var isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            contact == null ? 'Add emergency contact' : 'Edit contact',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  enabled: !isSaving,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: relationshipController,
                  enabled: !isSaving,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Relationship'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  enabled: !isSaving,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    hintText: '+91 98765 43210',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priorityController,
                  enabled: !isSaving,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Priority',
                    helperText: '1 is contacted first',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      final phone = phoneController.text.trim();
                      final priority = int.tryParse(priorityController.text);
                      if (name.isEmpty || phone.isEmpty) {
                        _showMessage('Name and phone number are required.');
                        return;
                      }
                      if (!RegExp(
                        r'^\+?[0-9][0-9 ()-]{6,24}$',
                      ).hasMatch(phone)) {
                        _showMessage('Enter a valid phone number.');
                        return;
                      }
                      if (priority == null || priority < 1 || priority > 100) {
                        _showMessage('Priority must be between 1 and 100.');
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      final updatedContact = EmergencyContact(
                        id:
                            contact?.id ??
                            'contact-${DateTime.now().microsecondsSinceEpoch}',
                        name: name,
                        phone: phone,
                        relationship: relationshipController.text.trim(),
                        priority: priority,
                      );
                      try {
                        final notifier = ref.read(
                          emergencyContactsProvider.notifier,
                        );
                        if (contact == null) {
                          await notifier.addContact(
                            updatedContact,
                            patientId: patientId,
                          );
                        } else {
                          await notifier.updateContact(updatedContact);
                        }
                        if (!dialogContext.mounted) return;
                        Navigator.of(dialogContext).pop();
                        _showMessage(
                          contact == null
                              ? '$name added as an emergency contact.'
                              : '$name updated.',
                        );
                      } catch (_) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() => isSaving = false);
                        _showMessage(
                          contact == null
                              ? 'Unable to add contact. Please try again.'
                              : 'Unable to update contact. Please try again.',
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(contact == null ? 'Add contact' : 'Save changes'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    relationshipController.dispose();
    phoneController.dispose();
    priorityController.dispose();
  }

  Future<void> _confirmContactDeletion(EmergencyContact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove emergency contact?'),
        content: Text(
          '${contact.name} will no longer be shown during an emergency.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.alertRed),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove contact'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref
          .read(emergencyContactsProvider.notifier)
          .deleteContact(contact.id);
      if (!mounted) return;
      _showMessage('${contact.name} removed.');
    } catch (_) {
      if (!mounted) return;
      _showMessage('Unable to remove contact. Please try again.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
