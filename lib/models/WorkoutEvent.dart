import 'package:me_fit/models/scheduled_workout.dart';

class WorkoutEvent {
  String title;
  final ScheduledWorkout scheduledWorkout;
  String? workoutName;

  WorkoutEvent(this.title,this.scheduledWorkout, {this.workoutName});

  @override
  String toString() => title;
}