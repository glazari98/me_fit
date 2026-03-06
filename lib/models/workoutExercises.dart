import 'package:firestorm/annotations/firestorm_object.dart';

@FirestormObject()
class WorkoutExercises {

  String id;
  String workoutId;
  String exerciseId;
  int order;
  int? repetitions;
  int? sets;
  int? restBetweenSets; //seconds
  List<double>? targetSetWeights; //weights the user sets before starting the exercise
  List<double>? actualSetWeights; //weights after the exercise finishes
  int? durationOfTimedSet; //seconds
  double? distance; //km
  int? setsCompleted;
  int? repsCompleted;
  int? durationLasted;
  double? distanceCovered;
  List<String>? routePoints;
  int? timeForDistanceCovered;
  bool? stretchingCompleted;

  WorkoutExercises({
    required this.id,
    required this.workoutId,
    required this.exerciseId,
    required this.order,
    this.repetitions,
    this.sets,
    this.targetSetWeights,
    this.actualSetWeights,
    this.restBetweenSets,
    this.durationOfTimedSet,
    this.distance,
    this.setsCompleted,
    this.repsCompleted,
    this.durationLasted,
    this.distanceCovered,
    this.timeForDistanceCovered,
    this.stretchingCompleted
  });

}