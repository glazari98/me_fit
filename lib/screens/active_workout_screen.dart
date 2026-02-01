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
              ClipRect(
                child: Image.network(ex!.imageUrl,
                    fit: BoxFit.cover,
                    height: 300,
                    width: 400,
                    loadingBuilder: (context,child,loadingProgress){
                      if(loadingProgress == null) return child;
                      return SizedBox(height: 200,child: const Center(child: CircularProgressIndicator()));
                    },
                    errorBuilder: (context,error,stackTrace)=> SizedBox(
                      height: 200,
                      child: const Center(child: Icon(Icons.broken_image)),
                    )),

              ),
              const SizedBox(height: 8),
              Table(
                columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
                border: TableBorder.all(color: Colors.black,width: 0.5),
                defaultVerticalAlignment: TableCellVerticalAlignment.fill ,
                children: [
                  createTableRow('Exercise name', ex!.name),
                  createTableRow('Instruction', ex!.instruction),
                  if(we.sets != null) createTableRow('Sets', we.sets.toString()),
                  if(we.repetitions != null) createTableRow('Repetitions', we.repetitions.toString()),
                  if(we.restBetweenSets != null) createTableRow('Rest between sets', we.restBetweenSets.toString()),
                ],
              ),

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

  TableRow createTableRow(String label, String value){
    return TableRow(
      children: [
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.fill,
          child: Container(
            width: double.infinity,
          padding: const EdgeInsets.all(8),
          color: Colors.grey,
          child: Text(label,style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        TableCell(
        verticalAlignment: TableCellVerticalAlignment.bottom,
        child: Container(
          width: 50,
          padding: const EdgeInsets.all(8),
          child: Text(value),
        ),
        ),
      ]
    );
  }
}