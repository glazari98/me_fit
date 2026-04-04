import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firestorm/firestorm.dart';
import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:me_fit/generated/firestorm_models.dart';
import 'package:me_fit/models/workout.dart';
import 'package:me_fit/models/workoutExercises.dart';
import 'package:me_fit/screens/edit_workout_screen.dart';
//Test that checks if workout exercises of a workout are displayed properly when editing a workout.
//Editing a workout exercise saves changes successfully
//run 'flutter test integration_test/edit_workout_test.dart'
//test login credentials
const testUserEmail = 'testuser@yourapp.com';
const testUserPassword = 'TestPassword123!';
//exercise ids of two strength exercises to be used for the test
const strengthExerciseId = '20260307-1515-8251-8689-f0f93e9dc16b';
const strengthExerciseId2 = '20260307-1515-8349-8404-ad3b12587cfe';

//function to create a test workout with exercises
Future<Workout> createTestWorkoutInFirestore(String userId) async {
  final workoutId = Firestorm.randomID();
  final workout = Workout(
    id: workoutId,
    name: 'Edit Test Workout',
    createdBy: userId,
    isMyWorkout: true,
    createdOn: Timestamp.now(),
  );
  await FS.create.one(workout);
//details of exercise 1
  await FS.create.one(WorkoutExercises(
    id: Firestorm.randomID(),
    workoutId: workoutId,
    exerciseId: strengthExerciseId,
    order: 1,
    sets: 3,
    repetitions: 12,
    restBetweenSets: 60,
  ));
//details of exercise 2
  await FS.create.one(WorkoutExercises(
    id: Firestorm.randomID(),
    workoutId: workoutId,
    exerciseId: strengthExerciseId2,
    order: 2,
    sets: 4,
    repetitions: 10,
    restBetweenSets: 90,
  ));
  return workout;
}

//function called at the end when all tests finished to delet workout and exercises from database
Future<void> deleteTestWorkout(String workoutId) async {
  final exercises = await FirebaseFirestore.instance
      .collection('WorkoutExercises')
      .where('workoutId', isEqualTo: workoutId)
      .get();
  for (final doc in exercises.docs) {
    await doc.reference.delete();
  }
  await FirebaseFirestore.instance
      .collection('Workout')
      .doc(workoutId)
      .delete();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Workout testWorkout;
  late String testUserId;

  //setup firebase/firestorm classes
  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    await FS.init();
    registerClasses();

    //sign in with test account
    final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: testUserEmail,
      password: testUserPassword,
    );
    testUserId = credential.user!.uid;
  });

  //call function to create test workout
  setUp(() async {
    testWorkout = await createTestWorkoutInFirestore(testUserId);
  });

  //delete workout data
  tearDown(() async {
    await deleteTestWorkout(testWorkout.id);
  });

  tearDownAll(() async {
    await FirebaseAuth.instance.signOut();
  });

  //call edit workout screen
  Future<void> pumpEditScreen(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: EditWorkoutScreen(workout: testWorkout)));
        await tester.pumpAndSettle(const Duration(seconds: 5)); //wait to render exercises
  }

  //test to check that exercises load correctly
  testWidgets('Loading workout exercises and display them',(WidgetTester tester) async{
        await pumpEditScreen(tester);
        //workout name shows correctly
        expect(find.text('Editing: Edit Test Workout'), findsOneWidget);

        //two exercise cards visible
        expect(find.text('1'), findsWidgets);
        expect(find.text('2'), findsWidgets);
        //total is 2 exercises
        expect(find.text('2 total'), findsOneWidget);

        //buttons for edit and delete exists
        expect(find.byIcon(Icons.edit), findsNWidgets(2));
        expect(find.byIcon(Icons.delete), findsNWidgets(2));
      });
  //test for edit an exercise and save changes
  testWidgets('EditWorkoutTest',(WidgetTester tester) async{
        await pumpEditScreen(tester);
        await tester.tap(find.byIcon(Icons.edit).first);
        await tester.pumpAndSettle();

        //clear set field and enter new value
        final setsField = find.widgetWithText(TextField, 'Sets (1-8)');
        await tester.tap(setsField);
        await tester.pump();
        await tester.enterText(setsField, '5');
        //clear reps field and enter a new value
        final repsField = find.widgetWithText(TextField, 'Reps (1-50)');
        await tester.tap(repsField);
        await tester.pump();
        await tester.enterText(repsField, '8');
        //save
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        //check for snack bar message
        expect(find.text('Changes saved'), findsOneWidget);
        //wait update to complete
        await tester.pumpAndSettle(const Duration(seconds: 5));

        //check if update values matched with what was entered
        final exercises = await FirebaseFirestore.instance.collection('WorkoutExercises')
            .where('workoutId', isEqualTo: testWorkout.id)
            .where('order', isEqualTo: 1)
            .get();
        final savedData = exercises.docs.first.data();
        expect(savedData['sets'], equals(5)); //expect 5 sets
        expect(savedData['repetitions'], equals(8)); //expect 8 reps
        await tester.pumpAndSettle(const Duration(seconds: 2));
      });

//test to check if removing an exercise works
  testWidgets('Delete button removes exercise from screen',(WidgetTester tester) async{
        await pumpEditScreen(tester);
        expect(find.text('2 total'), findsOneWidget); //workout has 2 exercises

        //tap delete icon
        await tester.tap(find.byIcon(Icons.delete).first);
        await tester.pumpAndSettle();

        //in dialog tap delete button
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle(const Duration(seconds: 5));

        //screen now shows just one exercise
        expect(find.text('1 total'), findsOneWidget);
      });
}