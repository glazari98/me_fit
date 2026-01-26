import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/screens/workout_details_screen.dart';
import 'package:me_fit/services/authentication_service.dart';

import '../models/workout.dart';

class MyWorkoutsScreen extends StatelessWidget{
  MyWorkoutsScreen ({super.key});

  final AuthenticationService authenticationService = AuthenticationService();

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
    return FutureBuilder<List<Workout>>(
        future: fetchWorkouts(),
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
    );
  }
}