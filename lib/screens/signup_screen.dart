import 'package:firestorm/firestorm.dart';
import 'package:flutter/material.dart';
import 'package:firestorm/fs/fs.dart';
import 'package:me_fit/models/exercise.dart';
import 'package:me_fit/models/scheduledWorkout.dart';
import 'package:me_fit/models/workout.dart';
import 'package:me_fit/models/workoutExercises.dart';
import '../models/user.dart';
import '../services/authentication_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => SignupScreenState();
}

class SignupScreenState extends State<SignupScreen> {
  int currentStep = 0;
  bool isLoading = false;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  final ageController = TextEditingController();

  String fitnessLevel = 'Beginner';

  final AuthenticationService authService = AuthenticationService();

  Future<void> signup() async {
    try{
      setState(() => isLoading = true);
      final registerUser = await authService.registerUser(
          email: emailController.text.trim(),
          password: passwordController.text.trim()
      );

      final firebaseUser = registerUser.user;
      if (firebaseUser == null) {
        throw Exception('User registration failed. Please try again.');
      }

      final id = firebaseUser.uid;
      final age = int.tryParse(ageController.text.trim());
      if (age == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid age')),
        );
        return;
      }
      User user = User(
        id,
        emailController.text.trim(),
        nameController.text.trim(),
        age,
        fitnessLevel,
      );

      await FS.create.one(user).then((_) {
        print("User created!");
      })
      .onError((e, st) {
        print("Error $e");
      });

      await assignStarterWorkouts(user.id);

      if(!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    }
    catch (e){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      setState (() => isLoading = false);
    }
  }
  Future<void> assignStarterWorkouts(String userId) async{
    final allExercises = await FS.list.allOfClass<Exercise>(Exercise);

    if(allExercises.isEmpty) return;
    List<Workout> starterWorkouts = [];

    for(int i = 0; i < 3;i++){
      final workout = Workout(
          id: Firestorm.randomID(),
          name: 'Workout ${i+1}',
          createdBy: userId);
      await FS.create.one(workout);

      final exercisesForWorkout = (allExercises..shuffle()).take(3).toList();
      for (int j = 0; j < exercisesForWorkout.length; j++){
        final we = WorkoutExercises(
            id: Firestorm.randomID(),
            workoutId: workout.id,
            exerciseId: exercisesForWorkout[j].id,
            order: j+1);
        await FS.create.one(we);
      }
      starterWorkouts.add(workout);
    }
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday-1));
    final scheduleDays = [0,2,4];
    for(int i = 0; i < starterWorkouts.length; i++) {
      final scheduledDate = monday.add(Duration(days: scheduleDays[i]));
      final scheduledWorkout = ScheduledWorkout(
          id: Firestorm.randomID(),
          userId: userId,
          workoutId: starterWorkouts[i].id,
          scheduledDate: scheduledDate);
      await FS.create.one(scheduledWorkout);
    }
  }
  Future<void> preLoadExercises() async{
    final result = await  FS.list.allOfClass<Exercise>(Exercise);
    debugPrint('Success}');
  }
  void nextStep(){
    switch (currentStep) {
      case 0: //Account
        if (emailController.text
            .trim()
            .isEmpty || passwordController.text
            .trim()
            .isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text(
                  'Please fill up both email and password fields'))
          );
          return;
        }
        setState(() => currentStep++);
        break;
      case 1: //Profile
        if (nameController.text
            .trim()
            .isEmpty || ageController.text
            .trim()
            .isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text(
                  'Please fill up both age and name fields'))
          );
          return;
        }
        setState(() => currentStep++);
        break;
      case 2: //Fitness
        if (fitnessLevel.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text(
                  'Please select a fitness level'))
          );
          return;
        }
        signup();
        break;
    }
  }

  void previousStep(){
    if(currentStep > 0){
      setState(() =>currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: Stepper(
        currentStep: currentStep,
        onStepContinue: isLoading ? null : nextStep,
        onStepCancel: previousStep,
        controlsBuilder: (context,details){
          return Row (
            children: [
              ElevatedButton(
                  onPressed: details.onStepContinue,
                  child: isLoading
              ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)
                  )
              : Text(currentStep == 2 ? 'Finish' : 'Next'),
              ),
              if(currentStep > 0)
                TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Back'),
                ),
            ],
          );
        },
        steps: [
          Step(
              title: const Text('Account'),
              content: Column(
                children: [
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                  )
                ],
              ),
          ),
          Step(
              title: const Text('Profile'),
              content: Column (
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  TextField(
                    controller: ageController,
                    decoration: const InputDecoration(labelText: 'Age'),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
          ),
          Step(
            title: const Text('Fitness'),
            content: DropdownButtonFormField<String>(
              initialValue: fitnessLevel,
              decoration: const InputDecoration(labelText: 'Fitness Level'),
              items: const [
                DropdownMenuItem(
                    value: 'Beginner',
                    child: Text('Beginner')),
                DropdownMenuItem(
                    value: 'Intermediate',
                    child: Text('Intermediate')),
                DropdownMenuItem(
                    value: 'Advanced',
                    child: Text('Advanced')),
              ],
              onChanged: (value) => setState(() => fitnessLevel = value!),
            ),
          ),
        ],
      ),
    );

  }
}


