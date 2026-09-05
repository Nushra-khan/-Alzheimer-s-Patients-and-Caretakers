import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/app_state.dart';

class SchedulesScreen extends ConsumerWidget {
  const SchedulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medications = ref.watch(medicationsProvider);
    final routines = ref.watch(routinesProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAlignment.start,
            children: [
              // Header & Add Medication Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '💊 Medication Schedules',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _showAddMedicationDialog(context, ref),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Add Dose', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Medication Items List
              ...medications.map(
                (med) => Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(18),
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryContainer,
                      radius: 26,
                      child: const Icon(Icons.medication_rounded, color: AppTheme.primaryColor, size: 26),
                    ),
                    title: Text(
                      med.medicineName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('Dosage: ${med.dosage} • Time: ${med.time}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('Instructions: ${med.instructions}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: med.isTakenToday ? AppTheme.successGreenContainer : Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            med.isTakenToday ? 'TAKEN' : 'PENDING',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: med.isTakenToday ? AppTheme.successGreen : Colors.orange.shade900,
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
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 14),

              ...routines.map(
                (routine) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 1,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: Icon(
                      routine.isCompleted ? Icons.task_alt_rounded : Icons.schedule_rounded,
                      color: routine.isCompleted ? AppTheme.successGreen : AppTheme.primaryColor,
                      size: 26,
                    ),
                    title: Text(routine.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Text('${routine.subtitle} • Scheduled: ${routine.time}'),
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
        title: const Text('Add Scheduled Medication'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Medicine Name (e.g. Donepezil)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dosageCtrl,
                decoration: const InputDecoration(labelText: 'Dosage (e.g. 10mg - 1 Tablet)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: timeCtrl,
                decoration: const InputDecoration(labelText: 'Scheduled Time (e.g. 08:00 PM)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: instCtrl,
                decoration: const InputDecoration(labelText: 'Instructions (e.g. Take with water after food)'),
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
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                final newMed = MedicationSchedule(
                  id: 'm-${DateTime.now().millisecondsSinceEpoch}',
                  medicineName: nameCtrl.text,
                  dosage: dosageCtrl.text.isEmpty ? '1 Dose' : dosageCtrl.text,
                  instructions: instCtrl.text.isEmpty ? 'As directed' : instCtrl.text,
                  time: timeCtrl.text,
                  isTakenToday: false,
                );
                ref.read(medicationsProvider.notifier).addMedication(newMed);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Scheduled ${nameCtrl.text} added cleanly.')),
                );
              }
            },
            child: const Text('Save Schedule'),
          ),
        ],
      ),
    );
  }
}
