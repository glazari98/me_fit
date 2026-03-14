import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firestorm/fs/fs.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/data/insert_data_script.dart';
import 'package:me_fit/screens/home_screen.dart';
import 'package:me_fit/screens/custom_workouts.dart';
import 'package:me_fit/screens/signup_screen.dart';
import 'package:me_fit/theme/app_theme_light.dart';
import 'firebase_options.dart';
import 'generated/firestorm_models.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); //Ensures Flutter is initialized before Firebase

  if (!kIsWeb) {
    await Firebase.initializeApp();
  }
  else {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
  }

  await FS.init(); //Initialize Firestorm to use Firestore
  registerClasses(); //Registers custom classes. Imported from generated file [firestorm_models.dart]

  final runnableApp = _buildRunnableApp(
    isWeb: kIsWeb,
    webAppWidth: 480,
    webAppHeight: 960,
    app: const MeFitApp(),
  );

  runApp(runnableApp);
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
        '/workouts': (context) => const  CustomWorkouts(),
      },
    );
  }
}

Widget _buildRunnableApp({
  required bool isWeb,
  required double webAppWidth,
  required double webAppHeight,
  required Widget app,
}) {
  if (!isWeb) {
    return app;
  }

  return Center(
    child: ClipRect(
      child: SizedBox(
        width: webAppWidth,
        height: webAppHeight,
        child: app,
      ),
    ),
  );
}