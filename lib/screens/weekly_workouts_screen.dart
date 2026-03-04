import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/components/drawer_menu.dart';
import 'package:me_fit/models/scheduled_workout.dart';
import 'package:me_fit/models/workout.dart';
import 'package:me_fit/models/workoutExerciseFeedback.dart';
import 'package:me_fit/screens/edit_weekly_workout_screen.dart';
import 'package:me_fit/screens/edit_workout_screen.dart';
import 'package:me_fit/screens/home_screen.dart';
import 'package:me_fit/screens/view_workout_screen.dart';
import 'package:me_fit/screens/workout_feedback_screen.dart';
import 'package:me_fit/services/authentication_service.dart';

import '../models/workoutExercises.dart';

Color workoutCardColor(ScheduledWorkout sw){
  if(sw.isCompleted) return Colors.green.shade200;
  if(isFutureWorkout(sw)) return Colors.red.shade200;
  return Colors.yellow.shade300;
}
DateTime startOfWeek(DateTime date){
  return DateTime(date.year,date.month,date.day).subtract(Duration(days: date.weekday -1 ));
}
DateTime endOfWeek(DateTime date){
  return startOfWeek(date).add(const Duration(days: 6));
}
bool isFutureWorkout(ScheduledWorkout sw){
  return sw.scheduledDate.toDate().isAfter(DateTime.now());
}
DateTime normaliseDate(DateTime date) => DateTime(date.year,date.month,date.day);

class WeeklyWorkoutsScreen extends StatefulWidget{
  final VoidCallback? onWorkoutUpdated;
  const WeeklyWorkoutsScreen({super.key, this.onWorkoutUpdated});

  @override
  State<WeeklyWorkoutsScreen> createState() => WeeklyWorkoutScreenState();

}
class WeeklyWorkoutScreenState extends State<WeeklyWorkoutsScreen>{
  final AuthenticationService authenticationService = AuthenticationService();
  late Future<Map<DateTime, List<ScheduledWorkout>>> weeklyWorkouts;

  @override
  void initState(){
    super.initState();
    weeklyWorkouts = fetchWeeklyWorkouts();
  }

  Future<Map<DateTime, List<ScheduledWorkout>>> fetchWeeklyWorkouts() async {
    final user = authenticationService.getCurrentUser();
    if(user == null) return {};

    final now = DateTime.now();
    final start = startOfWeek(now);
    final end = endOfWeek(now);

    final result = await FS.list.filter<ScheduledWorkout>(ScheduledWorkout)
        .whereEqualTo('userId', user.uid)
        .fetch();
    final weeklyScheduled = result.items.where((sw) {
      final date = normaliseDate(sw.scheduledDate.toDate());
      return !date.isBefore(start) && !date.isAfter(end);
    }).toList();

    Map<DateTime, List<ScheduledWorkout>> grouped = {};
    for (final sw in weeklyScheduled) {
      final date = normaliseDate(sw.scheduledDate.toDate());
      grouped.putIfAbsent(date, () => []).add(sw);
    }
    return Map.fromEntries(
        grouped.entries.toList()..sort((a,b) => a.key.compareTo(b.key))
    );
  }

