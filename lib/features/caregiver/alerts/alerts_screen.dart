import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/app_state.dart';

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  AlertStatus? _statusFilter; // null = all

  @override
  Widget build(BuildContext context) {
    final alerts = ref.watch(alertsProvider);
    final filteredAlerts = _statusFilter == null
        ? alerts
        : alerts.where((a) => a.status == _statusFilter).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Status Filter Chips Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: Text('All Alerts (${alerts.length})'),
                      selected: _statusFilter == null,
                      onSelected: (selected) {
                        setState(() {
                          _statusFilter = null;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text(
                        'Active (${alerts.where((a) => a.status == AlertStatus.active).length})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      selectedColor: AppTheme.alertRedContainer,
                      selected: _statusFilter == AlertStatus.active,
                      onSelected: (selected) {
                        setState(() {
                          _statusFilter = AlertStatus.active;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text(
                        'Acknowledged (${alerts.where((a) => a.status == AlertStatus.acknowledged).length})',
                      ),
                      selected: _statusFilter == AlertStatus.acknowledged,
                      onSelected: (selected) {
                        setState(() {
                          _statusFilter = AlertStatus.acknowledged;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text(
                        'Resolved (${alerts.where((a) => a.status == AlertStatus.resolved).length})',
                      ),
                      selected: _statusFilter == AlertStatus.resolved,
                      onSelected: (selected) {
                        setState(() {
                          _statusFilter = AlertStatus.resolved;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),

            // Alerts Feed List
            Expanded(
              child: filteredAlerts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.check_circle_outline,
                            size: 64,
                            color: AppTheme.successGreen,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No alerts matching selected filter.',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredAlerts.length,
                      itemBuilder: (ctx, index) {
                        final alert = filteredAlerts[index];
                        return _AlertCard(
                          alert: alert,
                          onAcknowledge: () {
                            ref
                                .read(alertsProvider.notifier)
                                .acknowledgeAlert(
                                  alert.id,
                                  'Sunita Sharma (Caregiver)',
                                );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Alert acknowledged and logged.'),
                              ),
                            );
                          },
                          onResolve: () {
                            ref
                                .read(alertsProvider.notifier)
                                .resolveAlert(alert.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Alert marked RESOLVED.'),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final AlertModel alert;
  final VoidCallback onAcknowledge;
  final VoidCallback onResolve;

  const _AlertCard({
    required this.alert,
    required this.onAcknowledge,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    Color cardBorderColor;
    Color iconBgColor;
    IconData alertIcon;

    switch (alert.type) {
      case AlertType.sos:
        alertIcon = Icons.warning_rounded;
        iconBgColor = AppTheme.alertRed;
        cardBorderColor = AppTheme.alertRed;
        break;
      case AlertType.safeZoneExit:
        alertIcon = Icons.location_off_rounded;
        iconBgColor = AppTheme.warningOrange;
        cardBorderColor = AppTheme.warningOrange;
        break;
      case AlertType.overdueDose:
        alertIcon = Icons.medication_liquid_rounded;
        iconBgColor = Colors.purple;
        cardBorderColor = Colors.purple.shade200;
        break;
      case AlertType.deviceOffline:
        alertIcon = Icons.wifi_off_rounded;
        iconBgColor = Colors.grey;
        cardBorderColor = Colors.grey;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: alert.status == AlertStatus.active
              ? cardBorderColor
              : Colors.grey.shade300,
          width: alert.status == AlertStatus.active ? 2 : 1,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Alert Title Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: iconBgColor.withValues(alpha: 0.15),
                  child: Icon(alertIcon, color: iconBgColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Patient: ${alert.patientName} • ${_formatTimeAgo(alert.timestamp)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(status: alert.status),
              ],
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              alert.description,
              style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 14),

            // Lifecycle Audit Details
            if (alert.acknowledgedBy != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.history_rounded,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Acknowledged by ${alert.acknowledgedBy} (${_formatTimeAgo(alert.acknowledgedAt!)})',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (alert.status == AlertStatus.active) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: onAcknowledge,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Acknowledge'),
                  ),
                ] else if (alert.status == AlertStatus.acknowledged) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successGreen,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: onResolve,
                    icon: const Icon(Icons.done_all_rounded, size: 18),
                    label: const Text('Mark Resolved'),
                  ),
                ] else ...[
                  const Icon(
                    Icons.task_alt_rounded,
                    color: AppTheme.successGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Resolved',
                    style: TextStyle(
                      color: AppTheme.successGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ],
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

class _StatusBadge extends StatelessWidget {
  final AlertStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case AlertStatus.active:
        bg = AppTheme.alertRedContainer;
        fg = AppTheme.alertRed;
        label = 'ACTIVE';
        break;
      case AlertStatus.acknowledged:
        bg = AppTheme.warningOrangeContainer;
        fg = AppTheme.warningOrange;
        label = 'ACKNOWLEDGED';
        break;
      case AlertStatus.resolved:
        bg = AppTheme.successGreenContainer;
        fg = AppTheme.successGreen;
        label = 'RESOLVED';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
