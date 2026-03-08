import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/models/scheduled_workout.dart';
import 'package:me_fit/services/authentication_service.dart';
import '../components/drawer_menu.dart';
import '../components/workout_card.dart';
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

  bool isFutureWorkout(ScheduledWorkout sw){
    return sw.scheduledDate.toDate().isAfter(DateTime.now());
  }
  Color workoutCardColor(ScheduledWorkout sw){
    if(sw.isCompleted) return Colors.green.shade200;
    if(isFutureWorkout(sw)) return Colors.red.shade200;
    return Colors.yellow.shade300;
  }

  bool isButtonEnabled(ScheduledWorkout sw){
    if(sw.isCompleted) return false;
    if(isFutureWorkout(sw)) return false;
    return true;
  }

  String buttonLabel(ScheduledWorkout sw){
    if(sw.isCompleted) return 'Completed';
    if(isFutureWorkout(sw)) return 'Locked';
    if(sw.isInProgress == true) return 'Continue';
    return 'Start';
  }

  String weekdayLabel(DateTime date) {
    const days = ['Monday', 'Tuesday', 'Wednesday',
      'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[date.weekday - 1];
  }

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
              return const Center(child: CircularProgressIndicator.adaptive());
            }
            final groupedWorkouts = snapshot.data ?? {};
            if (groupedWorkouts.isEmpty) {
              return _buildEmptyState();
            }

            return ListView.builder(
              padding:  EdgeInsets.all(16),
              itemCount: groupedWorkouts.length,
              itemBuilder: (context, index) {
                final entry = groupedWorkouts.entries.elementAt(index);
                return _buildDaySection(entry.key, entry.value);
              },
            );
          },
        ),
      ),
    );
  }

  /// Simple empty state with icon and message
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No workouts scheduled for this week', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ],
      ),
    );
  }

  /// Builds a section for a specific day, showing the date and its workouts
  Widget _buildDaySection(DateTime date, List<ScheduledWorkout> workouts) {
    final bool isToday = normaliseDate(DateTime.now()) == date;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 16, bottom: 8),
          child: Row(
            children: [
              Text(
                isToday ? 'TODAY' : weekdayLabel(date).toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: isToday ? Theme.of(context).primaryColor : Colors.grey[600],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${date.day}/${date.month}',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
            ],
          ),
        ),
        ...workouts.map((scheduledWorkout) => WorkoutCard(
          key: ValueKey(scheduledWorkout.id),
          scheduledWorkout: scheduledWorkout,
          onRefresh: refreshData,
        )),
      ],
    );
  }
}