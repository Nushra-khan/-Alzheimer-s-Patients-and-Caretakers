import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alzheimers_care/main.dart';

void main() {
  testWidgets('App renders Welcome screen smoke test', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: AlzheimersCareApp()));

    // Verify that Alzheimer's Care welcome title appears
    expect(find.text("Alzheimer’s Care"), findsOneWidget);
  });
}
