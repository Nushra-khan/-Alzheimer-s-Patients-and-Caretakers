import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/app_state.dart';

class PatientSettingsScreen extends ConsumerWidget {
  const PatientSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patient = ref.watch(patientProvider);
    final caregivers = ref.watch(caregiversProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          children: [
            // Profile Card Header
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppTheme.primaryContainer,
                      child: Text(
                        patient.name.characters.first,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAlignment.start,
                        children: [
                          Text(
                            patient.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Age: ${patient.age} • Patient ID: ${patient.id}',
                            style: const TextStyle(color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.battery_charging_full_rounded,
                                size: 18,
                                color: patient.batteryLevel > 20
                                    ? AppTheme.successGreen
                                    : AppTheme.alertRed,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${patient.batteryLevel}% Battery',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 12),
                              const Icon(Icons.wifi_rounded, size: 18, color: AppTheme.successGreen),
                              const SizedBox(width: 4),
                              const Text(
                                'Connected',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.successGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Location Sharing Toggle Section
            const Text(
              '📍 Privacy & Location Sharing',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 10),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                value: patient.locationSharingEnabled,
                activeThumbColor: AppTheme.primaryColor,
                title: const Text(
                  'Share My Location with Caregivers',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  patient.locationSharingEnabled
                      ? 'Location sharing ACTIVE for safe-zone protection.'
                      : 'Location sharing is PAUSED.',
                  style: TextStyle(
                    color: patient.locationSharingEnabled ? AppTheme.successGreen : AppTheme.alertRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onChanged: (val) {
                  ref.read(patientProvider.notifier).toggleLocationSharing();
                },
              ),
            ),
            const SizedBox(height: 24),

            // Approved Caregivers Section
            const Text(
              '👥 Approved Caregivers',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 10),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  ...caregivers.map(
                    (cg) => ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppTheme.primaryContainer,
                        child: Icon(Icons.person_rounded, color: AppTheme.primaryColor),
                      ),
                      title: Text(
                        cg.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(cg.relationship),
                      trailing: cg.isPrimary
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'PRIMARY',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.qr_code_rounded, color: AppTheme.primaryColor),
                    title: const Text('Show Caregiver Invitation QR Code', style: TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () {
                      _showQrCodeDialog(context);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Switch to Caregiver View
            const Text(
              '⚙️ App View Switcher',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 10),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: const Icon(Icons.swap_horiz_rounded, color: AppTheme.primaryColor),
                title: const Text('Switch to Caregiver Portal View', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Access Caregiver Dashboard & Alert Management'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  ref.read(userRoleProvider.notifier).state = UserRole.caregiver;
                  ref.read(sessionProvider.notifier).enterPreview(UserRole.caregiver);
                  context.go('/caregiver/dashboard');
                },
              ),
            ),
            const SizedBox(height: 24),

            // Sign Out / Exit
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

  void _showQrCodeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Caregiver Invitation QR Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 190,
              height: 190,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black87, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.qr_code_2_rounded, size: 150),
            ),
            const SizedBox(height: 14),
            const Text(
              'Have your caregiver scan this code with their app to link accounts.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
