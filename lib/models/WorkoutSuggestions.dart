import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firestorm/annotations/firestorm_object.dart';

@FirestormObject()
class WorkoutSuggestions {
  String id;
  String userId;
  Timestamp forWeekStart;
  String? scheduledWorkoutId; //workout to be replaced, not set, user has to choose
  String suggestedWorkoutId;
  String replacementReason;
  double confidenceScore;
  String status; //pending, accepted, declined
  String trainingType;
  Timestamp createdAt;

  WorkoutSuggestions({
    required this.id,
    required this.userId,
    required this.forWeekStart,
    this.scheduledWorkoutId,
    required this.suggestedWorkoutId,
    required this.replacementReason,
    required this.confidenceScore,
    required this.status,
    required this.trainingType,
    required this.createdAt,
  });
}
