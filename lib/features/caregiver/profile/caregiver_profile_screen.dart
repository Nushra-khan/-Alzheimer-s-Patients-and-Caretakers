import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/app_state.dart';

class CaregiverProfileScreen extends ConsumerStatefulWidget {
  const CaregiverProfileScreen({super.key});

  @override
  ConsumerState<CaregiverProfileScreen> createState() => _CaregiverProfileScreenState();
}

class _CaregiverProfileScreenState extends ConsumerState<CaregiverProfileScreen> {
  bool _pushNotifications = true;
  bool _smsAlerts = true;
  bool _soundAlerts = true;

  @override
  Widget build(BuildContext context) {
    final patient = ref.watch(patientProvider);
    final emergencyContacts = ref.watch(emergencyContactsProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          children: [
            // Profile Header Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: AppTheme.primaryContainer,
                      child: Icon(Icons.shield_rounded, size: 36, color: AppTheme.primaryColor),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAlignment.start,
                        children: [
                          Text(
                            'Sunita Sharma',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Primary Caregiver (Spouse)',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Phone: +91 98765 43210',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
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
              '👤 Linked Patient Account',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 10),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: const Icon(Icons.badge_rounded, color: AppTheme.primaryColor),
                title: Text(patient.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Age: ${patient.age} • Status: ${patient.isDeviceOnline ? "Device Online" : "Offline"}'),
                trailing: const Icon(Icons.check_circle, color: AppTheme.successGreen),
              ),
            ),
            const SizedBox(height: 24),

            // Notification & Escalation Rules
            const Text(
              '🔔 Alert & Notification Rules',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 10),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  SwitchListTile(
                    value: _pushNotifications,
                    activeThumbColor: AppTheme.primaryColor,
                    title: const Text('Push Notifications (FCM)', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Instant alerts for SOS, safe zone exits, and overdue doses.'),
                    onChanged: (val) => setState(() => _pushNotifications = val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: _smsAlerts,
                    activeThumbColor: AppTheme.primaryColor,
                    title: const Text('Emergency SMS Fallback', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Send SMS if internet connectivity drops.'),
                    onChanged: (val) => setState(() => _smsAlerts = val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: _soundAlerts,
                    activeThumbColor: AppTheme.primaryColor,
                    title: const Text('Critical Alarm Override', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Play high-priority alert sound even in Silent mode.'),
                    onChanged: (val) => setState(() => _soundAlerts = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Escalation Emergency Contacts
            const Text(
              '📞 Escalation Contacts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 10),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  ...emergencyContacts.map(
                    (contact) => ListTile(
                      leading: const Icon(Icons.phone_in_talk_rounded, color: AppTheme.primaryColor),
                      title: Text(contact.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${contact.relationship} • ${contact.phone}'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Role Switch & Sign Out
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: const Icon(Icons.swap_horiz_rounded, color: AppTheme.primaryColor),
                title: const Text('Switch to Patient App View', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  ref.read(userRoleProvider.notifier).state = UserRole.patient;
                  ref.read(sessionProvider.notifier).enterPreview(UserRole.patient);
                  context.go('/patient/today');
                },
              ),
            ),
            const SizedBox(height: 16),

            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.alertRed,
                side: const BorderSide(color: AppTheme.alertRed),
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                ref.read(sessionProvider.notifier).signOut();
                context.go('/login');
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
