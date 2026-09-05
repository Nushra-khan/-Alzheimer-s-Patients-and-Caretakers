import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../core/models/models.dart';
import '../../core/providers/app_state.dart';

class CaregiverShellScreen extends ConsumerWidget {
  final Widget child;

  const CaregiverShellScreen({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/caregiver/location')) return 1;
    if (location.startsWith('/caregiver/alerts')) return 2;
    if (location.startsWith('/caregiver/schedules')) return 3;
    if (location.startsWith('/caregiver/profile')) return 4;
    return 0; // default /caregiver/dashboard
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = _calculateSelectedIndex(context);
    final activeAlerts = ref
        .watch(alertsProvider)
        .where((a) => a.status == AlertStatus.active)
        .toList();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        elevation: 0,
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_rounded, color: AppTheme.primaryColor, size: 22),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAlignment.start,
              children: [
                Text(
                  'Caregiver Portal',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  'Active Patient Monitoring',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Active Alerts Badge Counter
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined, size: 28, color: AppTheme.textPrimary),
                if (activeAlerts.isNotEmpty)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.alertRed,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        '${activeAlerts.length}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => context.go('/caregiver/alerts'),
          ),
          // Role switch button
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: ActionChip(
              avatar: const Icon(Icons.person_rounded, size: 18, color: AppTheme.primaryColor),
              label: const Text(
                'Patient View',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
              ),
              backgroundColor: AppTheme.primaryContainer,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onPressed: () {
                ref.read(userRoleProvider.notifier).state = UserRole.patient;
                ref.read(sessionProvider.notifier).enterPreview(UserRole.patient);
                context.go('/patient/today');
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
                context.go('/caregiver/dashboard');
                break;
              case 1:
                context.go('/caregiver/location');
                break;
              case 2:
                context.go('/caregiver/alerts');
                break;
              case 3:
                context.go('/caregiver/schedules');
                break;
              case 4:
                context.go('/caregiver/profile');
                break;
            }
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.dashboard_outlined, size: 24),
              selectedIcon: Icon(Icons.dashboard_rounded, color: AppTheme.primaryColor, size: 26),
              label: 'Dashboard',
            ),
            const NavigationDestination(
              icon: Icon(Icons.map_outlined, size: 24),
              selectedIcon: Icon(Icons.map_rounded, color: AppTheme.primaryColor, size: 26),
              label: 'Location',
            ),
            NavigationDestination(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 24),
                  if (activeAlerts.isNotEmpty)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: AppTheme.alertRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              selectedIcon: const Icon(Icons.warning_rounded, color: AppTheme.alertRed, size: 26),
              label: 'Alerts',
            ),
            const NavigationDestination(
              icon: Icon(Icons.medication_outlined, size: 24),
              selectedIcon: Icon(Icons.medication_rounded, color: AppTheme.primaryColor, size: 26),
              label: 'Schedules',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline_rounded, size: 24),
              selectedIcon: Icon(Icons.person_rounded, color: AppTheme.primaryColor, size: 26),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
