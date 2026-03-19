import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:me_fit/generated/firestorm_models.dart';
import 'package:me_fit/models/exercise.dart';
import 'package:me_fit/screens/create_workout_screen.dart';
//Test that check if warning is shown if no exercise is added when creating a workout
//Creates a workout with one exercise and checks if new workout and workout exercises have been added in database
//run 'flutter test integration_test/create_workout_test.dart'
void main(){
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();


  setUpAll(() async{
    WidgetsFlutterBinding.ensureInitialized();
    //initialise firebase if not already initialised
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    await FS.init();
    registerClasses();
    //credentials of a test account i created
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: 'testuser@yourapp.com',
      password: 'TestPassword123!',
    );
  });

  //delete all records created after the test finishes
  tearDownAll(() async{
    final user = FirebaseAuth.instance.currentUser;
    if (user != null){
      final snapshot = await FirebaseFirestore.instance.collection('Workout')
          .where('createdBy', isEqualTo: user.uid)
          .where('name', isEqualTo: 'Test Workout Integration')
          .get();
      //delete workout exercises added
      for (final doc in snapshot.docs) {
        final weSnapshot = await FirebaseFirestore.instance.collection('WorkoutExercises')
            .where('workoutId', isEqualTo: doc.id)
            .get();
        for (final we in weSnapshot.docs){
          await we.reference.delete();
        }
        await doc.reference.delete();
      }
    }
    await FirebaseAuth.instance.signOut(); //sign out after delete
  });

  //test that checks if a warning is showed if user does not add an exercise to the workout
  testWidgets('Shows warning when saving with no exercises',(WidgetTester tester) async{
        await tester.pumpWidget(const MaterialApp(home: CreateWorkoutScreen()));
        await tester.pumpAndSettle();
        //test workout name
        await tester.enterText(find.byType(TextFormField), 'Test Workout Integration');
        await tester.pumpAndSettle();
        //tap button for save without adding exercise
        await tester.tap(find.text('Save Workout'));
        await tester.pumpAndSettle();
        //check for snack bar showing warning message
        expect(find.text('Add at least one exercise'), findsOneWidget);
      });

  //test that saves a workout with one exercise
  testWidgets('Saves a workout successfully and writes to Firestore',
          (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(home: CreateWorkoutScreen()));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField), 'Test Workout Integration');
        await tester.pumpAndSettle();
        final state = tester.state<CreateWorkoutScreenState>(
          find.byType(CreateWorkoutScreen),
        );
        //add data for exercise
        state.selectedExercises.add(
          WorkoutExerciseInstance(
            exercise: Exercise(
              id: 'test-exercise-id-001',
              name: 'Push Up',
              imageUrl: '',
              bodyParts: ['Chest'],
              equipmentId: 'none',
              exerciseTypeId: 'none',
              instruction: '',
              keywords: [],
            ),
            exerciseTypeName: 'STRENGTH',
          )
            ..sets = 3
            ..reps = 12
            ..rest = 60,
        );
        state.setState(() {});
        await tester.pumpAndSettle();

        expect(find.text('Push Up'), findsOneWidget);
        expect(find.text('3 sets'), findsOneWidget);
        expect(find.text('12 reps'), findsOneWidget);

        await tester.tap(find.text('Save Workout'));
        //wait for snack bar to show
        await tester.pump();
        await tester.pump(const Duration(seconds: 4));
        //check for success message
        expect(find.text('Workout successfully created'), findsOneWidget);

        //check if workout exists in firestore
        await tester.pumpAndSettle(const Duration(seconds: 5));
        final user = FirebaseAuth.instance.currentUser!;
        final workoutSnapshot = await FirebaseFirestore.instance.collection('Workout')
            .where('createdBy', isEqualTo: user.uid)
            .where('name', isEqualTo: 'Test Workout Integration')
            .get();
        expect(workoutSnapshot.docs.isNotEmpty, true);
        //check if workout exercise added exists in firestore
        final workoutId = workoutSnapshot.docs.first.id;
        final weSnapshot = await FirebaseFirestore.instance.collection('WorkoutExercises')
            .where('workoutId', isEqualTo: workoutId)
            .get();
        expect(weSnapshot.docs.isNotEmpty, true);
        //check if sets/reps/rest match what was inputed
        final savedExercise = weSnapshot.docs.first.data();
        expect(savedExercise['sets'], equals(3));
        expect(savedExercise['repetitions'], equals(12));
        expect(savedExercise['restBetweenSets'], equals(60));
        expect(savedExercise['order'], equals(1));
      });
}