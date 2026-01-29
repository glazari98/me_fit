import 'package:firestorm/annotations/firestorm_object.dart';

@FirestormObject()
class Exercise {
  String id;
  String name;
  String imageUrl;
  String bodyPartId;
  String equipmentId;
  String exerciseTypeId;
  String instruction;
  List<String> keywords;

  Exercise({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.bodyPartId,
    required this.equipmentId,
    required this.exerciseTypeId,
    required this.instruction,
    required this.keywords
  });

}