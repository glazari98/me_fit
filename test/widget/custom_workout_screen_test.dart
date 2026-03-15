import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:me_fit/screens/custom_workouts.dart';
void main() {
//test to check screen loads correctly
  testWidgets('CustomWorkouts screen loads correctly',(tester) async{
    await tester.pumpWidget(
      const MaterialApp(
        home: CustomWorkouts(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Custom Workouts'), findsOneWidget);
  });
//test to check if search field appears and that text is correctly accepted from controller
  testWidgets('Search field exists and accepts text',(tester) async{
    await tester.pumpWidget(
      const MaterialApp(
        home: CustomWorkouts(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'legs');
    await tester.pump();
    expect(find.text('legs'), findsOneWidget);
  });
//button to create a custom workout appears
  testWidgets('FloatingActionButton exists',(tester) async{
    await tester.pumpWidget(
      const MaterialApp(
        home: CustomWorkouts(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

}