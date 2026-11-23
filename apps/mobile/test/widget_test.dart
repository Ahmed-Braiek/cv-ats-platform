import 'package:cv_ats_mobile/main.dart';
import 'package:cv_ats_mobile/ui/ats_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('visitor sees core proposition and opens analysis flow', (tester) async {
    await tester.pumpWidget(const CvAtsApp());
    expect(find.text('Analyze my CV'), findsOneWidget);
    expect(find.textContaining('Know how your CV'), findsOneWidget);

    await tester.tap(find.text('Analyze my CV'));
    await tester.pumpAndSettle();
    expect(find.byType(NewAnalysisScreen), findsOneWidget);
    expect(find.text('Job description'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('analysis cannot be submitted while worker is disabled', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: NewAnalysisScreen()));
    final submit = find.widgetWithText(FilledButton, 'Analyze my application');
    expect(submit, findsOneWidget);
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
  });

  testWidgets('visual system supports light and dark modes', (tester) async {
    AtsAppearance.mode.value = ThemeMode.dark;
    await tester.pumpWidget(const CvAtsApp());
    expect(Theme.of(tester.element(find.byType(LandingScreen))).brightness,
      Brightness.dark);
    AtsAppearance.mode.value = ThemeMode.system;
    await tester.pump();
  });
}
