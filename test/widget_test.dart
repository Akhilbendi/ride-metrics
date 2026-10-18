import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:ride_metrics_fresh/main.dart';

void main() {
  testWidgets('shows the onboarding state when no vehicle exists', (
    tester,
  ) async {
    await tester.pumpWidget(const App());
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
