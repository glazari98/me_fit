import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import '../models/scheduled_workout.dart';
import '../models/workout.dart';
import '../screens/active_workout_screen.dart';

///A card widget that displays a scheduled workout with its status and allows the user to start or continue the workout.
class WorkoutCard extends StatefulWidget {
  final ScheduledWorkout scheduledWorkout;
  final VoidCallback onRefresh;

  const WorkoutCard({super.key, required this.scheduledWorkout, required this.onRefresh});

  @override
  State<WorkoutCard> createState() => _WorkoutCardState();
}

class _WorkoutCardState extends State<WorkoutCard> {
  late ScheduledWorkout scheduledWorkout;

  @override
  void initState() {
    super.initState();
    scheduledWorkout = widget.scheduledWorkout;
    fixScheduledDateIfNeeded();
  }
  Future<void> fixScheduledDateIfNeeded() async {
    final date = scheduledWorkout.scheduledDate.toDate();
    //check if time is not in this format 00:00:00
    if (date.hour != 0 || date.minute != 0 || date.second != 0) {
      //update it to make it available at midnight
      final fixedDate = DateTime(date.year,date.month,date.day,0, 0, 0, 0, 0);
      scheduledWorkout.scheduledDate = Timestamp.fromDate(fixedDate);
      await FS.update.one(scheduledWorkout);
      if (mounted) {
        setState(() {});
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Workout?>(
      future: FS.get.one<Workout>(scheduledWorkout.workoutId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 80);

        final workout = snapshot.data!;
        final bool isCompleted = scheduledWorkout.isCompleted;
        final bool isLocked = scheduledWorkout.scheduledDate.toDate().isAfter(DateTime.now());
        final bool isInProgress = scheduledWorkout.isInProgress == true;

        return Card(
          elevation: 0, //flat design
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.withOpacity(0.1)),
          ),
          margin: EdgeInsets.symmetric(vertical: 6),
          color: isCompleted ? Colors.green[50] : Colors.white,
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: getStatusColor(isCompleted, isLocked).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(getStatusIcon(isCompleted, isLocked),
                    color: getStatusColor(isCompleted, isLocked),
                  )),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(workout.name,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text( isCompleted
                            ? 'Well done!': (isLocked ? 'Locked until ${scheduledWorkout.scheduledDate.toDate().day}/${scheduledWorkout.scheduledDate.toDate().month}'
                            ' at ${scheduledWorkout.scheduledDate.toDate().hour.toString().padLeft(2, '0')}:00': 'Ready to go'),
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      )],
                  ),
                ),
                if (!isCompleted)
                  ElevatedButton(
                    onPressed: isLocked
                        ? null: () async {
                      await Navigator.push(
                        context, MaterialPageRoute(builder: (_) => ActiveWorkoutScreen(workout: workout, scheduledWorkout: scheduledWorkout)),
                      );
                      final updated = await FS.get.one<ScheduledWorkout>(scheduledWorkout.id);
                      if (updated != null && mounted) {
                        setState(() => scheduledWorkout = updated);
                      }
                      widget.onRefresh();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isInProgress ? Colors.orange.shade700 : Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(isInProgress ? 'Continue' : 'Start'),
                  )
                else
                  Icon(Icons.check_circle, color: Colors.green)
              ]),
          ));
      },
    );
  }

  ///determines the color based on completion and lock status
  Color getStatusColor(bool comp, bool lock) {
    if (comp) return Colors.green;
    if (lock) return Colors.redAccent;
    return Colors.orange;
  }

  ///determines the icon based on completion and lock status
  IconData getStatusIcon(bool comp, bool lock) {
    if (comp) return Icons.celebration;
    if (lock) return Icons.lock_outline;
    return Icons.fitness_center;
  }

}