import 'package:cv_ats_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('landing shows the candidate-first CTA', (tester) async {
    await tester.pumpWidget(const CvAtsApp());
    expect(find.text('Analyze my CV'), findsOneWidget);
    expect(find.text('ATS compatibility'), findsOneWidget);
    expect(find.text('Job Match'), findsOneWidget);
    await tester.tap(find.text('Analyze my CV'));
    await tester.pumpAndSettle();
    expect(find.byType(NewAnalysisScreen), findsOneWidget);
    expect(find.text('Job description'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });
}
