import 'package:firestorm/firestorm.dart';
import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/models/exercise.dart';
import 'package:me_fit/models/workoutExercises.dart';
import 'package:me_fit/screens/create_workout_screen.dart';
import 'package:me_fit/screens/exercise_details_screen.dart';
import 'package:me_fit/screens/select_exercise_screen.dart';

import '../models/bodyPart.dart';
import '../models/exerciseType.dart';
import '../models/workout.dart';
import '../utilityFunctions/utility_functions.dart';
//widget for editing workout exercises
class EditWorkoutScreen extends StatefulWidget {
  final Workout workout;

  const EditWorkoutScreen(
      {super.key, required this.workout});

  @override
  State<EditWorkoutScreen> createState() => EditWorkoutScreenState();
}
class WorkoutExerciseInstance {
  final WorkoutExercises workoutExercise;
  final Exercise exercise;
  final String exerciseTypeName;

  int? sets;
  int? reps;
  int? rest;
  int? duration;
  double? distance;

  WorkoutExerciseInstance({
    required this.workoutExercise,
    required this.exercise,
    required this.exerciseTypeName,
    this.sets,
    this.reps,
    this.rest,
    this.duration,
    this.distance
  });
  //This is used when loading existing exercises from Firestore to populate the editable
  //workout exercise instances in the UI. It maps all the database fields to the instance
  //properties that can be edited by the user.
  factory WorkoutExerciseInstance.fromWorkoutExercises(WorkoutExercises we,
      Exercise ex, String typeName) {
    return WorkoutExerciseInstance(
        workoutExercise: we,
        exercise: ex,
        exerciseTypeName: typeName,
        sets: we.sets,
        reps: we.repetitions,
        rest: we.restBetweenSets,
        duration: we.durationOfTimedSet,
        distance: we.distance);
  }

  void applyToWorkoutExercise() {
    workoutExercise.sets = sets;
    workoutExercise.repetitions = reps;
    workoutExercise.restBetweenSets = rest;
    workoutExercise.durationOfTimedSet = duration;
    workoutExercise.distance = distance;
  }
}

class EditWorkoutScreenState extends State<EditWorkoutScreen> {
  final List<WorkoutExerciseInstance> exercises = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadExercises();
  }
//fetch exercises of that workout
  Future<void> loadExercises() async {
    final weResult = await FS.list.filter<WorkoutExercises>(WorkoutExercises)
        .whereEqualTo('workoutId', widget.workout.id)
        .fetch();
    final workoutExercises = weResult.items
      ..sort((a, b) => a.order.compareTo(b.order));
    final exerciseIds = workoutExercises.map((e) => e.exerciseId).toList();
    final exResult = await FS.list.filter<Exercise>(Exercise).whereIn(
        'id', exerciseIds).fetch();
    final exerciseMap = {for (var e in exResult.items) e.id: e};

    final typeResult = await FS.list.allOfClass<ExerciseType>(ExerciseType);
    final typeMap = {for (var t in typeResult) t.id: t.name};

    final instances = workoutExercises.map((we) {
      final ex = exerciseMap[we.exerciseId]!;
      final typeName = typeMap[ex.exerciseTypeId] ?? '';
      return WorkoutExerciseInstance.fromWorkoutExercises(we, ex, typeName);
    }).toList();

    setState(() {
      exercises.addAll(instances);
      isLoading = false;
    });
  }
