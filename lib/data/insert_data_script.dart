import 'dart:convert';
import 'package:firestorm/firestorm.dart';
import 'package:firestorm/fs/fs.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:me_fit/models/bodyPart.dart';
import 'package:me_fit/models/exercise.dart';
import 'package:me_fit/models/exerciseType.dart';
import '../models/equipment.dart';
/*The purpose of this script is to insert data from the api into our database. It was run once by me so the tables get the data
* and it should nto executed again so we don't enter duplicate data into our tables.
* only if a collection is deleted or we change a model we can execute again something
* from this script.*/

  //<<<<<<<<<<<INSERT BODY PARTS SECTIONS>>>>>>>>>>>
  Future<List<Map<String, dynamic>>> fetchBodyPartsFromAPI() async {
    final response = await http.get(
        Uri.parse('https://edb-with-videos-and-images-by-ascendapi.p.rapidapi.com/api/v1/bodyparts',
    ),
    headers: {
        'X-RapidAPI-Key': '4ca14a21ecmshcffd671630b0ae1p18cba4jsn04e589b731c1',
        'X-RapidAPI-Host': 'edb-with-videos-and-images-by-ascendapi.p.rapidapi.com'
    },
    );

    if(response.statusCode != 200){
      throw Exception('Failed to load body parts');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final List bodyParts = decoded['data'];

    return bodyParts.cast<Map<String,dynamic>>();
  }

  BodyPart mapToBodyParts(Map<String,dynamic> json){
    return BodyPart(
        id: Firestorm.randomID(),
        name: json['name'],
        imageUrl: json['imageUrl']);
  }

  Future<void> seedBodyParts() async {
    final apiBodyParts = await fetchBodyPartsFromAPI();

    for (final b in apiBodyParts){
      final bodyPart = mapToBodyParts(b);
      await FS.create.one(bodyPart);


    }
    debugPrint('Success');
  }


//<<<<<<<<<<INSERT EXERCISE TYPES SECTION>>>>>>>>>>
Future<List<Map<String, dynamic>>> fetchExerciseTypesFromAPI() async {
  final response = await http.get(
    Uri.parse('https://edb-with-videos-and-images-by-ascendapi.p.rapidapi.com/api/v1/exercisetypes',
    ),
    headers: {
      'X-RapidAPI-Key': '4ca14a21ecmshcffd671630b0ae1p18cba4jsn04e589b731c1',
      'X-RapidAPI-Host': 'edb-with-videos-and-images-by-ascendapi.p.rapidapi.com'
    },
  );

  if(response.statusCode != 200){
    throw Exception('Failed to load exercise Types');
  }

  final decoded = jsonDecode(response.body) as Map<String, dynamic>;
  final List exerciseTypes = decoded['data'];

  return exerciseTypes.cast<Map<String,dynamic>>();
}

ExerciseType mapToExerciseTypes(Map<String,dynamic> json){
  return ExerciseType(
      id: Firestorm.randomID(),
      name: json['name'],
      imageUrl: json['imageUrl']);
}

Future<void> seedExerciseTypes() async {
  final apiExerciseTypes = await fetchExerciseTypesFromAPI();

  for (final b in apiExerciseTypes){
    final exerciseType = mapToExerciseTypes(b);
    await FS.create.one(exerciseType);

  }

}


//<<<<<<<<<<<INSERT EQUIPMENT SECTION>>>>>>>>>>>
Future<List<Map<String, dynamic>>> fetchEquipmentFromAPI() async {
  final response = await http.get(
    Uri.parse('https://edb-with-videos-and-images-by-ascendapi.p.rapidapi.com/api/v1/equipments',
    ),
    headers: {
      'X-RapidAPI-Key': '4ca14a21ecmshcffd671630b0ae1p18cba4jsn04e589b731c1',
      'X-RapidAPI-Host': 'edb-with-videos-and-images-by-ascendapi.p.rapidapi.com'
    },
  );

  if(response.statusCode != 200){
    throw Exception('Failed to load equipments');
  }

  final decoded = jsonDecode(response.body) as Map<String, dynamic>;
  final List equipments = decoded['data'];

  return equipments.cast<Map<String,dynamic>>();
}

Equipment mapToEquipments(Map<String,dynamic> json){
  return Equipment(
      id: Firestorm.randomID(),
      name: json['name'],
      imageUrl: json['imageUrl']);
}

Future<void> seedEquipments() async {
  final apiEquipments = await fetchEquipmentFromAPI();

  for (final b in apiEquipments){
    final equipment = mapToEquipments(b);
    await FS.create.one(equipment);


  }
  debugPrint('Success');
}

//<<<<<<<INSERT EXERCISES SECTION>>>>>>>
Future<List<Map<String, dynamic>>> fetchExercisesFromAPI() async {
    List<Map<String,dynamic>> allExercises = [];
    String? after;
    bool hasNextPage = true;
    while (hasNextPage) {
      final uri = Uri.https(
        'edb-with-videos-and-images-by-ascendapi.p.rapidapi.com',
        '/api/v1/exercises',
        {
          'limit': '25',
          if(after != null) 'after': after,
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'X-RapidAPI-Key': '4ca14a21ecmshcffd671630b0ae1p18cba4jsn04e589b731c1',
          'X-RapidAPI-Host': 'edb-with-videos-and-images-by-ascendapi.p.rapidapi.com'
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load exercises');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final  meta = decoded['meta'] as Map<String, dynamic>;
      final List data = decoded['data'];
      final batch = data.map((e) => Map<String, dynamic>.from(e)).toList();
      allExercises.addAll(batch);
      hasNextPage = meta['hasNextPage'] as bool;
      after = meta['nextCursor'] as String?;

      await Future.delayed(const Duration(milliseconds: 200));
    }
  return allExercises;
}

Future<Exercise> mapToExercises(Map<String,dynamic> json) async{
  final response = await http.get(
    Uri.parse('https://edb-with-videos-and-images-by-ascendapi.p.rapidapi.com/api/v1/exercises/${json['exerciseId']}',
    ),
    headers: {
      'X-RapidAPI-Key': '4ca14a21ecmshcffd671630b0ae1p18cba4jsn04e589b731c1',
      'X-RapidAPI-Host': 'edb-with-videos-and-images-by-ascendapi.p.rapidapi.com'
    },
  );

  final decoded = jsonDecode(response.body) as Map<String, dynamic>;
  final exerciseData = decoded['data'] as Map<String,dynamic>;

  return Exercise(
      id: Firestorm.randomID(),
      name: exerciseData['name'],
      imageUrl: exerciseData['imageUrl'],
      bodyPartId: safeFirst(exerciseData['bodyParts']),
      equipmentId: safeFirst(exerciseData['equipments']),
      exerciseTypeId: exerciseData['exerciseType'],
      instruction:  safeFirst(exerciseData['equipments']),
      keywords: safeStringList(exerciseData['keywords']));
}
String safeFirst(dynamic value){
    if(value is List && value.isNotEmpty){
      return value.first.toString();
    }
    return '';
}

List<String> safeStringList (dynamic value){
    if(value is List){
      return value.map((e)=> e.toString()).toList();
    }
    
    return [];
}
Future<void> seedExercises() async {
  final apiExercises = await fetchExercisesFromAPI();

  for (final b in apiExercises){
    final exercise = await mapToExercises(b);
    await FS.create.one(exercise);

  }

}

