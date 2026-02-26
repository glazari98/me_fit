import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';

import '../models/scheduled_workout.dart';
import '../models/workout.dart';
import '../screens/active_workout_screen.dart';

/// A card widget that displays a scheduled workout with its status and allows the user to start or continue the workout.
class WorkoutCard extends StatelessWidget {

  final ScheduledWorkout scheduledWorkout;
  final VoidCallback onRefresh;

  const WorkoutCard({super.key, required this.scheduledWorkout, required this.onRefresh});

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
          margin: const EdgeInsets.symmetric(vertical: 6),
          color: isCompleted ? Colors.green[50] : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [

                // Icon/Indicator
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getStatusColor(isCompleted, isLocked).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getStatusIcon(isCompleted, isLocked),
                    color: _getStatusColor(isCompleted, isLocked),
                  ),
                ),
                const SizedBox(width: 16),

                // Text Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workout.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        isCompleted
                            ? 'Well done!'
                            : (isLocked
                            ? 'Locked until ${scheduledWorkout.scheduledDate.toDate().day}/${scheduledWorkout.scheduledDate.toDate().month}'
                            ' at ${scheduledWorkout.scheduledDate.toDate().hour.toString().padLeft(2, '0')}:00'
                            : 'Ready to go'),
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),

                // Action Button
                if (!isCompleted)
                  ElevatedButton(
                    onPressed: isLocked
                        ? null
                        : () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ActiveWorkoutScreen(workout: workout, scheduledWorkout: scheduledWorkout)),
                      );
                      onRefresh();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isInProgress ? Colors.orange.shade700 : Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(isInProgress ? 'Continue' : 'Start'),
                  )
                else
                  const Icon(Icons.check_circle, color: Colors.green),

              ],
            ),
          ),
        );
      },
    );
  }

  /// Determines the color based on completion and lock status
  Color _getStatusColor(bool comp, bool lock) {
    if (comp) return Colors.green;
    if (lock) return Colors.redAccent;
    return Colors.orange;
  }

  /// Determines the icon based on completion and lock status
  IconData _getStatusIcon(bool comp, bool lock) {
    if (comp) return Icons.celebration;
    if (lock) return Icons.lock_outline;
    return Icons.fitness_center;
  }

}