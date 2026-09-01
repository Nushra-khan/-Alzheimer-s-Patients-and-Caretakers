import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/theme.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/app_state.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doses = ref.watch(doseInstancesProvider);
    final routines = ref.watch(routinesProvider);
    final upcomingDoses = doses.where((dose) => !dose.isReportedTaken).toList();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 600));
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Today's greeting & status banner
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.wb_sunny_rounded,
                        size: 40,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Today’s Schedule',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              upcomingDoses.isEmpty
                                  ? 'All scheduled doses are reported for today.'
                                  : 'You have ${upcomingDoses.length} dose(s) awaiting a report today.',
                              style: const TextStyle(
                                fontSize: 15,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Upcoming Medications Header
                const Text(
                  '💊 Medication Reminders',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                if (doses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text('No medications scheduled.'),
                  )
                else
                  ...doses.map(
                    (dose) => _MedicationCard(
                      dose: dose,
                      onReportTaken: dose.isReportedTaken
                          ? null
                          : () {
                              ref
                                  .read(doseInstancesProvider.notifier)
                                  .reportDoseTaken(dose.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${dose.medicineName} was reported taken.',
                                  ),
                                  backgroundColor: AppTheme.successGreen,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                    ),
                  ),

                const SizedBox(height: 32),

                // Daily Routine Reminders Header
                const Text(
                  '🌱 Daily Activities & Routines',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                ...routines.map(
                  (routine) => _RoutineCard(
                    routine: routine,
                    onToggleCompleted: () {
                      ref
                          .read(routinesProvider.notifier)
                          .toggleRoutine(routine.id);
                    },
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MedicationCard extends StatelessWidget {
  final DoseInstance dose;
  final VoidCallback? onReportTaken;

  const _MedicationCard({required this.dose, required this.onReportTaken});

  @override
  Widget build(BuildContext context) {
    final isTaken = dose.isReportedTaken;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isTaken
            ? AppTheme.successGreenContainer.withValues(alpha: 0.4)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTaken ? AppTheme.successGreen : Colors.grey.shade300,
          width: isTaken ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isTaken
                      ? AppTheme.successGreen
                      : AppTheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isTaken
                      ? Icons.check_circle_rounded
                      : Icons.medication_rounded,
                  color: isTaken ? Colors.white : AppTheme.primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dose.medicineName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isTaken
                            ? AppTheme.successGreen
                            : AppTheme.textPrimary,
                        decoration: isTaken ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${dose.dosage} • ${DateFormat.jm().format(dose.scheduledFor)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isTaken)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'TAKEN',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            dose.instructions,
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          // Large Action Button (Min 52dp height for high accessibility)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isTaken
                  ? Colors.grey.shade200
                  : AppTheme.primaryColor,
              foregroundColor: isTaken ? Colors.black87 : Colors.white,
              minimumSize: const Size(double.infinity, 52),
              elevation: isTaken ? 0 : 2,
            ),
            onPressed: onReportTaken,
            icon: Icon(
              isTaken ? Icons.check_circle_rounded : Icons.check_rounded,
              size: 24,
            ),
            label: Text(
              isTaken ? 'REPORTED TAKEN' : 'REPORT THIS DOSE TAKEN',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
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
              'Scheduled: ${routine.time}',
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
