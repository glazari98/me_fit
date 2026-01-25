import 'package:firestorm/fs/fs.dart';
import 'package:firestorm/fs/queries/fs_query_result.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/models/exercise.dart';
import '../services/authentication_service.dart';
import 'package:dropdown_button2/dropdown_button2.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final AuthenticationService authService = AuthenticationService();
  String? selectedExerciseId;
  Exercise? selectedExercise;
  void logOut(BuildContext context)async{
    authService.logOutUser();
    Navigator.pushReplacementNamed(context, '/login');
  }
  Future<List<Exercise>> fetchExercises() async {
    FSQueryResult<Exercise> result = await FS.list.filter<Exercise>(Exercise)
        .whereIn('userId', ['system',authService.getCurrentUser()?.uid])
        .fetch();

     List<Exercise> exercises = result.items;
     return exercises;
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
      body: Padding (
        padding: const EdgeInsets.all(16),
        child: Column (
          children: [
            Text(
              'Welcome, ${currentUser?.email ?? 'User'}!',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),

            ),
            const SizedBox(height: 20),
            FutureBuilder<List<Exercise>>(
              future: fetchExercises(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                } else if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text ('No exercises available');
                }
                List<Exercise> exercises = snapshot.data!;

                return DropdownButton2<String>(
                  isExpanded: true,
                  hint: const Text('Select Exercise'),
                  value: selectedExerciseId,
                  items: exercises.map((exercise) {
                    return DropdownMenuItem<String>(
                      value: exercise.id,
                      child: Text(exercise.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedExerciseId = value;
                      selectedExercise = exercises.firstWhere((ex) => ex.id == value);
                    });
                  },
                  dropdownStyleData: DropdownStyleData(
                    maxHeight: 200,
                    scrollbarTheme: ScrollbarThemeData(
                      thumbVisibility: .all(true),
                      thickness: .all(6),
                      radius: const Radius.circular(5),
                    ),
                  ),
                );
              },
            ),
        const SizedBox(height: 20),

        if(selectedExercise != null)
          Card(
            elevation: 3,
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedExercise!.name,
                  style: const TextStyle(fontSize: 18,fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text (
                  'Body part: ${selectedExercise!.bodyPart}',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  selectedExercise!.description,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
        ),
          ),
          ],
        ),
      ),
    );
  }
}