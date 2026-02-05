import 'package:firestorm/annotations/firestorm_object.dart';

@FirestormObject()
class User {

  String id;
  String emailAddress;
  String username;
  int age;

  String trainingType;
  bool hasAccessToGym;
  int preferredWorkoutsPerWeek;
  String? aerobicType;
  double? aerobicDistance;



 User({
    required this.id,
    required this.emailAddress,
    required this.username,
    required this.age,
    required this.trainingType,
    required this.hasAccessToGym,
    required this.preferredWorkoutsPerWeek,
    this.aerobicType,
    this.aerobicDistance,
});

}