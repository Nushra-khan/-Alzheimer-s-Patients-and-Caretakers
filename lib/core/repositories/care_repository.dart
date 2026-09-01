import '../models/models.dart';

/// Boundary between presentation state and the trusted backend.
///
/// Implementations must rely on backend authorization and must use idempotency
/// keys for actions that may be retried after a network interruption.
abstract interface class CareRepository {
  Stream<PatientModel> watchPatient(String patientId);

  Stream<List<DoseInstance>> watchTodayDoses(String patientId, DateTime day);

  Stream<List<AlertModel>> watchAlerts(String patientId);

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
