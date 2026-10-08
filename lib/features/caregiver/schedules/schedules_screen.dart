import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/app_state.dart';

class SchedulesScreen extends ConsumerWidget {
  const SchedulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medications = ref.watch(doseInstancesProvider);
    final routines = ref.watch(routinesProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Add Medication Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Medications',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _showAddMedicationDialog(context, ref),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text(
                      'Add',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Medication Items List
              ...medications.map(
                (med) => Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(18),
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryContainer,
                      radius: 26,
                      child: const Icon(
                        Icons.medication_rounded,
                        color: AppTheme.primaryColor,
                        size: 26,
                      ),
                    ),
                    title: Text(
                      med.medicineName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          '${med.dosage} • ${TimeOfDay.fromDateTime(med.scheduledFor).format(context)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          med.instructions,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: med.isReportedTaken
                                ? AppTheme.successGreenContainer
                                : Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            med.isReportedTaken ? 'TAKEN' : 'PENDING',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: med.isReportedTaken
                                  ? AppTheme.successGreen
                                  : Colors.orange.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Daily Routine Reminders Management
              const Text(
                'Routine',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 14),

              ...routines.map(
                (routine) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 1,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    leading: Icon(
                      routine.isCompleted
                          ? Icons.task_alt_rounded
                          : Icons.schedule_rounded,
                      color: routine.isCompleted
                          ? AppTheme.successGreen
                          : AppTheme.primaryColor,
                      size: 26,
                    ),
                    title: Text(
                      routine.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text('${routine.subtitle} • ${routine.time}'),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddMedicationDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final dosageCtrl = TextEditingController();
    final timeCtrl = TextEditingController(text: '09:00 AM');
    final instCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add medication'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Medicine',
                  hintText: 'Donepezil',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dosageCtrl,
                decoration: const InputDecoration(
                  labelText: 'Dosage',
                  hintText: '10mg - 1 tablet',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: timeCtrl,
                decoration: const InputDecoration(labelText: 'Time'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: instCtrl,
                decoration: const InputDecoration(
                  labelText: 'Instructions',
                  hintText: 'Take with water after food',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty) {
                final scheduledFor = _parseScheduledTime(timeCtrl.text);
                if (scheduledFor == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a valid time')),
                  );
                  return;
                }
                final newMed = DoseInstance(
                  id: 'dose-${DateTime.now().millisecondsSinceEpoch}',
                  medicationId: 'med-${DateTime.now().millisecondsSinceEpoch}',
                  medicineName: nameCtrl.text,
                  dosage: dosageCtrl.text.isEmpty ? '1 Dose' : dosageCtrl.text,
                  instructions: instCtrl.text.isEmpty
                      ? 'As directed'
                      : instCtrl.text,
                  scheduledFor: scheduledFor,
                  status: DoseStatus.scheduled,
                );
                try {
                  await ref
                      .read(doseInstancesProvider.notifier)
                      .addDose(newMed, patientId: ref.read(patientProvider).id);
                  if (!context.mounted) return;
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${nameCtrl.text} added')),
                  );
                } catch (_) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Unable to add medication')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  DateTime? _parseScheduledTime(String value) {
    final now = DateTime.now();
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) return null;

    var hour = int.tryParse(match.group(1) ?? '') ?? 9;
    final minute = int.tryParse(match.group(2) ?? '') ?? 0;
    if (hour < 1 || hour > 12 || minute < 0 || minute > 59) return null;
    final period = (match.group(3) ?? 'AM').toUpperCase();
    if (hour == 12) hour = 0;
    if (period == 'PM') hour += 12;
    final scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    return scheduled.isBefore(now)
        ? scheduled.add(const Duration(days: 1))
        : scheduled;
  }
}
