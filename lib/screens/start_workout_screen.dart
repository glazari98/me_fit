import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/models/scheduled_workout.dart';
import 'package:me_fit/services/authentication_service.dart';
import '../components/drawer_menu.dart';
import '../components/workout_card.dart';
import '../utilityFunctions/utility_functions.dart';

//widget for displaying list of workouts and user can start a workout
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
//fetch weekly workouts
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
    //show day according to date in the week
  String weekdayLabel(DateTime date) {
    const days = ['Monday', 'Tuesday', 'Wednesday',
      'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[date.weekday - 1];
  }
//function for refreshing the screen when go back to the screen or entering
  Future<void> refreshData() async {
    weeklyWorkouts = fetchWeeklyWorkouts();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(centerTitle: true,
        title:  Text('Weekly Schedule', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      drawer: AppDrawer(scaffoldContext: context,currentRoute: '/start-workout'),
      body: RefreshIndicator(
        onRefresh: refreshData,
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

  ///simple empty state with icon and message
  Widget buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No workouts scheduled for this week', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ]),
    );
  }

  ///builds a section for a specific day, showing the date and its workouts
  Widget buildDaySection(DateTime date, List<ScheduledWorkout> workouts) {
    final bool isToday = normaliseDate(DateTime.now()) == date;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4, top: 16, bottom: 8),
          child: Row(
            children: [
              Text(
                isToday ? 'TODAY' : weekdayLabel(date).toUpperCase(),
                style: TextStyle(
                  fontSize: 13,fontWeight: FontWeight.w900,
                  letterSpacing: 1.2, color: isToday ? Theme.of(context).primaryColor : Colors.grey[600],
                )),
              SizedBox(width: 8),
              Text('${date.day}/${date.month}',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              )]),
        ),
        ...workouts.map((scheduledWorkout) => WorkoutCard(
          key: ValueKey(scheduledWorkout.id),
          scheduledWorkout: scheduledWorkout,
          onRefresh: refreshData,
        )),
      ]);
  }
}