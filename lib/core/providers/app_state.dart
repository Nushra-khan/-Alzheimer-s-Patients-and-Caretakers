import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/auth_service.dart';
import '../config/app_config.dart';
import '../models/models.dart';
import '../repositories/care_repository.dart';
import '../repositories/supabase_care_repository.dart';

final careRepositoryProvider = Provider<CareRepository?>((ref) {
  if (!AppConfig.hasSupabaseConfiguration) return null;
  return SupabaseCareRepository(Supabase.instance.client);
});

class SessionNotifier extends StateNotifier<AppSession> {
  SessionNotifier() : super(const AppSession.signedOut()) {
    if (AppConfig.hasSupabaseConfiguration) {
      _authService = AuthService(Supabase.instance.client);
      _authSubscription = _authService!.authStateChanges.listen((authState) {
        if (authState.session == null) {
          state = const AppSession.signedOut();
        } else {
          unawaited(refreshAuthenticatedSession());
        }
      });

      if (_authService!.currentSession != null) {
        unawaited(refreshAuthenticatedSession());
      }
    }
  }

  AuthService? _authService;
  StreamSubscription<AuthState>? _authSubscription;

  AuthService get _configuredAuth =>
      _authService ??
      (throw StateError(
        'Supabase is not configured. Start the app with the staging config.',
      ));

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final role = await _configuredAuth.signInWithPassword(
      email: email,
      password: password,
    );
    establishAuthenticatedSession(role);
  }

  Future<bool> signUp({
    required String displayName,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final signedIn = await _configuredAuth.signUp(
      displayName: displayName,
      email: email,
      password: password,
      role: role,
    );
    if (signedIn) await refreshAuthenticatedSession();
    return signedIn;
  }

  Future<void> signInWithGoogle() => _configuredAuth.signInWithGoogle();

  Future<void> refreshAuthenticatedSession() async {
    try {
      final role = await _configuredAuth.resolveCurrentUserRole();
      establishAuthenticatedSession(role);
    } catch (_) {
      state = const AppSession.signedOut();
    }
  }

  void establishAuthenticatedSession(UserRole role) {
    state = AppSession.authenticated(role);
  }

  Future<void> signOut() async {
    if (_authService?.currentSession != null) {
      await _authService!.signOut();
    }
    state = const AppSession.signedOut();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

final sessionProvider = StateNotifierProvider<SessionNotifier, AppSession>(
  (ref) => SessionNotifier(),
);

// Patient Profile State Provider
class PatientNotifier extends StateNotifier<PatientModel> {
  PatientNotifier({bool useDemoData = true, this._repository})
    : super(
        useDemoData
            ? PatientModel(
                id: 'p-101',
                name: 'Ramesh Sharma',
                dateOfBirth: DateTime(1954, 1, 15),
                photoUrl: '',
                batteryLevel: 84,
                isDeviceOnline: true,
                locationSharingEnabled: true,
                lastSyncTime: DateTime.now().subtract(
                  const Duration(minutes: 3),
                ),
                safeZoneStatus: SafeZoneStatus.inside,
                lastKnownLocationName: 'Home (Vasant Vihar, New Delhi)',
              )
            : PatientModel(
                id: '',
                name: 'Patient',
                dateOfBirth: DateTime.now(),
                photoUrl: '',
                batteryLevel: 0,
                isDeviceOnline: false,
                locationSharingEnabled: false,
                lastSyncTime: DateTime.now(),
                safeZoneStatus: SafeZoneStatus.unknown,
                lastKnownLocationName: 'Location unavailable',
              ),
      );

  final CareRepository? _repository;

  void replace(PatientModel patient) => state = patient;

  Future<void> setLocationSharing(bool enabled) async {
    await _repository?.setLocationSharing(
      patientId: state.id,
      enabled: enabled,
    );
    state = state.copyWith(locationSharingEnabled: enabled);
  }

  void updateSafeZoneStatus(SafeZoneStatus status) {
    state = state.copyWith(
      safeZoneStatus: status,
      lastSyncTime: DateTime.now(),
    );
  }
}

final patientProvider = StateNotifierProvider<PatientNotifier, PatientModel>((
  ref,
) {
  return PatientNotifier(
    useDemoData: ref.watch(careRepositoryProvider) == null,
    repository: ref.watch(careRepositoryProvider),
  );
});

// Medications Provider
DateTime _todayAt(int hour, [int minute = 0]) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, hour, minute);
}

