import 'package:cv_ats_mobile/main.dart';
import 'package:cv_ats_mobile/features/analysis/analysis_report_screen.dart';
import 'package:cv_ats_mobile/features/auth/auth_screen.dart';
import 'package:cv_ats_mobile/ui/ats_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    AtsAppearance.mode.value = ThemeMode.system;
  });

  testWidgets('opens directly on Sign in, not a marketing home page',
      (tester) async {
    await tester.pumpWidget(const CvAtsApp());
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Know how your CV'), findsNothing);
  });

  testWidgets('Create account tab reveals name and password confirmation',
      (tester) async {
    await tester.pumpWidget(const CvAtsApp());
    await tester.tap(find.text('Create account').first);
    await tester.pumpAndSettle();
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    expect(find.text('Create your account'), findsOneWidget);

    await tester.tap(find.text('Sign in').first);
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('verification code input accepts configured lengths from 6 to 10',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: VerificationCodeScreen(email: 'test@example.com'),
    ));
    expect(find.text('Check your inbox.'), findsOneWidget);
    expect(find.text('test@example.com'), findsOneWidget);
    expect(find.text('Verification code'), findsOneWidget);
    final field = find.byType(TextField);
    expect(tester.widget<TextField>(field).maxLength, 10);

    FilledButton verifyButton() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Verify and continue'),
    );

    expect(verifyButton().onPressed, isNull);
    await tester.enterText(field, '12345');
    await tester.pump();
    expect(verifyButton().onPressed, isNull);

    await tester.enterText(field, '12345678');
    await tester.pump();
    expect(tester.widget<TextField>(field).controller?.text, '12345678');
    expect(verifyButton().onPressed, isNotNull);

    await tester.enterText(field, '1234567890');
    await tester.pump();
    expect(tester.widget<TextField>(field).controller?.text, '1234567890');
    expect(verifyButton().onPressed, isNotNull);
  });

  testWidgets('analysis remains gated before the worker is verified',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: NewAnalysisScreen()));
    final disabled = find.byWidgetPredicate(
      (widget) => widget is FilledButton && widget.onPressed == null,
    );
    expect(disabled, findsWidgets);
  });

  testWidgets('CV upload remains usable on a narrow mobile viewport',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(
      theme: AtsTheme.light(),
      home: const NewAnalysisScreen(),
    ));
    expect(find.text('Analyze your application'), findsOneWidget);
    expect(find.text('Choose your CV to get started'), findsOneWidget);
    await tester.ensureVisible(find.text('Analyze my application'));
    await tester.pump();
    expect(find.text('Analyze my application'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('evidence report explains scores and provides requirement filters',
      (tester) async {
    final report = <String, dynamic>{
      'ats': {
        'overall': 83,
        'rubric_json': {
          'version': 'ats-match-v0.2',
          'checks': [
            {'title': 'Readable content', 'score': 14,
             'max': 20, 'note': 'Text extraction verified'},
          ],
        },
      },
      'match': {
        'overall': 36,
        'rubric_json': {
          'version': 'ats-match-v0.2',
          'job_title': 'Marketing Coordinator',
          'summary': {'total': 3, 'direct': 1,
            'transferable': 1, 'missing': 1, 'confidence': 'moderate'},
          'required_coverage': .40,
          'preferred_coverage': 0,
          'category_scores': {'soft_skill': 100, 'tool': 0},
          'requirements': [
            {'id': 'R1', 'text': 'Communication',
              'importance': 'required', 'status': 'direct',
              'evidence_quote': 'Strong client communication',
              'source_quote': 'Strong written and verbal communication skills.',
              'explanation': 'Supported by client work'},
            {'id': 'R2', 'text': 'Campaign coordination',
              'importance': 'required', 'status': 'transferable',
              'evidence_quote': 'Managed projects from idea to delivery',
              'source_quote': 'Coordinate promotional events and campaigns.',
              'explanation': 'Some adjacent project experience'},
            {'id': 'R3', 'text': 'Google Analytics',
              'importance': 'required', 'status': 'missing',
              'evidence_quote': '',
              'source_quote': 'Familiarity with Google Analytics.',
              'explanation': 'Not demonstrated'},
          ],
        },
      },
      'recommendations': [
        {'priority': 1, 'category': 'job_gap',
          'message': 'Only add Google Analytics if you have used it.'},
      ],
    };
    await tester.pumpWidget(MaterialApp(
      home: AnalysisReportScreen(payload: report)));
    expect(find.text('Marketing Coordinator'), findsWidgets);
    expect(find.text('36'), findsWidgets);
    expect(find.text('83/100'), findsOneWidget);

    await tester.tap(find.text('Job match').first);
    await tester.pumpAndSettle();
    expect(find.text('Marketing Coordinator'), findsOneWidget);
    expect(find.textContaining('Match decisions are backed'), findsOneWidget);

    await tester.tap(find.text('Next steps').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Only add Google Analytics'), findsOneWidget);
  });

  testWidgets('appearance controller switches to dark mode',
      (tester) async {
    AtsAppearance.mode.value = ThemeMode.dark;
    await tester.pumpWidget(const CvAtsApp());
    expect(Theme.of(tester.element(find.byType(AuthScreen))).brightness,
        Brightness.dark);
  });
}
