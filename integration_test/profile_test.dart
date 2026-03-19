import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:me_fit/generated/firestorm_models.dart';
import 'package:me_fit/models/user.dart';
import 'package:me_fit/screens/profile_screen.dart';
//This test creates a test user with strength training type and muscle building training goal, 3 days workout per week and no gym access.
//Confirms these show in Workout Preference tab and edit preferences to see if changes apply.
//run 'flutter test integration_test/profile_test.dart'

//test credentials to sign in
const profileTestEmail = 'profile.test.user@mefit.com';
const profileTestPassword = 'ProfileTest123!';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  String testUserId = '';
  //setup firebase/firestorm classes
  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    await FS.init();
    registerClasses();

    //create authentication use
    final credential = await auth.FirebaseAuth.instance
        .createUserWithEmailAndPassword(
      email: profileTestEmail,
      password: profileTestPassword,
    );
    testUserId = credential.user!.uid;

    //create test user in firestore
    final testUser = User(
      id: testUserId,
      emailAddress: profileTestEmail,
      username: 'ProfileTestUser',
      age: 25,
      weight: 75.0,
      height: 175,
      signUpDate: Timestamp.now(),
      trainingType: 'Strength',
      trainingGoal: 'Muscle Building',
      hasAccessToGym: false,
      preferredWorkoutsPerWeek: 3,
      aerobicType: null,
      aerobicDistanceGoal: null,
      currentAerobicDistance: null,
      profileImageUrl: null,
      currentStreak: 0,
      bestStreak: 0,
      totalCompletedWorkouts: 0,
      unlockedBadges: [],
      badgeUnlockedDates: [],
      newScheduleMessageShown: true,
    );
    await FS.create.one(testUser);
  });
  //reset to set every test to strength muscle building
  setUp(() async {
    if (testUserId.isEmpty) return;

    final resetUser = User(
      id: testUserId,
      emailAddress: profileTestEmail,
      username: 'ProfileTestUser',
      age: 25,
      weight: 75.0,
      height: 175,
      trainingType: 'Strength',
      trainingGoal: 'Muscle Building',
      hasAccessToGym: false,
      preferredWorkoutsPerWeek: 3,
      aerobicType: null,
      aerobicDistanceGoal: null,
      currentAerobicDistance: null,
      profileImageUrl: null,
      currentStreak: 0,
      bestStreak: 0,
      totalCompletedWorkouts: 0,
      unlockedBadges: [],
      badgeUnlockedDates: [],
      newScheduleMessageShown: true,
    );
    await FS.update.one<User>(resetUser);
    await Future.delayed(const Duration(milliseconds: 500));
  });

  //delete all created records for this test
  tearDownAll(() async {
    //sign in
    await auth.FirebaseAuth.instance.signInWithEmailAndPassword(
      email: profileTestEmail,password: profileTestPassword);

    //delete user in firestore
    await FirebaseFirestore.instance.collection('User')
        .doc(testUserId)
        .delete();
    await auth.FirebaseAuth.instance.currentUser!.delete();

  await auth.FirebaseAuth.instance.signOut();
  });

  //function to open profile screen
  Future<void> pumpProfileAndGoToPreferences(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ProfileScreen()),
    );
    await tester.pumpAndSettle(const Duration(seconds: 6));

    //go to workout preference tab
    await tester.tap(find.text('Workout Preferences'));
    await tester.pumpAndSettle();
  }
//test to check if workout preferences tab displays current user preferences
  testWidgets('Workout Preferences tab displays correct preferences of user',(WidgetTester tester) async{
    await pumpProfileAndGoToPreferences(tester);

    expect(find.text('Strength'), findsWidgets);

    //training goals should be Muscle Building and Power Building
    expect(find.text('Training Goal'), findsOneWidget);
    expect(find.text('Muscle Building'), findsWidgets);
    expect(find.text('Power Building'), findsWidgets);
    //no access to gym - ensure corresponding text exists
    expect(find.text('Gym Access'), findsOneWidget);
    expect(find.text('Home Workout'), findsOneWidget);
    expect(find.text('Bodyweight only'), findsOneWidget);
    //ensure it shows 3 workouts per week
    expect(find.text('Workouts per Week'), findsOneWidget);
    expect(find.text('3 days per week'), findsOneWidget);

    //save button not visible
    expect(find.text('Save Preferences'), findsNothing);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  });

  //go to workout preferences tab and change training goal to power building, and save
  testWidgets('Change training goal and check changes applied in database',(WidgetTester tester) async{
        await pumpProfileAndGoToPreferences(tester);

        //tab power building
        await tester.tap(find.text('Power Building').first);
        await tester.pumpAndSettle();

        //check if save preferences button is visible
        expect(find.text('Save Preferences'), findsOneWidget);
        //press save preferences
        await tester.tap(find.text('Save Preferences'));
        await tester.pumpAndSettle();

        //dialog appears
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('If you save your changes, your workouts will be generated with '
                'your new preferences starting from next week.'),findsOneWidget);
        //tap save in dialog
        await tester.tap(find.text('Save').last);
        await tester.pump();
        await tester.pump(Duration(seconds: 3));

        //verify changes applied in Firestore
        final doc = await FirebaseFirestore.instance.collection('User').doc(testUserId).get();
        final data = doc.data()!;
        expect(data['trainingGoal'], equals('Power Building'));
        expect(data['trainingType'], equals('Strength'));
        await tester.pumpAndSettle(const Duration(seconds: 2));
      });
}