import 'package:firestorm/fs/fs.dart';
import 'package:me_fit/models/scheduled_workout.dart';

import '../models/user.dart';

class AchievementService{

  static const List<int> badgeMilestones = [ 1,5,10,20,50,100,200,500,1000,2000];

  String getBadgeImage(int milestone) => 'assets/images/$milestone.png';
  //after completing a workout, increase streak, check for unlocked badge
  void updateAfterWorkout(User user) {
    user.totalCompletedWorkouts += 1;
    user.currentStreak += 1;
    if(user.currentStreak > user.bestStreak ){
      user.bestStreak = user.currentStreak;
    }

    for (var milestone in badgeMilestones){
      if(user.totalCompletedWorkouts >= milestone && !user.unlockedBadges!.contains(milestone)){
        user.unlockedBadges?.add(milestone);
      }
    }
  }
  //check streak after a week has passed, if there incomplete workouts in past week, kae streak to zero
  Future<void> checkWeeklyCompletion(User user, List<ScheduledWorkout> workouts) async {
    final now = DateTime.now();

    final currentMonday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));

    final lastMonday = currentMonday.subtract(Duration(days: 7));
    final lastSunday = currentMonday.subtract(Duration(seconds: 1));

    final lastWeekWorkouts = workouts.where((w) =>!w.scheduledDate.toDate().isBefore(lastMonday) && !w.scheduledDate.toDate().isAfter(lastSunday)).toList();

    final lastWeekAllCompleted =lastWeekWorkouts.isNotEmpty && lastWeekWorkouts.every((w) => w.isCompleted);

    if (lastWeekAllCompleted) {
      return;
    }

    final currentSunday = currentMonday.add(Duration(days:6,hours:23,minutes:59,seconds:59));

    final currentWeekWorkouts = workouts.where((w) => !w.scheduledDate.toDate().isBefore(currentMonday) && !w.scheduledDate.toDate().isAfter(currentSunday)
    ).toList();

    final completedThisWeek = currentWeekWorkouts.where((w) => w.isCompleted).length;
    if(completedThisWeek > 0) {
      user.currentStreak = completedThisWeek;
      await FS.update.one(user);
    }else{
      user.currentStreak = 0;
      await FS.update.one(user);
    }
  }

  static int calculateTotalWorkoutsCompleted(List<ScheduledWorkout> workouts){
    return workouts.where((w) => w.isCompleted).length;
  }

  //Iterates backwards from the most recent workout
  //Counts consecutive completed workouts until an incomplete or future workout is found
  //Skips future workouts in the calculation
  static int calculateCurrentStreak(List<ScheduledWorkout> workouts){
    workouts.sort((a,b) => a.scheduledDate.compareTo(b.scheduledDate));

    int streak =0;
    for(int i = workouts.length - 1;i>=0;i--){
      final workout = workouts[i];
      if(workout.scheduledDate.toDate().isAfter(DateTime.now())){
        continue;
      }

      if(workout.isCompleted){
        streak++;
      }else{
        break;
      }
    }
    return streak;
  }
  //Calculates the user's all-time best streak.
  //Iterates through all workouts in chronological order
  //Tracks the current consecutive completed workouts
  //Updates the best streak whenever current exceeds it
  //Resets current counter when an incomplete workout is encountered
  static int calculateBestStreak(List<ScheduledWorkout> workouts){

    int best =0;
    int current =0;
    for (final workout in workouts){
      if(workout.isCompleted){
        current++;
        if(current > best)best = current;
      }else{
        current = 0;
      }
    }
    return best;
  }

  static List<int> calculateUnlockedBadges(int totalCompleted){
    return badgeMilestones.where((milestone) => totalCompleted>=milestone).toList();
  }
}