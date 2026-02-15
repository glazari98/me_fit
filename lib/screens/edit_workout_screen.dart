import 'package:firestorm/firestorm.dart';
import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/models/exercise.dart';
import 'package:me_fit/models/workoutExercises.dart';
import 'package:me_fit/screens/create_workout_screen.dart';
import 'package:me_fit/screens/exercise_details_screen.dart';
import 'package:me_fit/screens/select_exercise_screen.dart';

import '../models/bodyPart.dart';
import '../models/exerciseType.dart';
import '../models/workout.dart';

class EditWorkoutScreen extends StatefulWidget {
  final Workout workout;

  const EditWorkoutScreen(
      {super.key, required this.workout});

  @override
  State<EditWorkoutScreen> createState() => EditWorkoutScreenState();
}
class WorkoutExerciseInstance {
  final WorkoutExercises workoutExercise;
  final Exercise exercise;
  final String exerciseTypeName;

  int? sets;
  int? reps;
  int? rest;
  int? duration;
  double? distance;

  WorkoutExerciseInstance({
    required this.workoutExercise,
    required this.exercise,
    required this.exerciseTypeName,
    this.sets,
    this.reps,
    this.rest,
    this.duration,
    this.distance
  });

  factory WorkoutExerciseInstance.fromWorkoutExercises(WorkoutExercises we,
      Exercise ex, String typeName) {
    return WorkoutExerciseInstance(
        workoutExercise: we,
        exercise: ex,
        exerciseTypeName: typeName,
        sets: we.sets,
        reps: we.repetitions,
        rest: we.restBetweenSets,
        duration: we.duration,
        distance: we.distance);
  }

  void applyToWorkoutExercise() {
    workoutExercise.sets = sets;
    workoutExercise.repetitions = reps;
    workoutExercise.restBetweenSets = rest;
    workoutExercise.duration = duration;
    workoutExercise.distance = distance;
  }
}

class EditWorkoutScreenState extends State<EditWorkoutScreen>{
  final List<WorkoutExerciseInstance> exercises = [];
  bool isLoading = true;

  @override
  void initState(){
    super.initState();
    loadExercises();
  }
  Future<void> loadExercises() async {
    final weResult =  await FS.list.filter<WorkoutExercises>(WorkoutExercises)
                          .whereEqualTo('workoutId', widget.workout.id)
                          .fetch();
    final workoutExercises = weResult.items..sort((a,b) => a.order.compareTo(b.order));
    final exerciseIds = workoutExercises.map((e) => e.exerciseId).toList();
    final exResult = await FS.list.filter<Exercise>(Exercise).whereIn('id',exerciseIds).fetch();
    final exerciseMap = {for (var e in exResult.items) e.id : e};

    final typeResult =  await FS.list.allOfClass<ExerciseType>(ExerciseType);
    final typeMap = {for (var t in typeResult) t.id: t.name};

    final instances = workoutExercises.map((we) {
      final ex = exerciseMap[we.exerciseId]!;
      final typeName = typeMap[ex.exerciseTypeId] ?? '';
      return WorkoutExerciseInstance.fromWorkoutExercises(we,ex,typeName);
    }).toList();

    setState(() {
      exercises.addAll(instances);
      isLoading = false;
    });
                         
  }

