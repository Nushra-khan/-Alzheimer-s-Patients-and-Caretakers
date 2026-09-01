import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/theme.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/app_state.dart';

class SchedulesScreen extends ConsumerWidget {
  const SchedulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doses = ref.watch(doseInstancesProvider);
    final routines = ref.watch(routinesProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Add Medication Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '💊 Medication Schedules',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    onPressed: () => _showAddMedicationDialog(context, ref),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Add Dose'),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Medication Items List
              ...doses.map(
                (dose) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryContainer,
                      radius: 24,
                      child: const Icon(
                        Icons.medication_rounded,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    title: Text(
                      dose.medicineName,
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
                          'Dosage: ${dose.dosage} • Time: ${DateFormat.jm().format(dose.scheduledFor)}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        Text(
                          'Instructions: ${dose.instructions}',
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
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: dose.isReportedTaken
                                ? AppTheme.successGreenContainer
                                : Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            dose.isReportedTaken ? 'REPORTED' : 'PENDING',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: dose.isReportedTaken
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
                '🌱 Daily Routines & Care Tasks',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              ...routines.map(
                (routine) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: Icon(
                      routine.isCompleted
                          ? Icons.task_alt_rounded
                          : Icons.schedule_rounded,
                      color: routine.isCompleted
                          ? AppTheme.successGreen
                          : AppTheme.primaryColor,
                    ),
                    title: Text(
                      routine.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${routine.subtitle} • Scheduled: ${routine.time}',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddMedicationDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final dosageCtrl = TextEditingController();
    var selectedTime = const TimeOfDay(hour: 9, minute: 0);
    final instCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Scheduled Medication'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Medicine Name (e.g. Donepezil)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dosageCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Dosage (e.g. 10mg - 1 Tablet)',
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule_rounded),
                  title: const Text('Scheduled time'),
                  subtitle: Text(selectedTime.format(ctx)),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: ctx,
                      initialTime: selectedTime,
                    );
                    if (picked != null) {
                      setDialogState(() => selectedTime = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: instCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Instructions (e.g. Take with water after food)',
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
              onPressed: () {
                if (nameCtrl.text.isNotEmpty) {
                  final now = DateTime.now();
                  final scheduledFor = DateTime(
                    now.year,
                    now.month,
                    now.day,
                    selectedTime.hour,
                    selectedTime.minute,
                  );
                  final newDose = DoseInstance(
                    id: 'dose-${DateTime.now().microsecondsSinceEpoch}',
                    medicationId:
                        'med-${DateTime.now().microsecondsSinceEpoch}',
                    medicineName: nameCtrl.text,
                    dosage: dosageCtrl.text.isEmpty
                        ? '1 Dose'
                        : dosageCtrl.text,
                    instructions: instCtrl.text.isEmpty
                        ? 'As directed'
                        : instCtrl.text,
                    scheduledFor: scheduledFor,
                    status: DoseStatus.scheduled,
                  );
                  ref.read(doseInstancesProvider.notifier).addDose(newDose);
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Scheduled ${nameCtrl.text} added cleanly.',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Save Schedule'),
            ),
          ],
        ),
      ),
    );
  }
}
