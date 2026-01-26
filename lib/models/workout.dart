import 'package:firestorm/annotations/firestorm_object.dart';

@FirestormObject()
class Workout {
  String id;
  String name;
  String createdBy;

  Workout({
    required this.id,
    required this.name,
    required this.createdBy
  });

}