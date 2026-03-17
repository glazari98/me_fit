import 'dart:collection';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/components/drawer_menu.dart';
import 'package:me_fit/models/WorkoutEvent.dart';
import 'package:me_fit/screens/custom_workouts.dart';
import 'package:me_fit/screens/start_workout_screen.dart';
import 'package:me_fit/screens/suggestion_view_screen.dart';
import 'package:me_fit/screens/view_workout_screen.dart';
import 'package:me_fit/screens/workout_feedback_screen.dart';
import 'package:me_fit/services/authentication_service.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/WorkoutSuggestions.dart';
import '../models/scheduled_workout.dart';
import '../models/user.dart';
import '../models/workout.dart';
import '../models/workoutExercises.dart';
import '../utilityFunctions/utility_functions.dart';

//home screen showing workout calendar and ai workout suggestions
class HomeScreen extends StatefulWidget{
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen>{
  final AuthenticationService authService = AuthenticationService();
  int selectedIndex = 0;

  List<ScheduledWorkout> userSchedule = [];
  late LinkedHashMap<DateTime,List<WorkoutEvent>> kEvents;
  late ValueNotifier<List<WorkoutEvent>> selectedEvents;

  DateTime focusedDay = DateTime.now();
  DateTime? selectedDay;
  CalendarFormat calendarFormat = CalendarFormat.month;
  //variables for showing welcome message
  bool showWelcomeMessage = false;
  bool isSunday = false;
  int workoutsScheduled = 0;
  int remainingDays = 0;
  //variables for showing message when new workouts are generated every week
  bool showNewScheduleMessage = false;
  int newWorkoutsCount = 0;

  List<WorkoutSuggestions> pendingSuggestions = [];
  bool isLoadingSuggestions = false;
  bool showSuggestions = true;

  @override
//for showing welcome message once user sings up
  void didChangeDependencies(){
    super.didChangeDependencies();

    final arguments = ModalRoute.of(context)?.settings.arguments as Map?;
    if(arguments != null && arguments['justSignedUp'] == true) {
      setState(() {
        isSunday = arguments['isSunday'] ?? false;//check if it's sunday
        workoutsScheduled = arguments['workoutsScheduled'] ?? 0;
        remainingDays = arguments['remainingDays'];
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        showWelcomeDialog();
      });
    }
  }
  //welcome message accordign to what day it is
  void showWelcomeDialog() {
    String message;
    IconData icon;
    Color color;

    if(isSunday){
      message = "Since you signed up on a Sunday, your first weekly schedule will be generated tomorrow (Monday). Every Monday you'll receive a new workout schedule for the week with $workoutsScheduled workout${workoutsScheduled > 1 ? 's' : ''}.";
      icon = Icons.weekend;
      color = Colors.orange;
    }else{
      int days = remainingDays - 1;
      message = "A workout schedule has been generated for you for the remaining $days day${days > 1 ? 's' : ''} of this week. Every Monday you'll receive a new weekly schedule with $workoutsScheduled workout${workoutsScheduled > 1 ? 's' : ''}";
      icon = Icons.calendar_today;
      color = Colors.green;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              SizedBox(width: 12),
              Text('Welcome to MeFit! 🎉', style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold))],
          ),
          content: Text(
            message,style: TextStyle(fontSize: 16, height: 1.5)),
          actions: [
            TextButton(
              onPressed:(){
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.of(context).pushReplacementNamed(
                    '/home',arguments: null);
                });
              },style: TextButton.styleFrom(foregroundColor: color),
              child: Text('Got it!'),
            )
          ]);
      });
  }
  //function for checking if in the current week the system has new workouts
  Future<void> checkForNewScheduleMessage() async {
    final currentUser = authService.getCurrentUser();
    if (currentUser == null) return;

    final user= await FS.get.one<User>(currentUser.uid);

    if (user != null && !user.newScheduleMessageShown) {
      // Get workouts count for this week to show in dialog
      final now = DateTime.now();
      final thisMonday = now.subtract(Duration(days: now.weekday - 1));
      final thisMondayNormalised = normaliseDate(thisMonday);

      final thisWeekWorkouts = await FS.list.filter<ScheduledWorkout>(ScheduledWorkout)
          .whereEqualTo('userId', currentUser.uid)
          .whereGreaterThanOrEqualTo('scheduledDate', Timestamp.fromDate(thisMondayNormalised))
          .whereLessThan('scheduledDate', Timestamp.fromDate(thisMondayNormalised.add(Duration(days: 7))))
          .fetch();
      user.newScheduleMessageShown = true;
      await FS.update.one(user);
      setState(() {
        showNewScheduleMessage = true;
        newWorkoutsCount = thisWeekWorkouts.items.length;
      });
    }
  }
