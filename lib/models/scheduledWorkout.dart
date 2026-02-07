import 'package:firestorm/annotations/firestorm_object.dart';
import 'package:flutter/cupertino.dart';

@FirestormObject()
class ScheduledWorkout {
  String id;
  String userId;
  String workoutId;
  DateTime scheduledDate;
  bool isCompleted;
  int? totalDuration;

  ScheduledWorkout({
    required this.id,
    required this.userId,
    required this.workoutId,
    required this.scheduledDate,
    required this.isCompleted,
});

}