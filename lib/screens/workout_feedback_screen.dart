import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:me_fit/models/scheduled_workout.dart';
import 'package:me_fit/models/workoutExerciseFeedback.dart';
import 'package:me_fit/models/workoutExercises.dart';
import 'package:me_fit/screens/custom_workouts.dart';
import 'package:me_fit/services/achievement_service.dart';


import '../models/exercise.dart';
import '../models/workout.dart';
import '../utilityFunctions/utility_functions.dart';
//widget
class WorkoutFeedbackScreen extends StatefulWidget {
  final Workout workout;
  final List<WorkoutExercises> exercises;
  final bool showBadgeUnlocked;
  final int badgeMilestone;

  const WorkoutFeedbackScreen({
    super.key,
    required this.workout,
    required this.exercises,
    this.showBadgeUnlocked = false,
    this.badgeMilestone = 0,
  });

  @override
  State<WorkoutFeedbackScreen> createState() => WorkoutFeedbackScreenState();
}

class WorkoutFeedbackScreenState extends State<WorkoutFeedbackScreen> {

  ScheduledWorkout? scheduledWorkout;

  Map<String, WorkoutExerciseFeedback> feedbackMap = {};
  Map<String, Exercise> exerciseMap = {};
  GoogleMapController? mapController;

  @override
  void initState(){
    super.initState();
    loadData();
  }
//retrieve feedback
  Future<void> loadData() async {
    await loadScheduledWorkout();
    await loadFeedback();
    await loadExercises();

    if (widget.showBadgeUnlocked && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showBadgeUnlockedDialog();
      });
    }
    setState((){});
  }
//dialog to show when a badge is unlocked once a workout is completed and we move to this screen
  void showBadgeUnlockedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            SizedBox(width: 8),Text('New Badge Unlocked!')],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(AchievementService().getBadgeImage(widget.badgeMilestone),
              height: 100,width: 100),
            SizedBox(height: 16),
             Text('Congratulations!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('You\'ve completed ${widget.badgeMilestone} workout${widget.badgeMilestone > 1 ? 's' : ''}!',
              textAlign: TextAlign.center,
            )],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Continue'),
          )],
      ));
  }
//retrieve all exercises to display their names
  Future<void> loadExercises() async{
    final result = await FS.list.allOfClass<Exercise>(Exercise);

    exerciseMap = {
      for(var e in result) e.id : e
    };
  }
  //get scheduled workout to fetch exercises
  Future<void> loadScheduledWorkout() async{
    final result = await FS.list.filter<ScheduledWorkout>(ScheduledWorkout)
        .whereEqualTo('workoutId', widget.workout.id)
        .fetch();

    if(result.items.isNotEmpty){
      scheduledWorkout = result.items.first;
    }
  }

  Future<void> loadFeedback() async{
    final result = await FS.list.allOfClass<WorkoutExerciseFeedback>(WorkoutExerciseFeedback);

    feedbackMap = {
      for (var f in result) f.workoutExerciseId: f
    };
  }



  String getExerciseType(WorkoutExercises we) {
    if(we.distance != null) return 'AEROBIC';
    if(we.durationOfTimedSet != null && we.sets != null) return 'CARDIO_PLYO';
    if(we.durationOfTimedSet != null && we.sets == null) return 'STRETCHING';
    return 'STRENGTH';
  }
//function to fit whole route of aerobic exercise in image
  void fitRouteOnMap(List<LatLng> points){
    if(points.isEmpty || mapController == null) return;
    if(points.length < 2) return;


    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for(var point in points){
      if(point.latitude < minLat) minLat = point.latitude;
      if(point.latitude > maxLat) maxLat = point.latitude;
      if(point.longitude < minLng) minLng = point.longitude;
      if(point.longitude > maxLng) maxLng = point.longitude;
    }

    final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
    mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 20));
  }
//calculate pace of user in aerobic exercise according to time for distance covered and distance covered
  String calculatePace(double? distanceKm, int? timeSeconds){
    if(distanceKm == null || timeSeconds == null || distanceKm == 0){
      return '--';
    }
    final paceSecondsPerKm = timeSeconds / distanceKm;

    final minutes = paceSecondsPerKm ~/ 60;
    final seconds = (paceSecondsPerKm % 60).round();

    return '$minutes:${seconds.toString().padLeft(2,'0')} min/km';
  }
  @override
  Widget build(BuildContext context) {
    if(scheduledWorkout == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
      return Scaffold(
        appBar: AppBar(
          title: const Text('Workout Summary'),
          centerTitle: true,
        ),
         body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Container( padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.green,borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.emoji_events_rounded,color: Colors.white,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(widget.workout.name,
                            style: TextStyle(fontSize: 16,fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text('Duration: ${formatDuration2(scheduledWorkout!.totalDuration ?? 0)}',
                            style: TextStyle(fontSize: 13,color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Expanded(child: ListView.builder(
                itemCount: widget.exercises.length,
                  itemBuilder:(context,index){
                  final we = widget.exercises[index];
                  final feedback = feedbackMap[we.id];
                  final type = getExerciseType(we);

                  return buildExercisesCard(we,feedback,type);
                  }))
            ],
          )
        )
      );

  }
  //widget to display exercise name and includes other widget for exercise details
  Widget buildExercisesCard(WorkoutExercises we, WorkoutExerciseFeedback? feedback, String type){
    final exerciseName = exerciseMap[we.exerciseId]?.name ?? 'Exercise';
    final symbol = getExerciseStatusSymbol(we, feedback, type);
    return Container (width: double.infinity,padding: EdgeInsets.all(12),
      margin: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08),blurRadius: 15,offset: Offset(0,8)),],
        border: Border.all(color: Colors.grey,width: 1.2),
      ),
      child: Column(
        children: [
        Text(
          '$exerciseName $symbol',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Divider(height: 10),
        buildExerciseDetails(type, we, feedback),
      ],
      ),
    );
  }

