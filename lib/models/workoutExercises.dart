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
  int? duration; //minutes
  int? distance; //km

  WorkoutExercises({
    required this.id,
    required this.workoutId,
    required this.exerciseId,
    required this.order,
    this.repetitions,
    this.sets,
    this.restBetweenSets,
    this.duration,
    this.distance
  });

  static List<int> exerciseSets = [3, 4, 5];

  static List<int> reps = [6, 8, 12];

  static List<int> rest = [30, 45, 60, 90, 120, 150];

  static List<int> durations = [2, 5, 15, 30, 45, 60, 90];
  static List<int> distances = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20];

}