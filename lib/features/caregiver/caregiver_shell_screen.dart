import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../app/theme.dart';
import '../../core/models/models.dart';
import '../../core/providers/app_state.dart';
import '../auth/auth_service.dart';

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
    final selectedIndex = _selectedIndex(context);

    // Android Back: return to Home from other tabs; exit only from Home.
    return PopScope(
      canPop: selectedIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/caregiver/dashboard');
      },
      child: Scaffold(
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
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
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
          // Every tab except Profile shows the patient's data, so they show
          // the connect screen until a patient is linked.
          data: (status) =>
              status == CareBootstrapStatus.needsPatient && selectedIndex != 4
              ? const _ConnectPatientView()
              : child,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _LoadErrorView(error: error),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
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

  /// Codes are 16 letters and numbers; accept them with spaces or dashes.
  static String _normalizeCode(String value) =>
      value.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();

  Future<void> _connect() async {
    final repository = ref.read(careRepositoryProvider);
    if (repository == null) return;
    final code = _normalizeCode(_codeController.text);
    if (!RegExp(r'^[0-9A-F]{16}$').hasMatch(code)) {
      setState(
        () => _error = code.isEmpty
            ? 'Enter the code from the patient\'s phone'
            : 'Codes have 16 letters and numbers. Check and try again.',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await repository.acceptCareInvitation(code);
      ref.invalidate(careBootstrapProvider);
      // Start live updates for the newly connected patient.
      ref.invalidate(careRealtimeProvider);
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.message.contains('invalid or expired')
              ? 'Invalid or expired code. Ask the patient for a new one.'
              : error.message,
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = readableAuthError(error));
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
              const SizedBox(height: 8),
              const Text(
                'Link this account to the person you care for to see their '
                'medicines, routines, location and alerts.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              const Text(
                'On the patient\'s phone, open Memora and go to '
                'Settings → Caregiver code. Enter that code below '
                'within 15 minutes.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
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


/// Shown when care data cannot load. Offers a retry and a way out, so the
/// user is never stuck on this screen.
class _LoadErrorView extends ConsumerWidget {
  const _LoadErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load data',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              readableAuthError(error),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => ref.invalidate(careBootstrapProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
            TextButton(
              onPressed: () => ref.read(sessionProvider.notifier).signOut(),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
