import 'package:firestorm/annotations/firestorm_object.dart';

@FirestormObject()
class Exercise {

  String id;
  String name;
  String bodyPart;
  String category;
  String description;
  int? repetitions;
  int? sets;
  int? restBetweenSets; //seconds
  int? duration; //minutes
  int? distance; //km
  String userId;

  Exercise({
    required this.id,
    required this.name,
    required this.bodyPart,
    required this.category,
    required this.description,
    this.repetitions,
    this.sets,
    this.restBetweenSets,
    this.duration,
    this.distance,
    required this.userId
  });

  static List<String> bodyParts = [
    'Upper Body',
    'Lower Body',
    'Full Body'
  ];
  static List<String> categories = [
    'Strength',
    'Cardio',
    'Core'
  ];

  static List<int> exerciseSets = [3, 4, 5];

  static List<int> reps = [6, 8, 12];

  static List<int> rest = [30, 45, 60, 90, 120, 150];

  static List<int> durations = [2, 5, 15, 30, 45, 60, 90];
  static List<int> distances = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20];
}