class DoseInstanceNotifier extends StateNotifier<List<DoseInstance>> {
  DoseInstanceNotifier([this._repository])
    : super(
        _repository == null
            ? [
                DoseInstance(
                  id: 'dose-1',
                  medicationId: 'med-1',
                  medicineName: 'Donepezil',
                  dosage: '10 mg • 1 Tablet',
                  instructions: 'Take with evening meal',
                  scheduledFor: _todayAt(20),
                  status: DoseStatus.scheduled,
                ),
                DoseInstance(
                  id: 'dose-2',
                  medicationId: 'med-2',
                  medicineName: 'Memantine HCl',
                  dosage: '5 mg • 1 Tablet',
                  instructions: 'Take with morning breakfast',
                  scheduledFor: _todayAt(9),
                  status: DoseStatus.reportedTaken,
                  reportedAt: _todayAt(9, 5),
                ),
                DoseInstance(
                  id: 'dose-3',
                  medicationId: 'med-3',
                  medicineName: 'Vitamin B12 & D3',
                  dosage: '1 Capsule',
                  instructions: 'After lunch with glass of water',
                  scheduledFor: _todayAt(14),
                  status: DoseStatus.scheduled,
                ),
              ]
            : const [],
      );

  final CareRepository? _repository;

  void replace(List<DoseInstance> doses) => state = doses;

  Future<void> reportDoseTaken(String id) async {
    await _repository?.reportDoseTaken(
      doseInstanceId: id,
      idempotencyKey: 'dose:$id:reported',
      reportedAt: DateTime.now(),
    );
    state = state.map((dose) {
      if (dose.id == id && !dose.isReportedTaken) {
        return dose.copyWith(
          status: DoseStatus.reportedTaken,
          reportedAt: DateTime.now(),
        );
      }
      return dose;
    }).toList();
  }

  Future<void> addDose(DoseInstance dose, {required String patientId}) async {
    final persisted = await _repository?.createMedicationSchedule(
      patientId: patientId,
      medicineName: dose.medicineName,
      dosage: dose.dosage,
      instructions: dose.instructions,
      scheduledFor: dose.scheduledFor,
      timezone: AppConfig.careTimezone,
      idempotencyKey: 'schedule:${dose.id}',
    );
    state = [...state, persisted ?? dose];
  }
}

final doseInstancesProvider =
    StateNotifierProvider<DoseInstanceNotifier, List<DoseInstance>>((ref) {
      return DoseInstanceNotifier(ref.watch(careRepositoryProvider));
    });

// Routine Items Provider
class RoutineNotifier extends StateNotifier<List<RoutineItem>> {
  RoutineNotifier({bool useDemoData = true, this._repository})
    : super(
        useDemoData
            ? [
                RoutineItem(
                  id: 'r-1',
                  title: 'Morning Garden Walk',
                  subtitle: '15-minute gentle walk in garden',
                  time: '07:30 AM',
                  isCompleted: true,
                ),
                RoutineItem(
                  id: 'r-2',
                  title: 'Hydration — Hydrate Water',
                  subtitle: 'Drink 2 glasses of fresh water',
                  time: '11:00 AM',
                  isCompleted: true,
                ),
                RoutineItem(
                  id: 'r-3',
                  title: 'Memory Card Game / Music',
                  subtitle: 'Listen to favorite classic melodies',
                  time: '04:00 PM',
                  isCompleted: false,
                ),
                RoutineItem(
                  id: 'r-4',
                  title: 'Evening Rest & Breathing',
                  subtitle: 'Quiet time in living room',
                  time: '06:30 PM',
                  isCompleted: false,
                ),
              ]
            : const [],
      );

  final CareRepository? _repository;

  void replace(List<RoutineItem> routines) => state = routines;

