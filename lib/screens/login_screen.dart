import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/authentication_service.dart';
import '../utilityFunctions/utility_functions.dart';
//Widget where the user can log in into the application
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen>{
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;

  final AuthenticationService authService = AuthenticationService();
//function  checking email and password fields and logging the user in
  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if(email.isEmpty || password.isEmpty){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:Text('Please enter email and password'))
      );
      return;
    }

    try {
      setState(() => isLoading = true);
      await authService.logInUser(
          email: email,
          password: password);

      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You have successfully logged in'),duration: Duration(seconds: 2)),
      );
      Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch(e) { //error messages
      String message = 'Login Failed';
      if(e.code == 'user-not-found'){
        message = 'No user found for that email.';
      }else if (e.code == 'wrong-password'){
        message = 'Incorrect password';
      }else if(e.code == 'invalid-email'){
        message = 'Invalid email address';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch(e){
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }
  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: Text('Login'),centerTitle: true),
      body: Padding(
        padding:  EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              height: 200,
              width: 200,
              margin: EdgeInsets.symmetric(vertical: 20),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/logo.png',
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: Icon(
                        Icons.fitness_center,
                        size: 60,
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
              ),
            ),
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) return 'Email is required';
                if (!isValidEmail(email)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:Text('Please enter a valid email'),duration: Duration(seconds: 2))
                  );
                }
                return null;
              },
            ),

            SizedBox(height: 10,),

            TextFormField(
              controller: passwordController,
              obscureText: obscurePassword,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() => obscurePassword = !obscurePassword);
                  },
                ),
                helperText: 'Minimum 6+ characters',
              ),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (value) {
                final password = value ?? '';
                if (password.isEmpty) return 'Password is required';
                if (password.length <= 6) return 'Password too short';
                return null;
              },
            ),

            const SizedBox(height: 30),
            ElevatedButton(
                onPressed: () => isLoading ? null : login(),
                child: isLoading
              ? const SizedBox(
                  height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Login'),
            ),
            TextButton(
                onPressed: () => Navigator.pushNamed(context, '/signUp'),
                child: const Text("Don't have an account yet? Sign Up"),
            ),
          ],
        ),
      ),
    );
  }
}