  Future<WorkoutExerciseInstance?> showExerciseAlterDialog(
      WorkoutExerciseInstance instance) async {
    final type = instance.exerciseTypeName;

    final sets = TextEditingController(text: instance.sets?.toString() ?? '3');
    final reps = TextEditingController(text: instance.reps?.toString() ?? '12');
    final rest = TextEditingController(text: instance.rest?.toString() ?? '60');
    final duration = TextEditingController(text: instance.duration?.toString() ?? '30');
    final distance = TextEditingController(text: instance.distance?.toString() ?? '1');

    return showDialog<WorkoutExerciseInstance>(
        context: context,
        builder: (_){
          return AlertDialog(
            title: Text('Edit ${instance.exercise.name}'),
            content: SingleChildScrollView(
                child: Column (
                  children: [
                    if(type == 'STRENGTH') ...[
                      numberField(sets, 'Sets (1-8)'),
                      numberField(reps, 'Reps (1-50)'),
                      numberField(rest, 'Rest seconds (10-600'),
                    ],
                    if(type == 'CARDIO' || type == 'PLYOMETRICS') ...[
                      numberField(sets, 'Sets (1-10)'),
                      numberField(duration, 'Duration seconds (10-7200)'),
                      numberField(rest, 'Rest seconds (20-600'),
                    ],
                    if(type == 'AEROBIC') ...[
                      numberField(distance, 'Distance (0.1-100 km)',isDecimal: true),
                    ],
                    if(type == 'STRETCHING') ...[
                      numberField(duration, 'Duration seconds (10-1800)'),
                    ],
                  ],
                )
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
              ElevatedButton(
                  onPressed: () {
                    if(!validateInputs(type, sets, reps, rest, duration, distance)) return;
                    if(type == 'STRENGTH'){
                      instance.sets = int.parse(sets.text);
                      instance.reps = int.parse(reps.text);
                      instance.rest = int.parse(rest.text);
                    }
                    if(type == 'CARDIO' || type == 'PLYOMETRICS'){
                      instance.sets = int.parse(sets.text);
                      instance.duration = int.parse(duration.text);
                      instance.rest = int.parse(rest.text);
                    }
                    if(type == 'AEROBIC' ){
                      instance.distance = double.parse(distance.text);
                    }
                    if(type == 'STRETCHING' ){
                      instance.duration = int.parse(duration.text);
                    }
                    Navigator.pop(context, instance);
                  },
                  child: const Text('Save'))
            ],
          );
        }
    );
  }
//validation
  bool validateInputs(String type, TextEditingController sets, TextEditingController reps,
      TextEditingController rest, TextEditingController duration, TextEditingController distance){
    try {
      if (type == 'STRENGTH') {
        final s = int.parse(sets.text);
        final r = int.parse(reps.text);
        final res = int.parse(rest.text);

        if (s < 1 || s > 8) throw 'Sets must be 1-8';
        if (r < 1 || r > 50) throw 'Reps must be 1-50';
        if (res < 10 || res > 600) throw 'Rest must be 10-600 sec';
      }
      if(type == 'CARDIO' || type == 'PLYOMETRICS'){
        final s = int.parse(sets.text);
        final d = int.parse(duration.text);
        final res = int.parse(rest.text);

        if(s < 1 || s > 10) throw 'Sets must be 1-10';
        if(d < 10 || d > 7200) throw 'Duration must be between 10-7200 sec';
        if (res < 10 || res > 600) throw 'Rest must be 10-600 sec';
      }
      if(type == 'AEROBIC'){
        final dist = double.parse(distance.text);
        if(dist < 0.1 || dist > 100) throw 'Distance must be 0.1-100km';
      }
      if(type == 'STRETCHING'){
        final d = int.parse(duration.text);
        if(d < 10 || d > 1800) throw 'Duration must be 10-1800 sec';
      }
      return true;
    } catch(e){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      return false;
    }
  }
  Widget numberField(TextEditingController controller, String label, {bool isDecimal = false}){
    return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          keyboardType: isDecimal ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.number,
          decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder()
          ),
        )
    );
  }
  String buildSummary(WorkoutExerciseInstance i){
    final type = i.exerciseTypeName;
    if(type == 'STRENGTH'){
      return '${i.sets ?? 0}x${i.reps ?? 0} • Rest ${i.rest ?? 0}s';
    }
    if(type == 'CARDIO' || type == 'PLYOMETRICS'){
      return '${i.sets ?? 0}x${i.duration ?? 0}s • Rest ${i.rest ?? 0}s';
    }
    if(type == 'AEROBIC'){
      return '${i.distance ?? 0} km';
    }
    if(type == 'STRETCHING'){
      return '${i.duration ?? 0} s';
    }
    return '';
  }
  Future<void> saveChanges() async {
    final originalResult = await FS.list.filter<WorkoutExercises>(WorkoutExercises)
                                  .whereEqualTo('workoutId', widget.workout.id)
                                  .fetch();

    final originalItems = originalResult.items;

    final currentIds = exercises.map((e) => e.workoutExercise.id).toSet();

    for(var original in originalItems){
      if(!currentIds.contains(original.id)){
        await FS.delete.one(original);
      }
    }

    for(int i = 0; i<exercises.length; i++){
      final instance = exercises[i];

      instance.applyToWorkoutExercise();
      instance.workoutExercise.order =  i+1;

      final exists = originalItems.any((original) => original.id ==  instance.workoutExercise.id);
      if(exists) {
        await FS.update.one(instance.workoutExercise);
      }else {
        await FS.create.one(instance.workoutExercise);
      }
    }
    if(!mounted) return;
    Navigator.pop(context,true);

  }
  Future<void> addExerciseFlow() async {
    if(exercises.length >= 50){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('You can add up to 50 exercises')),
      );
      return;
    }
    final Exercise? exercise = await Navigator.push(
      context,MaterialPageRoute(builder: (_) => const SelectExerciseScreen())
    );
    if(exercise == null) return;

    final exerciseType = await FS.get.one<ExerciseType>(exercise.exerciseTypeId);

    if(exerciseType == null) return;

    final newWorkoutExercise = WorkoutExercises(
        id: Firestorm.randomID(),
        workoutId: widget.workout.id,
        exerciseId: exercise.id,
        order: exercises.length + 1);

    final instance = WorkoutExerciseInstance(
        workoutExercise: newWorkoutExercise,
        exercise: exercise,
        exerciseTypeName: exerciseType.name);

    final altered = await showExerciseAlterDialog(instance);

    if(altered != null){
      setState(() {
        exercises.add(altered);
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Workout'),
        actions: [
          IconButton(
              onPressed: addExerciseFlow,
              icon: const Icon (Icons.add))
        ],),
      body: isLoading ? const Center (child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: ReorderableListView(
                  onReorder: (oldIndex, newIndex){
                    if(newIndex > oldIndex) newIndex--;
                    final item = exercises.removeAt(oldIndex);
                    exercises.insert(newIndex, item);
                    setState((){});
                  },
                children: [
                  for(int i =0; i < exercises.length ; i++)
                    Card(
                      key: ValueKey(exercises[i].workoutExercise.id),
                      child: ListTile(
                        title: Text(exercises[i].exercise.name),
                        subtitle: Text(buildSummary(exercises[i])),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                                onPressed: () async {
                                  final updated = await showExerciseAlterDialog(exercises[i]);
                                  if(updated != null) setState(() {});
                                },
                                icon: const Icon (Icons.edit,color: Colors.blue)),
                            IconButton(
                                onPressed: () {
                                  setState((){
                                    exercises.removeAt(i);
                                  });
                                },
                                icon: const Icon (Icons.delete,color: Colors.red)
                            ),
                          ],
                        ),
                      ),
                    )
                ],
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: saveChanges, child: const Text ('Save changes'))
          ],
        ),
      )
    );
  }
}