  Future<void> toggleRoutine(String id) async {
    final routine = state.where((item) => item.id == id).firstOrNull;
    if (routine == null) return;
    await _repository?.setRoutineCompleted(
      routineId: id,
      completed: !routine.isCompleted,
      localDate: DateTime.now(),
    );
    state = state.map((item) {
      if (item.id == id) {
        return item.copyWith(isCompleted: !item.isCompleted);
      }
      return item;
    }).toList();
  }
}

final routinesProvider =
    StateNotifierProvider<RoutineNotifier, List<RoutineItem>>((ref) {
      return RoutineNotifier(
        useDemoData: ref.watch(careRepositoryProvider) == null,
        repository: ref.watch(careRepositoryProvider),
      );
    });

// Alerts Provider
class AlertNotifier extends StateNotifier<List<AlertModel>> {
  AlertNotifier([this._repository])
    : super(
        _repository == null
            ? [
                AlertModel(
                  id: 'alt-101',
                  patientId: 'p-101',
                  patientName: 'Ramesh Sharma',
                  type: AlertType.overdueDose,
                  severity: AlertSeverity.warning,
                  title: 'Overdue Dose: Donepezil 10mg',
                  description:
                      'Dose scheduled for 08:00 PM has not been reported taken after 30-min grace period.',
                  timestamp: DateTime.now().subtract(
                    const Duration(minutes: 45),
                  ),
                  status: AlertStatus.active,
                ),
                AlertModel(
                  id: 'alt-102',
                  patientId: 'p-101',
                  patientName: 'Ramesh Sharma',
                  type: AlertType.safeZoneExit,
                  severity: AlertSeverity.critical,
                  title: 'Safe Zone Boundary Advisory',
                  description:
                      'Patient updated location 150m outside Home Safe Zone boundary (Vasant Vihar).',
                  timestamp: DateTime.now().subtract(const Duration(hours: 2)),
                  status: AlertStatus.acknowledged,
                  acknowledgedBy: 'Dr. Sunita Sharma (Caregiver)',
                  acknowledgedAt: DateTime.now().subtract(
                    const Duration(hours: 1, minutes: 50),
                  ),
                ),
                AlertModel(
                  id: 'alt-103',
                  patientId: 'p-101',
                  patientName: 'Ramesh Sharma',
                  type: AlertType.sos,
                  severity: AlertSeverity.critical,
                  title: 'SOS Emergency Button Activated',
                  description:
                      'Patient pressed emergency SOS button from home screen.',
                  timestamp: DateTime.now().subtract(
                    const Duration(days: 1, hours: 3),
                  ),
                  status: AlertStatus.resolved,
                  acknowledgedBy: 'Anil Sharma (Son)',
                  acknowledgedAt: DateTime.now().subtract(
                    const Duration(days: 1, hours: 2, minutes: 55),
                  ),
                  resolvedAt: DateTime.now().subtract(
                    const Duration(days: 1, hours: 2, minutes: 30),
                  ),
                ),
              ]
            : const [],
      );

  final CareRepository? _repository;

  void replace(List<AlertModel> alerts) => state = alerts;

  Future<void> triggerSOSAlert({
    required String patientId,
    required String patientName,
  }) async {
    final occurredAt = DateTime.now();
    final localKey = occurredAt.microsecondsSinceEpoch.toString();
    final backendId = await _repository?.createSos(
      patientId: patientId,
      idempotencyKey: 'sos:$patientId:$localKey',
      occurredAt: occurredAt,
    );
    final sosAlert = AlertModel(
      id: backendId ?? 'alt-$localKey',
      patientId: patientId,
      patientName: patientName,
      type: AlertType.sos,
      severity: AlertSeverity.critical,
      title: '🚨 EMERGENCY SOS ACTIVATED',
      description:
          'Patient pressed the emergency SOS button. Immediate caregiver acknowledgement required.',
      timestamp: occurredAt,
      status: AlertStatus.active,
    );
    state = [sosAlert, ...state];
  }

  Future<void> acknowledgeAlert(String alertId, String caregiverName) async {
    await _repository?.acknowledgeAlert(
      alertId: alertId,
      idempotencyKey: 'alert:$alertId:acknowledged',
    );
    state = state.map((alt) {
      if (alt.id == alertId) {
        return alt.copyWith(
          status: AlertStatus.acknowledged,
          acknowledgedBy: caregiverName,
          acknowledgedAt: DateTime.now(),
        );
      }
      return alt;
    }).toList();
  }