  String weekdayLabel(DateTime date) {
    const days = ['Monday', 'Tuesday', 'Wednesday',
      'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[date.weekday - 1];
  }

  @override
  Widget build (BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true,
        title:  Text('Weekly Workout Program', style: TextStyle(fontWeight: FontWeight.bold)), // Added bold style
      ),drawer: AppDrawer(scaffoldContext: context,currentRoute: '/weekly-workouts'),
      body: RefreshIndicator(
        onRefresh: () async => setState(() => weeklyWorkouts = fetchWeeklyWorkouts()),
        child: FutureBuilder<Map<DateTime, List<ScheduledWorkout>>>(
          future: weeklyWorkouts,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator.adaptive());
            }
            final groupedWorkouts = snapshot.data ?? {};
            if (groupedWorkouts.isEmpty) {
              return buildEmptyState();
            }
            return ListView.builder(
              padding:  EdgeInsets.all(16),
              itemCount: groupedWorkouts.length,
              itemBuilder: (context, index) {
                final entry = groupedWorkouts.entries.elementAt(index);
                return buildDaySection(entry.key, entry.value);
              },
            );
          },
        ),
      ),
    );
  }
  //where there are no workouts for this week
  Widget buildEmptyState() {
    return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16), Text('No workouts scheduled for this week',
              style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ]));
  }

  Widget buildDaySection(DateTime date, List<ScheduledWorkout> workouts) {
    final bool isToday = normaliseDate(DateTime.now()) == date;
    return Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: [ Padding(
          padding: const EdgeInsets.only(left: 4, top: 16, bottom: 8),
          child: Row( children: [
              Text( isToday ? 'TODAY' : weekdayLabel(date).toUpperCase(),
                style: TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w900,letterSpacing: 1.2,
                  color: isToday ? Theme.of(context).primaryColor : Colors.grey[600],
                )), SizedBox(width: 8),
              Text('${date.day}/${date.month}',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              )])),
        ...workouts.map((scheduledWorkout) => buildWorkoutCard(scheduledWorkout)),
      ]);
  }

  Widget buildWorkoutCard(ScheduledWorkout sw) {
    return FutureBuilder<Workout?>(
      future: FS.get.one<Workout>(sw.workoutId),
      builder: (context, workoutSnapshot) {
        if (!workoutSnapshot.hasData) {
          return const SizedBox();
        }
        final workout = workoutSnapshot.data!;
        final bool isCompleted = sw.isCompleted;
        final bool isLocked = isFutureWorkout(sw);
        final bool isInProgress = sw.isInProgress == true;
        return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              final exerciseResult = await FS.list
                  .filter<WorkoutExercises>(WorkoutExercises)
                  .whereEqualTo('workoutId', workout.id)
                  .fetch();
              if (sw.isCompleted) {
                await Navigator.push( context, MaterialPageRoute(
                    builder: (_) =>
                        WorkoutFeedbackScreen( workout: workout,
                          exercises: exerciseResult.items,
                        )),
                );
              }else{
                await Navigator.push( context, MaterialPageRoute(
                    builder: (_) =>
                        ViewWorkoutScreen( workout: workout)),
                );
              }
            },
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: isCompleted ? Colors.green[50] : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,offset: Offset(0, 5),
                  )],
              ),
              child: Padding( padding:  EdgeInsets.all(12),
            child: Row( children: [
                Container( padding:  EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: getStatusColor(isCompleted, isLocked, isInProgress).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    getStatusIcon(isCompleted, isLocked, isInProgress),
                    color: getStatusColor(isCompleted, isLocked, isInProgress),
                  )),
                 SizedBox(width: 16),
                Expanded( child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text(
                        workout.name,style:  TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text( isCompleted
                            ? 'Completed!': (isLocked
                            ? 'Locked until ${sw.scheduledDate.toDate().day}/${sw.scheduledDate.toDate().month}'
                            : (isInProgress ? 'In progress' : 'Ready to go')),
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      )]),
                ),
                Row(mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isCompleted && !isInProgress)
                      IconButton(onPressed: () async {
                          final updated = await Navigator.push(
                            context,MaterialPageRoute(
                              builder: (_) => EditWorkoutScreen(workout: workout),
                            ));
                          if (updated == true) {
                            setState(() { weeklyWorkouts = fetchWeeklyWorkouts();
                            });
                          }
                          if (widget.onWorkoutUpdated != null) {
                            widget.onWorkoutUpdated!();
                          }},
                        icon: Icon(Icons.edit, color: Colors.blue),
                      ),
                    if (!isCompleted && !isInProgress)
                      IconButton(onPressed: () async {
                          await Navigator.push(
                            context, MaterialPageRoute(
                              builder: (_) => EditWeeklyWorkoutScreen(scheduledWorkout: sw),
                            ),);
                          setState(() {
                            weeklyWorkouts = fetchWeeklyWorkouts();
                          });
                          if (widget.onWorkoutUpdated != null) {
                            widget.onWorkoutUpdated!();
                          }},
                        icon: Icon(Icons.swap_horiz, color: Colors.purple),
                      )], ),
              ] ),),
        ));
      });
  }

  Color getStatusColor(bool completed, bool locked, bool inProgress){
    if (completed) return Colors.green;
    if (locked) return Colors.redAccent;
    if (inProgress) return Colors.orange;
    return Colors.blue;
  }
  IconData getStatusIcon(bool completed, bool locked, bool inProgress){
    if (completed) return Icons.check_circle;
    if (locked) return Icons.lock_outline;
    if (inProgress) return Icons.fitness_center;
    return Icons.play_circle_filled;
  }
}