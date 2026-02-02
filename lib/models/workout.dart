import 'package:firestorm/annotations/firestorm_object.dart';

@FirestormObject()
class Workout {
  String id;
  String name;
  String createdBy;
  bool isMyWorkout;

  Workout({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.isMyWorkout,
  });

}