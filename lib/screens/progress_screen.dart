import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/progress_log.dart';
import '../models/exercise.dart';
import '../models/programs.dart';
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
  List<Program> programs = [];
  Map<int, Program> programMap = {};

  List<_WeightLog> weightLogs = [];

  DateTime currentMonth =
  DateTime(DateTime.now().year, DateTime.now().month);

  DateTime? selectedDay;
  List<ProgressLog> selectedDayLogs = [];

  // ================= PHOTOS =================
  List<ProgressPhoto> photos = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    loadData();
    loadLocalPhotos();
  }

  // ================= DATA =================
  Future<void> loadData() async {
    setState(() => isLoading = true);

    final programLogs = await ProgressService.getUserProgress(1);
    final exerciseList = await ExerciseService.getAllExercises();

    final programData = await Supabase.instance.client
        .from('fitness_programs')
        .select();

    final loadedPrograms =
    programData.map<Program>((p) => Program.fromMap(p)).toList();

    programMap = {for (final p in loadedPrograms) p.id: p};

    final user = Supabase.instance.client.auth.currentUser;
    List<_WeightLog> weights = [];

    if (user != null) {
      final data = await Supabase.instance.client
          .from('weight_logs')
          .select()
          .eq('user_id', user.id)
          .order('logged_at');

      weights = data
          .map<_WeightLog>((e) => _WeightLog(
        date: DateTime.parse(e['logged_at']),
        weight: (e['weight_kg'] as num).toDouble(),
      ))
          .toList();
    }

    setState(() {
      logs = programLogs;
      exercises = exerciseList;
      programs = loadedPrograms;
      weightLogs = weights;
      isLoading = false;
    });
  }

  // ================= HELPERS =================
  bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year &&
        day.month == now.month &&
        day.day == now.day;
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

    final dir = await _photoDir();
    final file =
    File('${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await File(picked.path).copy(file.path);

    photos.add(ProgressPhoto(file: file, date: DateTime.now()));
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

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text(
          'Weight Progress',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
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
        _monthHeader(),
        const SizedBox(height: 12),
        _exerciseCalendar(),
        const SizedBox(height: 20),
        if (selectedDay != null) _selectedDayDetails(),
      ]),
    );
  }

  Widget _monthHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${_monthName(currentMonth.month)} ${currentMonth.year}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Row(children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() {
              currentMonth =
                  DateTime(currentMonth.year, currentMonth.month - 1);
              selectedDay = null;
            }),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() {
              currentMonth =
                  DateTime(currentMonth.year, currentMonth.month + 1);
              selectedDay = null;
            }),
          ),
        ])
      ],
    );
  }

  Widget _exerciseCalendar() {
    final daysInMonth =
    DateUtils.getDaysInMonth(currentMonth.year, currentMonth.month);

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: List.generate(daysInMonth, (i) {
        final day =
        DateTime(currentMonth.year, currentMonth.month, i + 1);

        final dayLogs = logs.where((l) =>
        l.date.year == day.year &&
            l.date.month == day.month &&
            l.date.day == day.day);

        final hasLogs = dayLogs.isNotEmpty;
        final isToday = _isToday(day);

        return GestureDetector(
          onTap: hasLogs
              ? () {
            setState(() {
              selectedDay = day;
              selectedDayLogs = dayLogs.toList();
            });
          }
              : null,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hasLogs ? Colors.deepPurple : Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
              border: isToday
                  ? Border.all(color: Colors.deepPurple, width: 2)
                  : null,
            ),
            child: Text(
              '${day.day}',
              style: TextStyle(
                color: hasLogs ? Colors.white : Colors.black54,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _selectedDayDetails() {
    final uniqueSessions = {
      for (var l in selectedDayLogs)
        '${l.programId}-${l.weekNumber}-${l.dayNumber}': l
    }.values.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${selectedDay!.day} ${_monthName(selectedDay!.month)}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...uniqueSessions.map((l) {
          final program = programMap[l.programId];

          return Container(
            height: 120,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: program != null
                  ? DecorationImage(
                image: NetworkImage(program.imageUrl),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.45),
                  BlendMode.darken,
                ),
              )
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      program?.name ?? 'Unknown program',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Week ${l.weekNumber} • Day ${l.dayNumber}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ================= PHOTOS =================
  Widget _photosTab() {
    if (photos.isEmpty) {
      return const Center(
        child: Text(
          'No progress photos yet\nTap the camera below',
          textAlign: TextAlign.center,
        ),
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
