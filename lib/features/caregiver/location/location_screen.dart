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

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Map Header Control Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: safeZone.isPatientInside
                          ? AppTheme.successGreenContainer
                          : AppTheme.alertRedContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      safeZone.isPatientInside
                          ? Icons.my_location_rounded
                          : Icons.location_off_rounded,
                      color: safeZone.isPatientInside
                          ? AppTheme.successGreen
                          : AppTheme.alertRed,
                    ),
                  ),
                  const SizedBox(width: 12),
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
                        Text(
                          'Accuracy: ±12 meters • Updated 3 mins ago',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.settings_suggest_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    tooltip: 'Configure Safe Zone Radius',
                    onPressed: () {
                      _showSafeZoneSettingsDialog(context, ref, safeZone);
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Map Display Placeholder Canvas with Geofence Visualizer
            Expanded(
              child: Stack(
                children: [
                  // Stylized Mock Map Graphic Container
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFE5E9EC),
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
                              width: (safeZone.radiusMeters / 300 * 200).clamp(
                                120,
                                280,
                              ),
                              height: (safeZone.radiusMeters / 300 * 200).clamp(
                                120,
                                280,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (safeZone.isPatientInside
                                            ? AppTheme.primaryColor
                                            : AppTheme.alertRed)
                                        .withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: safeZone.isPatientInside
                                      ? AppTheme.primaryColor
                                      : AppTheme.alertRed,
                                  width: 2.5,
                                ),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Patient Pin Icon
                                    Icon(
                                      Icons.person_pin_circle_rounded,
                                      size: 48,
                                      color: safeZone.isPatientInside
                                          ? AppTheme.primaryColor
                                          : AppTheme.alertRed,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        patient.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
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
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Map centered on patient position.',
                                ),
                              ),
                            );
                          },
                          child: const Icon(Icons.center_focus_strong_rounded),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'simulate',
                          backgroundColor: safeZone.isPatientInside
                              ? AppTheme.alertRed
                              : AppTheme.successGreen,
                          foregroundColor: Colors.white,
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
                                  .acknowledgeAlert('alt-102', 'System Alert');
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  newInside
                                      ? 'Simulated location: Patient returned INSIDE Safe Zone.'
                                      : 'Simulated location: Patient OUTSIDE Safe Zone! Alert generated.',
                                ),
                              ),
                            );
                          },
                          child: Icon(
                            safeZone.isPatientInside
                                ? Icons.directions_run
                                : Icons.home,
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
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
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
                                  fontSize: 16,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: safeZone.isPatientInside
                                      ? AppTheme.successGreenContainer
                                      : AppTheme.alertRedContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  safeZone.isPatientInside
                                      ? 'ZONE NORMAL'
                                      : 'OUTSIDE BOUNDARY',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: safeZone.isPatientInside
                                        ? AppTheme.successGreen
                                        : AppTheme.alertRed,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Configured Safe Radius: ${safeZone.radiusMeters.toInt()} meters • PostGIS Geofence Active',
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
          title: const Text('Configure Safe Zone'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Zone Name: ${safeZone.name}'),
              const SizedBox(height: 16),
              Text(
                'Radius Boundary: ${tempRadius.toInt()} meters',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Slider(
                value: tempRadius,
                min: 100,
                max: 1000,
                divisions: 18,
                label: '${tempRadius.toInt()}m',
                onChanged: (val) {
                  setStateDialog(() {
                    tempRadius = val;
                  });
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Exiting this radius triggers caregiver notification after 2-min grace period.',
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
              onPressed: () {
                ref.read(safeZoneProvider.notifier).updateRadius(tempRadius);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Safe-zone radius updated to ${tempRadius.toInt()}m.',
                    ),
                  ),
                );
              },
              child: const Text('Save Radius'),
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
