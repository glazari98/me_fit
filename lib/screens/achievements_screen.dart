import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/models/scheduled_workout.dart';
import 'package:me_fit/services/acheivement_service.dart';
import 'package:me_fit/services/authentication_service.dart';

import '../components/drawer_menu.dart';
import '../models/user.dart';

class AchievementsScreen extends StatefulWidget {

  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => AchievementsScreenState();

}

class AchievementsScreenState extends State<AchievementsScreen> {
  late User user;
  late List<int> unlockedBadges;
  bool isLoading = true;
  @override
  void initState() {
    super.initState();
    loadData();

  }
  Future<void> loadData() async {
    final currentUser = AuthenticationService().getCurrentUser();
    if (currentUser == null) {
      setState(() => isLoading = false);
      return;
    }
   final scheduledWorkouts = await FS.list.filter<ScheduledWorkout>(ScheduledWorkout)
        .whereEqualTo('userId', currentUser.uid)
        .fetch();
  //retrieve user to pass him into achievement service call
   final userData = await FS.get.one<User>(currentUser.uid);
    if (userData == null) {
      setState(() => isLoading = false);
      return;
    }
    AchievementService().checkWeeklyCompletion(userData, scheduledWorkouts.items);
    //retrieve user again after check weekly completion to see if there are changes with the streak
    final updatedUser = await FS.get.one<User>(currentUser.uid);

    if (updatedUser != null && mounted) {
      setState(() {
        user = updatedUser;
        unlockedBadges = AchievementService.calculateUnlockedBadges(updatedUser.totalCompletedWorkouts);
        isLoading = false;
      });
    }

  }

// ... rest of your code remains the same

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Achievements'),
          centerTitle: true,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(appBar: AppBar(
      title: Text('Achievements'), centerTitle: true,
    ),
      drawer: AppDrawer(scaffoldContext: context,currentRoute: '/achievements'),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Padding( padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Row(
                children: [
                  Container(padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.analytics,color: Theme.of(context).primaryColor,size: 16)),
                  SizedBox(width: 12),
                  Text('YOUR STATS',
                    style: TextStyle(fontSize: 14,fontWeight: FontWeight.w600,letterSpacing: 1.2,color: Colors.grey[700]),
                  )],
              )),
            buildStatCard('Current Streak', '${user.currentStreak}',
                Icons.local_fire_department, Colors.orange),
            SizedBox(height: 12),
            buildStatCard('Best Streak', '${user.bestStreak}', Icons.emoji_events,Colors.amber),
             SizedBox(height: 12),
            buildStatCard('Total Workouts', '${user.totalCompletedWorkouts}', Icons.fitness_center, Colors.green),
            SizedBox(height: 24),
            Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.emoji_events,color: Theme.of(context).primaryColor,size: 16),
                  ),
                  SizedBox(width: 12),
                  Text('UNLOCKED BADGES',
                    style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      letterSpacing: 1.2, color: Colors.grey[700])),
                  SizedBox(width: 8),
                  Container(width: 4,height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],shape: BoxShape.circle)),
                  SizedBox(width: 8),
                  Text('${unlockedBadges.length}/${AchievementService.badgeMilestones.length}',
                    style: TextStyle(
                      fontSize: 14,color: Colors.grey[600],fontWeight: FontWeight.w500),
                  )]),
            ),

            SizedBox(height: 8),
            Expanded(
              child:GridView.builder(
                itemCount: AchievementService.badgeMilestones.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,crossAxisSpacing: 12,
                  mainAxisSpacing: 12,childAspectRatio: 0.9),
                itemBuilder: (context, index) {
                  final milestone = AchievementService.badgeMilestones[index];
                  final unlocked = unlockedBadges.contains(milestone);
                  final imageName = unlocked
                      ? 'assets/images/$milestone.png'
                      : 'assets/images/${milestone}locked.png';
                  return buildBadgeItem(imageName, milestone, unlocked);
                },
              ))],
        ),
      ),
    );
  }

  Widget buildStatCard(String title, String value, IconData icon,Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,end: Alignment.bottomRight,
          colors: [Colors.white,Colors.grey[50]!]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow( color: color.withOpacity(0.1),blurRadius: 12,offset: Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, color: color, size: 20)),
                  SizedBox(width: 12),
                  Text( title,
                    style: TextStyle(
                      fontSize: 16,fontWeight: FontWeight.w500),
                  )]),
              Text(
                value,style: TextStyle(
                  fontSize: 24,fontWeight: FontWeight.bold,color: color),
              )]),
        )),
    );
  }

  Widget buildBadgeItem(String imageName, int milestone, bool unlocked) {
    return GestureDetector(
      onTap: () => showBadgeDetails(milestone, unlocked),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 8,offset:  Offset(0, 2),
            )],
        ),
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded( child: Image.asset(
                imageName,fit: BoxFit.contain,
              )),
            SizedBox(height: 4),
            Text('$milestone',
              style: TextStyle(
                fontSize: 11,fontWeight: FontWeight.bold,
                color: unlocked ? Colors.amber.shade800 : Colors.grey),
              overflow: TextOverflow.ellipsis,
            )]),
      ),
    );
  }

  void showBadgeDetails(int milestone, bool unlocked) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              children: [
                Icon( unlocked ? Icons.emoji_events : Icons.lock,
                  color: unlocked ? Colors.amber.shade700 : Colors.grey,
                ),
                SizedBox(width: 8),
                Text(unlocked ? 'Badge Unlocked!' : 'Badge Locked',
                  style: TextStyle(fontWeight: FontWeight.bold,
                    color: unlocked ? Colors.amber.shade700 : Colors.grey[700],
                  ))],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  unlocked ? 'assets/images/$milestone.png'
                      : 'assets/images/${milestone}locked.png',
                  height: 100, width: 100),
                SizedBox(height: 16),
                Text('Complete $milestone workouts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  )),
                SizedBox(height: 8),
                Text(unlocked ? 'Congratulations! You\'ve earned this badge!'
                      : 'Complete $milestone workouts to unlock this badge.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600],fontSize: 14),
                ),
              ]),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ]),
    );
  }
}