const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();

// generate random id for new record
function generateRandomId() {
  return Date.now().toString(36) + Math.random().toString(36).substring(2);
}

// calculate next week's monday
function getNextWeekMonday() {
  const now = new Date();
  const currentDay = now.getDay();

  // calculate days until next monday
  const daysUntilNextMonday = currentDay === 0 ? 1 : 8 - currentDay;

  const nextMonday = new Date(now);
  nextMonday.setDate(now.getDate() + daysUntilNextMonday);
  nextMonday.setHours(0, 0, 0, 0);
  return nextMonday;
}

// algorithm for distributing workouts
function distributeWorkouts(numWorkouts, startDate) {
  if (numWorkouts === 0) return [];

  const days = [];
  const startDay = startDate.getDay();
  const adjustedStartDay = startDay === 0 ? 6 : startDay - 1; // Make Monday = 0

  if (numWorkouts === 1) {
    days.push(adjustedStartDay);
  } else {
    const availableDays = [0, 1, 2, 3, 4, 5, 6];
    const step = (availableDays.length - 1) / (numWorkouts - 1);
    for (let i = 0; i < numWorkouts; i++) {
      const index = Math.round(i * step);
      days.push(availableDays[index]);
    }
  }
  return days;
}

async function getNextWorkoutNumber(userId) {
  // retrieve all system generated workouts of user
  const workoutsSnapshot = await db.collection('Workout')
      .where('createdBy', '==', userId)
      .where('isMyWorkout', '==', false)
      .get();

  if (workoutsSnapshot.empty) {
    return 1; // begin from one if no workouts exist (new account)
  }
  // get previous workout names and retrieve number
  let maxNumber = 0;
  workoutsSnapshot.docs.forEach((doc) => {
    const name = doc.data().name || '';
    const match = name.match(/Workout (\d+)/);
    if (match) {
      const num = parseInt(match[1], 10);
      if (num > maxNumber) maxNumber = num;
    }
  });

  return maxNumber + 1; // increment number used in workout name
}

