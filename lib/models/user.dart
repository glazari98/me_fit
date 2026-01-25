import 'package:firestorm/annotations/firestorm_object.dart';

@FirestormObject()
class User {

  String id;
  String emailAddress;
  String username;
  int age;
  String fitnessLevel;

  User(this.id, this.emailAddress, this.username, this.age, this.fitnessLevel);

}