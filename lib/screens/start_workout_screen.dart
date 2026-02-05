import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/models/scheduledWorkout.dart';
import 'package:me_fit/services/authentication_service.dart';
import '../models/workout.dart';
import 'active_workout_screen.dart';
DateTime startOfWeek(DateTime date){
  return DateTime(date.year,date.month,date.day).subtract(Duration(days: date.weekday -1 ));
}
DateTime endOfWeek(DateTime date){
  return startOfWeek(date).add(const Duration(days: 6));
}

DateTime normaliseDate(DateTime date) => DateTime(date.year,date.month,date.day);

class StartWorkoutScreen extends StatefulWidget {
  StartWorkoutScreen({super.key});

  @override
  State<StartWorkoutScreen> createState() => StartWorkoutScreenState();
}
class StartWorkoutScreenState extends State<StartWorkoutScreen>{

  final AuthenticationService authenticationService = AuthenticationService();
  late Future<Map<DateTime,List<Workout>>> weeklyWorkouts;

  @override
  void initState(){
    super.initState();
    weeklyWorkouts = fetchWeeklyWorkouts();
  }

  Future<Map<DateTime,List<Workout>>> fetchWeeklyWorkouts() async {
    final user = authenticationService.getCurrentUser();
    if (user == null) return {};

    final swResult = await FS.list.filter<ScheduledWorkout>(ScheduledWorkout)
        .whereEqualTo('userId', user.uid)
        .fetch();

    final now = DateTime.now();
    final start = startOfWeek(now);
    final end = endOfWeek(now);

    final weeklyScheduled = swResult.items.where((sw) {
      final date = normaliseDate(sw.scheduledDate);
      return !date.isBefore(start) && !date.isAfter(end);
    }).toList();

    Map<String, Workout> workoutMap = {};
    for (final sw in weeklyScheduled) {
      final workout = await FS.get.one<Workout>(sw.workoutId);
      if (workout != null) {
        workoutMap[sw.id] = workout;
      }
    }

    Map<DateTime, List<Workout>> grouped = {};
    for (final sw in weeklyScheduled) {
      final date = normaliseDate(sw.scheduledDate);
      final workout = workoutMap[sw.id];
      if (workout != null) {
        grouped.putIfAbsent(date, () => []).add(workout);
      }
    }

    final sortedGroup = Map.fromEntries(
      grouped.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key)),
    );
    return sortedGroup;
  }
  String weekdayLabel(DateTime date) {
    const days = ['Monday', 'Tuesday', 'Wednesday',
      'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[date.weekday - 1];
  }
    @override
    Widget build(BuildContext context) {
      return Scaffold( appBar: AppBar(title: const Text('Start Workout')),
      body:  FutureBuilder<Map<DateTime,List<Workout>>>(
            future: weeklyWorkouts,
            builder: (context, snapshot){
              if(!snapshot.hasData){
                return const Center(child: CircularProgressIndicator());
              }
              final groupedWorkouts = snapshot.data!;
              if(groupedWorkouts.isEmpty){
                return const Center(child: Text('No workouts available'));
              }
              return ListView(
                children: [
                  ...groupedWorkouts.entries.map((entry) {
                  final date = entry.key;
                  final workouts = entry.value;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16,vertical: 8),
                        child: Text(
                          '${weekdayLabel(date)}, ${date.day}/${date.month}/${date.year}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      ...workouts.map((workout) => Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                      title: Text(workout.name),
                      trailing: ElevatedButton(
                        onPressed: () {
                        Navigator.push(
                        context,
                        MaterialPageRoute(
                        builder: (_) => ActiveWorkoutScreen(workout: workout)),
                        );
                        },
                      child: const Text('Start'),
                              ),
                            ),
                           ),
                        ),
                       ],
                    );
                  }),
                ],
              );
            },
        ),
      );
    }
}