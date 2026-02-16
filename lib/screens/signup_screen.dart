

import 'package:firestorm/firestorm.dart';
import 'package:flutter/material.dart';
import 'package:firestorm/fs/fs.dart';
import 'package:me_fit/models/bodyPart.dart';
import 'package:me_fit/models/exercise.dart';
import 'package:me_fit/models/scheduled_workout.dart';
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

  String? trainingType;
  bool hasAccessToGym = false;
  int? preferredWorkoutsPerWeek;
  String? aerobicType;
  double? aerobicDistance;
  final aerobicDistanceController = TextEditingController();

  final AuthenticationService authService = AuthenticationService();

  Future<void> signup() async {
    try {
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
          id: id,
          emailAddress: emailController.text.trim(),
          username: nameController.text.trim(),
          age: age,
          trainingType: trainingType!,
          hasAccessToGym: hasAccessToGym!,
          preferredWorkoutsPerWeek: preferredWorkoutsPerWeek!,
          aerobicType: aerobicType,
          aerobicDistance: aerobicDistance
      );

      await FS.create.one(user).then((_) {
        print("User created!");
      })
          .onError((e, st) {
        print("Error $e");
      });

      await assignStarterWorkouts(user.id);

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    }
    catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> assignStarterWorkouts(String userId) async {
    final allExercises = await FS.list.allOfClass<Exercise>(Exercise);

    if (allExercises.isEmpty) return;
    List<Workout> starterWorkouts = [];
    if(trainingType == 'Strength') {
      List<BodyPart> bodyParts = await FS.list.allOfClass<BodyPart>(BodyPart);
      final Map<String, String> bodyPartNameToId = {
        for (final bp in bodyParts) bp.name : bp.id
      };
      List<List<String>> workoutPlanBodyParts = [];
      if(preferredWorkoutsPerWeek == 2){
        workoutPlanBodyParts = [
        ['CHEST', 'CHEST', 'BACK','BACK','BICEPS','BICEPS','TRICEPS', 'SHOULDERS', "FULL BODY"],
        ['THIGHS', 'THIGHS', 'HAMSTRINGS','QUADRICEPS','QUADRICEPS','HIPS','HIPS','CALVES', "FULL BODY"],
      ];
      }else if(preferredWorkoutsPerWeek == 3){
          workoutPlanBodyParts = [
          ['CHEST','CHEST','TRICEPS','TRICEPS','SHOULDERS','SHOULDERS','FULL BODY'],
          ['BACK','BACK','BACK','BACK','BICEPS','BICEPS','FULL BODY'],
          ['THIGHS','THIGHS','HAMSTRINGS','QUADRICEPS','HIPS','WAIST','CALVES','FULL BODY']
        ];
      }else if(preferredWorkoutsPerWeek == 4){
        workoutPlanBodyParts = [
          ['CHEST','CHEST','TRICEPS','TRICEPS','SHOULDERS','SHOULDERS','FULL BODY'],
          ['BACK','BACK','BACK','BACK','BICEPS','BICEPS','FULL BODY'],
          ['THIGHS','THIGHS','HAMSTRINGS','QUADRICEPS','HIPS','WAIST','CALVES','FULL BODY'],
          ['CHEST','TRICEPS','SHOULDERS','UPPER ARMS','QUADRICEPS','HIPS','THIGHS','CALVES','FULL BODY']
        ];
      }
      for(int i =0; i < workoutPlanBodyParts.length; i++){
        final workout = Workout(
            id: Firestorm.randomID(),
            name: 'Workout ${i + 1}',
            createdBy: userId,
            isMyWorkout: false);

        await FS.create.one(workout);
        for (int j = 0; j < workoutPlanBodyParts[i].length; j++) {
          final isLastExercise = j == workoutPlanBodyParts[i].length - 1;

          final exercisesForType = allExercises.where((e) {
            final equipmentMatch = hasAccessToGym! ||
                e.equipmentId == '20260129-1024-8a43-b037-3d29faa316f7';

            if (isLastExercise){
              return e.exerciseTypeId ==
                  '20260129-1023-8223-a819-4e81b08f7f14' && //stretching
                  equipmentMatch;
             }
            final bodyPartId = bodyPartNameToId[workoutPlanBodyParts[i][j]];
            final bodyPartMatch = e.bodyParts.contains(bodyPartId);


            return bodyPartMatch && equipmentMatch &&
                e.exerciseTypeId ==
                    '20260129-1023-8922-8643-a9a2984d73d5'; //strength
          }).toList();




          if(exercisesForType.isEmpty) continue;

          final exercise = (exercisesForType..shuffle()).first;

          final we = WorkoutExercises(
              id: Firestorm.randomID(),
              workoutId: workout.id,
              exerciseId: exercise.id,
              order: j + 1,
              sets: isLastExercise ? null : 3,
              repetitions: isLastExercise ? null : 12,
              restBetweenSets: isLastExercise ? null : 5,
              duration: isLastExercise ? 5 : null,
          );
          await FS.create.one(we);
        }
        starterWorkouts.add(workout);
      }

      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      List<int> scheduleDays;
      if(preferredWorkoutsPerWeek == 2){
        scheduleDays = [0,3];
      }else if(preferredWorkoutsPerWeek == 3){
        scheduleDays = [0,2,4];
      }else{
        scheduleDays = [0,1,3,5];
      }
      for (int i = 0; i < starterWorkouts.length; i++) {
        final scheduledDate = monday.add(Duration(days: scheduleDays[i]));
        final scheduledWorkout = ScheduledWorkout(
            id: Firestorm.randomID(),
            userId: userId,
            workoutId: starterWorkouts[i].id,
            scheduledDate: scheduledDate,
            isCompleted: false);
        await FS.create.one(scheduledWorkout);
      }
    }
    if(trainingType == 'Cardio') {
      List<List<String>> workoutPlanExerciseTypes = [];
      if(preferredWorkoutsPerWeek == 2){
        workoutPlanExerciseTypes = [
          ['CARDIO', 'CARDIO' 'CARDIO','CARDIO','CARDIO','CARDIO', "STRETCHING"],
          ['PLYOMETRICS', 'PLYOMETRICS' 'PLYOMETRICS','PLYOMETRICS','PLYOMETRICS','PLYOMETRICS','PLYOMETRICS','PLYOMETRICS', "STRETCHING"],
        ];
      }else if(preferredWorkoutsPerWeek == 3){
        workoutPlanExerciseTypes = [
          ['CARDIO','CARDIO','CARDIO','CARDIO','CARDIO','CARDIO', "STRETCHING"],
          ['PLYOMETRICS', 'PLYOMETRICS', 'PLYOMETRICS','PLYOMETRICS','PLYOMETRICS','PLYOMETRICS','PLYOMETRICS','PLYOMETRICS', "STRETCHING"],
          ['CARDIO', 'CARDIO', 'CARDIO','CARDIO','PLYOMETRICS','PLYOMETRICS','PLYOMETRICS','PLYOMETRICS', "STRETCHING"],
        ];
      }else if(preferredWorkoutsPerWeek == 4){
        workoutPlanExerciseTypes = [
          ['CARDIO','CARDIO','CARDIO','CARDIO','CARDIO','CARDIO', "STRETCHING"],
          ['CARDIO', 'CARDIO', 'CARDIO','CARDIO','PLYOMETRICS','PLYOMETRICS','PLYOMETRICS','PLYOMETRICS', "STRETCHING"],
          ['PLYOMETRICS', 'PLYOMETRICS', 'PLYOMETRICS','PLYOMETRICS','PLYOMETRICS','PLYOMETRICS', "STRETCHING"],
          ['CARDIO', 'CARDIO', 'CARDIO','CARDIO','PLYOMETRICS','PLYOMETRICS','PLYOMETRICS','PLYOMETRICS', "STRETCHING"],
        ];
      }
      for(int i =0; i < workoutPlanExerciseTypes.length; i++) {
        final workout = Workout(
            id: Firestorm.randomID(),
            name: 'Workout ${i + 1}',
            createdBy: userId,
            isMyWorkout: false);

        await FS.create.one(workout);

        for (int j = 0; j < workoutPlanExerciseTypes[i].length; j++){
          final type = workoutPlanExerciseTypes[i][j];

          String exerciseTypeId ;
          if(type == 'CARDIO'){
            exerciseTypeId = '20260129-1023-8c23-9480-a118b95f118c';
          } else if (type == 'PLYOMETRICS'){
            exerciseTypeId = '20260129-1023-8923-b650-e37111665694';
          } else{
            exerciseTypeId = '20260129-1023-8223-a819-4e81b08f7f14';
          }

          final exerciseForType = allExercises.where((e) {
            final typeMatch = e.exerciseTypeId == exerciseTypeId;
            final equipmentMatch = hasAccessToGym! || e.equipmentId == '20260129-1024-8a43-b037-3d29faa316f7';
            return typeMatch && equipmentMatch;
          }).toList();

          if(exerciseForType.isEmpty) continue;

          final exercise = (exerciseForType..shuffle()).first;
          WorkoutExercises we;

          if(type == 'CARDIO'){
            we = WorkoutExercises(
                id: Firestorm.randomID(),
                workoutId: workout.id,
                exerciseId: exercise.id,
                order: j+1,
                sets: 1,
                duration: 5,
                restBetweenSets: 5);
          }else if (type == 'PLYOMETRICS'){
            we = WorkoutExercises(
                id: Firestorm.randomID(),
                workoutId: workout.id,
                exerciseId: exercise.id,
                order: j + 1,
                sets: 2,
                duration: 5,
                restBetweenSets: 5);
          }else{
            we = WorkoutExercises(
                id: Firestorm.randomID(),
                workoutId: workout.id,
                exerciseId: exercise.id,
                order: j + 1,
                duration: 5);
          }
          await FS.create.one(we);
        }
        starterWorkouts.add(workout);
      }
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      List<int> scheduleDays;
      if(preferredWorkoutsPerWeek == 2){
        scheduleDays = [0,3];
      }else if(preferredWorkoutsPerWeek == 3){
        scheduleDays = [0,2,4];
      }else{
        scheduleDays = [0,1,3,5];
      }
      for (int i = 0; i < starterWorkouts.length; i++) {
        final scheduledDate = monday.add(Duration(days: scheduleDays[i]));
        final scheduledWorkout = ScheduledWorkout(
            id: Firestorm.randomID(),
            userId: userId,
            workoutId: starterWorkouts[i].id,
            scheduledDate: scheduledDate,
            isCompleted: false);
        await FS.create.one(scheduledWorkout);
      }
    }
    if(trainingType == 'Aerobic'){
      const aerobicExerciseTypeId = '20260129-1023-8024-a295-ced66eef7c9c';

      List<double> distanceSplits;
      if(preferredWorkoutsPerWeek == 2){
        distanceSplits = [0.4,0.6];
      }else if (preferredWorkoutsPerWeek == 3){
        distanceSplits = [0.25,0.30,0.45];
      }else{
        distanceSplits = [0.2,0.25,0.25,0.30];
      }

      for (int i =0 ; i< distanceSplits.length; i++){
        final workout = Workout(
            id: Firestorm.randomID(),
            name: 'Workout ${i + 1}',
            createdBy: userId,
            isMyWorkout: false);

        await FS.create.one(workout);
        starterWorkouts.add(workout);

        final workoutDistance = aerobicDistance! * distanceSplits[i];

        final matchingExercises = allExercises.where((e) {
          final typeMatch = e.exerciseTypeId == aerobicExerciseTypeId;
          final aerobicTypeMatch = e.name == aerobicType!;
          return typeMatch && aerobicTypeMatch;
        }).toList();

        if(matchingExercises.isEmpty) continue;
        final exercise = (matchingExercises..shuffle()).first;

        final we = WorkoutExercises(
            id: Firestorm.randomID(),
            workoutId: workout.id,
            exerciseId: exercise.id,
            order: 1,
            distance: workoutDistance);
        await FS.create.one(we);
      }

      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      List<int> scheduleDays;
      if(preferredWorkoutsPerWeek == 2){
        scheduleDays = [0,3];
      }else if(preferredWorkoutsPerWeek == 3){
        scheduleDays = [0,2,4];
      }else{
        scheduleDays = [0,1,3,5];
      }
      for (int i = 0; i < starterWorkouts.length; i++) {
        final scheduledDate = monday.add(Duration(days: scheduleDays[i]));
        final scheduledWorkout = ScheduledWorkout(
            id: Firestorm.randomID(),
            userId: userId,
            workoutId: starterWorkouts[i].id,
            scheduledDate: scheduledDate,
            isCompleted: false);
        await FS.create.one(scheduledWorkout);
      }

    }
  }

  Future<void> preLoadExercises() async {
    final result = await FS.list.allOfClass<Exercise>(Exercise);
    debugPrint('Success}');
  }

  void nextStep() {
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
      case 2:
        if (trainingType == null || preferredWorkoutsPerWeek == null ||
            hasAccessToGym == null) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Please complete all training preferences'))
          );
          return;
        }
        if (trainingType == 'Aerobic'){
          if(aerobicType == null){
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please select an aerobic type'))
          );
          return;
        }
        final distance = double.tryParse(aerobicDistanceController.text.trim());
        if (distance == null || distance <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(
                'Please enter a valid distance for your aerobic workout')),
          );
          return;
        }
        bool validDistance = false;
        switch (aerobicType) {
          case 'Running':
            validDistance = distance >= 5 && distance <= 80;
            break;
          case 'Cycling':
            validDistance = distance >= 20 && distance <= 300;
            break;
          case 'Swimming':
            validDistance = distance >= 1 && distance <= 15;
            break;
        }
        if (!validDistance) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(
                  'Distance for $aerobicType must within a normal range'))
          );
          return;
        }
        aerobicDistance = distance;
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
              title: const Text('Training Setup'),
              content: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: trainingType,
                    decoration: const InputDecoration(labelText: 'Training Type'),
                    items:
                      const [
                        DropdownMenuItem(value: 'Strength',child: const Text('Strength')),
                        DropdownMenuItem(value: 'Cardio',child: const Text('Cardio')),
                        DropdownMenuItem(value: 'Aerobic',child: const Text('Aerobic')),
                      ],
                    onChanged: (v) => setState(() => trainingType = v!),
                  ),
                  CheckboxListTile(
                      value: hasAccessToGym ?? false,
                      title: const Text('I have access to a gym'),
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) => setState(() => hasAccessToGym = v ?? false)),
                  DropdownButtonFormField<int>(
                    value: preferredWorkoutsPerWeek,
                    decoration: const InputDecoration(labelText: 'Workouts per Week'),
                    items: const [
                      DropdownMenuItem(value: 2,child: Text('2 days')),
                      DropdownMenuItem(value: 3,child: Text('3 days')),
                      DropdownMenuItem(value: 4,child: Text('4 days')),
                    ],
                    onChanged: (v) => setState(() => preferredWorkoutsPerWeek = v!),
                  ),
                  if(trainingType == 'Aerobic')...[
                  DropdownButtonFormField(
                      value: aerobicType,
                      decoration: const InputDecoration(labelText: 'Aerobic type'),
                      items: const [
                        DropdownMenuItem(value: 'Running',child: Text('Running')),
                        DropdownMenuItem(value: 'Cycling',child: Text('Cycling')),
                        DropdownMenuItem(value: 'Swimming',child: Text('Swimming')),
                      ],
                      onChanged: (v) => setState(() => aerobicType = v),
                  ),
                    TextField(
                      controller: aerobicDistanceController,
                      decoration: const InputDecoration(labelText: 'Weekly Distance (km)'),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                    )
                  ],
                ],
              ))
        ],
      ),
    );

  }
}


