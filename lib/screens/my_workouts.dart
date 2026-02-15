import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/screens/edit_workout_screen.dart';
import 'package:me_fit/screens/login_screen.dart';
import 'package:me_fit/screens/view_workout_screen.dart';
import 'package:me_fit/services/authentication_service.dart';

import '../models/workout.dart';
import '../models/workoutExercises.dart';
import 'create_workout_screen.dart';

class MyWorkoutsScreen extends StatefulWidget {
  const MyWorkoutsScreen({super.key});

  @override
  State<MyWorkoutsScreen> createState() => MyWorkoutsScreenState();
}
class MyWorkoutsScreenState extends State<MyWorkoutsScreen> {
  final AuthenticationService authenticationService = AuthenticationService();
  late Future<List<Workout>> workoutsUpdated;

  @override
  void initState(){
    super.initState();
    refreshWorkouts();
  }
  void refreshWorkouts(){
    workoutsUpdated = fetchWorkouts();
  }
  Future<List<Workout>> fetchWorkouts () async {
    final user = authenticationService.getCurrentUser();

    final result = await FS.list
      .filter<Workout>(Workout)
      .whereEqualTo('createdBy', user?.uid)
      .whereEqualTo('isMyWorkout', true)
      .fetch();

    return result.items;
  }
  void deleteWorkout(Workout workout) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Delete workout'),
          content: Text('Are you sure you want to delete ${workout.name}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context,false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(onPressed: () => Navigator.pop(context,true),
                child: const Text('Delete')),
          ],
        ));
    if(confirm != true) return;

    final exercises = await FS.list.filter<WorkoutExercises>(WorkoutExercises)
                      .whereEqualTo('workoutId', workout.id)
                        .fetch();

    for (final we in exercises.items){
      await FS.delete.one(we);
    }
    await FS.delete.one(workout);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Workout deleted')));

    setState(() {
      refreshWorkouts();
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Workouts')),
        floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreateWorkoutScreen(),
                ),
              );
              setState(() {
                refreshWorkouts();
              });
            }),
        body:FutureBuilder<List<Workout>>(
        future: workoutsUpdated,
        builder: (context, snapshot){
          if(snapshot.connectionState == ConnectionState.waiting){
            return const Center(child: CircularProgressIndicator());
          }
          if(!snapshot.hasData || snapshot.data!.isEmpty){
            return const Center(child: Text('No workouts yet'));
          }

          final workouts = snapshot.data!;
          return ListView.builder(
              itemCount: workouts.length,
              itemBuilder: (context, index){
                final workout = workouts[index];
                return Card (
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(
                      workout.name, style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: SizedBox(
                      child:Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'View Workout',
                              onPressed: (){
                            Navigator.push(
                              context,MaterialPageRoute(builder: (_) => ViewWorkoutScreen(workout: workout))
                            );
                            },
                          icon: const Icon (Icons.visibility, color: Colors.green)
                          ),
                          IconButton(
                            tooltip: 'Edit Workout',
                            icon: const Icon (Icons.edit, color: Colors.blue),
                            onPressed: (){
                              Navigator.push(
                                  context,MaterialPageRoute(builder: (_) => EditWorkoutScreen(workout: workout))
                              );
                            },

                          ),
                          IconButton(
                            tooltip: 'Delete Workout',
                              onPressed: () => deleteWorkout(workout),
                              icon: const Icon (Icons.delete, color: Colors.red)
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
          );
        },
        ),
    );
  }
}