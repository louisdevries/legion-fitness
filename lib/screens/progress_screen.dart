import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
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

class _ProgressScreenState extends State<ProgressScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool isLoading = true;

  List<ProgressLog> logs = [];
  List<Exercise> exercises = [];
  Exercise? selectedExercise;

  List<_WeightLog> weightLogs = [];

  // ================= PHOTOS =================
  List<ProgressPhoto> photos = [];

  final ImagePicker _picker = ImagePicker();

  DateTime currentMonth =
  DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(() => setState(() {}));
    loadData();
    loadLocalPhotos();
  }

  // ================= DATA =================
  Future<void> loadData() async {
    setState(() => isLoading = true);

    final programLogs = await ProgressService.getUserProgress(1);
    final exerciseList = await ExerciseService.getAllExercises();

    final user = Supabase.instance.client.auth.currentUser;
    List<_WeightLog> weights = [];

    if (user != null) {
      final data = await Supabase.instance.client
          .from('weight_logs')
          .select()
          .eq('user_id', user.id)
          .order('logged_at');

      weights = data.map<_WeightLog>((e) {
        return _WeightLog(
          date: DateTime.parse(e['logged_at']),
          weight: (e['weight_kg'] as num).toDouble(),
        );
      }).toList();
    }

    setState(() {
      logs = programLogs;
      exercises = exerciseList;
      weightLogs = weights;
      if (exercises.isNotEmpty) selectedExercise = exercises.first;
      isLoading = false;
    });
  }

  // ================= PHOTO STORAGE =================
  Future<Directory> _photoDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final d = Directory('${dir.path}/progress_photos');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  Future<void> loadLocalPhotos() async {
    final dir = await _photoDir();
    final metaFile = File('${dir.path}/meta.json');
    if (!metaFile.existsSync()) return;

    final data = jsonDecode(await metaFile.readAsString()) as List;
    setState(() {
      photos = data
          .map((e) => ProgressPhoto(
        file: File(e['path']),
        date: DateTime.parse(e['date']),
        weight: e['weight']?.toDouble(),
      ))
          .toList();
    });
  }

  Future<void> _savePhotoMeta() async {
    final dir = await _photoDir();
    final metaFile = File('${dir.path}/meta.json');

    await metaFile.writeAsString(jsonEncode(
      photos
          .map((p) => {
        'path': p.file.path,
        'date': p.date.toIso8601String(),
        'weight': p.weight,
      })
          .toList(),
    ));
  }

  Future<void> addPhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.camera);
    if (picked == null) return;

    double? weight;

    await showDialog(
      context: context,
      builder: (_) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Add weight (optional)'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(suffixText: 'kg'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  weight = double.tryParse(controller.text);
                }
                Navigator.pop(context);
              },
              child: const Text('Save'),
            )
          ],
        );
      },
    );

    final dir = await _photoDir();
    final file =
    File('${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await File(picked.path).copy(file.path);

    photos.add(
      ProgressPhoto(
        file: file,
        date: DateTime.now(),
        weight: weight,
      ),
    );

    await _savePhotoMeta();
    setState(() {});
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Exercises'),
            Tab(text: 'Photos'),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 2
          ? FloatingActionButton(
        onPressed: addPhoto,
        child: const Icon(Icons.camera_alt),
      )
          : null,
      floatingActionButtonLocation:
      FloatingActionButtonLocation.centerFloat,
      body: TabBarView(
        controller: _tabController,
        children: [
          _overviewTab(),
          _exerciseTab(),
          _photosTab(),
        ],
      ),
    );
  }

  // ================= OVERVIEW =================
  Widget _overviewTab() {
    if (weightLogs.isEmpty) {
      return const Center(child: Text('No weight data yet'));
    }

    final sorted = [...weightLogs]..sort((a, b) => a.date.compareTo(b.date));

    final min = sorted.map((e) => e.weight).reduce((a, b) => a < b ? a : b);
    final max = sorted.map((e) => e.weight).reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text(
          'Weight Progress',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
            'Min: ${min.toStringAsFixed(1)} kg • Max: ${max.toStringAsFixed(1)} kg'),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: sorted
                      .asMap()
                      .entries
                      .map((e) =>
                      FlSpot(e.key.toDouble(), e.value.weight))
                      .toList(),
                  isCurved: true,
                  barWidth: 4,
                  dotData: FlDotData(show: true),
                )
              ],
            ),
          ),
        ),
      ]),
    );
  }

  // ================= EXERCISES =================
  Widget _exerciseTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_monthName(currentMonth.month)} ${currentMonth.year}',
              style:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Row(children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() {
                  currentMonth = DateTime(
                      currentMonth.year, currentMonth.month - 1);
                }),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() {
                  currentMonth = DateTime(
                      currentMonth.year, currentMonth.month + 1);
                }),
              ),
            ])
          ],
        ),
        const SizedBox(height: 12),
        _exerciseCalendar(),
      ]),
    );
  }

  Widget _exerciseCalendar() {
    final daysInMonth =
    DateUtils.getDaysInMonth(currentMonth.year, currentMonth.month);

    final monthLogs = logs.where((l) =>
    l.date.year == currentMonth.year &&
        l.date.month == currentMonth.month);

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: List.generate(daysInMonth, (i) {
        final day =
        DateTime(currentMonth.year, currentMonth.month, i + 1);

        final dayLogs = monthLogs.where((l) =>
        l.date.year == day.year &&
            l.date.month == day.month &&
            l.date.day == day.day);

        final active = dayLogs.isNotEmpty;
        final isToday = DateUtils.isSameDay(day, DateTime.now());

        return GestureDetector(
          onTap:
          active ? () => _showWorkoutDetails(day, dayLogs.toList()) : null,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? Colors.deepPurple : Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
              border: isToday
                  ? Border.all(color: Colors.deepPurple, width: 2)
                  : null,
            ),
            child: Text(
              '${day.day}',
              style: TextStyle(
                  color: active ? Colors.white : Colors.black54,
                  fontWeight: FontWeight.bold),
            ),
          ),
        );
      }),
    );
  }

  void _showWorkoutDetails(DateTime day, List<ProgressLog> dayLogs) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${day.day} ${_monthName(day.month)}',
                style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...dayLogs.map((l) => ListTile(
                leading: const Icon(Icons.fitness_center),
                title: Text('Program ID: ${l.programId}'),
                subtitle:
                Text('Week ${l.weekNumber} • Day ${l.dayNumber}'),
              )),
            ]),
      ),
    );
  }

  String _monthName(int m) => const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ][m - 1];

  // ================= PHOTOS =================
  Widget _photosTab() {
    if (photos.isEmpty) {
      return const Center(
        child: Text('No progress photos yet\nTap the camera below',
            textAlign: TextAlign.center),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate:
      const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: photos.length,
      itemBuilder: (_, i) {
        return Image.file(photos[i].file, fit: BoxFit.cover);
      },
    );
  }
}

// ================= MODELS =================
class ProgressPhoto {
  final File file;
  final DateTime date;
  final double? weight;

  ProgressPhoto({required this.file, required this.date, this.weight});
}

class _WeightLog {
  final DateTime date;
  final double weight;
  _WeightLog({required this.date, required this.weight});
}
