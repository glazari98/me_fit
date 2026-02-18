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
  int? duration; //seconds
  double? distance; //km
  int? setsCompleted;
  int? repsCompleted;
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
    this.restBetweenSets,
    this.duration,
    this.distance,
    this.setsCompleted,
    this.repsCompleted,
    this.distanceCovered,
    this.timeForDistanceCovered,
    this.stretchingCompleted
  });

}