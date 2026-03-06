import 'package:firestorm/annotations/firestorm_object.dart';

@FirestormObject()
class WorkoutExerciseFeedback {

  String id;
  String workoutExerciseId;
  int? setsCompleted;
  int? repsCompleted;
  List<double>? setWeights;
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
    this.setWeights,
    this.distanceCovered,
    this.timeForDistanceCovered,
    this.pace,
    this.stretchingCompleted
  });

}