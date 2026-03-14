import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/models/scheduled_workout.dart';
import 'package:me_fit/models/workout.dart';
import 'package:me_fit/models/WorkoutSuggestions.dart';
import 'package:me_fit/screens/view_workout_screen.dart';
import 'package:me_fit/services/authentication_service.dart';
//widget for viewing ai suggestions where user can replace that suggestion with a weekly workout program
class SuggestionPreviewScreen extends StatefulWidget {
  final WorkoutSuggestions suggestion;
  final Workout suggestedWorkout;
  final VoidCallback onAccepted;
  final VoidCallback onDeclined;

  const SuggestionPreviewScreen({super.key,required this.suggestion,required this.suggestedWorkout,required this.onAccepted,
    required this.onDeclined});

  @override
  State<SuggestionPreviewScreen> createState() => SuggestionPreviewScreenState();
}

class SuggestionPreviewScreenState extends State<SuggestionPreviewScreen> {
  List<ScheduledWorkout> weeklyWorkouts = [];
  ScheduledWorkout? selectedWorkout;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    loadWeeklyWorkouts();
  }
//fetch weekly workouts which have not been completed yet
  Future<void> loadWeeklyWorkouts() async {
    final currentUser = AuthenticationService().getCurrentUser();
    if (currentUser == null) return;

    final now = DateTime.now();
    final thisMonday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final nextMonday = thisMonday.add(const Duration(days: 7));

    final result = await FS.list.filter<ScheduledWorkout>(ScheduledWorkout)
        .whereEqualTo('userId', currentUser.uid)
        .whereEqualTo('isCompleted', false)
        .whereGreaterThanOrEqualTo('scheduledDate', Timestamp.fromDate(thisMonday))
        .whereLessThan('scheduledDate', Timestamp.fromDate(nextMonday))
        .whereEqualTo('isInProgress',false)
        .fetch();

    if (mounted) {
      setState(() {
        weeklyWorkouts = result.items;
      });
    }
  }
//function for replacing an ai suggestion with a non-completed weekly workout
  Future<void> acceptSuggestion() async {
    if (selectedWorkout == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a workout to replace')),
      );return;
    }
    setState(() => isLoading = true);

    //update ui with new workout
    selectedWorkout!.workoutId = widget.suggestedWorkout.id;
    await FS.update.one(selectedWorkout!);

    //update status of suggestion
    widget.suggestion.status = 'accepted';
    widget.suggestion.scheduledWorkoutId = selectedWorkout!.id;
    await FS.update.one(widget.suggestion);

    if (mounted) {
      widget.onAccepted();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Workout replaced successfully!'),duration: Duration(seconds:2),
        ),
      );
      setState(() => isLoading = false);
    }
  }

//function to decline the ai suggestion and change its status to declined
  Future<void> declineSuggestion() async {
    setState(() => isLoading = true);
    widget.suggestion.status = 'declined';
    await FS.update.one(widget.suggestion);

    if (mounted) {
      widget.onDeclined();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(weeklyWorkouts.isEmpty ? 'Suggestion dismissed': 'Suggestion declined'),duration: Duration(seconds: 2),
        ),
      );
      setState(() => isLoading = false);
    }
  }
//display color for confidence score of ai suggestion
  Color getConfidenceColor(double score) {
    if (score >= 0.8) return Colors.green;
    if (score >= 0.6) return Colors.orange;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final confidencePercent = (widget.suggestion.confidenceScore * 100).round();

    return Scaffold(
      appBar: AppBar(
        title: Text('AI Coach Suggestion')),
      body: isLoading
          ? Center(child: CircularProgressIndicator()): SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.auto_awesome,color: Colors.white,size: 24),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.suggestedWorkout.name,
                    style: TextStyle(
                      color: Colors.white,fontSize: 18,fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8,vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12)),
                    child: Text('$confidencePercent% match',
                      style:  TextStyle(color: Colors.white,fontSize: 12,fontWeight: FontWeight.w500),
                    )),
                ])),
              ],
            ),
          ),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade200)),
              child: Row(
                children: [
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Why this workout?',
                          style: TextStyle(fontWeight: FontWeight.bold,fontSize: 14),
                        ),
                        SizedBox(height: 4),
                        Text(widget.suggestion.replacementReason,style: TextStyle(
                            color: Colors.grey[700],fontSize: 13),
                        )],
                    )),
                ]),
            ),
            SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(context,MaterialPageRoute( builder: (_) => ViewWorkoutScreen(workout: widget.suggestedWorkout),
                    ));
                },
                icon: Icon(Icons.visibility),label: Text('VIEW EXERCISES'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding:EdgeInsets.symmetric(horizontal: 24,vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                )),
            ),
            SizedBox(height: 24),
            //if all scheduled workouts for this week are completed show informational message
            if (weeklyWorkouts.isEmpty)
              Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300)),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text('No workouts available to replace this week. All workouts are completed or in progress!',
                            style: TextStyle(fontSize: 14)),
                        )],
                    )),
                  SizedBox(height: 20),
                ])
            else ...[ //show dropdown to replace if not all scheduled workouts are completed
              Text('REPLACE WORKOUT',style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1.2),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ScheduledWorkout>(
                    value: selectedWorkout,
                    hint: Text('Select workout to replace'),
                    isExpanded: true,
                    items: weeklyWorkouts.map((workout) {
                      return DropdownMenuItem(
                        value: workout,
                        child: FutureBuilder<Workout?>(
                          future: FS.get.one<Workout>(workout.workoutId),
                          builder: (context, snapshot) {
                            final name = snapshot.data?.name ?? 'Loading...';
                            final date = workout.scheduledDate.toDate();
                            return Text('$name (${date.day}/${date.month})');
                          },
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => selectedWorkout = value);
                    },
                  ))),
              SizedBox(height: 20),
            ],
            //if not all scheduled workouts for this week are completed show accept/decline buttons
            if (weeklyWorkouts.isNotEmpty)
              Row(
                children: [
                  Expanded(
                      child: OutlinedButton(
                        onPressed: declineSuggestion,
                        style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            )),
                        child: Text('DECLINE', style: TextStyle(color: Colors.red)),
                      )),
                  SizedBox(width: 12),
                  Expanded(
                      child: ElevatedButton(
                        onPressed: acceptSuggestion,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text('ACCEPT'),
                      )),
                ],
              )
            else
              Row(
                children : [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: declineSuggestion,
                      style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          )),
                      child: Text('Dismiss', style: TextStyle(color: Colors.red)),
                    ))],
              )],
        )),
    );
  }
}