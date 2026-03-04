import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firestorm/firestorm.dart';
import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:me_fit/models/exercise.dart';
import 'package:me_fit/models/exerciseType.dart';
import 'package:me_fit/models/workoutExercises.dart';
import 'package:me_fit/screens/select_exercise_screen.dart';
import 'package:me_fit/services/authentication_service.dart';

import '../models/workout.dart';


class CreateWorkoutScreen extends StatefulWidget{
  const CreateWorkoutScreen({super.key});

  @override
  State<CreateWorkoutScreen> createState() => CreateWorkoutScreenState();
}
class WorkoutExerciseInstance {
  final Exercise exercise;
  final String exerciseTypeName;

  int? sets;
  int? reps;
  int? rest;
  int? duration;
  double? distance;

  WorkoutExerciseInstance({
    required this.exercise,
    required this.exerciseTypeName
});
}
class CreateWorkoutScreenState extends State<CreateWorkoutScreen> {
  final formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();

  final List<WorkoutExerciseInstance> selectedExercises = [];

  //save workout
  Future<void> saveWorkout() async {
    if (!formKey.currentState!.validate()) return;

    if (selectedExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one exercise')));
      return;
    }
    final workoutName = nameController.text.trim();
    final authService = AuthenticationService();
    final user = authService.getCurrentUser();

    if (user == null) return;

    final existingWorkouts = await FS.list.filter<Workout>(Workout)
        .whereEqualTo('createdBy',user.uid)
        .whereEqualTo('isMyWorkout',true)
        .fetch();

    if (existingWorkouts.items.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You already have a workout with this name')),
      );
      return;
    }
      final workoutId = Firestorm.randomID();
      await FS.create.one(
        Workout(
            id: workoutId,
            name: workoutName,
            createdBy: authService.getCurrentUser()!.uid,
            isMyWorkout: true,
            createdOn: Timestamp.now()
        )
    );

