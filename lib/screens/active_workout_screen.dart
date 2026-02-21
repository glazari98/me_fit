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
  final ScheduledWorkout scheduledWorkout;

  const ActiveWorkoutScreen({super.key, required this.workout, required this.scheduledWorkout});

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
  int elapsedSeconds = 0;
  Timer? workoutTimer;
  int aerobicStartSeconds = 0;
  bool workoutTimerStarted = false;
  ExercisePhase phase = ExercisePhase.idle;
  int currentSet = 1;
  int remainingSeconds = 0;
  Timer? phaseTimer;
  bool isLastSetRest = false;
  bool isPaused = false;


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
    loadData();
    loadWorkout().then((_) {
      restoreProgress();
    });
  }

  Future<void> loadData() async {
    final bodyPartsResult = await FS.list.allOfClass<BodyPart>(BodyPart);
    final exerciseTypesResult = await FS.list.allOfClass<ExerciseType>(ExerciseType);
    if (!mounted) return;
    setState(() {
      bodyParts = bodyPartsResult;
      exerciseTypes = exerciseTypesResult;
    });
  }

  void restoreProgress() async {
    final scheduledWorkout = widget.scheduledWorkout;
    if(scheduledWorkout.isInProgress != true) return;

    currentIndex = scheduledWorkout.currentExerciseIndex!;
    currentSet = scheduledWorkout.currentSet!;
    elapsedSeconds = scheduledWorkout.elapsedSeconds!;
    remainingSeconds = scheduledWorkout.remainingSeconds!;
    phase = ExercisePhase.values.firstWhere((e) => e.name == scheduledWorkout.currentPhase,orElse: () => ExercisePhase.idle);
    isPaused = true;
    workoutTimerStarted = true;

    if(phase == ExercisePhase.activeSet && getExerciseType(we) == 'AEROBIC'){
      await reinitialiseAerobic();
    }
    setState(() {});
  }

  Future<void> reinitialiseAerobic() async {
    final currentWorkoutExercises = we;
    if(currentWorkoutExercises.routePoints != null && currentWorkoutExercises.routePoints!.isNotEmpty) {
      route = currentWorkoutExercises.routePoints!.map((s) {
        final parts = s.split(',');
        return LatLng(double.parse(parts[0]), double.parse(parts[1]));
      }).toList();
    }else{
      route = [];
    }
    aerobicStartSeconds = widget.scheduledWorkout.aerobicStartSeconds ?? elapsedSeconds;
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => hasLocationPermission = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if(permission == LocationPermission.denied){
      permission = await Geolocator.requestPermission();
    }
    if(permission == LocationPermission.denied || permission == LocationPermission.deniedForever){
      if(mounted) setState(() => hasLocationPermission = false);
      return;
    }
    try {
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final point = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          hasLocationPermission = true;
          currentPosition = point;
        });
        mapController?.animateCamera(CameraUpdate.newLatLng(point));
      }
    } catch (_) {
      if (mounted) setState(() => hasLocationPermission = false);
    }
  }

  Future<void> loadWorkout() async {
    final workoutExercisesResult = await FS.list.filter<WorkoutExercises>(WorkoutExercises)
        .whereEqualTo('workoutId', widget.workout.id)
        .fetch();
    workoutExercisesResult.items.sort((a,b) => a.order.compareTo(b.order));
    workoutExercises = workoutExercisesResult.items;

    final exercisesResult = await FS.list.filter<Exercise>(Exercise).fetch();
    exerciseMap = {
      for (var e in exercisesResult.items) e.id: e,
    };
    setState(() {});
  }

  void pauseWorkout() {
    if(isPaused) return;
    workoutTimer?.cancel();
    phaseTimer?.cancel();
    positionStream?.pause();
    setState(() => isPaused = true);
  }

  void resumeWorkout() {
    if(!isPaused) return;

    if(workoutTimerStarted){
      workoutTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => elapsedSeconds++);
      });

      if((phase == ExercisePhase.activeSet || phase == ExercisePhase.rest) && remainingSeconds > 0) {
        phaseTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
          setState(() => remainingSeconds--);
          if(remainingSeconds <= 0){
            t.cancel();
            if(phase == ExercisePhase.rest){
              finishRest();
            }else if(getExerciseType(we) == 'CARDIO_PLYO'){
              we.setsCompleted = (we.setsCompleted ?? 0) + 1;
              await FS.update.one(we);
              if(currentSet >= (we.sets ?? 1)){
                startRest(we.restBetweenSets ?? 0, postExercise: true);
              }else{
                setState(() => currentSet++);
                startRest(we.restBetweenSets ?? 0);
              }
            }else if(getExerciseType(we) == 'STRETCHING'){
              we.stretchingCompleted = true;
              we.durationLasted = we.duration;
              await FS.update.one(we);
              moveToNextExercise();
            }
          }
        });
      }
      if (phase == ExercisePhase.activeSet && getExerciseType(we) == 'AEROBIC' && hasLocationPermission) {
        startAerobicPositionStream(skipFirstPoint: true);
      } else {
        positionStream?.resume();
      }
      setState(() => isPaused = false);
    }
  }

  void startWorkoutTimer(){
    if(workoutTimerStarted) return;
    workoutTimerStarted = true;
    workoutTimer = Timer.periodic(const Duration(seconds: 1), (_){
      setState(() => elapsedSeconds++);
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
    positionStream?.cancel();
    positionStream = null;
    route = [];
    currentPosition = null;
    hasLocationPermission = false;
    mapController = null;

    phase = ExercisePhase.idle;
    currentSet = 1;

    if(currentIndex < workoutExercises.length - 1){
      setState(() => currentIndex++);
    } else {
      finishWorkout();
    }
  }

  void completeExercise() {
    if(currentIndex < workoutExercises.length - 1){
      setState(() => currentIndex++);
    } else {
      finishWorkout();
    }
  }

  String formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
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
          durationLasted: we.durationLasted,
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
      sw.currentExerciseIndex = null;
      sw.currentSet = null;
      sw.elapsedSeconds = null;
      sw.remainingSeconds = null;
      sw.currentPhase = null;
      sw.isInProgress = null;
      sw.aerobicStartSeconds = null;
      await FS.update.one(sw);
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutFeedbackScreen(
          workout: widget.workout,
          exercises: workoutExercises,
        ),
      ),
    );
    Navigator.pop(context, true);
  }

  //logic for strength
  void startStrengthSet(){
    startWorkoutTimer();
    setState(() {
      phase = ExercisePhase.activeSet;
      currentSet = 1;
    });
  }

  void completeStrengthSet() async {
    setState(() => isTransitioning = true);
    await Future.delayed(const Duration(milliseconds: 500));

    we.setsCompleted = (we.setsCompleted ?? 0) + 1;
    we.repsCompleted = (we.repsCompleted ?? 0) + (we.repetitions ?? 0);

    await FS.update.one(we);
    setState(() => isTransitioning = false);
    if(currentSet >= we.sets!){
      startRest(we.restBetweenSets!, postExercise: true);
    } else {
      startRest(we.restBetweenSets!);
    }
  }

  //cardio-plyo logic
  void startTimedSet() {
    startWorkoutTimer();
    phaseTimer?.cancel();
    setState(() {
      phase = ExercisePhase.activeSet;
      remainingSeconds = we.duration ?? 0;
    });

    phaseTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      setState(() => remainingSeconds--);
      if(remainingSeconds <= 0) {
        t.cancel();
        we.setsCompleted = (we.setsCompleted ?? 0) + 1;
        await FS.update.one(we);
        if(currentSet >= (we.sets ?? 1)){
          startRest(we.restBetweenSets ?? 0, postExercise: true);
        }else{
          setState(() => currentSet++);
          startRest(we.restBetweenSets ?? 0);
        }
      }
    });
  }

