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

  @override
  Widget build(BuildContext context){
    final currentUser = authService.getCurrentUser();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
              onPressed: () => logOut(context),
              icon: const Icon(Icons.logout),
          )
        ],
      ),
      body: const Text('Hello'),
      bottomNavigationBar: BottomNavigationBar(
        onTap: (index){
          if(index == 0){
            Navigator.push(context,
                MaterialPageRoute(builder: (_)=> const MyWorkoutsScreen())
            );
          }
          else{
            Navigator.push(context,
              MaterialPageRoute(builder: (_) => StartWorkoutScreen())
            );
          }
        },
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.list_alt),
              label: 'My Workouts',
          ),

          BottomNavigationBarItem(
              icon: Icon(Icons.play_arrow),
              label: 'Start Workout'),
        ],
      ),
    );
  }
}