import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../repositories/care_repository.dart';
import 'location_permission.dart';

/// Sends the patient's location to the backend while sharing is on.
///
/// Runs as an Android foreground service (with the required notification),
/// so it keeps working while Memora is in the background. Sends an update
/// after moving 100 m, or when the interval chosen by the backend has passed:
/// 5 minutes normally, 1 minute while outside the safe zone or during an SOS.
class LocationTracker {
  LocationTracker(this._repository);

  final CareRepository _repository;
  final Battery _battery = Battery();

  static const _moveThresholdMeters = 100.0;

  StreamSubscription<Position>? _subscription;
  Timer? _heartbeat;
  Position? _latest;
  Position? _lastSent;
  DateTime? _lastSentAt;
  Duration _interval = const Duration(minutes: 5);
  bool _sending = false;
  bool _stopped = false;

  bool get isRunning => _subscription != null;

  /// Starts tracking, asking for location permission if it has not been
  /// answered yet. Returns false when it could not start (permission refused
  /// or location turned off).
  Future<bool> startIfPermitted() async {
    if (isRunning || _stopped) return isRunning;
    if (await requestLocationAccess() != LocationAccess.granted) return false;
    if (_stopped) return false;

    final settings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 25,
      intervalDuration: const Duration(minutes: 1),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'Memora is sharing your location',
        notificationText: 'Your caregiver can see where you are.',
        notificationChannelName: 'Location sharing',
        setOngoing: true,
        enableWakeLock: true,
      ),
    );
    _subscription = Geolocator.getPositionStream(locationSettings: settings)
        .listen(
          _onPosition,
          onError: (Object error) => debugPrint('Location stream: $error'),
        );
    await sendNow();
    return true;
  }

  /// Sends a fresh location immediately, for example right after an SOS.
  Future<void> sendNow() async {
    final position = await _currentPosition();
    if (position != null) {
      await _send(position);
    } else {
      _scheduleHeartbeat();
    }
  }

  Future<void> stop() async {
    _stopped = true;
    _heartbeat?.cancel();
    _heartbeat = null;
    await _subscription?.cancel();
    _subscription = null;
  }

  void _onPosition(Position position) {
    _latest = position;
    final lastSent = _lastSent;
    final lastSentAt = _lastSentAt;
    final intervalPassed =
        lastSentAt == null ||
        DateTime.now().difference(lastSentAt) >= _interval;
    final moved =
        lastSent == null ||
        Geolocator.distanceBetween(
              lastSent.latitude,
              lastSent.longitude,
              position.latitude,
              position.longitude,
            ) >=
            _moveThresholdMeters;
    if (intervalPassed || moved) unawaited(_send(position));
  }

  /// When the phone is not moving, the stream is quiet; this timer still
  /// sends a location every interval so caregivers know the phone is on.
  void _scheduleHeartbeat() {
    _heartbeat?.cancel();
    if (_stopped) return;
    _heartbeat = Timer(_interval, () => unawaited(sendNow()));
  }

  Future<Position?> _currentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } catch (error) {
      debugPrint('Current location unavailable: $error');
      return _latest ?? await Geolocator.getLastKnownPosition();
    }
  }

  Future<int?> _batteryLevel() async {
    try {
      return await _battery.batteryLevel;
    } catch (_) {
      return null;
    }
  }

  Future<void> _send(Position position) async {
    if (_sending || _stopped) return;
    _sending = true;
    try {
      final nextSeconds = await _repository.recordLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        observedAt: position.timestamp,
        batteryLevel: await _batteryLevel(),
        idempotencyKey:
            'location:${position.timestamp.microsecondsSinceEpoch}:'
            '${position.latitude}:${position.longitude}',
      );
      _lastSent = position;
      _lastSentAt = DateTime.now();
      _interval = Duration(seconds: nextSeconds.clamp(30, 900));
    } catch (error) {
      // Offline or a server error: try again at the next interval.
      debugPrint('Location update failed: $error');
    } finally {
      _sending = false;
      _scheduleHeartbeat();
    }
  }
}
