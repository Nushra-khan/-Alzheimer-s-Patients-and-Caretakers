import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/app_state.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/patient/patient_shell_screen.dart';
import '../features/patient/today/today_screen.dart';
import '../features/patient/sos/sos_screen.dart';
import '../features/patient/settings/patient_settings_screen.dart';

import '../features/caregiver/caregiver_shell_screen.dart';
import '../features/caregiver/dashboard/caregiver_dashboard_screen.dart';
import '../features/caregiver/location/location_screen.dart';
import '../features/caregiver/alerts/alerts_screen.dart';
import '../features/caregiver/schedules/schedules_screen.dart';
import '../features/caregiver/profile/caregiver_profile_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(sessionProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final path = state.uri.path;
      final isPublic = path == '/login' || path == '/signup';
      if (isPublic && session.isAuthenticated) {
        return session.canAccessPatient
            ? '/patient/today'
            : '/caregiver/dashboard';
      }
      if (isPublic) return null;
      if (path.startsWith('/patient') && !session.canAccessPatient) {
        return '/login';
      }
      if (path.startsWith('/caregiver') && !session.canAccessCaregiver) {
        return '/login';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      // Patient Navigation Shell
      ShellRoute(
        builder: (context, state, child) {
          return PatientShellScreen(child: child);
        },
        routes: [
          GoRoute(
            path: '/patient/today',
            builder: (context, state) => const TodayScreen(),
          ),
          GoRoute(
            path: '/patient/sos',
            builder: (context, state) => const SosScreen(),
          ),
          GoRoute(
            path: '/patient/settings',
            builder: (context, state) => const PatientSettingsScreen(),
          ),
        ],
      ),
      // Caregiver Navigation Shell
      ShellRoute(
        builder: (context, state, child) {
          return CaregiverShellScreen(child: child);
        },
        routes: [
          GoRoute(
            path: '/caregiver/dashboard',
            builder: (context, state) => const CaregiverDashboardScreen(),
          ),
          GoRoute(
            path: '/caregiver/location',
            builder: (context, state) => const LocationScreen(),
          ),
          GoRoute(
            path: '/caregiver/alerts',
            builder: (context, state) => const AlertsScreen(),
          ),
          GoRoute(
            path: '/caregiver/schedules',
            builder: (context, state) => const SchedulesScreen(),
          ),
          GoRoute(
            path: '/caregiver/profile',
            builder: (context, state) => const CaregiverProfileScreen(),
          ),
        ],
      ),
    ],
  );
});
