import 'dart:collection';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firestorm/fs/fs.dart';
import 'package:flutter/material.dart';
import 'package:me_fit/components/drawer_menu.dart';
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
import '../models/workout.dart';
import 'completed_workouts_screen.dart';

//TODO - Utility functions, should be moved to other classes/files.
DateTime normaliseDate(DateTime date) => DateTime(date.year,date.month,date.day);
bool isFutureWorkout(ScheduledWorkout sw){
  return normaliseDate(sw.scheduledDate.toDate()).isAfter(normaliseDate(DateTime.now()));
}

//TODO - Dangling function, should be moved to a more appropriate place.

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
        // Rebuild the UI
        final normalisedSelectedDay = selectedDay != null ?
        normaliseDate(selectedDay!) :
        normaliseDate(DateTime.now());
        selectedEvents.value = kEvents[normalisedSelectedDay] ?? [];
      });
    }
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


  void onItemTapped(int index){
    if(index == 0){
      Navigator.push(context,MaterialPageRoute(builder: (context) => MyWorkoutsScreen()));
    }
    else if (index == 1){
      Navigator.push(context,MaterialPageRoute(builder: (context) => StartWorkoutScreen()));
    }
  }
  Future<User?> loadCurrentUser() async {
    final currentUser = authService.getCurrentUser();
    if(currentUser == null) return null;
    return await FS.get.one<User>(currentUser.uid);
  }
  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title:  Text('Home'),
        centerTitle: true,
      ),
      body: Column(
              children: [
                SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_month,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24),
                     SizedBox(width: 8),
                    Text(
                      'Workout Calendar',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
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
                    itemBuilder: (context, index) {
                      final event = value[index];
                      final sw = event.scheduledWorkout;
                      final scheduledDate = normaliseDate(sw.scheduledDate.toDate());
                      final today = normaliseDate(DateTime.now());

                      String statusText;
                      IconData statusIcon;
                      Color statusColor;

                      if (sw.isCompleted){
                        statusText = 'Completed';
                        statusIcon = Icons.check_circle;
                        statusColor = Colors.green;
                      }else if(sw.isInProgress == true) {
                        statusText = 'In Progress';
                        statusIcon = Icons.fitness_center;
                        statusColor = Colors.orange;
                      }else if(scheduledDate.isAfter(today)){
                        statusText = 'Locked';
                        statusIcon = Icons.lock;
                        statusColor = Colors.red;
                      }else{
                        statusText = 'Ready to go';
                        statusIcon = Icons.play_circle_filled;
                        statusColor = Colors.blue;
                      }
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12)),
                        child: ListTile(leading: Icon(statusIcon, color: statusColor, size: 32),
                          title: Text( event.title,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(statusText, style: TextStyle(color: statusColor)),
                              Text('Scheduled for: ${sw.scheduledDate.toDate().day}/${sw.scheduledDate.toDate().month}'),
                              if (sw.isCompleted && sw.completedDate != null)
                                Text('Completed on: ${sw.completedDate?.toDate().day}/${sw.completedDate?.toDate().month}'
                                    ' at ${sw.completedDate?.toDate().hour.toString().padLeft(2, '0')}:${sw.completedDate?.toDate().minute.toString().padLeft(2, '0')}'),
                            ],
                          ),

                         )
                      );
                    },
                  );
                }))
        ],
      ),
      drawer: AppDrawer(scaffoldContext: context,onWorkoutUpdated: loadSchedule,userSchedule: userSchedule,loadSchedule: loadSchedule, currentRoute: '/home',)
  );
}

}



