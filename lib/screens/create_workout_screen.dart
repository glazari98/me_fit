import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firestorm/firestorm.dart';
import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:me_fit/models/exercise.dart';
import 'package:me_fit/models/exerciseType.dart';
import 'package:me_fit/models/workoutExercises.dart';
import 'package:me_fit/screens/select_exercise_screen.dart';
import 'package:me_fit/services/authentication_service.dart';

import '../models/workout.dart';


class CreateWorkoutScreen extends StatefulWidget{
  const CreateWorkoutScreen({super.key});

  @override
  State<CreateWorkoutScreen> createState() => CreateWorkoutScreenState();
}
class WorkoutExerciseInstance {
  final Exercise exercise;
  final String exerciseTypeName;

  int? sets;
  int? reps;
  int? rest;
  int? duration;
  double? distance;

  WorkoutExerciseInstance({
    required this.exercise,
    required this.exerciseTypeName
});
}
class CreateWorkoutScreenState extends State<CreateWorkoutScreen>{
  final formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();

  final List<WorkoutExerciseInstance> selectedExercises = [];

  //save workout
  Future<void> saveWorkout() async {
    if(!formKey.currentState!.validate()) return;

    if(selectedExercises.isEmpty){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one exercise')));
      return;
    }

    final workoutId = Firestorm.randomID();
    final AuthenticationService authService = AuthenticationService();
    await FS.create.one(
      Workout(
        id: workoutId,
        name: nameController.text.trim(),
        createdBy: authService.getCurrentUser()!.uid,
        isMyWorkout: true, createdOn: Timestamp.now()
      )
    );

    for (int i = 0 ; i < selectedExercises.length ;i++){
      final draftExercise = selectedExercises[i];

      await FS.create.one(
        WorkoutExercises(
            id: Firestorm.randomID(),
            workoutId: workoutId,
            exerciseId: draftExercise.exercise.id,
            order: i + 1,
            sets: draftExercise.sets,
            repetitions: draftExercise.reps,
            restBetweenSets: draftExercise.rest,
            duration: draftExercise.duration,
            distance: draftExercise.distance,)
      );
    }
    Navigator.pop(context,true);
  }

  //add exercise
  Future<void> addExerciseFlow() async {
    if(selectedExercises.length >= 50){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can add up to 50 exercises'))
      );
      return;
    }

    final Exercise? exercise = await Navigator.push(
      context, MaterialPageRoute(builder: (_) => const SelectExerciseScreen())
    );

    if(exercise == null) return;

    final exerciseType = await FS.get.one<ExerciseType>(exercise.exerciseTypeId);

    if(exerciseType == null) return;

    final draft = WorkoutExerciseInstance(exercise: exercise, exerciseTypeName: exerciseType.name);

    final alteredExercise = await showExerciseAlterDialog(draft);

    if(alteredExercise != null){
      setState(() {
        selectedExercises.add(alteredExercise);
      });
    }
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
        return AlertDialog( //TODO - This dialog seems to be reused throughout your app. I suggest you create a separate widget for it, it will make the code cleaner and more maintainable
          title: Text('Alter ${instance.exercise.name}'),
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

  void applyValuesToInstance(WorkoutExerciseInstance instance, String type,
      TextEditingController sets, TextEditingController reps,
      TextEditingController rest, TextEditingController duration,
      TextEditingController distance,
      ) {
    if(type == 'STRENGTH'){
      instance.sets = int.tryParse(sets.text);
      instance.rest = int.tryParse(reps.text);
      instance.rest = int.tryParse(rest.text);
    }
    if(type == 'CARDIO' || type == 'PLYOMETRICS'){
      instance.sets = int.tryParse(sets.text);
      instance.duration = int.tryParse(duration.text);
      instance.rest = int.tryParse(rest.text);
    }
    if(type == 'AEROBIC' ){
      instance.distance = double.tryParse(distance.text);
    }
    if(type == 'STRETCHING' ){
      instance.duration = int.tryParse(duration.text);
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

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: const Text('Create Workout')),
      floatingActionButton: FloatingActionButton(
        foregroundColor: Colors.black,
        backgroundColor: Colors.amberAccent,
          onPressed: addExerciseFlow,
          child: const Icon (Icons.add)),
      body: SafeArea(
        child: Padding(
          padding:const EdgeInsets.all(16),
          child: Column(
            children: [
              Form(
                key: formKey,
                child: TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Workout name'),
                  validator: (value) => value == null || value.isEmpty ? 'Enter workout name' : null,
                ),
              ),
              const SizedBox(height: 20),

              Expanded(child: ReorderableListView(
                  onReorder: (oldIndex, newIndex){
                    if(newIndex > oldIndex) newIndex--;
                    final item = selectedExercises.removeAt(oldIndex);
                    selectedExercises.insert(newIndex, item);
                    setState((){});
                  },
              children: [
                for (int i = 0; i < selectedExercises.length ; i++)
                  Card(
                    key: ValueKey(selectedExercises[i].exercise.id),
                    child: ListTile(
                      title: Text(selectedExercises[i].exercise.name),
                      subtitle: Text(buildSummary(selectedExercises[i])),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                              onPressed: () async {
                                final updated = await showExerciseAlterDialog(selectedExercises[i]);
                                if(updated != null) {
                                  setState(() {});
                                }
                              },
                              icon: const Icon (Icons.edit,color: Colors.blue)),
                          IconButton(onPressed: () async {
                            final confirm = await showDialog<bool>(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.circular(16)),
                                  title: const Row(children: [
                                    Icon(Icons.warning_amber_rounded,color: Colors.red),
                                    SizedBox(width: 8),Text('Remove Exercise'),
                                  ],),
                                  content: Text('Are you sure you want to remove ${selectedExercises[i].exercise.name}?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context),
                                        child: Text('Cancel')),
                                    ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                        onPressed: () => Navigator.pop(context,true), child: Text('Remove',style: TextStyle(color: Colors.white)))

                                  ],
                                )
                            );
                            if(confirm != true) return;
                            setState(() {
                              selectedExercises.removeAt(i);
                            });
                          }, icon: const Icon (Icons.delete,color: Colors.red))
                        ],
                      ),
                    ),
                  )
              ],)),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green,
                ), onPressed: saveWorkout, child: const Text('Save Workout',
                  style: TextStyle(fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,color: Colors.white)),),
            )
            ],
          )
        ),
      ),

    );
  }
}