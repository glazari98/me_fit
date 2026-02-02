import 'package:me_fit/models/scheduledWorkout.dart';

class WorkoutEvent {
  final String title;
  final ScheduledWorkout scheduledWorkout;

  const WorkoutEvent(this.title,this.scheduledWorkout);

  @override
  String toString() => title;
}