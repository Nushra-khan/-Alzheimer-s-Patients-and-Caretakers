import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/providers/app_state.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medications = ref.watch(medicationsProvider);
    final routines = ref.watch(routinesProvider);
    final upcomingMeds = medications.where((m) => !m.isTakenToday).toList();
    final takenMedsCount = medications.where((m) => m.isTakenToday).length;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
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
                              Icon(Icons.wb_sunny_rounded, color: Colors.amber, size: 28),
                              SizedBox(width: 8),
                              Text(
                                'Today’s Overview',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${medications.length - upcomingMeds.length}/${medications.length} Doses',
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
                        upcomingMeds.isEmpty
                            ? '🎉 Excellent work! All medicines taken.'
                            : 'You have ${upcomingMeds.length} medicine dose(s) remaining.',
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
                          value: medications.isEmpty ? 0 : (takenMedsCount / medications.length),
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
                      '💊 Medication Reminders',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      '${medications.length} Items',
                      style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                if (medications.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('No medications scheduled for today.'),
                  )
                else
                  ...medications.map(
                    (med) => _MedicationCard(
                      medication: med,
                      onToggleTaken: () {
                        ref.read(medicationsProvider.notifier).toggleDoseTaken(med.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              med.isTakenToday
                                  ? 'Marked ${med.medicineName} dose as pending.'
                                  : 'Reported ${med.medicineName} dose taken! Caregivers notified.',
                            ),
                            backgroundColor:
                                med.isTakenToday ? Colors.black87 : AppTheme.successGreen,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 32),

                // Daily Routine Reminders Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '🌱 Daily Activities & Routines',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      '${routines.where((r) => r.isCompleted).length}/${routines.length} Done',
                      style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                ...routines.map(
                  (routine) => _RoutineCard(
                    routine: routine,
                    onToggleCompleted: () {
                      ref.read(routinesProvider.notifier).toggleRoutine(routine.id);
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
}

class _MedicationCard extends StatelessWidget {
  final dynamic medication;
  final VoidCallback onToggleTaken;

  const _MedicationCard({
    required this.medication,
    required this.onToggleTaken,
  });

  @override
  Widget build(BuildContext context) {
    final bool isTaken = medication.isTakenToday;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isTaken ? AppTheme.successGreenContainer.withValues(alpha: 0.35) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isTaken ? AppTheme.successGreen : Colors.grey.shade300,
          width: isTaken ? 2 : 1,
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
        crossAxisAlignment: CrossAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isTaken ? AppTheme.successGreen : AppTheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isTaken ? Icons.check_circle_rounded : Icons.medication_rounded,
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
                      medication.medicineName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isTaken ? AppTheme.successGreen : AppTheme.textPrimary,
                        decoration: isTaken ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${medication.dosage} • ${medication.time}',
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isTaken ? Colors.transparent : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    medication.instructions,
                    style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Large Action Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isTaken ? Colors.grey.shade200 : AppTheme.primaryColor,
              foregroundColor: isTaken ? Colors.black87 : Colors.white,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: isTaken ? 0 : 2,
            ),
            onPressed: onToggleTaken,
            icon: Icon(isTaken ? Icons.undo_rounded : Icons.check_rounded, size: 24),
            label: Text(
              isTaken ? 'Mark as Not Taken' : 'I TOOK THIS MEDICINE',
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

  const _RoutineCard({
    required this.routine,
    required this.onToggleCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = routine.isCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isCompleted ? Colors.grey.shade300 : Colors.grey.shade200),
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
            isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
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
          crossAxisAlignment: CrossAlignment.start,
          children: [
            Text(routine.subtitle, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 2),
            Text(
              'Time: ${routine.time}',
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
