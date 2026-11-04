import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/app_state.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medications = ref.watch(doseInstancesProvider);
    final routines = ref.watch(routinesProvider);
    final pendingMeds = medications
        .where(
          (dose) =>
              dose.status == DoseStatus.scheduled ||
              dose.status == DoseStatus.overdue,
        )
        .toList();
    final recordedDoseCount = medications
        .where(
          (dose) =>
              dose.status == DoseStatus.reportedTaken ||
              dose.status == DoseStatus.skipped,
        )
        .length;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Today's Greeting & Progress Hero Banner
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6750A4), Color(0xFF4F378B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(
                                Icons.wb_sunny_rounded,
                                color: Colors.amber,
                                size: 28,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Today',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$recordedDoseCount/${medications.length} Doses',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        pendingMeds.isEmpty
                            ? 'All doses recorded.'
                            : '${pendingMeds.length} dose(s) remaining',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Linear Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: medications.isEmpty
                              ? 0
                              : (recordedDoseCount / medications.length),
                          backgroundColor: Colors.white24,
                          color: AppTheme.primaryContainer,
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Upcoming Medications Header
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
                  ],
                ),
                const SizedBox(height: 14),

                if (medications.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('No medication today'),
                  )
                else
                  ...medications.map(
                    (med) => _MedicationCard(
                      medication: med,
                      onMarkTaken: () async {
                        try {
                          await ref
                              .read(doseInstancesProvider.notifier)
                              .reportDoseTaken(med.id);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Marked as taken'),
                              backgroundColor: AppTheme.successGreen,
                            ),
                          );
                        } catch (_) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Unable to update')),
                          );
                        }
                      },
                      onSkip: () => _confirmSkipDose(context, ref, med),
                      onCorrect: () async {
                        try {
                          await ref
                              .read(doseInstancesProvider.notifier)
                              .correctDose(med.id);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Dose returned to pending'),
                            ),
                          );
                        } catch (_) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Unable to update')),
                          );
                        }
                      },
                    ),
                  ),

                const SizedBox(height: 32),

                // Daily Routine Reminders Header
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
                    Text(
                      '${routines.where((r) => r.isCompleted).length}/${routines.length} Done',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                ...routines.map(
                  (routine) => _RoutineCard(
                    routine: routine,
                    onToggleCompleted: () async {
                      try {
                        await ref
                            .read(routinesProvider.notifier)
                            .toggleRoutine(routine.id);
                      } catch (_) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Unable to update')),
                        );
                      }
                    },
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSkipDose(
    BuildContext context,
    WidgetRef ref,
    DoseInstance dose,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Skip this dose?'),
        content: Text(
          '${dose.medicineName} will be recorded as skipped. You can correct it afterward if needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Skip dose'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(doseInstancesProvider.notifier).skipDose(dose.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Dose recorded as skipped')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to update')));
    }
  }
}

class _MedicationCard extends StatelessWidget {
  final DoseInstance medication;
  final VoidCallback onMarkTaken;
  final VoidCallback onSkip;
  final VoidCallback onCorrect;

  const _MedicationCard({
    required this.medication,
    required this.onMarkTaken,
    required this.onSkip,
    required this.onCorrect,
  });

  @override
  Widget build(BuildContext context) {
    final bool isTaken = medication.isReportedTaken;
    final bool isSkipped = medication.status == DoseStatus.skipped;
    final bool isRecorded = isTaken || isSkipped;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isTaken
            ? AppTheme.successGreenContainer.withValues(alpha: 0.35)
            : isSkipped
            ? Colors.orange.shade50
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isTaken
              ? AppTheme.successGreen
              : isSkipped
              ? Colors.orange.shade400
              : Colors.grey.shade300,
          width: isRecorded ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isTaken
                      ? AppTheme.successGreen
                      : isSkipped
                      ? Colors.orange.shade400
                      : AppTheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isTaken
                      ? Icons.check_circle_rounded
                      : isSkipped
                      ? Icons.not_interested_rounded
                      : Icons.medication_rounded,
                  color: isRecorded ? Colors.white : AppTheme.primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medication.medicineName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isTaken
                            ? AppTheme.successGreen
                            : isSkipped
                            ? Colors.orange.shade900
                            : AppTheme.textPrimary,
                        decoration: isRecorded
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${medication.dosage} • ${TimeOfDay.fromDateTime(medication.scheduledFor).format(context)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isRecorded)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isTaken
                        ? AppTheme.successGreen
                        : Colors.orange.shade700,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isTaken ? 'TAKEN' : 'SKIPPED',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isRecorded ? Colors.transparent : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 18,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    medication.instructions,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          if (isRecorded)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
              onPressed: onCorrect,
              icon: const Icon(Icons.undo_rounded),
              label: const Text('Correct status'),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                    ),
                    onPressed: onSkip,
                    icon: const Icon(Icons.not_interested_rounded),
                    label: const Text('Skip'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 52),
                    ),
                    onPressed: onMarkTaken,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Taken'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  final dynamic routine;
  final VoidCallback onToggleCompleted;

  const _RoutineCard({required this.routine, required this.onToggleCompleted});

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = routine.isCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted ? Colors.grey.shade300 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: IconButton(
          icon: Icon(
            isCompleted
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: isCompleted ? AppTheme.successGreen : AppTheme.primaryColor,
            size: 32,
          ),
          onPressed: onToggleCompleted,
        ),
        title: Text(
          routine.title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            decoration: isCompleted ? TextDecoration.lineThrough : null,
            color: isCompleted ? Colors.grey : AppTheme.textPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(routine.subtitle, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 2),
            Text(
              routine.time,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
