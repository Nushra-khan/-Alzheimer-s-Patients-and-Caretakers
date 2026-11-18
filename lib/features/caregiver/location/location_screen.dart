import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/app_state.dart';
import '../../auth/auth_service.dart';
import '../../profile/profile_avatar.dart';

/// OpenStreetMap tiles. Their policy asks apps to identify themselves.
const _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _tileUserAgent = 'com.alzheimers.care';

/// Shown when there is no location or safe zone yet (centre of India).
const _fallbackCenter = LatLng(20.5937, 78.9629);

class LocationScreen extends ConsumerStatefulWidget {
  const LocationScreen({super.key});

  @override
  ConsumerState<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends ConsumerState<LocationScreen> {
  final _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final patient = ref.watch(patientProvider);
    final safeZone = ref.watch(safeZoneProvider);
    final isDemoMode = ref.watch(careRepositoryProvider) == null;
    final hasSafeZone = safeZone.id.isNotEmpty;
    final reported = ref.watch(patientLocationProvider);
    // Demo data has no real position; show the demo patient at home.
    final patientPoint = reported != null
        ? LatLng(reported.latitude, reported.longitude)
        : isDemoMode && hasSafeZone
        ? LatLng(safeZone.centerLatitude, safeZone.centerLongitude)
        : null;
    final zoneCenter = hasSafeZone
        ? LatLng(safeZone.centerLatitude, safeZone.centerLongitude)
        : null;
    final status = _statusFor(patient);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              patient: patient,
              status: status,
              hasSafeZone: hasSafeZone,
              onEditZone: () => _showRadiusDialog(safeZone),
            ),
            const Divider(height: 1),
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter:
                          patientPoint ?? zoneCenter ?? _fallbackCenter,
                      initialZoom: patientPoint != null || zoneCenter != null
                          ? 16
                          : 4,
                      minZoom: 3,
                      maxZoom: 19,
                      onLongPress: (_, point) =>
                          _showSaveZoneDialog(point, safeZone),
                    ),
                    children: [
                      if (!isDemoMode)
                        TileLayer(
                          urlTemplate: _tileUrl,
                          userAgentPackageName: _tileUserAgent,
                        ),
                      if (zoneCenter != null)
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: zoneCenter,
                              radius: safeZone.radiusMeters,
                              useRadiusInMeter: true,
                              color: status.color.withValues(alpha: 0.14),
                              borderColor: status.color,
                              borderStrokeWidth: 2,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          if (zoneCenter != null)
                            Marker(
                              point: zoneCenter,
                              width: 34,
                              height: 34,
                              child: const _HomeMarker(),
                            ),
                          if (patientPoint != null)
                            Marker(
                              point: patientPoint,
                              width: 48,
                              height: 48,
                              child: _PatientMarker(
                                color: status.color,
                                name: patient.name,
                                photoUrl: patient.photoUrl,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _StatusPill(status: status),
                  ),
                  if (patientPoint != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: FloatingActionButton.small(
                        heroTag: 'center-on-patient',
                        tooltip: 'Center on patient',
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryColor,
                        onPressed: () => _mapController.move(patientPoint, 16),
                        child: const Icon(Icons.my_location_rounded),
                      ),
                    ),
                  if (patientPoint == null && !isDemoMode)
                    Center(
                      child: _MapMessage(
                        icon: Icons.location_searching_rounded,
                        text: patient.locationSharingEnabled
                            ? 'Waiting for the first location from the '
                                  "patient's phone."
                            : "Location sharing is off on the patient's "
                                  'phone. Ask them to turn it on in Settings.',
                      ),
                    ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: _ZoneCard(
                      safeZone: safeZone,
                      hasSafeZone: hasSafeZone,
                      canUsePatientLocation: patientPoint != null,
                      onUsePatientLocation: patientPoint == null
                          ? null
                          : () => _showSaveZoneDialog(patientPoint, safeZone),
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

  _LocationStatusView _statusFor(PatientModel patient) {
    if (!patient.isDeviceOnline) {
      return const _LocationStatusView(
        label: 'DEVICE OFFLINE',
        color: AppTheme.textSecondary,
        background: Color(0xFFEEEEEE),
        icon: Icons.wifi_off_rounded,
      );
    }
    return switch (patient.safeZoneStatus) {
      SafeZoneStatus.inside => const _LocationStatusView(
        label: 'SAFE ZONE',
        color: AppTheme.successGreen,
        background: AppTheme.successGreenContainer,
        icon: Icons.my_location_rounded,
      ),
      SafeZoneStatus.outside => const _LocationStatusView(
        label: 'OUTSIDE BOUNDARY',
        color: AppTheme.alertRed,
        background: AppTheme.alertRedContainer,
        icon: Icons.location_off_rounded,
      ),
      _ => const _LocationStatusView(
        label: 'STATUS UNKNOWN',
        color: AppTheme.warningOrange,
        background: AppTheme.warningOrangeContainer,
        icon: Icons.location_searching_rounded,
      ),
    };
  }

  String get _patientId => ref.read(patientProvider).id;

  Future<void> _showSaveZoneDialog(LatLng point, SafeZoneModel current) async {
    final nameController = TextEditingController(
      text: current.id.isEmpty ? 'Home' : current.name,
    );
    var radius = current.id.isEmpty
        ? 300.0
        : current.radiusMeters.clamp(50, 2000).toDouble();
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            current.id.isEmpty ? 'Create safe zone' : 'Move safe zone',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              Text(
                'Radius: ${radius.round()} m',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Slider(
                value: radius,
                min: 50,
                max: 2000,
                divisions: 39,
                activeColor: AppTheme.primaryColor,
                label: '${radius.round()} m',
                onChanged: saving
                    ? null
                    : (value) => setDialogState(() => radius = value),
              ),
              const Text(
                'You will get an alert when the patient leaves this area.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your caregiver identity and the time of this change will be recorded.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      setDialogState(() => saving = true);
                      try {
                        await ref
                            .read(safeZoneProvider.notifier)
                            .saveZone(
                              patientId: _patientId,
                              name: nameController.text,
                              latitude: point.latitude,
                              longitude: point.longitude,
                              radiusMeters: radius,
                            );
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                        if (ref.read(careRepositoryProvider) != null) {
                          ref.invalidate(careBootstrapProvider);
                        }
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Safe zone saved')),
                        );
                      } catch (error) {
                        setDialogState(() => saving = false);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(readableAuthError(error))),
                        );
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
  }

  Future<void> _showRadiusDialog(SafeZoneModel safeZone) async {
    var radius = safeZone.radiusMeters.clamp(50, 2000).toDouble();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
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
                'Radius: ${radius.round()} m',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Slider(
                value: radius,
                min: 50,
                max: 2000,
                divisions: 39,
                activeColor: AppTheme.primaryColor,
                label: '${radius.round()} m',
                onChanged: (value) => setDialogState(() => radius = value),
              ),
              const Text(
                'To move the zone, long-press the map at the new spot.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await ref
                      .read(safeZoneProvider.notifier)
                      .updateRadius(radius.roundToDouble());
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Safe zone updated')),
                  );
                } catch (error) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(readableAuthError(error))),
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

class _LocationStatusView {
  const _LocationStatusView({
    required this.label,
    required this.color,
    required this.background,
    required this.icon,
  });

  final String label;
  final Color color;
  final Color background;
  final IconData icon;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.patient,
    required this.status,
    required this.hasSafeZone,
    required this.onEditZone,
  });

  final PatientModel patient;
  final _LocationStatusView status;
  final bool hasSafeZone;
  final VoidCallback onEditZone;

  @override
  Widget build(BuildContext context) {
    final lastSync = patient.lastSyncTime;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      color: Colors.white,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: status.background,
              shape: BoxShape.circle,
            ),
            child: Icon(status.icon, color: status.color, size: 24),
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
                  lastSync == null
                      ? 'Device has not synced'
                      : patient.isDeviceOnline
                      ? 'Updated ${_formatTimeAgo(lastSync)}'
                      : 'Device offline • updated ${_formatTimeAgo(lastSync)}',
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
            onPressed: hasSafeZone ? onEditZone : null,
          ),
        ],
      ),
    );
  }
}

