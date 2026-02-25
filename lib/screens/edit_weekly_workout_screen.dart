import 'package:collection/collection.dart';
import 'package:firestorm/firestorm.dart';
import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/models/scheduled_workout.dart';
import 'package:me_fit/screens/home_screen.dart';
import 'package:me_fit/screens/weekly_workouts_screen.dart';

import '../models/workout.dart';
import '../models/workoutExercises.dart';

class EditWeeklyWorkoutScreen extends StatefulWidget{
  final ScheduledWorkout scheduledWorkout;

  const EditWeeklyWorkoutScreen({super.key, required this.scheduledWorkout});
  @override
  State<EditWeeklyWorkoutScreen> createState() => EditWeeklyWorkoutScreenState();
}

class EditWeeklyWorkoutScreenState extends State<EditWeeklyWorkoutScreen>{

  DateTime selectedDate = DateTime.now();
  Workout? selectedWorkout;
  List<Workout> myWorkouts = [];

  String? originalWorkoutId = '';

  @override
  void initState(){
    super.initState();
    selectedDate = widget.scheduledWorkout.scheduledDate;
    originalWorkoutId = widget.scheduledWorkout.workoutId;
    loadMyWorkouts();
  }

  Future<void> loadMyWorkouts() async {
    final result = await FS.list.filter<Workout>(Workout)
                            .whereEqualTo('createdBy', widget.scheduledWorkout.userId)
                            .whereEqualTo('isMyWorkout', true)
                            .fetch();


    if(!mounted) return;

    final currentWorkout = result.items.firstWhereOrNull(
        (w) => w.id == widget.scheduledWorkout.workoutId
        );

    setState(() {
      myWorkouts = result.items;
      selectedWorkout = currentWorkout;
    });


  }

  Future<void> updateScheduledWorkout({ DateTime? newDate, Workout? newWorkout})async{
    final updatedDate = newDate != null ? normaliseDate(newDate) : widget.scheduledWorkout.scheduledDate;

    if(newDate != null){
      final originalDate = normaliseDate(widget.scheduledWorkout.scheduledDate);

      if(updatedDate != originalDate) {
        final existing = await FS.list.filter<ScheduledWorkout>(ScheduledWorkout)
                                      .whereEqualTo('usedId', widget.scheduledWorkout.userId)
                                      .fetch();

        final conflict = existing.items.any((sw) {
          return sw.id != widget.scheduledWorkout.userId && normaliseDate(sw.scheduledDate) == updatedDate;

        });
        if(conflict) {
          if(!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('There is already a workout on that day')));
        return;
        }
      }
      widget.scheduledWorkout.scheduledDate = updatedDate;
    }
    if(newWorkout != null) {
      final clonedWorkout = Workout(
        id: Firestorm.randomID(),
        name: newWorkout.name,
        createdBy: newWorkout.createdBy,
        isMyWorkout: false,
        createdOn: DateTime.now(),
      );
      await FS.create.one(clonedWorkout);
      final weResult = await FS.list
          .filter<WorkoutExercises>(WorkoutExercises)
          .whereEqualTo('workoutId', newWorkout.id)
          .fetch();

      final templateExercises = weResult.items;

      for (var ex in templateExercises) {
        final clonedExercise = WorkoutExercises(
          id: Firestorm.randomID(),
          workoutId: clonedWorkout.id,
          exerciseId: ex.exerciseId,
          order: ex.order,
          repetitions: ex.repetitions,
          sets: ex.sets,
          restBetweenSets: ex.restBetweenSets,
          duration: ex.duration,
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
      widget.scheduledWorkout.workoutId = clonedWorkout.id;
    }
    await FS.update.one(widget.scheduledWorkout);
  }
    @override
    Widget build(BuildContext context){
      return Scaffold(
        appBar: AppBar(title: const Text('Change date/Replace Workout')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.circular(12)),
                elevation: 4,
                child: ListTile(
                leading: Icon(Icons.calendar_today,color: Colors.blue),
                title: const Text('Workout Day',style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(weekdayLabel(selectedDate),style: TextStyle(fontSize: 16),),

                onTap: () async {
                  final today = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate.isBefore(today) ? today : selectedDate,
                    firstDate: today,
                    lastDate: endOfWeek(today),
                  );

                  if(picked != null){
                    setState(() {
                      selectedDate = picked;
                    });
                    await updateScheduledWorkout(newDate: picked);
                    if(mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Workout updated'),duration: Duration(seconds: 2),));
                    }
                  }
                },
                ),
              ),
              const SizedBox(height: 16),
              if (myWorkouts.isNotEmpty)
                Card(shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.circular(12)),
                elevation: 4,
                child: Padding(
                padding: const EdgeInsets.all(12),
                child:
                Row(children: [ Expanded(
                      child: DropdownButtonFormField<Workout>(
                        value: selectedWorkout,hint: const Text('Select a workout (optional)'),
                        items: myWorkouts.map((w) {
                          return DropdownMenuItem(
                            value: w, child: Text(w.name),
                          );
                        }).toList(),
                        onChanged: (value) async {
                          setState(() => selectedWorkout = value);
                          if (value != null) {
                            await updateScheduledWorkout(newWorkout: value);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Workout replaced with "${value.name}"'),duration: const Duration(seconds: 2),
                                ),
                              );}}},
                        decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),),
                    ),
                    if (selectedWorkout != null)
                      Padding(padding: const EdgeInsets.only(left:8.0),
                      child:
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent
                        ,shape: const CircleBorder(),padding: EdgeInsets.all(12)),
                        onPressed: () async {
                          setState(() {
                            selectedWorkout = null;
                            widget.scheduledWorkout.workoutId = widget
                                .scheduledWorkout.originalWorkoutId ?? '';
                          });
                          await FS.update.one(widget.scheduledWorkout);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restored original workout'),duration: Duration(seconds: 2),),
                            );
                          }},
                        child: const Icon(Icons.clear,color: Colors.white),
                        ),
                        ),],
                ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

  String weekdayLabel(DateTime date) {
    const days = ['Monday', 'Tuesday', 'Wednesday',
      'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[date.weekday - 1];
  }
}