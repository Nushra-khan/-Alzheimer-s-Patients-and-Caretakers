import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:alzheimers_care/main.dart';
import 'package:alzheimers_care/features/auth/reset_password_screen.dart';
import 'package:alzheimers_care/features/patient/settings/patient_settings_screen.dart';
import 'package:alzheimers_care/features/caregiver/schedules/schedules_screen.dart';

void main() {
  testWidgets('App opens directly to Login screen smoke test', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MemoraApp()));

    expect(find.text('Memora'), findsOneWidget);
    expect(find.text('Sign in to continue'), findsNothing);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text("Don't have an account?"), findsOneWidget);
    expect(find.textContaining('Preview'), findsNothing);
    expect(find.text('Secure caregiver support'), findsNothing);

    await tester.ensureVisible(find.text('Sign up'));
    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();

    expect(find.text('Sign up'), findsWidgets);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
  });

  testWidgets('Login validates required credentials', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MemoraApp()));

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Login'));
    await tester.tap(find.widgetWithText(FilledButton, 'Login'));
    await tester.pump();

    expect(find.text('Enter your email address'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });

  testWidgets('Forgot-password screen validates email', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MemoraApp()));

    await tester.ensureVisible(find.text('Forgot password?'));
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(find.text('Forgot your password?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Send reset link'));
    await tester.pump();

    expect(find.text('Enter your email address'), findsOneWidget);
  });

  testWidgets('Reset-password screen validates both passwords', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ResetPasswordScreen())),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Update password'));
    await tester.pump();

    expect(find.text('Use at least 8 characters'), findsOneWidget);
  });

  testWidgets('Sign-up validates required account details', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MemoraApp()));

    await tester.ensureVisible(find.text('Sign up'));
    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Sign up'));
    await tester.tap(find.widgetWithText(FilledButton, 'Sign up'));
    await tester.pump();

    expect(find.text('Enter your full name'), findsOneWidget);
    expect(find.text('Enter your email address'), findsOneWidget);
    expect(find.text('Use at least 8 characters'), findsOneWidget);
  });

  testWidgets('patient must confirm before removing a caregiver', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: PatientSettingsScreen())),
    );

    final removeButton = find.byTooltip('Remove Sunita Sharma');
    await tester.ensureVisible(removeButton);
    await tester.tap(removeButton);
    await tester.pumpAndSettle();

    expect(find.text('Remove caregiver?'), findsOneWidget);
    expect(find.text('Remove access'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Remove caregiver?'), findsNothing);
  });

  testWidgets('caregiver must confirm before stopping medication', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SchedulesScreen())),
    );

    final options = find.byTooltip('Medication options for Donepezil');
    await tester.ensureVisible(options);
    await tester.tap(options);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop medication').last);
    await tester.pumpAndSettle();

    expect(find.text('Stop this medication?'), findsOneWidget);
    expect(
      find.textContaining('Past dose records will be kept.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Stop this medication?'), findsNothing);
  });
}
