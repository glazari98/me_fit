import 'package:firestorm/annotations/firestorm_object.dart';
import 'package:flutter/cupertino.dart';

@FirestormObject()
class ScheduledWorkout {
  String id;
  String userId;
  String workoutId;
  DateTime scheduledDate;

  ScheduledWorkout({
    required this.id,
    required this.userId,
    required this.workoutId,
    required this.scheduledDate,
});

}