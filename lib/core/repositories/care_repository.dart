import '../models/models.dart';

class NoPatientConnectionException implements Exception {
  const NoPatientConnectionException();

  @override
  String toString() => 'No patient is connected to this account.';
}

/// Boundary between presentation state and the trusted backend.
///
/// Implementations must rely on backend authorization and must use idempotency
/// keys for actions that may be retried after a network interruption.
abstract interface class CareRepository {
  Future<String> resolveAccessiblePatientId();

  Future<PatientModel> loadPatient(String patientId);

  Future<List<DoseInstance>> loadTodayDoses(String patientId, DateTime day);

  Future<List<AlertModel>> loadAlerts(String patientId);

  Future<List<RoutineItem>> loadRoutines(String patientId);

  Future<List<CaregiverModel>> loadCaregivers(String patientId);

  Future<CaregiverModel> loadCurrentCaregiver();

  Future<List<EmergencyContact>> loadEmergencyContacts(String patientId);

  Future<SafeZoneModel?> loadSafeZone(String patientId);

  Future<({String token, DateTime expiresAt})> createCareInvitation();

  Future<String> acceptCareInvitation(String token);

  Future<DoseInstance> createMedicationSchedule({
    required String patientId,
    required String medicineName,
    required String dosage,
    required String instructions,
    required DateTime scheduledFor,
    required String timezone,
    required String idempotencyKey,
  });

  Future<void> setRoutineCompleted({
    required String routineId,
    required bool completed,
    required DateTime localDate,
  });

  Future<void> setLocationSharing({
    required String patientId,
    required bool enabled,
  });

  Future<void> updateSafeZoneRadius({
    required String safeZoneId,
    required double radiusMeters,
  });

  Stream<PatientModel> watchPatient(String patientId);

  Stream<List<DoseInstance>> watchTodayDoses(String patientId, DateTime day);

  Stream<List<AlertModel>> watchAlerts(String patientId);

  Stream<void> watchCareChanges(String patientId);

  Future<void> reportDoseTaken({
    required String doseInstanceId,
    required String idempotencyKey,
    required DateTime reportedAt,
  });

  Future<String> createSos({
    required String patientId,
    required String idempotencyKey,
    required DateTime occurredAt,
  });

  Future<void> acknowledgeAlert({
    required String alertId,
    required String idempotencyKey,
  });

  Future<void> resolveAlert({
    required String alertId,
    required String resolutionNote,
    required String idempotencyKey,
  });
}
