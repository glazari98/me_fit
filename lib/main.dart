import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/data/insert_data_script.dart';
import 'package:me_fit/screens/home_screen.dart';
import 'package:me_fit/screens/my_workouts.dart';
import 'package:me_fit/screens/signup_screen.dart';
import 'package:me_fit/theme/app_theme_light.dart';
import 'generated/firestorm_models.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Try to initialize Firebase
    await Firebase.initializeApp();
    print('✅ Firebase initialized successfully');

    await FS.init();
    print('✅ Firestorm initialized successfully');

    registerClasses();

    runApp(const MeFitApp());
  } catch (e) {
    print('❌ Initialization error: $e');
    // Show an error screen instead of crashing silently
    runApp(ErrorApp(error: e.toString()));
  }
}

class ErrorApp extends StatelessWidget {
  final String error;

  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 20),
                const Text(
                  'Failed to initialize app',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    // Restart the app
                    main();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MeFitApp extends StatelessWidget{
  const MeFitApp({super.key});

  @override
  Widget build(BuildContext context){
    return MaterialApp(
      title: 'MeFit',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      initialRoute: FirebaseAuth.instance.currentUser != null ? '/home' : '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signUp': (context) => const SignupScreen(),
        '/home': (context) => const  HomeScreen(),
        '/workouts': (context) => const  MyWorkoutsScreen(),
      },
    );
  }
}