//message for informing user they have anew workout plan
  void showNewScheduleDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
                child:  Icon(Icons.calendar_view_week, color: Colors.blue, size: 20),
              ),
               SizedBox(width: 12),
               Text('New Weekly Schedule!',style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold)
              ),
            ]),
          content: Text(
            'Your new weekly schedule has been generated with $newWorkoutsCount workout${newWorkoutsCount > 1 ? 's' : ''} for this week.\n\n'
                'Check your calendar to see the scheduled workouts.',
            style:  TextStyle(fontSize: 16, height: 1.5)),
          actions: [
            TextButton(
              onPressed: (){
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue,
              ), child: Text('Got it!'),
            )]);
      },
    );
  }
  @override
  void initState(){
    super.initState();
    selectedDay = focusedDay;

    kEvents = LinkedHashMap<DateTime,List<WorkoutEvent>>(
      equals: isSameDay,
      hashCode: (date) => normaliseDate(date).hashCode,
    );
    selectedEvents = ValueNotifier([]);
    loadSchedule();
    loadSuggestions();
    showSuggestions = false;
  }
  //calendar functions
  LinkedHashMap<DateTime, List<WorkoutEvent>> buildWorkoutEventMap(List<ScheduledWorkout> workouts){
    final map = LinkedHashMap<DateTime,List<WorkoutEvent>>(
        equals: isSameDay,
        hashCode: (date) => normaliseDate(date).hashCode
    );
    for (final sw in workouts){
      final day = normaliseDate(sw.scheduledDate.toDate());
      map.putIfAbsent(day, () => []).add(
        WorkoutEvent('Loading...', sw),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_){
      addWorkoutNameToEvent(map);
    });
    return map;
  }

  Future<void> addWorkoutNameToEvent(LinkedHashMap<DateTime, List<WorkoutEvent>> map) async {
    bool updated = false;
    for (final events in map.values){
      for(final event in events){
        final workout = await FS.get.one<Workout>(event.scheduledWorkout.workoutId);
        if(workout != null){
          event.title = workout.name;
          event.workoutName  = workout.name;
          updated = true;
        }
      }
    }
    if (updated && mounted) {
      setState(() {
        //refresh UI
        final normalisedSelectedDay = selectedDay != null ?
        normaliseDate(selectedDay!) :
        normaliseDate(DateTime.now());
        selectedEvents.value = kEvents[normalisedSelectedDay] ?? [];
      });
    }
  }
  //fetch weekly schedule of logged in user
  Future<void> loadSchedule() async{
    final currentUser = authService.getCurrentUser();
    if(currentUser == null) return;

    final result = await FS.list.filter<ScheduledWorkout>(ScheduledWorkout)
                              .whereEqualTo('userId', currentUser.uid)
                              .fetch();
    final tempMap = buildWorkoutEventMap(result.items);

    if (mounted) {
      setState(() {
        userSchedule = result.items;
        kEvents.clear();
        kEvents.addAll(tempMap);

        final normalisedSelectedDay = selectedDay != null ?
        normaliseDate(selectedDay!) :
        normaliseDate(DateTime.now());
        selectedEvents.value = kEvents[normalisedSelectedDay] ?? [];
      });
    }
    if(mounted) {
      await checkForNewScheduleMessage();
    }
  }

  List<WorkoutEvent> getEventsForDay(DateTime day){
    return kEvents[normaliseDate(day)] ?? [];
  }

  void onDaySelected(DateTime day,DateTime focused){
    final normalised = normaliseDate(day);
    setState(() {
      selectedDay = normalised;
      focusedDay = focused;
      selectedEvents.value = getEventsForDay(normalised);
    });
  }
