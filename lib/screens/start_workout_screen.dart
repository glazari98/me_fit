import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/models/scheduled_workout.dart';
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
  late Future<Map<DateTime,List<ScheduledWorkout>>> weeklyWorkouts;

  @override
  void initState(){
    super.initState();
    weeklyWorkouts = fetchWeeklyWorkouts();
  }

  Future<Map<DateTime,List<ScheduledWorkout>>> fetchWeeklyWorkouts() async {
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

    Map<DateTime, List<ScheduledWorkout>> grouped = {};
    for (final sw in weeklyScheduled) {
      final date = normaliseDate(sw.scheduledDate);
      grouped.putIfAbsent(date, () => []).add(sw);
      }
    return Map.fromEntries(
      grouped.entries.toList()..sort((a,b) => a.key.compareTo(b.key))
      );
    }

  bool isFutureWorkout(ScheduledWorkout sw){
    return sw.scheduledDate.isAfter(DateTime.now());
  }
  Color workoutCardColor(ScheduledWorkout sw){
    if(sw.isCompleted) return Colors.green;
    if(isFutureWorkout(sw)) return Colors.red;
    return Colors.yellow;
  }

  bool isButtonEnabled(ScheduledWorkout sw){
    if(sw.isCompleted) return false;
    if(isFutureWorkout(sw)) return false;
    return true;
  }
  
  String buttonLabel(ScheduledWorkout sw){
    if(sw.isCompleted) return 'Completed';
    if(isFutureWorkout(sw)) return 'Locked';
    return 'Start';
  }

  String weekdayLabel(DateTime date) {
    const days = ['Monday', 'Tuesday', 'Wednesday',
      'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[date.weekday - 1];
  }
    @override
    Widget build(BuildContext context) {
      return Scaffold( appBar: AppBar(title: const Text('Start Workout')),
      body:  FutureBuilder<Map<DateTime,List<ScheduledWorkout>>>(
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
                      ...workouts.map((sw){
                      return FutureBuilder<Workout?>(
                      future: FS.get.one<Workout>(sw.workoutId),
                      builder: (context,snapshot){
                        if(!snapshot.hasData){
                        return const SizedBox.shrink();
                        }
                        
                        final workout = snapshot.data!;
                        final enabled = isButtonEnabled(sw);
                        
                        return Card(
                            color: workoutCardColor(sw),
                            margin: const EdgeInsets.symmetric(horizontal: 16,vertical: 4),
                            child: ListTile(
                              title: Text(workout.name,
                              style: TextStyle(fontWeight: FontWeight.bold,color: Colors.black)),
                              trailing: ElevatedButton(
                                  onPressed: enabled ? () async {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => ActiveWorkoutScreen(workout: workout))
                                    );
                                    setState(() {
                                      weeklyWorkouts = fetchWeeklyWorkouts();
                                    });
                                  } : null,
                                child: Text(buttonLabel(sw),
                              ),
                              ),
                            ),
                        );
                      },
                      );
                      }).toList(),
                    ],
                  );
                }).toList(),
              ]);
            },
      ),
      );
    }
}