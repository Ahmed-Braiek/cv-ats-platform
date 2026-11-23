import 'package:cv_ats_mobile/main.dart';
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

  testWidgets('appearance controller switches to dark mode',
      (tester) async {
    AtsAppearance.mode.value = ThemeMode.dark;
    await tester.pumpWidget(const CvAtsApp());
    expect(Theme.of(tester.element(find.byType(AuthScreen))).brightness,
        Brightness.dark);
  });
}
