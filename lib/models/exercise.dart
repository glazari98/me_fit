import 'package:firestorm/annotations/firestorm_object.dart';

@FirestormObject()
class Exercise {
  String id;
  String name;
  String bodyPart;
  String category;
  String description;
  String userId;

  Exercise({
    required this.id,
    required this.name,
    required this.bodyPart,
    required this.category,
    required this.description,
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
}