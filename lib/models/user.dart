import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firestorm/annotations/firestorm_object.dart';

@FirestormObject()
class User {

  String id;
  String emailAddress;
  String username;
  int age;
  double weight;
  int height;
  Timestamp? signUpDate;
  String trainingType;
  String? trainingGoal;
  bool hasAccessToGym;
  String? aerobicType;
  double? currentAerobicDistance;
  double? aerobicDistanceGoal;
  int preferredWorkoutsPerWeek;
  String? profileImageUrl;
  int currentStreak;
  int bestStreak;
  int totalCompletedWorkouts;
  List<int>? unlockedBadges;
  List<Timestamp>? badgeUnlockedDates;
  bool newScheduleMessageShown;

 User({
    required this.id,
    required this.emailAddress,
    required this.username,
    required this.age,
    required this.weight,
    required this.height,
    this.signUpDate,
    required this.trainingType,
   this.trainingGoal,
    required this.hasAccessToGym,
    required this.preferredWorkoutsPerWeek,
    required this.currentStreak,
    required this.bestStreak,
    required this.totalCompletedWorkouts,
    this.unlockedBadges,
    this.badgeUnlockedDates,
    this.aerobicType,
    this.aerobicDistanceGoal,
    this.currentAerobicDistance,
    this.profileImageUrl,
    required this.newScheduleMessageShown
});

}