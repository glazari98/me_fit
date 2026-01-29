import 'dart:async';

import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/models/exercise.dart';
import 'package:me_fit/models/workoutExercises.dart';
import 'package:me_fit/screens/workout_feedback_screen.dart';

import '../models/workout.dart';

class ActiveWorkoutScreen extends StatefulWidget{
  final Workout workout;

  const ActiveWorkoutScreen({super.key, required this.workout});

  @override
  State<ActiveWorkoutScreen> createState() => ActiveWorkoutScreenState();
}

class ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  List<WorkoutExercises> workoutExercises = [];
  Map<String, Exercise> exerciseMap = {};

  int currentIndex = 0;
  int elapsedSeconds = 0;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    loadWorkout();
    startTimer();
  }

  Future<void> loadWorkout() async {
    final weResult = await FS.list.filter<WorkoutExercises>(WorkoutExercises)
                                    .whereEqualTo('workoutId', widget.workout.id)
                                     .fetch();
    weResult.items.sort((a,b) =>a.order.compareTo(b.order));
    workoutExercises = weResult.items;

    final exResult = await FS.list.filter<Exercise>(Exercise).fetch();

    exerciseMap = {
      for (var e in exResult.items) e.id: e,

    };

    setState(() {});
  }
  void startTimer(){
    timer = Timer.periodic(const Duration(seconds: 1), (_){
      setState(()=> elapsedSeconds++);
    });
  }

  void completeExercise() {
    if(currentIndex < workoutExercises.length -1){
      setState(() => currentIndex++);
    } else {
      finishWorkout();
    }
  }
  void finishWorkout(){
    timer?.cancel();

    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => WorkoutFeedbackScreen(
              workout: widget.workout,
              exercises: workoutExercises,
              durationSeconds: elapsedSeconds,
            ),
        ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context){
    if(workoutExercises.isEmpty){
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final we = workoutExercises[currentIndex];
    final ex = exerciseMap[we.exerciseId];
    final progress = (currentIndex + 1) / workoutExercises.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workout.name),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 16),
              Text(
                'Time: ${elapsedSeconds ~/ 60}:${(elapsedSeconds % 60).toString().padLeft(2,'0')}',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),

              Text(ex!.name, style: const TextStyle(fontSize: 24,fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(ex.instruction),
              const SizedBox(height:16),

              if(we.sets != null) Text('Sets: ${we.sets}'),
              if(we.repetitions != null) Text('Reps: ${we.repetitions}'),
              if(we.restBetweenSets != null) Text ('Rest: ${we.restBetweenSets}'),

              const Spacer(),

              ElevatedButton(
                  onPressed: completeExercise,
                  child: Text(currentIndex == workoutExercises.length -1
                  ? 'Finish Workout'
                  : 'Complete Exercise',
                  ),
              ),
            ],
          ) ,
      ),
    );

  }

}