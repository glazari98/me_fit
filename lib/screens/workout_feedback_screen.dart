import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:me_fit/models/scheduled_workout.dart';
import 'package:me_fit/models/workoutExerciseFeedback.dart';
import 'package:me_fit/models/workoutExercises.dart';


import '../models/exercise.dart';
import '../models/workout.dart';

class WorkoutFeedbackScreen extends StatefulWidget {
  final Workout workout;
  final List<WorkoutExercises> exercises;

  const WorkoutFeedbackScreen({
    super.key,
    required this.workout,
    required this.exercises,
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

  Future<void> loadData() async {
    await loadScheduledWorkout();
    await loadFeedback();
    await loadExercises();
    setState((){});
  }

  Future<void> loadExercises() async{
    final result = await FS.list.allOfClass<Exercise>(Exercise);

    exerciseMap = {
      for(var e in result) e.id : e
    };
  }
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

  String formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2,'0')}';
  }

  String getExerciseType(WorkoutExercises we) {
    if(we.distance != null) return 'AEROBIC';
    if(we.duration != null && we.sets != null) return 'CARDIO_PLYO';
    if(we.duration != null && we.sets == null) return 'STRETCHING';
    return 'STRENGTH';
  }

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
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)
                ),
                child: Padding(padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      widget.workout.name,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text('Total Duration: ${formatDuration(scheduledWorkout!.totalDuration ?? 0)}',
                    style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 6),
                    const Text(
                      "Completed Successfully!!",
                      style: TextStyle(color: Colors.green,fontWeight: FontWeight.bold),
                    )
                  ],
                )),
              ),
              const SizedBox(height: 20),
              Expanded(child: ListView.builder(
                itemCount: widget.exercises.length,
                  itemBuilder:(context,index){
                  final we = widget.exercises[index];
                  final feedback = feedbackMap[we.id];
                  final type = getExerciseType(we);

                  return buildExerciseCard(we,feedback,type);
                  }))
            ],
          )
        )
      );

  }

  Widget buildExerciseCard(WorkoutExercises we, WorkoutExerciseFeedback? feedback, String type){
    final exerciseName = exerciseMap[we.exerciseId]?.name ?? 'Exercise';
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
               exerciseName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            buildExerciseDetails(type, we, feedback),
          ],
        ),
      ),
    );
  }

  Widget buildExerciseDetails(String type,WorkoutExercises we,WorkoutExerciseFeedback? feedback,
      )
  {
    switch (type){
      case 'STRENGTH':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sets: ${feedback?.setsCompleted ?? 0} / ${we.sets ?? 0}'),
            Text('Reps completed: ${we.repsCompleted ?? 0}'),
          ],
        );

      case 'CARDIO_PLYO':
        return Column (
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sets: ${feedback?.setsCompleted ?? 0} / ${we.sets ?? 0 }'),
          ],
        );

      case 'AEROBIC':
        if(we.routePoints != null && we.routePoints!.isNotEmpty) {
          final routePoints = we.routePoints!
              .map((p) => parseLatLng(p))
              .toList();
            //bug regarding markers
            // final Set<Marker> markers = <Marker> {
            //   Marker(markerId:  MarkerId('start'),
            //       position: routePoints.first,
            //       infoWindow:  InfoWindow(title: 'Start')
            //       ),
            //   Marker(markerId:  MarkerId('end'),
            //       position: routePoints.last,
            //       infoWindow:  InfoWindow(title: 'End'),
            //       ),
            // };

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Target distance: ${we.distance ?? 0} km'),
              Text('Distance covered: ${feedback?.distanceCovered ?? 0} km'),
              Text('Time ${formatDuration(
                  feedback?.timeForDistanceCovered ?? 0)}'),
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
                    Future.delayed(const Duration(milliseconds: 300), () {
                      final points = we.routePoints!
                          .map((p) => parseLatLng(p))
                          .toList();
                      fitRouteOnMap(points);
                    });
                  },
                ),
                ),
            ],
          );
        }else{
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Target distance: ${we.distance ?? 0} km'),
              Text('Distance covered: ${feedback?.distanceCovered ?? 0} km'),
              Text('Time ${formatDuration(feedback?.timeForDistanceCovered ?? 0)}'),
            ],
          );
        }

      case 'STRETCHING':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
}