  Future<void> resolveAlert(String alertId) async {
    await _repository?.resolveAlert(
      alertId: alertId,
      resolutionNote: 'Resolved in Memora',
      idempotencyKey: 'alert:$alertId:resolved',
    );
    state = state.map((alt) {
      if (alt.id == alertId) {
        return alt.copyWith(
          status: AlertStatus.resolved,
          resolvedAt: DateTime.now(),
        );
      }
      return alt;
    }).toList();
  }
}

final alertsProvider = StateNotifierProvider<AlertNotifier, List<AlertModel>>((
  ref,
) {
  return AlertNotifier(ref.watch(careRepositoryProvider));
});

enum CareBootstrapStatus { ready, needsPatient }

Future<T> _withFallback<T>(Future<T> request, T fallback) async {
  try {
    return await request;
  } catch (error, stackTrace) {
    debugPrint('Optional care data failed to load: $error');
    debugPrintStack(stackTrace: stackTrace);
    return fallback;
  }
}

final careBootstrapProvider = FutureProvider<CareBootstrapStatus>((ref) async {
  final session = ref.watch(sessionProvider);
  final repository = ref.watch(careRepositoryProvider);
  if (!session.isAuthenticated || repository == null) {
    return CareBootstrapStatus.ready;
  }

  late final String patientId;
  try {
    patientId = await repository.resolveAccessiblePatientId();
  } on NoPatientConnectionException {
    if (session.canAccessCaregiver) return CareBootstrapStatus.needsPatient;
    rethrow;
  }
  final values = await Future.wait<Object?>([
    repository.loadPatient(patientId),
    _withFallback<List<DoseInstance>>(
      repository.loadTodayDoses(patientId, DateTime.now()),
      const [],
    ),
    _withFallback<List<AlertModel>>(repository.loadAlerts(patientId), const []),
    _withFallback<List<RoutineItem>>(
      repository.loadRoutines(patientId),
      const [],
    ),
    _withFallback<List<CaregiverModel>>(
      repository.loadCaregivers(patientId),
      const [],
    ),
    _withFallback<List<EmergencyContact>>(
      repository.loadEmergencyContacts(patientId),
      const [],
    ),
    _withFallback<SafeZoneModel?>(repository.loadSafeZone(patientId), null),
  ]);
  ref.read(patientProvider.notifier).replace(values[0] as PatientModel);
  ref
      .read(doseInstancesProvider.notifier)
      .replace(values[1] as List<DoseInstance>);
  ref.read(alertsProvider.notifier).replace(values[2] as List<AlertModel>);
  ref.read(routinesProvider.notifier).replace(values[3] as List<RoutineItem>);
  ref
      .read(caregiversProvider.notifier)
      .replace(values[4] as List<CaregiverModel>);
  ref
      .read(emergencyContactsProvider.notifier)
      .replace(values[5] as List<EmergencyContact>);
  final safeZone = values[6] as SafeZoneModel?;
  if (safeZone != null) {
    ref.read(safeZoneProvider.notifier).replace(safeZone);
  }
  if (session.canAccessCaregiver) {
    final caregiver = await _withFallback<CaregiverModel?>(
      repository.loadCurrentCaregiver(),
      null,
    );
    if (caregiver != null) {
      ref.read(currentCaregiverProvider.notifier).replace(caregiver);
    }
  }
  return CareBootstrapStatus.ready;
});

final careRealtimeProvider = StreamProvider<void>((ref) async* {
  final session = ref.watch(sessionProvider);
  final repository = ref.watch(careRepositoryProvider);
  if (!session.isAuthenticated || repository == null) return;

  late final String patientId;
  try {
    patientId = await repository.resolveAccessiblePatientId();
  } on NoPatientConnectionException {
    return;
  }

  await for (final _ in repository.watchCareChanges(patientId)) {
    ref.invalidate(careBootstrapProvider);
    yield null;
  }
});

