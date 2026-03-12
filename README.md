# meFit 

meFit is a cross-platform smart workout assistant mobile application that combines ML and gamification to increase user motivation to participate in physical activity. One of the primary features of the app will be to offer a personalised workout plan every week according to the user’s preferences and needs and track their performance during a workout. The use of ML will mainly focus on offering workout suggestions according to user behaviour and preferences, while gamification elements such as badges and streaks will aim to keep the user interested and encourage physical activity.


## 📋 Table of Contents
- [About The Project](#about-the-project)
- [Development Tools](#development-tools)
- [Getting Started](#getting-started)
- [Usage](#usage)
- [Contact](#contact)

## 🎯 About The Project

Core meFit features include:
- Personalised workout plan, generated every week acoording to training type and training goal of user
- User is able to create their own 'custom' workouts and replace system generated scheduled workouts.
- User can complete a workout and receive feedback and statistics.
- Badges and streaks upon succesfull completion of workouts
- User can change workout preferences and goals, and new workout plan will be generated upon those preferences
- AI Coach Workouts suggestions are generated every week, according to user training type, training goal and performance. The user can replace a weekly workout with an AI suggested workout.

## 🛠 Development Tools

- **Frontend Framework**: Flutter (cross-platform mobile development)
- **Database**: Firebase Firestore (NoSQL cloud database)
- **Backend Services**: Firebase Cloud Functions (serverless functions)
- **Scheduling**: Cron-job.org (for triggering weekly workout generation)
- **Maps & Location**: Google Maps API with Geolocator package
- **State Management**: Flutter's built-in state management with ValueNotifier
- **Data Modeling**: Firestorm package (Firestore ORM for Flutter)
- **Authentication**: Firebase Authentication

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.x or higher)
- [Dart SDK](https://dart.dev/get-dart) (included with Flutter)
- [Git](https://git-scm.com/) (version control)
- [Android Studio](https://developer.android.com/studio)  
- [Node.js](https://nodejs.org/) (for Firebase Cloud Functions, optional)

### Installation

1. **Clone the repository**
  ```bash
  git clone https://github.com/glazari98/me_fit.git 
   ```
2. **Open Android Studio**
    - Open Android Studio and open the directory from the location you saved the github repository.
      
3. **Install Flutter dependencies**
   - In the terminal:
   ```bash
   cd meFit
   flutter pub get
   ```
4. **Install Node.js and Firebase tools for using cloud functions**(Optional)
 ```bash
 cd functions
npm install
npm install -g firebase-tools
firebase login
firebase init functions
 ```
5. **Emulator setup**
   - From the right side menu bar select device manager.
   - If a device is already added it will show there, press ▶️. If not press the + sign to add a device.
   - Then from top menu bar make sure main.dart and the emulator device are selected.
     
6. **Run the app**
   ```bash
   cd meFit
   flutter run
   ```
   
## 📱 Usage
Once the app is running on the emulator
###First time setup
1. Create an account
2. Complete your profile (email,password,username, age, weight, height)
3. Select your training type and goals
4. Set your weekly workout availability
### App usage after login or sign up
1. Once signed up or logged in you will be navigated to 'Home' where you will see your weekly schedule. Dates that include scheduled workouts have a green dot, by clickign on the date, you can see specific details regardign the status of the workout. If you fiurther click on that you can see the workout exercises or workout feedback if the workout is completed. At the top you can see a section 'AI COACH SUGGESTION'. In the area, if a user completes more than oen workout from the week they signed up, then the next week and every other week on Monday, they will get an AI suggested workout. If a workout is displayed there, the user can press 'View Details' where they can view the reason for that workout suggestion, the exercises it includes, and if the user wants they can replace a weekly workout with that. Moreoevr, every Monday the user will get a new weekly schedule with system generated workouts.
2. From the side menu, if you select 'Custom workouts' you will be navigated to a screen wher eyou can search, create and filter workouts created by you. By clicking the create button is takes you to a screen where you can setup your own workout according to what type of exercises you want.
3. From the side menu, if you choose Weekly Workout Program, you will see a list of the workouts for the week, where you can edit a workout, add/remove exercises, change the date and reaplce it with a custom workout created by you. If you change your mind by replacing a system workout to a custom one and you want to rollback, you can choose the swap button and an option called 'Restore Original Workout' will restore the workout originally assigned.
4. From the side menu, if you choose 'Start Workout', a list of weekly workouts appears showing which is ready to be started and which is not according the the scheduled dat eof that workout. If you want to start a workout, you can press the start button. When completing a workout, you can pause or cancel it from top bar. Upon succesfull completion of a workout, feedback will be shown about statistics of sets/reps/duration/distance covered depending on the exercises the workout had.
5. From the side menu, if you choose 'Completed Workouts', you will see a list ordered by workouts completed the latest, you can search accordign to name or filter by date latest/earliest. If you press on a completed workout, feedback corresponding to that workout will be displayed.
6. From the side menu, if you choose 'Achievements', you will see the current streak according to consistent weekly completion of workouts and your best streak. Badges displayed in silver are locked and in gold are unlocked. When pressing on a locked badge you can see the requirement to requirement to unlock it.
7. From the side menu, if you choose 'Statistics', statistics regarding number of workouts, total added duration of completed workouts, total weight lifed, total distance covered and total time doign cardio in the current month will be displayed, if any. Also, a pie chart will b edisplayed showing the most common types of exercises the user does(cardio, stretchign, aerobic, strength,plyometrics). If using the app across months you can see stats for each month inidvidually.
9. From the side menu, at the very bottom if the user presses 'Profile', they will navigate to a screne with two tabs 'Personal Details' and 'Workout Preferences' tabs. In 'Personal Details' tab the user can edit their account information regarding username, age. weight, height and upload an image they wan tto be displayed as their profile image. In 'Workout Details' tab a user can see their current workout preferences. They can choose the edit those options and save the changed preferences, and from next week, the system generated worout schedule will be according to the new preferences.

   
   
## Project Structure
```text
me_fit/
├── lib/
│   ├── components/       # Reusable widgets
│   ├── data/             # Script for inserting data into database from api
│   ├── generated/        # Firestorm model serialisation.
│   ├── models/           # Data models
│   ├── screens/          # UI screens
│   ├── services/         # Business logic
│   ├── theme/            # Project theme configuration
│   └── main.dart         # Entry point
├── assets/
│   ├── images/           # Badge images and logo icon
│   └── sounds/           # Sound effects
├── functions/            # Firebase Cloud Functions
├── android/              # Android-specific files
├── ios/                  # iOS-specific files
└── pubspec.yaml          # Dependencies
```


## Note
Please if something is not clear or you spot a bug, please contact me and I will reply as soon as I can.

## Contact
- Email: glazari@uclan.ac.uk or giorgos.lazari98@gmail.com
- Project link: https://github.com/glazari98/me_fit


