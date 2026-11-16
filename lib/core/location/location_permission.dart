import 'package:geolocator/geolocator.dart';

enum LocationAccess { granted, serviceDisabled, denied, deniedForever }

/// Asks for location permission if needed. "While using the app" is enough:
/// tracking runs in a foreground service started while the app is open.
Future<LocationAccess> requestLocationAccess() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    return LocationAccess.serviceDisabled;
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  return switch (permission) {
    LocationPermission.whileInUse ||
    LocationPermission.always => LocationAccess.granted,
    LocationPermission.deniedForever => LocationAccess.deniedForever,
    _ => LocationAccess.denied,
  };
}

/// Checks permission without showing any prompt.
Future<bool> hasLocationAccess() async {
  if (!await Geolocator.isLocationServiceEnabled()) return false;
  final permission = await Geolocator.checkPermission();
  return permission == LocationPermission.whileInUse ||
      permission == LocationPermission.always;
}

/// A short explanation and the settings screen that fixes [access].
({String message, Future<bool> Function() openSettings})? locationAccessHelp(
  LocationAccess access,
) => switch (access) {
  LocationAccess.granted => null,
  LocationAccess.serviceDisabled => (
    message: 'Turn on Location on your phone to share where you are.',
    openSettings: Geolocator.openLocationSettings,
  ),
  LocationAccess.denied => (
    message: 'Memora needs location permission to share where you are.',
    openSettings: Geolocator.openAppSettings,
  ),
  LocationAccess.deniedForever => (
    message: 'Allow location for Memora in your phone settings.',
    openSettings: Geolocator.openAppSettings,
  ),
};
