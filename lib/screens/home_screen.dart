import 'dart:collection';
import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/models/WorkoutEvent.dart';
import 'package:me_fit/models/scheduled_workout.dart';
import 'package:me_fit/screens/achievements_screen.dart';
import 'package:me_fit/screens/my_workouts.dart';
import 'package:me_fit/screens/profile_screen.dart';
import 'package:me_fit/screens/start_workout_screen.dart';
import 'package:me_fit/screens/weekly_workouts_screen.dart';
import 'package:me_fit/services/authentication_service.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/user.dart';
import 'completed_workouts_screen.dart';

//TODO - Utility functions, should be moved to other classes/files.
DateTime normaliseDate(DateTime date) => DateTime(date.year,date.month,date.day);
bool isFutureWorkout(ScheduledWorkout sw){
  return normaliseDate(sw.scheduledDate).isAfter(normaliseDate(DateTime.now()));
}

//TODO - Dangling function, should be moved to a more appropriate place.
LinkedHashMap<DateTime, List<WorkoutEvent>> buildWorkoutEventMap(List<ScheduledWorkout> workouts){
  final map = LinkedHashMap<DateTime,List<WorkoutEvent>>(
    equals: isSameDay,
    hashCode: (date) => normaliseDate(date).hashCode
  );

  for (final sw in workouts){
    final day = normaliseDate(sw.scheduledDate);
    map.putIfAbsent(day, () => []).add(
      WorkoutEvent('Workout: ${sw.workoutId}', sw),
    );
  }
  return map;
}

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
  }

  Future<void> loadSchedule() async{
    final currentUser = authService.getCurrentUser();
    if(currentUser == null) return;

    final result = await FS.list.filter<ScheduledWorkout>(ScheduledWorkout)
                              .whereEqualTo('userId', currentUser.uid)
                              .fetch();

    final tempMap = buildWorkoutEventMap(result.items);

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

  void logOut(BuildContext context) async{
    //TODO - Important: Ask the user to confirm log out before logging them out. You can use an AlertDialog.
    authService.logOutUser();
    Navigator.pushReplacementNamed(context, '/login');
  }

  void onItemTapped(int index){
    if(index == 0){
      Navigator.push(context,MaterialPageRoute(builder: (context) => MyWorkoutsScreen()));
    }
    else if (index == 1){
      Navigator.push(context,MaterialPageRoute(builder: (context) => StartWorkoutScreen()));
    }
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: const Text('Home'),
      actions: [
        IconButton(
            onPressed: () => logOut(context),
            icon: const Icon(Icons.logout),)
      ],
      ),
      body: Column(
        children: [
          TableCalendar<WorkoutEvent>(
            focusedDay: focusedDay,
            firstDay: DateTime.now().subtract(const Duration(days: 30)),
            lastDay: DateTime.now().add(const Duration(days: 90)),
            selectedDayPredicate: (day) => isSameDay(selectedDay, day),
            calendarFormat: calendarFormat,
            eventLoader: getEventsForDay,
            onDaySelected: onDaySelected,
            onFormatChanged: (format) => setState(() => calendarFormat = format),

            rowHeight: 52,
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
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
            const SizedBox(height: 8),
            Expanded(
              child: ValueListenableBuilder<List<WorkoutEvent>>(
                valueListenable: selectedEvents,
                builder: (context,value,_){
                  if(value.isEmpty) return const Center(child: Text('No workouts'));
                  return ListView.builder(
                  itemCount: value.length,
                  itemBuilder: (context,index){
                    final workout = value[index];
                    return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12,vertical: 4),
                    decoration: BoxDecoration(
                    border: Border.all(),
                    borderRadius: BorderRadius.circular(12),

                    ),
                    child: ListTile(
                    title: Text(workout.title),
                    onTap: (){},
                    ),
                    );
                  },
                  );
                },
              ),
            ),
        ],
      ),
      //TODO - Ideally the drawer is a reusable widget that can be used across multiple screens.
      //TODO You can create a separate widget for the drawer and use it in all the screens that require it.
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.green.shade900,
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text('MeFit',
                style: TextStyle(color: Colors.white,fontSize: 24,fontWeight: FontWeight.bold)),
              )),
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('My Workouts'),
              onTap: (){
                Navigator.pop(context);
                Navigator.push(context,MaterialPageRoute(builder: (_) => MyWorkoutsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_view_week),
              title: const Text('Weekly Workouts'),
              onTap: () async{
                Navigator.pop(context);
                await Navigator.push(context,MaterialPageRoute(builder: (_) => WeeklyWorkoutsScreen(onWorkoutUpdated: (){ loadSchedule();})));
              },
            ),
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('Start Workout'),
              onTap: (){
                Navigator.pop(context);
                Navigator.push(context,MaterialPageRoute(builder: (_) => StartWorkoutScreen()))
                .then((_){
                  loadSchedule();
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.done),
              title: const Text('Completed Workouts'),
              onTap: (){
                Navigator.pop(context);
                Navigator.push(context,MaterialPageRoute(builder: (_) => CompletedWorkoutsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: (){
                Navigator.pop(context);
                Navigator.push(context,MaterialPageRoute(builder: (_) => ProfileScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.badge),
              title: const Text('Achievements'),
              onTap: () async {
                Navigator.pop(context);
                final currentUser = authService.getCurrentUser();
                User? user = await FS.get.one<User>(currentUser!.uid);
                if(user != null){
                  Navigator.push(context,MaterialPageRoute(builder: (_) => AchievementsScreen(user: user,workouts: userSchedule)));
                }else{
                  null;
                }

              },
            ),

          ],
        )
      ),
  );
}
}



