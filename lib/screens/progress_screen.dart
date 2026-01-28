import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/progress_log.dart';
import '../models/exercise.dart';
import '../services/progress_service.dart';
import '../services/exercise_service.dart';

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
  List<_WeightLog> weightLogs = [];
  Set<DateTime> exerciseDates = {};

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    setState(() => isLoading = true);
    try {
      final programLogs = await ProgressService.getUserProgress(1);
      final exerciseList = await ExerciseService.getAllExercises();

      final user = Supabase.instance.client.auth.currentUser;
      List<Map<String, dynamic>> weightData = [];
      if (user != null) {
        weightData = await Supabase.instance.client
            .from('weight_logs')
            .select()
            .eq('user_id', user.id) as List<Map<String, dynamic>>;
      }

      final weights = weightData.map((e) {
        return _WeightLog(
          date: DateTime.parse(e['logged_at']),
          weight: (e['weight_kg'] as num).toDouble(),
        );
      }).toList();

      final dates = programLogs.map((log) {
        return DateTime(log.date.year, log.date.month, log.date.day);
      }).toSet();

      setState(() {
        logs = programLogs;
        exercises = exerciseList;
        weightLogs = weights;
        exerciseDates = dates;

        if (logs.isNotEmpty && exercises.isNotEmpty) {
          selectedExercise =
              exercises.firstWhere((ex) => ex.id == logs.first.exerciseId);
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

  List<_DayProgress> _aggregatePerDay(List<ProgressLog> logs, int exerciseId) {
    final Map<DateTime, double> repsPerDay = {};
    for (final log in logs) {
      if (log.exerciseId != exerciseId) continue;
      final day = DateTime(log.date.year, log.date.month, log.date.day);
      repsPerDay[day] = log.repsCompleted.toDouble();
    }
    final result = repsPerDay.entries
        .map((e) => _DayProgress(date: e.key, value: e.value))
        .toList();
    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  List<_WeightLog> _sortedWeights() {
    final sorted = List<_WeightLog>.from(weightLogs);
    sorted.sort((a, b) => a.date.compareTo(b.date));
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =================== WEIGHT CHART ===================
          const Text("Weight Progress",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          weightLogs.isEmpty
              ? const Text("No weight logs yet.")
              : _stylizedLineChart(
            spots: _sortedWeights()
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value.weight))
                .toList(),
            minY: _sortedWeights()
                .map((e) => e.weight)
                .reduce((a, b) => a < b ? a : b) -
                1,
            maxY: _sortedWeights()
                .map((e) => e.weight)
                .reduce((a, b) => a > b ? a : b) +
                1,
            labels: _sortedWeights()
                .map((e) => "${e.date.day}/${_monthName(e.date.month)}")
                .toList(),
          ),
          const SizedBox(height: 24),

          // =================== EXERCISE CALENDAR ===================
          const Text("Exercise Calendar",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _stylizedExerciseCalendar(),
          const SizedBox(height: 24),

          // =================== EXERCISE PROGRESS ===================
          const Text("Exercise Progress",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          DropdownButton<Exercise>(
            value: selectedExercise,
            items: exercises
                .map(
                  (ex) => DropdownMenuItem<Exercise>(
                value: ex,
                child: Text(ex.name),
              ),
            )
                .toList(),
            onChanged: (value) {
              setState(() => selectedExercise = value);
            },
          ),
          const SizedBox(height: 12),
          if (selectedExercise != null)
            _stylizedLineChart(
              spots: _aggregatePerDay(logs, selectedExercise!.id)
                  .asMap()
                  .entries
                  .map((e) => FlSpot(e.key.toDouble(), e.value.value))
                  .toList(),
              minY: _aggregatePerDay(logs, selectedExercise!.id)
                  .map((e) => e.value)
                  .reduce((a, b) => a < b ? a : b) -
                  1,
              maxY: _aggregatePerDay(logs, selectedExercise!.id)
                  .map((e) => e.value)
                  .reduce((a, b) => a > b ? a : b) +
                  1,
              labels: _aggregatePerDay(logs, selectedExercise!.id)
                  .map((e) => "${e.date.day}/${_monthName(e.date.month)}")
                  .toList(),
            ),
        ],
      ),
    );
  }

  // =================== MODERN LINE CHART ===================
  Widget _stylizedLineChart({
    required List<FlSpot> spots,
    required double minY,
    required double maxY,
    required List<String> labels,
  }) {
    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              gradient: LinearGradient(
                colors: [
                  Colors.purpleAccent,
                  Colors.deepPurpleAccent,
                  Colors.indigoAccent,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(
                      radius: 6,
                      color: Colors.deepPurpleAccent,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    Colors.purpleAccent.withOpacity(0.4),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= labels.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      labels[index],
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: 2,
                getTitlesWidget: (val, meta) => Text(val.toInt().toString()),
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 2,
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) {
                return spots.map((spot) {
                  return LineTooltipItem(
                    spot.y.toStringAsFixed(1),
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList();
              },
              tooltipPadding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              tooltipMargin: 6,
            ),
          ),
        ),
      ),
    );
  }

  // =================== MODERN EXERCISE CALENDAR ===================
  Widget _stylizedExerciseCalendar() {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 29));

    // Count reps per day for heatmap coloring
    final Map<DateTime, int> repsPerDay = {};
    for (final log in logs) {
      final day = DateTime(log.date.year, log.date.month, log.date.day);
      repsPerDay[day] = (repsPerDay[day] ?? 0) + log.repsCompleted;
    }

    // Group days by month for labeling
    final Map<String, List<DateTime>> monthGroups = {};
    for (int i = 0; i < 30; i++) {
      final day = start.add(Duration(days: i));
      final monthKey = "${day.year}-${day.month.toString().padLeft(2, '0')}";
      monthGroups.putIfAbsent(monthKey, () => []).add(day);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: monthGroups.entries.map((entry) {
        final monthLabel = DateTime.parse("${entry.key}-01");
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                "${_monthName(monthLabel.month)} ${monthLabel.year}",
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: entry.value.map((day) {
                final reps = repsPerDay[day] ?? 0;
                final exercised = reps > 0;

                final color = exercised
                    ? Color.lerp(
                    Colors.purple[200], Colors.deepPurpleAccent,
                    (reps / 20).clamp(0, 1))
                    : Colors.grey[200];

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                    border: exercised
                        ? Border.all(
                      color: Colors.deepPurpleAccent,
                      width: 2,
                    )
                        : null,
                    boxShadow: exercised
                        ? [
                      BoxShadow(
                          color: Colors.deepPurpleAccent
                              .withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 3))
                    ]
                        : [],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "${day.day}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: exercised ? Colors.white : Colors.black54,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      }).toList(),
    );
  }

  String _monthName(int month) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return names[month - 1];
  }
}

class _DayProgress {
  final DateTime date;
  final double value;
  _DayProgress({required this.date, required this.value});
}

class _WeightLog {
  final DateTime date;
  final double weight;
  _WeightLog({required this.date, required this.weight});
}