// function called by cron-job.org (every sunday 00:00:00)
exports.generateNextWeekWorkouts = functions.https.onRequest(async (req, res) => {
  console.log('Weekly workout generation triggered');

  // secret key used in url for security
  const secretKey = 'g7H2kL9pQ4mR8xW3zN5vB1cF6'; // this a random string created by me
  if (req.query.secret !== secretKey) {
    res.status(403).send('Unauthorized');
    return;
  }

  try {
    // retrieve all users from database
    const usersSnapshot = await db.collection('User').get();
    console.log(`Found ${usersSnapshot.size} users`);

    let successCount = 0;
    let errorCount = 0;

    // Process each user
    for (const user of usersSnapshot.docs) {
      try {
        const userData = user.data();
        const userId = user.id;

        // check if next week's workouts already exist
        const nextMonday = getNextWeekMonday();
        const nextSunday = new Date(nextMonday);
        nextSunday.setDate(nextMonday.getDate() + 6);

        const existingSchedule = await db.collection('ScheduledWorkout')
            .where('userId', '==', userId)
            .where('scheduledDate', '>=', nextMonday)
            .where('scheduledDate', '<=', nextSunday)
            .limit(1)
            .get();
        // if that user has already the next week workouts, skip and move to next user
        if (!existingSchedule.empty) {
          console.log(`User ${userId} already has next week's workouts, skipping`);
          continue;
        }
        // retrieve all exercises
        const exercisesSnapshot = await db.collection('Exercise').get();
        const allExercises = exercisesSnapshot.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
        }));
        // table has no exercises
        if (allExercises.length === 0) {
          console.log('No exercises found');
          errorCount++;
          continue;
        }

        const starterWorkouts = [];

        // algorithm for generating workouts according to training type and goal, same as in sign up screen
        if (userData.trainingType === 'Strength') {
          // retrieve body parts
          const bodyPartsSnapshot = await db.collection('BodyPart').get();
          const bodyParts = bodyPartsSnapshot.docs.map((doc) => ({
            id: doc.id,
            name: doc.data().name,
          }));

          const bodyPartNameToId = {};
          bodyParts.forEach((bp) => {
            bodyPartNameToId[bp.name] = bp.id;
          });

          // workout plans according to availability of user and preferences
          let workoutPlanBodyParts = [];
          const preferredWorkouts = userData.preferredWorkoutsPerWeek || 3;

          if (preferredWorkouts === 1) {
            workoutPlanBodyParts = [[
              'CHEST', 'TRICEPS', 'SHOULDERS', 'UPPER ARMS',
              'QUADRICEPS', 'HIPS', 'THIGHS', 'CALVES', 'FULL BODY',
            ]];
          } else if (preferredWorkouts === 2) {
            workoutPlanBodyParts = [
              ['CHEST', 'CHEST', 'BACK', 'BACK', 'BICEPS', 'BICEPS', 'TRICEPS', 'SHOULDERS', 'FULL BODY'],
              ['THIGHS', 'THIGHS', 'HAMSTRINGS', 'QUADRICEPS', 'QUADRICEPS', 'HIPS', 'HIPS', 'CALVES', 'FULL BODY'],
            ];
          } else if (preferredWorkouts === 3) {
            workoutPlanBodyParts = [
              ['CHEST', 'CHEST', 'TRICEPS', 'TRICEPS', 'SHOULDERS', 'SHOULDERS', 'FULL BODY'],
              ['BACK', 'BACK', 'BACK', 'BACK', 'BICEPS', 'BICEPS', 'FULL BODY'],
              ['THIGHS', 'THIGHS', 'HAMSTRINGS', 'QUADRICEPS', 'HIPS', 'WAIST', 'CALVES', 'FULL BODY'],
            ];
          } else if (preferredWorkouts === 4) {
            workoutPlanBodyParts = [
              ['CHEST', 'CHEST', 'TRICEPS', 'TRICEPS', 'SHOULDERS', 'SHOULDERS', 'FULL BODY'],
              ['BACK', 'BACK', 'BACK', 'BACK', 'BICEPS', 'BICEPS', 'FULL BODY'],
              ['THIGHS', 'THIGHS', 'HAMSTRINGS', 'QUADRICEPS', 'HIPS', 'WAIST', 'CALVES', 'FULL BODY'],
              ['CHEST', 'TRICEPS', 'SHOULDERS', 'UPPER ARMS', 'QUADRICEPS', 'HIPS', 'THIGHS', 'CALVES', 'FULL BODY'],
            ];
          } else {
            workoutPlanBodyParts = [
              ['CHEST', 'CHEST', 'TRICEPS', 'TRICEPS', 'SHOULDERS', 'SHOULDERS', 'FULL BODY'],
              ['BACK', 'BACK', 'BACK', 'BACK', 'BICEPS', 'BICEPS', 'FULL BODY'],
              ['CHEST', 'TRICEPS', 'SHOULDERS', 'UPPER ARMS', 'QUADRICEPS', 'HIPS', 'THIGHS', 'CALVES', 'FULL BODY'],
              ['THIGHS', 'THIGHS', 'HAMSTRINGS', 'QUADRICEPS', 'HIPS', 'WAIST', 'CALVES', 'FULL BODY'],
              ['CHEST', 'TRICEPS', 'SHOULDERS', 'UPPER ARMS', 'QUADRICEPS', 'HIPS', 'THIGHS', 'CALVES', 'FULL BODY'],
            ];
          }

          // assign next workout number to new workout
          const startWorkoutNumber = await getNextWorkoutNumber(userId);

          // create the new workouts
          for (let i = 0; i < workoutPlanBodyParts.length; i++) {
            const workoutNumber = startWorkoutNumber + i;
            const workoutId = generateRandomId();
            const workouts = db.collection('Workout').doc(workoutId);

            await workouts.set({
              id: workoutId,
              name: `Workout ${workoutNumber}`,
              createdBy: userId,
              isMyWorkout: false,
              createdOn: admin.firestore.FieldValue.serverTimestamp(),
            });

            for (let j = 0; j < workoutPlanBodyParts[i].length; j++) {
              const isLastExercise = j === workoutPlanBodyParts[i].length - 1;

              // Filter exercises
              const exercisesForType = allExercises.filter((e) => {
                const equipmentMatch = userData.hasAccessToGym ||
                  e.equipmentId === '20260129-1024-8a43-b037-3d29faa316f7';

                if (isLastExercise) {
                  return e.exerciseTypeId === '20260129-1023-8223-a819-4e81b08f7f14' && equipmentMatch; // assigned strength exercise type id manually
                }

                const bodyPartId = bodyPartNameToId[workoutPlanBodyParts[i][j]];
                const bodyPartMatch = e.bodyParts && e.bodyParts.includes(bodyPartId);

                return bodyPartMatch && equipmentMatch &&
                  e.exerciseTypeId === '20260129-1023-8922-8643-a9a2984d73d5';
              });

              if (exercisesForType.length === 0) continue;

              const exercise = exercisesForType[Math.floor(Math.random() * exercisesForType.length)];

              // set sets/reps/rest based on goal
              let sets; let reps; let rest;
              if (userData.trainingGoal === 'Muscle Building') {
                sets = 3;
                reps = 12;
                rest = 90;
              } else { // Power Building (more sets/less reps)
                sets = 5;
                reps = 6;
                rest = 180;
              }

              const weId = generateRandomId();
              const workoutExercises = db.collection('WorkoutExercises').doc(weId);

              await workoutExercises.set({
                id: weId,
                workoutId: workoutId,
                exerciseId: exercise.id,
                order: j + 1,
                sets: isLastExercise ? null : sets,
                repetitions: isLastExercise ? null : reps,
                restBetweenSets: isLastExercise ? null : rest,
                duration: isLastExercise ? 300 : null,
              });
            }

            starterWorkouts.push({id: workoutId});
          }
        } else if (userData.trainingType === 'Cardio') { // for cardio workouts
          let workoutPlanExerciseTypes = [];
          const preferredWorkouts = userData.preferredWorkoutsPerWeek || 3;

          if (preferredWorkouts === 1) {
            workoutPlanExerciseTypes = [[
              'CARDIO', 'CARDIO', 'CARDIO', 'CARDIO',
              'PLYOMETRICS', 'PLYOMETRICS', 'PLYOMETRICS', 'PLYOMETRICS', 'STRETCHING',
            ]];
          } else if (preferredWorkouts === 2) {
            workoutPlanExerciseTypes = [
              ['CARDIO', 'CARDIO', 'CARDIO', 'CARDIO', 'CARDIO', 'CARDIO', 'STRETCHING'],
              ['PLYOMETRICS', 'PLYOMETRICS', 'PLYOMETRICS', 'PLYOMETRICS', 'PLYOMETRICS', 'PLYOMETRICS', 'PLYOMETRICS', 'PLYOMETRICS', 'STRETCHING'],
            ];
          } else if (preferredWorkouts === 3) {
            workoutPlanExerciseTypes = [
              ['CARDIO', 'CARDIO', 'CARDIO', 'CARDIO', 'CARDIO', 'CARDIO', 'STRETCHING'],
              ['PLYOMETRICS', 'PLYOMETRICS', 'PLYOMETRICS', 'PLYOMETRICS', 'PLYOMETRICS', 'PLYOMETRICS', 'PLYOMETRICS', 'PLYOMETRICS', 'STRETCHING'],
              ['CARDIO', 'CARDIO', 'CARDIO', 'CARDIO', 'PLYOMETRICS', 'PLYOMETRICS', 'PLYOMETRICS', 'PLYOMETRICS', 'STRETCHING'],
            ];
          } else if (preferredWorkouts === 4) {
            workoutPlanExerciseTypes = [
              ['CARDIO', 'CARDIO', 'CARDIO', 'CARDIO', 'CARDIO', 'CARDIO', 'STRETCHING'],
              ['CARDIO', 'CARDIO', 'CARDIO', 'CARDIO', 'PLYOMETRICS', 'PLYOMETRICS', 'PLYOMETRICS', 'PLYOMETRICS', 'STRETCHING'],
              ['PLYOMETRICS', 'PLYOMETRICS', 'PLYOMETRICS', 'PLYOMETRICS', 'PLYOMETRICS', 'PLYOMETRICS', 'STRETCHING'],
              ['CARDIO', 'CARDIO', 'CARDIO', 'CARDIO', 'PLYOMETRICS', 'PLYOMETRICS', 'PLYOMETRICS', 'PLYOMETRICS', 'STRETCHING'],
            ];
          } else { // 5 workouts
            workoutPlanExerciseTypes = [
              ['CARDIO', 'CARDIO', 'CARDIO', 'CARDIO', 'CARDIO', 'CARDIO', 'STRETCHING'],
              ['CARDIO', 'CARDIO', 'CARDIO', 'CARDIO', 'PLYOMETRICS', 'PLYOMETRICS', 'PLYOMETRICS', 'PLYOMETRICS', 'STRETCHING'],
              ['CARDIO', 'CARDIO', 'CARDIO', 'CARDIO', 'PLYOMETRICS', 'PLYOMETRICS', 'PLYOMETRICS', 'PLYOMETRICS', 'STRETCHING'],
              ['PLYOMETRICS', 'PLYOMETRICS', 'PLYOMETRICS', 'PLYOMETRICS', 'PLYOMETRICS', 'PLYOMETRICS', 'STRETCHING'],
              ['CARDIO', 'CARDIO', 'CARDIO', 'CARDIO', 'PLYOMETRICS', 'PLYOMETRICS', 'PLYOMETRICS', 'PLYOMETRICS', 'STRETCHING'],
            ];
          }

          // retrieve starting workout number for this week
          const startWorkoutNumber = await getNextWorkoutNumber(userId);

          // retrieve workous of user
          for (let i = 0; i < workoutPlanExerciseTypes.length; i++) {
            const workoutNumber = startWorkoutNumber + i;
            const workoutId = generateRandomId();
            const workouts = db.collection('Workout').doc(workoutId);

            await workouts.set({
              id: workoutId,
              name: `Workout ${workoutNumber}`,
              createdBy: userId,
              isMyWorkout: false,
              createdOn: admin.firestore.FieldValue.serverTimestamp(),
            });

            const workoutDuration = 2700; // 45 mins in seconds
            // spread duration across all exercises (except stretching)
            const durationPerExercise = Math.round(workoutDuration / (workoutPlanExerciseTypes[i].length - 1));

            for (let j = 0; j < workoutPlanExerciseTypes[i].length; j++) {
              const type = workoutPlanExerciseTypes[i][j];

              // assign exercise type to Id manually
              let exerciseTypeId;
              if (type === 'CARDIO') {
                exerciseTypeId = '20260129-1023-8c23-9480-a118b95f118c';
              } else if (type === 'PLYOMETRICS') {
                exerciseTypeId = '20260129-1023-8923-b650-e37111665694';
              } else { // stretching
                exerciseTypeId = '20260129-1023-8223-a819-4e81b08f7f14';
              }

              // filter exercises according to if user has access to the gym or not.
              const exercisesForType = allExercises.filter((e) => {
                const typeMatch = e.exerciseTypeId === exerciseTypeId;
                const equipmentMatch = userData.hasAccessToGym ||
                  e.equipmentId === '20260129-1024-8a43-b037-3d29faa316f7';
                return typeMatch && equipmentMatch;
              });
              if (exercisesForType.length === 0) continue;

              // shuffle through exercises filtered
              const exercise = exercisesForType[Math.floor(Math.random() * exercisesForType.length)];

              // Set exercise parameters based on goal
              let sets;
              let duration;
              let rest;
              if (userData.trainingGoal === 'Endurance') {
                sets = 1;
                duration = durationPerExercise;
                rest = 120;
              } else { // Fat Loss
                sets = 5;
                duration = 60;
                rest = 60;
              }

              const weId = generateRandomId();
              const workoutExercises = db.collection('WorkoutExercises').doc(weId);

              if (type === 'STRETCHING') {
                await workoutExercises.set({
                  id: weId,
                  workoutId: workoutId,
                  exerciseId: exercise.id,
                  order: j + 1,
                  duration: 300, // 5 minutes stretching
                });
              } else {
                await workoutExercises.set({
                  id: weId,
                  workoutId: workoutId,
                  exerciseId: exercise.id,
                  order: j + 1,
                  sets: sets,
                  duration: duration,
                  restBetweenSets: rest,
                });
              }
            }

            starterWorkouts.push({id: workoutId});
          }
        } else if (userData.trainingType === 'Aerobic') {
          const aerobicExerciseTypeId = '20260129-1023-8024-a295-ced66eef7c9c';
          const preferredWorkouts = userData.preferredWorkoutsPerWeek || 3;
          const aerobicDistance = userData.aerobicDistance || 5.0;
          const aerobicType = userData.aerobicType || 'Running';

          // distance according to user's goal on weekly distance and workouts per week
          let distanceSplits;
          if (preferredWorkouts === 1) {
            distanceSplits = [1.0];
          } else if (preferredWorkouts === 2) {
            distanceSplits = [0.4, 0.6];
          } else if (preferredWorkouts === 3) {
            distanceSplits = [0.25, 0.30, 0.45];
          } else if (preferredWorkouts === 4) {
            distanceSplits = [0.25, 0.30, 0.45];
          } else { // 5 workouts
            distanceSplits = [0.2, 0.15, 0.25, 0.25, 0.15];
          }
          // get next workout number for user's new workout
          const startWorkoutNumber = await getNextWorkoutNumber(userId);

          // create new workouts
          for (let i = 0; i < distanceSplits.length; i++) {
            const workoutNumber = startWorkoutNumber + i;
            const workoutId = generateRandomId();
            const workouts = db.collection('Workout').doc(workoutId);

            await workouts.set({
              id: workoutId,
              name: `Workout ${workoutNumber}`,
              createdBy: userId,
              isMyWorkout: false,
              createdOn: admin.firestore.FieldValue.serverTimestamp(),
            });
            const workoutDistance = aerobicDistance * distanceSplits[i];

            // filter exercise for the aerobic type
            const matchingExercises = allExercises.filter((e) => {
              const typeMatch = e.exerciseTypeId === aerobicExerciseTypeId;
              const aerobicTypeMatch = e.name === aerobicType;
              return typeMatch && aerobicTypeMatch;
            });

            if (matchingExercises.length === 0) {
              console.log(`No matching exercises found for aerobic type: ${aerobicType}`);
              continue;
            }
            // shuffle through that
            const exercise = matchingExercises[Math.floor(Math.random() * matchingExercises.length)];

            const weId = generateRandomId();
            const workoutExercises = db.collection('WorkoutExercises').doc(weId);
            await workoutExercises.set({
              id: weId,
              workoutId: workoutId,
              exerciseId: exercise.id,
              order: 1,
              distance: workoutDistance,
            });

            starterWorkouts.push({id: workoutId});
          }
        }

        // Schedule the workouts
        if (starterWorkouts.length > 0) {
          const nextMonday = getNextWeekMonday();
          const scheduledDays = distributeWorkouts(
              Math.min(starterWorkouts.length, userData.preferredWorkoutsPerWeek || 3),
              nextMonday,
          );
          // create scheduled workouts
          for (let i = 0; i < Math.min(starterWorkouts.length, scheduledDays.length); i++) {
            const scheduledDate = new Date(nextMonday);
            scheduledDate.setDate(nextMonday.getDate() + scheduledDays[i]);

            const scheduledId = generateRandomId();
            await db.collection('ScheduledWorkout').doc(scheduledId).set({
              id: scheduledId,
              userId: userId,
              workoutId: starterWorkouts[i].id,
              originalWorkoutId: starterWorkouts[i].id,
              scheduledDate: scheduledDate,
              isCompleted: false,
              isInProgress: false,
            });
          }

          successCount++;
        }
      } catch (userError) {
        console.error(`Error processing user ${user.id}:`, userError);
        errorCount++;
      }
    }
    // success messages for tracking if the function run correctly
    console.log(`Generation complete. Success: ${successCount}, Errors: ${errorCount}`);
    res.status(200).send(`Success: ${successCount}, Errors: ${errorCount}`);
  } catch (error) { // error for tracking what went wrong
    console.error('Fatal error:', error);
    res.status(500).send(error.message);
  }
});