//function to measure total weight lifted form reps done in sets that included weights
  double calculateActualWeightLifted(WorkoutExercises we) {
    if (we.actualSetWeights == null || we.actualSetWeights!.isEmpty) return 0;

    //total weight lifted calculation
    double actualTotal = 0;
    for (int i = 0; i < we.actualSetWeights!.length; i++) {
      if (we.actualSetWeights![i] > 0) {
        actualTotal += we.actualSetWeights![i] * we.repetitions!;
      }
    }

    return actualTotal;
  }
  //widget that displays details like sets completed, reps completed, duration ,distance covered depending on what type of exercise it is
  Widget buildExerciseDetails(String type,WorkoutExercises we,WorkoutExerciseFeedback? feedback)
  {
    switch (type){
      case 'STRENGTH':
        double totalWeightLifted = 0;
        if (we.actualSetWeights != null) {
          for (var weight in we.actualSetWeights!) {
            totalWeightLifted += weight;
          }
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('Sets completed: ${feedback?.setsCompleted ?? 0} / ${we.sets ?? 0}'),
            Text('Reps completed: ${we.repsCompleted ?? 0}'),
             if(totalWeightLifted != 0)Text('Total weight lifted: ${calculateActualWeightLifted(we)} kg' ),
          ],
        );

      case 'CARDIO_PLYO':
        return Column (
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('Sets completed: ${feedback?.setsCompleted ?? 0} / ${we.sets ?? 0 }'),
          ],
        );

      case 'AEROBIC':
        if(we.routePoints != null && we.routePoints!.isNotEmpty) {
          final routePoints = we.routePoints!
              .map((p) => parseLatLng(p))
              .toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('Target distance: ${we.distance ?? 0} km'),
              Text('Distance covered: ${(feedback?.distanceCovered ?? 0).toStringAsFixed(2)} km'),
              Text('Moving time: ${formatDuration2(
                  feedback?.timeForDistanceCovered ?? 0)}'),
              Text(
                'Pace: ${calculatePace(feedback?.distanceCovered,feedback?.timeForDistanceCovered,
                )}',
              ),

              if(we.routePoints != null && we.routePoints!.isNotEmpty)
                SizedBox(
                  height: 200, child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                      target: parseLatLng(we.routePoints!.first), zoom: 15),
                  polylines: {Polyline(
                    polylineId: const PolylineId('route'),
                    color: Colors.blue,
                    width: 5,
                    points: we.routePoints!.map((p) => parseLatLng(p)).toList(),
                  ),
                  },
                  //markers: markers,
                  zoomControlsEnabled: false,
                  myLocationEnabled: false,
                  onMapCreated: (controller) {
                    mapController = controller;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final points = we.routePoints!.map((p) => parseLatLng(p)).toList();
                      fitRouteOnMap(points);
                    });
                  },
                ),
                ),
            ],
          );
        }else{
          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('Target distance: ${we.distance ?? 0} km'),
              Text('Distance covered: ${feedback?.distanceCovered ?? 0} km'),
              Text('Time ${formatDuration2(feedback?.timeForDistanceCovered ?? 0)}'),
            Text(
            'Pace: ${calculatePace(feedback?.distanceCovered,feedback?.timeForDistanceCovered,
            )}',),
            ],
          );
        }

      case 'STRETCHING':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('Completed: ${feedback?.stretchingCompleted == true ? 'Yes' : 'No'}'),
          ],
        );
      default:
        return const SizedBox();
    }
  }
  LatLng parseLatLng(String value) {
    final parts = value.split(',');
    return LatLng(
      double.parse(parts[0]),
      double.parse(parts[1]),
    );
  }
  //according to statistics display appropriate icon for type of exercise
  String getExerciseStatusSymbol(WorkoutExercises we, WorkoutExerciseFeedback? feedback, String type){
    switch(type){
      case 'STRENGTH':
      case 'CARDIO_PLYO':
        final totalSets = we.sets ?? 0;
        final completed = feedback?.setsCompleted ?? 0;
        if(totalSets == 0) return '';
        final percent = completed / totalSets * 100;
        if(percent <= 33.333) return '❌';
        if(percent > 33.333 && percent <= 70) return '⚠️';
        return '✅';

      case 'STRETCHING':
        return feedback?.stretchingCompleted == true ? '✅' : '❌';
      case 'AEROBIC':
        final target = we.distance ?? 0;
        final covered = feedback?.distanceCovered ?? 0;
        if(target == 0) return '';
        final percent = covered / target * 100;
        if(percent >= 100) return '✅';
        if(percent >= 70 && percent < 100) return '⚠️';
        return '❌';
      default:
        return '';
    }
  }
}