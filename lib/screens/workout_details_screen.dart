import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/models/exercise.dart';
import 'package:me_fit/models/workoutExercises.dart';

import '../models/workout.dart';

class WorkoutDetailsScreen extends StatelessWidget{
  final Workout workout;

  const WorkoutDetailsScreen({super.key, required this.workout});

  Future<List<WorkoutExercises>> fetchWorkoutExercises() async {
    final result = await FS.list.filter<WorkoutExercises>(WorkoutExercises)
                                .whereEqualTo('workoutId', workout.id)
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
    @override
    Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: Text(workout.name)),
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
                            title: Text(exercise!.name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Sets: ${we.sets ?? '-'}'),
                                Text('Reps: ${we.repetitions ?? '-'}'),
                                if(we.restBetweenSets != null)
                                  Text('Rest: ${we.restBetweenSets} s'),
                                if(we.duration != null)
                                  Text('Duration: ${we.duration} min'),
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
