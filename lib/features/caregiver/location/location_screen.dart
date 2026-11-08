import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/app_state.dart';

class LocationScreen extends ConsumerWidget {
  const LocationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patient = ref.watch(patientProvider);
    final safeZone = ref.watch(safeZoneProvider);
    final isDemoMode = ref.watch(careRepositoryProvider) == null;
    final locationStatusColor = !patient.isDeviceOnline
        ? AppTheme.textSecondary
        : safeZone.isPatientInside
        ? AppTheme.successGreen
        : AppTheme.alertRed;
    final locationStatusContainer = !patient.isDeviceOnline
        ? Colors.grey.shade200
        : safeZone.isPatientInside
        ? AppTheme.successGreenContainer
        : AppTheme.alertRedContainer;
    final locationStatusLabel = !patient.isDeviceOnline
        ? 'DEVICE OFFLINE'
        : safeZone.isPatientInside
        ? 'SAFE ZONE'
        : 'OUTSIDE BOUNDARY';

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // Map Header Control Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              color: Colors.white,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: locationStatusContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      !patient.isDeviceOnline
                          ? Icons.wifi_off_rounded
                          : safeZone.isPatientInside
                          ? Icons.my_location_rounded
                          : Icons.location_off_rounded,
                      color: locationStatusColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient.lastKnownLocationName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          patient.lastSyncTime == null
                              ? 'Device has not synced'
                              : patient.isDeviceOnline
                              ? 'Updated ${_formatTimeAgo(patient.lastSyncTime!)}'
                              : 'Device offline • updated ${_formatTimeAgo(patient.lastSyncTime!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: patient.isDeviceOnline
                                ? AppTheme.textSecondary
                                : AppTheme.alertRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.tune_rounded,
                      color: AppTheme.primaryColor,
                      size: 26,
                    ),
                    tooltip: 'Safe zone',
                    onPressed: () {
                      _showSafeZoneSettingsDialog(context, ref, safeZone);
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Map Display Canvas with Geofence Visualizer
            Expanded(
              child: Stack(
                children: [
                  // Stylized Mock Map Graphic Container
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFE8ECEF),
                    child: CustomPaint(
                      painter: _MapGridPainter(
                        isPatientInside: safeZone.isPatientInside,
                        radiusMeters: safeZone.radiusMeters,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Geofence Circle representation
                            Container(
                              width: (safeZone.radiusMeters / 300 * 210).clamp(
                                130,
                                290,
                              ),
                              height: (safeZone.radiusMeters / 300 * 210).clamp(
                                130,
                                290,
                              ),
                              decoration: BoxDecoration(
                                color: locationStatusColor.withValues(
                                  alpha: 0.16,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: locationStatusColor,
                                  width: 2.8,
                                ),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Patient Pin Icon
                                    Icon(
                                      Icons.person_pin_circle_rounded,
                                      size: 52,
                                      color: locationStatusColor,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        patient.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Floating Map Controls Overlay
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Column(
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'recenter',
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.primaryColor,
                          elevation: 3,
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Map centered')),
                            );
                          },
                          child: const Icon(Icons.center_focus_strong_rounded),
                        ),
                        if (isDemoMode) const SizedBox(height: 10),
                        if (isDemoMode)
                          FloatingActionButton.small(
                            heroTag: 'simulate',
                            backgroundColor: safeZone.isPatientInside
                                ? AppTheme.alertRed
                                : AppTheme.successGreen,
                            foregroundColor: Colors.white,
                            elevation: 3,
                            onPressed: () {
                              ref
                                  .read(safeZoneProvider.notifier)
                                  .togglePatientInside();
                              final newInside = ref
                                  .read(safeZoneProvider)
                                  .isPatientInside;
                              if (!newInside) {
                                ref
                                    .read(alertsProvider.notifier)
                                    .acknowledgeAlert(
                                      'alt-102',
                                      'System Advisory',
                                    );
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    newInside
                                        ? 'Patient inside safe zone'
                                        : 'Patient outside safe zone',
                                  ),
                                ),
                              );
                            },
                            child: Icon(
                              safeZone.isPatientInside
                                  ? Icons.directions_run
                                  : Icons.home_rounded,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Bottom Geofence Info Card Overlay
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                safeZone.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: locationStatusContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  locationStatusLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: locationStatusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Radius: ${safeZone.radiusMeters.toInt()} m',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime time) {
    final difference = DateTime.now().difference(time);
    if (difference.isNegative || difference.inMinutes < 1) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  void _showSafeZoneSettingsDialog(
    BuildContext context,
    WidgetRef ref,
    SafeZoneModel safeZone,
  ) {
    double tempRadius = safeZone.radiusMeters;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Safe zone'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(safeZone.name),
              const SizedBox(height: 16),
              Text(
                'Radius: ${tempRadius.toInt()} m',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Slider(
                value: tempRadius,
                min: 100,
                max: 1000,
                divisions: 18,
                activeColor: AppTheme.primaryColor,
                label: '${tempRadius.toInt()}m',
                onChanged: (val) {
                  setStateDialog(() {
                    tempRadius = val;
                  });
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Alerts when patient leaves this area',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                try {
                  await ref
                      .read(safeZoneProvider.notifier)
                      .updateRadius(tempRadius);
                  if (!context.mounted) return;
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Safe zone updated')),
                  );
                } catch (_) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Unable to update')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  final bool isPatientInside;
  final double radiusMeters;

  _MapGridPainter({required this.isPatientInside, required this.radiusMeters});

  @override
  void paint(Canvas canvas, Size size) {
    final paintGrid = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1.0;

    const double step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paintGrid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