//show dialog for editing an exercises
  Future<WorkoutExerciseInstance?> showExerciseAlterDialog(
      WorkoutExerciseInstance instance) async {
    final type = instance.exerciseTypeName;

    final sets = TextEditingController(text: instance.sets?.toString() ?? '3');
    final reps = TextEditingController(text: instance.reps?.toString() ?? '12');
    final rest = TextEditingController(text: instance.rest?.toString() ?? '60');
    final duration = TextEditingController(
        text: instance.duration?.toString() ?? '30');
    final distance = TextEditingController(
        text: instance.distance?.toString() ?? '1');

    return showDialog<WorkoutExerciseInstance>(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: Text('Edit ${instance.exercise.name}'),
            content: SingleChildScrollView(
                child: Column(
                  children: [
                    if(type == 'STRENGTH') ...[
                      numberField(sets, 'Sets (1-8)'),
                      numberField(reps, 'Reps (1-50)'),
                      numberField(rest, 'Rest seconds (10-600'),
                    ],
                    if(type == 'CARDIO' || type == 'PLYOMETRICS') ...[
                      numberField(sets, 'Sets (1-10)'),
                      numberField(duration, 'Duration seconds (10-7200)'),
                      numberField(rest, 'Rest seconds (20-600'),
                    ],
                    if(type == 'AEROBIC') ...[
                      numberField(
                          distance, 'Distance (0.1-100 km)', isDecimal: true),
                    ],
                    if(type == 'STRETCHING') ...[
                      numberField(duration, 'Duration seconds (10-1800)'),
                    ],
                  ],
                )
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
              ElevatedButton(
                  onPressed: () {
                    if (!validateInputs(
                        type, sets, reps, rest, duration, distance)) return;
                    if (type == 'STRENGTH') {
                      instance.sets = int.parse(sets.text);
                      instance.reps = int.parse(reps.text);
                      instance.rest = int.parse(rest.text);
                    }
                    if (type == 'CARDIO' || type == 'PLYOMETRICS') {
                      instance.sets = int.parse(sets.text);
                      instance.duration = int.parse(duration.text);
                      instance.rest = int.parse(rest.text);
                    }
                    if (type == 'AEROBIC') {
                      instance.distance = double.parse(distance.text);
                    }
                    if (type == 'STRETCHING') {
                      instance.duration = int.parse(duration.text);
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Changes saved'),duration: Duration(seconds: 2),),
                    );
                    Navigator.pop(context, instance);
                  },
                  child: const Text('Save'))
            ],
          );
        }
    );
  }

//validations for each type of exercises
  bool validateInputs(String type, TextEditingController sets,
      TextEditingController reps,
      TextEditingController rest, TextEditingController duration,
      TextEditingController distance) {
    try {
      if (type == 'STRENGTH') {
        final s = int.parse(sets.text);
        final r = int.parse(reps.text);
        final res = int.parse(rest.text);

        if (s < 1 || s > 8) throw 'Sets must be 1-8';
        if (r < 1 || r > 50) throw 'Reps must be 1-50';
        if (res < 10 || res > 600) throw 'Rest must be 10-600 sec';
      }
      if (type == 'CARDIO' || type == 'PLYOMETRICS') {
        final s = int.parse(sets.text);
        final d = int.parse(duration.text);
        final res = int.parse(rest.text);

        if (s < 1 || s > 10) throw 'Sets must be 1-10';
        if (d < 10 || d > 7200) throw 'Duration must be between 10-7200 sec';
        if (res < 10 || res > 600) throw 'Rest must be 10-600 sec';
      }
      if (type == 'AEROBIC') {
        final dist = double.parse(distance.text);
        if (dist < 0.1 || dist > 100) throw 'Distance must be 0.1-100km';
      }
      if (type == 'STRETCHING') {
        final d = int.parse(duration.text);
        if (d < 10 || d > 1800) throw 'Duration must be 10-1800 sec';
      }
      return true;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())));
      return false;
    }
  }
