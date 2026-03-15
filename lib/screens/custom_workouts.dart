import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firestorm/firestorm.dart';
import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/components/drawer_menu.dart';
import 'package:me_fit/screens/edit_workout_screen.dart';
import 'package:me_fit/screens/view_workout_screen.dart';
import 'package:me_fit/services/authentication_service.dart';
import '../models/scheduled_workout.dart';
import '../models/workout.dart';
import '../models/workoutExercises.dart';
import 'create_workout_screen.dart';
//widget for displaying list of custom workouts created by user
class CustomWorkouts extends StatefulWidget {
  const CustomWorkouts({super.key});

  @override
  State<CustomWorkouts> createState() => CustomWorkoutsState();
}
class CustomWorkoutsState extends State<CustomWorkouts> {
  final AuthenticationService authenticationService = AuthenticationService();
  late Future<List<Workout>> workoutsUpdated;

  List<Workout> allWorkouts = [];
  bool isLatestFirst = true;
  String searchQuery = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchWorkouts();
  }
//function for sorting workouts according to ones created latest/earliest
  void sortList() {
    allWorkouts.sort((a, b) {
      final aDate = a.createdOn?.toDate() ?? DateTime(0);
      final bDate = b.createdOn?.toDate() ?? DateTime(0);


      return isLatestFirst ? bDate.compareTo(aDate) : aDate.compareTo(bDate);
    });
  }
//if a workout is a custom one, 'isMyWorkout' attribute is true
  Future<void> fetchWorkouts() async {
    final user = authenticationService.getCurrentUser();

    final result = await FS.list.filter<Workout>(Workout)
        .whereEqualTo('createdBy', user?.uid)
        .whereEqualTo('isMyWorkout', true)
        .fetch();

    setState(() {
      allWorkouts = result.items;
      isLoading = false;
    });
    sortList();
  }
//function used in searching by workout name
  List<Workout> get filteredList {
    return allWorkouts.where((workout) {
      return workout.name.toLowerCase()
          .contains(searchQuery.toLowerCase());
    }).toList();
  }
  //schedule a custom workout for a specific date
  Future<void> createScheduledWorkout(Workout workout) async {
    final user = authenticationService.getCurrentUser();
    if (user == null) return;

    //date should start from today onwards
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      helpText: 'Select date for workout',
      confirmText: 'Schedule',
      cancelText: 'Cancel',
    );

    if (selectedDate == null) return;

    //set it to be available form midnight on that day
    final scheduledDate = DateTime(
        selectedDate.year,selectedDate.month,selectedDate.day,0, 0, 0, 0, 0);

    //add workout to calendar
    final scheduledWorkout = ScheduledWorkout(
      id: Firestorm.randomID(),
      userId: user.uid,
      workoutId: workout.id,
      originalWorkoutId: workout.id,
      scheduledDate: Timestamp.fromDate(scheduledDate),
      isCompleted: false,
      isInProgress: false,
    );

    await FS.create.one(scheduledWorkout);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(
            'Workout scheduled for ${scheduledDate.day}/${scheduledDate.month}/${scheduledDate.year}'),
        duration: Duration(seconds: 2)),
    );
  }
