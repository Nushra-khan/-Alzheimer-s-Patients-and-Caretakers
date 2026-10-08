import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          children: [
            // Profile Card Header
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
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
              'Location',
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
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                value: patient.locationSharingEnabled,
                activeThumbColor: AppTheme.primaryColor,
                title: const Text(
                  'Share location',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onChanged: (val) async {
                  try {
                    await ref
                        .read(patientProvider.notifier)
                        .setLocationSharing(val);
                  } catch (_) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Unable to update')),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 24),

            // Approved Caregivers Section
            const Text(
              'Caregivers',
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
                                horizontal: 10,
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
                    title: const Text(
                      'Caregiver code',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onTap: () => _showCaregiverCodeDialog(context, ref),
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

  void _showCaregiverCodeDialog(BuildContext context, WidgetRef ref) {
    final repository = ref.read(careRepositoryProvider);
    if (repository == null) return;
    final invitation = repository.createCareInvitation();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Caregiver code'),
        content: FutureBuilder<({String token, DateTime expiresAt})>(
          future: invitation,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 90,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError || snapshot.data == null) {
              return const Text('Unable to create code');
            }
            final token = snapshot.data!.token;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SelectableText(
                  token,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                IconButton(
                  tooltip: 'Copy',
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: token)),
                  icon: const Icon(Icons.copy_rounded),
                ),
              ],
            );
          },
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