String _formatTimeAgo(DateTime time) {
  final difference = DateTime.now().difference(time);
  if (difference.isNegative || difference.inMinutes < 1) return 'just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  return '${difference.inDays}d ago';
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final _LocationStatusView status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: status.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: status.color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: status.color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _PatientMarker extends StatelessWidget {
  const _PatientMarker({
    required this.color,
    required this.name,
    required this.photoUrl,
  });

  final Color color;
  final String name;
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$name location',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 6),
          ],
        ),
        child: photoUrl.isEmpty
            ? const Icon(Icons.person_rounded, color: Colors.white)
            : ProfileAvatar(name: name, photoUrl: photoUrl, radius: 21),
      ),
    );
  }
}

class _HomeMarker extends StatelessWidget {
  const _HomeMarker();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: Icon(Icons.home_rounded, color: AppTheme.primaryColor, size: 22),
    );
  }
}

class _MapMessage extends StatelessWidget {
  const _MapMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Flexible(child: Text(text)),
        ],
      ),
    );
  }
}

class _ZoneCard extends StatelessWidget {
  const _ZoneCard({
    required this.safeZone,
    required this.hasSafeZone,
    required this.canUsePatientLocation,
    required this.onUsePatientLocation,
  });

  final SafeZoneModel safeZone;
  final bool hasSafeZone;
  final bool canUsePatientLocation;
  final VoidCallback? onUsePatientLocation;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hasSafeZone ? safeZone.name : 'Safe zone not configured',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              hasSafeZone
                  ? 'Radius: ${safeZone.radiusMeters.round()} m • '
                        'Long-press the map to move it.'
                  : 'An authorized caregiver must set Home. Long-press the '
                        'map where the patient lives, or use their current '
                        'location.',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            if (hasSafeZone) ...[
              const SizedBox(height: 4),
              Text(
                _configuredByText(safeZone),
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (!hasSafeZone) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: canUsePatientLocation ? onUsePatientLocation : null,
                icon: const Icon(Icons.add_location_alt_rounded),
                label: const Text("Use patient's location"),
              ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                style: TextButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 11),
                  foregroundColor: AppTheme.textSecondary,
                ),
                onPressed: () => launchUrl(
                  Uri.parse('https://www.openstreetmap.org/copyright'),
                  mode: LaunchMode.externalApplication,
                ),
                child: const Text('© OpenStreetMap contributors'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _configuredByText(SafeZoneModel safeZone) {
  final configuredAt = safeZone.configuredAt;
  if (configuredAt == null) return 'Set by ${safeZone.configuredByName}';
  final local = configuredAt.toLocal();
  final date =
      '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/${local.year}';
  return 'Set by ${safeZone.configuredByName} on $date';
}
