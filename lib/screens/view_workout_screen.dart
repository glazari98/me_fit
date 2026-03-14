import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/models/exercise.dart';
import 'package:me_fit/models/workoutExercises.dart';
import 'package:me_fit/screens/exercise_details_screen.dart';
import 'package:me_fit/screens/select_exercise_screen.dart';

import '../models/bodyPart.dart';
import '../models/exerciseType.dart';
import '../models/workout.dart';
import '../utilityFunctions/utility_functions.dart';
//widget to view workout exercises
class ViewWorkoutScreen extends StatefulWidget {
  final Workout workout;

  const ViewWorkoutScreen(
      {super.key, required this.workout});

  @override
  State<ViewWorkoutScreen> createState() => ViewWorkoutScreenState();
}
class ViewWorkoutScreenState extends State<ViewWorkoutScreen>{
  late Future<List<WorkoutExercises>> workoutExercisesFuture;
  late Future<Map<String,String>> exerciseTypeMap;

  @override
  void initState(){
    super.initState();
    workoutExercisesFuture = fetchWorkoutExercises();
    exerciseTypeMap = fetchExerciseTypeMap();
  }
//retrieve exercises the workout has
  Future<List<WorkoutExercises>> fetchWorkoutExercises() async {
    final result = await FS.list.filter<WorkoutExercises>(WorkoutExercises)
                                .whereEqualTo('workoutId', widget.workout.id)
                                .fetch();
    final items= result.items;
    items.sort((a,b) => a.order.compareTo(b.order));
    return items;
  }
  //function to retrieve exercise type name from foreign key id
  Future<Map<String, String>> fetchExerciseTypeMap()async{
    final typeResult = await FS.list.allOfClass<ExerciseType>(ExerciseType);
    return {for (var type in typeResult) type.id: type.name};
  }
  //function to retrieve exercise name from foreign key id
  Future<Map<String,Exercise>> fetchExercisesMap(
      List<WorkoutExercises> workoutExercises) async {
    final exerciseIds = workoutExercises.map((e) => e.exerciseId).toList();

    final result = await FS.list.filter<Exercise>(Exercise)
        .whereIn('id', exerciseIds)
        .fetch();

    return {for (var e in result.items) e.id: e};
  }
  String showDuration(int totalSeconds){
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;

    if(minutes == 0){
      return '$seconds s';
    }
    if(seconds == 0){
      return '$minutes min';
    }

    return '$minutes min $seconds s';
  }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(title: Text('Viewing workout: ${widget.workout.name}')),
        body: FutureBuilder<List<WorkoutExercises>>(
          future: fetchWorkoutExercises(),
          builder: (context, weSnapshot) {
            if (weSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }
            if (!weSnapshot.hasData || weSnapshot.data!.isEmpty) {
              return buildEmptyState();
            }
            final workoutExercises = weSnapshot.data!;

            return FutureBuilder<Map<String, Exercise>>(
              future: fetchExercisesMap(workoutExercises),
              builder: (context, exSnapshot) {
                if (!exSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final exerciseMap = exSnapshot.data!;

                return FutureBuilder<Map<String, String>>(
                  future: exerciseTypeMap,
                  builder: (context, typeSnapshot) {
                    if (!typeSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final typeMap = typeSnapshot.data!;
                    return Column(
                      children: [
                        Padding(padding: const EdgeInsets.fromLTRB(
                            16, 16, 16, 8),
                          child: Row(children: [
                            Text('EXERCISES',
                                style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2, color: Colors.grey[700],
                                )),
                            const SizedBox(width: 8),
                            Container(width: 4,
                                height: 4, decoration: BoxDecoration(
                                  color: Colors.grey[400],
                                  shape: BoxShape.circle,
                                )),
                            const SizedBox(width: 8),
                            Text('${workoutExercises.length} total',
                                style: TextStyle(
                                  fontSize: 14, color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                )),
                          ]),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: workoutExercises.length,
                            itemBuilder: (context, index) {
                              final we = workoutExercises[index];
                              final exercise = exerciseMap[we.exerciseId]!;
                              final exerciseTypeName =
                                  typeMap[exercise.exerciseTypeId] ?? 'UNKNOWN';
                              return buildExerciseCard(
                                we,
                                exercise,
                                exerciseTypeName,
                                index,
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      );
    }
//show no exercise message with icon if no exercises exist in workout
    Widget buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: Colors.grey[200],
              shape: BoxShape.circle),
            child: Icon(Icons.fitness_center_outlined,
              size: 64,color: Colors.grey[600])),
          const SizedBox(height: 24),
          Text('No exercises yet',
            style: TextStyle(
              fontSize: 20,fontWeight: FontWeight.bold,
              color: Colors.grey[800])),
          const SizedBox(height: 8),
          Text('This workout doesn\'t have any exercises',
            style: TextStyle(fontSize: 14,
              color: Colors.grey[600]),
          )])
    );
  }

//widget display workout exercise name, order number, if user taps it leads to exercise details screen where user views details about individual exercise
  Widget buildExerciseCard(
      WorkoutExercises we,
      Exercise exercise,
      String exerciseTypeName,
      int index,
      ) {
    return Container(
      key: ValueKey(we.id),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final bodyPartsResult = await FS.list.allOfClass<BodyPart>(BodyPart);
            final exerciseTypesResult =
            await FS.list.allOfClass<ExerciseType>(ExerciseType);
            if (!context.mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ExerciseDetailsScreen(
                  exercise: exercise,
                  bodyParts: bodyPartsResult,
                  exerciseTypes: exerciseTypesResult,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,fontSize: 14),
                    )),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        style: TextStyle( fontWeight: FontWeight.bold,
                          fontSize: 16),
                      ),
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: getTypeColor(exerciseTypeName).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          exerciseTypeName,
                          style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w600,
                            color: getTypeColor(exerciseTypeName),
                          )),
                      ),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,runSpacing: 4,
                        children: buildExerciseTags(we),
                      )],
                  )),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.chevron_right,
                    color: Colors.grey[600], size: 20,
                  ))
              ]),
          )),
      ),
    );
  }
  //display sets,reps,rest,distance for an exercise
  List<Widget> buildExerciseTags(WorkoutExercises we) {
    List<Widget> tags = [];
    if (we.sets != null) {
      tags.add(buildTag(
        icon: Icons.repeat,
        text: '${we.sets} sets',
      ));
    }
    if (we.repetitions != null) {
      tags.add(buildTag(
        icon: Icons.fitness_center,
        text: '${we.repetitions} reps',
      ));
    }
    if (we.durationOfTimedSet != null) {
      tags.add(buildTag(
        icon: Icons.timer,
        text: formatDuration(we.durationOfTimedSet!),
      ));
    }
    if (we.restBetweenSets != null) {
      tags.add(buildTag(
        icon: Icons.hourglass_empty,
        text: 'rest ${formatDuration(we.restBetweenSets!)}',
      ));
    }
    if (we.distance != null) {
      tags.add(buildTag(
        icon: Icons.map,
        text: '${we.distance} km',
      ));
    }
    return tags;
  }
//widget to display icon and sets for sets,reps,rest etc.
  Widget buildTag({required IconData icon,required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children:[ Icon(icon,size: 12,
            color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(text,style: TextStyle(
              fontSize: 11,color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ))],),
    );
  }
  //retrieve color according to exercise type name
  Color getTypeColor (String type) {
    switch (type) {
      case 'STRENGTH':
        return Colors.blue;
      case 'CARDIO':
        return Colors.green;
      case 'PLYOMETRICS':
        return Colors.orange;
      case 'AEROBIC':
        return Colors.purple;
      case 'STRETCHING':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

}