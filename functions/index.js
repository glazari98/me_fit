const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();

// generate random id for new record
function generateRandomId() {
  return Date.now().toString(36) + Math.random().toString(36).substring(2);
}

// calculate this week's monday
function getThisWeekMonday() {
  const now = new Date();
  const currentDay = now.getDay();

  const daysToMonday = currentDay === 0 ? 6 : currentDay - 1;

  const thisMonday = new Date(now);
  thisMonday.setDate(now.getDate() - daysToMonday);
  thisMonday.setHours(0, 0, 0, 0);
  return thisMonday;
}

// function to help in grouping weeks
function getWeekKey(date) {
  const startOfYear = new Date(date.getFullYear(), 0, 1);
  const days = Math.floor((date - startOfYear) / (24 * 60 * 60 * 1000));
  const weekNumber = Math.ceil((days + startOfYear.getDay() + 1) / 7);
  return `${date.getFullYear()}-W${weekNumber}`;
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

// function called by cron-job.org (every monday 00:00:00)
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

    let successCount = 0;
    let errorCount = 0;

    // Process each user
    for (const user of usersSnapshot.docs) {
      try {
        const userData = user.data();
        const userId = user.id;

        // check if this week's workouts already exist
        const thisMonday = getThisWeekMonday();
        const nextSunday = new Date(thisMonday);
        nextSunday.setDate(thisMonday.getDate() + 6);

        const existingSchedule = await db.collection('ScheduledWorkout')
            .where('userId', '==', userId)
            .where('scheduledDate', '>=', thisMonday)
            .where('scheduledDate', '<=', nextSunday)
            .limit(1)
            .get();
        // if that user has already the next week workouts, skip and move to next user
        if (!existingSchedule.empty) {
          console.log(`User ${userId} already has this week's workouts, skipping`);
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
                durationOfTimedSet: isLastExercise ? 300 : null,
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

          // retrieve workouts of user
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
                  durationOfTimedSet: 300, // 5 minutes stretching
                });
              } else {
                await workoutExercises.set({
                  id: weId,
                  workoutId: workoutId,
                  exerciseId: exercise.id,
                  order: j + 1,
                  sets: sets,
                  durationOfTimedSet: duration,
                  restBetweenSets: rest,
                });
              }
            }

            starterWorkouts.push({id: workoutId});
          }
        } else if (userData.trainingType === 'Aerobic') {
          const aerobicExerciseTypeId = '20260129-1023-8024-a295-ced66eef7c9c';
          const preferredWorkouts = userData.preferredWorkoutsPerWeek;
          const currentDistance = userData.currentAerobicDistance || 5.0; // starting point
          const goalDistance = userData.aerobicDistanceGoal || 10.0; // target goal
          const aerobicType = userData.aerobicType || 'Running';

          // increase by 0.5 km per week
          const weeklyIncrement = 0.5;

          // get workouts up to 4 weeks ago to track progress
          const fourWeeksAgo = new Date();
          fourWeeksAgo.setDate(fourWeeksAgo.getDate() - 28);

          const recentWorkouts = await db.collection('ScheduledWorkout')
              .where('userId', '==', userId)
              .where('isCompleted', '==', true)
              .where('completedDate', '>=', fourWeeksAgo)
              .get();

          // find the most recent week's distance starting form first week user signed up
          let lastWeekDistance = currentDistance;

          if (recentWorkouts.size > 0) {
            const weeklyTotals = {};

            for (const workout of recentWorkouts.docs) {
              const workoutData = workout.data();
              const completedDate = workoutData.completedDate.toDate();

              const weekKey = getWeekKey(completedDate);

              // get the distance for that workout
              const workoutExercisesSnapshot = await db.collection('WorkoutExercises')
                  .where('workoutId', '==', workoutData.workoutId)
                  .get();

              let workoutDistance = 0;
              workoutExercisesSnapshot.docs.forEach((exDoc) => {
                const exData = exDoc.data();
                if (exData.distance) {
                  workoutDistance += exData.distance;
                }
              });

              if (workoutDistance > 0) {
                if (!weeklyTotals[weekKey]) weeklyTotals[weekKey] = 0;
                weeklyTotals[weekKey] += workoutDistance;
              }
            }

            // calculate total distance for that week
            const weeks = Object.keys(weeklyTotals).sort();
            if (weeks.length > 0) {
              const mostRecentWeek = weeks[weeks.length - 1];
              lastWeekDistance = weeklyTotals[mostRecentWeek];
              console.log(`Most recent week (${mostRecentWeek}) distance: ${lastWeekDistance.toFixed(1)}km`);
            }
          }

          // calculate this week's target distance
          let thisWeekDistance;

          if (lastWeekDistance >= goalDistance) {
            // already reached goal, then just continue with the same distance
            thisWeekDistance = goalDistance;
          } else {
            // increment distance
            thisWeekDistance = Math.min(lastWeekDistance + weeklyIncrement, goalDistance);
          }

          // distance splits based on preferred workouts per week
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

            let workoutDistance = thisWeekDistance * distanceSplits[i];
            workoutDistance = Math.round(workoutDistance * 1000) / 1000;
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
          const thisMonday = getThisWeekMonday();
          console.log(thisMonday);
          const scheduledDays = distributeWorkouts(
              Math.min(starterWorkouts.length, userData.preferredWorkoutsPerWeek || 3),
              thisMonday,
          );
          // create scheduled workouts
          for (let i = 0; i < Math.min(starterWorkouts.length, scheduledDays.length); i++) {
            const scheduledDate = new Date(thisMonday);
            scheduledDate.setDate(thisMonday.getDate() + scheduledDays[i]);
            scheduledDate.setHours(0, 0, 0, 0);
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
          await db.collection('User').doc(userId).update({
            newScheduleMessageShown: false,
          });
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

// AI suggestions logic
const {GoogleGenerativeAI} = require('@google/generative-ai');

// initialize Gemini
const genAI = new GoogleGenerativeAI('AIzaSyBdTMJDtPvxDCZLOGoXqgMQJEjtANN5j-g');

exports.generateAISuggestions = functions.https.onRequest(async (req, res) => {
  // secret key for security
  const secretKey = 'ftwe87ftfdc78ewter7tfc98y';
  if (req.query.secret !== secretKey) {
    res.status(403).send('Unauthorized');
    return;
  }

  try {
    // get all users
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
  // get user data
  const userDoc = await db.collection('User').doc(userId).get();
  const userData = userDoc.data();

  // get user's completed workouts from last 4 weeks
  const fourWeeksAgo = new Date();
  fourWeeksAgo.setDate(fourWeeksAgo.getDate() - 28);

  const completedWorkouts = await db.collection('ScheduledWorkout')
      .where('userId', '==', userId)
      .where('isCompleted', '==', true)
      .where('completedDate', '>=', fourWeeksAgo)
      .get();
  if (completedWorkouts.size === 0) {
    console.log(`User ${userId} has not completed any workouts in the last 4 weeks. Skipping AI suggestions.`);
    return;
  }

  // get exercise library filtered by training type and goal
  const exercisesSnapshot = await db.collection('Exercise').get();
  const exerciseTypesSnapshot = await db.collection('ExerciseType').get();
  const bodyPartsSnapshot = await db.collection('BodyPart').get();
  const equipmentSnapshot = await db.collection('Equipment').get();

  // maps to search in exercises body parts and equipments
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


  // adjust exercises to be used in the prompt
  // adjust exercises to be used in the prompt
  const formattedExercises = exercisesSnapshot.docs
      .filter((doc) => {
        const ex = doc.data();
        const typeName = typeMap[ex.exerciseTypeId];
        const equipmentName = equipmentMap[ex.equipmentId];

        // convert to upper case
        const userTrainingType = (userData.trainingType || '').toUpperCase();
        const exerciseType = (typeName || '').toUpperCase();

        // training type filter
        if (userTrainingType === 'STRENGTH') {
          // if training type is strength then filter only strength exercises
          if (exerciseType !== 'STRENGTH') return false;
        } else if (userTrainingType === 'CARDIO') {
          // if training type is Cardio then filter only cardio and plyometrics exercises
          if (!['CARDIO', 'PLYOMETRICS'].includes(exerciseType)) return false;
        } else if (userTrainingType === 'AEROBIC') {
          // if training type is aerobic then filter aerobic exercises and match them by aerobic type and exercise name
          const aerobicType = (userData.aerobicType || '').toLowerCase();
          const exerciseName = (ex.name || '').toLowerCase();

          if (aerobicType === 'running' && !exerciseName.includes('running')) return false;
          if (aerobicType === 'cycling' && !exerciseName.includes('cycling')) return false;
          if (aerobicType === 'swimming' && !exerciseName.includes('swimming')) return false;
        }

        // if user has gym access get all exercises, else get ones with equipment 'BODY WEIGHT'
        if (!userData.hasAccessToGym) {
          const equipmentUpper = (equipmentName || '').toUpperCase();
          if (equipmentUpper !== 'BODY WEIGHT') return false;
        }
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

  console.log(`Total exercises after filtering: ${formattedExercises.length}`);
  // calculate performance
  let workoutPerformance = '';

  if (completedWorkouts.size > 0) {
    workoutPerformance = '\nRECENT WORKOUT PERFORMANCE:\n';

    for (const workout of completedWorkouts.docs) {
      const workoutData = workout.data();
      const completedDate = workoutData.completedDate.toDate();


      const workoutDoc = await db.collection('Workout').doc(workoutData.workoutId).get();
      const workoutName = workoutDoc.exists ? workoutDoc.data().name : 'Unknown Workout';

      // retrieve workout exercises of scheduled workouts
      const workoutExercisesSnapshot = await db.collection('WorkoutExercises')
          .where('workoutId', '==', workoutData.workoutId)
          .get();

      workoutPerformance += `\nWorkout: ${workoutName} (${completedDate.toLocaleDateString()}):\n`;

      let totalExercises = 0;
      let completedExercises = 0;

      for (const weDoc of workoutExercisesSnapshot.docs) {
        const weData = weDoc.data();
        const exercise = formattedExercises.find((e) => e.id === weData.exerciseId);

        if (exercise) {
          totalExercises++;
          let completionRate = 0;
          // for strength get the sets and reps completed
          if (exercise.type === 'STRENGTH') {
            const prescribedSets = weData.sets || 0;
            const completedSets = weData.setsCompleted || 0;
            const prescribedReps = weData.repetitions || 0;
            const completedReps = weData.repsCompleted || 0;

            // Calculate total weight lifted if actual weights exist
            let totalWeightLifted = 0;
            let weightInfo = '';

            if (weData.actualSetWeights && weData.actualSetWeights.length > 0) {
              for (const weight of weData.actualSetWeights) {
                totalWeightLifted += weight;
              }
              if (totalWeightLifted > 0) {
                weightInfo = ` (total weight: ${totalWeightLifted}kg)`;
              }
            }

            if (prescribedSets > 0) {
              const setCompletion = completedSets / prescribedSets;
              const repCompletion = prescribedReps > 0 ? (completedReps / (prescribedSets * prescribedReps)) : 0;
              completionRate = (setCompletion + repCompletion) / 2;
            }

            workoutPerformance += `  - ${exercise.name}: Completed ${completedSets}/${prescribedSets} sets, ${completedReps}/${prescribedSets * prescribedReps} reps${weightInfo}\n`;
          } else if (exercise.type === 'CARDIO' || exercise.type === 'PLYOMETRICS') {
            const prescribedSets = weData.sets || 0;
            const completedSets = weData.setsCompleted || 0;

            if (prescribedSets > 0) {
              completionRate = completedSets / prescribedSets;
            }
            workoutPerformance += `  - ${exercise.name}: Completed ${completedSets}/${prescribedSets} sets\n`;
          } else if (exercise.type === 'AEROBIC') { // for aerobic get the distance covered
            const prescribedDistance = weData.distance || 0;
            const coveredDistance = weData.distanceCovered || 0;

            if (prescribedDistance > 0) {
              completionRate = Math.min(coveredDistance / prescribedDistance, 1);
            }
            workoutPerformance += `  - ${exercise.name}: Covered ${coveredDistance.toFixed(1)}/${prescribedDistance.toFixed(1)} km\n`;
          }

          if (completionRate >= 0.9) completedExercises++;
        }
      }

      const workoutCompletionRate = totalExercises > 0 ? (completedExercises / totalExercises * 100).toFixed(0) : 0;
      workoutPerformance += `  → Workout completion: ${workoutCompletionRate}%\n`;
    }
  }

  // build the prompt with all pre-calculated data
  const prompt = buildPrompt(userData, formattedExercises, workoutPerformance);

  // call Gemini
  const model = genAI.getGenerativeModel({model: 'gemini-2.5-flash'});
  const result = await model.generateContent(prompt);
  const response = result.response.text();

  // clean JSON response
  try {
    let cleanedResponse = response;
    cleanedResponse = cleanedResponse.replace(/```json\n?/g, '');
    cleanedResponse = cleanedResponse.replace(/```\n?/g, '');
    cleanedResponse = cleanedResponse.trim();
    const suggestions = JSON.parse(cleanedResponse);

    await storeSuggestions(userId, suggestions, userData);
  } catch (e) {
    console.error('Failed to parse Gemini response:', e);
    console.error('Original response was:', response);
    await db.collection('FailedSuggestions').add({
      userId: userId,
      prompt: prompt,
      response: response,
      error: e.message,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
}

function buildPrompt(userData, exercises, workoutPerformance) {
  const exerciseList = exercises.slice(0, 50).map((ex) =>
    `ID: ${ex.id}, Name: ${ex.name}, Type: ${ex.type}, Body Parts: ${ex.bodyParts}, Equipment: ${ex.equipment}`,
  ).join('\n');

  let typeSpecificInstructions = '';
  let jsonFormatExample = '';

  if (userData.trainingType === 'Strength') {
    const strengthParams = userData.trainingGoal === 'Muscle Building'?
      {sets: 3, reps: 12, rest: 90, description: 'hypertrophy focus (3x12, 90s rest)'}:
      {sets: 5, reps: 6, rest: 180, description: 'power building focus (5x6, 180s rest)'};

    // use the exercises list to retrieve exercises
    const sampleExerciseId = exercises.length > 0 ? exercises[0].id : 'USE_ACTUAL_ID_FROM_LIST';
    typeSpecificInstructions = `
- For STRENGTH exercises: Include sets (${strengthParams.sets}), reps (${strengthParams.reps}), and rest seconds (${strengthParams.rest})
- IMPORTANT: You MUST use the EXACT exercise IDs from the AVAILABLE EXERCISES list above
- IMPORTANT: Include a "targetSetWeights" array that matches the number of sets
  Example for ${strengthParams.sets} sets: "targetSetWeights": [60, 60, 65] (one weight per set)
- If the user has weight data from previous workouts, suggest progressive overload by increasing weights slightly (2.5-5kg)
- If no weight data exists, you can set the targetSetWeights field to null
- Aim for 6-8 exercises per workout
- GOAL: ${userData.trainingGoal} - ${strengthParams.description}
- Based on recent performance, suggest exercises where the user has high completion rates`;

    jsonFormatExample = `{
  "workoutName": "Upper Body Strength",
  "targetDay": "Monday",
  "replacementReason": "Better muscle balance based on recent workouts",
  "confidenceScore": 0.92,
  "exercises": [
    {
      "exerciseId": "${sampleExerciseId}",
      "sets": ${strengthParams.sets},
      "reps": ${strengthParams.reps},
      "restSeconds": ${strengthParams.rest},
      "targetSetWeights": [60, 60, 65],
      "order": 1,
      "type": "STRENGTH"
    }
  ]
}`;
  } else if (userData.trainingType === 'Cardio') {
    const cardioParams = userData.trainingGoal === 'Endurance'?
      {sets: 1, durationOfTimedSet: 300, rest: 120, description: 'longer duration, fewer sets'}:
      {sets: 5, durationOfTimedSet: 60, rest: 60, description: 'short bursts, more sets'};

    const sampleExerciseId = exercises.length > 0 ? exercises[0].id : 'USE_ACTUAL_ID_FROM_LIST';

    typeSpecificInstructions = `
- For CARDIO/PLYOMETRICS exercises: Include sets (${cardioParams.sets}), duration (${cardioParams.durationOfTimedSet} seconds), and rest seconds (${cardioParams.rest})
- IMPORTANT: You MUST use the EXACT exercise IDs from the AVAILABLE EXERCISES list above
- GOAL: ${userData.trainingGoal} - ${cardioParams.description}
- Based on recent performance, suggest exercises where the user has high completion rates`;

    jsonFormatExample = `{
  "workoutName": "HIIT Cardio Blast",
  "targetDay": "Wednesday",
  "replacementReason": "Mix of intensity based on your ${userData.trainingGoal} goal",
  "confidenceScore": 0.88,
  "exercises": [
    {
      "exerciseId": "${sampleExerciseId}",
      "sets": ${cardioParams.sets},
      "durationOfTimedSet": ${cardioParams.durationOfTimedSet},
      "restSeconds": ${cardioParams.rest},
      "order": 1,
      "type": "CARDIO"
    }
  ]
}`;
  } else if (userData.trainingType === 'Aerobic') {
    const sampleExerciseId = exercises.length > 0 ? exercises[0].id : 'USE_ACTUAL_ID_FROM_LIST';

    typeSpecificInstructions = `
- For AEROBIC exercises: Include distance in km
- Weekly goal: ${userData.aerobicDistanceGoal}km total
- Each workout should have exactly 1 aerobic exercise
- IMPORTANT: You MUST use the EXACT exercise IDs from the AVAILABLE EXERCISES list above
- Based on recent performance, suggest appropriate distances for progression`;

    jsonFormatExample = `{
  "workoutName": "Long Run",
  "targetDay": "Saturday",
  "replacementReason": "Builds endurance with proper weekly distance distribution",
  "confidenceScore": 0.95,
  "exercises": [
    {
      "exerciseId": "${sampleExerciseId}",
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
${userData.trainingType === 'Aerobic' ? `- Weekly Distance Goal: ${userData.aerobicDistanceGoal}km` : ''}

${workoutPerformance || 'No recent workout data available.'}

AVAILABLE EXERCISES (use ONLY these IDs):
${exerciseList}

TASK:
Suggest ONE optimized workout to replace a day in their upcoming weekly schedule.
The workout should match their goal and use available exercises.
Consider their recent performance - suggest exercises they complete successfully.

${typeSpecificInstructions}

IMPORTANT:
- For STRENGTH: Use "sets", "reps", "restSeconds", and optionally "targetSetWeights"
- For CARDIO/PLYOMETRICS: Use "sets", "durationOfTimedSet" (seconds), "restSeconds"
- For AEROBIC: Use "distance" (km)
- Include "type" field for each exercise
- For STRETCHING: Use "durationOfTimedSet" (seconds) only
- CRITICAL: The "exerciseId" MUST be one of the actual IDs from the AVAILABLE EXERCISES list above

Return ONLY valid JSON in this exact format:

${jsonFormatExample}
`;
}

async function storeSuggestions(userId, suggestions, userData) {
  // create workout record for workout suggestion
  const workoutId = generateRandomId();
  await db.collection('Workout').doc(workoutId).set({
    id: workoutId,
    name: suggestions.workoutName || 'Unknown Workout',
    createdBy: userId,
    isMyWorkout: false,
    createdOn: admin.firestore.FieldValue.serverTimestamp(),
  });

  // create workout exercises for workout suggestion
  for (const ex of suggestions.exercises) {
    const weId = generateRandomId();
    const exerciseData = {
      id: weId,
      workoutId: workoutId,
      exerciseId: ex.exerciseId || '',
      order: ex.order || 0,
    };

    // add exercise types with null checks for all fields
    switch (ex.type) {
      case 'STRENGTH':
        exerciseData.sets = ex.sets !== undefined ? ex.sets : null;
        exerciseData.repetitions = ex.reps !== undefined ? ex.reps : null;
        exerciseData.restBetweenSets = ex.restSeconds !== undefined ? ex.restSeconds : null;
        exerciseData.targetSetWeights = ex.targetSetWeights || null;
        break;

      case 'CARDIO':
      case 'PLYOMETRICS':
        exerciseData.sets = ex.sets !== undefined ? ex.sets : null;
        exerciseData.durationOfTimedSet = ex.durationOfTimedSet !== undefined ? ex.durationOfTimedSet : null;
        exerciseData.restBetweenSets = ex.restSeconds !== undefined ? ex.restSeconds : null;
        break;

      case 'AEROBIC':
        exerciseData.distance = ex.distance !== undefined ? ex.distance : null;
        break;

      case 'STRETCHING':
        exerciseData.durationOfTimedSet = ex.durationOfTimedSet !== undefined ? ex.durationOfTimedSet : 300;
        break;

      default:
        console.log('Unknown exercise type:', ex.type);
    }

    // set completion fields to 0 or null (never undefined)
    exerciseData.setsCompleted = null;
    exerciseData.repsCompleted = null;
    exerciseData.durationLasted = null;
    exerciseData.distanceCovered = null;
    exerciseData.stretchingCompleted = null;
    exerciseData.timeForDistanceCovered = null;

    await db.collection('WorkoutExercises').doc(weId).set(exerciseData);
  }

  // create workout suggestion
  const suggestionId = generateRandomId();
  await db.collection('WorkoutSuggestions').doc(suggestionId).set({
    id: suggestionId,
    userId: userId,
    forWeekStart: getThisWeekMonday(),
    scheduledWorkoutId: null,
    suggestedWorkoutId: workoutId,
    replacementReason: suggestions.replacementReason || '',
    confidenceScore: suggestions.confidenceScore || 0,
    status: 'pending',
    trainingType: userData.trainingType,
    trainingGoal: userData.trainingGoal,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}
