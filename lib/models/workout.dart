import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firestorm/annotations/firestorm_object.dart';

@FirestormObject()
class Workout {
  String id;
  String name;
  String createdBy;
  Timestamp? createdOn;
  bool isMyWorkout;

  Workout({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.isMyWorkout,
    required this.createdOn,
  });

}