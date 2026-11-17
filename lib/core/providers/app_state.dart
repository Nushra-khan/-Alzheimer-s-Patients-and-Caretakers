import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/auth_service.dart';
import '../config/app_config.dart';
import '../location/location_tracker.dart';
import '../models/models.dart';
import '../repositories/care_repository.dart';
import '../repositories/supabase_care_repository.dart';

final careRepositoryProvider = Provider<CareRepository?>((ref) {
  if (!AppConfig.hasSupabaseConfiguration) return null;
  return SupabaseCareRepository(Supabase.instance.client);
});

final passwordRecoveryProvider = StateProvider<bool>((ref) => false);

/// Role picked on the sign-up screen before choosing Google, used to
/// preselect the choice on the role screen after Google returns.
final pendingSignupRoleProvider = StateProvider<UserRole?>((ref) => null);

class SessionNotifier extends StateNotifier<AppSession> {
  SessionNotifier({void Function(bool)? onPasswordRecovery})
    : _onPasswordRecovery = onPasswordRecovery ?? _ignorePasswordRecovery,
      super(const AppSession.signedOut()) {
    if (AppConfig.hasSupabaseConfiguration) {
      _authService = AuthService(Supabase.instance.client);
      _authSubscription = _authService!.authStateChanges.listen((authState) {
        if (authState.event == AuthChangeEvent.passwordRecovery) {
          _onPasswordRecovery(true);
          return;
        }
        if (authState.session == null) {
          _onPasswordRecovery(false);
          state = const AppSession.signedOut();
          return;
        }
        // A refreshed token does not change who is signed in. Re-checking the
        // role here used to rebuild the router and reload all care data
        // about once an hour and whenever the app came back to the front.
        if (authState.event == AuthChangeEvent.tokenRefreshed &&
            state.role != null) {
          return;
        }
        unawaited(refreshAuthenticatedSession());
      });

      if (_authService!.currentSession != null) {
        // Show a loading screen instead of flashing the login screen while
        // the saved sign-in is checked.
        state = const AppSession.restoring();
        unawaited(refreshAuthenticatedSession());
      }
    }
  }

  AuthService? _authService;
  StreamSubscription<AuthState>? _authSubscription;
  final void Function(bool) _onPasswordRecovery;

  static void _ignorePasswordRecovery(bool _) {}

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
    _applyRole(role);
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

  bool get isEmailAccount => _authService?.isEmailAccount ?? false;

  Future<void> changePassword(String newPassword) =>
      _configuredAuth.changePassword(newPassword);

  /// Deletes the account on the server, then signs out on this phone.
  Future<void> deleteAccount() async {
    await _configuredAuth.deleteAccount();
    state = const AppSession.signedOut();
  }

  Future<void> resendConfirmation(String email) =>
      _configuredAuth.resendConfirmation(email);

  Future<void> sendPasswordReset(String email) =>
      _configuredAuth.sendPasswordReset(email);

  Future<void> updatePassword(String password) async {
    await _configuredAuth.updatePassword(password);
    await _configuredAuth.signOut();
    _onPasswordRecovery(false);
    state = const AppSession.signedOut();
  }

  Future<void> cancelPasswordRecovery() async {
    if (_authService?.currentSession != null) {
      await _authService!.signOut();
    }
    _onPasswordRecovery(false);
    state = const AppSession.signedOut();
  }

  Future<void> refreshAuthenticatedSession() async {
    try {
      final role = await _configuredAuth.resolveCurrentUserRole();
      _applyRole(role);
    } catch (error) {
      final isNetworkFailure =
          error is AuthRetryableFetchException ||
          (error is! AuthException && error is! PostgrestException);
      if (!isNetworkFailure) {
        state = const AppSession.signedOut();
        return;
      }
      // The backend could not be reached (for example, the phone is offline).
      // Keep a still-valid Supabase session signed in using the role stored on
      // the account; RLS still decides what data the user can load.
      debugPrint('Unable to confirm account role: $error');
      final role = _configuredAuth.roleFromAccountMetadata;
      if (role == null) {
        state = const AppSession.signedOut();
      } else {
        _applyRole(role);
      }
    }
  }

  int _generation = 0;

  String? get _currentUserId => _authService?.currentUserId;

