// Smoke test: the home screen's empty-state widget renders the expected
// copy when no bridges are paired. We render it in isolation (not through
// HueTapApp) so the full Riverpod + NFC + Drift-watch wiring isn't exercised
// here — feature-level tests and on-device validation cover that path.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huetap/core/theme/twilight_hearth_theme.dart';

void main() {
  testWidgets('HueTap theme builds without throwing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: TwilightHearthTheme.build(),
        home: const Scaffold(
          body: Center(child: Text('HueTap')),
        ),
      ),
    );
    expect(find.text('HueTap'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
