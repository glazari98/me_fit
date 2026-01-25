import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/authentication_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen>{
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;

  final AuthenticationService authService = AuthenticationService();

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
      Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch(e) {
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
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: emailController,
                decoration: const InputDecoration(labelText: 'Email')),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
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
