import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/models/scheduledWorkout.dart';
import 'package:me_fit/models/workout.dart';
import 'package:me_fit/screens/edit_workout_screen.dart';
import 'package:me_fit/screens/home_screen.dart';
import 'package:me_fit/screens/workout_details_screen.dart';
import 'package:me_fit/services/authentication_service.dart';

Color workoutCardColor(ScheduledWorkout sw){
  if(sw.isCompleted) return Colors.green.shade200;
  if(isFutureWorkout(sw)) return Colors.red.shade200;
  return Colors.yellow;
}
DateTime startOfWeek(DateTime date){
  return DateTime(date.year,date.month,date.day).subtract(Duration(days: date.weekday -1 ));
}
DateTime endOfWeek(DateTime date){
  return startOfWeek(date).add(const Duration(days: 6));
}
class WeeklyWorkoutsScreen extends StatefulWidget{
  final VoidCallback? onWorkoutUpdated;
  const WeeklyWorkoutsScreen({super.key, this.onWorkoutUpdated});

  @override
  State<WeeklyWorkoutsScreen> createState() => WeeklyWorkoutScreenState();

}
class WeeklyWorkoutScreenState extends State<WeeklyWorkoutsScreen>{
  final AuthenticationService authenticationService = AuthenticationService();

  late Future<List<ScheduledWorkout>> weeklyWorkouts;

  @override
  void initState(){
    super.initState();
    weeklyWorkouts = fetchWeeklyWorkouts();
  }

  Future<List<ScheduledWorkout>> fetchWeeklyWorkouts() async {
    final user = authenticationService.getCurrentUser();
    if(user == null) return [];

    final now = DateTime.now();
    final start = startOfWeek(now);
    final end = endOfWeek(now);

    final result = await FS.list.filter<ScheduledWorkout>(ScheduledWorkout)
                                    .whereEqualTo('userId', user.uid)
                                    .fetch();

      return result.items.where((sw){
        final date = DateTime(
          sw.scheduledDate.year,
          sw.scheduledDate.month,
          sw.scheduledDate.day
        );
        return !date.isBefore(start) && !date.isAfter(end);
      }).toList();
  }

  @override
  Widget build (BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Weekly Workouts')),
        body: FutureBuilder<List<ScheduledWorkout>>(
          future: weeklyWorkouts,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.data!.isEmpty) {
              return const Center(child: Text('No workouts scheduled'));
            }

            final scheduled = snapshot.data!
              ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

            return ListView.builder(
                itemCount: scheduled.length,
                itemBuilder: (context, index) {
                  final sw = scheduled[index];
                  return FutureBuilder<Workout?>(
                    future: FS.get.one<Workout>(sw.workoutId),
                    builder: (context,workoutSnapshot){
                      if(!workoutSnapshot.hasData){
                        return const SizedBox();
                      }

                      final workout = workoutSnapshot.data!;

                      return Card(
                        color: workoutCardColor(sw),
                        margin: const EdgeInsets.symmetric(horizontal: 12,vertical: 6),
                        child: ListTile(leading: const Icon (Icons.fitness_center),
                        title: Text(workout.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(weekdayLabel(sw.scheduledDate)),
                        trailing: SizedBox(width: 110,
                        child: Row(mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                              width: 36,height: 36,
                              child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    padding: EdgeInsets.zero
                                  ),
                                  onPressed: (){
                                    Navigator.push(context,MaterialPageRoute(
                                        builder: (_) => WorkoutDetailsScreen(workout: workout,isEditable: false)));
                                  },
                                  child: const Icon (Icons.visibility,size: 20)),
                            ),
                            SizedBox(
                              width: 36,height: 36,
                              child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.zero
                                  ),
                                  onPressed: sw.isCompleted ? null : () async {
                                    final updated = await Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => WorkoutDetailsScreen(workout: workout,isEditable: true))
                                    );
                                    if(updated == true){
                                      setState(() {
                                        weeklyWorkouts = fetchWeeklyWorkouts();
                                      });
                                    }
                                    if(widget.onWorkoutUpdated != null){
                                      widget.onWorkoutUpdated!();
                                    }
                                  },
                                  child: const Icon (Icons.edit,size: 20)),
                            ),
                            const SizedBox(width: 2),
                            SizedBox(width: 36,height: 36,
                            child:  ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                ),
                            onPressed: sw.isCompleted ? null : () async {
                                  final updated = await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => EditWeeklyWorkoutScreen(scheduledWorkout: sw))
                                  );
                                  if(updated == true){
                                    setState(() {
                                      weeklyWorkouts = fetchWeeklyWorkouts();
                                    });
                                  }
                                  if(widget.onWorkoutUpdated != null){
                                    widget.onWorkoutUpdated!();
                                  }
                            },
                            child: const Icon (Icons.swap_horiz,size: 20))
                            ),
                          ],
                        ))),

                      );
                    },
                  );
                },
            );
          },
        ),
    );
  }
    String weekdayLabel(DateTime date) {
      const days = ['Monday', 'Tuesday', 'Wednesday',
      'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return days[date.weekday - 1];
    }
  }
