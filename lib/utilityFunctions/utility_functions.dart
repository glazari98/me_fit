
import '../models/scheduled_workout.dart';
//calculates start of week  containing the given date
DateTime startOfWeek(DateTime date){
  return DateTime(date.year,date.month,date.day).subtract(Duration(days: date.weekday -1 ));
}
//calculates end of week containing the given date
DateTime endOfWeek(DateTime date){
  return startOfWeek(date).add(const Duration(days: 6));
}
//normalises a datetime object to remove the time component
DateTime normaliseDate(DateTime date) => DateTime(date.year,date.month,date.day);
//formats duration from seconds to seconds/minutes/hours
String formatDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final remainingSeconds = seconds % 60;

  if (minutes == 0) {
    return '${seconds}s';
  }
  if (remainingSeconds == 0) {
    return '${minutes}min';
  }
  return '${minutes}min ${remainingSeconds}s';
}
//calculate pace of user in aerobic exercise according to time for distance covered and distance covered
String calculatePace(double? distanceKm, int? timeSeconds){
  if(distanceKm == null || timeSeconds == null || distanceKm == 0){
    return '--';
  }
  final paceSecondsPerKm = timeSeconds / distanceKm;

  final minutes = paceSecondsPerKm ~/ 60;
  final seconds = (paceSecondsPerKm % 60).round();

  return '$minutes:${seconds.toString().padLeft(2,'0')} min/km';
}
String formatDuration2(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final secs = seconds % 60;
  return '${hours.toString().padLeft(2,'0')}:${minutes.toString().padLeft(2,'0')}:${secs.toString().padLeft(2,'0')}';
}
//Checks if a scheduled workout is in the future
bool isFutureWorkout(ScheduledWorkout sw){
  return normaliseDate(sw.scheduledDate.toDate()).isAfter(normaliseDate(DateTime.now()));
}
//formats a DateTime object to
String formatDate(DateTime date) {
  return "${date.day}/${date.month}/${date.year} "
      "${date.hour.toString().padLeft(2, '0')}:"
      "${date.minute.toString().padLeft(2, '0')}";
}
//validates an email address using a regular expression pattern.
bool isValidEmail(String email) {
  final emailRegex =
  RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  return emailRegex.hasMatch(email);
}