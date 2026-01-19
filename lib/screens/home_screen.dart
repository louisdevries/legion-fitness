import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Greeting / Motivation
          Container(
            height: 80,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            color: Colors.deepPurple.shade100,
            child: const Center(
              child: Text(
                'Greeting / Motivation goes here',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),

          // Next Workout / Quick Action
          Container(
            height: 120,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            color: Colors.deepPurple.shade200,
            child: const Center(
              child: Text(
                'Next Workout / Quick Actions go here',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),

          // Weekly Summary / Stats
          Container(
            height: 100,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            color: Colors.deepPurple.shade300,
            child: const Center(
              child: Text(
                'Weekly Summary / Stats go here',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),

          // Quick Links / Tips
          Container(
            height: 150,
            padding: const EdgeInsets.all(16),
            color: Colors.deepPurple.shade400,
            child: const Center(
              child: Text(
                'Quick Links / Tips / Challenges go here',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
