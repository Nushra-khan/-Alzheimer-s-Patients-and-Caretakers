import 'dart:typed_data';

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

  Future<EmergencyContact> createEmergencyContact({
    required String patientId,
    required String name,
    required String relationship,
    required String phone,
    required int priority,
    required String idempotencyKey,
  });

  Future<void> updateEmergencyContact({
    required String contactId,
    required String name,
    required String relationship,
    required String phone,
    required int priority,
  });

  Future<void> deleteEmergencyContact({required String contactId});

  Future<SafeZoneModel?> loadSafeZone(String patientId);

  Future<({String token, DateTime expiresAt})> createCareInvitation();

  Future<String> acceptCareInvitation(String token);

  Future<void> revokeCaregiverAccess({
    required String patientId,
    required String caregiverId,
  });

  Future<DoseInstance> createMedicationSchedule({
    required String patientId,
    required String medicineName,
    required String dosage,
    required String instructions,
    required DateTime scheduledFor,
    required String timezone,
    required String idempotencyKey,
  });

  Future<List<MedicationModel>> loadMedications(String patientId);

  Future<PatientDetails> loadPatientDetails(String patientId);

  Future<void> updatePatientDetails({
    required String patientId,
    required String fullName,
    required DateTime? dateOfBirth,
    required Map<String, String> fields,
  });

  /// Uploads a square JPEG as the photo of [profileId] (the user's own
  /// profile, or their patient's). Returns a short-lived URL to show it.
  Future<String> uploadProfilePhoto({
    required String profileId,
    required Uint8List jpegBytes,
  });

  Future<void> updateCaregiverProfile({
    required String name,
    required String phone,
    required String relationship,
  });

  Future<void> updateMedicationTime({
    required String patientId,
    required String medicationId,
    required int hour,
    required int minute,
    required String timezone,
  });

  Future<void> deactivateMedication({
    required String patientId,
    required String medicationId,
  });

  Future<void> updateMedicationDetails({
    required String patientId,
    required String medicationId,
    required String medicineName,
    required String dosage,
    required String instructions,
  });

  Future<RoutineItem> createRoutineSchedule({
    required String patientId,
    required String title,
    required String description,
    required DateTime scheduledFor,
    required String timezone,
    required String idempotencyKey,
  });

  Future<void> updateRoutineSchedule({
    required String routineId,
    required String title,
    required String description,
    required DateTime scheduledFor,
    required String timezone,
  });

  Future<void> deactivateRoutineSchedule({required String routineId});

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

  Future<String> saveSafeZone({
    required String patientId,
    required String name,
    required double latitude,
    required double longitude,
    required int radiusMeters,
  });

  Future<LocationStatus> loadLocationStatus(String patientId);

  /// Sends the patient's position. Returns how many seconds to wait before
  /// the next update.
  Future<int> recordLocation({
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required DateTime observedAt,
    required int? batteryLevel,
    required String idempotencyKey,
  });

  Stream<PatientModel> watchPatient(String patientId);

  Stream<List<DoseInstance>> watchTodayDoses(String patientId, DateTime day);

  Stream<List<AlertModel>> watchAlerts(String patientId);

  Stream<void> watchCareChanges(String patientId);

  Future<void> updateDoseStatus({
    required String doseInstanceId,
    required DoseStatus status,
    required String idempotencyKey,
    required DateTime occurredAt,
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
