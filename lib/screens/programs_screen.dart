import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/programs.dart';
import '../services/program_service.dart';
import 'week_day_selector_screen.dart';

class ProgramsScreen extends StatelessWidget {
  const ProgramsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Program>>(
      future: fetchPrograms(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final programs = snapshot.data!;
        if (programs.isEmpty) {
          return const Center(child: Text("No programs available"));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: programs.length,
          itemBuilder: (context, index) {
            final program = programs[index];

            return GestureDetector(
              onTap: () async {
                // 1️⃣ Save as active program
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('active_program_id', program.id);
                await prefs.setInt('active_week_number', 1); // start from week 1

                // 2️⃣ Navigate to WeekDaySelectorScreen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        WeekDaySelectorScreen(programId: program.id),
                  ),
                );
              },
              child: Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  alignment: Alignment.bottomLeft,
                  children: [
                    Image.network(
                      program.imageUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 180,
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.image, size: 50),
                      ),
                    ),

                    // Gradient overlay
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),

                    // Program name
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        program.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 4,
                            )
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