    for (int i = 0; i < selectedExercises.length; i++) {
      final draftExercise = selectedExercises[i];

      await FS.create.one(
          WorkoutExercises(
            id: Firestorm.randomID(),
            workoutId: workoutId,
            exerciseId: draftExercise.exercise.id,
            order: i + 1,
            sets: draftExercise.sets,
            repetitions: draftExercise.reps,
            restBetweenSets: draftExercise.rest,
            durationOfTimedSet: draftExercise.duration,
            distance: draftExercise.distance,)
      );
    }
    Navigator.pop(context, true);
  }

  //add exercise
  Future<void> addExerciseFlow() async {
    if (selectedExercises.length >= 50) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You can add up to 50 exercises'))
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

    final draft = WorkoutExerciseInstance(
        exercise: exercise, exerciseTypeName: exerciseType.name);

    final alteredExercise = await showExerciseAlterDialog(draft);

    if (alteredExercise != null) {
      setState(() {
        selectedExercises.add(alteredExercise);
      });
    }
  }

  //validation
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
          return AlertDialog( //TODO - This dialog seems to be reused throughout your app. I suggest you create a separate widget for it, it will make the code cleaner and more maintainable
            title: Text('Alter ${instance.exercise.name}'),
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
                    Navigator.pop(context, instance);
                  },
                  child: const Text('Save'))
            ],
          );
        }
    );
  }

  void applyValuesToInstance(WorkoutExerciseInstance instance, String type,
      TextEditingController sets, TextEditingController reps,
      TextEditingController rest, TextEditingController duration,
      TextEditingController distance,) {
    if (type == 'STRENGTH') {
      instance.sets = int.tryParse(sets.text);
      instance.rest = int.tryParse(reps.text);
      instance.rest = int.tryParse(rest.text);
    }
    if (type == 'CARDIO' || type == 'PLYOMETRICS') {
      instance.sets = int.tryParse(sets.text);
      instance.duration = int.tryParse(duration.text);
      instance.rest = int.tryParse(rest.text);
    }
    if (type == 'AEROBIC') {
      instance.distance = double.tryParse(distance.text);
    }
    if (type == 'STRETCHING') {
      instance.duration = int.tryParse(duration.text);
    }
  }

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

  String buildSummary(WorkoutExerciseInstance i) {
    final type = i.exerciseTypeName;

    if (type == 'STRENGTH') {
      return '${i.sets ?? 0}x${i.reps ?? 0} • Rest ${i.rest ?? 0}s';
    }
    if (type == 'CARDIO' || type == 'PLYOMETRICS') {
      return '${i.sets ?? 0}x${i.duration ?? 0}s • Rest ${i.rest ?? 0}s';
    }
    if (type == 'AEROBIC') {
      return '${i.distance ?? 0} km';
    }
    if (type == 'STRETCHING') {
      return '${i.duration ?? 0} s';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Create Workout')),
      body: SafeArea(
        child: Padding( padding:  EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05),
                      blurRadius: 15,offset: const Offset(0, 5),
                    )]),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Form(
                    key: formKey,
                    child: TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Workout Name',hintText: 'e.g., Full Body Blast',
                        prefixIcon: Icon(Icons.fitness_center,
                          color: Theme.of(context).primaryColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none),
                        filled: true,fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,vertical: 16)),
                      validator: (value) =>
                      value == null || value.isEmpty ? 'Enter workout name' : null,
                    ))),
              ),
              SizedBox(height: 20),
              Padding(
                padding:EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Container(padding:  EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon( Icons.fitness_center,
                        color: Theme.of(context).primaryColor, size: 16)),
                    SizedBox(width: 12),
                    Text('EXERCISES', style: TextStyle(fontSize: 14,fontWeight: FontWeight.w600,letterSpacing: 1.2,color: Colors.grey[700]),
                    ),
                    SizedBox(width: 8),
                    Container(width: 4,height: 4,decoration: BoxDecoration(color: Colors.grey[400],
                        shape: BoxShape.circle)),
                    SizedBox(width: 8),
                    Text('${selectedExercises.length} selected',
                      style: TextStyle(
                        fontSize: 14,color: Colors.grey[600],
                        fontWeight: FontWeight.w500)),
                    Spacer(),
                    Container(decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30)),
                      child: IconButton(
                        onPressed: addExerciseFlow,
                        icon: Icon(Icons.add,
                          color: Theme.of(context).primaryColor),
                        tooltip: 'Add Exercise',
                      ))],
                )),

              SizedBox(height: 12),
              Expanded(
                child: selectedExercises.isEmpty
                    ? buildEmptyState()
                    : ReorderableListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: selectedExercises.length,
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex--;
                    final item = selectedExercises.removeAt(oldIndex);
                    selectedExercises.insert(newIndex, item);
                    setState(() {});
                  },
                  itemBuilder: (context, index) {
                    return buildExerciseCard(
                      selectedExercises[index],
                      index,
                    );
                  },
                ),
              ),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 16, bottom: 8),
                child: ElevatedButton(
                  onPressed: saveWorkout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save),
                      SizedBox(width: 8),
                      Text('Save Workout',style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,letterSpacing: 1),
                      )]),
                ))],
          ))));
  }

  Widget buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding:  EdgeInsets.all(32),
            decoration: BoxDecoration(color: Colors.grey[200],shape: BoxShape.circle),
            child: Icon(Icons.fitness_center_outlined,
              size: 64,color: Colors.grey[600])),
           SizedBox(height: 24),
          Text('No exercises added',
            style: TextStyle(fontSize: 20,
              fontWeight: FontWeight.bold,color: Colors.grey[800])),
          SizedBox(height: 8),Text(
            'Tap + to add your first exercise',
            style: TextStyle(fontSize: 14,color: Colors.grey[600])),
          SizedBox(height: 24),
        ]));
  }

  Widget buildExerciseCard(WorkoutExerciseInstance exercise,int index) {
    return Container(
      key: ValueKey(exercise.exercise.id),
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,offset: Offset(0, 5),
          )]),
      child: Material(
        color: Colors.transparent,
        child: Padding(padding:  EdgeInsets.all(12),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: index,child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.drag_handle,color: Colors.grey[600],size: 20),
                )),
              SizedBox(width: 12),
              Container(width: 36,height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),shape: BoxShape.circle),
                child: Center(
                  child: Text('${index + 1}',
                    style: TextStyle(color: Theme.of(context).primaryColor,fontWeight: FontWeight.bold,fontSize: 14),
                  ))),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercise.exercise.name,
                      style: TextStyle(fontWeight: FontWeight.bold,
                        fontSize: 16)),
                    SizedBox(height: 4),
                    Container(padding:  EdgeInsets.symmetric(
                        horizontal: 8,vertical: 4),
                      decoration: BoxDecoration(
                        color: getTypeColor(exercise.exerciseTypeName).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [Icon(getTypeIcon(exercise.exerciseTypeName),
                            size: 12,color: getTypeColor(exercise.exerciseTypeName)),
                          SizedBox(width: 4),
                          Text(exercise.exerciseTypeName,
                            style: TextStyle(fontSize: 11,fontWeight: FontWeight.w600,
                              color: getTypeColor(exercise.exerciseTypeName),
                            ))]),
                    ),
                    SizedBox(height: 8),
                    Wrap(spacing: 8,runSpacing: 4,
                      children: buildExerciseTags(exercise),
                    )]),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildActionButton(
                    icon: Icons.edit,color: Colors.blue,tooltip: 'Edit Exercise',
                    onPressed: () async {
                      final updated = await showExerciseAlterDialog(exercise);
                      if (updated != null) {
                        setState(() {});
                      }},
                  ),
                  const SizedBox(width: 4),
                  buildActionButton(
                    icon: Icons.delete,color: Colors.red,
                    tooltip: 'Remove Exercise',
                    onPressed: () => showDeleteDialog(exercise),
                  ),
                ],
              )])),
      )
    );
  }

  Widget buildActionButton({required IconData icon,required Color color,required String tooltip,required VoidCallback onPressed}) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12)),
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        onPressed: onPressed,tooltip: tooltip,
        constraints: BoxConstraints(
          minWidth: 36, minHeight: 36),
        padding: EdgeInsets.zero,
      ));
  }

  List<Widget> buildExerciseTags(WorkoutExerciseInstance exercise) {
    List<Widget> tags = [];
    final type = exercise.exerciseTypeName;

    if(type == 'STRENGTH'){
      if (exercise.sets != null){
        tags.add(buildTag(icon: Icons.repeat,text: '${exercise.sets} sets'));
      }
      if(exercise.reps != null){
        tags.add(buildTag(icon: Icons.fitness_center,text: '${exercise.reps} reps'));
      }
      if(exercise.rest != null){
        tags.add(buildTag(
          icon: Icons.timer,text: 'rest ${exercise.rest}s'));
      }
    } else if(type == 'CARDIO' || type == 'PLYOMETRICS') {
      if(exercise.sets != null){
        tags.add(buildTag(icon: Icons.repeat,text: '${exercise.sets} sets'));
      }
      if(exercise.duration != null){
        tags.add(buildTag(icon: Icons.timer,text: formatDuration(exercise.duration!)));
      }
      if(exercise.rest != null){
        tags.add(buildTag(icon: Icons.hourglass_empty,text: 'rest ${exercise.rest}s'));
      }
    } else if(type == 'AEROBIC'){
      if(exercise.distance != null){
        tags.add(buildTag(icon: Icons.map,text: '${exercise.distance} km'));
      }
    } else if(type == 'STRETCHING'){
      if(exercise.duration != null){
        tags.add(buildTag(
          icon: Icons.timer, text: formatDuration(exercise.duration!)));
      }
    }
    return tags;
  }

  Widget buildTag({required IconData icon,required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],borderRadius: BorderRadius.circular(20)),
      child: Row( mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,size: 12,color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            text,style: TextStyle(fontSize: 11,color: Colors.grey[700],fontWeight: FontWeight.w500)),
        ]),
    );
  }

  void showDeleteDialog(WorkoutExerciseInstance exercise) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red),
                SizedBox(width: 8),Text('Remove Exercise')]),
            content: Text('Are you sure you want to remove ${exercise.exercise.name}?'),
            actions: [
              TextButton( onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  )),
                onPressed: () => Navigator.pop(context, true),
                child: Text('Remove'),
              )]),
    );
    if (confirm == true && mounted) {
      setState(() {
        selectedExercises.remove(exercise);
      });
    }
  }


  Color getTypeColor(String typeName) {
    switch (typeName){
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

  IconData getTypeIcon(String typeName) {
    switch (typeName) {
      case 'STRENGTH':
        return Icons.fitness_center;
      case 'CARDIO':
        return Icons.directions_run;
      case 'PLYOMETRICS':
        return Icons.sports_gymnastics;
      case 'AEROBIC':
        return Icons.directions_bike;
      case 'STRETCHING':
        return Icons.self_improvement;
      default:
        return Icons.fitness_center;
    }
  }

  String formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;

    if (minutes == 0) {
      return '${seconds}s';
    }
    if (remainingSeconds == 0) {
      return '${minutes}min';
    }
    return '${minutes}min ${remainingSeconds}s';
  }
}