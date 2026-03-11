import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firestorm/firestorm.dart';
import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/components/drawer_menu.dart';
import 'package:me_fit/models/scheduled_workout.dart';
import 'package:me_fit/models/workout.dart';
import 'package:me_fit/screens/edit_workout_screen.dart';
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

  bool isChangingDate = false;

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
  //for changing workout date
  Future<void> changeWorkoutDate(ScheduledWorkout scheduledWorkout) async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,initialDate: scheduledWorkout.scheduledDate.toDate().isBefore(today)
        ? today : scheduledWorkout.scheduledDate.toDate(),
      firstDate: today,lastDate: endOfWeek(today),
    );

    if (picked != null) {
      setState(() => isChangingDate = true);

      final normalisedDate = normaliseDate(picked);
      final originalDate = normaliseDate(scheduledWorkout.scheduledDate.toDate());

      if (normalisedDate != originalDate) {
        //check for scheduled workouts on that date
        final existing = await FS.list.filter<ScheduledWorkout>(ScheduledWorkout)
            .whereEqualTo('userId', scheduledWorkout.userId)
            .fetch();
        final conflict = existing.items.any((sw) {
          return sw.id != scheduledWorkout.id &&
              normaliseDate(sw.scheduledDate.toDate()) == normalisedDate;
        });

        if (conflict) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('There is already a workout on that day')));
          setState(() => isChangingDate = false);
          return;
        }

        //update date
        scheduledWorkout.scheduledDate = Timestamp.fromDate(normalisedDate);
        await FS.update.one(scheduledWorkout);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Workout date updated'), duration: Duration(seconds: 2)));
          setState(() {
            weeklyWorkouts = fetchWeeklyWorkouts();
            isChangingDate = false;
          });
        }
      }
    }
  }
  //replace system workout with custom one/restore original workout
  Future<void> showReplaceWorkoutDialog(ScheduledWorkout scheduledWorkout) async {
    final user = authenticationService.getCurrentUser();
    if (user == null) return;

    //load custom workouts of user
    final result = await FS.list.filter<Workout>(Workout)
        .whereEqualTo('createdBy', user.uid)
        .whereEqualTo('isMyWorkout', true)
        .fetch();

    final myWorkouts = result.items;
    //check if current workouts has been replaced
    final hasOriginal = scheduledWorkout.originalWorkoutId != null &&
        scheduledWorkout.originalWorkoutId!.isNotEmpty;
    final isDifferent = scheduledWorkout.workoutId != scheduledWorkout.originalWorkoutId;
    final hasBeenReplaced = hasOriginal && isDifferent;

    if (myWorkouts.isEmpty && !hasBeenReplaced) {
      //show message if user has nto created custom workouts yet
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(children: [
              Icon(Icons.info_outline, color: Colors.orange),
              SizedBox(width: 8),Text('No Custom Workouts')],
            ),
            content: Text('You haven\'t created any custom workouts yet. Go to "Custom Workouts" to create one.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              )]),
      );
      return;
    }

    Workout? selectedWorkout;
    //show dropdown and restore button
    if (!mounted) return;
    final result2 = await showDialog<Workout?>(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title:  Row(
                  children: [
                    Icon(Icons.swap_horiz, color: Colors.purple),
                    SizedBox(width: 8),Text('Replace Workout')],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (myWorkouts.isNotEmpty) ...[
                      Text('Select a custom workout to replace the current one:'),
                      SizedBox(height: 15),
                      Container(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12)
                          ),
                          child: DropdownButtonHideUnderline(
                              child: DropdownButton<Workout>(
                                value: selectedWorkout,
                                hint: Text('Choose a workout'),
                                isExpanded: true,
                                items: myWorkouts.map((workout) {
                                  return DropdownMenuItem(
                                    value: workout,
                                    child: Text(workout.name),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedWorkout = value;
                                  });
                                },
                              ))),
                    ],
                    SizedBox(height: 10),
                    if (hasBeenReplaced) ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,foregroundColor: Colors.white,
                          minimumSize: Size(double.infinity, 48),shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: Icon(Icons.restore),
                        label: Text('Restore Original Workout'),
                        onPressed: () async {//close dialog and refresh
                          Navigator.pop(context);
                          if(scheduledWorkout.originalWorkoutId != null &&scheduledWorkout.originalWorkoutId!.isNotEmpty){
                            scheduledWorkout.workoutId = scheduledWorkout.originalWorkoutId!;//replace with original workout
                            await FS.update.one(scheduledWorkout);

                            if (mounted){
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restored original system workout'),duration: Duration(seconds: 2)));                         this.setState(() {
                                weeklyWorkouts = fetchWeeklyWorkouts();
                              });
                              this.setState(() {
                                weeklyWorkouts = fetchWeeklyWorkouts();
                              });
                            }
                            if (widget.onWorkoutUpdated != null) {
                              widget.onWorkoutUpdated!();
                            }
                          }
                        },
                      ),
                      SizedBox(height: 8),
                    ]],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, null),
                    child: Text('Cancel'),
                  ),
                  if (myWorkouts.isNotEmpty)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.purple,foregroundColor: Colors.white
                      ),
                      onPressed: selectedWorkout == null ? null: () => Navigator.pop(context, selectedWorkout),
                      child: Text('Replace'),
                    )]
            );
          }),
    );
    //replace with custom workout
    if (result2 != null) {
      //clone workout
      final clonedWorkout = Workout(
        id: Firestorm.randomID(),
        name: result2.name,
        createdBy: result2.createdBy,
        isMyWorkout: false,
        createdOn: Timestamp.now(),
      );
      await FS.create.one(clonedWorkout);

      //clone exercises
      final weResult = await FS.list
          .filter<WorkoutExercises>(WorkoutExercises)
          .whereEqualTo('workoutId', result2.id)
          .fetch();

      for (var ex in weResult.items) {
        final clonedExercise = WorkoutExercises(
          id: Firestorm.randomID(),
          workoutId: clonedWorkout.id,
          exerciseId: ex.exerciseId,
          order: ex.order,
          repetitions: ex.repetitions,
          sets: ex.sets,
          restBetweenSets: ex.restBetweenSets,
          durationOfTimedSet: ex.durationOfTimedSet,
          distance: ex.distance,
          setsCompleted: 0,
          repsCompleted: 0,
          durationLasted: 0,
          distanceCovered: 0,
          timeForDistanceCovered: 0,
          stretchingCompleted: false,
        );
        await FS.create.one(clonedExercise);
      }
      //update scheduled workout
      scheduledWorkout.workoutId = clonedWorkout.id;
      await FS.update.one(scheduledWorkout);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Workout replaced with "${result2.name}"'),
              duration: Duration(seconds: 2)),
        );
        setState(() {
          weeklyWorkouts = fetchWeeklyWorkouts();
        });
      }
      if (widget.onWorkoutUpdated != null) {
        widget.onWorkoutUpdated!();
      }
    }

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
          return SizedBox();
        }
        final workout = workoutSnapshot.data!;
        final bool isCompleted = sw.isCompleted;
        final bool isLocked = isFutureWorkout(sw);
        final bool isInProgress = sw.isInProgress == true;

        //check if workout has been replaced
        final bool hasBeenReplaced = sw.originalWorkoutId != null &&
            sw.originalWorkoutId!.isNotEmpty && sw.workoutId != sw.originalWorkoutId;

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final exerciseResult = await FS.list
                .filter<WorkoutExercises>(WorkoutExercises)
                .whereEqualTo('workoutId', workout.id)
                .fetch();
            if (sw.isCompleted) {
              await Navigator.push(
                context,MaterialPageRoute(
                  builder: (_) => WorkoutFeedbackScreen(
                    workout: workout,exercises: exerciseResult.items,
                  )),
              );
            }else{
              await Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ViewWorkoutScreen(workout: workout))
              );
            }
          },
          child: Container(
            margin: EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: isCompleted ? Colors.green[50] : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),blurRadius: 15,
                  offset: Offset(0, 5))
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: getStatusColor(isCompleted, isLocked, isInProgress).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      getStatusIcon(isCompleted, isLocked, isInProgress),
                      color: getStatusColor(isCompleted, isLocked, isInProgress)),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          workout.name,style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(isCompleted ? 'Completed!': (isLocked ? 'Locked until ${sw.scheduledDate.toDate().day}/${sw.scheduledDate.toDate().month}'
                              : (isInProgress ? 'In progress' : 'Ready to go')),
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        )],
                    )),
                  //show icons only if workout is not completed and not in progress
                  if (!isCompleted && !isInProgress) ...[
                    IconButton(
                      onPressed: () async {
                        final updated = await Navigator.push(
                          context,MaterialPageRoute(builder: (_) => EditWorkoutScreen(workout: workout)),
                        );
                        if (updated == true) {
                          setState(() {
                            weeklyWorkouts = fetchWeeklyWorkouts();
                          });
                        }
                        if (widget.onWorkoutUpdated != null) {
                          widget.onWorkoutUpdated!();
                        }
                      },
                      icon: Icon(Icons.edit, color: Colors.blue),
                      tooltip: 'Edit workout'),
                    IconButton(
                      onPressed: () => changeWorkoutDate(sw),
                      icon: Icon(Icons.calendar_month, color: Colors.green),
                      tooltip: 'Change date'),
                    IconButton(
                      onPressed: () => showReplaceWorkoutDialog(sw),
                      icon: Icon(Icons.swap_horiz, color: Colors.purple),
                      tooltip: 'Replace workout',
                    )]],
              )),
          ));
      },
    );
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