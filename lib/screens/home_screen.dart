import 'package:flutter/material.dart';
import 'package:me_fit/screens/my_workouts.dart';
import '../services/authentication_service.dart';


import 'create_workout_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final AuthenticationService authService = AuthenticationService();
  int currentIndex =0;
  void logOut(BuildContext context)async{
    authService.logOutUser();
    Navigator.pushReplacementNamed(context, '/login');
  }
  late final List<Widget> screens =  [
    const Center(child: Text('Home',style: TextStyle(fontSize: 18))),
    MyWorkoutsScreen(),
    CreateWorkoutScreen(),
  ];

  late final List<String> titles = [
    'Home', 'My Workouts', 'Create Workouts',
  ];

  @override
  Widget build(BuildContext context){
    final currentUser = authService.getCurrentUser();
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[currentIndex]),
        actions: [
          IconButton(
              onPressed: () => logOut(context),
              icon: const Icon(Icons.logout),
          )
        ],
      ),
      body: screens[currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => setState(()=> currentIndex = index),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
          ),
          BottomNavigationBarItem(
              icon: Icon(Icons.list_alt),
              label: 'My Workouts',
          ),
          BottomNavigationBarItem(
              icon: Icon(Icons.fitness_center),
              label: 'Create Workouts'),
        ],
      ),
    );
  }
}