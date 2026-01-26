import 'package:firestorm/firestorm.dart';
import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/models/workout.dart';
import 'package:me_fit/models/workoutExercises.dart';
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

  String? selectedCategory;
  String? selectedBodyPart;
  String? selectedExerciseId;

  final List<WorkoutExercises> addedExercises = [];

  List<Exercise> allExercises = [];
  @override
  void initState(){
    super.initState();
    fetchExercises();
  }

  Future<void> fetchExercises() async{
    final result = await FS.list.filter<Exercise>(Exercise)
        .whereIn('userId', ['system'])
        .fetch();
    setState(() => allExercises = result.items);
  }

  List<Exercise> get filteredExercises {
    return allExercises.where((e) {
      if(selectedCategory != null && e.category != selectedCategory){
        return false;
      }
      if(selectedBodyPart != null && e.bodyPart != selectedBodyPart){
        return false;
      }
      return true;
    }).toList();
  }

  void addExercise() {
    if(selectedExerciseId == null || addedExercises.length >= 3) return;

    addedExercises.add(
      WorkoutExercises(
          id: Firestorm.randomID(),
          workoutId: 'temp',
          exerciseId: selectedExerciseId!,
          order: addedExercises.length + 1,
          sets: 3,
          repetitions: 10,
          restBetweenSets: 60,
      ),
    );
  }

  void nextStep() {
    if(currentStep == 0 && workoutNameController.text.isEmpty) return;
    if(currentStep == 1 && addedExercises.isEmpty) return;
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
    if(workoutNameController.text.isEmpty || addedExercises.isEmpty) return;

    final user = authenticationService.getCurrentUser();
    final workoutId = Firestorm.randomID();
    if(user == null) return;
    final workout = Workout(
      id: workoutId,
      name: workoutNameController.text.trim(),
      createdBy: user.uid,
    );

    await FS.create.one(workout);

    for(final we in addedExercises){
      final workoutExercise = WorkoutExercises(
          id: Firestorm.randomID(),
          workoutId: workoutId,
          exerciseId: we.exerciseId,
          order: we.order,
          sets: we.sets,
          repetitions: we.repetitions,
          restBetweenSets: we.restBetweenSets,
          duration: we.duration,
          distance: we.distance,
      );

      await FS.create.one(workoutExercise);

      if(!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workout created succesfully')),
      );

      setState(() {
        currentStep = 0;
        workoutNameController.clear();
        addedExercises.clear();
        selectedCategory = null;
        selectedBodyPart = null;
        selectedExerciseId = null;
      });
    }
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
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Category'),
            value: selectedCategory,
            items: Exercise.categories
              .map((c) => DropdownMenuItem(
                value: c,
                child: Text(c)))
              .toList(),
            onChanged: (value){
              setState(() {
                selectedCategory = value;
                selectedExerciseId = null;
              });
            }
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Body Part'),
            value: selectedBodyPart,
            items: Exercise.bodyParts
            .map((b) => DropdownMenuItem(
                value: b,
                child: Text(b)))
            .toList(),
            onChanged: (value){
              setState(() {
                selectedBodyPart = value;
                selectedExerciseId = null;
              });
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Exercise'),
            value: selectedExerciseId,
            items: filteredExercises
              .map((e) => DropdownMenuItem(
                value: e.id,
                child: Text(e.name)))
            .toList(),
            onChanged: (value){
              setState(() {
                selectedExerciseId = value;
              });
          },
          ),
          const SizedBox(height: 10),
          ElevatedButton(
              onPressed: addExercise,
              child: const Text('Add Exercise'),
          ),
          const SizedBox(height: 10),
          ...addedExercises.map((we) => ListTile(
            title: Text(
              allExercises
              .firstWhere((e) => e.id == we.exerciseId)
              .name,
            ),
            subtitle: Text('Sets: ${we.sets}, Reps: ${we.repetitions}'),
          ),
          ),
        ],
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
          ...addedExercises.map(
              (we) => Text (
                '- ${allExercises.firstWhere((e) => e.id == we.exerciseId).name}',
              ),
          ),
        ],
      )
    );
  }
}