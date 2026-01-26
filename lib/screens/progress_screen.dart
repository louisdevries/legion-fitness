import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/progress_log.dart';
import '../services/progress_service.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  bool isLoading = true;
  List<ProgressLog> logs = [];

  @override
  void initState() {
    super.initState();
    loadProgress();
  }

  Future<void> loadProgress() async {
    setState(() => isLoading = true);
    try {
      // Fetch all progress for all programs
      // Or you can filter by a specific programId if needed
      final allProgramsLogs = <ProgressLog>[];

      // For demonstration, fetch logs for programId = 1
      // Replace or loop through multiple programs if needed
      final programLogs = await ProgressService.getUserProgress(1);
      allProgramsLogs.addAll(programLogs);

      setState(() => logs = allProgramsLogs);
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (logs.isEmpty) {
      return const Center(child: Text("No progress logged yet."));
    }

    // Sort by date
    logs.sort((a, b) => a.date.compareTo(b.date));

    // Prepare FlSpot data
    final spots = <FlSpot>[];
    for (var i = 0; i < logs.length; i++) {
      final log = logs[i];
      // Use weight if available, otherwise reps
      final y = log.weightUsedKg ?? log.repsCompleted.toDouble();
      spots.add(FlSpot(i.toDouble(), y));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Text(
            "Progress Over Time",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
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
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index < 0 || index >= logs.length) return const SizedBox();
                        final date = logs[index].date;
                        return Text("${date.day}/${date.month}");
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
