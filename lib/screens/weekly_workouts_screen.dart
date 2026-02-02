import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/models/scheduledWorkout.dart';
import 'package:me_fit/models/workout.dart';
import 'package:me_fit/services/authentication_service.dart';


DateTime startOfWeek(DateTime date){
  return DateTime(date.year,date.month,date.day).subtract(Duration(days: date.weekday -1 ));
}
DateTime endOfWeek(DateTime date){
  return startOfWeek(date).add(const Duration(days: 6));
}
class WeeklyWorkoutsScreen extends StatefulWidget{
  const WeeklyWorkoutsScreen({super.key});

  @override
  State<WeeklyWorkoutsScreen> createState() => WeeklyWorkoutScreenState();

}
class WeeklyWorkoutScreenState extends State<WeeklyWorkoutsScreen>{
  final AuthenticationService authenticationService = AuthenticationService();

  late Future<Map<DateTime,Workout>> weeklyWorkouts;

  @override
  void initState(){
    super.initState();
    weeklyWorkouts = fetchWeeklyWorkouts();
  }

  Future<Map<DateTime,Workout>> fetchWeeklyWorkouts() async {
    final user = authenticationService.getCurrentUser();
    if(user == null) return{};

    final now = DateTime.now();
    final start = startOfWeek(now);
    final end = endOfWeek(now);

    final scheduled = await FS.list.filter<ScheduledWorkout>(ScheduledWorkout)
                                    .whereEqualTo('userId', user.uid)
                                    .fetch();

    final weekly = scheduled.items.where((sw) =>
        !sw.scheduledDate.isBefore(start) &&
        !sw.scheduledDate.isAfter(end));

    final Map<DateTime,Workout> result = {};

    for (final sw in weekly){
      final workout = await FS.get.one<Workout>(sw.workoutId);
      if(workout != null){
        result[sw.scheduledDate] = workout;
      }
    }
    return result;
  }

  @override
  Widget build (BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Weekly Workouts')),
        body: FutureBuilder<Map<DateTime, Workout>>(
          future: weeklyWorkouts,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.data!.isEmpty) {
              return const Center(child: Text('No workouts scheduled'));
            }

            final entries = snapshot.data!.entries.toList()
              ..sort((a, b) => a.key.compareTo(b.key));

            return ListView.builder(
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final date = entries[index].key;
                  final workout = entries[index].value;

                  return ListTile(
                    title: Text(
                        workout.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)
                    ),
                    subtitle: Text(weekdayLabel(date),
                    ),
                    leading: const Icon(Icons.fitness_center),
                  );
                });
          },
        )
    );
  }

    String weekdayLabel(DateTime date) {
      const days = ['Monday', 'Tuesday', 'Wednesday',
      'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return days[date.weekday - 1];
    }
  }
