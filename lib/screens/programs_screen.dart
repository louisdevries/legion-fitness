import 'package:flutter/material.dart';
import '../models/programs.dart';
import '../services/program_service.dart';
import 'exercise_screen.dart';
import '../models/exercise.dart'; // for mock exercises until you fetch real ones

class ProgramsScreen extends StatelessWidget {
  const ProgramsScreen({super.key});

  // TEMP: mock exercises for each program
  List<Exercise> _getExercisesForProgram(Program program) {
    return mockExercises;
  }

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
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ExercisesScreen(
                      programName: program.name,
                      exercises: _getExercisesForProgram(program),
                    ),
                  ),
                );
              },
              child: Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: Image.network(
                        program.imageUrl,
                        height: 150,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            program.name,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            program.description,
                            style: const TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "${program.weeks} weeks",
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
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
