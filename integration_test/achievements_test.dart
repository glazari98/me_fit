import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:me_fit/generated/firestorm_models.dart';
import 'package:me_fit/models/user.dart';
import 'package:me_fit/screens/achievements_screen.dart';
import 'package:me_fit/services/achievement_service.dart';
//This test creates a user with streak stats and 1 unlocked badge and checks if they appear correctly on the screen
//run 'flutter test integration_test/achievements_test.dart'

//test credentials to create an authentication user for this test
const achievementsTestEmail = 'achievements.test@mefit.com';
const achievementsTestPassword = 'AchievementsTest123!';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  String testUserId = '';

  //initialise firebase/firestorm classes
  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    await FS.init();
    registerClasses();

    final credential = await auth.FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: achievementsTestEmail,password: achievementsTestPassword);
    testUserId = credential.user!.uid;
//created user with best streak 5 and current streak 3 (current streak will be displayed as 0 in test screen bcs it depends on a function that checks completion of scheduled workouts in the week, there is no completed workout it wil be zero)
    final testUser = User(
      id: testUserId,
      emailAddress: achievementsTestEmail,
      username: 'AchievementsTestUser',
      age: 25,
      weight: 75.0,
      height: 175,
      signUpDate: Timestamp.now(),
      trainingType: 'Strength',
      trainingGoal: 'Muscle Building',
      hasAccessToGym: false,
      preferredWorkoutsPerWeek: 3,
      currentStreak: 3,
      bestStreak: 5,
      totalCompletedWorkouts: 1,
      unlockedBadges: [AchievementService.badgeMilestones.first],
      badgeUnlockedDates: [Timestamp.now()],
      aerobicType: null,
      aerobicDistanceGoal: null,
      currentAerobicDistance: null,
      profileImageUrl: null,
      newScheduleMessageShown: true,
    );
    await FS.create.one(testUser);
  });

  //delete test user after tests finish
  tearDownAll(() async{
    await auth.FirebaseAuth.instance.signInWithEmailAndPassword(
      email: achievementsTestEmail,password: achievementsTestPassword );
    //find instance and delete it
    await FirebaseFirestore.instance.collection('User')
        .doc(testUserId)
        .delete();

    await auth.FirebaseAuth.instance.currentUser!.delete();
    await auth.FirebaseAuth.instance.signOut();
  });

  //function to navigate to Achievement screen
  Future<void> pumpAchievementsScreen(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: AchievementsScreen()));
    await tester.pumpAndSettle(Duration(seconds: 8));
  }
//test check if stats are displayed for best streak has value 5
    testWidgets('Achievements screen displays best streak to have value 5',(WidgetTester tester) async{
        await pumpAchievementsScreen(tester);
        expect(find.text('Best Streak'), findsOneWidget);
        expect(find.byWidgetPredicate((widget) =>
          widget is Text && widget.data == '5' && widget.style?.fontSize == 24),
          findsOneWidget); //there are more widgets with value 5 so we test to make it specific to how best streak font is displayed
        await tester.pumpAndSettle(Duration(seconds: 2));
      });
//achievement screen shows 1 unlocked badge
  testWidgets('UnlockedBadgeTest',(WidgetTester tester) async{
        await pumpAchievementsScreen(tester);
        final totalBadges = AchievementService.badgeMilestones.length;
        expect(find.text('1/$totalBadges'),findsOneWidget); //total badges shows 1 unlocked

        //tap first milestone badge
        final firstMilestone = AchievementService.badgeMilestones.first;
        await tester.tap(find.text('$firstMilestone').first);
        await tester.pumpAndSettle();

        //dialog shows the completion of 1 workout
        expect(find.text('Completed $firstMilestone workout${firstMilestone > 1 ? 's' : ''}'),
          findsOneWidget);

        await tester.pumpAndSettle(Duration(seconds: 2));
      });
}