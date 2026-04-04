import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firestorm/firestorm.dart';
import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:me_fit/generated/firestorm_models.dart';
import 'package:me_fit/models/WorkoutSuggestions.dart';
import 'package:me_fit/models/scheduled_workout.dart';
import 'package:me_fit/models/workout.dart';
import 'package:me_fit/screens/suggestion_view_screen.dart';
//view an ai suggestion and replace a system generated workout with a i suggested one
//run 'flutter test integration_test/ai_suggestion_test.dart'

//fake credentials for user to create a user in Authentication
const suggestionTestEmail = 'suggestion.test@mefit.com';
const suggestionTestPassword = 'SuggestionTest123!';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  String testUserId = '';
  late Workout originalWorkout;
  late Workout suggestedWorkout;
  late ScheduledWorkout scheduledWorkout;
  late WorkoutSuggestions suggestion;

  //setup firebase/firestorm classes
  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    await FS.init();
    registerClasses();

    //authentication account
    final credential = await auth.FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: suggestionTestEmail,password: suggestionTestPassword);
    testUserId = credential.user!.uid;
  });

  setUp(() async {
    if (testUserId.isEmpty) return;

    //create a workout that will show at the scheduled workout
    originalWorkout = Workout(
      id: Firestorm.randomID(),
      name: 'Original Weekly Workout',
      createdBy: testUserId,
      isMyWorkout: false,
      createdOn: Timestamp.now(),
    );
    await FS.create.one(originalWorkout);

    //create ai suggested workout
    suggestedWorkout = Workout(
      id: Firestorm.randomID(),
      name: 'AI Suggested Workout',
      createdBy: testUserId,
      isMyWorkout: false,
      createdOn: Timestamp.now(),
    );
    await FS.create.one(suggestedWorkout);

    //create scheduled workout
    final now = DateTime.now();
    final thisMonday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    scheduledWorkout = ScheduledWorkout(
      id: Firestorm.randomID(),
      userId: testUserId,
      workoutId: originalWorkout.id,
      originalWorkoutId: originalWorkout.id,
      scheduledDate: Timestamp.fromDate(thisMonday),
      isCompleted: false,
      isInProgress: false,
      completedDate: null,
      totalDuration: null,
      currentExerciseIndex: null,
      currentSet: null,
      elapsedSeconds: null,
      remainingSeconds: null,
      aerobicStartSeconds: null,
      currentPhase: null,
    );
    await FS.create.one(scheduledWorkout);

    //create ai suggested workout
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    suggestion = WorkoutSuggestions(
      id: Firestorm.randomID(),
      userId: testUserId,
      forWeekStart: Timestamp.fromDate(weekStart),
      scheduledWorkoutId: null,
      suggestedWorkoutId: suggestedWorkout.id,
      replacementReason: 'This workout better matches your current fitness level and recovery status.',
      confidenceScore: 0.87,
      status: 'pending',
      trainingType: 'Strength',
      createdAt: Timestamp.now(),
    );
    await FS.create.one(suggestion);
    await Future.delayed(Duration(milliseconds: 500));

  });

  //after every test delete all records created
  tearDown(() async {
    final docs = [
      FirebaseFirestore.instance.collection('Workout').doc(originalWorkout.id),
      FirebaseFirestore.instance.collection('Workout').doc(suggestedWorkout.id),
      FirebaseFirestore.instance.collection('ScheduledWorkout').doc(scheduledWorkout.id),
      FirebaseFirestore.instance.collection('WorkoutSuggestions').doc(suggestion.id),
    ];
    for (final doc in docs) {
      await doc.delete();
    }
    await Future.delayed(Duration(milliseconds: 500));

  });

  //delete authentication account
  tearDownAll(() async {
    await auth.FirebaseAuth.instance.signInWithEmailAndPassword(
      email: suggestionTestEmail,
      password: suggestionTestPassword,
    );
    await auth.FirebaseAuth.instance.currentUser!.delete();
    await auth.FirebaseAuth.instance.signOut();
  });

  //function that opens to suggestion screen
    Future<void> pumpSuggestionScreen(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SuggestionPreviewScreen(suggestion: suggestion,suggestedWorkout: suggestedWorkout,
        onAccepted: () {}, onDeclined: () {})));
    await tester.pumpAndSettle(const Duration(seconds: 6));
  }
//suggestion screen displays all widgets
  testWidgets('AISuggestionTest',(WidgetTester tester) async{
        await pumpSuggestionScreen(tester);
        //name and confidence score displayed
        expect(find.text('AI Suggested Workout'), findsOneWidget);

        //view exercises button shown
        expect(find.text('VIEW EXERCISES'), findsOneWidget);
        //dropdown to choose from incomplete scheduled workouts
        expect(find.text('Select workout to replace'), findsOneWidget);
        //accept/decline buttons
        expect(find.text('ACCEPT'), findsOneWidget);
        expect(find.text('DECLINE'), findsOneWidget);
        await tester.pumpAndSettle(Duration(seconds: 2));
      });


//test to see if user chooses to replace scheduled workout with ai suggestion, if workout is updated correctly
  testWidgets('AcceptAISuggestionTest',(WidgetTester tester) async{
        await pumpSuggestionScreen(tester);
        //select scheduled workout from dropdown
        await tester.tap(find.text('Select workout to replace'));
        await tester.pumpAndSettle(Duration(seconds: 3));

        //create dropdown details
        final now = DateTime.now();
        final thisMonday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        final expectedLabel ='Original Weekly Workout (${thisMonday.day}/${thisMonday.month})';
        //tap item in dropdown
        await tester.tap(find.text(expectedLabel).last);
        await tester.pumpAndSettle();

        //press accept
        await tester.tap(find.text('ACCEPT'));
        await tester.pump();
        await tester.pump(Duration(seconds: 5)); //wait for changes to apply in database

        //check confirmation message
        expect(find.text('Workout replaced successfully!'), findsOneWidget);

        await tester.pumpAndSettle(Duration(seconds: 3));

        //check scheduled workout has the suggested workout id
        final swDoc = await FirebaseFirestore.instance.collection('ScheduledWorkout')
            .doc(scheduledWorkout.id).get();
        expect(swDoc.data()!['workoutId'],equals(suggestedWorkout.id));

        await tester.pumpAndSettle(Duration(seconds: 2));
      });
}