//fetch current user
  Future<User?> loadCurrentUser() async {
    final currentUser = authService.getCurrentUser();
    if(currentUser == null) return null;
    return await FS.get.one<User>(currentUser.uid);
  }
//view details of tapped workout
  Future<void> viewWorkout(WorkoutEvent event) async {
    final sw = event.scheduledWorkout;
    final workout = await FS.get.one<Workout>(sw.workoutId);
    if (workout == null) return;
    //if completed go to feedback screen
    if (sw.isCompleted) {
      final exerciseResult = await FS.list
          .filter<WorkoutExercises>(WorkoutExercises)
          .whereEqualTo('workoutId', workout.id)
          .fetch();

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkoutFeedbackScreen(
            workout: workout,
            exercises: exerciseResult.items,
          ),
        ),
      );
    } else {
      //if not completed yet, view the workout exercises in view workout screen
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ViewWorkoutScreen(workout: workout),
        ),
      );
    }    
    if(mounted) {
      loadSchedule();
    }
  }
  //function to check for past incomplete workouts so the calendar can display them as incomplete
  bool isFromPastWeek(DateTime workoutDate) {
    final now = DateTime.now();
    final currentWeekMonday = now.subtract(Duration(days: now.weekday - 1));
    final currentWeekStart = normaliseDate(currentWeekMonday);

    return workoutDate.isBefore(currentWeekStart);
  }
//fetch ai suggestion for current week
  Future<void> loadSuggestions() async {
    final currentUser = authService.getCurrentUser();
    if (currentUser == null) return;

    setState(() => isLoadingSuggestions = true);

  
    final now = DateTime.now();
    //get this week's monday
    final thisMonday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final normalizedMonday = DateTime(thisMonday.year, thisMonday.month, thisMonday.day);

    //get pending suggestion
    final allPending = await FS.list.filter<WorkoutSuggestions>(WorkoutSuggestions)
        .whereEqualTo('userId', currentUser.uid)
        .whereEqualTo('status', 'pending')
        .fetch();

    //get suggestions that match for this week
    final matchingSuggestions = allPending.items.where((s) {
      final suggestionDate = s.forWeekStart.toDate();
      return suggestionDate.year == normalizedMonday.year &&
          suggestionDate.month == normalizedMonday.month &&
          suggestionDate.day == normalizedMonday.day;
    }).toList();

    if (mounted) {
      setState(() {
        pendingSuggestions = matchingSuggestions;
        isLoadingSuggestions = false;
        showSuggestions = pendingSuggestions.isNotEmpty;
      });
    }
    
  }
//widget for displaying the ai suggestion
  Widget buildSuggestionsSection() {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3),width: 2),
        borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(decoration: BoxDecoration(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [             
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.05),
                  border: Border(
                    bottom: BorderSide( color: Colors.grey,width: 0.5)),
                ),
                child: Row(
                  children: [
                    Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12)),
                        child: Icon(
                            Icons.auto_awesome,
                            color: Theme.of(context).primaryColor,
                            size: 20)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('AI COACH SUGGESTION',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1.2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (pendingSuggestions.isNotEmpty)
                      Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          margin: EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              borderRadius: BorderRadius.circular(12)),
                          child: Text('${pendingSuggestions.length}',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                          )),
                    IconButton(
                      icon: Icon(
                        showSuggestions ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey.shade600,size: 20),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                      onPressed: () {
                        setState(() {
                          showSuggestions = !showSuggestions;
                        });
                      },
                    )],
                )
              ),
              if (showSuggestions)
                if (isLoadingSuggestions)
                  Container(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (pendingSuggestions.isEmpty)
                  Container(
                    padding: EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(16)
                          ),
                          child: Icon(
                            Icons.auto_awesome,color: Colors.grey, size: 24),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('AI Coach',style: TextStyle(fontWeight: FontWeight.bold,fontSize: 16),
                              ),
                              SizedBox(height: 4),
                              Text( userSchedule.where((w) => w.isCompleted).length >= 3
                                    ? 'Suggestion is generated every start of the week! Check back on Monday!'
                                    : 'Complete more workouts to get personalized AI suggestion!',
                                style: TextStyle(color: Colors.grey[600],fontSize: 13),
                              )]),
                        )],
                    ))
                else
                  Column(children: pendingSuggestions.map((suggestion) =>
                        buildSuggestionCard(suggestion)).toList(),
                  )]),
        )),
    );
  }
