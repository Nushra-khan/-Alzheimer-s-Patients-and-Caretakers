import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/app_state.dart';

enum _MedicationAction { edit, deactivate }

enum _RoutineAction { edit, deactivate }

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
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _doseStatusBackground(med.status),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _doseStatusLabel(med.status),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _doseStatusColor(med.status),
                            ),
                          ),
                        ),
                        PopupMenuButton<_MedicationAction>(
                          tooltip: 'Medication options for ${med.medicineName}',
                          onSelected: (action) {
                            switch (action) {
                              case _MedicationAction.edit:
                                _showEditMedicationDialog(context, ref, med);
                                break;
                              case _MedicationAction.deactivate:
                                _confirmMedicationDeactivation(
                                  context,
                                  ref,
                                  med,
                                );
                                break;
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: _MedicationAction.edit,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.edit_outlined,
                                    color: AppTheme.primaryColor,
                                  ),
                                  SizedBox(width: 10),
                                  Text('Edit details'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: _MedicationAction.deactivate,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.remove_circle_outline_rounded,
                                    color: AppTheme.alertRed,
                                  ),
                                  SizedBox(width: 10),
                                  Text('Stop medication'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Daily Routine Reminders Management
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Routine',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showRoutineDialog(context, ref),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Add'),
                  ),
                ],
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
                    trailing: PopupMenuButton<_RoutineAction>(
                      tooltip: 'Routine options for ${routine.title}',
                      onSelected: (action) {
                        switch (action) {
                          case _RoutineAction.edit:
                            _showRoutineDialog(context, ref, routine: routine);
                            break;
                          case _RoutineAction.deactivate:
                            _confirmRoutineDeactivation(context, ref, routine);
                            break;
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: _RoutineAction.edit,
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_outlined,
                                color: AppTheme.primaryColor,
                              ),
                              SizedBox(width: 10),
                              Text('Edit routine'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: _RoutineAction.deactivate,
                          child: Row(
                            children: [
                              Icon(
                                Icons.remove_circle_outline_rounded,
                                color: AppTheme.alertRed,
                              ),
                              SizedBox(width: 10),
                              Text('Stop routine'),
                            ],
                          ),
                        ),
                      ],
                    ),
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

  Future<void> _showRoutineDialog(
    BuildContext context,
    WidgetRef ref, {
    RoutineItem? routine,
  }) async {
    final titleController = TextEditingController(text: routine?.title ?? '');
    final descriptionController = TextEditingController(
      text: routine?.subtitle ?? '',
    );
    final timeController = TextEditingController(
      text: routine?.time ?? '08:00 AM',
    );
    var isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(routine == null ? 'Add routine' : 'Edit routine'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  enabled: !isSaving,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Routine title',
                    hintText: 'Morning walk',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  enabled: !isSaving,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: '15-minute gentle walk',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: timeController,
                  enabled: !isSaving,
                  decoration: const InputDecoration(
                    labelText: 'Reminder time',
                    hintText: '08:00 AM',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final title = titleController.text.trim();
                      final scheduledFor = _parseScheduledTime(
                        timeController.text,
                      );
                      if (title.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Routine title is required.'),
                          ),
                        );
                        return;
                      }
                      if (scheduledFor == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Enter a valid reminder time.'),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      final displayTime = TimeOfDay.fromDateTime(
                        scheduledFor,
                      ).format(context);
                      try {
                        final notifier = ref.read(routinesProvider.notifier);
                        if (routine == null) {
                          final timestamp =
                              DateTime.now().microsecondsSinceEpoch;
                          await notifier.addRoutine(
                            RoutineItem(
                              id: 'routine-$timestamp',
                              title: title,
                              subtitle: descriptionController.text.trim(),
                              time: displayTime,
                              isCompleted: false,
                            ),
                            patientId: ref.read(patientProvider).id,
                            scheduledFor: scheduledFor,
                          );
                        } else {
                          await notifier.updateRoutine(
                            routineId: routine.id,
                            title: title,
                            description: descriptionController.text,
                            displayTime: displayTime,
                            scheduledFor: scheduledFor,
                          );
                        }
                        if (!dialogContext.mounted) return;
                        Navigator.of(dialogContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              routine == null
                                  ? '$title added.'
                                  : '$title updated.',
                            ),
                          ),
                        );
                      } catch (_) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() => isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              routine == null
                                  ? 'Unable to add routine. Please try again.'
                                  : 'Unable to update routine. Please try again.',
                            ),
                          ),
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(routine == null ? 'Add routine' : 'Save changes'),
            ),
          ],
        ),
      ),
    );

    titleController.dispose();
    descriptionController.dispose();
    timeController.dispose();
  }

  Future<void> _confirmRoutineDeactivation(
    BuildContext context,
    WidgetRef ref,
    RoutineItem routine,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Stop this routine?'),
        content: Text(
          '${routine.title} will be removed from the active schedule. Past completion records will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.alertRed),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Stop routine'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(routinesProvider.notifier).deactivateRoutine(routine.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${routine.title} is no longer active.')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to stop routine. Please try again.'),
        ),
      );
    }
  }

  Future<void> _showEditMedicationDialog(
    BuildContext context,
    WidgetRef ref,
    DoseInstance medication,
  ) async {
    final nameController = TextEditingController(text: medication.medicineName);
    final dosageController = TextEditingController(text: medication.dosage);
    final instructionsController = TextEditingController(
      text: medication.instructions,
    );
    var isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Edit medication'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  enabled: !isSaving,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Medicine'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dosageController,
                  enabled: !isSaving,
                  decoration: const InputDecoration(labelText: 'Dosage'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: instructionsController,
                  enabled: !isSaving,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Instructions'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      final dosage = dosageController.text.trim();
                      if (name.isEmpty || dosage.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Medicine and dosage are required.'),
                          ),
                        );
                        return;
                      }
                      setDialogState(() => isSaving = true);
                      try {
                        await ref
                            .read(doseInstancesProvider.notifier)
                            .updateMedicationDetails(
                              patientId: ref.read(patientProvider).id,
                              medicationId: medication.medicationId,
                              medicineName: name,
                              dosage: dosage,
                              instructions: instructionsController.text,
                            );
                        if (!dialogContext.mounted) return;
                        Navigator.of(dialogContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$name updated.')),
                        );
                      } catch (_) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() => isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Unable to update medication. Please try again.',
                            ),
                          ),
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save changes'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    dosageController.dispose();
    instructionsController.dispose();
  }

  Future<void> _confirmMedicationDeactivation(
    BuildContext context,
    WidgetRef ref,
    DoseInstance medication,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Stop this medication?'),
        content: Text(
          '${medication.medicineName} will be removed from the active schedule. Past dose records will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.alertRed),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Stop medication'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(doseInstancesProvider.notifier)
          .deactivateMedication(
            patientId: ref.read(patientProvider).id,
            medicationId: medication.medicationId,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${medication.medicineName} is no longer active.'),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to stop medication. Please try again.'),
        ),
      );
    }
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

String _doseStatusLabel(DoseStatus status) => switch (status) {
  DoseStatus.reportedTaken => 'TAKEN',
  DoseStatus.skipped => 'SKIPPED',
  DoseStatus.overdue => 'OVERDUE',
  DoseStatus.scheduled => 'PENDING',
};

Color _doseStatusColor(DoseStatus status) => switch (status) {
  DoseStatus.reportedTaken => AppTheme.successGreen,
  DoseStatus.skipped => Colors.blueGrey.shade700,
  DoseStatus.overdue => AppTheme.alertRed,
  DoseStatus.scheduled => Colors.orange.shade900,
};

Color _doseStatusBackground(DoseStatus status) => switch (status) {
  DoseStatus.reportedTaken => AppTheme.successGreenContainer,
  DoseStatus.skipped => Colors.blueGrey.shade100,
  DoseStatus.overdue => Colors.red.shade100,
  DoseStatus.scheduled => Colors.orange.shade100,
};
