import 'package:alzheimers_care/core/models/models.dart';
import 'package:alzheimers_care/core/providers/app_state.dart';
import 'package:alzheimers_care/core/repositories/care_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  test('care state is reset when the authenticated session changes', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final session = container.read(sessionProvider.notifier);
    session.establishAuthenticatedSession(UserRole.caregiver);

    container
        .read(patientProvider.notifier)
        .replace(
          PatientModel(
            id: 'private-patient',
            name: 'Previous account',
            dateOfBirth: DateTime(1950),
            photoUrl: '',
            batteryLevel: 50,
            isDeviceOnline: true,
            locationSharingEnabled: true,
            lastSyncTime: DateTime(2026),
            safeZoneStatus: SafeZoneStatus.inside,
            lastKnownLocationName: 'Private location',
          ),
        );
    container.read(doseInstancesProvider.notifier).replace(const []);
    container.read(routinesProvider.notifier).replace(const []);
    container.read(alertsProvider.notifier).replace(const []);
    container
        .read(safeZoneProvider.notifier)
        .replace(
          SafeZoneModel(
            id: 'private-zone',
            name: 'Previous safe zone',
            radiusMeters: 500,
            centerLatitude: 1,
            centerLongitude: 1,
            isPatientInside: false,
            lastChecked: DateTime(2026),
          ),
        );
    container.read(caregiversProvider.notifier).replace(const []);
    container
        .read(currentCaregiverProvider.notifier)
        .replace(
          CaregiverModel(
            id: 'private-caregiver',
            name: 'Previous caregiver',
            relationship: 'Family',
            phone: 'private',
            email: 'private@example.com',
            isPrimary: true,
          ),
        );
    container.read(emergencyContactsProvider.notifier).replace(const []);

    // A new auth event may keep the same role while representing another user.
    session.establishAuthenticatedSession(UserRole.caregiver);

    expect(container.read(patientProvider).id, 'p-101');
    expect(container.read(doseInstancesProvider), isNotEmpty);
    expect(container.read(routinesProvider), isNotEmpty);
    expect(container.read(alertsProvider), isNotEmpty);
    expect(container.read(safeZoneProvider).id, 'sz-1');
    expect(container.read(caregiversProvider), isNotEmpty);
    expect(container.read(currentCaregiverProvider).id, isEmpty);
    expect(container.read(emergencyContactsProvider), isNotEmpty);
  });

  test(
    'failed optional refreshes preserve the last loaded care data',
    () async {
      final container = ProviderContainer(
        overrides: [
          careRepositoryProvider.overrideWithValue(
            _FailingOptionalCareRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(sessionProvider.notifier)
          .establishAuthenticatedSession(UserRole.patient);

      final dose = DoseInstance(
        id: 'cached-dose',
        medicationId: 'cached-medication',
        medicineName: 'Cached medicine',
        dosage: '1 tablet',
        instructions: 'After food',
        scheduledFor: DateTime(2026, 11, 6, 9),
        status: DoseStatus.scheduled,
      );
      final routine = RoutineItem(
        id: 'cached-routine',
        title: 'Cached routine',
        subtitle: 'Previously loaded',
        time: '09:00 AM',
        isCompleted: false,
      );
      final alert = AlertModel(
        id: 'cached-alert',
        patientId: 'patient-1',
        patientName: 'Patient',
        type: AlertType.sos,
        severity: AlertSeverity.critical,
        title: 'Cached alert',
        description: 'Previously loaded',
        timestamp: DateTime(2026, 11, 6),
        status: AlertStatus.active,
      );
      final caregiver = CaregiverModel(
        id: 'cached-caregiver',
        name: 'Cached caregiver',
        relationship: 'Family',
        phone: '123',
        email: 'caregiver@example.com',
        isPrimary: true,
      );
      final contact = EmergencyContact(
        id: 'cached-contact',
        name: 'Cached contact',
        phone: '456',
        relationship: 'Family',
        priority: 1,
      );
      container.read(doseInstancesProvider.notifier).replace([dose]);
      container.read(routinesProvider.notifier).replace([routine]);
      container.read(alertsProvider.notifier).replace([alert]);
      container.read(caregiversProvider.notifier).replace([caregiver]);
      container.read(emergencyContactsProvider.notifier).replace([contact]);

      await container.read(careBootstrapProvider.future);

      expect(container.read(doseInstancesProvider).single.id, dose.id);
      expect(container.read(routinesProvider).single.id, routine.id);
      expect(container.read(alertsProvider).single.id, alert.id);
      expect(container.read(caregiversProvider).single.id, caregiver.id);
      expect(container.read(emergencyContactsProvider).single.id, contact.id);
    },
  );

  test(
    'dose status supports taken, correction, and skipped transitions',
    () async {
      final notifier = DoseInstanceNotifier();
      final doseId = notifier.state.first.id;

      await notifier.reportDoseTaken(doseId);
      expect(notifier.state.first.status, DoseStatus.reportedTaken);
      expect(notifier.state.first.reportedAt, isNotNull);

      await notifier.correctDose(doseId);
      expect(notifier.state.first.status, DoseStatus.scheduled);
      expect(notifier.state.first.reportedAt, isNull);

      await notifier.skipDose(doseId);
      expect(notifier.state.first.status, DoseStatus.skipped);
      expect(notifier.state.first.reportedAt, isNull);
    },
  );

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

  test('emergency contacts can be added, edited, and removed', () async {
    final notifier = EmergencyContactsNotifier();
    final contact = EmergencyContact(
      id: 'new-contact',
      name: 'Test Contact',
      phone: '+91 90000 00000',
      relationship: 'Family',
      priority: 4,
    );

    await notifier.addContact(contact, patientId: 'patient-1');
    expect(notifier.state.any((item) => item.id == contact.id), isTrue);

    final updatedContact = contact.copyWith(
      name: 'Updated Contact',
      priority: 1,
    );
    await notifier.updateContact(updatedContact);
    final updated = notifier.state.firstWhere((item) => item.id == contact.id);
    expect(updated.name, 'Updated Contact');
    expect(updated.priority, 1);

    await notifier.deleteContact(contact.id);
    expect(notifier.state.any((item) => item.id == contact.id), isFalse);
  });
}

class _FailingOptionalCareRepository implements CareRepository {
  @override
  Future<String> resolveAccessiblePatientId() async => 'patient-1';

  @override
  Future<PatientModel> loadPatient(String patientId) async => PatientModel(
    id: patientId,
    name: 'Patient',
    dateOfBirth: DateTime(1950),
    photoUrl: '',
    batteryLevel: 50,
    isDeviceOnline: true,
    locationSharingEnabled: false,
    lastSyncTime: DateTime(2026, 11, 6),
    safeZoneStatus: SafeZoneStatus.unknown,
    lastKnownLocationName: 'Unavailable',
  );

  @override
  Future<List<DoseInstance>> loadTodayDoses(String patientId, DateTime day) =>
      Future.error(StateError('Temporary backend failure'));

  @override
  Future<List<AlertModel>> loadAlerts(String patientId) =>
      Future.error(StateError('Temporary backend failure'));

  @override
  Future<List<RoutineItem>> loadRoutines(String patientId) =>
      Future.error(StateError('Temporary backend failure'));

  @override
  Future<List<CaregiverModel>> loadCaregivers(String patientId) =>
      Future.error(StateError('Temporary backend failure'));

  @override
  Future<List<EmergencyContact>> loadEmergencyContacts(String patientId) =>
      Future.error(StateError('Temporary backend failure'));

  @override
  Future<SafeZoneModel?> loadSafeZone(String patientId) =>
      Future.error(StateError('Temporary backend failure'));

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future<Object?>.error(StateError('Temporary backend failure'));
}
