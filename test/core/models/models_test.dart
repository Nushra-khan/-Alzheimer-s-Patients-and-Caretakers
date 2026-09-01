import 'package:alzheimers_care/core/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PatientModel age', () {
    final patient = PatientModel(
      id: 'patient-1',
      name: 'Test Patient',
      dateOfBirth: DateTime(1954, 9, 15),
      photoUrl: '',
      batteryLevel: 80,
      isDeviceOnline: true,
      locationSharingEnabled: true,
      lastSyncTime: DateTime(2026, 9, 1),
      safeZoneStatus: SafeZoneStatus.inside,
      lastKnownLocationName: 'Home',
    );

    test('does not increment age before the birthday', () {
      expect(patient.ageOn(DateTime(2026, 9, 1)), 71);
    });

    test('increments age on the birthday', () {
      expect(patient.ageOn(DateTime(2026, 9, 15)), 72);
    });
  });

  test('a reported dose exposes an explicit reported state', () {
    final dose = DoseInstance(
      id: 'dose-1',
      medicationId: 'med-1',
      medicineName: 'Medicine',
      dosage: '1 tablet',
      instructions: 'As directed',
      scheduledFor: DateTime(2026, 9, 1, 9),
      status: DoseStatus.reportedTaken,
      reportedAt: DateTime(2026, 9, 1, 9, 5),
    );

    expect(dose.isReportedTaken, isTrue);
  });
}
