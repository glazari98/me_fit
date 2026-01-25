import 'package:firebase_auth/firebase_auth.dart';

class AuthenticationService {
  final FirebaseAuth authentication = FirebaseAuth.instance;

  Future<UserCredential> registerUser ({
    required String email,
    required String password,
}) async {
    return await authentication.createUserWithEmailAndPassword(
        email: email,
        password: password,
    );
  }

  Future<UserCredential> logInUser({
    required String email,
    required String password,
}) async {
    return await authentication.signInWithEmailAndPassword(
        email: email,
        password: password,
    );
  }

  Future<void> logOutUser() async {
    await authentication.signOut();
  }

  User? getCurrentUser() {
    return authentication.currentUser;
  }
}