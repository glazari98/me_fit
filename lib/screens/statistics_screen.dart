import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/components/drawer_menu.dart';
import 'package:me_fit/models/scheduled_workout.dart';
import 'package:me_fit/models/workoutExercises.dart';
import 'package:me_fit/services/authentication_service.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/exercise.dart';
import '../models/user.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => StatisticsScreenState();
}

class StatisticsScreenState extends State<StatisticsScreen> {
  final AuthenticationService authService = AuthenticationService();
  bool isLoading = true;

  //stats
  int totalWorkoutsThisMonth = 0;
  int totalDurationThisMonth = 0;
  double totalWeightLifted = 0;
  double totalDistanceCovered = 0;
  int totalCardioDuration = 0;

  //pie chart of common exercise types
  Map<String, int> exerciseTypeCount = {};

  late DateTime currentMonth;
  late DateTime signupDate;
  bool signUpDateLoaded = false;

  @override
  void initState() {
    super.initState();
    currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    loadProgressData();
  }

  Future<void> loadProgressData() async {
    setState(() => isLoading = true);

    final currentUser = authService.getCurrentUser();
    if (currentUser == null) return;
    //get user sign up date
    final userData = await FS.get.one<User>(currentUser.uid);
    if (userData != null && userData.signUpDate != null) {
      signupDate = userData.signUpDate!.toDate();
      signUpDateLoaded = true;
    }
    //get completed workouts of this month
    final nextMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);

    final completedWorkouts = await FS.list.filter<ScheduledWorkout>(ScheduledWorkout)
        .whereEqualTo('userId', currentUser.uid)
        .whereEqualTo('isCompleted', true)
        .whereGreaterThanOrEqualTo('completedDate', Timestamp.fromDate(currentMonth))
        .whereLessThan('completedDate', Timestamp.fromDate(nextMonth))
        .fetch();

    totalWorkoutsThisMonth = completedWorkouts.items.length;
    //initialise stats
    totalDurationThisMonth = 0;
    totalWeightLifted = 0;
    totalDistanceCovered = 0;
    totalCardioDuration = 0;
    exerciseTypeCount = {};

