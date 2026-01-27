import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/progress_log.dart';
import '../models/exercise.dart';
import '../services/progress_service.dart';
import '../services/exercise_service.dart'; // You need a service to fetch exercises

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  bool isLoading = true;
  List<ProgressLog> logs = [];
  List<Exercise> exercises = [];
  Exercise? selectedExercise;

  @override
  void initState() {
    super.initState();
    loadProgress();
  }

  Future<void> loadProgress() async {
    setState(() => isLoading = true);
    try {
      // Fetch logs
      final programLogs = await ProgressService.getUserProgress(1);

      // Fetch exercises
      final exerciseList = await ExerciseService.getAllExercises();

      setState(() {
        logs = programLogs;
        exercises = exerciseList;

        if (logs.isNotEmpty && exercises.isNotEmpty) {
          // Pick the first exercise from logs as default
          final firstExerciseId = logs.first.exerciseId;
          selectedExercise =
              exercises.firstWhere((ex) => ex.id == firstExerciseId);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load progress: $e')),
        );
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  /// Aggregate logs per day for selected exercise
  List<_DayProgress> _aggregatePerDay(List<ProgressLog> logs, int exerciseId) {
    final Map<DateTime, double> repsPerDay = {};

    for (final log in logs) {
      if (log.exerciseId != exerciseId) continue;

      final day = DateTime(log.date.year, log.date.month, log.date.day);
      final reps = log.repsCompleted.toDouble();

      // Use max reps per day
      if (!repsPerDay.containsKey(day) || reps > repsPerDay[day]!) {
        repsPerDay[day] = reps;
      }
    }

    final result = repsPerDay.entries
        .map((e) => _DayProgress(date: e.key, value: e.value))
        .toList();

    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (logs.isEmpty || exercises.isEmpty) {
      return const Center(child: Text("No progress or exercises available."));
    }

    final aggregated = selectedExercise != null
        ? _aggregatePerDay(logs, selectedExercise!.id)
        : <_DayProgress>[];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Text(
            "Progress Over Time (Reps)",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Exercise dropdown
          DropdownButton<Exercise>(
            value: selectedExercise,
            items: exercises
                .map((ex) => DropdownMenuItem<Exercise>(
              value: ex,
              child: Text(ex.name),
            ))
                .toList(),
            onChanged: (value) {
              setState(() {
                selectedExercise = value;
              });
            },
          ),

          const SizedBox(height: 24),
          Expanded(
            child: aggregated.isEmpty
                ? const Center(child: Text("No data for this exercise yet."))
                : LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < aggregated.length; i++)
                        FlSpot(i.toDouble(), aggregated[i].value)
                    ],
                    isCurved: true,
                    barWidth: 3,
                    color: Theme.of(context).primaryColor,
                    dotData: FlDotData(show: true),
                  ),
                ],
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= aggregated.length) {
                          return const SizedBox();
                        }
                        final date = aggregated[index].date;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text("${date.day}/${date.month}"),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true),
                  ),
                ),
                gridData: FlGridData(show: true),
                borderData: FlBorderData(show: true),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayProgress {
  final DateTime date;
  final double value;

  _DayProgress({required this.date, required this.value});
}
