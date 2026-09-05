import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/auth_service.dart';
import '../config/app_config.dart';
import '../models/models.dart';

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
  PatientNotifier()
    : super(
        PatientModel(
          id: 'p-101',
          name: 'Ramesh Sharma',
          dateOfBirth: DateTime(1954, 1, 15),
          photoUrl: '',
          batteryLevel: 84,
          isDeviceOnline: true,
          locationSharingEnabled: true,
          lastSyncTime: DateTime.now().subtract(const Duration(minutes: 3)),
          safeZoneStatus: SafeZoneStatus.inside,
          lastKnownLocationName: 'Home (Vasant Vihar, New Delhi)',
        ),
      );

  void toggleLocationSharing() {
    state = state.copyWith(
      locationSharingEnabled: !state.locationSharingEnabled,
    );
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
  return PatientNotifier();
});

// Medications Provider
DateTime _todayAt(int hour, [int minute = 0]) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, hour, minute);
}

class DoseInstanceNotifier extends StateNotifier<List<DoseInstance>> {
  DoseInstanceNotifier()
    : super([
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
      ]);

  void reportDoseTaken(String id) {
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

  void addDose(DoseInstance dose) {
    state = [...state, dose];
  }
}

final doseInstancesProvider =
    StateNotifierProvider<DoseInstanceNotifier, List<DoseInstance>>((ref) {
      return DoseInstanceNotifier();
    });

// Routine Items Provider
class RoutineNotifier extends StateNotifier<List<RoutineItem>> {
  RoutineNotifier()
    : super([
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
      ]);

  void toggleRoutine(String id) {
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
      return RoutineNotifier();
    });

// Alerts Provider
class AlertNotifier extends StateNotifier<List<AlertModel>> {
  AlertNotifier()
    : super([
        AlertModel(
          id: 'alt-101',
          patientId: 'p-101',
          patientName: 'Ramesh Sharma',
          type: AlertType.overdueDose,
          severity: AlertSeverity.warning,
          title: 'Overdue Dose: Donepezil 10mg',
          description:
              'Dose scheduled for 08:00 PM has not been reported taken after 30-min grace period.',
          timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
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
          description: 'Patient pressed emergency SOS button from home screen.',
          timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
          status: AlertStatus.resolved,
          acknowledgedBy: 'Anil Sharma (Son)',
          acknowledgedAt: DateTime.now().subtract(
            const Duration(days: 1, hours: 2, minutes: 55),
          ),
          resolvedAt: DateTime.now().subtract(
            const Duration(days: 1, hours: 2, minutes: 30),
          ),
        ),
      ]);

  void triggerSOSAlert({required String patientName}) {
    final sosAlert = AlertModel(
      id: 'alt-${DateTime.now().millisecondsSinceEpoch}',
      patientId: 'p-101',
      patientName: patientName,
      type: AlertType.sos,
      severity: AlertSeverity.critical,
      title: '🚨 EMERGENCY SOS ACTIVATED',
      description:
          'Patient pressed the emergency SOS button. Immediate caregiver acknowledgement required.',
      timestamp: DateTime.now(),
      status: AlertStatus.active,
    );
    state = [sosAlert, ...state];
  }

  void acknowledgeAlert(String alertId, String caregiverName) {
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

  void resolveAlert(String alertId) {
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
  return AlertNotifier();
});

// Safe Zone Provider
class SafeZoneNotifier extends StateNotifier<SafeZoneModel> {
  SafeZoneNotifier()
    : super(
        SafeZoneModel(
          id: 'sz-1',
          name: 'Home Safe Radius (Vasant Vihar)',
          radiusMeters: 300,
          centerLatitude: 28.5562,
          centerLongitude: 77.1610,
          isPatientInside: true,
          lastChecked: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      );

  void updateRadius(double newRadius) {
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
    return SafeZoneNotifier();
  },
);

// Caregivers & Emergency Contacts List
final caregiversProvider = Provider<List<CaregiverModel>>((ref) {
  return [
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
  ];
});

final emergencyContactsProvider = Provider<List<EmergencyContact>>((ref) {
  return [
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
  ];
});
