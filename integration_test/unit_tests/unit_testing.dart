import 'package:flutter_test/flutter_test.dart';
import 'package:me_fit/utilityFunctions/utility_functions.dart';


void main() {
  //unit test for checking if invalid email formats are caught as wrong
  group('Email Validation Test', () {
    test('isValidEmail returns false for invalid email address', () {
      const email = 'invalid-email.com';
      final result = isValidEmail(email);
      expect(result, false);
    });
    test('isValidEmail returns false for invalid email address', () {
      const email = 'uclanTest@email.com';
      final result = isValidEmail(email);
      expect(result, true);
    });
  });

  /*unit test for checking if the normaliseDate function used when a user sets a workout to a date if the datetime is
  * set to midnight so the workout is accessible through the whole day
  */
  group('Date Normalisation Test', () {
    test('normaliseDate converts DateTime to midnight', () {
      final inputDate = DateTime(2026, 3, 20, 2, 30, 45);
      final expectedDate = DateTime(2026, 3, 20, 0, 0, 0);
      final result = normaliseDate(inputDate);
      expect(result, expectedDate);
    });
  });
//unit tests for checking calculation of pace of user for an aerobic exercise
  group('Pace Calculation Test', () {
    test('calculatePace returns correct pace for valid distance and time', () {
      const distance = 10.0;
      const timeSeconds = 3600; // 25 minutes
      final result = calculatePace(distance, timeSeconds);
      expect(result, '6:00 min/km');
    });
    test('calculatePace returns correct pace for valid distance and time', () {
      const distance = 5.0;
      const timeSeconds = 1650; // 25 minutes
      final result = calculatePace(distance, timeSeconds);
      expect(result, '5:30 min/km');
    });
  });

//unit tests for checking correct display of workout duration from seconds to hours:minutes:seconds
  group('Workout Duration Formatting Test', () {
    test('formatDuration2 formats 125 seconds as "02:05"', () {
      const seconds = 3200;
      final result = formatDuration2(seconds);
      expect(result, '00:53:20');
    });
    test('formatDuration2 formats 5235 seconds as "01:27:15"', () {
      const seconds = 3200;
      final result = formatDuration2(seconds);
      expect(result, '01:27:15');
    });
  });



}