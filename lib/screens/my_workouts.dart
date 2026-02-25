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

  List<Workout> allWorkouts = [];
  bool isLatestFirst = true;
  String searchQuery = '';
  bool isLoading = true;

  @override
  void initState(){
    super.initState();
    fetchWorkouts();
  }
  void sortList() {
    allWorkouts.sort((a,b) {
      final aDate = a.createdOn ?? DateTime(0);
      final bDate = b.createdOn ?? DateTime(0);


      return isLatestFirst ? bDate.compareTo(aDate) : aDate.compareTo(bDate);
    });
  }
  Future<void> fetchWorkouts () async {
    final user = authenticationService.getCurrentUser();

    final result = await FS.list //TODO - This line causes an error: Unhandled Exception: type 'Timestamp' is not a subtype of type 'DateTime?' in type cast
      .filter<Workout>(Workout)
      .whereEqualTo('createdBy', user?.uid)
      .whereEqualTo('isMyWorkout', true)
      .fetch();

    setState(() {
      allWorkouts = result.items;
      isLoading = false;
    });
    sortList();
  }
  List<Workout> get filteredList {
    return allWorkouts.where((workout) {
      return workout.name.toLowerCase()
          .contains(searchQuery.toLowerCase());
    }).toList();
  }
  void deleteWorkout(Workout workout) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.warning_amber_rounded,color: Colors.red),
            SizedBox(width: 8),Text('Delete Workout'),
          ],),
          content: Text('Are you sure you want to remove ${workout.name}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context,false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context,true),
                child: const Text('Delete',style: TextStyle(color: Colors.white))),
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
    await fetchWorkouts();
  }
  String formatDate(DateTime date){
    return "${date.day}/${date.month}/${date.year} "
        "${date.hour.toString().padLeft(2,'0')}:"
        "${date.minute.toString().padLeft(2,'0')}";
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Workouts'),
      actions: [
        IconButton(
          icon: Icon(isLatestFirst ? Icons.arrow_downward : Icons.arrow_upward),
          onPressed: (){
            setState(() {
              isLatestFirst = !isLatestFirst;
              sortList();
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(isLatestFirst ? 'Sorted by latest workouts' : 'Sorted by earliest workouts'),
              duration: const Duration(seconds: 2))
            );
          } )
        ],),
        floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreateWorkoutScreen(),
                ),
              );
              await fetchWorkouts();
            }),
        body: isLoading ? const Center(child: CircularProgressIndicator())
        : Column(children: [
        Padding( padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search workout name',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value){
              setState(() {
                searchQuery = value;
              });
            },
          ),

      ),
        Expanded(child: filteredList.isEmpty ? const Center(child: Text('No workouts found'))
        : ListView.builder(
            itemCount: filteredList.length,
            itemBuilder: (context,index){
              final workout = filteredList[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12,vertical: 6),
                child: ListTile(onTap: () async {
                  Navigator.push(
                    context,MaterialPageRoute(builder: (_) =>ViewWorkoutScreen(workout: workout))
                  );
                },
                title:Text(workout.name,style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: workout.createdOn != null ? Text('Created on: ${formatDate(workout.createdOn!)}')
                  : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit Workout', icon: Icon(Icons.edit,color: Colors.blue),
                        onPressed: (){
                          Navigator.push(context,MaterialPageRoute(builder: (_) => EditWorkoutScreen(workout: workout)));
                        },

                      ),
                      IconButton(
                        tooltip: 'Delete workout',
                        onPressed: () => deleteWorkout(workout),
                        icon:const Icon(Icons.delete, color: Colors.red)
                      )
                    ],
                  ),
                ),
              );
            }))
      ],)
    );
  }
}