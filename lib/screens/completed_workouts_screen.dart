import 'package:firebase_auth/firebase_auth.dart';
import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/models/scheduled_workout.dart';
import 'package:me_fit/models/workoutExercises.dart';
import 'package:me_fit/screens/workout_feedback_screen.dart';
import 'package:me_fit/services/authentication_service.dart';

import '../models/workout.dart';

class CompletedWorkoutsScreen extends StatefulWidget {
  const CompletedWorkoutsScreen({super.key});

  @override
  State<CompletedWorkoutsScreen> createState() => CompleteWorkoutsScreenState();
}
class CompleteWorkoutsScreenState extends State<CompletedWorkoutsScreen>{
   List<ScheduledWorkout> allCompleted = [];
   Map<String, Workout> workoutMap = {};
    AuthenticationService authenticationService = AuthenticationService();
   bool isLatestFirst = true;
   bool isLoading = true;
   int visibleCount = 10;
   String searchQuery = '';

   @override
   void initState(){
     super.initState();
     loadData();
   }

   Future<void> loadData() async {
     final scheduledResult = await FS.list.filter<ScheduledWorkout>(ScheduledWorkout)
                                          .whereEqualTo('isCompleted', true)
                                          .whereEqualTo('userId', authenticationService.getCurrentUser()?.uid)
                                          .fetch();
     final workoutResult = await FS.list.allOfClass<Workout>(Workout);

     final map = { for (var workout in workoutResult) workout.id : workout};

     setState(() {
       allCompleted = scheduledResult.items;
       workoutMap = map;
       isLoading = false;
     });
     sortList();
   }

   void sortList() {
     allCompleted.sort((a,b){
       final aDate = a.completedDate?.toDate() ?? DateTime(0);
       final bDate = b.completedDate?.toDate() ?? DateTime(0);
       return isLatestFirst ? bDate.compareTo(aDate) : aDate.compareTo(bDate);
     });
   }
   List<ScheduledWorkout> get filteredList {
     final filtered = allCompleted.where((sw) {
       final workout = workoutMap[sw.workoutId];
       if(workout == null) return false;

       return workout.name.toLowerCase().contains(searchQuery.toLowerCase());
     }).toList();

     return filtered.take(visibleCount).toList();
   }

   String formatDate(DateTime date){
     return "${date.day}/${date.month}/${date.year} "
         "${date.hour.toString().padLeft(2,'0')}:"
         "${date.minute.toString().padLeft(2,'0')}";
   }

   Future<void> navigateToFeedbackScreen(ScheduledWorkout sw) async{
     final workout = workoutMap[sw.workoutId];
      if(workout == null) return;
     final workoutExercisesResult = await FS.list.filter<WorkoutExercises>(WorkoutExercises)
                                            .whereEqualTo('workoutId', workout.id)
                                            .fetch();
     
     final exercises = workoutExercisesResult.items;
     
     if(!mounted) return;
     
     Navigator.push(context,MaterialPageRoute(builder: (_) => WorkoutFeedbackScreen(workout: workout, exercises: exercises)));
                                            
   }
   @override
  Widget build(BuildContext context){
     if(isLoading){
       return const Scaffold(
         body: Center(child: CircularProgressIndicator())
       );
     }
    final hasMore = filteredList.length < allCompleted.where((sw) {
      final workout = workoutMap[sw.workoutId];
      if (workout == null) return false;
      return workout.name
          .toLowerCase()
          .contains(searchQuery.toLowerCase());
    }).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Completed Workout'),
        actions: [
          IconButton(icon: Icon(isLatestFirst ? Icons.arrow_downward : Icons.arrow_upward),
          onPressed: (){
            setState(() {
              isLatestFirst = !isLatestFirst;
              sortList();
            });
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
              isLatestFirst ? 'Sorted by latest completed workouts' : 'Sorted by earliest completed workouts'
            ),duration: const Duration(seconds: 2)));
          })
        ],
      ),
      body: Column(
        children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search workout name',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value){
              setState(() {
                searchQuery = value;
                visibleCount = 10;
              });
            },
          ),
        ),
        Expanded(child: ListView.builder(
          itemCount: filteredList.length + (hasMore ? 1 : 0),
            itemBuilder: (context, index){
            if(index >= filteredList.length){
              return Padding(
              padding: const EdgeInsets.all(12),
                  child: ElevatedButton(
                    onPressed: (){
                      setState(() {
                        visibleCount += 10;
                      });
                  },
                  child: const Text('Load More')));
                }
            final sw = filteredList[index];
            final workout = workoutMap[sw.workoutId];

            return ListTile(
            title: Text(workout?.name ?? 'Unknown Workout'),
            subtitle: Text(sw.completedDate != null ? 'Completed on: ${formatDate(sw.completedDate!.toDate())}' : '',
            ),
            leading: const Icon(Icons.check_circle,color: Colors.green),
            onTap: () => navigateToFeedbackScreen(sw),
            );
           })
        ),
        ],
      ),
    );
  }

}