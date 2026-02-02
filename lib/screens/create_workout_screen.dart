import 'package:firestorm/firestorm.dart';
import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/models/workout.dart';
import 'package:me_fit/models/workoutExercises.dart';
import 'package:me_fit/screens/select_exercise_screen.dart';
import 'package:me_fit/services/authentication_service.dart';

import '../models/exercise.dart';

class CreateWorkoutScreen extends StatefulWidget{
  const CreateWorkoutScreen({super.key});

  @override
  State<CreateWorkoutScreen> createState() => CreateWorkoutScreenState();
}

class CreateWorkoutScreenState extends State<CreateWorkoutScreen>{
  final AuthenticationService authenticationService = AuthenticationService();

  int currentStep = 0;
  final workoutNameController = TextEditingController();

  final List<Exercise> selectedExercises = [];



  void nextStep() {
    if(currentStep == 0 && workoutNameController.text.isEmpty) return;
    if(currentStep == 1 && selectedExercises.isEmpty) return;
    if(currentStep < 2){
      setState(() =>currentStep++);
    }else{
      saveWorkout();
    }
  }

  void previousStep() {
    if(currentStep > 0){
      setState(() => currentStep--);
    }
  }
  Future<void> saveWorkout() async{
    if(workoutNameController.text.isEmpty || selectedExercises.isEmpty) return;

    final user = authenticationService.getCurrentUser();

    if(user == null) return;
    final workoutId = Firestorm.randomID();
    final workout = Workout(
      id: workoutId,
      name: workoutNameController.text.trim(),
      createdBy: user.uid,
      isMyWorkout: true
    );

    await FS.create.one(workout);

    for(int i =0;i < selectedExercises.length;i++) {
      final exercise = selectedExercises[i];
      await FS.create.one(
        WorkoutExercises(
            id: Firestorm.randomID(),
            workoutId: workoutId,
            exerciseId: exercise.id,
            order: i+1,
            repetitions: 10,
            sets: 3,
            restBetweenSets: 60,
        ),
      );
    }
      if(!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workout created succesfully')),
      );

      setState(() {
        currentStep = 0;
        workoutNameController.clear();
        selectedExercises.clear();
      });

      Navigator.pop(context,true);

  }

  @override
  Widget build (BuildContext context){
    return Scaffold(
      appBar: AppBar(title: const Text('Create Workout')),
      body: Stepper(
        currentStep: currentStep,
        onStepContinue: nextStep,
        onStepCancel: previousStep,
        steps: [
          workoutInfoStep(),
          addExercisesStep(),
          reviewStep(),
        ],
      ),
    );
  }
  Step workoutInfoStep(){
    return Step (
      title: const Text('Workout Info'),
      isActive: currentStep >= 0,
      content: TextField(
        controller: workoutNameController,
        decoration: const InputDecoration(
          labelText: 'Workout Name',
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
  Step addExercisesStep() {
    return Step(
      title: const Text('Add Exercises (max 3)'),
      isActive: currentStep >= 1,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Exercise'),
              onPressed: selectedExercises.length >= 3
                ? null
                : ()async {
                final Exercise? exercise = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SelectExerciseScreen(),
                ),
                );
                if(exercise != null && !selectedExercises.any((e)=> e.id == exercise.id)){
                  setState(() {
                    selectedExercises.add(exercise);
                  });
                }
              },
            ),
          const SizedBox(height: 12),
          if(selectedExercises.isNotEmpty)
            SizedBox(
              height: 220,
              child: ReorderableListView(
                  children: [
                    for (int i =0; i < selectedExercises.length;i++)
                      ListTile(
                        key: ValueKey(selectedExercises[i].id),
                        leading: const Icon(Icons.drag_handle),
                        title: Text(selectedExercises[i].name),
                        subtitle: const Text('Sets: 3, Reps: 10'),
                        trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: (){
                              setState(() {
                                selectedExercises.removeAt(i);
                              });
                            },
                        ),

                      )
                  ],
                  onReorder: (oldIndex, newIndex){
                    setState(() {
                      if(newIndex >oldIndex){
                        newIndex -= 1;
                      }
                      final item = selectedExercises.removeAt(oldIndex);
                      selectedExercises.insert(newIndex, item);
                    });
                  },
              ),
            )
        ]
      ),
    );
  }
  Step reviewStep() {
    return Step (
      title: const Text ('Review'),
      isActive: currentStep >= 2,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Workout: ${workoutNameController.text}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ...selectedExercises.map(
              (e) => Text (
                '- ${e.name}',
              ),
          ),
        ],
      )
    );
  }
}