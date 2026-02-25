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

  String? trainingType;
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
        trainingType: trainingType!,
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

  Future<void> assignStarterWorkouts(String userId) async {
    final allExercises = await FS.list.allOfClass<Exercise>(Exercise);
    if (allExercises.isEmpty) return;
  }

  bool isValidEmail(String email) { //TODO Move to a util class, can be reused elsewhere (e.g., login screen)
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

        if (username.isEmpty || age == null || weight == null) {
          showError('Please complete all profile fields');
          return;
        }

        setState(() => currentStep++);
        break;

      case 2:
        if (trainingType == null || preferredWorkoutsPerWeek == null) {
          showError('Please complete all training preferences');
          return;
        }
        signup();
        break;
    }
  }

  void previousStep() {
    if (currentStep > 0) {
      setState(() => currentStep--);
    }
  }

  InputDecoration fieldDecoration(String label, IconData icon) { //TODO Move to a theming class instead. Can be reused across the app for consistent styling of form fields.
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
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
              gradient: LinearGradient(colors: [Color(0xFF1E3C72), Color(0xFF2A5298)], //TODO - Change this gradient to match the app's color scheme (Green!)
                  begin: Alignment.topCenter, end:Alignment.topCenter)
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
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextButton.icon(
                                    onPressed: details.onStepCancel,
                                    icon: const Icon(Icons.arrow_back),
                                    label: const Text('Back'),
                                  ),
                                ),
                              ],
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(52),
                                  ),
                                  onPressed: details.onStepContinue,
                                  icon: Icon(
                                    currentStep == 2
                                        ? Icons.check
                                        : Icons.arrow_forward,
                                  ),
                                  label: isLoading
                                      ? const SizedBox(
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
                          title: const Text('Account'),
                          subtitle:
                          const Text('Login credentials'),
                          content: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: emailController,
                                  decoration: fieldDecoration('Email', Icons.email_outlined),
                                  keyboardType: TextInputType.emailAddress,
                                  autovalidateMode: AutovalidateMode.onUserInteraction,
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
                                const SizedBox(height: 22),
                                TextFormField(
                                  controller: passwordController,
                                  decoration: fieldDecoration('Password', Icons.lock_outline).copyWith(
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        obscurePassword ? Icons.visibility_off : Icons.visibility,
                                      ),
                                      onPressed: () {
                                        setState(() => obscurePassword = !obscurePassword);
                                      },
                                    ),
                                    helperText: 'Minimum 6+ characters',
                                  ),
                                  obscureText: obscurePassword,
                                  autovalidateMode: AutovalidateMode.onUserInteraction,
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
                          title: const Text('Profile'),
                          subtitle:
                          const Text('Personal details'),
                          content: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              children: [
                                TextFormField(
                                  textCapitalization: TextCapitalization.words,
                                  controller: nameController,
                                  decoration: fieldDecoration(
                                      'Name',
                                      Icons.person_outline),
                                ),
                                const SizedBox(height: 22),
                                TextFormField(
                                  controller: ageController,
                                  decoration: fieldDecoration(
                                      'Age',
                                      Icons.cake_outlined),
                                  keyboardType:
                                  TextInputType.number,
                                ),
                                const SizedBox(height: 22),
                                TextFormField(
                                  controller: weightController,
                                  decoration: fieldDecoration(
                                      'Weight (kg)',
                                      Icons
                                          .monitor_weight_outlined),
                                  keyboardType:
                                  const TextInputType
                                      .numberWithOptions(
                                      decimal: true),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Step(
                          title:
                          const Text('Training Setup'),
                          subtitle:
                          const Text('Preferences'),
                          content: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              children: [
                                const SizedBox(height: 8),
                                SegmentedButton<String>(
                                  segments: const [
                                    ButtonSegment(
                                        value: 'Strength',
                                        label:
                                        Text('Strength')),
                                    ButtonSegment(
                                        value: 'Cardio',
                                        label:
                                        Text('Cardio')),
                                    ButtonSegment(
                                        value: 'Aerobic',
                                        label:
                                        Text('Aerobic')),
                                  ],
                                  selected: {
                                    trainingType ??
                                        'Strength'
                                  },
                                  onSelectionChanged:
                                      (selection) {
                                    setState(() =>
                                    trainingType =
                                        selection.first);
                                  },
                                ),
                                const SizedBox(height: 18),
                                if (trainingType !=
                                    'Aerobic')
                                  SwitchListTile(
                                    value: hasAccessToGym,
                                    title: const Text(
                                        'Gym Access'),
                                    onChanged: (v) =>
                                        setState(() =>
                                        hasAccessToGym =
                                            v),
                                  ),
                                const SizedBox(height: 18),
                                DropdownButtonFormField<int>(
                                  value:
                                  preferredWorkoutsPerWeek,
                                  decoration:
                                  const InputDecoration(
                                    labelText:
                                    'Workouts per Week',
                                    filled: true,
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 1,
                                        child:
                                        Text('1 days')),
                                    DropdownMenuItem(
                                        value: 2,
                                        child:
                                        Text('2 days')),
                                    DropdownMenuItem(
                                        value: 3,
                                        child:
                                        Text('3 days')),
                                    DropdownMenuItem(
                                        value: 4,
                                        child:
                                        Text('4 days')),
                                    DropdownMenuItem(
                                        value: 5,
                                        child:
                                        Text('5 days')),
                                  ],
                                  onChanged: (v) =>
                                      setState(() =>
                                      preferredWorkoutsPerWeek =
                                      v!),
                                ),
                                if (trainingType ==
                                    'Aerobic') ...[
                                  const SizedBox(
                                      height: 22),
                                  DropdownButtonFormField<
                                      String>(
                                    value: aerobicType,
                                    decoration:
                                    const InputDecoration(
                                      labelText:
                                      'Aerobic type',
                                      filled: true,
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                          value:
                                          'Running',
                                          child:
                                          Text('Running')),
                                      DropdownMenuItem(
                                          value:
                                          'Cycling',
                                          child:
                                          Text('Cycling')),
                                      DropdownMenuItem(
                                          value:
                                          'Swimming',
                                          child:
                                          Text('Swimming')),
                                    ],
                                    onChanged: (v) =>
                                        setState(() =>
                                        aerobicType =
                                            v),
                                  ),
                                  const SizedBox(
                                      height: 22),
                                  TextFormField(
                                    controller:
                                    aerobicDistanceController,
                                    decoration:
                                    fieldDecoration(
                                        'Weekly Distance (km)',
                                        Icons
                                            .directions_run_outlined),
                                    keyboardType:
                                    const TextInputType
                                        .numberWithOptions(
                                        decimal: true),
                                  ),
                                ]
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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