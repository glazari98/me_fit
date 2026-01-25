import 'package:flutter/material.dart';
import '../services/authentication_service.dart';

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
              tooltip: 'Logout',
          ),
        ],
      ),
      body: Center(
        child: Text(
          'Welcome, ${currentUser?.email ?? 'User'}!',
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}