import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:me_fit/models/workout.dart';
import 'package:me_fit/screens/view_workout_screen.dart';
void main() {
//view workout screen displays title of page and workout name
  testWidgets('ViewWorkoutScreen shows workout title',(tester) async{
    final workout = Workout(
      id: 'w1',name: 'Leg Day',
      createdBy: 'user1',isMyWorkout: true, createdOn: null);
    await tester.pumpWidget(
      MaterialApp(
        home: ViewWorkoutScreen(workout: workout),
      ),
    );
    expect(find.textContaining('Viewing workout'), findsOneWidget);
    expect(find.textContaining('Leg Day'), findsOneWidget);
  });
//test if exercises get corresponding color for exercise type
  test('getTypeColor returns correct color', () {
    final state = ViewWorkoutScreenState();
    expect(state.getTypeColor('STRENGTH'), Colors.blue);
    expect(state.getTypeColor('CARDIO'), Colors.green);
    expect(state.getTypeColor('PLYOMETRICS'), Colors.yellow);
    expect(state.getTypeColor('AEROBIC'), Colors.purple);
    expect(state.getTypeColor('STRETCHING'), Colors.teal);
    expect(state.getTypeColor('UNKNOWN'), Colors.grey);
  });
}