import 'package:flutter/material.dart';

enum ProfileFieldKind { text, multiline, phone, choice }

/// One editable detail of the patient's profile, keyed by database column.
class ProfileField {
  const ProfileField(
    this.key,
    this.label, {
    this.hint,
    this.kind = ProfileFieldKind.text,
    this.maxLength = 200,
    this.choices = const {},
  });

  final String key;
  final String label;
  final String? hint;
  final ProfileFieldKind kind;
  final int maxLength;

  /// Stored value -> label shown to people.
  final Map<String, String> choices;

  String display(String value) =>
      kind == ProfileFieldKind.choice ? (choices[value] ?? value) : value;
}

class ProfileSection {
  const ProfileSection(this.title, this.icon, this.fields);

  final String title;
  final IconData icon;
  final List<ProfileField> fields;
}

final _phonePattern = RegExp(r'^\+?[0-9 ()-]{6,20}$');

/// Returns an error message, or null when [value] is acceptable.
String? validateProfileField(ProfileField field, String value) {
  final text = value.trim();
  if (text.isEmpty) return null;
  if (text.length > field.maxLength) {
    return 'Use ${field.maxLength} characters or fewer';
  }
  if (field.kind == ProfileFieldKind.phone && !_phonePattern.hasMatch(text)) {
    return 'Enter a valid phone number';
  }
  return null;
}

const patientProfileSections = [
  ProfileSection('About', Icons.person_outline_rounded, [
    ProfileField(
      'preferred_name',
      'Preferred name',
      hint: 'What they like to be called',
      maxLength: 80,
    ),
    ProfileField(
      'gender',
      'Gender',
      kind: ProfileFieldKind.choice,
      choices: {
        'female': 'Female',
        'male': 'Male',
        'other': 'Other',
        'prefer_not_to_say': 'Prefer not to say',
      },
    ),
    ProfileField('languages', 'Languages spoken', hint: 'Hindi, English'),
    ProfileField(
      'home_address',
      'Home address',
      kind: ProfileFieldKind.multiline,
      maxLength: 300,
    ),
  ]),
  ProfileSection('Medical', Icons.medical_information_outlined, [
    ProfileField(
      'blood_group',
      'Blood group',
      kind: ProfileFieldKind.choice,
      choices: {
        'A+': 'A+',
        'A-': 'A-',
        'B+': 'B+',
        'B-': 'B-',
        'AB+': 'AB+',
        'AB-': 'AB-',
        'O+': 'O+',
        'O-': 'O-',
        'unknown': "Don't know",
      },
    ),
    ProfileField(
      'food_allergies',
      'Food allergies',
      hint: 'Peanuts, milk',
      maxLength: 300,
    ),
    ProfileField(
      'medicine_allergies',
      'Medicine allergies',
      hint: 'Penicillin',
      maxLength: 300,
    ),
    ProfileField('other_allergies', 'Other allergies', maxLength: 300),
    ProfileField(
      'medical_conditions',
      'Medical conditions',
      hint: "Alzheimer's disease, diabetes",
      kind: ProfileFieldKind.multiline,
      maxLength: 500,
    ),
    ProfileField(
      'dementia_stage',
      'Dementia stage',
      kind: ProfileFieldKind.choice,
      choices: {
        'early': 'Early',
        'middle': 'Middle',
        'late': 'Late',
        'unknown': 'Not sure',
      },
    ),
    ProfileField('doctor_name', 'Doctor name', maxLength: 120),
    ProfileField(
      'doctor_phone',
      'Doctor phone',
      kind: ProfileFieldKind.phone,
      maxLength: 30,
    ),
    ProfileField('preferred_hospital', 'Preferred hospital'),
    ProfileField(
      'medical_notes',
      'Medical notes',
      kind: ProfileFieldKind.multiline,
      maxLength: 1000,
    ),
  ]),
  ProfileSection('Care and safety', Icons.health_and_safety_outlined, [
    ProfileField('mobility_aids', 'Mobility aids', hint: 'Walking stick'),
    ProfileField(
      'sensory_aids',
      'Hearing or vision aids',
      hint: 'Hearing aid (left ear), glasses',
    ),
    ProfileField(
      'diet_needs',
      'Diet needs',
      hint: 'Vegetarian, soft food, diabetic',
      maxLength: 300,
    ),
    ProfileField(
      'wandering_risk',
      'Wandering risk',
      kind: ProfileFieldKind.choice,
      choices: {
        'low': 'Low',
        'medium': 'Medium',
        'high': 'High',
        'unknown': 'Not sure',
      },
    ),
    ProfileField(
      'calming_things',
      'Things that calm them',
      hint: 'Old songs, tea, family photos',
      kind: ProfileFieldKind.multiline,
      maxLength: 500,
    ),
    ProfileField(
      'upsetting_things',
      'Things that upset them',
      hint: 'Loud noise, crowds',
      kind: ProfileFieldKind.multiline,
      maxLength: 500,
    ),
    ProfileField('id_bracelet_number', 'ID bracelet number', maxLength: 60),
  ]),
];
