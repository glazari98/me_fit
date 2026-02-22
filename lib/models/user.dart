import 'package:firestorm/annotations/firestorm_object.dart';

@FirestormObject()
class User {

  String id;
  String emailAddress;
  String username;
  int age;
  double weight;
  String trainingType;
  bool hasAccessToGym;
  int preferredWorkoutsPerWeek;
  String? aerobicType;
  double? aerobicDistance;
  String? profileImageUrl;
  int currentStreak;
  int bestStreak;
  int totalCompletedWorkouts;
  List<int>? unlockedBadges;

 User({
    required this.id,
    required this.emailAddress,
    required this.username,
    required this.age,
    required this.weight,
    required this.trainingType,
    required this.hasAccessToGym,
    required this.preferredWorkoutsPerWeek,
    required this.currentStreak,
    required this.bestStreak,
    required this.totalCompletedWorkouts,
    this.unlockedBadges,
    this.aerobicType,
    this.aerobicDistance,
    this.profileImageUrl
});

}