   //total duration from all completed workouts
    for (var scheduledWorkout in completedWorkouts.items) {
      if (scheduledWorkout.totalDuration != null) {
        totalDurationThisMonth += scheduledWorkout.totalDuration!;
      }

      final workoutExercises = await FS.list.filter<WorkoutExercises>(WorkoutExercises)
          .whereEqualTo('workoutId', scheduledWorkout.workoutId)
          .fetch();


      for (var exercise in workoutExercises.items) {
        await processExerciseStats(exercise);
      }
    }
    if(mounted) {
      setState(() => isLoading = false);
    }

  }

  Future<void> processExerciseStats(WorkoutExercises exercise) async {
    final exerciseData = await FS.get.one<Exercise>(exercise.exerciseId);
    if (exerciseData == null) return;

    final type = getExerciseType(exercise);
    exerciseTypeCount[type] = (exerciseTypeCount[type] ?? 0) + 1;

     switch (type) {
      case 'STRENGTH'://for strength exercises find weight lifted
        if (exercise.actualSetWeights != null) {
          for (int i = 0; i < exercise.actualSetWeights!.length; i++) {
            if(exercise.actualSetWeights![i] > 0) {
              totalWeightLifted += exercise.actualSetWeights![i] * exercise.repetitions!;
            }
          }
        }
        break;

      case 'CARDIO':
      case 'PLYOMETRICS': //for cardio/plyometric exercises find duration of completed set
        if (exercise.durationOfTimedSet != null && exercise.setsCompleted != null) {
          totalCardioDuration += exercise.durationOfTimedSet! * exercise.setsCompleted!;
        }
        break;

      case 'AEROBIC'://for aerobic exercise find total distance covered
        if (exercise.distanceCovered != null) {
          totalDistanceCovered += exercise.distanceCovered!;
        }
        break;
    }
  }

  String getExerciseType(WorkoutExercises we) {
    if (we.distance != null) return 'AEROBIC';
    if (we.durationOfTimedSet != null && we.sets != null) return 'CARDIO';
    if (we.durationOfTimedSet != null && we.sets == null) return 'STRETCHING';
    return 'STRENGTH';
  }

  String formatDuration(int seconds) {
    if (seconds < 60) {
      return '$seconds s';
    } else if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      return '${minutes}m';
    } else {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      if (minutes == 0) {
        return '${hours}h';
      }
      return '${hours}h ${minutes}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Statistics'), centerTitle: true),
      drawer: AppDrawer(scaffoldContext: context,currentRoute: '/statistics'),
      body: isLoading? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: loadProgressData,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildMonthSelector(),
              SizedBox(height: 16),
              GridView.count(shrinkWrap: true,physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 3,crossAxisSpacing: 8, mainAxisSpacing: 8,childAspectRatio: 0.9,
                children: [
                  buildStatCard('Workouts','$totalWorkoutsThisMonth',Icons.fitness_center,Colors.blue),
                  buildStatCard('Total Time',formatDuration(totalDurationThisMonth),Icons.timer,Colors.teal),
                  buildStatCard('Weight lifted','${totalWeightLifted.toStringAsFixed(0)}kg',Icons.fitness_center,Colors.orange),
                  buildStatCard('Distance','${totalDistanceCovered.toStringAsFixed(1)}km',Icons.map,Colors.green),
                  buildStatCard('Cardio',formatDuration(totalCardioDuration),Icons.directions_run,Colors.purple),
                ],
              ),
              SizedBox(height: 20),
              buildExerciseTypeChart(), //pie chart
            ],
          )),
      ));
  }

  Widget buildMonthSelector() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left),
            onPressed: () {
              final prevMonth = DateTime(currentMonth.year, currentMonth.month - 1, 1);
              //allow going to next month if next month is not after the current month
              if (signUpDateLoaded &&(prevMonth.year > signupDate.year || (prevMonth.year == signupDate.year && prevMonth.month >= signupDate.month))) {
                setState(() {
                  currentMonth = prevMonth;
                });
                loadProgressData();
              }
            }),
          Text(
            '${monthName(currentMonth.month)} ${currentMonth.year}',
            style: TextStyle(fontSize: 18,fontWeight: FontWeight.bold)),
          IconButton(icon: Icon(Icons.chevron_right),onPressed: currentMonth.month == DateTime.now().month &&
                currentMonth.year == DateTime.now().year ? null
                : () {
              setState(() {
                currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
              });
              loadProgressData();
            })],
      ),
    );
  }

  Widget buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, color.withOpacity(0.05)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.1),blurRadius: 8,offset: Offset(0, 2))],
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(color: color.withOpacity(0.1),borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 16)),
            Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,style: TextStyle(fontSize: 16,fontWeight: FontWeight.bold,color: color),
                ),
                Text(title,style: TextStyle(fontSize: 10,color: Colors.grey[600]),
                ),
              ])],
        )),
    );
  }

  Widget buildExerciseTypeChart() {
    if (exerciseTypeCount.isEmpty) {
      return Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.grey.shade50,borderRadius: BorderRadius.circular(20),border: Border.all(color: Colors.grey.shade200)),
        child: Center(
          child: Text('No exercise data for this month')),
      );
    }

    final colors = {
      'STRENGTH': Colors.blue,'CARDIO': Colors.green,'PLYOMETRICS': Colors.orange,
      'AEROBIC': Colors.purple,'STRETCHING': Colors.teal};

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,offset:Offset(0, 4)),
        ],border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.pie_chart, color: Colors.purple)),
              SizedBox(width: 12),
              Text(' FAVOURITE EXERCISE TYPES',style: TextStyle(fontSize: 14,fontWeight: FontWeight.w600,letterSpacing: 1.2),
              )],
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 150,
                  child: PieChart(
                    PieChartData(sections: exerciseTypeCount.entries.map((entry) {
                        return PieChartSectionData(
                          value: entry.value.toDouble(),
                          title: '${entry.value}',
                          color: colors[entry.key] ?? Colors.grey,
                          radius: 60,
                          titleStyle: TextStyle(color: Colors.white,fontWeight: FontWeight.bold,fontSize: 12),
                        );
                      }).toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                    )),
                )),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: exerciseTypeCount.entries.map((entry) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(width: 10,height: 10,
                            decoration: BoxDecoration(color: colors[entry.key] ?? Colors.grey,shape: BoxShape.circle),
                          ),
                          SizedBox(width: 6),
                          Expanded(child: Text(entry.key,
                              style: TextStyle(
                                fontSize: 11,color: Colors.grey[700]),
                            ))],
                      ),
                    );
                  }).toList(),
                ))],
          )],
      )
    );
  }

  String monthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}