import 'package:alzheimers_care/core/models/models.dart';
import 'package:alzheimers_care/core/providers/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session starts signed out and receives a server-assigned role', () {
    final notifier = SessionNotifier();

    expect(notifier.state.isAuthenticated, isFalse);
    expect(notifier.state.role, isNull);

    notifier.establishAuthenticatedSession(UserRole.caregiver);

    expect(notifier.state.isAuthenticated, isTrue);
    expect(notifier.state.canAccessCaregiver, isTrue);
    expect(notifier.state.canAccessPatient, isFalse);

    notifier.signOut();
    expect(notifier.state.role, isNull);
  });

  test('reporting a dose is one-way in patient state', () async {
    final notifier = DoseInstanceNotifier();
    final doseId = notifier.state.first.id;

    await notifier.reportDoseTaken(doseId);
    final firstReportedAt = notifier.state.first.reportedAt;
    await notifier.reportDoseTaken(doseId);

    expect(notifier.state.first.status, DoseStatus.reportedTaken);
    expect(notifier.state.first.reportedAt, firstReportedAt);
  });

  test('location sharing updates after a successful local action', () async {
    final notifier = PatientNotifier(useDemoData: false);

    await notifier.setLocationSharing(true);

    expect(notifier.state.locationSharingEnabled, isTrue);
  });

  test('routine completion can be changed', () async {
    final notifier = RoutineNotifier();
    final routine = notifier.state.first;

    await notifier.toggleRoutine(routine.id);

    expect(notifier.state.first.isCompleted, isNot(routine.isCompleted));
  });

  test('routine schedules can be added, edited, and deactivated', () async {
    final notifier = RoutineNotifier();
    final scheduledFor = DateTime(2026, 11, 4, 8);
    final routine = RoutineItem(
      id: 'new-routine',
      title: 'Morning tea',
      subtitle: 'Prepare one cup of tea',
      time: '8:00 AM',
      isCompleted: false,
    );

    await notifier.addRoutine(
      routine,
      patientId: 'patient-1',
      scheduledFor: scheduledFor,
    );
    expect(notifier.state.any((item) => item.id == routine.id), isTrue);

    await notifier.updateRoutine(
      routineId: routine.id,
      title: 'Morning breakfast',
      description: 'Prepare a light breakfast',
      displayTime: '8:30 AM',
      scheduledFor: DateTime(2026, 11, 4, 8, 30),
    );
    final updated = notifier.state.firstWhere((item) => item.id == routine.id);
    expect(updated.title, 'Morning breakfast');
    expect(updated.subtitle, 'Prepare a light breakfast');
    expect(updated.time, '8:30 AM');

    await notifier.deactivateRoutine(routine.id);
    expect(notifier.state.any((item) => item.id == routine.id), isFalse);
  });

  test('safe-zone radius can be changed', () async {
    final notifier = SafeZoneNotifier();

    await notifier.updateRadius(450);

    expect(notifier.state.radiusMeters, 450);
  });

  test('a medication can be added to local state', () async {
    final notifier = DoseInstanceNotifier();
    final dose = DoseInstance(
      id: 'new-dose',
      medicationId: 'new-medication',
      medicineName: 'Test medicine',
      dosage: '1 tablet',
      instructions: 'After food',
      scheduledFor: DateTime(2026, 10, 8, 20),
      status: DoseStatus.scheduled,
    );

    await notifier.addDose(dose, patientId: 'patient-1');

    expect(notifier.state.last.id, dose.id);
  });

  test('deactivating a medication removes all of its active doses', () async {
    final notifier = DoseInstanceNotifier();
    final medicationId = notifier.state.first.medicationId;

    await notifier.deactivateMedication(
      patientId: 'patient-1',
      medicationId: medicationId,
    );

    expect(
      notifier.state.any((dose) => dose.medicationId == medicationId),
      isFalse,
    );
  });

  test('editing medication updates every visible dose detail', () async {
    final notifier = DoseInstanceNotifier();
    final medicationId = notifier.state.first.medicationId;

    await notifier.updateMedicationDetails(
      patientId: 'patient-1',
      medicationId: medicationId,
      medicineName: 'Updated medicine',
      dosage: '2 tablets',
      instructions: 'After dinner',
    );

    final updated = notifier.state.where(
      (dose) => dose.medicationId == medicationId,
    );
    expect(updated, isNotEmpty);
    expect(
      updated.every((dose) => dose.medicineName == 'Updated medicine'),
      isTrue,
    );
    expect(updated.every((dose) => dose.dosage == '2 tablets'), isTrue);
    expect(
      updated.every((dose) => dose.instructions == 'After dinner'),
      isTrue,
    );
  });

  test('revoking caregiver access removes the caregiver from state', () async {
    final notifier = CaregiversNotifier();
    final caregiverId = notifier.state.first.id;

    await notifier.revokeAccess(
      patientId: 'patient-1',
      caregiverId: caregiverId,
    );

    expect(
      notifier.state.any((caregiver) => caregiver.id == caregiverId),
      isFalse,
    );
  });
}
