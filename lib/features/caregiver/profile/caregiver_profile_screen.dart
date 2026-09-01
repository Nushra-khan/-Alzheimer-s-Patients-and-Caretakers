import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../core/providers/app_state.dart';

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
    final emergencyContacts = ref.watch(emergencyContactsProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            // Profile Card Header
            Card(
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
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sunita Sharma',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Primary Caregiver (Spouse)',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Phone: +91 98765 43210',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Patient Linked Info
            const Text(
              '👤 Linked Patient Account',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
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
                  'Age: ${patient.age} • Status: ${patient.isDeviceOnline ? "Device Active" : "Offline"}',
                ),
                trailing: const Icon(
                  Icons.check_circle,
                  color: AppTheme.successGreen,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Notification & Escalation Preferences
            const Text(
              '🔔 Alert & Notification Rules',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    value: _pushNotifications,
                    activeThumbColor: AppTheme.primaryColor,
                    title: const Text('Push Notifications (FCM)'),
                    subtitle: const Text(
                      'Instant alerts for SOS, safe zone exits, and overdue doses.',
                    ),
                    onChanged: (val) =>
                        setState(() => _pushNotifications = val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: _smsAlerts,
                    activeThumbColor: AppTheme.primaryColor,
                    title: const Text('Emergency SMS Fallback'),
                    subtitle: const Text(
                      'Send SMS if internet is disconnected on device.',
                    ),
                    onChanged: (val) => setState(() => _smsAlerts = val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: _soundAlerts,
                    activeThumbColor: AppTheme.primaryColor,
                    title: const Text('Critical Alarm Sound Override'),
                    subtitle: const Text(
                      'Play high-priority alert sound even during Silent/Do Not Disturb.',
                    ),
                    onChanged: (val) => setState(() => _soundAlerts = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Emergency Contacts
            const Text(
              '📞 Escalation Contacts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
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
              ),
              onPressed: () {
                ref.read(sessionProvider.notifier).signOut();
                context.go('/welcome');
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign Out'),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
