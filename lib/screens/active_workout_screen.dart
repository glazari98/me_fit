import 'dart:async';

import 'package:firestorm/firestorm.dart';
import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/models/bodyPart.dart';
import 'package:me_fit/models/workout.dart';
import 'package:me_fit/models/exercise.dart';
import 'package:me_fit/models/exerciseType.dart';
import 'package:me_fit/models/scheduled_workout.dart';
import 'package:me_fit/models/workoutExerciseFeedback.dart';
import 'package:me_fit/models/workoutExercises.dart';
import 'package:me_fit/screens/workout_feedback_screen.dart';
import 'package:me_fit/screens/exercise_details_screen.dart';



class ActiveWorkoutScreen extends StatefulWidget{
  final Workout workout;

  const ActiveWorkoutScreen({super.key, required this.workout});

  @override
  State<ActiveWorkoutScreen> createState() => ActiveWorkoutScreenState();
}
enum ExercisePhase {
  idle,
  activeSet,
  rest,
  completed,
}
class ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  List<WorkoutExercises> workoutExercises = [];
  Map<String, Exercise> exerciseMap = {};

  int currentIndex = 0;
  //workout timer
  int elapsedSeconds = 0;
  Timer? workoutTimer;
  bool workoutTimerStarted = false;
  //exercise state
  ExercisePhase phase = ExercisePhase.idle;
  int currentSet = 1;
  int remainingSeconds = 0;
  Timer? phaseTimer;
  bool isLastSetRest = false;

  List<BodyPart> bodyParts = [];
  List<ExerciseType> exerciseTypes = [];

  @override
  void initState(){
    super.initState();
    loadWorkout();
    loadData();
  }
  Future<void> loadData() async {
    final bodyPartsResult = await FS.list.allOfClass<BodyPart>(BodyPart);

    final exerciseTypesResult = await FS.list.allOfClass<ExerciseType>(
        ExerciseType);
    if (!mounted) return;
    setState(() {
      bodyParts = bodyPartsResult;
      exerciseTypes = exerciseTypesResult;
    });
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
  void startWorkoutTimer(){
    if(workoutTimerStarted) return;
    workoutTimerStarted = true;
    workoutTimer = Timer.periodic(const Duration(seconds: 1), (_){
      setState(()=> elapsedSeconds++);
    });
  }

  //helper functions

  WorkoutExercises get we => workoutExercises[currentIndex];
  Exercise get ex => exerciseMap[we.exerciseId]!;

  String getExerciseType(WorkoutExercises we){
    if(we.distance != null) return 'AEROBIC';
    if(we.duration != null && we.sets != null) return 'CARDIO_PLYO';
    if(we.duration != null && we.sets == null) return 'STRETCHING';
    return 'STRENGTH';
  }

  void moveToNextExercise(){
    phaseTimer?.cancel();
    phase = ExercisePhase.idle;
    currentSet = 1;

    if(currentIndex < workoutExercises.length - 1){
      setState(() => currentIndex++);
    } else{
      finishWorkout();
    }
  }
  void completeExercise() {
    if(currentIndex < workoutExercises.length -1){
      setState(() => currentIndex++);
    } else {
      finishWorkout();
    }
  }
  Future<void> finishWorkout() async {
    workoutTimer?.cancel();
    phaseTimer?.cancel();

    for(var we in workoutExercises){
      final feedback = WorkoutExerciseFeedback(
          id: Firestorm.randomID(),
          workoutExerciseId: we.id,
          setsCompleted: we.setsCompleted,
          repsCompleted: we.repsCompleted,
          distanceCovered: we.distanceCovered,
          timeForDistanceCovered: we.timeForDistanceCovered,
          stretchingCompleted: we.stretchingCompleted);
        await FS.create.one(feedback);
    }
    final scheduled = await FS.list.filter<ScheduledWorkout>(ScheduledWorkout)
                              .whereEqualTo('workoutId', widget.workout.id)
                              .fetch();
    if(scheduled.items.isNotEmpty){
      final sw = scheduled.items.first;
      sw.isCompleted = true;
      sw.totalDuration = elapsedSeconds;
      sw.completedDate = DateTime.now();

      await FS.update.one(sw);
    }
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => WorkoutFeedbackScreen(
              workout: widget.workout,
              exercises: workoutExercises,
            ),
        ),
    );
  }

  //logic for strength
  void startStrengthSet(){
    startWorkoutTimer();
    setState(() {
      phase = ExercisePhase.activeSet;
      currentSet = (we.setsCompleted ?? 0) + 1;
    });
  }

  void completeStrengthSet() async{
    we.setsCompleted = (we.setsCompleted ?? 0) +1;
    we.repsCompleted = (we.repsCompleted ?? 0) + (we.repetitions ?? 0);

    await FS.update.one(we);

    if(we.setsCompleted! >= we.sets!){
      startRest(we.restBetweenSets!,postExercise: true);
    }else{
      startRest(we.restBetweenSets!);
    }
  }

  //cardio-plyo logic
  void startTimedSet() {
    startWorkoutTimer();

    phase = ExercisePhase.activeSet;
    remainingSeconds = we.duration!;

    phaseTimer?.cancel();
    phaseTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      setState(() => remainingSeconds--);
      if(remainingSeconds <= 0) {
        t.cancel();

        we.setsCompleted = (we.setsCompleted ?? 0) +1;
        FS.update.one(we);

        if(we.setsCompleted! >= we.sets!){
          startRest(we.restBetweenSets!, postExercise: true);
        }else {
          startRest(we.restBetweenSets!);
        }
      }
    });
  }


  //aerobic login
  void completeAerobic(double distanceCovered) async {
    we.distanceCovered = distanceCovered;
    we.timeForDistanceCovered = elapsedSeconds;

    await FS.update.one(we);
    moveToNextExercise();
  }

  //stretching logic
  void startStretching(){
    startWorkoutTimer();

    phase = ExercisePhase.activeSet;
    remainingSeconds = we.duration!;

    phaseTimer?.cancel();
    phaseTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => remainingSeconds--);
      if (remainingSeconds <= 0) {
        t.cancel();

        we.stretchingCompleted = true;
        FS.update.one(we);
        moveToNextExercise();
      }
    });
  }


  //rest
  void startRest(int seconds, {bool postExercise = false}){
    phase = ExercisePhase.rest;
    remainingSeconds = seconds;
    isLastSetRest = postExercise;

    phaseTimer?.cancel();

    phaseTimer = Timer.periodic(const Duration(seconds: 1), (t){
      setState(() =>remainingSeconds--);
      if(remainingSeconds <= 0){
        t.cancel();
      if(isLastSetRest){
        isLastSetRest = false;
        moveToNextExercise();
        return;
      }
        final type = getExerciseType(we);

        if(type == 'CARDIO_PLYO') {
          startTimedSet();
        }
        phase = ExercisePhase.activeSet;
        currentSet++;

      }
    });
  }

  @override
  Widget build(BuildContext context){
    if(workoutExercises.isEmpty || exerciseMap.isEmpty){
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
                'Workout time: ${elapsedSeconds ~/ 60}:${(elapsedSeconds % 60).toString().padLeft(2,'0')}',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),


              buildExerciseControls(),

            ],
          ) ,
      ),
    );
  }

 Widget buildExerciseControls() {
  final type = getExerciseType(we);

  if(phase == ExercisePhase.rest){
    return Text(
      'Rest: $remainingSeconds s',
      style: const TextStyle(fontSize: 20,color: Colors.red),
    );
  }
  switch(type){
    case 'STRENGTH':
      if(phase == ExercisePhase.idle) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Exercise ${currentIndex + 1}: ${ex.name}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Sets ${we.sets}'),
            Text('Repetitions: ${we.repetitions}'),
            Text('Rest between sets: ${we.restBetweenSets} s'),
            ElevatedButton(
                onPressed: () { Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => ExerciseDetailsScreen(
                            exercise: ex,
                            bodyParts: bodyParts,
                            exerciseTypes: exerciseTypes)));
                },
                child: const Icon(Icons.visibility)),
            ElevatedButton(
                onPressed: startStrengthSet,
                child: Text('Start Exercise')),
          ],
        );
      }
      if(phase == ExercisePhase.activeSet){
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Exercise ${currentIndex + 1}: ${ex.name}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Set $currentSet /  ${we.sets}'),
            Text('Repetitions: ${we.repetitions}'),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: completeStrengthSet,
                child: Text('Complete set')),
          ],
        );
      }
      return const SizedBox();
    case 'CARDIO_PLYO':
      if(phase == ExercisePhase.idle) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Exercise ${currentIndex + 1}: ${ex.name}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Sets:${we.sets}'),
            Text('Duration of set: ${we.duration} s'),
            ElevatedButton(
                onPressed: () { Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => ExerciseDetailsScreen(
                            exercise: ex,
                            bodyParts: bodyParts,
                            exerciseTypes: exerciseTypes)));
                },
                child: const Icon(Icons.visibility)),
            ElevatedButton(
                onPressed: startTimedSet,
                child: Text('Start Exercise'))
          ],
        );
      }
      if(phase == ExercisePhase.activeSet) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Exercise ${currentIndex + 1}: ${ex.name}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Set: $currentSet / ${we.sets}'),
            Text('Time left: $remainingSeconds s',
            style: const TextStyle(fontSize: 20)),
          ],
        );
      }
      return const SizedBox();
    case 'AEROBIC':
      if(phase == ExercisePhase.idle) {
        return Column(
          children: [
            Text('Exercise ${currentIndex + 1}: ${ex.name}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Target distance: ${we.distance} km'),
            ElevatedButton(
                onPressed: () { Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => ExerciseDetailsScreen(
                            exercise: ex,
                            bodyParts: bodyParts,
                            exerciseTypes: exerciseTypes)));
                },
                child: const Icon(Icons.visibility)),
            ElevatedButton(
                onPressed: () {
                  startWorkoutTimer();
                  phase = ExercisePhase.activeSet;
                },
                child: const Text('Start Exercise'))
          ],
        );
      }
      if(phase == ExercisePhase.activeSet) {
        return Column(
          children: [
            Text('Target distance: ${we.distance} km'),
            ElevatedButton(
                onPressed: showAerobicDistanceDialog,
                child: const Text('Complete Exercise'))
          ],
        );
      }
      return const SizedBox();
    case 'STRETCHING':
      if(phase == ExercisePhase.idle) {
        return Column(
          children: [
            Text('Exercise ${currentIndex + 1}: ${ex.name}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
              Text('Duration: ${we.duration} s'),
            ElevatedButton(
                onPressed: () { Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => ExerciseDetailsScreen(
                            exercise: ex,
                            bodyParts: bodyParts,
                            exerciseTypes: exerciseTypes)));
                },
                child: const Icon(Icons.visibility)),
            ElevatedButton(
                onPressed: startStretching,
                child: Text('Start Stretching'
                  ))
          ],
        );
      }
      if(phase == ExercisePhase.activeSet) {
        return Column(
          children: [
            Text('Exercise ${currentIndex + 1}: ${ex.name}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Time left: $remainingSeconds s'),
          ],
        );
      }
      return const SizedBox();
    default: return SizedBox();
  }
 }

 Future<void> showAerobicDistanceDialog() async{
    final controller = TextEditingController();

    final result = await showDialog<double>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Distance covered'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Distance (km)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
                onPressed: (){
                  final value = double.tryParse(controller.text);
                  if(value != null){
                    Navigator.pop(context,value);
                  }
                },
                child: const Text('Confirm'))
          ],
        ));
    if(result != null){
      completeAerobic(result);
    }
 }
  @override
  void dispose(){
    workoutTimer?.cancel();
    phaseTimer?.cancel();
    super.dispose();
  }
}