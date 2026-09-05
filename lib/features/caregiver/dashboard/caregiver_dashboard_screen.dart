import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/app_state.dart';

class CaregiverDashboardScreen extends ConsumerWidget {
  const CaregiverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patient = ref.watch(patientProvider);
    final safeZone = ref.watch(safeZoneProvider);
    final medications = ref.watch(medicationsProvider);
    final alerts = ref.watch(alertsProvider);

    final activeAlerts = alerts.where((a) => a.status == AlertStatus.active).toList();
    final pendingMeds = medications.where((m) => !m.isTakenToday).toList();

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAlignment.start,
              children: [
                // Active Critical Warning Banners (If any active alerts)
                if (activeAlerts.isNotEmpty) ...[
                  ...activeAlerts.map(
                    (alert) => Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: alert.severity == AlertSeverity.critical
                            ? AppTheme.alertRedContainer
                            : AppTheme.warningOrangeContainer,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: alert.severity == AlertSeverity.critical
                              ? AppTheme.alertRed
                              : AppTheme.warningOrange,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAlignment.start,
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
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  alert.title,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: alert.severity == AlertSeverity.critical
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
                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.alertRed,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(130, 42),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () {
                                  ref
                                      .read(alertsProvider.notifier)
                                      .acknowledgeAlert(alert.id, 'Sunita Sharma');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Alert acknowledged! Logged in audit trail.'),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.check_circle_outline, size: 18),
                                label: const Text('Acknowledge', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Patient Overview Hero Card
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: AppTheme.primaryContainer,
                              child: Text(
                                patient.name.characters.first,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAlignment.start,
                                children: [
                                  Text(
                                    patient.name,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Age ${patient.age} • ID: ${patient.id}',
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                                    color: patient.isDeviceOnline ? AppTheme.successGreen : Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    patient.isDeviceOnline ? 'ONLINE' : 'OFFLINE',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: patient.isDeviceOnline ? AppTheme.successGreen : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const Divider(height: 1),
                        const SizedBox(height: 16),

                        // Status Metrics Grid
                        Row(
                          children: [
                            Expanded(
                              child: _StatusMetricTile(
                                icon: Icons.battery_charging_full_rounded,
                                title: 'Battery',
                                value: '${patient.batteryLevel}%',
                                color: patient.batteryLevel > 20
                                    ? AppTheme.successGreen
                                    : AppTheme.alertRed,
                              ),
                            ),
                            Container(width: 1, height: 40, color: Colors.grey.shade200),
                            Expanded(
                              child: _StatusMetricTile(
                                icon: Icons.sync_rounded,
                                title: 'Last Sync',
                                value: _formatTimeAgo(patient.lastSyncTime),
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            Container(width: 1, height: 40, color: Colors.grey.shade200),
                            Expanded(
                              child: _StatusMetricTile(
                                icon: Icons.location_on_rounded,
                                title: 'Safe Zone',
                                value: safeZone.isPatientInside ? 'INSIDE' : 'OUTSIDE',
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
                const SizedBox(height: 24),

                // Location Summary Preview Card
                const Text(
                  '📍 Patient Location & Safe Zone',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: safeZone.isPatientInside
                                    ? AppTheme.successGreenContainer
                                    : AppTheme.alertRedContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                safeZone.isPatientInside
                                    ? Icons.fit_screen_rounded
                                    : Icons.wrong_location_rounded,
                                color: safeZone.isPatientInside
                                    ? AppTheme.successGreen
                                    : AppTheme.alertRed,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAlignment.start,
                                children: [
                                  Text(
                                    safeZone.isPatientInside
                                        ? 'Inside Safe Radius (${safeZone.name})'
                                        : 'Outside Safe Zone Boundary!',
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
                                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => context.go('/caregiver/location'),
                          icon: const Icon(Icons.map_rounded),
                          label: const Text('Open Interactive Geofence Map', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Dose Compliance Today
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '💊 Medication Compliance',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    TextButton(
                      onPressed: () => context.go('/caregiver/schedules'),
                      child: const Text('Manage Schedules'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Reported Doses: ${medications.length - pendingMeds.length} of ${medications.length}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Text(
                              '${((medications.length - pendingMeds.length) / (medications.isEmpty ? 1 : medications.length) * 100).toInt()}%',
                              style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: medications.isEmpty
                                ? 0
                                : (medications.length - pendingMeds.length) / medications.length,
                            backgroundColor: Colors.grey.shade200,
                            color: AppTheme.primaryColor,
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...medications.map(
                          (med) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              med.isTakenToday ? Icons.check_circle_rounded : Icons.schedule_rounded,
                              color: med.isTakenToday ? AppTheme.successGreen : Colors.orange,
                              size: 24,
                            ),
                            title: Text(med.medicineName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            subtitle: Text('${med.dosage} • Scheduled: ${med.time}'),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: med.isTakenToday
                                    ? AppTheme.successGreenContainer
                                    : Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                med.isTakenToday ? 'TAKEN' : 'PENDING',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: med.isTakenToday
                                      ? AppTheme.successGreen
                                      : Colors.orange.shade900,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
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
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          title,
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}
