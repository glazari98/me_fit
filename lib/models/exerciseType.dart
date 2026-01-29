import 'package:firestorm/annotations/firestorm_object.dart';

@FirestormObject()
class ExerciseType {

  String id;
  String name;
  String imageUrl;

  ExerciseType({
    required this.id,
    required this.name,
    required this.imageUrl
  });

}