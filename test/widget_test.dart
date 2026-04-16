// Baseline smoke test for the scaffolding. Replaced with real feature tests
// during Phase 1 of the build plan (see SPEC §12).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huetap/main.dart';

void main() {
  testWidgets('App boots without exceptions', (WidgetTester tester) async {
    await tester.pumpWidget(const HueTapApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
