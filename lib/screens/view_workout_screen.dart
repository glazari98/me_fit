import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/models/exercise.dart';
import 'package:me_fit/models/workoutExercises.dart';
import 'package:me_fit/screens/exercise_details_screen.dart';
import 'package:me_fit/screens/select_exercise_screen.dart';

import '../models/bodyPart.dart';
import '../models/exerciseType.dart';
import '../models/workout.dart';

class ViewWorkoutScreen extends StatefulWidget {
  final Workout workout;

  const ViewWorkoutScreen(
      {super.key, required this.workout});

  @override
  State<ViewWorkoutScreen> createState() => ViewWorkoutScreenState();
}
class ViewWorkoutScreenState extends State<ViewWorkoutScreen>{
  late Future<List<WorkoutExercises>> workoutExercisesFuture;

  @override
  void initState(){
    super.initState();
    workoutExercisesFuture = fetchWorkoutExercises();
  }

  Future<List<WorkoutExercises>> fetchWorkoutExercises() async {
    final result = await FS.list.filter<WorkoutExercises>(WorkoutExercises)
                                .whereEqualTo('workoutId', widget.workout.id)
                                .fetch();
    final items= result.items;
    items.sort((a,b) => a.order.compareTo(b.order));
    return items;
  }
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

  Future<void> replaceExercise(WorkoutExercises we, Exercise newExercise) async{
    we.exerciseId = newExercise.id;
    await FS.update.one(we);
    setState(() {
      workoutExercisesFuture = fetchWorkoutExercises();
    });
  }
    @override
    Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: Text(widget.workout.name)),
      body: FutureBuilder<List<WorkoutExercises>>(
          future: fetchWorkoutExercises(),
          builder: (context,weSnapshot){
            if(weSnapshot.connectionState == ConnectionState.waiting){
              return const Center(child: CircularProgressIndicator());
            }
            if(!weSnapshot.hasData  || weSnapshot.data!.isEmpty){
              return const Center (child: Text('No exercises in this workout'));
            }
            final workoutExercises = weSnapshot.data!;

            return FutureBuilder<Map<String,Exercise>>(
                future: fetchExercisesMap(workoutExercises),
                builder: (context,exSnapshot){
                  if(!exSnapshot.hasData){
                    return Center(child: CircularProgressIndicator());
                  }
                  final exerciseMap = exSnapshot.data!;

                  return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: workoutExercises.length,
                      itemBuilder: (context,index){
                        final we = workoutExercises[index];
                        final exercise = exerciseMap[we.exerciseId];

                        return Card (
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            onTap: () async {
                              final bodyPartsResult = await FS.list.allOfClass<BodyPart>(BodyPart);
                              final exerciseTypesResult = await FS.list.allOfClass<ExerciseType>(
                                  ExerciseType);
                              if(!mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => ExerciseDetailsScreen(exercise: exercise,
                                    bodyParts: bodyPartsResult, exerciseTypes: exerciseTypesResult
                                ),
                                ),
                              );
                            },
                            title: Text(exercise!.name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if(we.sets != null)
                                  Text('Sets: ${we.sets}'),
                                if(we.repetitions != null)
                                  Text('Reps: ${we.repetitions ?? '-'}'),
                                if(we.duration != null)
                                    Text('Duration: ${showDuration(we.duration!)}'),
                                if(we.restBetweenSets != null)
                                  Text('Rest between sets: ${showDuration(we.restBetweenSets!)}'),
                                if(we.distance != null)
                                  Text('Distance: ${we.distance} km'),
                              ],
                            ),
                          ),
                        );
                      },
                  );
                },
            );
          },
      ),
    );
    }
}