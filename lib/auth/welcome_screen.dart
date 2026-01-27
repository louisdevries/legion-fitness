import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import '../main.dart'; // ✅ Needed to access MainShell

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  Future<void> _skip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("hasSeenWelcome", true);

    if (!mounted) return; // Check if widget is still in the tree

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Welcome to Legion Fitness",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              child: const Text("Login or Create Account"),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _skip,
              child: const Text("Skip for now"),
            ),
          ],
        ),
      ),
    );
  }
}
