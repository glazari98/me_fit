import 'package:flutter/material.dart';
import 'package:me_fit/models/workoutExercises.dart';

import '../models/workout.dart';

class WorkoutFeedbackScreen extends StatelessWidget{
  final Workout workout;
  final List<WorkoutExercises> exercises;
  final int durationSeconds;

  const WorkoutFeedbackScreen({
    super.key,
    required this.workout,
    required this.exercises,
    required this.durationSeconds,
  });

  @override
  Widget build(BuildContext context){
    final totalSets = exercises.fold(0,(sum,e) => sum + (e.sets ?? 0));

    final totalReps = exercises.fold(0, (sum,e) => sum + (e.repetitions ?? 0));
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;

    return Scaffold (
      appBar: AppBar(title: const Text('Workout Complete')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Congratulations!', style: TextStyle(fontSize: 24,fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text('Workout: ${workout.name}'),
            const SizedBox(height:12),
            Text('Duration: $minutes min ${seconds.toString().padLeft(2,'0')} sec'),
            Text('Total sets: $totalSets'),
            Text('Total reps: $totalReps'),
            const Spacer(),
          ],
        )
      ),
    );
  }
}