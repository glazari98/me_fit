import 'package:firestorm/annotations/firestorm_object.dart';

@FirestormObject()
class WorkoutExerciseFeedback {

  String id;
  String workoutExerciseId;
  int? setsCompleted;
  int? repsCompleted;
  int? durationLasted;
  double? distanceCovered;
  int? timeForDistanceCovered;
  double? pace;
  bool? stretchingCompleted;

  WorkoutExerciseFeedback({
    required this.id,
    required this.workoutExerciseId,
    this.setsCompleted,
    this.repsCompleted,
    this.durationLasted,
    this.distanceCovered,
    this.timeForDistanceCovered,
    this.pace,
    this.stretchingCompleted
  });

}