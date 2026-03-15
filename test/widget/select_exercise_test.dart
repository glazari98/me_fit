import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:me_fit/screens/select_exercise_screen.dart';
void main() {
//test to see if select exercise screen renders correctly
  testWidgets('SelectExerciseScreen loads correctly',(WidgetTester tester) async{
    await tester.pumpWidget(
      const MaterialApp(
        home: SelectExerciseScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Select Exercise'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
  });
//test to see if text written in the search bar is inputted correctly
  testWidgets('Search field accepts text',(WidgetTester tester) async{
    await tester.pumpWidget(
      const MaterialApp(
        home: SelectExerciseScreen(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'bench');
    await tester.pump();
    expect(find.text('bench'), findsOneWidget);
  });
//check to see if state of sorting button changes accordingly, including the icon
  testWidgets('Sort button toggles', (WidgetTester tester) async{
    await tester.pumpWidget(
      const MaterialApp(
        home: SelectExerciseScreen(),
      ),
    );
    await tester.pumpAndSettle();
    final sortButton = find.byIcon(Icons.arrow_upward);
    expect(sortButton, findsOneWidget);
    await tester.tap(sortButton);
    await tester.pump();
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
  });
//test to ensure when there are no exercises, if UI shows informational message and displays no exercises
  testWidgets('Empty state appears when no exercises',(WidgetTester tester) async{
    await tester.pumpWidget(
      const MaterialApp(
        home: SelectExerciseScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No exercises found'), findsOneWidget);
  });
}