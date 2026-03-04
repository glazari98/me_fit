import 'package:cloud_firestore/cloud_firestore.dart';
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

  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  final ageController = TextEditingController();
  final weightController = TextEditingController();
  final heightController = TextEditingController();

  String? trainingType = 'Strength';
  String? trainingGoal = 'Muscle Building';
  bool hasAccessToGym = false;
  int? preferredWorkoutsPerWeek;
  String? aerobicType;
  double? aerobicDistance;
  final aerobicDistanceController = TextEditingController();

  bool obscurePassword = true;

  final AuthenticationService authService = AuthenticationService();

  Future<void> signup() async {
    try {
      setState(() => isLoading = true);
      final registerUser = await authService.registerUser(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
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
        weight: double.parse(weightController.text.trim()),
        height: int.parse(heightController.text.trim()),
        trainingType: trainingType!,
        trainingGoal: trainingGoal!,
        hasAccessToGym: hasAccessToGym!,
        preferredWorkoutsPerWeek: preferredWorkoutsPerWeek!,
        aerobicType: aerobicType,
        aerobicDistance: aerobicDistance,
        currentStreak: 0,
        bestStreak: 0,
        totalCompletedWorkouts: 0,
        unlockedBadges: [],
      );

      await FS.create.one(user);
      await assignStarterWorkouts(user.id);

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }
  Future<void> scheduleWorkoutsForCurrentWeek({required String userId, required List<Workout> starterWorkouts,required int preferredWorkoutsPerWeek}) async {
    final now = DateTime.now();
    final currentDayOfWeek = now.weekday;
    final remainingDays = 7 - currentDayOfWeek + 1;

    int maxWorkoutsThisWeek;
    //adjust how many workouts can fit in the week according to how many days are remaining in the week
    if(remainingDays >= 6){
      maxWorkoutsThisWeek = preferredWorkoutsPerWeek;
    }else if(remainingDays == 5){
      maxWorkoutsThisWeek = preferredWorkoutsPerWeek > 4 ? 4 : preferredWorkoutsPerWeek;
    }else if(remainingDays == 4){
      maxWorkoutsThisWeek = preferredWorkoutsPerWeek > 3 ? 3 : preferredWorkoutsPerWeek;
    }else if(remainingDays == 3){
      maxWorkoutsThisWeek = preferredWorkoutsPerWeek > 2 ? 2 : preferredWorkoutsPerWeek;
    }else if(remainingDays == 2){
      maxWorkoutsThisWeek = preferredWorkoutsPerWeek > 1 ? 1 : preferredWorkoutsPerWeek;
    }else{
      maxWorkoutsThisWeek = 1;
    }
    //actual number of workouts happening this week
    final workoutsToSchedule = maxWorkoutsThisWeek;

    if (workoutsToSchedule > 0) {
      List<int> availableDays = []; //build list of available days form today until end of the week
      for (int i = currentDayOfWeek - 1; i < 7; i++) {
        availableDays.add(i);
      }
      List<int> scheduledDays = []; //list to add the workouts in available days
      if (workoutsToSchedule == 1) { //if only 1 workout add it on same day
        scheduledDays = [currentDayOfWeek - 1];
      } else { //for multiple workouts space them evenly
        double step = (availableDays.length - 1) / (workoutsToSchedule -1); //how many steps to move forward for every new workout
        for (int i = 0; i < workoutsToSchedule; i++) {
          int index = (i * step).round();
          scheduledDays.add(availableDays[index]);
        }
      }
      final monday = now.subtract(Duration(days: now.weekday - 1));
      for (int i = 0; i < workoutsToSchedule; i++) {
        final scheduledDate = monday.add(Duration(days: scheduledDays[i]));
        final scheduleDateToMidnight = DateTime(scheduledDate.year,scheduledDate.month,scheduledDate.day,0,0,0,0,0);
        final scheduledWorkout = ScheduledWorkout(
            id: Firestorm.randomID(),
            userId: userId,
            workoutId: starterWorkouts[i].id,
            originalWorkoutId: starterWorkouts[i].id,
            scheduledDate: Timestamp.fromDate(scheduleDateToMidnight),
            isCompleted: false);
        await FS.create.one(scheduledWorkout);
      }
    }
  }
  Future<void> assignStarterWorkouts(String userId) async {
    final allExercises = await FS.list.allOfClass<Exercise>(Exercise);
    if (allExercises.isEmpty) return;

    List<Workout> starterWorkouts = [];
    if (trainingType == 'Strength') {
      List<BodyPart> bodyParts = await FS.list.allOfClass<BodyPart>(BodyPart);
      final Map<String, String> bodyPartNameToId = {
        for (final bp in bodyParts) bp.name: bp.id
      };
      List<List<String>> workoutPlanBodyParts = [];
      if (preferredWorkoutsPerWeek == 1) {
        workoutPlanBodyParts = [
          [
            'CHEST',
            'TRICEPS',
            'SHOULDERS',
            'UPPER ARMS',
            'QUADRICEPS',
            'HIPS',
            'THIGHS',
            'CALVES',
            'FULL BODY'
          ]
        ];
      }
      else if (preferredWorkoutsPerWeek == 2) {
        workoutPlanBodyParts = [
          [
            'CHEST',
            'CHEST',
            'BACK',
            'BACK',
            'BICEPS',
            'BICEPS',
            'TRICEPS',
            'SHOULDERS',
            "FULL BODY"
          ],
          [
            'THIGHS',
            'THIGHS',
            'HAMSTRINGS',
            'QUADRICEPS',
            'QUADRICEPS',
            'HIPS',
            'HIPS',
            'CALVES',
            "FULL BODY"
          ],
        ];
      } else if (preferredWorkoutsPerWeek == 3) {
        workoutPlanBodyParts = [
          [
            'CHEST',
            'CHEST',
            'TRICEPS',
            'TRICEPS',
            'SHOULDERS',
            'SHOULDERS',
            'FULL BODY'
          ],
          ['BACK', 'BACK', 'BACK', 'BACK', 'BICEPS', 'BICEPS', 'FULL BODY'],
          [
            'THIGHS',
            'THIGHS',
            'HAMSTRINGS',
            'QUADRICEPS',
            'HIPS',
            'WAIST',
            'CALVES',
            'FULL BODY'
          ]
        ];
      } else if (preferredWorkoutsPerWeek == 4) {
        workoutPlanBodyParts = [
          [
            'CHEST',
            'CHEST',
            'TRICEPS',
            'TRICEPS',
            'SHOULDERS',
            'SHOULDERS',
            'FULL BODY'
          ],
          ['BACK', 'BACK', 'BACK', 'BACK', 'BICEPS', 'BICEPS', 'FULL BODY'],
          [
            'THIGHS',
            'THIGHS',
            'HAMSTRINGS',
            'QUADRICEPS',
            'HIPS',
            'WAIST',
            'CALVES',
            'FULL BODY'
          ],
          [
            'CHEST',
            'TRICEPS',
            'SHOULDERS',
            'UPPER ARMS',
            'QUADRICEPS',
            'HIPS',
            'THIGHS',
            'CALVES',
            'FULL BODY'
          ]
        ];
      }
      else if (preferredWorkoutsPerWeek == 5) {
        workoutPlanBodyParts = [
          [
            'CHEST',
            'CHEST',
            'TRICEPS',
            'TRICEPS',
            'SHOULDERS',
            'SHOULDERS',
            'FULL BODY'
          ],
          ['BACK', 'BACK', 'BACK', 'BACK', 'BICEPS', 'BICEPS', 'FULL BODY'],
          [
            'CHEST',
            'TRICEPS',
            'SHOULDERS',
            'UPPER ARMS',
            'QUADRICEPS',
            'HIPS',
            'THIGHS',
            'CALVES',
            'FULL BODY'
          ],
          [
            'THIGHS',
            'THIGHS',
            'HAMSTRINGS',
            'QUADRICEPS',
            'HIPS',
            'WAIST',
            'CALVES',
            'FULL BODY'
          ],
          [
            'CHEST',
            'TRICEPS',
            'SHOULDERS',
            'UPPER ARMS',
            'QUADRICEPS',
            'HIPS',
            'THIGHS',
            'CALVES',
            'FULL BODY'
          ]
        ];
      }
      for (int i = 0; i < workoutPlanBodyParts.length; i++) {
        final workout = Workout(
            id: Firestorm.randomID(),
            name: 'Workout ${i + 1}',
            createdBy: userId,
            isMyWorkout: false,
            createdOn: Timestamp.now());

        await FS.create.one(workout);
        for (int j = 0; j < workoutPlanBodyParts[i].length; j++) {
          final isLastExercise = j == workoutPlanBodyParts[i].length - 1;

          final exercisesForType = allExercises.where((e) {
            final equipmentMatch = hasAccessToGym! ||
                e.equipmentId == '20260129-1024-8a43-b037-3d29faa316f7';

            if (isLastExercise) {
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


          if (exercisesForType.isEmpty) continue;

          final exercise = (exercisesForType..shuffle()).first;
          //adjusting sets reps according to goal
          int? sets;
          int? reps;
          int? rest;
          if(trainingGoal == 'Muscle Building') {
            sets = 3;
            reps = 12;
            rest = 90;
          }else{ //power building (more sets/less reps)
            sets = 5;
            reps = 6;
            rest = 180;
          }
          final we = WorkoutExercises(
            id: Firestorm.randomID(),
            workoutId: workout.id,
            exerciseId: exercise.id,
            order: j + 1,
            sets: isLastExercise ? null : sets,
            repetitions: isLastExercise ? null : reps,
            restBetweenSets: isLastExercise ? null : rest,
            durationOfTimedSet: isLastExercise ? 300 : null,
          );
          await FS.create.one(we);
        }
        starterWorkouts.add(workout);
      }
      await scheduleWorkoutsForCurrentWeek(userId: userId,
          starterWorkouts: starterWorkouts,
          preferredWorkoutsPerWeek: preferredWorkoutsPerWeek!);
    }
    if (trainingType == 'Cardio') {
      List<List<String>> workoutPlanExerciseTypes = [];
      if (preferredWorkoutsPerWeek == 1) {
        workoutPlanExerciseTypes = [
          [
            'CARDIO',
            'CARDIO',
            'CARDIO',
            'CARDIO',
            'PLYOMETRICS',
            'PLYOMETRICS',
            'PLYOMETRICS',
            'PLYOMETRICS',
            "STRETCHING"
          ],
        ];
      }
      if (preferredWorkoutsPerWeek == 2) {
        workoutPlanExerciseTypes = [
          [
            'CARDIO',
            'CARDIO',
            'CARDIO',
            'CARDIO',
            'CARDIO',
            'CARDIO',
            "STRETCHING"
          ],
          [
            'PLYOMETRICS',
            'PLYOMETRICS',
            'PLYOMETRICS',
            'PLYOMETRICS',
            'PLYOMETRICS',
            'PLYOMETRICS',
            'PLYOMETRICS',
            'PLYOMETRICS',
            "STRETCHING"
          ],
        ];
      } else if (preferredWorkoutsPerWeek == 3) {
        workoutPlanExerciseTypes = [
          [
            'CARDIO',
            'CARDIO',
            'CARDIO',
            'CARDIO',
            'CARDIO',
            'CARDIO',
            "STRETCHING"
          ],
          [
            'PLYOMETRICS',
            'PLYOMETRICS',
            'PLYOMETRICS',
            'PLYOMETRICS',
            'PLYOMETRICS',
            'PLYOMETRICS',
            'PLYOMETRICS',
            'PLYOMETRICS',
            "STRETCHING"
          ],
          [
            'CARDIO',
            'CARDIO',
            'CARDIO',
            'CARDIO',
            'PLYOMETRICS',
            'PLYOMETRICS',
            'PLYOMETRICS',
            'PLYOMETRICS',
            "STRETCHING"
          ],
        ];
      } else if (preferredWorkoutsPerWeek == 4) {
        workoutPlanExerciseTypes = [
          [
            'CARDIO',
            'CARDIO',
            'CARDIO',
            'CARDIO',
            'CARDIO',
            'CARDIO',
            "STRETCHING"
          ],
          [
            'CARDIO',
            'CARDIO',
            'CARDIO',
            'CARDIO',
            'PLYOMETRICS',
            'PLYOMETRICS',
            'PLYOMETRICS',
            'PLYOMETRICS',
            "STRETCHING"
          ],
          [
            'PLYOMETRICS',
            'PLYOMETRICS',
            'PLYOMETRICS',
            'PLYOMETRICS',
            'PLYOMETRICS',
            'PLYOMETRICS',
            "STRETCHING"
          ],
          [
            'CARDIO',
            'CARDIO',
            'CARDIO',
            'CARDIO',
            'PLYOMETRICS',
            'PLYOMETRICS',
            'PLYOMETRICS',
            'PLYOMETRICS',
            "STRETCHING"
          ],
        ];
      } else if (preferredWorkoutsPerWeek == 5) {
        workoutPlanExerciseTypes = [
          [
            'CARDIO',
            'CARDIO',
            'CARDIO',
            'CARDIO',
            'CARDIO',
            'CARDIO',
            "STRETCHING"
          ],
          [
            'CARDIO',
            'CARDIO',
            'CARDIO',
            'CARDIO',
            'PLYOMETRICS',
            'PLYOMETRICS',
            'PLYOMETRICS',
            'PLYOMETRICS',
            "STRETCHING"
          ],
          [
            'CARDIO',
            'CARDIO',
            'CARDIO',
            'CARDIO',
            'PLYOMETRICS',
            'PLYOMETRICS',
            'PLYOMETRICS',
            'PLYOMETRICS',
            "STRETCHING"
          ],
          [
            'PLYOMETRICS',
            'PLYOMETRICS',
            'PLYOMETRICS',
            'PLYOMETRICS',
            'PLYOMETRICS',
            'PLYOMETRICS',
            "STRETCHING"
          ],
          [
            'CARDIO',
            'CARDIO',
            'CARDIO',
            'CARDIO',
            'PLYOMETRICS',
            'PLYOMETRICS',
            'PLYOMETRICS',
            'PLYOMETRICS',
            "STRETCHING"
          ],
        ];
      }

      for (int i = 0; i < workoutPlanExerciseTypes.length; i++) {
        final workout = Workout(
            id: Firestorm.randomID(),
            name: 'Workout ${i + 1}',
            createdBy: userId,
            isMyWorkout: false,
            createdOn: Timestamp.now());

        await FS.create.one(workout);

        for (int j = 0; j < workoutPlanExerciseTypes[i].length; j++) {
          final type = workoutPlanExerciseTypes[i][j];

          String exerciseTypeId;
          if (type == 'CARDIO') {
            exerciseTypeId = '20260129-1023-8c23-9480-a118b95f118c';
          } else if (type == 'PLYOMETRICS') {
            exerciseTypeId = '20260129-1023-8923-b650-e37111665694';
          } else {
            exerciseTypeId = '20260129-1023-8223-a819-4e81b08f7f14';
          }

          final exerciseForType = allExercises.where((e) {
            final typeMatch = e.exerciseTypeId == exerciseTypeId;
            final equipmentMatch = hasAccessToGym! ||
                e.equipmentId == '20260129-1024-8a43-b037-3d29faa316f7';
            return typeMatch && equipmentMatch;
          }).toList();

          if (exerciseForType.isEmpty) continue;

          final exercise = (exerciseForType..shuffle()).first;
          WorkoutExercises we;
          int workoutDuration = 2700; //45 mins
          //spread duration across all exercises
          int durationPerExercise = (workoutDuration / workoutPlanExerciseTypes.length -1).round(); //we don't count stretching
          int? sets;
          int? duration;
          int? rest;
          if(trainingGoal == 'Endurance'){
            sets = 1;
            duration = durationPerExercise;
            rest = 120;
          }else{ //fat loss (multiple sets, shorter intervals)
            sets = 5;
            duration = 60;
            rest = 60;
          }
          if(type == 'CARDIO') {
            we = WorkoutExercises(
                id: Firestorm.randomID(),
                workoutId: workout.id,
                exerciseId: exercise.id,
                order: j + 1,
                sets: sets,
                durationOfTimedSet: duration,
                restBetweenSets: rest);
          }else if (type == 'PLYOMETRICS') {
            we = WorkoutExercises(
                id: Firestorm.randomID(),
                workoutId: workout.id,
                exerciseId: exercise.id,
                order: j + 1,
                sets: sets,
                durationOfTimedSet: duration,
                restBetweenSets: rest);
          }else{
            we = WorkoutExercises(
                id: Firestorm.randomID(),
                workoutId: workout.id,
                exerciseId: exercise.id,
                order: j + 1,
                durationOfTimedSet: 300);
          }
          await FS.create.one(we);
        }
        starterWorkouts.add(workout);
      }
      await scheduleWorkoutsForCurrentWeek(userId: userId,
          starterWorkouts: starterWorkouts,
          preferredWorkoutsPerWeek: preferredWorkoutsPerWeek!);
    }if (trainingType == 'Aerobic') {
      const aerobicExerciseTypeId = '20260129-1023-8024-a295-ced66eef7c9c';

      List<double> distanceSplits;
      if (preferredWorkoutsPerWeek == 1) {
        distanceSplits = [1.0];
      } else if (preferredWorkoutsPerWeek == 2) {
        distanceSplits = [0.4, 0.6];
      } else if (preferredWorkoutsPerWeek == 3) {
        distanceSplits = [0.25, 0.30, 0.45];
      } else if (preferredWorkoutsPerWeek == 4) {
        distanceSplits = [0.25, 0.30, 0.45];
      } else {
        distanceSplits = [0.2, 0.15, 0.25, 0.25, 0.15];
      }

      for (int i = 0; i < distanceSplits.length; i++) {
        final workout = Workout(
            id: Firestorm.randomID(),
            name: 'Workout ${i + 1}',
            createdBy: userId,
            isMyWorkout: false,
            createdOn: Timestamp.now());

        await FS.create.one(workout);
        starterWorkouts.add(workout);

        final workoutDistance = aerobicDistance! * distanceSplits[i];

        final matchingExercises = allExercises.where((e) {
          final typeMatch = e.exerciseTypeId == aerobicExerciseTypeId;
          final aerobicTypeMatch = e.name == aerobicType!;
          return typeMatch && aerobicTypeMatch;
        }).toList();

        if (matchingExercises.isEmpty) continue;
        final exercise = (matchingExercises..shuffle()).first;

        final we = WorkoutExercises(
            id: Firestorm.randomID(),
            workoutId: workout.id,
            exerciseId: exercise.id,
            order: 1,
            distance: workoutDistance);
        await FS.create.one(we);
      }

      await scheduleWorkoutsForCurrentWeek(userId: userId,
          starterWorkouts: starterWorkouts,
          preferredWorkoutsPerWeek: preferredWorkoutsPerWeek!);
    }
  }

  bool isValidEmail(String email) {
    //TODO Move to a util class, can be reused elsewhere (e.g., login screen)
    final emailRegex =
    RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  void showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> nextStep() async {
    switch (currentStep) {
      case 0:
        final email = emailController.text.trim();
        final password = passwordController.text.trim();

        if (email.isEmpty || password.isEmpty) {
          showError('Please fill up both email and password fields');
          return;
        }
        if (password.length <= 6) {
          showError('Password must be more than 6 characters');
          return;
        }
        if (!isValidEmail(email)) {
          showError('Please enter a valid email address');
          return;
        }

        setState(() => currentStep++);
        break;

      case 1:
        final username = nameController.text.trim();
        final age = int.tryParse(ageController.text.trim());
        final weight = double.tryParse(weightController.text.trim());
        final height = int.tryParse(heightController.text.trim());

        if (age == null || age < 18 || age > 50) {
          showError('Age must be between 18 and 50');
          return;
        }
        if (weight == null || weight < 45 || weight > 250) {
          showError('Weight must be between 45kg and 250kg');
          return;
        }
        if (height == null || height < 120 || height > 230) {
          showError('Height must be between 100cm and 230cm');
          return;
        }
        setState(() => currentStep++);
        break;

      case 2:
        if (trainingType == null || preferredWorkoutsPerWeek == null ||
            (trainingType != 'Aerobic' && trainingGoal == null)) {
          showError('Please complete all training preferences');
          return;
        }
        showThesisAgreementDialog();
        break;
    }
  }

  void previousStep() {
    if (currentStep > 0) {
      setState(() => currentStep--);
    }
  }

  Future<void> showThesisAgreementDialog() async {
    final agreed = await showDialog(context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: Text('Research Notice'),
            content: Text(
                'This application is part of a thesis research project.\n\n'
                    'By continuing, you acknowledge that you are responsible '
                    'for using this app safely and appropriately.\n\n'
                    'Do you agree to proceed?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false),
                  child: Text('Decline')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true),
                  child: Text('Agree')),
            ],
          );
        });
    if (agreed == true) {
      signup();
    }
  }
  InputDecoration fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder( borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red, width: 1)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
  Widget buildTrainingTypeButton({required String value,required IconData icon,required String label,
    required String selected,required Color color}) {
    final isSelected = selected == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap:(){
          setState((){
            trainingType = value;
            trainingGoal = null;
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,color: isSelected ? Colors.white : color,
                size: 24),
               SizedBox(height: 4),
              Text(label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              )]),
        )),
    );
  }
  Widget sectionTitle(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        children: [
          Container(
            width: 4, height: 20,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(4),
            )),
           SizedBox(width: 8),
          Text(text,style: TextStyle(
              fontSize: 15,fontWeight: FontWeight.w600,letterSpacing: 0.5),
          )]),
    );
  }
    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Sign Up',
          ),
        ),
        body: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xFFC8E6C9), Color(0xFFA5D6A7)],
                      //TODO - Change this gradient to match the app's color scheme (Green!)
                      begin: Alignment.topCenter,
                      end: Alignment.topCenter)
              ),
            ),
            SafeArea(
              child: Card(
                margin: const EdgeInsets.all(10),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 28),
                  child: Form(
                    key: _formKey,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Stepper(
                        type: StepperType.vertical,
                        currentStep: currentStep,
                        onStepContinue: isLoading ? null : nextStep,
                        onStepCancel: previousStep,
                        controlsBuilder: (context, details) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              children: [
                                if (currentStep > 0) ...[
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: TextButton.icon(
                                      onPressed: details.onStepCancel,
                                      icon: Icon(Icons.arrow_back),
                                      label: Text('Back'),
                                    ),
                                  ),
                                ],
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: Size.fromHeight(52),
                                    ),
                                    onPressed: details.onStepContinue,
                                    icon: Icon(
                                      currentStep == 2
                                          ? Icons.check
                                          : Icons.arrow_forward,
                                    ),
                                    label: isLoading
                                        ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child:
                                      CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                        : Text(currentStep == 2
                                        ? 'Finish'
                                        : 'Next'),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        steps: [
                          Step(
                            title: Text('Account'),
                            subtitle:
                            Text('Login credentials'),
                            content: Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: emailController,
                                    decoration: fieldDecoration(
                                        'Email', Icons.email_outlined),
                                    keyboardType: TextInputType.emailAddress,
                                    autovalidateMode: AutovalidateMode
                                        .onUserInteraction,
                                    validator: (value) {
                                      final email = value?.trim() ?? '';

                                      if (email.isEmpty) {
                                        return 'Email is required';
                                      }
                                      if (!isValidEmail(email)) {
                                        return 'Enter a valid email address';
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: 22),
                                  TextFormField(
                                    controller: passwordController,
                                    decoration: fieldDecoration(
                                        'Password', Icons.lock_outline)
                                        .copyWith(
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          obscurePassword
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                        ),
                                        onPressed: () {
                                          setState(() =>
                                          obscurePassword = !obscurePassword);
                                        },
                                      ),
                                      helperText: 'Minimum 6+ characters',
                                    ),
                                    obscureText: obscurePassword,
                                    autovalidateMode: AutovalidateMode
                                        .onUserInteraction,
                                    validator: (value) {
                                      final password = value ?? '';

                                      if (password.isEmpty) {
                                        return 'Password is required';
                                      }
                                      if (password.length <= 6) {
                                        return 'Password must be more than 6 characters';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Step(
                            title: Text('Profile'),
                            subtitle:
                            Text('Personal details'),
                            content: Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Column(
                                children: [
                                  TextFormField(
                                    textCapitalization: TextCapitalization
                                        .words,
                                    controller: nameController,
                                    decoration: fieldDecoration(
                                        'Name',
                                        Icons.person_outline),
                                  ),
                                  SizedBox(height: 22),
                                  TextFormField(
                                    controller: ageController,
                                    decoration: fieldDecoration(
                                        'Age',
                                        Icons.cake_outlined),
                                    keyboardType:
                                    TextInputType.number,
                                  ),
                                  SizedBox(height: 22),
                                  TextFormField(
                                    controller: weightController,
                                    decoration: fieldDecoration(
                                        'Weight (kg)',
                                        Icons
                                            .monitor_weight_outlined),
                                    keyboardType:
                                    TextInputType
                                        .numberWithOptions(
                                        decimal: true),
                                  ),
                                  SizedBox(height: 22),
                                  TextFormField(
                                    controller: heightController,
                                    decoration: fieldDecoration(
                                        'Height (cm)',
                                        Icons
                                            .height),
                                    keyboardType:
                                    TextInputType.number
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Step(
                            title: Text('Training Setup'),
                            subtitle:
                             Text('Training Preferences'),
                            content: Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  sectionTitle('Training Type'),
                                   SizedBox(height: 8),
                                  Container(padding: EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.grey.shade200)),
                                    child: Row(
                                      children: [
                                        Expanded(child: buildTrainingTypeButton(
                                            value: 'Strength',icon: Icons.fitness_center,
                                            label: 'Strength',selected: trainingType ?? 'Strength',
                                            color: Colors.blue,
                                          )),
                                        SizedBox(width: 4),
                                        Expanded(
                                          child: buildTrainingTypeButton(
                                            value: 'Cardio',icon: Icons.directions_run,
                                            label: 'Cardio',selected: trainingType ?? 'Strength',
                                            color: Colors.green,
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Expanded(child: buildTrainingTypeButton(
                                            value: 'Aerobic',icon: Icons.directions_bike,
                                            label: 'Aerobic',selected: trainingType ?? 'Strength',
                                            color: Colors.purple,
                                          )),
                                      ]),
                                  ),
                                  if (trainingType == 'Strength' || trainingType == 'Cardio') ...[
                                     SizedBox(height: 24),
                                    sectionTitle('Training Goal'),
                                     SizedBox(height: 8),
                                    Container(
                                      padding: EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: SegmentedButton<String>(
                                        showSelectedIcon: false,
                                        style: ButtonStyle(
                                          backgroundColor: MaterialStateProperty.resolveWith<Color>(
                                                (states) {
                                              if (states.contains(MaterialState.selected)) {
                                                return trainingType == 'Strength'
                                                    ? Colors.blue.shade400: Colors.orange.shade400;
                                              }
                                              return Colors.transparent;
                                            },
                                          ),
                                          foregroundColor: MaterialStateProperty.resolveWith<Color>(
                                                (states) {
                                              if (states.contains(MaterialState.selected)) {
                                                return Colors.white;
                                              }
                                              return Colors.grey.shade700;
                                            },
                                          ),
                                          textStyle: MaterialStateProperty.all(
                                            TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                          ),
                                          padding: MaterialStateProperty.all(
                                            EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                          ),
                                        ),
                                        segments: trainingType == 'Strength'
                                            ? [
                                          ButtonSegment(
                                            value: 'Muscle Building',label: Text('Muscle Building'),icon: Icon(Icons.fitness_center)),
                                          ButtonSegment(
                                            value: 'Power Building',label: Text('Power Building'),icon: Icon(Icons.bolt)),
                                          ]: [
                                          ButtonSegment(
                                            value: 'Fat Loss',label: Text('Fat Loss'),icon: Icon(Icons.whatshot)),
                                          ButtonSegment(
                                            value: 'Endurance',label: Text('Endurance'),icon: Icon(Icons.timer)),
                                        ],
                                        selected: {
                                          trainingGoal ?? (trainingType == 'Strength'? 'Muscle Building': 'Fat Loss') },
                                        onSelectionChanged: (selection) {
                                          setState(() => trainingGoal = selection.first);
                                        },
                                      ))],

                                  if (trainingType != 'Aerobic') ...[
                                    SizedBox(height: 24),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: SwitchListTile(
                                        value: hasAccessToGym,
                                        title: Text('Gym Access',style: TextStyle(fontWeight: FontWeight.w600)),
                                        subtitle: Text(
                                          hasAccessToGym? 'Using gym equipment'
                                              : 'Bodyweight only',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12)),
                                        activeColor: Theme.of(context).primaryColor,
                                        onChanged: (v) => setState(() => hasAccessToGym = v),
                                      )),
                                  ],
                                  SizedBox(height: 24),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.grey.shade200),
                                    ),
                                    child: DropdownButtonFormField<int>(
                                      value: preferredWorkoutsPerWeek,
                                      decoration: InputDecoration(
                                        labelText: 'Workouts per Week',
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      ),
                                      items: [
                                        DropdownMenuItem(value: 1, child: Text('1 day per week')),
                                        DropdownMenuItem(value: 2, child: Text('2 days per week')),
                                        DropdownMenuItem(value: 3, child: Text('3 days per week')),
                                        DropdownMenuItem(value: 4, child: Text('4 days per week')),
                                        DropdownMenuItem(value: 5, child: Text('5 days per week')),
                                      ],
                                      onChanged: (v) => setState(() => preferredWorkoutsPerWeek = v!),
                                    )),
                                  if (trainingType == 'Aerobic') ...[
                                    SizedBox(height: 16),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: DropdownButtonFormField<String>(
                                        value: aerobicType,
                                        decoration: InputDecoration(
                                          labelText: 'Aerobic Type',
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        ),
                                        items: [
                                          DropdownMenuItem(value: 'Running', child: Text('🏃 Running')),
                                          DropdownMenuItem(value: 'Cycling', child: Text('🚴 Cycling')),
                                          DropdownMenuItem(value: 'Swimming', child: Text('🏊 Swimming')),
                                        ],
                                        onChanged: (v) => setState(() => aerobicType = v),
                                      ),
                                    ),
                                    SizedBox(height: 16),
                                    TextFormField(
                                      decoration: fieldDecoration('Weekly Distance Goal (km)', Icons.route),
                                      controller: aerobicDistanceController,
                                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                                    ),
                                  ],
                                ],
                              )),
                          )]),
                    ),
                  ))),
            ),
            if (isLoading)
              Container(
                color: Colors.black26,
                child: const Center(
                    child: CircularProgressIndicator()),
              ),
          ],
        ),
      );
    }
  }
