import 'dart:io';
import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/models/scheduled_workout.dart';
import 'package:me_fit/models/user.dart';
import 'package:me_fit/screens/achievements_screen.dart';
import 'package:me_fit/screens/completed_workouts_screen.dart';
import 'package:me_fit/screens/home_screen.dart';
import 'package:me_fit/screens/my_workouts.dart';
import 'package:me_fit/screens/profile_screen.dart';
import 'package:me_fit/screens/start_workout_screen.dart';
import 'package:me_fit/screens/weekly_workouts_screen.dart';
import 'package:me_fit/services/authentication_service.dart';

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
                  MaterialPageRoute(builder: (_) => const MyWorkoutsScreen()),
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
          //achievements
          buildDrawerItem(
            context,icon: Icons.badge,
            title: 'Achievements', route: '/achievements',
            onTap: () async { Navigator.pop(context);
              if (currentRoute != '/achievements') {
                final authService = AuthenticationService();
                final currentUser = authService.getCurrentUser();
                if (currentUser != null) {
                  User? user = await FS.get.one<User>(currentUser.uid);
                  if (user != null && context.mounted) {
                    Navigator.pushReplacement( context,
                      MaterialPageRoute(builder: (_) => AchievementsScreen(
                          user: user, workouts: userSchedule ?? [],
                        ),
                      ),
                    );
                  }}}
            })],
      ),
    );
  }

  void logOut(BuildContext context) async{
    final AuthenticationService authService = AuthenticationService();
    //TODO - Important: Ask the user to confirm log out before logging them out. You can use an AlertDialog.
    authService.logOutUser();
    Navigator.pushReplacementNamed(context, '/login');
  }
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

  Future<User?> loadCurrentUser(AuthenticationService authService) async {
    final currentUser = authService.getCurrentUser();
    if (currentUser == null) return null;
    return await FS.get.one<User>(currentUser.uid);
  }

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