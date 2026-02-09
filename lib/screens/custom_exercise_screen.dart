import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../models/program_exercise_details.dart';
import '../services/exercise_service.dart';

class CustomExerciseScreen extends StatefulWidget {
  const CustomExerciseScreen({super.key});

  @override
  State<CustomExerciseScreen> createState() => _CustomExerciseScreenState();
}

class _CustomExerciseScreenState extends State<CustomExerciseScreen> {
  List<Exercise> _allExercises = [];
  bool _loading = true;

  final Map<String, List<ProgramExerciseDetail>> exercisesByCategory = {
    'warmup': [],
    'main': [],
    'cooldown': [],
  };

  final Map<String, _FormState> formState = {
    'warmup': _FormState(),
    'main': _FormState(),
    'cooldown': _FormState(),
  };

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    final exercises = await ExerciseService.getAllExercises();
    setState(() {
      _allExercises = exercises;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Custom Workout")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildCategory("Warm-up", "warmup"),
            _buildCategory("Main", "main"),
            _buildCategory("Cooldown", "cooldown"),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _startWorkout,
              icon: const Icon(Icons.play_arrow),
              label: const Text("Start Workout"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= CATEGORY =================

  Widget _buildCategory(String title, String key) {
    final state = formState[key]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            /// EXERCISE DROPDOWN (FROM DB)
            DropdownButtonFormField<int>(
              value: state.exerciseId,
              hint: const Text("Select exercise"),
              items: _allExercises
                  .map(
                    (e) => DropdownMenuItem(
                  value: e.id,
                  child: Text(e.name),
                ),
              )
                  .toList(),
              onChanged: (v) => setState(() => state.exerciseId = v),
            ),

            const SizedBox(height: 12),

            /// SETS
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Sets"),
              onChanged: (v) =>
              state.sets = int.tryParse(v) ?? 1,
            ),

            const SizedBox(height: 12),

            /// REPS / SECONDS
            Row(
              children: [
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Min"),
                    onChanged: (v) =>
                    state.min = int.tryParse(v) ?? 0,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Max"),
                    onChanged: (v) =>
                    state.max = int.tryParse(v) ?? 0,
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: state.durationType,
                  items: const [
                    DropdownMenuItem(value: 'reps', child: Text("Reps")),
                    DropdownMenuItem(value: 'seconds', child: Text("Sec")),
                  ],
                  onChanged: (v) =>
                      setState(() => state.durationType = v!),
                ),
              ],
            ),

            const SizedBox(height: 12),

            /// ADD BUTTON
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text("Add exercise"),
                onPressed: () => _addExercise(key),
              ),
            ),

            /// ADDED EXERCISES
            ...exercisesByCategory[key]!.map(
                  (e) => ListTile(
                title: Text(
                  _allExercises
                      .firstWhere((x) => x.id == e.exerciseId)
                      .name,
                ),
                subtitle: Text(
                  "${e.sets} × ${e.minQuantity}-${e.maxQuantity} ${e.durationType}",
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () =>
                      setState(() => exercisesByCategory[key]!.remove(e)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= ACTIONS =================

  void _addExercise(String key) {
    final s = formState[key]!;
    if (s.exerciseId == null) return;

    setState(() {
      exercisesByCategory[key]!.add(
        ProgramExerciseDetail(
          id: 0,
          programExerciseId: 0,
          exerciseId: s.exerciseId!,
          sets: s.sets,
          minQuantity: s.min,
          maxQuantity: s.max,
          durationType: s.durationType,
          isSuperset: false,
          hasAlternative: false,
        ),
      );
    });
  }

  void _startWorkout() {
    final total = exercisesByCategory.values
        .fold<int>(0, (sum, list) => sum + list.length);

    if (total == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Add at least one exercise")),
      );
      return;
    }

    debugPrint("Custom workout ready:");
    debugPrint(exercisesByCategory.toString());

    // NEXT:
    // - Convert to ExercisePreviewScreen input
    // - Or persist as temporary program
  }
}

// ================= FORM STATE =================

class _FormState {
  int? exerciseId;
  int sets = 1;
  int min = 0;
  int max = 0;
  String durationType = 'reps';
}