// Safe Zone Provider
class SafeZoneNotifier extends StateNotifier<SafeZoneModel> {
  SafeZoneNotifier({bool useDemoData = true, this._repository})
    : super(
        useDemoData
            ? SafeZoneModel(
                id: 'sz-1',
                name: 'Home Safe Radius (Vasant Vihar)',
                radiusMeters: 300,
                centerLatitude: 28.5562,
                centerLongitude: 77.1610,
                isPatientInside: true,
                lastChecked: DateTime.now().subtract(
                  const Duration(minutes: 5),
                ),
              )
            : SafeZoneModel(
                id: '',
                name: 'Safe zone',
                radiusMeters: 300,
                centerLatitude: 0,
                centerLongitude: 0,
                isPatientInside: true,
                lastChecked: DateTime.now(),
              ),
      );

  final CareRepository? _repository;

  void replace(SafeZoneModel safeZone) => state = safeZone;

  Future<void> updateRadius(double newRadius) async {
    await _repository?.updateSafeZoneRadius(
      safeZoneId: state.id,
      radiusMeters: newRadius,
    );
    state = state.copyWith(radiusMeters: newRadius);
  }

  void togglePatientInside() {
    state = state.copyWith(
      isPatientInside: !state.isPatientInside,
      lastChecked: DateTime.now(),
    );
  }
}

final safeZoneProvider = StateNotifierProvider<SafeZoneNotifier, SafeZoneModel>(
  (ref) {
    return SafeZoneNotifier(
      useDemoData: ref.watch(careRepositoryProvider) == null,
      repository: ref.watch(careRepositoryProvider),
    );
  },
);

// Caregivers & Emergency Contacts List
class CaregiversNotifier extends StateNotifier<List<CaregiverModel>> {
  CaregiversNotifier({bool useDemoData = true})
    : super(
        useDemoData
            ? [
                CaregiverModel(
                  id: 'c-1',
                  name: 'Sunita Sharma',
                  relationship: 'Primary Caregiver (Spouse)',
                  phone: '+91 98765 43210',
                  email: 'sunita.sharma@example.com',
                  isPrimary: true,
                ),
                CaregiverModel(
                  id: 'c-2',
                  name: 'Anil Sharma',
                  relationship: 'Secondary Caregiver (Son)',
                  phone: '+91 98123 45678',
                  email: 'anil.sharma@example.com',
                  isPrimary: false,
                ),
              ]
            : const [],
      );

  void replace(List<CaregiverModel> caregivers) => state = caregivers;
}

final caregiversProvider =
    StateNotifierProvider<CaregiversNotifier, List<CaregiverModel>>((ref) {
      return CaregiversNotifier(
        useDemoData: ref.watch(careRepositoryProvider) == null,
      );
    });

class CurrentCaregiverNotifier extends StateNotifier<CaregiverModel> {
  CurrentCaregiverNotifier()
    : super(
        CaregiverModel(
          id: '',
          name: 'Caregiver',
          relationship: 'Caregiver',
          phone: '',
          email: '',
          isPrimary: false,
        ),
      );

  void replace(CaregiverModel caregiver) => state = caregiver;
}

final currentCaregiverProvider =
    StateNotifierProvider<CurrentCaregiverNotifier, CaregiverModel>((ref) {
      return CurrentCaregiverNotifier();
    });

class EmergencyContactsNotifier extends StateNotifier<List<EmergencyContact>> {
  EmergencyContactsNotifier({bool useDemoData = true})
    : super(
        useDemoData
            ? [
                EmergencyContact(
                  name: 'Sunita Sharma (Spouse)',
                  phone: '+91 98765 43210',
                  relationship: 'Primary Caregiver',
                ),
                EmergencyContact(
                  name: 'Anil Sharma (Son)',
                  phone: '+91 98123 45678',
                  relationship: 'Family Member',
                ),
                EmergencyContact(
                  name: 'Dr. V. K. Gupta (Neurologist)',
                  phone: '+91 11 2614 9999',
                  relationship: 'Attending Physician',
                ),
              ]
            : const [],
      );

  void replace(List<EmergencyContact> contacts) => state = contacts;
}

final emergencyContactsProvider =
    StateNotifierProvider<EmergencyContactsNotifier, List<EmergencyContact>>((
      ref,
    ) {
      return EmergencyContactsNotifier(
        useDemoData: ref.watch(careRepositoryProvider) == null,
      );
    });
