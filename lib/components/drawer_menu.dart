import 'dart:io';
import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/models/scheduled_workout.dart';
import 'package:me_fit/models/user.dart';
import 'package:me_fit/screens/achievements_screen.dart';
import 'package:me_fit/screens/completed_workouts_screen.dart';
import 'package:me_fit/screens/home_screen.dart';
import 'package:me_fit/screens/custom_workouts.dart';
import 'package:me_fit/screens/profile_screen.dart';
import 'package:me_fit/screens/statistics_screen.dart';
import 'package:me_fit/screens/start_workout_screen.dart';
import 'package:me_fit/screens/weekly_workouts_screen.dart';
import 'package:me_fit/services/authentication_service.dart';

///Widget for side menu
class AppDrawer extends StatelessWidget {
  final BuildContext scaffoldContext;
  final VoidCallback? onWorkoutUpdated;
  final List<ScheduledWorkout>? userSchedule;
  final Function()? loadSchedule;
  final String currentRoute;

  const AppDrawer({
    required this.scaffoldContext,
    super.key,
    this.onWorkoutUpdated,
    this.userSchedule,
    this.loadSchedule,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {

    return Drawer( child: Column(
        children:[ buildDrawerHeader(context),
          //home
          buildDrawerItem( context,
            icon: Icons.home, title: 'Home',
            route: '/home',onTap: () {
              Navigator.pop(context);
              if (currentRoute != '/home') {
                Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                );
              }}),
          //my workouts
          buildDrawerItem(
            context,icon: Icons.list_alt,
            title: 'Custom Workouts',route: '/my-workouts',
            onTap: () { Navigator.pop(context);
              if (currentRoute != '/my-workouts') {
                Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const CustomWorkouts()),
                );
              }}),
          //weekly Program
          buildDrawerItem(
            context, icon: Icons.calendar_view_week,
            title: 'Weekly Workout Program',
            route: '/weekly-workouts',
            onTap: () async {  Navigator.pop(context);
              if (currentRoute != '/weekly-workouts') {
                await Navigator.pushReplacement( context,
                  MaterialPageRoute( builder: (_) => WeeklyWorkoutsScreen(
                      onWorkoutUpdated: onWorkoutUpdated ?? () {},
                    )),
                );
              }} ),
          //start workout
          buildDrawerItem(
            context,icon: Icons.play_arrow,
            title: 'Start Workout', route: '/start-workout',
            onTap: () { Navigator.pop(context);
              if (currentRoute != '/start-workout') {
                Navigator.pushReplacement( context, MaterialPageRoute(builder: (_) =>  StartWorkoutScreen()),
                ).then((_) {
                  if (loadSchedule != null) {
                    loadSchedule!();
                  }
                });
              }}),
          //completed workouts
          buildDrawerItem(
            context,icon: Icons.done,
            title: 'Completed Workouts', route: '/completed-workouts',
            onTap: () { Navigator.pop(context);
              if (currentRoute != '/completed-workouts') {
                Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const CompletedWorkoutsScreen()),
                );}
            }),

          //achievements
          buildDrawerItem(
            context,icon: Icons.badge,
            title: 'Achievements', route: '/achievements',
            onTap: () async { Navigator.pop(context);
                    Navigator.pushReplacement( context,
                      MaterialPageRoute(builder: (_) => AchievementsScreen()));

            }),
          //progress
          buildDrawerItem(
              context,icon: Icons.analytics,
              title: 'Statistics', route: '/statistics',
              onTap: () async { Navigator.pop(context);
              Navigator.pushReplacement( context,
                  MaterialPageRoute(builder: (_) => StatisticsScreen()));

              }),
          const Spacer(),
          //profile
          buildDrawerItem(
              context, icon: Icons.person,
              title: 'Profile', route: '/profile',
              onTap: () {Navigator.pop(context);
              if (currentRoute != '/profile') {
                Navigator.pushReplacement( context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              }}),
        ],
      ),
    );
  }
  //load user data
  Future<User?> loadCurrentUser(AuthenticationService authService) async {
    final currentUser = authService.getCurrentUser();
    if (currentUser == null) return null;
    return await FS.get.one<User>(currentUser.uid);
  }

  void logOut(BuildContext context) async{
    final AuthenticationService authService = AuthenticationService();
    final confirmLogOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(children: [Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),Text('Log Out'),
          ]),
        content: Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red,foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Log Out'),
          ),
        ],
      ),
    );

    // Only log out if user confirmed
    if (confirmLogOut == true) {
      await authService.logOutUser();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You have successfully logged out'),duration: Duration(seconds: 2)),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/login',(route)=>false);
      }
    }
  //widget for header of side menu
  Widget buildDrawerHeader(BuildContext context) {
    final authService = AuthenticationService();
    return FutureBuilder<User?>(
      future: loadCurrentUser(authService),
      builder: (context, snapshot) {
        return DrawerHeader(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(color: Colors.green.shade900),
          child: !snapshot.hasData? Align(
            alignment: Alignment.center,
            child: CircularProgressIndicator(color: Colors.white),
          )
          : buildUserHeader(snapshot.data!),
        );
      });
  }


  //widget that displays information for user in header
  Widget buildUserHeader(User user) {
    final hasImage = user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('MeFit',style: TextStyle(
            color: Colors.white,fontSize: 28,
            fontWeight: FontWeight.bold,
          )),
        const Spacer(),
        Row(children: [
            CircleAvatar(
              radius: 24,backgroundImage: hasImage ? FileImage(File(user.profileImageUrl!)) : null,
              backgroundColor: Colors.white24,
              child: !hasImage? Text(
                user.username.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: Colors.white,fontWeight: FontWeight.bold,fontSize: 20),
              )
              : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(
                user.username, style: const TextStyle(
                  color: Colors.white,fontSize: 20,
                  fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              )), IconButton(
            onPressed: () => logOut(scaffoldContext),
            icon:  Icon(Icons.logout, color: Colors.white))],
        )],
    );
  }
  //widget to create each tile in side menu
  Widget buildDrawerItem(BuildContext context,{required IconData icon,required String title,
        required String route,required VoidCallback onTap}) {
    final isCurrentScreen = currentRoute == route;
    return Container(
      decoration: BoxDecoration(color: isCurrentScreen ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
        borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        leading: Icon(icon,color: isCurrentScreen ? Theme.of(context).primaryColor : null),
        title: Text(title,style: TextStyle(
            fontWeight: isCurrentScreen ? FontWeight.bold : FontWeight.normal,
            color: isCurrentScreen ? Theme.of(context).primaryColor : null,
          )),
        onTap: onTap, selected: isCurrentScreen,
        selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.1),
      ));
  }
}