import 'package:alzheimers_care/core/models/models.dart';
import 'package:alzheimers_care/core/providers/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session starts signed out and receives a server-assigned role', () {
    final notifier = SessionNotifier();

    expect(notifier.state.isAuthenticated, isFalse);
    expect(notifier.state.role, isNull);

    notifier.establishAuthenticatedSession(UserRole.caregiver);

    expect(notifier.state.isAuthenticated, isTrue);
    expect(notifier.state.canAccessCaregiver, isTrue);
    expect(notifier.state.canAccessPatient, isFalse);

    notifier.signOut();
    expect(notifier.state.role, isNull);
  });

  test('reporting a dose is one-way in patient state', () {
    final notifier = DoseInstanceNotifier();
    final doseId = notifier.state.first.id;

    notifier.reportDoseTaken(doseId);
    final firstReportedAt = notifier.state.first.reportedAt;
    notifier.reportDoseTaken(doseId);

    expect(notifier.state.first.status, DoseStatus.reportedTaken);
    expect(notifier.state.first.reportedAt, firstReportedAt);
  });
}
