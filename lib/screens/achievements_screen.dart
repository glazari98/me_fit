import 'package:flutter/material.dart';
import 'package:me_fit/models/scheduled_workout.dart';
import 'package:me_fit/services/acheivement_service.dart';

import '../models/user.dart';

class AchievementsScreen extends StatefulWidget {
  final User user;
  final List<ScheduledWorkout> workouts;

  const AchievementsScreen({super.key, required this.user,required this.workouts});
    
  @override
  State<AchievementsScreen> createState() => AchievementsScreenState();

}

class AchievementsScreenState extends State<AchievementsScreen>{
  
  late User user;
  late List<int> unlockedBadges;

  @override
  void initState() {
    super.initState();
    user = widget.user;
    AchievementService().checkWeeklyCompletion(user, widget.workouts);
    unlockedBadges = AchievementService.calculateUnlockedBadges(user.totalCompletedWorkouts);

  }

  @override
  Widget build(BuildContext context){
    return Scaffold(appBar: AppBar(
      title: Text('Achievements'),centerTitle: true,
    ),
      body: Padding(padding: EdgeInsets.all(16.0),
      child: Column(children: [
        buildStatCard('Current Streak','${user.currentStreak}'),
        SizedBox(height:12),
        buildStatCard('Best Streak','${user.bestStreak}'),
        SizedBox(height:20),
        buildStatCard('Total workouts','${user.totalCompletedWorkouts}'),
        SizedBox(height: 20),
        buildBadgesSection(),
        ],)),
    );
  }

  Widget buildStatCard(String title, String value){
    return Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    elevation: 4,child: Padding(padding: EdgeInsets.symmetric(vertical: 24,horizontal: 20),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,style: TextStyle(fontSize: 18,fontWeight: FontWeight.w500)),
        Text(value,style: TextStyle(fontSize: 18,fontWeight: FontWeight.bold)),
      ],)),);
  }

  Widget buildBadgesSection() {
    return Expanded(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Unlocked Badges', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        SizedBox(height: 12),
        Expanded(child: GridView.builder(
            itemCount: AchievementService.badgeMilestones.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, crossAxisSpacing: 12, mainAxisSpacing: 12),
            itemBuilder: (context,index){
              final milestone = AchievementService.badgeMilestones[index];
              final unlocked = unlockedBadges.contains(milestone);
              final imageName = unlocked ? 'assets/images/$milestone.png' : 'assets/images/${milestone}locked.png';
              return Column(children: [
                Image.asset(imageName,height: 80,width: 80,fit: BoxFit.contain),
                SizedBox(height: 4),

              ],);
            }))

      ],
    ));
  }
}