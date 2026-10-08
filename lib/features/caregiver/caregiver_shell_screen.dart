import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/models/models.dart';
import '../../core/providers/app_state.dart';

class CaregiverShellScreen extends ConsumerWidget {
  const CaregiverShellScreen({super.key, required this.child});

  final Widget child;

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/caregiver/location')) return 1;
    if (location.startsWith('/caregiver/alerts')) return 2;
    if (location.startsWith('/caregiver/schedules')) return 3;
    if (location.startsWith('/caregiver/profile')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final careData = ref.watch(careBootstrapProvider);
    ref.watch(careRealtimeProvider);
    final activeAlertCount = ref
        .watch(alertsProvider)
        .where((alert) => alert.status == AlertStatus.active)
        .length;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 18,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/branding/memora_app_icon.png',
                width: 42,
                height: 42,
                fit: BoxFit.cover,
                semanticLabel: 'Memora',
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Memora',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: activeAlertCount == 0
                ? 'No active alerts'
                : '$activeAlertCount active alerts',
            onPressed: () => context.go('/caregiver/alerts'),
            icon: Badge(
              isLabelVisible: activeAlertCount > 0,
              label: Text('$activeAlertCount'),
              backgroundColor: AppTheme.alertRed,
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: careData.when(
        data: (status) => status == CareBootstrapStatus.needsPatient
            ? const _ConnectPatientView()
            : child,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Unable to load data'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => ref.invalidate(careBootstrapProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex(context),
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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.location_on_outlined),
            selectedIcon: Icon(Icons.location_on_rounded),
            label: 'Location',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none_rounded),
            selectedIcon: Icon(Icons.notifications_rounded),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note_rounded),
            label: 'Schedule',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _ConnectPatientView extends ConsumerStatefulWidget {
  const _ConnectPatientView();

  @override
  ConsumerState<_ConnectPatientView> createState() =>
      _ConnectPatientViewState();
}

class _ConnectPatientViewState extends ConsumerState<_ConnectPatientView> {
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final repository = ref.read(careRepositoryProvider);
    if (repository == null || _codeController.text.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await repository.acceptCareInvitation(_codeController.text);
      ref.invalidate(careBootstrapProvider);
    } catch (_) {
      if (mounted) setState(() => _error = 'Invalid or expired code');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.link_rounded, size: 52),
              const SizedBox(height: 12),
              const Text(
                'Connect patient',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Invitation code',
                  errorText: _error,
                ),
                onSubmitted: (_) => _connect(),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : _connect,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Connect'),
              ),
              TextButton(
                onPressed: _loading
                    ? null
                    : () async {
                        await ref.read(sessionProvider.notifier).signOut();
                        if (context.mounted) context.go('/login');
                      },
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
