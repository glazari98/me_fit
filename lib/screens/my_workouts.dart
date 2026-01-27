import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/screens/workout_details_screen.dart';
import 'package:me_fit/services/authentication_service.dart';

import '../models/workout.dart';
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
      .fetch();

    return result.items;
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
                return ListTile(
                  title: Text(
                    workout.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: (){
                    Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => WorkoutDetailsScreen(workout: workout),
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