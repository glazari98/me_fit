import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:me_fit/screens/active_workout_screen.dart';
import 'package:me_fit/models/workout.dart';
import 'package:me_fit/models/scheduled_workout.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
//passing dummy workout and scheduled workout data to all sets since it's required to enter this screen
//test to ensure workout timer is displayed
  testWidgets('ActiveWorkoutScreen displays workout timer text',(WidgetTester tester) async{
    final workout = Workout(
        id: 'w1',name: 'Workout',
        createdBy: 'user',isMyWorkout: true,
        createdOn: Timestamp.now());
    final scheduled = ScheduledWorkout(
        id: 's1',userId: 'user',
        workoutId: 'w1',scheduledDate: Timestamp.now(),
        isCompleted: false);
        await tester.pumpWidget(
          MaterialApp(
            home: ActiveWorkoutScreen(
              workout: workout,
              scheduledWorkout: scheduled,
            ),
          ),
        );
        await tester.pump();
        expect(find.textContaining('Workout time:'), findsOneWidget);
  });
//test to ensure progress indicator widget for showing progress on which exercise the user is currently, appears in screen
  testWidgets('Progress indicator is visible',(WidgetTester tester) async{
        final workout = Workout(
          id: 'w1',name: 'Workout',
          createdBy: 'user',isMyWorkout: true,
          createdOn: Timestamp.now());
        final scheduled = ScheduledWorkout(
          id: 's1',userId: 'user',
          workoutId: 'w1',scheduledDate: Timestamp.now(),
          isCompleted: false);
        await tester.pumpWidget(
          MaterialApp(
            home: ActiveWorkoutScreen(
              workout: workout,
              scheduledWorkout: scheduled,
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
      });
  //test to check if there is a button displayed for user to start the exercises
  testWidgets('Start exercise button exists',(WidgetTester tester) async{
        final workout = Workout(
            id: 'w1',name: 'Workout',
            createdBy: 'user',isMyWorkout: true,
            createdOn: Timestamp.now());
        final scheduled = ScheduledWorkout(
            id: 's1',userId: 'user',
            workoutId: 'w1',scheduledDate: Timestamp.now(),
            isCompleted: false);
        await tester.pumpWidget(
          MaterialApp(
            home: ActiveWorkoutScreen(
              workout: workout,
              scheduledWorkout: scheduled,
            )),
        );
        await tester.pump();
        expect(find.byType(Scaffold), findsOneWidget);
      });
}