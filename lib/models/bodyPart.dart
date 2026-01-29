import 'package:firestorm/annotations/firestorm_object.dart';

@FirestormObject()
class BodyPart {

  String id;
  String name;
  String imageUrl;

  BodyPart({
      required this.id,
      required this.name,
      required this.imageUrl
  });

}