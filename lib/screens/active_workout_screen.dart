import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:me_fit/services/acheivement_service.dart';
import 'package:me_fit/services/authentication_service.dart';
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

import '../models/user.dart';

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

  List<TextEditingController> weightControllers = [];
  bool showWeightInput = false;



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
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Workout paused.'),duration: Duration(seconds: 2)));
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
              we.durationLasted = we.durationOfTimedSet;
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
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Resuming workout.'),duration: Duration(seconds: 2)));
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
    if(we.durationOfTimedSet != null && we.sets != null) return 'CARDIO_PLYO';
    if(we.durationOfTimedSet != null && we.sets == null) return 'STRETCHING';
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

    weightControllers.clear();
    showWeightInput = false;

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
          stretchingCompleted: we.stretchingCompleted,
          setWeights: we.actualSetWeights);
      await FS.create.one(feedback);
    }
    final scheduled = await FS.list.filter<ScheduledWorkout>(ScheduledWorkout)
        .whereEqualTo('workoutId', widget.workout.id)
        .fetch();
    if(scheduled.items.isNotEmpty){
      final sw = scheduled.items.first;
      sw.isCompleted = true;
      sw.totalDuration = elapsedSeconds;
      sw.completedDate = Timestamp.now();
      sw.currentExerciseIndex = null;
      sw.currentSet = null;
      sw.elapsedSeconds = null;
      sw.remainingSeconds = null;
      sw.currentPhase = null;
      sw.isInProgress = null;
      sw.aerobicStartSeconds = null;
      await FS.update.one(sw);
    }
    //achievements
    final userId = AuthenticationService().getCurrentUser()?.uid;
    if(userId == null) return;
    User? user = await FS.get.one<User>(userId);
    //keep track of old badges before user is updated
    final oldBadges = AchievementService.calculateUnlockedBadges(user!.totalCompletedWorkouts);
    final userScheduledWorkouts = await FS.list.filter<ScheduledWorkout>(ScheduledWorkout)
        .whereEqualTo('userId', user?.id)
        .fetch();
    AchievementService().updateAfterWorkout(user!);
    AchievementService().checkWeeklyCompletion(user!, userScheduledWorkouts.items);

    await FS.update.one(user);
    //keep track of new badges if unlocked after user is updated
    final newBadges = AchievementService.calculateUnlockedBadges(user!.totalCompletedWorkouts);
    final hasNewBadge = newBadges.length > oldBadges.length; //compare
    final badgeMilestone = hasNewBadge ? newBadges.last : 0;
    if(hasNewBadge){
      user.badgeUnlockedDates?.add(Timestamp.now());
      await FS.update.one(user);
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutFeedbackScreen(
          workout: widget.workout,
          exercises: workoutExercises,
          showBadgeUnlocked: hasNewBadge,//pass boolean to know if in feedback the dialog of unlocked badge needs to show
          badgeMilestone: badgeMilestone,
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
    if(we.targetSetWeights != null && we.targetSetWeights!.isNotEmpty){
      we.actualSetWeights?.add(we.targetSetWeights![currentSet - 1]);
    }
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
      remainingSeconds = we.durationOfTimedSet ?? 0;
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
      remainingSeconds = we.durationOfTimedSet!;
    });

    phaseTimer?.cancel();
    phaseTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) return;
      setState(() => remainingSeconds--);
      if (remainingSeconds <= 0) {
        t.cancel();
        we.stretchingCompleted = true;
        we.durationLasted = we.durationOfTimedSet;
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
      currentSet++;
      return;
    }
      setState(() {
        phase = ExercisePhase.activeSet;
        currentSet++;
      });

  }

  Future<void> saveWorkoutProgress() async {
    final sw = widget.scheduledWorkout;

    sw.currentExerciseIndex = currentIndex;
    sw.currentSet = currentSet;
    sw.elapsedSeconds = elapsedSeconds;
    sw.remainingSeconds = remainingSeconds;
    sw.currentPhase = phase.name;
    if(elapsedSeconds == 0){
      sw.isInProgress = false;
    }else {
      sw.isInProgress = true;
    }

    if (phase == ExercisePhase.activeSet &&
        getExerciseType(we) == 'AEROBIC') {
      sw.aerobicStartSeconds = aerobicStartSeconds;
      we.routePoints = route.map((e) => '${e.latitude},${e.longitude}').toList();
      await FS.update.one(we);
    }

    await FS.update.one(sw);

  }

  //TODO - Move this to a separate widget file --> WorkoutActionButton?
  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    IconAlignment? iconAlignment,
    bool isFullWidth = false,
  }) {
    final button = ElevatedButton.icon(
      icon: Icon(icon, size: 22, color: Colors.white),
      label: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: isPaused ? Colors.grey : color,
        minimumSize: Size(isFullWidth ? double.infinity : 0, 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
      ),
      onPressed: isPaused ? null : onPressed,
      iconAlignment: iconAlignment ?? IconAlignment.start,
    );

    return isFullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }

  //TODO - Move this to a separate widget file --> WorkoutActionButton?
  Widget _buildSecondaryActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    bool isFullWidth = false,
    IconAlignment? iconAlignment,
  }) {
    final button = OutlinedButton.icon(
      icon: Icon(icon, size: 22,),
      label: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        minimumSize: Size(isFullWidth ? double.infinity : 0, 60),
        elevation: 4,
      ),
      onPressed: isPaused ? null : onPressed,
      iconAlignment: iconAlignment ?? IconAlignment.start,
    );

    return isFullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }

  // Progress Circle
  //TODO - Move this to a separate widget file --> WorkoutProgressCircle?
  Widget _buildTimerCircle({required double percent, required int seconds, required Color color}) {
    return Center(
      child: CircularPercentIndicator(
        radius: 110,
        lineWidth: 15,
        percent: percent.clamp(0.0, 1.0),
        center: Text('${seconds}s', style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900)),
        circularStrokeCap: CircularStrokeCap.round,
        progressColor: isPaused ? Colors.grey : color,
        backgroundColor: Colors.grey.shade200,
        animation: true,
        animateFromLastPercent: true,
      ),
    );
  }

  // Exercise Info Card
  // TODO - Move this to a separate widget file --> ExerciseInfoCard?
  Widget _buildViewDetailsButton(Exercise ex) {
    return _buildSecondaryActionButton(
      label: 'VIEW DETAILS',
      icon: Icons.info_outline,
      color: Colors.black87,
      isFullWidth: true,
      onPressed: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => ExerciseDetailsScreen(exercise: ex, bodyParts: bodyParts, exerciseTypes: exerciseTypes))),
    );
  }
  Future<void> showCancelDialog() async{
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning,color: Colors.red),
          SizedBox(width: 8),Text('Cancel Workout')
        ],
        ),
        content: Text('Are you sure you want to cancel this workout? All progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context,false),
            child: Text('No, continue'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red,foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context,true),
              child: Text('Yes, cancel'))
        ],
      )
    );
    if(confirm == true){
      await cancelWorkout();
    }
  }
  Future<void> cancelWorkout() async {
    workoutTimer?.cancel();
    phaseTimer?.cancel();
    positionStream?.cancel();

    final sw = widget.scheduledWorkout;
    sw.isInProgress = false;
    sw.currentExerciseIndex = null;
    sw.currentSet = null;
    sw.elapsedSeconds = null;
    sw.remainingSeconds = null;
    sw.currentPhase = null;
    sw.aerobicStartSeconds = null;
    await FS.update.one(sw);

    for(var we in workoutExercises){
      we.setsCompleted = 0;
      we.repsCompleted = 0;
      we.durationLasted = 0;
      we.distanceCovered = 0;
      we.targetSetWeights = null;
      we.actualSetWeights = null;
      we.timeForDistanceCovered = 0;
      we.stretchingCompleted = false;
      we.routePoints = null;
      await FS.update.one(we);
    }

    for (var controller in weightControllers) {
      controller.dispose();
    }
    weightControllers.clear();
    showWeightInput = false;

    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Workout cancelled.'),duration: Duration(seconds: 2)));
    Navigator.pop(context,true);
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
              IconButton(
                onPressed: showCancelDialog,
                icon: Icon(Icons.cancel_outlined),
                tooltip: 'Cancel Workout',
              ),
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
        body: Padding( padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              LinearProgressIndicator(minHeight: 10,value: progress,backgroundColor: Colors.red,color: Colors.green),
              SizedBox(height: 16),
              Row( mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Workout time: ', style: TextStyle(fontSize: 20, letterSpacing: 2)),
                  Text(formatDuration(elapsedSeconds),
                      style:  TextStyle(fontSize: 34, fontWeight: FontWeight.bold)),
                ]),
              SizedBox(height: 5),
              Expanded(
                child: buildExerciseControls(),
              ),
            ]),
        )),
    );
  }

  Widget buildExerciseControls() {
    if (isTransitioning) {
      return Center(child: CircularProgressIndicator());
    }

    final type = getExerciseType(we);

    if (phase == ExercisePhase.rest) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Take a break...',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 28, letterSpacing: 1.2)),
            const SizedBox(height: 30),
            _buildTimerCircle(
              percent: remainingSeconds / (we.restBetweenSets ?? 1),
              seconds: remainingSeconds, color: Colors.blue
            ),
            const SizedBox(height: 40),
            _buildActionButton(
              label: 'SKIP REST',
              icon: Icons.skip_next,
              color: Colors.orange.shade700,
              isFullWidth: true,
              onPressed: finishRest,
              iconAlignment: IconAlignment.end,
            ),
          ],
        ),
      );
    }

    switch (type) {
      case 'STRENGTH':
        if (phase == ExercisePhase.idle) {
          return Column(children: [
            buildExerciseInfoCard(children: [
              _buildHeaderTag(),
              const SizedBox(height: 12),
              Text(ex.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Divider(height: 32),
              _buildInfoRow('Sets', '${we.sets}'),
              _buildInfoRow('Reps', '${we.repetitions}'),
              _buildInfoRow('Rest', '${we.restBetweenSets}s'),
            ]),
            //show eights input
            if (!showWeightInput)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _buildSecondaryActionButton(
                  label: 'ADD WEIGHTS (OPTIONAL)',
                  icon: Icons.fitness_center,
                  color: Colors.blue,
                  onPressed: () {
                    setState(() {
                      showWeightInput = true;
                      //create controllers for each set
                      weightControllers = List.generate(
                        we.sets!,
                            (index) => TextEditingController(),
                      );
                    });
                  },
                  isFullWidth: true,
                )),
            if (showWeightInput) ...[
              SizedBox(height: 5),
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration( color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row( mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                            Icon(Icons.fitness_center, size: 20, color: Colors.blue.shade700),
                            SizedBox(width: 8),
                            Text('Weight per set (kg)',
                              style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600, color: Colors.blue)),
                          ]),
                        IconButton(
                          icon: Icon(Icons.close, size: 20),
                          onPressed: () {
                            setState(() {
                              showWeightInput = false;
                              weightControllers.clear();
                            });
                          }
                        )]),
                    SizedBox(height: 12),
                    SizedBox(
                      height: 168,
                      child: SingleChildScrollView(
                        child: Column(
                          children: List.generate(we.sets!, (index) {
                            return Padding(
                              padding:  EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Container(width: 30, height: 30,
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      shape: BoxShape.circle),
                                    child: Center(
                                      child: Text('${index + 1}',
                                        style: TextStyle(fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade800),
                                      ))),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: weightControllers[index],
                                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                                      decoration: InputDecoration(
                                        hintText: 'Enter weight (kg)',
                                        suffixText: 'kg',border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                    ))],
                              ));
                          }),
                        )),
                    ),
                    //show there are more sets if any
                    if (we.sets! > 3)
                      Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Center(
                          child: Text('Scroll to see more sets',

                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            )),
                        ))],
                ))],
            SizedBox(height: 10),
            _buildViewDetailsButton(ex),
            SizedBox(height: 12),
            _buildActionButton(
              label: 'START EXERCISE',
              icon: Icons.play_arrow,
              color: Colors.green,
              onPressed: () {
                if (showWeightInput && weightControllers.isNotEmpty) {
                  List<double> targetWeights = [];
                  for (int i = 0; i < weightControllers.length; i++) {
                    final weight = double.tryParse(weightControllers[i].text) ?? 0;
                    if(weight < 0 || weight > 400 ){
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Weight must vary between 0.5 kg and 400 kg'),duration: Duration(seconds: 2)));
                      return;
                    }
                    targetWeights.add(weight != null && weight > 0 ? weight : 0);
                  }

                  if (targetWeights.any((w) => w > 0)) {
                    we.targetSetWeights = targetWeights;
                    FS.update.one(we);
                  }
                }
                startStrengthSet();
              },
              isFullWidth: true,
            ),
          ]);
        }
        if (phase == ExercisePhase.activeSet) {
          return Column(children: [
            buildExerciseInfoCard(children: [
              _buildHeaderTag(),
              const SizedBox(height: 12),
              Text(ex.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const Divider(height: 24),
              Text('SET $currentSet OF ${we.sets}',
                  style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.w900, fontSize: 18, color: Colors.green)),
              if (we.targetSetWeights != null && currentSet <= we.targetSetWeights!.length &&
                  we.targetSetWeights![currentSet - 1] > 0)
                Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Target Weight: ${we.targetSetWeights![currentSet - 1]} kg',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.blue.shade800),
                    ),
                  ),
                ),
            ]),

            const SizedBox(height: 40),
            Row(children: [
              Expanded(child: _buildActionButton(
                  label: 'SKIP', icon: Icons.skip_next, color: Colors.orange.shade700,
                  iconAlignment: IconAlignment.end,
                  onPressed: () async {
                    phaseTimer?.cancel();
                    if(we.targetSetWeights != null && we.targetSetWeights!.isNotEmpty) {
                      we.actualSetWeights?.add(0);
                      await FS.update.one(we);
                    }
                    (currentSet >= (we.sets ?? 1)) ? startRest(we.restBetweenSets ?? 0, postExercise: true) : startRest(we.restBetweenSets ?? 0);
                  }
              )),
              const SizedBox(width: 12),
              Expanded(child: _buildActionButton(
                  label: 'DONE', icon: Icons.check, color: Colors.green,
                  onPressed: completeStrengthSet
              )),
            ]),
            const Spacer(),
            _buildViewDetailsButton(ex),
          ]);
        }
        break;

      case 'TIMED':
      case 'CARDIO_PLYO':
        if (phase == ExercisePhase.idle) {
          return Column(children: [
            buildExerciseInfoCard(children: [
              _buildHeaderTag(),
              const SizedBox(height: 12),
              Text(ex.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const Divider(height: 32),
              _buildInfoRow('Sets', '${we.sets}'),
              _buildInfoRow('Duration', '${we.durationOfTimedSet}s'),
            ]),
            const SizedBox(height: 24),
            _buildViewDetailsButton(ex),
            const SizedBox(height: 12),
            _buildActionButton(label: 'START', icon: Icons.timer, color: Colors.green, onPressed: startTimedSet, isFullWidth: true),
          ]);
        }
        if (phase == ExercisePhase.activeSet) {
          return Column(children: [
            buildExerciseInfoCard(children: [
              _buildHeaderTag(),
              const SizedBox(height: 12),
              Text(ex.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Text('Set $currentSet / ${we.sets}', style: TextStyle(color: Colors.grey[600])),
            ]),
            const SizedBox(height: 30),
            _buildTimerCircle(
              percent: we.durationOfTimedSet != null && we.durationOfTimedSet! > 0 ? (remainingSeconds / we.durationOfTimedSet!) : 0.0,
              seconds: remainingSeconds, color: Colors.green
            ),
            const SizedBox(height: 40),
            _buildActionButton(
                label: 'SKIP SET', icon: Icons.skip_next, color: Colors.orange.shade700, isFullWidth: true,
                onPressed: () {
                  phaseTimer?.cancel();
                  (currentSet >= (we.sets ?? 1)) ? startRest(we.restBetweenSets ?? 0, postExercise: true) : startRest(we.restBetweenSets ?? 0);
                }
            ),
            const Spacer(),
            _buildViewDetailsButton(ex),
          ]);
        }
        break;

      case 'AEROBIC':
        if (phase == ExercisePhase.idle) {
          return Column(children: [
            buildExerciseInfoCard(children: [
              _buildHeaderTag(),
              const SizedBox(height: 12),
              Text(ex.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const Divider(height: 32),
              _buildInfoRow('Goal Distance', '${we.distance} km'),
            ]),
            const SizedBox(height: 24),
            _buildViewDetailsButton(ex),
            const SizedBox(height: 12),
            _buildActionButton(
                label: 'START TRACKING',
                icon: Icons.location_on,
                color: Colors.green,
                onPressed: startAerobicTracking,
                isFullWidth: true
            ),
          ]);
        }

        if (phase == ExercisePhase.activeSet) {
          return Column(children: [
            buildExerciseInfoCard(children: [
              _buildHeaderTag(),
              const SizedBox(height: 12),
              Text(ex.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const Divider(height: 20),
              _buildInfoRow('Current Goal', '${we.distance} km'),
            ]),
            Container(
              height: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: hasLocationPermission
                    ? GoogleMap(
                  key: ValueKey('map_exercise_$currentIndex'),
                  initialCameraPosition: CameraPosition(
                    target: currentPosition ?? const LatLng(0, 0),
                    zoom: 15,
                  ),
                  onMapCreated: (controller) => mapController = controller,
                  polylines: {
                    Polyline(
                      polylineId: const PolylineId('route'),
                      color: Theme.of(context).primaryColor,
                      width: 6,
                      points: route,
                    )
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                )
                    : const Center(child: Text("Location permission required for map")),
              ),
            ),
            const SizedBox(height: 24),
            _buildActionButton(
              label: 'FINISH EXERCISE',
              icon: Icons.check_circle,
              color: Colors.green,
              isFullWidth: true,
              onPressed: hasLocationPermission ? finishAerobicTracking : showAerobicDistanceDialog,
            ),
          ]);
        }
        break;
      case 'STRETCHING':
        if (phase == ExercisePhase.idle) {
          return Column(
            children: [
              buildExerciseInfoCard(children: [
                _buildHeaderTag(),
                const SizedBox(height: 12),
                Text(ex.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                const Divider(height: 32),
                _buildInfoRow('Target Duration', '${we.durationOfTimedSet}s'),
              ]),
              const SizedBox(height: 24),
              _buildViewDetailsButton(ex),
              const SizedBox(height: 12),
              _buildActionButton(
                label: 'START STRETCHING',
                icon: Icons.accessibility_new,
                color: Theme.of(context).primaryColor,
                isFullWidth: true,
                onPressed: startStretching,
              ),
            ],
          );
        }
        if (phase == ExercisePhase.activeSet) {
          return Column(
            children: [
              buildExerciseInfoCard(children: [
                _buildHeaderTag(),
                const SizedBox(height: 12),
                Text(ex.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 30),
              _buildTimerCircle(
                percent: remainingSeconds / (we.durationOfTimedSet ?? 1),
                seconds: remainingSeconds, color: Colors.blue
              ),
              const SizedBox(height: 40),
              _buildActionButton(
                label: 'SKIP STRETCH',
                icon: Icons.skip_next,
                color: Colors.orange.shade700,
                isFullWidth: true,
                iconAlignment: IconAlignment.end,
                onPressed: () async {
                  phaseTimer?.cancel();
                  we.stretchingCompleted = false;
                  await FS.update.one(we);
                  moveToNextExercise();
                },
              ),
              const Spacer(),
              _buildViewDetailsButton(ex),
            ],
          );
        }
        break;
    }

    return const SizedBox();
  }

  /// Header Tag for Exercise Progress
  Widget _buildHeaderTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: Theme.of(context).primaryColor, borderRadius: BorderRadius.circular(20)),
      child: Text('EXERCISE ${currentIndex + 1} / ${workoutExercises.length}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }

  /// Info Row for Exercise Details
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 17)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        ],
      ),
    );
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

    weightControllers.clear();
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