// AI Suggestions logic
const {GoogleGenerativeAI} = require('@google/generative-ai');

// Initialize Gemini
const genAI = new GoogleGenerativeAI('AIzaSyBdTMJDtPvxDCZLOGoXqgMQJEjtANN5j-g');

exports.generateAISuggestions = functions.https.onRequest(async (req, res) => {
  // Secret key for security
  const secretKey = 'ftwe87ftfdc78ewter7tfc98y';
  if (req.query.secret !== secretKey) {
    res.status(403).send('Unauthorized');
    return;
  }

  try {
    // Get all users (or a specific user for testing)
    const usersSnapshot = await db.collection('User').get();

    for (const userDoc of usersSnapshot.docs) {
      await processUserForAISuggestions(userDoc.id);
    }

    res.status(200).send('AI suggestions generated');
  } catch (error) {
    console.error('Error:', error);
    res.status(500).send(error.message);
  }
});

async function processUserForAISuggestions(userId) {
  // 1. Get user data
  const userDoc = await db.collection('User').doc(userId).get();
  const userData = userDoc.data();

  // 2. Get user's completed workouts from last 2 weeks
  const twoWeeksAgo = new Date();
  twoWeeksAgo.setDate(twoWeeksAgo.getDate() - 14);

  const completedWorkouts = await db.collection('ScheduledWorkout')
      .where('userId', '==', userId)
      .where('isCompleted', '==', true)
      .where('completedDate', '>=', twoWeeksAgo)
      .get();

  // 3. Get exercise library (filtered by training type and gym access)
  const exercisesSnapshot = await db.collection('Exercise').get();
  const exerciseTypesSnapshot = await db.collection('ExerciseType').get();
  const bodyPartsSnapshot = await db.collection('BodyPart').get();
  const equipmentSnapshot = await db.collection('Equipment').get();

  // Create maps for lookups
  const typeMap = {};
  exerciseTypesSnapshot.docs.forEach((doc) => {
    typeMap[doc.id] = doc.data().name;
  });

  const bodyPartMap = {};
  bodyPartsSnapshot.docs.forEach((doc) => {
    bodyPartMap[doc.id] = doc.data().name;
  });

  const equipmentMap = {};
  equipmentSnapshot.docs.forEach((doc) => {
    equipmentMap[doc.id] = doc.data().name;
  });

  // Format exercises for the prompt
  const formattedExercises = exercisesSnapshot.docs
      .filter((doc) => {
        const ex = doc.data();
        // Filter by training type
        const typeName = typeMap[ex.exerciseTypeId];
        if (userData.trainingType === 'Strength' && typeName !== 'STRENGTH') return false;
        if (userData.trainingType === 'Cardio' && !['CARDIO', 'PLYOMETRICS'].includes(typeName)) return false;
        if (userData.trainingType === 'Aerobic' && typeName !== 'AEROBIC') return false;

        // Filter by gym access
        const equipmentName = equipmentMap[ex.equipmentId];
        if (!userData.hasAccessToGym && equipmentName !== 'BODYWEIGHT') return false;

        return true;
      })
      .map((doc) => {
        const ex = doc.data();
        const bodyPartNames = ex.bodyParts.map((id) => bodyPartMap[id] || id).join(', ');
        return {
          id: doc.id,
          name: ex.name,
          type: typeMap[ex.exerciseTypeId] || 'UNKNOWN',
          bodyParts: bodyPartNames,
          equipment: equipmentMap[ex.equipmentId] || 'UNKNOWN',
        };
      });

  // 4. Build the prompt
  const prompt = buildPrompt(userData, completedWorkouts, formattedExercises);

  // 5. Call Gemini
  const model = genAI.getGenerativeModel({model: 'gemini-2.5-flash'});
  const result = await model.generateContent(prompt);
  const response = result.response.text();

  // 6. Clean and parse JSON response
  try {
    // Remove markdown code blocks if present
    let cleanedResponse = response;

    // Remove ```json and ``` markers
    cleanedResponse = cleanedResponse.replace(/```json\n?/g, '');
    cleanedResponse = cleanedResponse.replace(/```\n?/g, '');

    // Trim any whitespace
    cleanedResponse = cleanedResponse.trim();

    console.log('Cleaned response:', cleanedResponse);

    const suggestions = JSON.parse(cleanedResponse);

    // 7. Store in database
    await storeSuggestions(userId, suggestions, userData);
  } catch (e) {
    console.error('Failed to parse Gemini response:', e);
    console.error('Original response was:', response);

    // Optional: Save failed responses for debugging
    await db.collection('FailedSuggestions').add({
      userId: userId,
      prompt: prompt,
      response: response,
      error: e.message,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
}

function buildPrompt(userData, completedWorkouts, exercises) {
  // Format completed workouts data with more detail
  const workoutHistory = completedWorkouts.docs.map((doc) => {
    const sw = doc.data();
    return `Completed on: ${sw.completedDate.toDate()}`;
  }).join('\n');

  // Format exercise list with clear type indicators
  const exerciseList = exercises.slice(0, 50).map((ex) =>
    `ID: ${ex.id}, Name: ${ex.name}, Type: ${ex.type}, Body Parts: ${ex.bodyParts}, Equipment: ${ex.equipment}`,
  ).join('\n');

  // Build type-specific instructions based on user's training type and goal
  let typeSpecificInstructions = '';
  let jsonFormatExample = '';

  if (userData.trainingType === 'Strength') {
    // Match your exact strength logic
    const strengthParams = userData.trainingGoal === 'Muscle Building'?
      {sets: 3, reps: 12, rest: 90, description: 'hypertrophy focus (3x12, 90s rest)'}:
      {sets: 5, reps: 6, rest: 180, description: 'power building focus (5x6, 180s rest)'};

    typeSpecificInstructions = `
- For STRENGTH exercises: Include sets (${strengthParams.sets}), reps (${strengthParams.reps}), and rest seconds (${strengthParams.rest})
- Aim for 6-8 exercises per workout
- GOAL: ${userData.trainingGoal} - ${strengthParams.description}
- Each exercise should follow this pattern unless there's a specific reason to vary`;

    jsonFormatExample = `{
  "workoutName": "Upper Body Strength",
  "targetDay": "Monday",
  "replacementReason": "Better muscle balance based on recent workouts",
  "confidenceScore": 0.92,
  "exercises": [
    {
      "exerciseId": "ex_001",
      "sets": ${strengthParams.sets},
      "reps": ${strengthParams.reps},
      "restSeconds": ${strengthParams.rest},
      "order": 1,
      "type": "STRENGTH"
    }
  ]
}`;
  } else if (userData.trainingType === 'Cardio') {
    // Match your exact cardio logic
    const cardioParams = userData.trainingGoal === 'Endurance'?
      {sets: 1, duration: 'durationPerExercise', rest: 120, description: 'longer duration, fewer sets'}:
      {sets: 5, duration: 60, rest: 60, description: 'short bursts, more sets'};

    typeSpecificInstructions = `
- For CARDIO/PLYOMETRICS exercises: Include sets, duration in seconds, and rest seconds
- GOAL: ${userData.trainingGoal} - ${cardioParams.description}
- ${userData.trainingGoal === 'Endurance'?
    'Use longer duration per exercise (aim for 2-5 minutes) with 1 set and 120s rest between exercises':
    'Use short bursts (45-60 seconds) with 5 sets and 60s rest between sets'}`;

    jsonFormatExample = `{
  "workoutName": "HIIT Cardio Blast",
  "targetDay": "Wednesday",
  "replacementReason": "Mix of intensity based on your ${userData.trainingGoal} goal",
  "confidenceScore": 0.88,
  "exercises": [
    {
      "exerciseId": "ex_002",
      "sets": ${cardioParams.sets},
      "duration": ${cardioParams.duration === 'durationPerExercise' ? 180 : 60},
      "restSeconds": ${cardioParams.rest},
      "order": 1,
      "type": "CARDIO"
    }
  ]
}`;
  } else if (userData.trainingType === 'Aerobic') {
    typeSpecificInstructions = `
- For AEROBIC exercises: Include distance in km
- Progressive overload based on weekly goal: ${userData.aerobicDistance}km total for the week
- Distances should sum to approximately the weekly goal when spread across workouts
- Each workout should have exactly 1 aerobic exercise`;

    jsonFormatExample = `{
  "workoutName": "Long Run",
  "targetDay": "Saturday",
  "replacementReason": "Builds endurance with proper weekly distance distribution",
  "confidenceScore": 0.95,
  "exercises": [
    {
      "exerciseId": "ex_003",
      "distance": 5.2,
      "order": 1,
      "type": "AEROBIC"
    }
  ]
}`;
  }

  return `
You are a personal trainer AI. Based on this user data:

USER PROFILE:
- Training Type: ${userData.trainingType}
- Training Goal: ${userData.trainingGoal || 'Not specified'}
- Gym Access: ${userData.hasAccessToGym}
- Workouts per week: ${userData.preferredWorkoutsPerWeek}
${userData.trainingType === 'Aerobic' ? `- Weekly Distance Goal: ${userData.aerobicDistance}km` : ''}

RECENT COMPLETED WORKOUTS (last 14 days):
${workoutHistory || 'No recent workouts'}

AVAILABLE EXERCISES (use ONLY these):
${exerciseList}

TASK:
Suggest ONE optimized workout to replace a day in their upcoming weekly schedule.
The workout should match their goal and use available exercises.

${typeSpecificInstructions}

IMPORTANT:
- For STRENGTH exercises: Use "sets", "reps", "restSeconds"
- For CARDIO/PLYOMETRICS: Use "sets", "duration" (seconds), "restSeconds"
- For AEROBIC exercises: Use "distance" (km)
- Include a "type" field for each exercise (STRENGTH, CARDIO, PLYOMETRICS, AEROBIC, STRETCHING)
- For STRETCHING exercises (if included as last exercise): Use "duration" (seconds) only, no sets/reps/rest

Return ONLY valid JSON in this exact format:

${jsonFormatExample}
`;
}

async function storeSuggestions(userId, suggestions, userData) {
  // Create a workout document for the suggestion
  const workoutId = generateRandomId();
  await db.collection('Workout').doc(workoutId).set({
    id: workoutId,
    name: suggestions.workoutName,
    createdBy: userId,
    isMyWorkout: false,
    createdOn: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Create workout exercises based on their type
  for (const ex of suggestions.exercises) {
    const weId = generateRandomId();
    const exerciseData = {
      id: weId,
      workoutId: workoutId,
      exerciseId: ex.exerciseId,
      order: ex.order,
    };

    // Add type-specific fields matching your database structure
    switch (ex.type) {
      case 'STRENGTH':
        exerciseData.sets = ex.sets;
        exerciseData.repetitions = ex.reps;
        exerciseData.restBetweenSets = ex.restSeconds;
        break;

      case 'CARDIO':
      case 'PLYOMETRICS':
        exerciseData.sets = ex.sets;
        exerciseData.duration = ex.duration; // duration per set
        exerciseData.restBetweenSets = ex.restSeconds;
        break;

      case 'AEROBIC':
        exerciseData.distance = ex.distance;
        break;

      case 'STRETCHING':
        exerciseData.duration = ex.duration || 300; // default 5 minutes if not specified
        break;

      default:
        console.log('Unknown exercise type:', ex.type);
    }

    // Initialize completion tracking fields to 0/null
    exerciseData.setsCompleted = 0;
    exerciseData.repsCompleted = 0;
    exerciseData.durationLasted = 0;
    exerciseData.distanceCovered = 0;
    exerciseData.stretchingCompleted = false;

    await db.collection('WorkoutExercises').doc(weId).set(exerciseData);
  }

  // Store the suggestion
  const suggestionId = generateRandomId();
  await db.collection('WorkoutSuggestions').doc(suggestionId).set({
    id: suggestionId,
    userId: userId,
    forWeekStart: getNextWeekMonday(),
    scheduledWorkoutId: null,
    suggestedWorkoutId: workoutId,
    replacementReason: suggestions.replacementReason,
    confidenceScore: suggestions.confidenceScore,
    status: 'pending',
    trainingType: userData.trainingType,
    trainingGoal: userData.trainingGoal,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}
