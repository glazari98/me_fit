import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/services/authentication_service.dart';
import '../models/workout.dart';
import 'active_workout_screen.dart';

class StartWorkoutScreen extends StatelessWidget{
  StartWorkoutScreen({super.key});

  final AuthenticationService authenticationService = AuthenticationService();

  Future<List<Workout>> fetchWorkouts() async {
    final user = authenticationService.getCurrentUser();
    final result = await FS.list.filter<Workout>(Workout)
        .whereEqualTo('createdBy', user?.uid)
        .fetch();
    return result.items;
  }
    @override
    Widget build(BuildContext context) {
      return Scaffold( appBar: AppBar(title: const Text('Start Workout')),
      body:  FutureBuilder<List<Workout>>(
            future: fetchWorkouts(),
            builder: (context, snapshot){
              if(!snapshot.hasData){
                return const Center(child: CircularProgressIndicator());
              }
              final workouts = snapshot.data!;
              if(workouts.isEmpty){
                return const Center(child: Text('No workouts available'));
              }
              return ListView.builder(
                itemCount: workouts.length,
                itemBuilder: (context, index){
                  final workout = workouts[index];
                  return Card(
                    child: ListTile(
                      title: Text(workout.name),
                      trailing: ElevatedButton(
                          onPressed: (){
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => ActiveWorkoutScreen(workout: workout)),
                            );
                          },
                          child: const Text('Start')),
                    ),
                  );
                },
              );
            },
          ),
          );

    }

  }
