import 'package:firebase_core/firebase_core.dart';
import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/screens/home_screen.dart';
import 'package:me_fit/screens/signup_screen.dart';
import 'generated/firestorm_models.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); //Ensures Flutter is initialized before Firebase
  await Firebase.initializeApp();
  await FS.init(); //Initialize Firestorm to use Firestore
  registerClasses(); //Registers custom classes. Imported from generated file [firestorm_models.dart].

  runApp(const MeFitApp());
}

class MeFitApp extends StatelessWidget{
  const MeFitApp({super.key});

  @override
  Widget build(BuildContext context){
    return MaterialApp(
      title: 'MeFit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signUp': (context) => const SignupScreen(),
        '/home': (context) => const  HomeScreen(),
      },
    );
  }
}