//aerobic logic
  void startAerobicPositionStream({bool skipFirstPoint = false}) {
    positionStream?.cancel();
    positionStream = null;

    bool isFirstPoint = skipFirstPoint;

    positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      if (!mounted) return;
      final newPoint = LatLng(position.latitude, position.longitude);

      if(isFirstPoint){
        isFirstPoint = false;
        setState(() => currentPosition = newPoint);
        mapController?.animateCamera(CameraUpdate.newLatLng(newPoint));
        return;
      }
      setState(() {
        route.add(newPoint);
        currentPosition = newPoint;
      });
      mapController?.animateCamera(CameraUpdate.newLatLng(newPoint));
    });
  }

  Future<void> startAerobicTracking() async {
    startWorkoutTimer();

    positionStream?.cancel();
    positionStream = null;

    route = [];
    currentPosition = null;
    aerobicStartSeconds = elapsedSeconds;

    setState(() => phase = ExercisePhase.activeSet);

    bool locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if(!locationServiceEnabled){
      setState(() => hasLocationPermission = false);
      return;
    }

    LocationPermission permission = await Geolocator.requestPermission();
    if(permission == LocationPermission.denied){
      permission = await Geolocator.requestPermission();
    }
    if(permission == LocationPermission.deniedForever || permission == LocationPermission.denied){
      setState(() => hasLocationPermission = false);
      return;
    }
    setState(() => hasLocationPermission = true);

    final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    final startPoint = LatLng(position.latitude, position.longitude);
    setState(() {
      currentPosition = startPoint;
      route.add(startPoint);
    });
    mapController?.animateCamera(
        CameraUpdate.newCameraPosition(CameraPosition(target: startPoint, zoom: 15)));
    startAerobicPositionStream(skipFirstPoint: false);
  }

  Future<void> finishAerobicTracking() async {
    positionStream?.cancel();
    positionStream = null;

    double totalDistanceMeters = 0.0;
    if (route.length >= 2) {
      for (int i = 0; i < route.length - 1; i++) {
        totalDistanceMeters += await Geolocator.distanceBetween(
          route[i].latitude,route[i].longitude,route[i + 1].latitude,route[i + 1].longitude);
      }
    }

    we.distanceCovered = totalDistanceMeters/1000;
    we.timeForDistanceCovered = elapsedSeconds - aerobicStartSeconds;
    we.routePoints = route.map((e) => '${e.latitude},${e.longitude}').toList();
    fitRouteOnMap();
    await FS.update.one(we);
    moveToNextExercise();
  }

  void completeAerobic(double distanceCovered) async {
    we.distanceCovered = distanceCovered;
    we.timeForDistanceCovered = elapsedSeconds - aerobicStartSeconds;
    we.routePoints = null;
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

    final bounds = LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
    mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  //stretching logic
  void startStretching() async {
    startWorkoutTimer();
    setState((){
      phase = ExercisePhase.activeSet;
      remainingSeconds = we.duration!;
    });

    phaseTimer?.cancel();
    phaseTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) return;
      setState(() => remainingSeconds--);
      if (remainingSeconds <= 0) {
        t.cancel();
        we.stretchingCompleted = true;
        we.durationLasted = we.duration;
        await FS.update.one(we);
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
      setState(() => remainingSeconds--);
      if(remainingSeconds <= 0){
        t.cancel();
        finishRest();
      }
    });
  }

  void finishRest() {
    phaseTimer?.cancel();
    if(isLastSetRest){
      isLastSetRest = false;
      moveToNextExercise();
      return;
    }
    final type = getExerciseType(we);
    if(type == 'CARDIO_PLYO'){
      startTimedSet();
      return;
    }
    setState(() {
      phase = ExercisePhase.activeSet;
      currentSet++;
    });
  }

  Future<void> saveWorkoutProgress() async {
    final scheduled = await FS.list.filter<ScheduledWorkout>(ScheduledWorkout)
        .whereEqualTo('workoutId', widget.workout.id)
        .fetch();
    if(scheduled.items.isEmpty) return;
    final sw = scheduled.items.first;

    sw.currentExerciseIndex = currentIndex;
    sw.currentSet = currentSet;
    sw.elapsedSeconds = elapsedSeconds;
    sw.remainingSeconds = remainingSeconds;
    sw.currentPhase = phase.name;
    sw.isInProgress = true;

    if(phase == ExercisePhase.activeSet && getExerciseType(we) == 'AEROBIC'){
      sw.aerobicStartSeconds = aerobicStartSeconds;
      we.routePoints = route.map((e) => '${e.latitude},${e.longitude}').toList();
      await FS.update.one(we);
    }
    await FS.update.one(sw);
  }

  @override
  Widget build(BuildContext context){
    if(workoutExercises.isEmpty || exerciseMap.isEmpty){
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final progress = (currentIndex + 1) / workoutExercises.length;
    return WillPopScope(
      onWillPop: () async {
        await saveWorkoutProgress();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.workout.name),
          actions: [
            if(workoutTimerStarted)
              IconButton(onPressed: () async {
                if(isPaused) {
                  resumeWorkout();
                }else{
                  pauseWorkout();
                  await saveWorkoutProgress();
                }},
              icon: Icon(isPaused ? Icons.play_arrow :Icons.pause))
          ]),
        body: Padding( padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 16),
              Row( mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Workout time: ', style: TextStyle(fontSize: 13, letterSpacing: 2)),
                  Text(formatDuration(elapsedSeconds),
                      style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold)),
                ]),
              const SizedBox(height: 20),
              buildExerciseControls(),
            ]),
        )),
    );
  }

  Widget buildExerciseControls() {
    if(isTransitioning){
      return const Center(child: CircularProgressIndicator());
    }
    final type = getExerciseType(we);

    if(phase == ExercisePhase.rest){
      return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Lets take a break...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
              const SizedBox(height: 30),
              SizedBox(width: 200, height: 200,
                  child: CircularPercentIndicator(
                      radius: 100, lineWidth: 18,
                      percent: remainingSeconds / we.restBetweenSets!,
                      center: Text('$remainingSeconds', style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold)),
                      circularStrokeCap: CircularStrokeCap.round,
                      progressColor: isPaused ? Colors.grey : Colors.blue,
                      backgroundColor: Colors.grey.shade300,
                      animation: false,
                      animateFromLastPercent: true,
                      animationDuration: 500)),
              const SizedBox(height: 20),
              SizedBox(height: 60,
                child: ElevatedButton.icon(
                    icon: const Icon(Icons.skip_next, color: Colors.white),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: isPaused ? Colors.grey : Colors.orange,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    onPressed: isPaused ? null : finishRest,
                    label: const Text('Skip', style: TextStyle(fontSize: 18,fontWeight: FontWeight.bold,color: Colors.white))),)
            ])
          );
    }

    switch(type){
      case 'STRENGTH':
        if (phase == ExercisePhase.idle) {
          return Column(
            children: [
              buildExerciseInfoCard(children: [
                Text('Exercise ${currentIndex + 1} / ${workoutExercises.length}',
                    style: TextStyle(fontSize: 13, letterSpacing: 2, color: Colors.grey)),
                const SizedBox(height: 8),
                Text(ex.name, textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const Divider(height: 30),
                Text('Sets: ${we.sets}', style: TextStyle(fontSize: 16)),
                Text('Repetitions: ${we.repetitions}', style: const TextStyle(fontSize: 16)),
                Text('Rest: ${we.restBetweenSets} sec', style: const TextStyle(fontSize: 16)),
              ]),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange,
                      elevation: 6, shadowColor: Colors.green.withOpacity(0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ExerciseDetailsScreen(exercise: ex, bodyParts: bodyParts, exerciseTypes: exerciseTypes))),
                  child: const Text('View Exercise', style: TextStyle(fontSize: 16,fontWeight: FontWeight.w600,color: Colors.black)),
                )),
              const SizedBox(height: 12),
              SizedBox(width:double.infinity, height: 60,
              child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: isPaused ? Colors.grey : Colors.green,
                  elevation: 6, shadowColor: Colors.green.withOpacity(0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: isPaused ? null : startStrengthSet,
              child: const Text('Start Exercise',
                  style: TextStyle(fontSize: 18,fontWeight: FontWeight.bold,letterSpacing: 1,color: Colors.black))))
            ]);
        }
        if(phase == ExercisePhase.activeSet){
          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              buildExerciseInfoCard(children: [
                Text('Exercise ${currentIndex + 1} / ${workoutExercises.length}',
                    style: const TextStyle(fontSize: 13, letterSpacing: 2,color: Colors.grey)),
                const SizedBox(height: 6),
                Text(ex.name, textAlign: TextAlign.center,
                    style:const TextStyle(fontSize: 22,fontWeight: FontWeight.bold)),
                const Divider(height: 30),
                Text('Set: $currentSet / ${we.sets}'),
                Text('Repetitions: ${we.repetitions}'),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: SizedBox(height: 60,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.skip_next, color: Colors.white),
                    style: ElevatedButton.styleFrom(backgroundColor: isPaused ? Colors.grey : Colors.orange,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    onPressed: isPaused ? null : (){
                      phaseTimer?.cancel();
                      if(currentSet >= (we.sets ?? 1)){
                        startRest(we.restBetweenSets ?? 0, postExercise: true);
                      }else{
                        startRest(we.restBetweenSets ?? 0);
                      }},
                  label: const Text('Skip',style: TextStyle(fontSize: 18,fontWeight: FontWeight.bold,color: Colors.white))),)),
                const SizedBox(width: 12),
                Expanded(child: SizedBox(height: 60, child:
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: isPaused ? Colors.grey : Colors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: const Text('Set Completed',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  onPressed: isPaused ? null : completeStrengthSet,
                ))),
              ])
            ],
          );
        }
        return const SizedBox();

      case 'CARDIO_PLYO':
        if(phase == ExercisePhase.idle) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              buildExerciseInfoCard(children: [
                Text('Exercise ${currentIndex + 1} / ${workoutExercises.length}',
                    style: const TextStyle(fontSize: 13, letterSpacing: 2, color: Colors.grey)),
                Text(ex.name, textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const Divider(height: 30),
                Text('Sets: ${we.sets}'),
                Text('Duration of set: ${we.duration}s'),
              ]),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange,
                      elevation: 6, shadowColor: Colors.green.withOpacity(0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ExerciseDetailsScreen(exercise: ex, bodyParts: bodyParts, exerciseTypes: exerciseTypes))),
                  child: const Text('View Exercise', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, height: 60,
                  child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: isPaused ? Colors.grey : Colors.green,
                          elevation: 6, shadowColor: Colors.green.withOpacity(0.4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      onPressed: isPaused ? null : startTimedSet,
                      child: const Text('Start Exercise',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.black))))
            ],
          );
        }
        if(phase == ExercisePhase.activeSet) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              buildExerciseInfoCard(children: [
                Text('Exercise ${currentIndex + 1} / ${workoutExercises.length}',
                    style: const TextStyle(fontSize: 13, letterSpacing: 2, color: Colors.grey)),
                const SizedBox(height: 6),
                Text(ex.name, textAlign: TextAlign.center,
                    style: const TextStyle(fontSize:22, fontWeight: FontWeight.bold)),
                Text('Set: $currentSet / ${we.sets}')
              ]),
              const SizedBox(height: 10),
              SizedBox(width: 300, height: 300,
                  child: CircularPercentIndicator(
                      progressColor: isPaused ? Colors.grey : Colors.green,
                      radius: 100, lineWidth: 18,
                      percent: we.duration != null && we.duration! > 0
                          ? (remainingSeconds / we.duration!).clamp(0.0,1.0) : 0.0,
                      center: Text('$remainingSeconds',
                          style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold)),
                      circularStrokeCap: CircularStrokeCap.round,
                      backgroundColor: Colors.grey.shade300,
                      animation: false, animateFromLastPercent: true, animationDuration: 500)),
              SizedBox(height: 60,
                child: ElevatedButton.icon(
                    icon: const Icon(Icons.skip_next, color: Colors.white),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: isPaused ? Colors.grey : Colors.orange,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    onPressed: isPaused ? null : () {
                      phaseTimer?.cancel();
                      if(currentSet >= (we.sets ?? 1)){
                        startRest(we.restBetweenSets ?? 0, postExercise: true);
                      } else {
                        setState(() => currentSet++);
                        startRest(we.restBetweenSets ?? 0);
                      }
                    },
                    label: const Text('Skip', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))),)
            ] );
        }
        return const SizedBox();

      case 'AEROBIC':
        if(phase == ExercisePhase.idle) {
          return Column(
            children: [
              buildExerciseInfoCard(children: [
                Text('Exercise ${currentIndex + 1} / ${workoutExercises.length}',
                    style: const TextStyle(fontSize: 13, letterSpacing: 2, color: Colors.grey)),
                const SizedBox(height: 6),
                Text(ex.name, textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const Divider(height: 30),
                Text('Target distance: ${we.distance} km'),
              ]),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange,
                      elevation: 6, shadowColor: Colors.green.withOpacity(0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ExerciseDetailsScreen(exercise: ex,bodyParts: bodyParts,exerciseTypes: exerciseTypes))),
                  child: Text('View Exercise', style: TextStyle(fontSize: 16,fontWeight: FontWeight.w600,color: Colors.black)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, height: 60,
                child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: isPaused ? Colors.grey : Colors.green,
                    elevation: 6, shadowColor: Colors.green.withOpacity(0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: isPaused ? null : startAerobicTracking,
                child: const Text('Start Exercise',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.black))))
      ],
          );
        }
        if(phase == ExercisePhase.activeSet) {
          return Column(
            children: [ buildExerciseInfoCard(children: [
                Text('Exercise ${currentIndex + 1} / ${workoutExercises.length}',
                  style: const TextStyle(fontSize: 13,letterSpacing: 2,color: Colors.grey)),
                const SizedBox(height: 6),
                Text(ex.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const Divider(height: 30),
                Text('Target distance: ${we.distance} km'),
              ]),
              const SizedBox(height: 12),
              hasLocationPermission ? SizedBox(height: 250, width: double.infinity,
              child: ClipRect( child: GoogleMap(
                  key: ValueKey('map_exercise_$currentIndex'),
                  initialCameraPosition: CameraPosition(
                      target: currentPosition ?? const LatLng(0, 0), zoom: 15),
                  onMapCreated: (controller) {
                    mapController = controller;
                  },
                  polylines: {
                    Polyline(polylineId: const PolylineId('route'),color: Colors.blue,
                      width: 6,points: route)},
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                ),
              ))
              : const SizedBox(),
              const SizedBox(height: 12),
              SizedBox(height: 60, child:
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: isPaused ? Colors.grey : Colors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                icon: const Icon(Icons.check, color: Colors.white),
                label: const Text('Finish', style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                onPressed: isPaused ? null : (hasLocationPermission ? finishAerobicTracking : showAerobicDistanceDialog),
              ))
            ]);
        }
        return const SizedBox();
      case 'STRETCHING':
        if(phase == ExercisePhase.idle) {
          return Column(
            children: [
              buildExerciseInfoCard(children: [
                Text('Exercise ${currentIndex + 1} / ${workoutExercises.length}',
                    style: const TextStyle(fontSize: 13,letterSpacing: 2,color: Colors.grey)),
                const SizedBox(height: 6),
                Text(ex.name, textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const Divider(height: 30),
                Text('Duration: ${we.duration}s'),
              ]),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, height: 55,
                child: ElevatedButton( style: ElevatedButton.styleFrom(backgroundColor: Colors.orange,
                      elevation: 6, shadowColor: Colors.green.withOpacity(0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ExerciseDetailsScreen(exercise: ex, bodyParts: bodyParts, exerciseTypes: exerciseTypes))),
                  child: const Text('View Exercise', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, height: 60,
                  child: ElevatedButton(style: ElevatedButton.styleFrom( backgroundColor: isPaused ? Colors.grey : Colors.green,
                      elevation: 6, shadowColor: Colors.green.withOpacity(0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: isPaused ? null : startStretching,
                  child: const Text('Start Stretching',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.black))))
        ] );
        }
        if(phase == ExercisePhase.activeSet) {
          return Column(
            children: [
              const SizedBox(height: 20),
              buildExerciseInfoCard(children: [
                Text('Exercise ${currentIndex + 1} / ${workoutExercises.length}',
                    style: const TextStyle(fontSize: 13,letterSpacing: 2, color: Colors.grey)),
                const SizedBox(height: 6),
                Text(ex.name, textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22,fontWeight: FontWeight.bold))
              ]),
              SizedBox(width: 300, height: 300,
                child: CircularPercentIndicator(
                  radius: 100, lineWidth: 18,
                  percent: remainingSeconds / we.duration!,
                  center: Text('$remainingSeconds',
                      style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold)),
                  circularStrokeCap: CircularStrokeCap.round,
                  progressColor: isPaused ? Colors.grey : Colors.green,
                  backgroundColor: Colors.grey.shade300,
                  animation: false, animateFromLastPercent: true, animationDuration: 500)),
              Row( mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 60,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: isPaused ? Colors.grey : Colors.orange,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    icon: const Icon(Icons.skip_next, color: Colors.white),
                    label: const Text('Skip',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    onPressed: isPaused ? null : () async {
                      phaseTimer?.cancel();
                      we.stretchingCompleted = false;
                      await FS.update.one(we);
                      moveToNextExercise();
                      },
                    )),
                  const SizedBox(width: 12),
                ])]);
        }
        return const SizedBox();
      default: return const SizedBox();
    }
  }

  Future<void> showAerobicDistanceDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<double>(
        context: context, builder: (context) => AlertDialog(
          title: const Text('Distance covered'),
          content: TextField( controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Distance (km)'),
          ),
          actions: [ TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton( onPressed: () {
                  final value = double.tryParse(controller.text);
                  if(value != null) Navigator.pop(context, value);
                },
                child: const Text('Confirm'))
          ],
        ));
    if(result != null) completeAerobic(result);
  }

  @override
  void dispose(){
    workoutTimer?.cancel();
    phaseTimer?.cancel();
    positionStream?.cancel();
    super.dispose();
  }
}

Widget buildExerciseInfoCard({required List<Widget> children}) {
  return Container(width: double.infinity, padding: const EdgeInsets.all(20),
    margin: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 8))],
      border: Border.all(color: Colors.grey.shade500, width: 1.2),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: children),
  );
}