//widget for displaying individual suggestion
  Widget buildSuggestionCard(WorkoutSuggestions suggestion) {
    return FutureBuilder<Workout?>(
      future: FS.get.one<Workout>(suggestion.suggestedWorkoutId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox();
        }
        final workout = snapshot.data!;
        final confidencePercent = (suggestion.confidenceScore * 100).round();
        return Container(
          margin: EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200)),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding:  EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                      child: Icon(
                        Icons.fitness_center,
                        color: Theme.of(context).primaryColor,
                        size: 16),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(workout.name,style:  TextStyle(fontWeight: FontWeight.w600,
                              fontSize: 14)),
                          SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.thumb_up,size: 10,color: confidencePercent >= 80
                                    ? Colors.green:confidencePercent >= 60
                                    ? Colors.orange:Colors.grey),
                              SizedBox(width: 2),
                              Text('$confidencePercent% match',style: TextStyle(fontSize: 10,
                                  color: confidencePercent >= 80
                                      ? Colors.green:confidencePercent >= 60
                                      ? Colors.orange:Colors.grey,
                                fontWeight: FontWeight.w500),
                              )]),
                        ]),
                    )],
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => viewSuggestion(suggestion, workout),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                          side: BorderSide(color: Theme.of(context).primaryColor)),
                        child: Text('VIEW DETAILS',style: TextStyle(fontSize: 11,
                            color: Theme.of(context).primaryColor,
                          ))),
                    ),
                  ]),
              ])));
      },
    );
  }
