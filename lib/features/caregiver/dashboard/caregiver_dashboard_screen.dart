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
    final caregiver = ref.watch(currentCaregiverProvider);
    final safeZone = ref.watch(safeZoneProvider);
    final medications = ref.watch(doseInstancesProvider);
    final alerts = ref.watch(alertsProvider);

    final activeAlerts = alerts
        .where((a) => a.status == AlertStatus.active)
        .toList();
    final pendingMeds = medications.where((m) => m.isPending).toList();
    final hasSafeZone = safeZone.id.isNotEmpty;
    final locationStatus = _locationStatus(
      patient: patient,
      safeZone: safeZone,
      hasSafeZone: hasSafeZone,
    );

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _refresh(context, ref),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                              const SizedBox(width: 12),
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
                                onPressed: () async {
                                  try {
                                    await ref
                                        .read(alertsProvider.notifier)
                                        .acknowledgeAlert(
                                          alert.id,
                                          caregiver.name,
                                        );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Alert acknowledged'),
                                      ),
                                    );
                                  } catch (_) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Unable to update'),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(
                                  Icons.check_circle_outline,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Acknowledge',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                horizontal: 12,
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
                                value: patient.batteryLevel == null
                                    ? 'Unavailable'
                                    : '${patient.batteryLevel}%',
                                color: patient.batteryLevel == null
                                    ? AppTheme.textSecondary
                                    : patient.batteryLevel! > 20
                                    ? AppTheme.successGreen
                                    : AppTheme.alertRed,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.grey.shade200,
                            ),
                            Expanded(
                              child: _StatusMetricTile(
                                icon: Icons.sync_rounded,
                                title: 'Last Sync',
                                value: patient.lastSyncTime == null
                                    ? 'Never'
                                    : _formatTimeAgo(patient.lastSyncTime!),
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.grey.shade200,
                            ),
                            Expanded(
                              child: _StatusMetricTile(
                                icon: Icons.location_on_rounded,
                                title: 'Safe Zone',
                                value: locationStatus.shortLabel,
                                color: locationStatus.color,
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
                  'Location',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: locationStatus.containerColor,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                locationStatus.icon,
                                color: locationStatus.color,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    locationStatus.title,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: locationStatus.color,
                                    ),
                                  ),
                                  Text(
                                    locationStatus.subtitle,
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
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => context.go('/caregiver/location'),
                          icon: const Icon(Icons.map_rounded),
                          label: const Text(
                            'Open map',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
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
                      'Medications',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/caregiver/schedules'),
                      child: const Text('Manage'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${medications.length - pendingMeds.length} of ${medications.length} taken',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
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
                                : (medications.length - pendingMeds.length) /
                                      medications.length,
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
                              _doseStatusIcon(med.status),
                              color: _doseStatusColor(med.status),
                              size: 24,
                            ),
                            title: Text(
                              med.medicineName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Text(
                              '${med.dosage} • ${TimeOfDay.fromDateTime(med.scheduledFor).format(context)}',
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _doseStatusBackground(med.status),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _doseStatusLabel(med.status),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _doseStatusColor(med.status),
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

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    try {
      await refreshCareData(ref);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to refresh care information.')),
      );
    }
  }

  _DashboardLocationStatus _locationStatus({
    required PatientModel patient,
    required SafeZoneModel safeZone,
    required bool hasSafeZone,
  }) {
    if (!patient.locationSharingEnabled) {
      return const _DashboardLocationStatus(
        shortLabel: 'SHARING OFF',
        title: 'Location sharing is off',
        subtitle: 'The patient must enable sharing to update location.',
        icon: Icons.location_disabled_rounded,
        color: AppTheme.textSecondary,
        containerColor: Color(0xFFF0F0F0),
      );
    }
    if (!patient.isDeviceOnline || patient.lastSyncTime == null) {
      return const _DashboardLocationStatus(
        shortLabel: 'UNKNOWN',
        title: 'Location status unavailable',
        subtitle: 'The patient device is offline or has not synced.',
        icon: Icons.location_searching_rounded,
        color: AppTheme.textSecondary,
        containerColor: Color(0xFFF0F0F0),
      );
    }
    if (!hasSafeZone) {
      return const _DashboardLocationStatus(
        shortLabel: 'NOT SET',
        title: 'Safe zone not configured',
        subtitle: 'Create a safe zone before monitoring its boundary.',
        icon: Icons.add_location_alt_outlined,
        color: AppTheme.warningOrange,
        containerColor: AppTheme.warningOrangeContainer,
      );
    }
    if (safeZone.isPatientInside) {
      return _DashboardLocationStatus(
        shortLabel: 'INSIDE',
        title: 'Inside Safe Radius (${safeZone.name})',
        subtitle: patient.lastKnownLocationName,
        icon: Icons.fit_screen_rounded,
        color: AppTheme.successGreen,
        containerColor: AppTheme.successGreenContainer,
      );
    }
    return _DashboardLocationStatus(
      shortLabel: 'OUTSIDE',
      title: 'Outside Safe Zone Boundary!',
      subtitle: patient.lastKnownLocationName,
      icon: Icons.wrong_location_rounded,
      color: AppTheme.alertRed,
      containerColor: AppTheme.alertRedContainer,
    );
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

class _DashboardLocationStatus {
  const _DashboardLocationStatus({
    required this.shortLabel,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.containerColor,
  });

  final String shortLabel;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color containerColor;
}

String _doseStatusLabel(DoseStatus status) => switch (status) {
  DoseStatus.reportedTaken => 'TAKEN',
  DoseStatus.skipped => 'SKIPPED',
  DoseStatus.overdue => 'OVERDUE',
  DoseStatus.scheduled => 'PENDING',
};

Color _doseStatusColor(DoseStatus status) => switch (status) {
  DoseStatus.reportedTaken => AppTheme.successGreen,
  DoseStatus.skipped => Colors.blueGrey.shade700,
  DoseStatus.overdue => AppTheme.alertRed,
  DoseStatus.scheduled => Colors.orange.shade900,
};

Color _doseStatusBackground(DoseStatus status) => switch (status) {
  DoseStatus.reportedTaken => AppTheme.successGreenContainer,
  DoseStatus.skipped => Colors.blueGrey.shade100,
  DoseStatus.overdue => Colors.red.shade100,
  DoseStatus.scheduled => Colors.orange.shade100,
};

IconData _doseStatusIcon(DoseStatus status) => switch (status) {
  DoseStatus.reportedTaken => Icons.check_circle_rounded,
  DoseStatus.skipped => Icons.not_interested_rounded,
  DoseStatus.overdue => Icons.warning_amber_rounded,
  DoseStatus.scheduled => Icons.schedule_rounded,
};

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
