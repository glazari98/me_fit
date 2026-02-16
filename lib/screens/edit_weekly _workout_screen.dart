import 'package:collection/collection.dart';
import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/models/scheduled_workout.dart';
import 'package:me_fit/screens/home_screen.dart';
import 'package:me_fit/screens/weekly_workouts_screen.dart';

import '../models/workout.dart';

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

  @override
  void initState(){
    super.initState();
    selectedDate = widget.scheduledWorkout.scheduledDate;
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

  Future<void> saveChanges() async {
    final originalDate = normaliseDate(widget.scheduledWorkout.scheduledDate);

    final newDate = normaliseDate(selectedDate);

    if(newDate != originalDate){
      final existing = await FS.list.filter<ScheduledWorkout>(ScheduledWorkout)
          .whereEqualTo('userId', widget.scheduledWorkout.userId)
          .fetch();
      final conflict = existing.items.any((sw){
        return sw.id != widget.scheduledWorkout.id &&
            normaliseDate(sw.scheduledDate) ==newDate;
      });
      if(conflict){
        if(!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('There is already a workout on that day'),
            )
        );
        return;
      }
    }
    widget.scheduledWorkout.scheduledDate = newDate;
    if(selectedWorkout != null ){
      widget.scheduledWorkout.workoutId = selectedWorkout!.id;
    }
    await FS.update.one(widget.scheduledWorkout);

    if(!mounted) return;

    Navigator.pop(context,true);
  }

    @override
    Widget build(BuildContext context){
      return Scaffold(
        appBar: AppBar(title: const Text('Change date/Replace Workout')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ListTile(
                title: const Text('Workout Day'),
                subtitle: Text(weekdayLabel(selectedDate)),
                trailing: const Icon(Icons.calendar_today),
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
                  }
                },
              ),
              const SizedBox(height: 16),
              if(myWorkouts.isNotEmpty)
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<Workout>(
                      value: selectedWorkout,
                      hint: const Text('Select a workout (optional)'),
                      items: myWorkouts.map((w){
                        return DropdownMenuItem(
                          value: w,
                            child: Text(w.name),
                        );
                      }).toList(),
                      onChanged: (value){
                        setState(() => selectedWorkout = value);
                      },
                       decoration: const InputDecoration(
                         border: OutlineInputBorder(),
                         contentPadding: EdgeInsets.symmetric(horizontal: 12,vertical: 12),
                       ) ,
                    ),
                  ),
                    if(selectedWorkout != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear selection',
                        onPressed: (){
                          setState(() {
                            selectedWorkout = null;
                          });
                        },
                      )
                      ],
                    ),
                    const Spacer(),
                    ElevatedButton(onPressed: saveChanges, child: const Text('Save changes'))
                  ],
                )
              ),
            );
          }

  String weekdayLabel(DateTime date) {
    const days = ['Monday', 'Tuesday', 'Wednesday',
      'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[date.weekday - 1];
  }
}