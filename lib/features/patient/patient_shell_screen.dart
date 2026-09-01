import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
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
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: AppTheme.primaryContainer,
              radius: 18,
              child: Icon(Icons.person, color: AppTheme.primaryColor, size: 22),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Last Sync: ${_formatTimeAgo(patient.lastSyncTime)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: selectedIndex,
          iconSize: 32,
          selectedFontSize: 15,
          unselectedFontSize: 14,
          onTap: (index) {
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
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.today_rounded),
              activeIcon: Icon(Icons.today_rounded, size: 36),
              label: 'Today',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.warning_amber_rounded, color: AppTheme.alertRed),
              activeIcon: Icon(
                Icons.warning_rounded,
                color: AppTheme.alertRed,
                size: 38,
              ),
              label: 'SOS Emergency',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded),
              activeIcon: Icon(Icons.settings_rounded, size: 36),
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
