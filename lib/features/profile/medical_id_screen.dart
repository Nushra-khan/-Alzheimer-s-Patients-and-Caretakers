import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/providers/app_state.dart';
import 'patient_profile_fields.dart';
import 'profile_avatar.dart';

/// A high-contrast card a stranger or paramedic can read quickly: who the
/// patient is, key medical facts, and who to call. Opened from the SOS tab.
class MedicalIdScreen extends ConsumerWidget {
  const MedicalIdScreen({super.key});

  static const _ink = Color(0xFF111111);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patient = ref.watch(patientProvider);
    final details = ref.watch(patientDetailsProvider);
    final contacts = ref.watch(emergencyContactsProvider);
    final medications = ref.watch(medicationsProvider);

    final name = details?.fullName.isNotEmpty == true
        ? details!.fullName
        : patient.name;
    final preferred = details?.value('preferred_name') ?? '';
    final age = details?.age;
    final bloodGroup = details?.value('blood_group') ?? '';
    final allergies = details?.allAllergies ?? '';
    final conditions = details?.value('medical_conditions') ?? '';
    final doctor = details?.value('doctor_name') ?? '';
    final doctorPhone = details?.value('doctor_phone') ?? '';
    final address = details?.value('home_address') ?? '';
    final bloodLabel = bloodGroup.isEmpty || bloodGroup == 'unknown'
        ? 'Unknown'
        : bloodGroup;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppTheme.alertRed,
        foregroundColor: Colors.white,
        title: const Text(
          'MEDICAL ID',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Row(
            children: [
              ProfileAvatar(
                name: name,
                photoUrl: details?.photoUrl.isNotEmpty == true
                    ? details!.photoUrl
                    : patient.photoUrl,
                radius: 44,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: _ink,
                      ),
                    ),
                    if (preferred.isNotEmpty)
                      Text(
                        'Call me $preferred',
                        style: const TextStyle(fontSize: 18, color: _ink),
                      ),
                    if (age != null)
                      Text(
                        '$age years old',
                        style: const TextStyle(fontSize: 18, color: _ink),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4D6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFB8860B), width: 2),
            ),
            child: const Text(
              'I have memory loss and may be confused. If I seem lost, '
              'please stay with me and call one of my contacts below.',
              style: TextStyle(
                fontSize: 19,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
          ),
          const SizedBox(height: 18),
          _Fact(label: 'BLOOD GROUP', value: bloodLabel, big: true),
          _Fact(
            label: 'ALLERGIES',
            value: allergies.isEmpty ? 'None recorded' : allergies,
            warning: allergies.isNotEmpty,
          ),
          _Fact(
            label: 'MEDICAL CONDITIONS',
            value: conditions.isEmpty ? 'None recorded' : conditions,
          ),
          if ((details?.value('dementia_stage') ?? '').isNotEmpty)
            _Fact(
              label: 'DEMENTIA STAGE',
              value: _choiceLabel(
                'dementia_stage',
                details!.value('dementia_stage'),
              ),
            ),
          if (medications.isNotEmpty)
            _Fact(
              label: 'MEDICINES',
              value: medications
                  .map((m) => '${m.name} (${m.dosage})')
                  .join(', '),
            ),
          if (address.isNotEmpty) _Fact(label: 'HOME ADDRESS', value: address),
          const SizedBox(height: 10),
          const Text(
            'CALL FOR HELP',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color: _ink,
            ),
          ),
          const SizedBox(height: 10),
          for (final contact in contacts)
            _CallButton(
              title: contact.name,
              subtitle: contact.relationship,
              phone: contact.phone,
            ),
          if (doctor.isNotEmpty && doctorPhone.isNotEmpty)
            _CallButton(title: doctor, subtitle: 'Doctor', phone: doctorPhone),
          const _CallButton(
            title: 'Emergency services',
            subtitle: 'Ambulance, police, fire',
            phone: '112',
            emergency: true,
          ),
        ],
      ),
    );
  }

  static String _choiceLabel(String key, String value) {
    for (final section in patientProfileSections) {
      for (final field in section.fields) {
        if (field.key == key) return field.display(value);
      }
    }
    return value;
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.label,
    required this.value,
    this.big = false,
    this.warning = false,
  });

  final String label;
  final String value;
  final bool big;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warning ? const Color(0xFFFFE5E5) : const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: warning ? AppTheme.alertRed : const Color(0xFFCCCCCC),
          width: warning ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color: warning ? AppTheme.alertRed : const Color(0xFF444444),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: big ? 30 : 20,
              fontWeight: FontWeight.w800,
              color: MedicalIdScreen._ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.title,
    required this.subtitle,
    required this.phone,
    this.emergency = false,
  });

  final String title;
  final String subtitle;
  final String phone;
  final bool emergency;

  @override
  Widget build(BuildContext context) {
    final color = emergency ? AppTheme.alertRed : AppTheme.successGreen;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final opened = await launchUrl(
              Uri(scheme: 'tel', path: phone.replaceAll(' ', '')),
              mode: LaunchMode.externalApplication,
            );
            if (!opened && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Unable to call. Dial $phone.')),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.call_rounded, color: Colors.white, size: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        subtitle.isEmpty ? phone : '$subtitle • $phone',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