  /// Starts a fresh session after an explicit sign-in. Always clears care
  /// data left from whoever used the app before.
  void establishAuthenticatedSession(UserRole role) {
    state = AppSession.authenticated(
      role,
      userId: _currentUserId,
      generation: ++_generation,
    );
  }

  /// Applies a role found when re-checking the session. Keeps the current
  /// session (and its loaded data) when it is the same person and role, so
  /// routine token refreshes do not reload everything.
  void _applyRole(UserRole? role) {
    final userId = _currentUserId;
    if (state.isAuthenticated &&
        state.role == role &&
        state.userId == userId) {
      return;
    }
    _generation++;
    state = role == null
        ? AppSession.needsRole(userId: userId, generation: _generation)
        : AppSession.authenticated(
            role,
            userId: userId,
            generation: _generation,
          );
  }

  /// Completes setup for an account that signed in without a role.
  Future<void> chooseRole(UserRole role) async {
    final chosen = await _configuredAuth.chooseRole(role);
    establishAuthenticatedSession(chosen);
  }

  Future<void> signOut() async {
    try {
      if (_authService?.currentSession != null) {
        await _authService!.signOut();
      }
    } finally {
      state = const AppSession.signedOut();
    }
  }

  // StateNotifier notifies listeners on every assignment, even of an equal
  // value. Skipping equal sessions keeps the router and care data stable.
  @override
  bool updateShouldNotify(AppSession old, AppSession current) =>
      old != current;

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

final sessionProvider = StateNotifierProvider<SessionNotifier, AppSession>(
  (ref) => SessionNotifier(
    onPasswordRecovery: (isActive) =>
        ref.read(passwordRecoveryProvider.notifier).state = isActive,
  ),
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
                batteryLevel: null,
                isDeviceOnline: false,
                locationSharingEnabled: false,
                lastSyncTime: null,
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
  ref.watch(sessionProvider);
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

/// Sample doses shown when the app runs without Supabase (demo mode).
List<DoseInstance> _demoDoses() => [
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
];

class DoseInstanceNotifier extends StateNotifier<List<DoseInstance>> {
  DoseInstanceNotifier([this._repository])
    : super(_repository == null ? _demoDoses() : const []);

  final CareRepository? _repository;

  /// Request keys for dose updates that have not been confirmed yet. A retry
  /// of the same action reuses its key so the backend applies it only once.
  final _pendingDoseActions = <String, ({String key, DateTime occurredAt})>{};

  void replace(List<DoseInstance> doses) => state = doses;

  Future<void> reportDoseTaken(String id) async {
    await _setDoseStatus(id, DoseStatus.reportedTaken);
  }

  Future<void> skipDose(String id) async {
    await _setDoseStatus(id, DoseStatus.skipped);
  }

  Future<void> correctDose(String id) async {
    await _setDoseStatus(id, DoseStatus.scheduled);
  }

  Future<void> _setDoseStatus(String id, DoseStatus status) async {
    final action = 'dose:$id:${status.name}';
    final pending = _pendingDoseActions.putIfAbsent(action, () {
      final now = DateTime.now();
      return (key: '$action:${now.microsecondsSinceEpoch}', occurredAt: now);
    });
    final occurredAt = pending.occurredAt;
    await _repository?.updateDoseStatus(
      doseInstanceId: id,
      status: status,
      idempotencyKey: pending.key,
      occurredAt: occurredAt,
    );
    // Any confirmed change supersedes earlier unconfirmed actions on this dose.
    _pendingDoseActions.removeWhere((key, _) => key.startsWith('dose:$id:'));
    state = state.map((dose) {
      if (dose.id != id) return dose;
      return dose.copyWith(
        status: status,
        reportedAt: status == DoseStatus.reportedTaken ? occurredAt : null,
        clearReportedAt: status != DoseStatus.reportedTaken,
      );
    }).toList();
  }

  /// Creates a daily medication. Returns the saved first dose. It is added
  /// to today's list only when it falls on today.
  Future<DoseInstance> addDose(
    DoseInstance dose, {
    required String patientId,
  }) async {
    final persisted =
        await _repository?.createMedicationSchedule(
          patientId: patientId,
          medicineName: dose.medicineName,
          dosage: dose.dosage,
          instructions: dose.instructions,
          scheduledFor: dose.scheduledFor,
          timezone: AppConfig.careTimezone,
          idempotencyKey: 'schedule:${dose.id}',
        ) ??
        dose;
    if (_isToday(persisted.scheduledFor)) {
      state = [...state, persisted]
        ..sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
    }
    return persisted;
  }

  /// Moves today's pending dose of a medication to a new time.
  void moveTodayDose(String medicationId, int hour, int minute) {
    state =
        state.map((dose) {
          if (dose.medicationId != medicationId || !dose.isPending) {
            return dose;
          }
          final at = dose.scheduledFor;
          return dose.copyWith(
            scheduledFor: DateTime(at.year, at.month, at.day, hour, minute),
            status: DoseStatus.scheduled,
          );
        }).toList()
        ..sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
  }

  static bool _isToday(DateTime time) {
    final now = DateTime.now();
    return time.year == now.year &&
        time.month == now.month &&
        time.day == now.day;
  }

  Future<void> deactivateMedication({
    required String patientId,
    required String medicationId,
  }) async {
    await _repository?.deactivateMedication(
      patientId: patientId,
      medicationId: medicationId,
    );
    state = state.where((dose) => dose.medicationId != medicationId).toList();
  }

  Future<void> updateMedicationDetails({
    required String patientId,
    required String medicationId,
    required String medicineName,
    required String dosage,
    required String instructions,
  }) async {
    await _repository?.updateMedicationDetails(
      patientId: patientId,
      medicationId: medicationId,
      medicineName: medicineName,
      dosage: dosage,
      instructions: instructions,
    );
    state = state.map((dose) {
      if (dose.medicationId != medicationId) return dose;
      return dose.copyWith(
        medicineName: medicineName.trim(),
        dosage: dosage.trim(),
        instructions: instructions.trim(),
      );
    }).toList();
  }
}

final doseInstancesProvider =
    StateNotifierProvider<DoseInstanceNotifier, List<DoseInstance>>((ref) {
      ref.watch(sessionProvider);
      return DoseInstanceNotifier(ref.watch(careRepositoryProvider));
    });

/// The patient's active medications, whether or not a dose is due today.
/// The caregiver's Schedule tab lists these, so a medication that starts
/// tomorrow can still be edited or stopped.
class MedicationsNotifier extends StateNotifier<List<MedicationModel>> {
  MedicationsNotifier({
    List<MedicationModel> initial = const [],
    this._repository,
  }) : super(initial);

  final CareRepository? _repository;

  void replace(List<MedicationModel> medications) =>
      state = _sorted(medications);

  void add(MedicationModel medication) => state = _sorted([
    ...state.where((m) => m.id != medication.id),
    medication,
  ]);

  void remove(String medicationId) =>
      state = state.where((m) => m.id != medicationId).toList();

  void updateDetails({
    required String medicationId,
    required String name,
    required String dosage,
    required String instructions,
  }) {
    state = state
        .map(
          (m) => m.id == medicationId
              ? m.copyWith(
                  name: name.trim(),
                  dosage: dosage.trim(),
                  instructions: instructions.trim(),
                )
              : m,
        )
        .toList();
  }

  Future<void> updateTime({
    required String patientId,
    required String medicationId,
    required int hour,
    required int minute,
  }) async {
    await _repository?.updateMedicationTime(
      patientId: patientId,
      medicationId: medicationId,
      hour: hour,
      minute: minute,
      timezone: AppConfig.careTimezone,
    );
    state = _sorted(
      state
          .map(
            (m) => m.id == medicationId
                ? m.copyWith(hour: hour, minute: minute)
                : m,
          )
          .toList(),
    );
  }

  static List<MedicationModel> _sorted(List<MedicationModel> list) =>
      [...list]..sort((a, b) => a.minutesOfDay.compareTo(b.minutesOfDay));
}

final medicationsProvider =
    StateNotifierProvider<MedicationsNotifier, List<MedicationModel>>((ref) {
      ref.watch(sessionProvider);
      final repository = ref.watch(careRepositoryProvider);
      if (repository != null) {
        return MedicationsNotifier(repository: repository);
      }
      // Demo mode: one medication per demo dose.
      final today = DateTime.now();
      return MedicationsNotifier(
        initial: [
          for (final dose in _demoDoses())
            MedicationModel(
              id: dose.medicationId,
              name: dose.medicineName,
              dosage: dose.dosage,
              instructions: dose.instructions,
              hour: dose.scheduledFor.hour,
              minute: dose.scheduledFor.minute,
              startsOn: DateTime(today.year, today.month, today.day),
            ),
        ],
      );
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

  Future<void> addRoutine(
    RoutineItem routine, {
    required String patientId,
    required DateTime scheduledFor,
  }) async {
    final persisted = await _repository?.createRoutineSchedule(
      patientId: patientId,
      title: routine.title,
      description: routine.subtitle,
      scheduledFor: scheduledFor,
      timezone: AppConfig.careTimezone,
      idempotencyKey: 'routine:${routine.id}',
    );
    state = [...state, persisted ?? routine];
  }

  Future<void> updateRoutine({
    required String routineId,
    required String title,
    required String description,
    required String displayTime,
    required DateTime scheduledFor,
  }) async {
    await _repository?.updateRoutineSchedule(
      routineId: routineId,
      title: title,
      description: description,
      scheduledFor: scheduledFor,
      timezone: AppConfig.careTimezone,
    );
    state = state.map((routine) {
      if (routine.id != routineId) return routine;
      return routine.copyWith(
        title: title.trim(),
        subtitle: description.trim(),
        time: displayTime,
      );
    }).toList();
  }

  Future<void> deactivateRoutine(String routineId) async {
    await _repository?.deactivateRoutineSchedule(routineId: routineId);
    state = state.where((routine) => routine.id != routineId).toList();
  }

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
      ref.watch(sessionProvider);
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

  /// The SOS that has not been confirmed by the backend yet. Pressing SOS
  /// again after a failure retries the same alert instead of creating another.
  ({String patientId, String key, DateTime occurredAt})? _pendingSos;

  void replace(List<AlertModel> alerts) => state = alerts;

  Future<void> triggerSOSAlert({
    required String patientId,
    required String patientName,
  }) async {
    var pending = _pendingSos;
    if (pending == null || pending.patientId != patientId) {
      final now = DateTime.now();
      pending = (
        patientId: patientId,
        key: 'sos:$patientId:${now.microsecondsSinceEpoch}',
        occurredAt: now,
      );
      _pendingSos = pending;
    }
    final occurredAt = pending.occurredAt;
    final backendId = await _repository?.createSos(
      patientId: patientId,
      idempotencyKey: pending.key,
      occurredAt: occurredAt,
    );
    _pendingSos = null;
    final sosAlert = AlertModel(
      id: backendId ?? 'alt-${occurredAt.microsecondsSinceEpoch}',
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
    state = [sosAlert, ...state.where((alert) => alert.id != sosAlert.id)];
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
  ref.watch(sessionProvider);
  return AlertNotifier(ref.watch(careRepositoryProvider));
});

enum CareBootstrapStatus { ready, needsPatient }

Future<T> _withFallback<T>(Future<T> request, T fallback) async {
  try {
    return await request;
  } catch (error) {
    debugPrint('Optional care data failed to load: $error');
    return fallback;
  }
}

final careBootstrapProvider = FutureProvider<CareBootstrapStatus>((ref) async {
  final session = ref.watch(sessionProvider);
  final repository = ref.watch(careRepositoryProvider);
  if (session.role == null || repository == null) {
    return CareBootstrapStatus.ready;
  }

  late final String patientId;
  try {
    patientId = await repository.resolveAccessiblePatientId();
  } on NoPatientConnectionException {
    if (!session.canAccessCaregiver) rethrow;
    // Load the caregiver's own profile so the Profile tab works before a
    // patient is connected.
    final caregiver = await _withFallback<CaregiverModel?>(
      repository.loadCurrentCaregiver(),
      null,
    );
    if (caregiver != null) {
      ref.read(currentCaregiverProvider.notifier).replace(caregiver);
    }
    return CareBootstrapStatus.needsPatient;
  }
  final values = await Future.wait<Object?>([
    repository.loadPatient(patientId),
    _withFallback<List<DoseInstance>>(
      repository.loadTodayDoses(patientId, DateTime.now()),
      ref.read(doseInstancesProvider),
    ),
    _withFallback<List<AlertModel>>(
      repository.loadAlerts(patientId),
      ref.read(alertsProvider),
    ),
    _withFallback<List<RoutineItem>>(
      repository.loadRoutines(patientId),
      ref.read(routinesProvider),
    ),
    _withFallback<List<CaregiverModel>>(
      repository.loadCaregivers(patientId),
      ref.read(caregiversProvider),
    ),
    _withFallback<List<EmergencyContact>>(
      repository.loadEmergencyContacts(patientId),
      ref.read(emergencyContactsProvider),
    ),
    _withFallback<LocationStatus?>(
      repository.loadLocationStatus(patientId),
      null,
    ),
    _withFallback<List<MedicationModel>>(
      repository.loadMedications(patientId),
      ref.read(medicationsProvider),
    ),
    _withFallback<PatientDetails?>(
      repository.loadPatientDetails(patientId),
      ref.read(patientDetailsProvider),
    ),
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
  final locationStatus = values[6] as LocationStatus?;
  if (locationStatus != null) _applyLocationStatus(ref, locationStatus);
  ref
      .read(medicationsProvider.notifier)
      .replace(values[7] as List<MedicationModel>);
  final details = values[8] as PatientDetails?;
  if (details != null) {
    ref.read(patientDetailsProvider.notifier).replace(details);
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

/// Copies the backend's location status into the patient, safe zone and
/// map providers that the screens read.
void _applyLocationStatus(Ref ref, LocationStatus status) {
  final patientNotifier = ref.read(patientProvider.notifier);
  final patient = ref.read(patientProvider);
  final lastSeen = status.lastSeenAt;
  final location = status.location;
  patientNotifier.replace(
    PatientModel(
      id: patient.id,
      profileId: patient.profileId,
      name: patient.name,
      dateOfBirth: patient.dateOfBirth,
      photoUrl: patient.photoUrl,
      batteryLevel: status.batteryLevel,
      isDeviceOnline:
          lastSeen != null && status.state != LocationState.offline,
      locationSharingEnabled: status.sharingEnabled,
      lastSyncTime: lastSeen,
      safeZoneStatus: switch (status.state) {
        LocationState.inside => SafeZoneStatus.inside,
        LocationState.outside => SafeZoneStatus.outside,
        LocationState.offline => SafeZoneStatus.offline,
        LocationState.unknown ||
        LocationState.sharingOff => SafeZoneStatus.unknown,
      },
      lastKnownLocationName: location == null
          ? 'Location unavailable'
          : 'Last location at ${_clockTime(location.observedAt)}',
    ),
  );
  ref.read(patientLocationProvider.notifier).state = location;
  ref
      .read(safeZoneProvider.notifier)
      .replace(status.safeZone ?? SafeZoneNotifier.emptyZone());
}

String _clockTime(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${time.hour >= 12 ? 'PM' : 'AM'}';
}

/// The patient's last reported position, shown on the caregiver's map.
final patientLocationProvider = StateProvider<PatientLocation?>((ref) {
  ref.watch(sessionProvider);
  return null;
});

/// Runs location tracking on the patient's phone while sharing is on.
/// Watched by the patient shell, so it stops when the patient signs out.
final locationTrackerProvider = Provider<LocationTracker?>((ref) {
  final session = ref.watch(sessionProvider);
  final repository = ref.watch(careRepositoryProvider);
  final patientId = ref.watch(patientProvider.select((p) => p.id));
  final sharing = ref.watch(
    patientProvider.select((p) => p.locationSharingEnabled),
  );
  if (kIsWeb ||
      !session.canAccessPatient ||
      repository == null ||
      patientId.isEmpty ||
      !sharing) {
    return null;
  }
  final tracker = LocationTracker(repository);
  ref.onDispose(tracker.stop);
  unawaited(tracker.startIfPermitted());
  return tracker;
});

Future<void> refreshCareData(WidgetRef ref) async {
  ref.invalidate(careBootstrapProvider);
  await ref.read(careBootstrapProvider.future);
}

final careRealtimeProvider = StreamProvider<void>((ref) async* {
  final session = ref.watch(sessionProvider);
  final repository = ref.watch(careRepositoryProvider);
  if (session.role == null || repository == null) return;

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

  /// Placeholder used when the patient has no safe zone yet.
  static SafeZoneModel emptyZone() => SafeZoneModel(
    id: '',
    name: 'Safe zone',
    radiusMeters: 300,
    centerLatitude: 0,
    centerLongitude: 0,
    isPatientInside: true,
    lastChecked: DateTime.now(),
  );

  /// Creates or moves the safe zone. Earlier zones are switched off.
  Future<void> saveZone({
    required String patientId,
    required String name,
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) async {
    final id = await _repository?.saveSafeZone(
      patientId: patientId,
      name: name,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters.round(),
    );
    state = SafeZoneModel(
      id: id ?? 'sz-${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim().isEmpty ? 'Home' : name.trim(),
      radiusMeters: radiusMeters,
      centerLatitude: latitude,
      centerLongitude: longitude,
      isPatientInside: state.isPatientInside,
      lastChecked: DateTime.now(),
    );
  }

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
    ref.watch(sessionProvider);
    return SafeZoneNotifier(
      useDemoData: ref.watch(careRepositoryProvider) == null,
      repository: ref.watch(careRepositoryProvider),
    );
  },
);

// Caregivers & Emergency Contacts List
class CaregiversNotifier extends StateNotifier<List<CaregiverModel>> {
  CaregiversNotifier({bool useDemoData = true, this._repository})
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

  final CareRepository? _repository;

  void replace(List<CaregiverModel> caregivers) => state = caregivers;

  Future<void> revokeAccess({
    required String patientId,
    required String caregiverId,
  }) async {
    await _repository?.revokeCaregiverAccess(
      patientId: patientId,
      caregiverId: caregiverId,
    );
    state = state.where((caregiver) => caregiver.id != caregiverId).toList();
  }
}

final caregiversProvider =
    StateNotifierProvider<CaregiversNotifier, List<CaregiverModel>>((ref) {
      ref.watch(sessionProvider);
      return CaregiversNotifier(
        useDemoData: ref.watch(careRepositoryProvider) == null,
        repository: ref.watch(careRepositoryProvider),
      );
    });

class CurrentCaregiverNotifier extends StateNotifier<CaregiverModel> {
  CurrentCaregiverNotifier([this._repository])
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

  final CareRepository? _repository;

  void replace(CaregiverModel caregiver) => state = caregiver;

  Future<void> updateProfile({
    required String name,
    required String phone,
    required String relationship,
  }) async {
    await _repository?.updateCaregiverProfile(
      name: name,
      phone: phone,
      relationship: relationship,
    );
    state = state.copyWith(
      name: name.trim(),
      phone: phone.trim(),
      relationship: relationship.trim(),
    );
  }

  Future<void> uploadPhoto(Uint8List jpegBytes) async {
    final repository = _repository;
    if (repository == null || state.profileId.isEmpty) return;
    final url = await repository.uploadProfilePhoto(
      profileId: state.profileId,
      jpegBytes: jpegBytes,
    );
    state = state.copyWith(photoUrl: url);
  }
}

final currentCaregiverProvider =
    StateNotifierProvider<CurrentCaregiverNotifier, CaregiverModel>((ref) {
      ref.watch(sessionProvider);
      return CurrentCaregiverNotifier(ref.watch(careRepositoryProvider));
    });

/// The patient's full profile (medical and care details). Null until loaded.
class PatientDetailsNotifier extends StateNotifier<PatientDetails?> {
  PatientDetailsNotifier(super.initial, this._repository);

  final CareRepository? _repository;

  void replace(PatientDetails details) => state = details;

  Future<void> save({
    required String patientId,
    required String fullName,
    required DateTime? dateOfBirth,
    required Map<String, String> fields,
  }) async {
    final cleaned = {
      for (final entry in fields.entries)
        if (entry.value.trim().isNotEmpty) entry.key: entry.value.trim(),
    };
    await _repository?.updatePatientDetails(
      patientId: patientId,
      fullName: fullName,
      dateOfBirth: dateOfBirth,
      fields: {
        // Send every field, so cleared ones are removed on the server.
        for (final key in PatientDetails.fieldKeys) key: cleaned[key] ?? '',
      },
    );
    final current = state;
    state = PatientDetails(
      profileId: current?.profileId ?? '',
      fullName: fullName.trim(),
      dateOfBirth: dateOfBirth,
      photoUrl: current?.photoUrl ?? '',
      fields: cleaned,
    );
  }

  Future<String> uploadPhoto(String profileId, Uint8List jpegBytes) async {
    final repository = _repository;
    if (repository == null) return state?.photoUrl ?? '';
    final url = await repository.uploadProfilePhoto(
      profileId: profileId,
      jpegBytes: jpegBytes,
    );
    final current = state;
    if (current != null) state = current.copyWith(photoUrl: url);
    return url;
  }
}

final patientDetailsProvider =
    StateNotifierProvider<PatientDetailsNotifier, PatientDetails?>((ref) {
      ref.watch(sessionProvider);
      final repository = ref.watch(careRepositoryProvider);
      if (repository != null) return PatientDetailsNotifier(null, repository);
      // Demo mode: details matching the demo patient.
      return PatientDetailsNotifier(
        PatientDetails(
          profileId: 'demo-patient',
          fullName: 'Ramesh Sharma',
          dateOfBirth: DateTime(1954, 1, 15),
          photoUrl: '',
          fields: const {
            'preferred_name': 'Ramesh ji',
            'gender': 'male',
            'languages': 'Hindi, English',
            'home_address': 'Vasant Vihar, New Delhi',
            'blood_group': 'B+',
            'food_allergies': 'Peanuts',
            'medicine_allergies': 'Penicillin',
            'medical_conditions': "Alzheimer's disease, high blood pressure",
            'dementia_stage': 'middle',
            'doctor_name': 'Dr. V. K. Gupta',
            'doctor_phone': '+91 11 2614 0000',
            'wandering_risk': 'medium',
            'calming_things': 'Old Hindi songs, tea on the balcony',
          },
        ),
        null,
      );
    });

class EmergencyContactsNotifier extends StateNotifier<List<EmergencyContact>> {
  EmergencyContactsNotifier({bool useDemoData = true, this._repository})
    : super(
        useDemoData
            ? [
                EmergencyContact(
                  id: 'contact-1',
                  name: 'Sunita Sharma (Spouse)',
                  phone: '+91 98765 43210',
                  relationship: 'Primary Caregiver',
                  priority: 1,
                ),
                EmergencyContact(
                  id: 'contact-2',
                  name: 'Anil Sharma (Son)',
                  phone: '+91 98123 45678',
                  relationship: 'Family Member',
                  priority: 2,
                ),
                EmergencyContact(
                  id: 'contact-3',
                  name: 'Dr. V. K. Gupta (Neurologist)',
                  phone: '+91 11 2614 9999',
                  relationship: 'Attending Physician',
                  priority: 3,
                ),
              ]
            : const [],
      );

  final CareRepository? _repository;

  void replace(List<EmergencyContact> contacts) => state = contacts;

  Future<void> addContact(
    EmergencyContact contact, {
    required String patientId,
  }) async {
    final persisted = await _repository?.createEmergencyContact(
      patientId: patientId,
      name: contact.name,
      relationship: contact.relationship,
      phone: contact.phone,
      priority: contact.priority,
      idempotencyKey: 'contact:${contact.id}',
    );
    state = [...state, persisted ?? contact]
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }

  Future<void> updateContact(EmergencyContact contact) async {
    await _repository?.updateEmergencyContact(
      contactId: contact.id,
      name: contact.name,
      relationship: contact.relationship,
      phone: contact.phone,
      priority: contact.priority,
    );
    state =
        state
            .map((existing) => existing.id == contact.id ? contact : existing)
            .toList()
          ..sort((a, b) => a.priority.compareTo(b.priority));
  }

  Future<void> deleteContact(String contactId) async {
    await _repository?.deleteEmergencyContact(contactId: contactId);
    state = state.where((contact) => contact.id != contactId).toList();
  }
}

final emergencyContactsProvider =
    StateNotifierProvider<EmergencyContactsNotifier, List<EmergencyContact>>((
      ref,
    ) {
      ref.watch(sessionProvider);
      return EmergencyContactsNotifier(
        useDemoData: ref.watch(careRepositoryProvider) == null,
        repository: ref.watch(careRepositoryProvider),
      );
    });
