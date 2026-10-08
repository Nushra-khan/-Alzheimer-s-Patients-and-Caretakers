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
}
