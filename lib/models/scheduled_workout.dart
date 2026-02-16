import 'package:firestorm/annotations/firestorm_object.dart';


@FirestormObject()
class ScheduledWorkout {
  String id;
  String userId;
  String workoutId;
  DateTime scheduledDate;
  bool isCompleted;
  DateTime? completedDate;
  int? totalDuration;

  ScheduledWorkout({
    required this.id,
    required this.userId,
    required this.workoutId,
    required this.scheduledDate,
    required this.isCompleted,
    this.completedDate,
    this.totalDuration
});

}