//display number field fro setting sets/reps/rest/distance
  Widget numberField(TextEditingController controller, String label,
      {bool isDecimal = false}) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          keyboardType: isDecimal ? const TextInputType.numberWithOptions(
              decimal: true)
              : TextInputType.number,
          decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder()
          ),
        )
    );
  }
  //function for adding exercises
  Future<void> addExerciseFlow() async {
    if (exercises.length >= 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You can add up to 50 exercises'),duration: Duration(seconds: 2),),
      );
      return;
    }
    final Exercise? exercise = await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const SelectExerciseScreen())
    );
    if (exercise == null) return;

    final exerciseType = await FS.get.one<ExerciseType>(
        exercise.exerciseTypeId);

    if (exerciseType == null) return;

    final newWorkoutExercise = WorkoutExercises(
        id: Firestorm.randomID(),
        workoutId: widget.workout.id,
        exerciseId: exercise.id,
        order: exercises.length + 1);

    final instance = WorkoutExerciseInstance(
        workoutExercise: newWorkoutExercise,
        exercise: exercise,
        exerciseTypeName: exerciseType.name);

    final altered = await showExerciseAlterDialog(instance);

    if (altered != null) {
      altered.applyToWorkoutExercise();
      await FS.create.one(altered.workoutExercise);
      setState(() {
        exercises.add(altered);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Editing: ${widget.workout.name}'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(30)),
            child: IconButton(icon: const Icon(Icons.info_outline),
              onPressed: showWorkoutInfo,
              color: Theme.of(context).primaryColor,
              tooltip: 'Workout Info',
            ))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addExerciseFlow, icon: const Icon(Icons.add),
        label: const Text('Add Exercise'), backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 4),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(padding: const EdgeInsets.only(bottom: 80),
        child: Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(children: [
                  Container(padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.fitness_center,
                      color: Theme.of(context).primaryColor,size: 20)),
                  SizedBox(width: 12),
                  Text('EXERCISES',
                    style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,color: Colors.grey[700])),
                  SizedBox(width: 8),
                  Container(width: 4,height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      shape: BoxShape.circle),
                  ), SizedBox(width: 8),
                  Text('${exercises.length} total',
                    style: TextStyle(
                      fontSize: 14,color: Colors.grey[600],
                      fontWeight: FontWeight.w500),
                  )])),
            Expanded(
              child: exercises.isEmpty
                  ? buildEmptyState(): ReorderableListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: exercises.length,onReorder: (oldIndex, newIndex) async {
                  if (newIndex > oldIndex) newIndex--;
                  final item = exercises.removeAt(oldIndex);
                  exercises.insert(newIndex, item);
                  for (int i = 0; i < exercises.length; i++) {
                    exercises[i].workoutExercise.order = i + 1;
                    await FS.update.one(exercises[i].workoutExercise);
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Changes saved'),duration: Duration(seconds: 2),),
                  );
                  setState(() {});
                },
                itemBuilder: (context, index) {
                  return buildExerciseCard(
                    exercises[index],
                    index,
                  );
                },
                itemExtent: null,
              ))],
        )));
  }
//widget showing when workout has not exercises
  Widget buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Container(
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(color: Colors.grey[200],
              shape: BoxShape.circle),
            child: Icon(Icons.fitness_center_outlined,
              size: 64,color: Colors.grey[600]),
          ),SizedBox(height: 24),
          Text('No exercises yet',
            style: TextStyle(fontSize: 20,
              fontWeight: FontWeight.bold,color: Colors.grey[800])),
           SizedBox(height: 8),Text(
            'Tap + to add your first exercise',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(onPressed: addExerciseFlow,
            icon: Icon(Icons.add),label: Text('Add Exercise'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,padding: EdgeInsets.symmetric(
                horizontal: 24,vertical: 12,
              ),
              shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(30),
              ) ))]),
    );
  }
//widget containing exercise info and buttons for editing and removing an exercises
  Widget buildExerciseCard(WorkoutExerciseInstance exercise,int index) {
    return Container(
      key: ValueKey(exercise.workoutExercise.id),
      margin: const EdgeInsets.only(bottom: 12),decoration: BoxDecoration(
        color: Colors.white,borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 15,offset: const Offset(0, 5))]),
      child: Material(
        color: Colors.transparent,
        child: Padding( padding: const EdgeInsets.all(12),
          child: Row( children: [
              ReorderableDragStartListener(
                index: index, child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12)),
                  child: Icon(
                    Icons.drag_handle,color: Colors.grey[600],
                    size: 20)),
              ),
              SizedBox(width: 12),
              Container(
                width: 36,height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(child: Text(
                    '${index + 1}', style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold, fontSize: 14,
                    )) )),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercise.exercise.name,
                      style: TextStyle( fontWeight: FontWeight.bold,
                        fontSize: 16)),
                    SizedBox(height: 4),
                    Container( padding: EdgeInsets.symmetric(
                        horizontal: 8,vertical: 4),
                      decoration: BoxDecoration(
                        color: getTypeColor(exercise.exerciseTypeName).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        exercise.exerciseTypeName,
                        style: TextStyle(fontSize: 10,
                          fontWeight: FontWeight.w600,color: getTypeColor(exercise.exerciseTypeName))),
                    ),
                    SizedBox(height: 8),
                    Wrap(spacing: 8,runSpacing: 4,children: buildExerciseTags(exercise)),
                  ])),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [buildActionButton(
                    icon: Icons.edit, color: Colors.blue,
                    tooltip: 'Edit Exercise',onPressed: () async {
                      final updated = await showExerciseAlterDialog(exercise);
                      if (updated != null) {
                        updated.applyToWorkoutExercise();
                        await FS.update.one(updated.workoutExercise);
                        setState(() {});
                      }}),
                  SizedBox(width: 4),
                  buildActionButton(icon: Icons.delete,color: Colors.red,
                    tooltip: 'Delete Exercise',onPressed: () => showDeleteDialog(exercise),
                  )])],
          ))),
    );
  }
