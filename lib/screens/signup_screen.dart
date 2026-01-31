import 'package:flutter/material.dart';
import 'package:firestorm/fs/fs.dart';
import 'package:me_fit/models/exercise.dart';
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

      final id = registerUser.user!.uid;

      User user = User(
        id,
        emailController.text.trim(),
        nameController.text.trim(),
        int.parse(ageController.text),
        fitnessLevel,
      );

      FS.create.one(user).then((_) {
        print("User created!");
      })
      .onError((e, st) {
        print("Error $e");
      });

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


