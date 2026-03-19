import 'package:integration_test/integration_test.dart';
import 'create_workout_test.dart' as create_workout;
import 'edit_workout_test.dart' as edit_workout;
import 'profile_test.dart' as view_edit_profile;
import 'ai_suggestion_test.dart' as ai_suggestion;
import 'achievements_test.dart' as achievements_test;

/*if you are going to use the command -flutter test integration_test/app_test.dart -v
please uncomment just one of the tests each time
otherwise run them like this flutter test integration_test/achievements_test.dart*/
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // create_workout.main();
  // edit_workout.main();
  //view_edit_profile.main();
  //ai_suggestion.main();
  //achievements_test.main();
}