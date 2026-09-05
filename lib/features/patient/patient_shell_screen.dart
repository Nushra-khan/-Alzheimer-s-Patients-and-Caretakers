import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../core/models/models.dart';
import '../../core/providers/app_state.dart';

class PatientShellScreen extends ConsumerWidget {
  final Widget child;

  const PatientShellScreen({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/patient/sos')) return 1;
    if (location.startsWith('/patient/settings')) return 2;
    return 0; // default /patient/today
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = _calculateSelectedIndex(context);
    final patient = ref.watch(patientProvider);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        elevation: 0,
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primaryColor, width: 2),
              ),
              child: const CircleAvatar(
                backgroundColor: AppTheme.primaryContainer,
                radius: 18,
                child: Icon(Icons.person, color: AppTheme.primaryColor, size: 22),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.successGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Synced ${_formatTimeAgo(patient.lastSyncTime)}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Caregiver View Switcher Badge
          Container(
            margin: const EdgeInsets.only(right: 14),
            child: ActionChip(
              avatar: const Icon(Icons.swap_horiz_rounded, size: 18, color: AppTheme.primaryColor),
              label: const Text(
                'Caregiver View',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
              ),
              backgroundColor: AppTheme.primaryContainer,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onPressed: () {
                ref.read(userRoleProvider.notifier).state = UserRole.caregiver;
                ref.read(sessionProvider.notifier).enterPreview(UserRole.caregiver);
                context.go('/caregiver/dashboard');
              },
            ),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          height: 72,
          backgroundColor: Colors.white,
          indicatorColor: AppTheme.primaryContainer,
          onDestinationSelected: (index) {
            switch (index) {
              case 0:
                context.go('/patient/today');
                break;
              case 1:
                context.go('/patient/sos');
                break;
              case 2:
                context.go('/patient/settings');
                break;
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.today_outlined, size: 26),
              selectedIcon: Icon(Icons.today_rounded, color: AppTheme.primaryColor, size: 28),
              label: 'Today',
            ),
            NavigationDestination(
              icon: Icon(Icons.warning_amber_rounded, color: AppTheme.alertRed, size: 28),
              selectedIcon: Icon(Icons.warning_rounded, color: AppTheme.alertRed, size: 30),
              label: 'SOS Emergency',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined, size: 26),
              selectedIcon: Icon(Icons.settings_rounded, color: AppTheme.primaryColor, size: 28),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
