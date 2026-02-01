import 'package:flutter/material.dart';
import 'package:me_fit/screens/my_workouts.dart';
import 'package:me_fit/screens/start_workout_screen.dart';
import '../services/authentication_service.dart';


import 'create_workout_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final AuthenticationService authService = AuthenticationService();

  void logOut(BuildContext context)async{
    authService.logOutUser();
    Navigator.pushReplacementNamed(context, '/login');
  }
  int selectedIndex = 0;
//Handles bottom navigation selection
  void onItemTapped (int index) {
    if (index == 0) {
      Navigator.push(context, MaterialPageRoute(builder: (context) =>
          MyWorkoutsScreen()));
    } else if (index == 1) {
      Navigator.push(context, MaterialPageRoute(builder: (context) =>
          StartWorkoutScreen()));
    }
  }
  @override
  Widget build(BuildContext context){
    final currentUser = authService.getCurrentUser();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
              onPressed: () => logOut(context),
              icon: const Icon(Icons.logout),
          )
        ],
      ),
      body: const Text('Hello'),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: onItemTapped,
        backgroundColor: Colors.white,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: "My Workouts"),
          BottomNavigationBarItem(icon: Icon(Icons.play_arrow), label: "Start Workout")
        ],
      ),
    );
  }
}