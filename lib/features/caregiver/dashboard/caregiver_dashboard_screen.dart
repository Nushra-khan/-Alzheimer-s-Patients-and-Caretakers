import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/theme.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/app_state.dart';

class CaregiverDashboardScreen extends ConsumerWidget {
  const CaregiverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patient = ref.watch(patientProvider);
    final safeZone = ref.watch(safeZoneProvider);
    final doses = ref.watch(doseInstancesProvider);
    final alerts = ref.watch(alertsProvider);

    final activeAlerts = alerts
        .where((a) => a.status == AlertStatus.active)
        .toList();
    final pendingDoses = doses.where((dose) => !dose.isReportedTaken).toList();
    final completion = doses.isEmpty
        ? 0.0
        : (doses.length - pendingDoses.length) / doses.length;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Active Critical Alert Warning Banner (If any)
                if (activeAlerts.isNotEmpty) ...[
                  ...activeAlerts.map(
                    (alert) => Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: alert.severity == AlertSeverity.critical
                            ? AppTheme.alertRedContainer
                            : AppTheme.warningOrangeContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: alert.severity == AlertSeverity.critical
                              ? AppTheme.alertRed
                              : AppTheme.warningOrange,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                alert.severity == AlertSeverity.critical
                                    ? Icons.warning_rounded
                                    : Icons.info_rounded,
                                color: alert.severity == AlertSeverity.critical
                                    ? AppTheme.alertRed
                                    : AppTheme.warningOrange,
                                size: 28,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  alert.title,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        alert.severity == AlertSeverity.critical
                                        ? AppTheme.onAlertRedContainer
                                        : Colors.brown.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            alert.description,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.alertRed,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(120, 42),
                                ),
                                onPressed: () {
                                  ref
                                      .read(alertsProvider.notifier)
                                      .acknowledgeAlert(
                                        alert.id,
                                        'Sunita Sharma',
                                      );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Alert acknowledged! Logged in audit history.',
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.check_circle_outline,
                                  size: 18,
                                ),
                                label: const Text('Acknowledge'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Patient Overview Main Header Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: AppTheme.primaryContainer,
                              child: Text(
                                patient.name.characters.first,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    patient.name,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Age ${patient.age} • Patient ID: ${patient.id}',
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: patient.isDeviceOnline
                                    ? AppTheme.successGreenContainer
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 10,
                                    color: patient.isDeviceOnline
                                        ? AppTheme.successGreen
                                        : Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    patient.isDeviceOnline
                                        ? 'ONLINE'
                                        : 'OFFLINE',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: patient.isDeviceOnline
                                          ? AppTheme.successGreen
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 14),

                        // Metrics Grid
                        Row(
                          children: [
                            Expanded(
                              child: _StatusMetricTile(
                                icon: Icons.battery_charging_full_rounded,
                                title: 'Battery State',
                                value: '${patient.batteryLevel}%',
                                color: patient.batteryLevel > 20
                                    ? AppTheme.successGreen
                                    : AppTheme.alertRed,
                              ),
                            ),
                            Expanded(
                              child: _StatusMetricTile(
                                icon: Icons.sync_rounded,
                                title: 'Last Sync',
                                value: _formatTimeAgo(patient.lastSyncTime),
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            Expanded(
                              child: _StatusMetricTile(
                                icon: Icons.location_on_rounded,
                                title: 'Safe Zone',
                                value: safeZone.isPatientInside
                                    ? 'INSIDE'
                                    : 'OUTSIDE',
                                color: safeZone.isPatientInside
                                    ? AppTheme.successGreen
                                    : AppTheme.alertRed,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Location Summary Preview Card
                const Text(
                  '📍 Patient Location & Safe Zone',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              safeZone.isPatientInside
                                  ? Icons.fit_screen_rounded
                                  : Icons.wrong_location_rounded,
                              color: safeZone.isPatientInside
                                  ? AppTheme.successGreen
                                  : AppTheme.alertRed,
                              size: 26,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    safeZone.isPatientInside
                                        ? 'Inside Safe Zone (${safeZone.name})'
                                        : 'Outside Safe Zone Boundary',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: safeZone.isPatientInside
                                          ? AppTheme.successGreen
                                          : AppTheme.alertRed,
                                    ),
                                  ),
                                  Text(
                                    patient.lastKnownLocationName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 44),
                          ),
                          onPressed: () => context.go('/caregiver/location'),
                          icon: const Icon(Icons.map_rounded),
                          label: const Text(
                            'Open Interactive Map & Geofence Settings',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Medications Quick Compliance Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '💊 Dose Compliance Today',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/caregiver/schedules'),
                      child: const Text('Manage Schedules'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Pending Doses: ${pendingDoses.length} of ${doses.length}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${(completion * 100).toInt()}% Reported',
                              style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: completion,
                          backgroundColor: Colors.grey.shade200,
                          color: AppTheme.primaryColor,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 14),
                        ...doses.map(
                          (dose) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              dose.isReportedTaken
                                  ? Icons.check_circle
                                  : Icons.schedule,
                              color: dose.isReportedTaken
                                  ? AppTheme.successGreen
                                  : Colors.orange,
                            ),
                            title: Text(
                              dose.medicineName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${dose.dosage} • ${DateFormat.jm().format(dose.scheduledFor)}',
                            ),
                            trailing: Text(
                              dose.isReportedTaken ? 'Reported' : 'Pending',
                              style: TextStyle(
                                color: dose.isReportedTaken
                                    ? AppTheme.successGreen
                                    : Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

class _StatusMetricTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatusMetricTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}
