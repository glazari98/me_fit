import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:me_fit/screens/home_screen.dart';
import 'package:table_calendar/table_calendar.dart';

void main() {
//test to see if home screen renders correctly
  testWidgets('Home screen displays title and calendar',(tester) async{
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Workout Calendar'), findsOneWidget);
  });
//test to ai coach suggestion section shows correctly
  testWidgets('AI suggestion section is visible',(tester) async{
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('AI COACH SUGGESTION'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome), findsWidgets);
  });

//check to see if calendar widget exists in home to show scheduled workouts
  testWidgets('Calendar widget is displayed',(tester) async{
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TableCalendar),findsOneWidget);

  });
}


