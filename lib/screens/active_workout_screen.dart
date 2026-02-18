import 'dart:async';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:firestorm/firestorm.dart';
import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/models/bodyPart.dart';
import 'package:me_fit/models/workout.dart';
import 'package:me_fit/models/exercise.dart';
import 'package:me_fit/models/exerciseType.dart';
import 'package:me_fit/models/scheduled_workout.dart';
import 'package:me_fit/models/workoutExerciseFeedback.dart';
import 'package:me_fit/models/workoutExercises.dart';
import 'package:me_fit/screens/workout_feedback_screen.dart';
import 'package:me_fit/screens/exercise_details_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';



class ActiveWorkoutScreen extends StatefulWidget{
  final Workout workout;

  const ActiveWorkoutScreen({super.key, required this.workout});

  @override
  State<ActiveWorkoutScreen> createState() => ActiveWorkoutScreenState();
}
enum ExercisePhase {
  idle,
  activeSet,
  rest,
  completed,
}
class ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  bool isTransitioning = false;

  List<WorkoutExercises> workoutExercises = [];
  Map<String, Exercise> exerciseMap = {};

  int currentIndex = 0;
  //workout timer
  int elapsedSeconds = 0;
  Timer? workoutTimer;
  int aerobicStartSeconds = 0;
  bool workoutTimerStarted = false;
  //exercise state
  ExercisePhase phase = ExercisePhase.idle;
  int currentSet = 1;
  int remainingSeconds = 0;
  Timer? phaseTimer;
  bool isLastSetRest = false;

  List<BodyPart> bodyParts = [];
  List<ExerciseType> exerciseTypes = [];
  List<LatLng> route = [];
  bool hasLocationPermission = false;
  LatLng? currentPosition;
  StreamSubscription<Position>? positionStream;
  GoogleMapController? mapController;

  @override
  void initState(){
    super.initState();
    loadWorkout();
    loadData();
  }
  Future<void> loadData() async {
    final bodyPartsResult = await FS.list.allOfClass<BodyPart>(BodyPart);

    final exerciseTypesResult = await FS.list.allOfClass<ExerciseType>(
        ExerciseType);
    if (!mounted) return;
    setState(() {
      bodyParts = bodyPartsResult;
      exerciseTypes = exerciseTypesResult;
    });
  }
  Future<void> loadWorkout() async {
    final weResult = await FS.list.filter<WorkoutExercises>(WorkoutExercises)
                                    .whereEqualTo('workoutId', widget.workout.id)
                                     .fetch();
    weResult.items.sort((a,b) =>a.order.compareTo(b.order));
    workoutExercises = weResult.items;

    final exResult = await FS.list.filter<Exercise>(Exercise).fetch();

    exerciseMap = {
      for (var e in exResult.items) e.id: e,

    };

    setState(() {});
  }
  void startWorkoutTimer(){
    if(workoutTimerStarted) return;
    workoutTimerStarted = true;
    workoutTimer = Timer.periodic(const Duration(seconds: 1), (_){
      setState(()=> elapsedSeconds++);
    });
  }

  //helper functions

  WorkoutExercises get we => workoutExercises[currentIndex];
  Exercise get ex => exerciseMap[we.exerciseId]!;

  String getExerciseType(WorkoutExercises we){
    if(we.distance != null) return 'AEROBIC';
    if(we.duration != null && we.sets != null) return 'CARDIO_PLYO';
    if(we.duration != null && we.sets == null) return 'STRETCHING';
    return 'STRENGTH';
  }

  void moveToNextExercise(){
    phaseTimer?.cancel();
    phase = ExercisePhase.idle;
    currentSet = 1;

    if(currentIndex < workoutExercises.length - 1){
      setState(() => currentIndex++);
    } else{
      finishWorkout();
    }
  }
  void completeExercise() {
    if(currentIndex < workoutExercises.length -1){
      setState(() => currentIndex++);
    } else {
      finishWorkout();
    }
  }
  String formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${hours.toString().padLeft(2,'0')}:${minutes.toString().padLeft(2,'0')}:${secs.toString().padLeft(2,'0')}';
  }
  Future<void> finishWorkout() async {
    workoutTimer?.cancel();
    phaseTimer?.cancel();

    for(var we in workoutExercises){
      final feedback = WorkoutExerciseFeedback(
          id: Firestorm.randomID(),
          workoutExerciseId: we.id,
          setsCompleted: we.setsCompleted,
          repsCompleted: we.repsCompleted,
          distanceCovered: we.distanceCovered,
          timeForDistanceCovered: we.timeForDistanceCovered,
          stretchingCompleted: we.stretchingCompleted);
        await FS.create.one(feedback);
    }
    final scheduled = await FS.list.filter<ScheduledWorkout>(ScheduledWorkout)
                              .whereEqualTo('workoutId', widget.workout.id)
                              .fetch();
    if(scheduled.items.isNotEmpty){
      final sw = scheduled.items.first;
      sw.isCompleted = true;
      sw.totalDuration = elapsedSeconds;
      sw.completedDate = DateTime.now();

      await FS.update.one(sw);
    }
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => WorkoutFeedbackScreen(
              workout: widget.workout,
              exercises: workoutExercises,
            ),
        ),
    );
  }

  //logic for strength
  void startStrengthSet(){
    startWorkoutTimer();
    setState(() {
      phase = ExercisePhase.activeSet;
      currentSet = (we.setsCompleted ?? 0) + 1;
    });
  }

  void completeStrengthSet() async{
    setState(() => isTransitioning = true);
    await Future.delayed(const Duration(milliseconds: 500));

    we.setsCompleted = (we.setsCompleted ?? 0) +1;
    we.repsCompleted = (we.repsCompleted ?? 0) + (we.repetitions ?? 0);

    await FS.update.one(we);
    setState(() =>isTransitioning = false);
    if(we.setsCompleted! >= we.sets!){
      startRest(we.restBetweenSets!,postExercise: true);
    }else{
      startRest(we.restBetweenSets!);
    }
  }

  //cardio-plyo logic
  void startTimedSet() {
    startWorkoutTimer();

    phase = ExercisePhase.activeSet;
    remainingSeconds = we.duration!;

    phaseTimer?.cancel();
    phaseTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      setState(() => remainingSeconds--);
      if(remainingSeconds <= 0) {
        t.cancel();

        we.setsCompleted = (we.setsCompleted ?? 0) +1;
        FS.update.one(we);

        if(we.setsCompleted! >= we.sets!){
          startRest(we.restBetweenSets!, postExercise: true);
        }else {
          startRest(we.restBetweenSets!);
        }
      }
    });
  }


  //aerobic logic
  Future<void> startAerobicTracking() async {
    startWorkoutTimer();
    await positionStream?.cancel();
    route.clear();
    currentPosition = null;
    aerobicStartSeconds = elapsedSeconds;
    phase = ExercisePhase.activeSet;

    bool locationServiceEnabled = await Geolocator.isLocationServiceEnabled();

    if(!locationServiceEnabled){
      setState(() {
        hasLocationPermission = false;
      });
      return;
    }
    LocationPermission permission = await Geolocator.requestPermission();
    if(permission == LocationPermission.denied){
      permission = await Geolocator.requestPermission();
    }
    if(permission == LocationPermission.deniedForever || permission ==LocationPermission.denied){
      setState(() {
        hasLocationPermission = false;
      });
      return;
    }
    setState(() {
      hasLocationPermission = true;
    });
    route.clear();
    final position = await Geolocator.getCurrentPosition();
    final point = LatLng(position.latitude, position.longitude);

    setState(() {
      currentPosition = point;
      route.add(point);
    });
    mapController?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: point,zoom: 15)));


    positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high, distanceFilter: 5
      )
    ).listen((Position position){
      final newPoint = LatLng(position.latitude, position.longitude);
      setState(() {
        route.add(newPoint);
      });
      mapController?.animateCamera(CameraUpdate.newLatLng(newPoint));
    });
    setState(() {});
  }
  Future<void> finishAerobicTracking() async {
    positionStream?.cancel();

    final distance = await Geolocator.distanceBetween(
        route.first.latitude, route.first.longitude, route.last.latitude, route.last.longitude);

    we.distanceCovered = distance / 1000;

    we.timeForDistanceCovered = elapsedSeconds - aerobicStartSeconds;

    we.routePoints = route.map((e) => '${e.latitude},${e.longitude}').toList();
    fitRouteOnMap();
    await FS.update.one(we);
    moveToNextExercise();
  }

  void completeAerobic(double distanceCovered) async {
    we.distanceCovered = distanceCovered;
    we.timeForDistanceCovered = elapsedSeconds;

    await FS.update.one(we);
    moveToNextExercise();
  }
  void fitRouteOnMap(){
    if(route.isEmpty || mapController == null) return;

    double minLat = route.first.latitude;
    double maxLat = route.first.latitude;
    double minLng = route.first.longitude;
    double maxLng = route.first.longitude;

    for(var point in route){
      if(point.latitude < minLat) minLat = point.latitude;
      if(point.latitude > maxLat) maxLat = point.latitude;
      if(point.longitude < minLng) minLng = point.longitude;
      if(point.longitude > maxLng) maxLng = point.longitude;
    }

    final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
    mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }
  //stretching logic
  void startStretching(){
    startWorkoutTimer();

    phase = ExercisePhase.activeSet;
    remainingSeconds = we.duration!;

    phaseTimer?.cancel();
    phaseTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => remainingSeconds--);
      if (remainingSeconds <= 0) {
        t.cancel();

        we.stretchingCompleted = true;
        FS.update.one(we);
        moveToNextExercise();
      }
    });
  }


  //rest
  void startRest(int seconds, {bool postExercise = false}){
    phase = ExercisePhase.rest;
    remainingSeconds = seconds;
    isLastSetRest = postExercise;

    phaseTimer?.cancel();

    phaseTimer = Timer.periodic(const Duration(seconds: 1), (t){
      setState(() =>remainingSeconds--);
      if(remainingSeconds <= 0){
        t.cancel();
      if(isLastSetRest){
        isLastSetRest = false;
        moveToNextExercise();
        return;
      }
        final type = getExerciseType(we);

        if(type == 'CARDIO_PLYO') {
          startTimedSet();
        }
        phase = ExercisePhase.activeSet;
        currentSet++;

      }
    });
  }

  @override
  Widget build(BuildContext context){
    if(workoutExercises.isEmpty || exerciseMap.isEmpty){
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final progress = (currentIndex + 1) / workoutExercises.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workout.name),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context,true),
              child: const Text('Cancel',style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Workout time: ',
                    style: const TextStyle(fontSize: 13, letterSpacing: 2),
                  ),
                  Text(
                    formatDuration(elapsedSeconds),
                    style: const TextStyle(fontSize:34,fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 20),


              buildExerciseControls(),

            ],
          ) ,
      ),
    );
  }

 Widget buildExerciseControls() {
   if(isTransitioning){
     return const Center(
       child: CircularProgressIndicator(),
     );
   }
  final type = getExerciseType(we);

  if(phase == ExercisePhase.rest){
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Lets take a break...',style: TextStyle(fontWeight: FontWeight.bold,fontSize: 24)),
          const SizedBox(height: 30),
          SizedBox(width: 200, height: 200,
              child: CircularPercentIndicator(
                  radius: 100, lineWidth: 18,
                  percent: remainingSeconds / we.restBetweenSets!,
                  center: Text('$remainingSeconds',style: const TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.bold)),
                  circularStrokeCap: CircularStrokeCap.round,
                  progressColor: Colors.blue,
                  backgroundColor: Colors.grey.shade300,
                  animation: false,
                  animateFromLastPercent: true,
                  animationDuration: 500)),
          const SizedBox(height: 20),
          Image.asset("assets/images/rest-up-rest.gif", height:200,width:200),
        ],
      )
    );

  }
  switch(type){
    case 'STRENGTH':
      if (phase == ExercisePhase.idle) {
        return Column(
          children: [
            buildExerciseInfoCard(
              children: [
                Text(
                  'Exercise ${currentIndex + 1} / ${workoutExercises.length}',
                  style: const TextStyle(
                    fontSize: 13,
                    letterSpacing: 2,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  ex.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(height: 30),
                Text('Sets: ${we.sets}', style: const TextStyle(fontSize: 16)),
                Text('Repetitions: ${we.repetitions}', style: const TextStyle(fontSize: 16)),
                Text('Rest: ${we.restBetweenSets} sec', style: const TextStyle(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange,
                    elevation: 6,shadowColor: Colors.green.withOpacity(0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                onPressed: (){
                    Navigator.push(context,MaterialPageRoute(builder: (_) =>ExerciseDetailsScreen(exercise: ex, bodyParts: bodyParts, exerciseTypes: exerciseTypes)));
                },
                child: const Text('View Exercise',style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,color: Colors.black)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity,height: 60,
            child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green,
                elevation: 6,shadowColor: Colors.green.withOpacity(0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: startStrengthSet,
                child: const Text('Start Exercise',
                    style: TextStyle(fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,color: Colors.black))))
          ],
        );
      }

      if(phase == ExercisePhase.activeSet){
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset("assets/images/cat-meme.gif",height: 200,width: 200,
            ),
            buildExerciseInfoCard(
              children: [
                Text('Exercise ${currentIndex + 1} / ${workoutExercises.length}',
                    style: TextStyle(fontSize: 13,letterSpacing: 2,color: Colors.grey)),
                const SizedBox(height: 6),
                Text(ex.name,textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22,fontWeight: FontWeight.bold)),
                const Divider(height: 30),
                Text('Set $currentSet /  ${we.sets}'),
                Text('Repetitions: ${we.repetitions}'),
              ],
            ),

            const SizedBox(height: 16),
            SizedBox(width: double.infinity,height: 60,
                child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green,
                      elevation: 6,shadowColor: Colors.green.withOpacity(0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: completeStrengthSet,
                    child: const Text('I completed the set',
                        style: TextStyle(fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,color: Colors.black))))

          ],
        );
      }
      return const SizedBox();
    case 'CARDIO_PLYO':
      if(phase == ExercisePhase.idle) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            buildExerciseInfoCard(
              children: [
                Text('Exercise ${currentIndex + 1} / ${workoutExercises.length}',
                    style: TextStyle(fontSize: 13,letterSpacing: 2,color: Colors.grey)),
                Text(ex.name,textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22,fontWeight: FontWeight.bold)),
                const Divider(height: 30),
                Text('Sets:${we.sets}'),
                Text('Duration of set: ${we.duration} s'),
              ],
            ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange,
                  elevation: 6,shadowColor: Colors.green.withOpacity(0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: (){
                  Navigator.push(context,MaterialPageRoute(builder: (_) =>ExerciseDetailsScreen(exercise: ex, bodyParts: bodyParts, exerciseTypes: exerciseTypes)));
                },
                child: const Text('View Exercise',style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,color: Colors.black)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity,height: 60,
                child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green,
                      elevation: 6,shadowColor: Colors.green.withOpacity(0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: startTimedSet, child: const Text('Start Exercise',style: TextStyle(fontSize: 18,fontWeight: FontWeight.bold,letterSpacing: 1,color: Colors.black))))
          ],
        );
      }
      if(phase == ExercisePhase.activeSet) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset("assets/images/cat-meme.gif",height: 200,width: 200,
            ),
            buildExerciseInfoCard(
              children: [
                Text('Exercise ${currentIndex + 1} / ${workoutExercises.length}',
                    style: TextStyle(fontSize: 13,letterSpacing: 2,color: Colors.grey)),
                const SizedBox(height: 6),
                Text(ex.name,textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22,fontWeight: FontWeight.bold)),
                Text('Set: $currentSet / ${we.sets}')
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(width: 300, height: 300,
              child: CircularPercentIndicator(
                  progressColor: Colors.green,
                  radius: 100, lineWidth: 18,
                  percent: remainingSeconds / we.duration!,
                  center: Text('$remainingSeconds',style: const TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.bold)),
                  circularStrokeCap: CircularStrokeCap.round,
                  backgroundColor: Colors.grey.shade300,
                  animation: false,
                  animateFromLastPercent: true,
                  animationDuration: 500)),

          ],
        );
      }
      return const SizedBox();
    case 'AEROBIC':
      if(phase == ExercisePhase.idle) {
        return Column(
          children: [
            buildExerciseInfoCard(
              children: [
                Text('Exercise ${currentIndex + 1} / ${workoutExercises.length}',
                    style: TextStyle(fontSize: 13,letterSpacing: 2,color: Colors.grey)),
                const SizedBox(height: 6),
                Text(ex.name,textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22,fontWeight: FontWeight.bold)),
                const Divider(height: 30),
                Text('Target distance: ${we.distance} km'),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange,
                  elevation: 6,shadowColor: Colors.green.withOpacity(0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: (){
                  Navigator.push(context,MaterialPageRoute(builder: (_) =>ExerciseDetailsScreen(exercise: ex, bodyParts: bodyParts, exerciseTypes: exerciseTypes)));
                },
                child: const Text('View Exercise',style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,color: Colors.black)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity,height: 60,
                child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green,
                      elevation: 6,shadowColor: Colors.green.withOpacity(0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: startAerobicTracking, child: const Text('Start Exercise',style: TextStyle(fontSize: 18,fontWeight: FontWeight.bold,letterSpacing: 1,color: Colors.black))))
          ],
        );
      }
      if(phase == ExercisePhase.activeSet) {
        return Column(
              children: [
                      buildExerciseInfoCard(
                      children: [
                      Text('Exercise ${currentIndex + 1} / ${workoutExercises.length}',
                      style: TextStyle(fontSize: 13,letterSpacing: 2,color: Colors.grey)),
                      const SizedBox(height: 6),
                      Text(ex.name,textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22,fontWeight: FontWeight.bold)),
                      const Divider(height: 30),
                      Text('Target distance: ${we.distance} km'),
                ],
                ),
                const SizedBox(height: 12),
                hasLocationPermission ?
                SizedBox(height:250,width: double.infinity,
                  child: ClipRect(
                  child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                          target: currentPosition ?? const LatLng(0, 0),zoom: 15),
                  onMapCreated: (controller){
                        mapController = controller;
                  },
                  polylines: {Polyline(
                      polylineId: const PolylineId('route'),
                      color: Colors.blue,
                      width: 6,
                      points: route
                  ),
                  },
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                  ),
                )) : const SizedBox(),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity,height: 60,
                    child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        ),
                        onPressed: finishAerobicTracking,
                        child: const Text('Finish Exercise',
                        style: TextStyle(fontSize: 18,fontWeight: FontWeight.bold, color: Colors.black))))
              ],
            );
      }
      return const SizedBox();
    case 'STRETCHING':
      if(phase == ExercisePhase.idle) {
        return Column(
          children: [
            buildExerciseInfoCard(
              children: [
                Text('Exercise ${currentIndex + 1} / ${workoutExercises.length}',
                    style: TextStyle(fontSize: 13,letterSpacing: 2,color: Colors.grey)),
                const SizedBox(height: 6),
                Text(ex.name,textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22,fontWeight: FontWeight.bold)),
                const Divider(height: 30),
                Text('Duration: ${we.duration} s'),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange,
                  elevation: 6,shadowColor: Colors.green.withOpacity(0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: (){
                  Navigator.push(context,MaterialPageRoute(builder: (_) =>ExerciseDetailsScreen(exercise: ex, bodyParts: bodyParts, exerciseTypes: exerciseTypes)));
                },
                child: const Text('View Exercise',style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,color: Colors.black)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity,height: 60,
                child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green,
                      elevation: 6,shadowColor: Colors.green.withOpacity(0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: startStretching, child: const Text('Start Stretching',style: TextStyle(fontSize: 18,fontWeight: FontWeight.bold,letterSpacing: 1,color: Colors.black))))
          ],
        );
      }
      if(phase == ExercisePhase.activeSet) {
        return Column(
          children: [
            Image.asset("assets/images/cat-doing-the-sun-greeting.gif",height: 200,width: 200,
            ),
            const SizedBox(height: 20),
            buildExerciseInfoCard(
              children: [
                Text('Exercise ${currentIndex + 1} / ${workoutExercises.length}',
                    style: TextStyle(fontSize: 13,letterSpacing: 2,color: Colors.grey)),
                const SizedBox(height: 6),
                Text(ex.name,textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22,fontWeight: FontWeight.bold))
              ],
            ),
            SizedBox(width: 300, height: 300,
              child: CircularPercentIndicator(
                radius: 100, lineWidth: 18,
                percent: remainingSeconds / we.duration!,
                center: Text('$remainingSeconds',style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold)),
                circularStrokeCap: CircularStrokeCap.round,
                progressColor: Colors.green,
                backgroundColor: Colors.grey.shade300,
                animation: false,
                animateFromLastPercent: true,
                animationDuration: 500)),
          ],
        );
      }
      return const SizedBox();
    default: return SizedBox();
  }
 }

 Future<void> showAerobicDistanceDialog() async{
    final controller = TextEditingController();

    final result = await showDialog<double>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Distance covered'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Distance (km)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
                onPressed: (){
                  final value = double.tryParse(controller.text);
                  if(value != null){
                    Navigator.pop(context,value);
                  }
                },
                child: const Text('Confirm'))
          ],
        ));
    if(result != null){
      completeAerobic(result);
    }
 }
  @override
  void dispose(){
    workoutTimer?.cancel();
    phaseTimer?.cancel();
    super.dispose();
  }
}

Widget buildExerciseInfoCard({required List<Widget> children}) {
  return Container(width: double.infinity, padding: const EdgeInsets.all(20),
    margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow( color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 8),
        ),
      ],
      border: Border.all( color: Colors.grey.shade500, width: 1.2,
      ),
    ),
    child: Column( crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    ),
  );
}
