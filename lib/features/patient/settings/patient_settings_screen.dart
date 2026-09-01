import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../core/providers/app_state.dart';

class PatientSettingsScreen extends ConsumerWidget {
  const PatientSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patient = ref.watch(patientProvider);
    final caregivers = ref.watch(caregiversProvider);

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
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
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
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Icon(
                                Icons.wifi_rounded,
                                size: 18,
                                color: AppTheme.successGreen,
                              ),
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                value: patient.locationSharingEnabled,
                activeThumbColor: AppTheme.primaryColor,
                title: const Text(
                  'Share My Location with Caregivers',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  patient.locationSharingEnabled
                      ? 'Location sharing ACTIVE for safe-zone alerts.'
                      : 'Location sharing is PAUSED.',
                  style: TextStyle(
                    color: patient.locationSharingEnabled
                        ? AppTheme.successGreen
                        : AppTheme.alertRed,
                  ),
                ),
                onChanged: (val) {
                  ref.read(patientProvider.notifier).toggleLocationSharing();
                },
              ),
            ),
            const SizedBox(height: 24),

            // Linked Caregivers Section
            const Text(
              '👥 Approved Caregivers',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ...caregivers.map(
                    (cg) => ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppTheme.primaryContainer,
                        child: Icon(
                          Icons.person_rounded,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      title: Text(
                        cg.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(cg.relationship),
                      trailing: cg.isPrimary
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
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
                    leading: const Icon(
                      Icons.qr_code_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    title: const Text('Show Caregiver Invitation QR Code'),
                    onTap: () {
                      _showQrCodeDialog(context);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Sign Out / Exit
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

  void _showQrCodeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Caregiver Invitation QR Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.qr_code_2_rounded, size: 140),
            ),
            const SizedBox(height: 12),
            const Text(
              'Have caregiver scan this code with their app to link accounts.',
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
