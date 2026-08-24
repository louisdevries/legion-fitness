import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../models/program_exercise_details.dart';
import '../models/local_custom_program.dart';
import '../services/exercise_service.dart';
import '../services/local_program_service.dart';

class CustomExerciseScreen extends StatefulWidget {
  const CustomExerciseScreen({super.key});

  @override
  State<CustomExerciseScreen> createState() => _CustomExerciseScreenState();
}

class _CustomExerciseScreenState extends State<CustomExerciseScreen> {
  List<Exercise> _allExercises = [];
  bool _loading = true;

  final _nameController = TextEditingController();
  int _weeks = 4;
  int _daysPerWeek = 3;

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

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Program name',
                hintText: 'e.g. Morning Push Day',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit_outlined),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildNumberPicker(
                    label: 'Weeks',
                    value: _weeks,
                    min: 1,
                    max: 16,
                    onChanged: (v) => setState(() => _weeks = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildNumberPicker(
                    label: 'Days / Week',
                    value: _daysPerWeek,
                    min: 1,
                    max: 7,
                    onChanged: (v) => setState(() => _daysPerWeek = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildCategory("Warm-up", "warmup"),
            _buildCategory("Main", "main"),
            _buildCategory("Cooldown", "cooldown"),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saveProgram,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text("Save Program"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _startWorkout,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text("Start Workout"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ================= PICKERS =================

  Widget _buildNumberPicker({
    required String label,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: value > min ? () => onChanged(value - 1) : null,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.remove,
                      size: 18,
                      color: value > min
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline),
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: value < max ? () => onChanged(value + 1) : null,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.add,
                      size: 18,
                      color: value < max
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline),
                ),
              ),
            ],
          ),
        ],
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
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            /// EXERCISE DROPDOWN
            DropdownButtonFormField<int>(
              initialValue: state.exerciseId,
              hint: const Text("Select exercise"),
              isExpanded: true,
              items: _allExercises
                  .map(
                    (e) => DropdownMenuItem(
                  value: e.id,
                  child: Text(
                    e.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
                  .toList(),
              onChanged: (v) => setState(() => state.exerciseId = v),
            ),

            const SizedBox(height: 12),

            /// SETS + UNIT
            Row(
              children: [
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Sets",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => state.sets = int.tryParse(v) ?? 1,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: state.durationType,
                    decoration: const InputDecoration(
                      labelText: "Unit",
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'reps', child: Text("Reps")),
                      DropdownMenuItem(
                          value: 'seconds', child: Text("Seconds")),
                      DropdownMenuItem(
                          value: 'time_max',
                          child: Text("Time (count up)")),
                      DropdownMenuItem(
                          value: 'm', child: Text("Complete only")),
                    ],
                    onChanged: (v) => setState(() => state.durationType = v!),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            /// MIN + MAX
            Row(
              children: [
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Min",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => state.min = int.tryParse(v) ?? 0,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Max",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => state.max = int.tryParse(v) ?? 0,
                  ),
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

  Future<void> _saveProgram() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a program name first")),
      );
      return;
    }
    final total = exercisesByCategory.values
        .fold<int>(0, (sum, list) => sum + list.length);
    if (total == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Add at least one exercise")),
      );
      return;
    }

    List<LocalExerciseEntry> toEntries(String key) {
      return exercisesByCategory[key]!.map((e) {
        final ex = _allExercises.firstWhere((x) => x.id == e.exerciseId);
        return LocalExerciseEntry(
          exerciseId: e.exerciseId,
          exerciseName: ex.name,
          mediaUrl: ex.mediaUrl ?? '',
          coachingCues: ex.coachingCues,
          sets: e.sets,
          minQuantity: e.minQuantity,
          maxQuantity: e.maxQuantity,
          durationType: e.durationType,
        );
      }).toList();
    }

    final program = LocalCustomProgram(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      createdAt: DateTime.now(),
      weeks: _weeks,
      daysPerWeek: _daysPerWeek,
      warmup: toEntries('warmup'),
      main: toEntries('main'),
      cooldown: toEntries('cooldown'),
    );

    await LocalProgramService.save(program);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"$name" saved to My Programs')),
    );
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