//function called when user decided to delete custom workout
  void deleteWorkout(Workout workout) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (_) =>
            AlertDialog(
              title: const Row(children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red),
                SizedBox(width: 8), Text('Delete Workout'),
              ],),
              content: Text('Are you sure you want to remove ${workout.name}'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                        'Delete', style: TextStyle(color: Colors.white))),
              ],
            ));
    if (confirm != true) return;

    final exercises = await FS.list.filter<WorkoutExercises>(WorkoutExercises)
        .whereEqualTo('workoutId', workout.id)
        .fetch();

    for (final we in exercises.items) {
      await FS.delete.one(we);
    }
    await FS.delete.one(workout);

    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Workout deleted')));
    await fetchWorkouts();
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title:  Text('Custom Workouts'), centerTitle: true,
        actions: [
          IconButton(
              icon: Icon(isLatestFirst ? Icons.arrow_upward : Icons.arrow_downward ,
                color: Colors.white,
              ),onPressed: () {
                setState(() {
                  isLatestFirst = !isLatestFirst;
                  sortList();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(
                      isLatestFirst?'Sorted by latest workouts'
                          :'Sorted by earliest workouts',
                    ),behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 1),
                  ));
              }),
        ]),
      drawer: AppDrawer(scaffoldContext: context,currentRoute: '/my-workouts'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,  MaterialPageRoute(
              builder: (_) =>  CreateWorkoutScreen(),
            ));
          await fetchWorkouts();
        },
        icon: Icon(Icons.add),label:  Text('Create'),backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,borderRadius: BorderRadius.circular(16),
              boxShadow:[BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10, offset:Offset(0, 4),
                )]),
            child: TextField(decoration: InputDecoration(
                hintText: 'Search workouts...',prefixIcon: Icon(
                  Icons.search,color: Colors.grey[600]
                ),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(icon: Icon(Icons.clear,color: Colors.grey[600]),
                  onPressed: () {
                    setState(() {
                      searchQuery = '';
                    });
                  }): null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,vertical: 14,
                )),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              })),
          Padding(
            padding:  EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
                Text(
                  '${filteredList.length} workouts',
                  style: TextStyle(color: Colors.grey[600],fontSize: 14,fontWeight: FontWeight.w500,
                  ))],
            )),
           SizedBox(height: 8),
          Expanded(
            child: filteredList.isEmpty
                ? Center( child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(padding:  EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      shape: BoxShape.circle),
                    child: Icon(Icons.fitness_center_outlined,size: 48,color: Colors.grey[600]),
                  ),
                   SizedBox(height: 16),
                  Text( searchQuery.isNotEmpty
                        ? 'No workouts match "$searchQuery"'
                        : 'No custom workouts yet',
                    style: TextStyle(color: Colors.grey[600],
                      fontSize: 16, fontWeight: FontWeight.w500,
                    )),
                   SizedBox(height: 8),
                  if (searchQuery.isNotEmpty)
                    TextButton(onPressed: () {
                        setState(() {
                          searchQuery = '';
                        });
                      },child:  Text('Clear search'),
                    )else Text(
                      'Tap + to create your first workout',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ))],
              ),
            )
            : ListView.builder(
              padding:  EdgeInsets.all(16),
              itemCount: filteredList.length,
              itemBuilder: (context, index) {
                final workout = filteredList[index];
                return buildWorkoutCard(workout);
              },
            ))],
      ));
  }
//widget for showing inside information regarding the workout and icons for editing or deleting
  Widget buildWorkoutCard(Workout workout) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white,borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15, offset: const Offset(0, 5),
          )]),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,MaterialPageRoute(
                builder: (_) => ViewWorkoutScreen(workout: workout),
              ));
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(padding: const EdgeInsets.all(16),
            child: Column (children: [
              Row(children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16)),
                  child: Icon(
                    Icons.fitness_center, color: Theme.of(context).primaryColor,size: 28 )),
                 SizedBox(width: 16),
                Expanded( child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text(
                        workout.name,style:  TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                      ), SizedBox(height: 4),

                    ])),
                Row( mainAxisSize: MainAxisSize.min,
                  children: [
                    buildActionButton(
                      icon: Icons.edit,color: Colors.blue,
                      tooltip: 'Edit Workout',
                      onPressed: () {
                        Navigator.push(
                          context,MaterialPageRoute(
                            builder: (_) => EditWorkoutScreen(workout: workout),
                          ),
                        );
                      }),
                    SizedBox(width: 8),
                    buildActionButton(
                      icon: Icons.calendar_month,
                      color: Colors.green,
                      tooltip: 'Schedule Workout',
                      onPressed: () => createScheduledWorkout(workout),
                    ),
                    SizedBox(width: 8),
                    buildActionButton(icon: Icons.delete,
                      color: Colors.red,tooltip: 'Delete Workout',
                      onPressed: () => deleteWorkout(workout),
                    )]),
              ]),
              if (workout.createdOn != null)
                Padding(padding: EdgeInsets.symmetric(horizontal: 55.0),
                child: Row(mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                  Icon(Icons.calendar_today,size: 12,color: Colors.grey[500]),
                  SizedBox(width: 4),
                  Flexible(child:Text('Created ${workout.createdOn?.toDate().day}/${workout.createdOn?.toDate().month}'
                      ' at ${workout.createdOn?.toDate().hour.toString().padLeft(2, '0')}:${workout.createdOn?.toDate().minute.toString().padLeft(2, '0')}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  )),])),
              ])
          ),
        )),
    );
  }
//widget for creating buttons for editing or deleting a workout
  Widget buildActionButton({required IconData icon,required Color color,required String tooltip,required VoidCallback onPressed}) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12)),
      child: IconButton(icon: Icon(icon, color: color, size: 20),
        onPressed: onPressed,tooltip: tooltip,
        constraints: const BoxConstraints(
          minWidth: 40,minHeight: 40),
        padding: EdgeInsets.zero)
    );
  }
}
