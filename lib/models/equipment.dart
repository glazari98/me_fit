import 'package:firestorm/annotations/firestorm_object.dart';

@FirestormObject()
class Equipment {

  String id;
  String name;
  String imageUrl;

  Equipment({
    required this.id,
    required this.name,
    required this.imageUrl
  });

}