//button for removing/editing an exercise
  Widget buildActionButton({required IconData icon,required Color color,required String tooltip,
    required VoidCallback onPressed}) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(icon: Icon(icon, color: color, size: 20),
        onPressed: onPressed,tooltip: tooltip,
        constraints: const BoxConstraints(minWidth: 36,minHeight: 36),
        padding: EdgeInsets.zero),
    );
  }
//function for assigning details to an exercise according to what type it is
  List<Widget> buildExerciseTags(WorkoutExerciseInstance exercise) {
    List<Widget> tags = [];
    final type = exercise.exerciseTypeName;
    if (type == 'STRENGTH') {
      if (exercise.sets != null) {
        tags.add(buildTag(icon: Icons.repeat,text: '${exercise.sets} sets'));
      }
      if (exercise.reps != null) {
        tags.add(buildTag(icon: Icons.fitness_center,text: '${exercise.reps} reps'));
      }
      if (exercise.rest != null) {
        tags.add(buildTag(icon: Icons.timer,text: 'rest ${exercise.rest}s'));
      }
    } else if (type == 'CARDIO' || type == 'PLYOMETRICS') {
      if (exercise.sets != null) {
        tags.add(buildTag(icon: Icons.repeat,text: '${exercise.sets} sets'));
      }
      if (exercise.duration != null) {
        tags.add(buildTag(icon: Icons.timer,text: formatDuration(exercise.duration!)));
      }
      if (exercise.rest != null) {
        tags.add(buildTag(icon: Icons.hourglass_empty,text: 'rest ${exercise.rest}s'));
      }
    } else if (type == 'AEROBIC') {
      if (exercise.distance != null) {
        tags.add(buildTag(icon: Icons.map,text: '${exercise.distance} km'));
      }
    } else if (type == 'STRETCHING') {
      if (exercise.duration != null) {
        tags.add(buildTag(icon: Icons.timer,text: formatDuration(exercise.duration!)));
      }}
    return tags;
  }
//widget for details with icon
  Widget buildTag({required IconData icon,required String text}){
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,size: 12,color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(text,style: TextStyle(
              fontSize: 11,color: Colors.grey[700],
              fontWeight: FontWeight.w500),
          )]),
    );
  }
//function for assigning a color according to exercise type
  Color getTypeColor (String type) {
    switch (type) {
      case 'STRENGTH':
        return Colors.blue;
      case 'CARDIO':
        return Colors.green;
      case 'PLYOMETRICS':
        return Colors.orange;
      case 'AEROBIC':
        return Colors.purple;
      case 'STRETCHING':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
  //function for displaying dialog with workout info if info icon is pressed
  void showWorkoutInfo() {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 8),
                Text('Workout Info'),
              ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Created: ${formatDate(
                      widget.workout.createdOn?.toDate() ?? DateTime.now())}',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 8),
                Text(
                  'Total Exercises: ${exercises.length}',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 16),
                Text('Drag the handle to reorder exercises',
                  style: TextStyle(fontSize: 12,color: Colors.grey)),
              ]),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              )]),
    );
  }

  String formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
//dialog showing when user presses remove exercise icon
  void showDeleteDialog(WorkoutExerciseInstance exercise) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red),
                SizedBox(width: 8),Text('Delete Exercise'),
              ]),
            content: Text('Are you sure you want to remove ${exercise.exercise.name}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child:  Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child:  Text('Delete'),
              )]),
    );

    if (confirm != true) return;

    final index = exercises.indexOf(exercise);
    if (index >= 0) {
      final removed = exercises.removeAt(index);
      await FS.delete.one(removed.workoutExercise);

      for (int i = 0; i < exercises.length; i++) {
        exercises[i].workoutExercise.order = i + 1;
        await FS.update.one(exercises[i].workoutExercise);
      }

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${exercise.exercise.name} removed'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}