//function called when user taps to see details of an ai suggesiton
  Future<void> viewSuggestion(WorkoutSuggestions suggestion,Workout workout) async {
    final result = await Navigator.push(context,MaterialPageRoute(
        builder: (_) => SuggestionPreviewScreen(suggestion: suggestion,suggestedWorkout: workout,
          onAccepted: () {
            loadSuggestions();
            loadSchedule();
          },
          onDeclined: () {
            loadSuggestions();
          },
        )));
  }

  @override
  Widget build(BuildContext context){
    if (showNewScheduleMessage) {
      setState(() {
        showNewScheduleMessage = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showNewScheduleDialog();
        }
      });

    }
    return Scaffold(
      appBar: AppBar(title:  Text('Home'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
              children: [
                buildSuggestionsSection(),
                SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_month,
                      color: Theme.of(context).colorScheme.primary,
                      size: 22),
                     SizedBox(width: 6),
                    Flexible(child:Text(
                      'Workout Calendar',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )),
                  ],
                ),
          TableCalendar<WorkoutEvent>(
            focusedDay: focusedDay,
            firstDay: DateTime.now().subtract(const Duration(days: 30)),
            lastDay: DateTime.now().add(const Duration(days: 90)),
            selectedDayPredicate: (day) => isSameDay(selectedDay, day),
            calendarFormat: calendarFormat,
            eventLoader: getEventsForDay,
            onDaySelected: onDaySelected,
            onFormatChanged: (format) => setState(() => calendarFormat = format),

            rowHeight: 48,
            daysOfWeekHeight: 32,

            headerStyle: HeaderStyle(
              titleCentered: true,
              formatButtonVisible: false,
              titleTextStyle: Theme.of(context).textTheme.titleMedium!,
              leftChevronIcon: Icon(
                Icons.chevron_left,
                color: Theme.of(context).colorScheme.primary,
              ),
              rightChevronIcon: Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),

            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
              weekendStyle: TextStyle(
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w600,
              ),
            ),

            calendarStyle: CalendarStyle(
              isTodayHighlighted: true,

              cellMargin: const EdgeInsets.all(6),
              cellPadding: const EdgeInsets.all(0),

              defaultDecoration: BoxDecoration(
                shape: BoxShape.circle,
              ),

              weekendDecoration: BoxDecoration(
                shape: BoxShape.circle,
              ),

              todayDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),

              selectedDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),

              selectedTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),

              todayTextStyle: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),

              defaultTextStyle: const TextStyle(
                fontWeight: FontWeight.w500,
              ),

              weekendTextStyle: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                final workoutEvents = events.cast<WorkoutEvent>();
                if (workoutEvents.isEmpty) return null;

                final color = Theme.of(context).colorScheme.secondary;

                return Positioned(
                  bottom: 6,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      workoutEvents.length > 3 ? 3 : workoutEvents.length,
                          (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ))),
                );
              },
            ),
          ),
            SizedBox(height: 8),
            Container(
              height: MediaQuery.of(context).size.height * 0.35, //take 35 percent of screen
              child: ValueListenableBuilder<List<WorkoutEvent>>(
                valueListenable: selectedEvents,
                builder: (context,value,_){
                  return ListView.builder(
                    itemCount: value.length,
                    itemBuilder: (context, index) {
                      final event = value[index];
                      final sw = event.scheduledWorkout;
                      final scheduledDate = normaliseDate(sw.scheduledDate.toDate());
                      final today = normaliseDate(DateTime.now());
                      final bool isPastWeek = isFromPastWeek(scheduledDate);

                      String statusText;
                      IconData statusIcon;
                      Color statusColor;

                      if (sw.isCompleted) {
                        statusText = 'Completed';
                        statusIcon = Icons.check_circle;
                        statusColor = Colors.green;
                      } else if (sw.isInProgress == true) {
                        statusText = 'In Progress';
                        statusIcon = Icons.fitness_center;
                        statusColor = Colors.orange;
                      } else if (scheduledDate.isAfter(today) || isPastWeek) { //workouts of passed week which are incomplete appear as 'missed'
                        statusText = isPastWeek ? 'Missed' : 'Locked'; //workouts of current week which are in the future appear as 'locked'.
                        statusIcon = Icons.lock;
                        statusColor = Colors.grey;
                      } else {
                        statusText = 'Ready to go';
                        statusIcon = Icons.play_circle_filled;
                        statusColor = Colors.blue;
                      }
                      return GestureDetector(
                        onTap: () => viewWorkout(event),
                        child: Container(
                          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            leading: Icon(
                              statusIcon,
                              color: statusColor,
                              size: 32,
                            ),
                            title: Text(
                              event.title,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  statusText,
                                  style: TextStyle(color: statusColor),
                                ),
                                Text(
                                  'Scheduled for: ${sw.scheduledDate.toDate().day}/${sw.scheduledDate.toDate().month}',
                                ),
                                if (sw.isCompleted && sw.completedDate != null)
                                  Text(
                                    'Completed on: ${sw.completedDate?.toDate().day}/${sw.completedDate?.toDate().month} '
                                        'at ${sw.completedDate?.toDate().hour.toString().padLeft(2, '0')}:${sw.completedDate?.toDate().minute.toString().padLeft(2, '0')}',
                                  ),
                                ],
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
              ],
      )),
      drawer: AppDrawer(scaffoldContext: context,onWorkoutUpdated: loadSchedule,userSchedule: userSchedule,loadSchedule: loadSchedule, currentRoute: '/home',)
  );
}

}



