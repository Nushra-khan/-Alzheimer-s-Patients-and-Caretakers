import 'package:alzheimers_care/core/models/models.dart';
import 'package:alzheimers_care/core/providers/app_state.dart';
import 'package:alzheimers_care/features/profile/medical_id_screen.dart';
import 'package:alzheimers_care/features/profile/patient_profile_fields.dart';
import 'package:alzheimers_care/features/profile/patient_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

PatientDetails _details({DateTime? born, Map<String, String>? fields}) =>
    PatientDetails(
      profileId: 'profile-1',
      fullName: 'Asha Rao',
      dateOfBirth: born,
      photoUrl: '',
      fields: fields ?? const {},
    );

ProfileField _field(String key) => patientProfileSections
    .expand((section) => section.fields)
    .firstWhere((field) => field.key == key);

void main() {
  group('PatientDetails', () {
    test('age is calculated from the date of birth', () {
      final now = DateTime.now();
      final details = _details(born: DateTime(now.year - 70, 1, 1));
      expect(details.age, 70);
      expect(_details().age, isNull);
    });

    test('a birthday later this year has not added a year yet', () {
      final now = DateTime.now();
      final later = now.add(const Duration(days: 2));
      final details = _details(
        born: DateTime(now.year - 70, later.month, later.day),
      );
      expect(details.age, later.year == now.year ? 69 : 70);
    });

    test('allergies are combined for the Medical ID', () {
      final details = _details(
        fields: const {
          'food_allergies': 'Peanuts',
          'medicine_allergies': 'Penicillin',
        },
      );
      expect(details.allAllergies, 'Peanuts; Penicillin');
      expect(_details().allAllergies, isEmpty);
    });
  });

  group('profile field validation', () {
    test('phone numbers must look like phone numbers', () {
      final phone = _field('doctor_phone');
      expect(validateProfileField(phone, '+91 98765 43210'), isNull);
      expect(validateProfileField(phone, 'call me'), isNotNull);
      expect(validateProfileField(phone, ''), isNull);
    });

    test('text longer than the limit is rejected', () {
      final field = _field('preferred_name');
      expect(validateProfileField(field, 'a' * 80), isNull);
      expect(validateProfileField(field, 'a' * 81), isNotNull);
    });

    test('choices show friendly labels', () {
      expect(_field('dementia_stage').display('middle'), 'Middle');
      expect(_field('blood_group').display('unknown'), "Don't know");
    });
  });

  test('saving keeps filled fields and drops blank ones', () async {
    final notifier = PatientDetailsNotifier(_details(), null);
    await notifier.save(
      patientId: 'patient-1',
      fullName: '  Asha Rao  ',
      dateOfBirth: DateTime(1950, 5, 2),
      fields: const {'blood_group': 'O+', 'diet_needs': '   '},
    );
    expect(notifier.state!.fullName, 'Asha Rao');
    expect(notifier.state!.value('blood_group'), 'O+');
    expect(notifier.state!.fields.containsKey('diet_needs'), isFalse);
  });

  testWidgets('Medical ID shows name, blood group and allergies', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: MedicalIdScreen())),
    );

    expect(find.text('MEDICAL ID'), findsOneWidget);
    expect(find.text('Ramesh Sharma'), findsOneWidget);
    expect(find.text('B+'), findsOneWidget);
    expect(find.text('Peanuts; Penicillin'), findsOneWidget);
  });

  testWidgets('profile opens an editable form with the name filled in', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: PatientProfileScreen())),
    );

    expect(find.text('My profile'), findsOneWidget);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'Ramesh Sharma'), findsOneWidget);
  });

  testWidgets('demo patient details load without a backend', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(patientDetailsProvider)?.fullName, 'Ramesh Sharma');
  });
}
