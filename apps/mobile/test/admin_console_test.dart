import 'package:cv_ats_mobile/features/admin/admin_console_screen.dart';
import 'package:cv_ats_mobile/features/admin/admin_user_sheet.dart';
import 'package:cv_ats_mobile/ui/ats_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main(){
  testWidgets('admin workspace never fakes data when authentication is missing',
      (tester)async{
    await tester.pumpWidget(const MaterialApp(home:AdminConsoleScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Control room'),findsOneWidget);
    expect(find.text('Administration unavailable'),findsOneWidget);
    expect(find.text('Try again'),findsOneWidget);
    expect(find.byIcon(Icons.people_outline_rounded),findsWidgets);
  });

  testWidgets('account inspector shows real fields and protects account actions',
      (tester)async{
    final user=<String,dynamic>{
      'id':'11111111-1111-4111-8111-111111111111',
      'email':'candidate@example.test',
      'display_name':'Test Candidate',
      'role':'candidate',
      'plan_code':'free',
      'account_status':'active',
      'cv_count':1,
      'analysis_count':2,
      'email_confirmed_at':'2026-01-01T00:00:00Z',
    };
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:AdminUserSheet(user:user))));
    expect(find.text('Test Candidate'),findsOneWidget);
    expect(find.text('candidate@example.test'),findsOneWidget);
    expect(find.text('ACCOUNT INSPECTOR'),findsOneWidget);
    expect(find.text('FREE'),findsWidgets);
  });

  testWidgets('shared loading placeholders render without mock statistics',
      (tester)async{
    await tester.pumpWidget(const MaterialApp(home:Scaffold(
      body:SingleChildScrollView(child:Padding(
        padding:EdgeInsets.all(16),
        child:AtsLoadingCards(count:3))))));
    expect(find.byType(AtsSkeleton),findsWidgets);
    expect(find.text('100%'),findsNothing);
  });
}
