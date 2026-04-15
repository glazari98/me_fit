import 'package:flutter_test/flutter_test.dart';
import 'package:me_fit/models/scheduled_workout.dart';
import 'package:me_fit/models/user.dart';
import 'package:me_fit/services/achievement_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  //tests calculation of completed workouts
  group('Calculate Total Workouts Completed Test', () {
    test('Returns 0 when workout list is empty', () {
      final workouts = <ScheduledWorkout>[];
      final result = AchievementService.calculateTotalWorkoutsCompleted(
          workouts);
      expect(result, 0);
    });
    test('Returns 3 since all three workouts are completed', () {
      final workouts = [
        ScheduledWorkout(id: '1',
            userId: 'u1',
            workoutId: 'w1',
            scheduledDate: Timestamp.now(),
            isCompleted: true),
        ScheduledWorkout(id: '2',
            userId: 'u1',
            workoutId: 'w2',
            scheduledDate: Timestamp.now(),
            isCompleted: true),
        ScheduledWorkout(id: '3',
            userId: 'u1',
            workoutId: 'w3',
            scheduledDate: Timestamp.now(),
            isCompleted: true),
      ];
      final result = AchievementService.calculateTotalWorkoutsCompleted(
          workouts);
      expect(result, 3);
    });
  });
    //
    group('Calculate Unlocked Badges Tests', () {
      test('Returns empty list when total completed is 0', () {
        final result = AchievementService.calculateUnlockedBadges(0);
        expect(result, []);
      });
      test('List contains badge at milestone 1,5 and 10', () {
        final result = AchievementService.calculateUnlockedBadges(11);
        expect(result, [1, 5, 10]);
      });
    });

}