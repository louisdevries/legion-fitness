import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../models/progress_log.dart';
import '../models/exercise.dart';
import '../models/programs.dart';
import '../services/progress_service.dart';
import '../services/exercise_service.dart';
import 'photo_compare_screen.dart';
import 'progress_report_screen.dart';
import 'package:table_calendar/table_calendar.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});
  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ScrollController _scrollController;
  bool isLoading = true;
  List<ProgressLog> logs = [];
  List<Exercise> exercises = [];
  List<Program> programs = [];
  Map<int, Program> programMap = {};
  List<_WeightLog> weightLogs = [];
  List<ProgressPhoto> photos = [];
  final ImagePicker _picker = ImagePicker();
  ProgressPhoto? compareStart;
  List<OutdoorRun> runs = [];
  DateTime selectedDate = DateTime.now();
  Map<String, int> stepsMap = {}; // key: "yyyy-MM-dd"

  // ── Removed scroll-shrink logic; replaced with swipe-to-dismiss ──
  bool _bannerVisible = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _scrollController = ScrollController();
    loadData();
    loadLocalPhotos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    setState(() => isLoading = true);

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => isLoading = false);
      return;
    }

    final programLogs = await ProgressService.getUserCompletions();
    final exerciseList = await ExerciseService.getAllExercises();

    final programData =
    await Supabase.instance.client.from('fitness_programs').select();
    final loadedPrograms =
    programData.map<Program>((p) => Program.fromMap(p)).toList();
    programMap = {for (final p in loadedPrograms) p.id: p};

    final weightData = await Supabase.instance.client
        .from('weight_logs')
        .select()
        .eq('user_id', user.id)
        .order('logged_at');
    final weights = weightData.map<_WeightLog>((e) {
      return _WeightLog(
        date: DateTime.parse(e['logged_at']),
        weight: (e['weight_kg'] as num).toDouble(),
      );
    }).toList();

    final runData = await Supabase.instance.client
        .from('outdoor_runs')
        .select()
        .eq('user_id', user.id);
    final loadedRuns = runData.map<OutdoorRun>((e) => OutdoorRun.fromMap(e)).toList();

    // ✅ Fetch steps
    final stepsData = await Supabase.instance.client
        .from('daily_steps')
        .select()
        .eq('user_id', user.id);
    final loadedSteps = <String, int>{};
    for (final row in stepsData) {
      loadedSteps[row['date'] as String] = (row['steps'] as num).toInt();
    }

    if (mounted) {
      setState(() {
        logs = programLogs;
        exercises = exerciseList;
        programs = loadedPrograms;
        weightLogs = weights;
        runs = loadedRuns;
        stepsMap = loadedSteps;
        isLoading = false;
      });
    }
  }

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
    if (mounted) {
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
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 60,
      maxWidth: 1080,
      maxHeight: 1920,
    );
    if (picked == null) return;
    final user = Supabase.instance.client.auth.currentUser;
    double? latestWeight;
    if (user != null) {
      final data = await Supabase.instance.client
          .from('weight_logs')
          .select()
          .eq('user_id', user.id)
          .order('logged_at', ascending: false)
          .limit(1);
      if (data.isNotEmpty) {
        latestWeight = (data[0]['weight_kg'] as num).toDouble();
      }
    }
    final dir = await _photoDir();
    final file =
    File('${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await File(picked.path).copy(file.path);
    photos.add(ProgressPhoto(
      file: file,
      date: DateTime.now(),
      weight: latestWeight,
    ));
    await _savePhotoMeta();
    if (mounted) setState(() {});
  }

  Future<void> _shareTransformation(List<ProgressPhoto> pair) async {
    final bytes0 = await pair[0].file.readAsBytes();
    final bytes1 = await pair[1].file.readAsBytes();
    final img1 = await decodeImageFromList(bytes0);
    final img2 = await decodeImageFromList(bytes1);

    const maxW = 800.0;
    double scale1 = img1.width > maxW ? maxW / img1.width : 1.0;
    double scale2 = img2.width > maxW ? maxW / img2.width : 1.0;

    final w1 = (img1.width * scale1).round();
    final h1 = (img1.height * scale1).round();
    final w2 = (img2.width * scale2).round();
    final h2 = (img2.height * scale2).round();

    final totalWidth = w1 + w2;
    final totalHeight = h1 > h2 ? h1 : h2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder,
        Rect.fromLTWH(0, 0, totalWidth.toDouble(), totalHeight.toDouble()));

    canvas.save();
    canvas.scale(scale1);
    canvas.drawImage(img1, Offset.zero, Paint());
    canvas.restore();

    canvas.save();
    canvas.translate(w1.toDouble(), 0);
    canvas.scale(scale2);
    canvas.drawImage(img2, Offset.zero, Paint());
    canvas.restore();

    final picture = recorder.endRecording();
    final image = await picture.toImage(totalWidth, totalHeight);
    final byteData =
    await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/transform.png');
    await file.writeAsBytes(pngBytes);

    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)]),
    );
  }

  Future<void> _deletePhoto(ProgressPhoto photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete photo?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
              const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    await photo.file.delete();
    photos.remove(photo);
    await _savePhotoMeta();
    if (mounted) setState(() {});
  }

  void _openFullScreen(ProgressPhoto photo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black),
          body: Center(
            child: InteractiveViewer(
              child: Image.file(photo.file),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Login required')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Weight'),
            Tab(text: 'Photos'),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton(
              onPressed: _showLogWeightDialog,
              child: const Icon(Icons.edit),
            )
          : _tabController.index == 2
              ? FloatingActionButton(
                  onPressed: addPhoto,
                  child: const Icon(Icons.camera_alt),
                )
              : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          _overviewTab(),
          _weightTab(),
          _photosTab(),
        ],
      ),
    );
  }

  Future<void> _showLogWeightDialog() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final controller = TextEditingController();
    if (weightLogs.isNotEmpty) {
      final latest = weightLogs.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
      controller.text = latest.weight.toStringAsFixed(1);
    }

    double? savedValue;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Log Weight',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Weight (kg)',
                border: OutlineInputBorder(),
                suffixText: 'kg',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final value = double.tryParse(controller.text.trim());
                  if (value == null || value <= 0) return;
                  savedValue = value;
                  Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );

    // Do NOT call controller.dispose() here — showModalBottomSheet resolves
    // as soon as Navigator.pop fires, but the dismiss animation keeps the
    // builder alive for several more frames. Disposing here causes a
    // "used after dispose" error during that animation. The controller is
    // a function-local variable and will be GC'd when this scope exits.

    if (savedValue != null) {
      await Supabase.instance.client.from('weight_logs').insert({
        'user_id': user.id,
        'weight_kg': savedValue,
        'logged_at': DateTime.now().toIso8601String(),
      });
      await loadData();
    }
  }

  Widget _overviewTab() {
    if (weightLogs.isEmpty && runs.isEmpty) {
      return const Center(child: Text('No data yet'));
    }

    final sortedWeights = [...weightLogs]
      ..sort((a, b) => a.date.compareTo(b.date));

    return SingleChildScrollView(
      child: Column(
        children: [

          // 📅 Calendar
          TableCalendar(
            focusedDay: selectedDate,
            firstDay: DateTime(2020),
            lastDay: DateTime.now(),
            selectedDayPredicate: (day) =>
                isSameDay(day, selectedDate),
            onDaySelected: (selected, focused) {
              setState(() {
                selectedDate = selected;
              });
            },
          ),

          const SizedBox(height: 12),

          // 📊 Selected Day Data
          _buildDayDetails(),
        ],
      ),
    );
  }

  Widget _weightTab() {
    if (weightLogs.isEmpty) {
      return const Center(child: Text('No weight data yet'));
    }

    final sorted = [...weightLogs]
      ..sort((a, b) => a.date.compareTo(b.date));

    List<FlSpot> spots = sorted.map((w) {
      return FlSpot(
        w.date.millisecondsSinceEpoch.toDouble(),
        w.weight,
      );
    }).toList();

    // Handle single point
    if (spots.length == 1) {
      final single = spots.first;
      spots.add(FlSpot(single.x + 1000, single.y));
    }

    final minX = spots.first.x;
    final maxX = spots.last.x;

    final double range = maxX - minX;
    final double interval = range == 0 ? 1.0 : range / 4.0;

    final latestSpot = spots.last;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          minX: minX,
          maxX: maxX,

          // ✅ Clean grid
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
          ),

          borderData: FlBorderData(show: false),

          // ✅ Axis styling
          titlesData: FlTitlesData(
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),

            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: interval,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  final date =
                  DateTime.fromMillisecondsSinceEpoch(value.toInt());
                  return Text(
                    "${date.day}/${date.month}",
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),

            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 52,
                getTitlesWidget: (value, meta) {
                  final parts = value.toStringAsFixed(1).split('.');
                  return SideTitleWidget(
                    meta: meta,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(parts[0],
                            style: const TextStyle(fontSize: 10)),
                        const Text('.',
                            style: TextStyle(fontSize: 10)),
                        SizedBox(
                          width: 12,
                          child: Text(parts[1],
                              style: const TextStyle(fontSize: 10)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // ✅ Touch tooltip
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final date = DateTime.fromMillisecondsSinceEpoch(
                      spot.x.toInt());
                  return LineTooltipItem(
                    "${spot.y.toStringAsFixed(1)} kg\n${date.day}/${date.month}/${date.year}",
                    const TextStyle(color: Colors.white),
                  );
                }).toList();
              },
            ),
          ),

          // ✅ THE GOOD STUFF (visual upgrade)
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              barWidth: 3,

              // 🔥 Gradient line
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF6C63FF),
                  Color(0xFF00C9A7),
                ],
              ),

              // 🔥 Area fill
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6C63FF).withOpacity(0.3),
                    const Color(0xFF00C9A7).withOpacity(0.05),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),

              // 🔥 Highlight latest point
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) {
                  if (spot.x == latestSpot.x &&
                      spot.y == latestSpot.y) {
                    return FlDotCirclePainter(
                      radius: 5,
                      color: Colors.orange,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    );
                  }
                  return FlDotCirclePainter(
                    radius: 2,
                    color: Colors.white,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photosTab() {
    final sortedPhotos = [...photos]
      ..sort((a, b) => b.date.compareTo(a.date));
    final bestPair = _getBestTransformation();

    return Stack(
      children: [
        CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Swipe-to-dismiss transformation banner ──
            if (bestPair != null && _bannerVisible)
              SliverToBoxAdapter(
                child: Dismissible(
                  key: const ValueKey('transformation_banner'),
                  direction: DismissDirection.up,
                  onDismissed: (_) =>
                      setState(() => _bannerVisible = false),
                  child: _buildBestTransformation(bestPair),
                ),
              ),
            ..._buildGroupedPhotoSlivers(sortedPhotos),
          ],
        ),
        if (compareStart != null)
          Positioned(
            bottom: 80,
            left: 16,
            right: 16,
            child: Material(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.compare, color: Colors.white),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Now tap a second photo to compare',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          setState(() => compareStart = null),
                      child: const Text('Cancel',
                          style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBestTransformation(List<ProgressPhoto> pair) {
    final diff = pair[1].weight != null && pair[0].weight != null
        ? (pair[1].weight! - pair[0].weight!)
        : null;
    final days = pair[1].date.difference(pair[0].date).inDays;

    Widget weightDiffBadge() {
      if (diff == null) return const SizedBox.shrink();
      final lost = diff < 0;
      final label = '${lost ? '▼' : '▲'} ${diff.abs().toStringAsFixed(1)} kg';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: lost
                ? [const Color(0xFF43E97B), const Color(0xFF38F9D7)]
                : [const Color(0xFFFA709A), const Color(0xFFFEE140)],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: (lost ? Colors.greenAccent : Colors.orangeAccent)
                  .withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 17,
            shadows: [Shadow(blurRadius: 4, color: Colors.black38)],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: BoxDecoration(
        color: Colors.deepPurple,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Title row + swipe hint + share ──
          Row(
            children: [
              const Expanded(
                child: Text(
                  '🔥 Best Transformation',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              // Subtle "swipe up to dismiss" hint
              const Text(
                'swipe up to hide',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.share, color: Colors.white),
                onPressed: () => _shareTransformation(pair),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ── Images ──
          SizedBox(
            height: 180,
            child: Row(
              children: [
                // Before
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(pair[0].file, fit: BoxFit.cover),
                      ),
                      if (pair[0].weight != null)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: _label(
                              '${pair[0].weight!.toStringAsFixed(1)} kg'),
                        ),
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: _label(
                            '${pair[0].date.day}/${pair[0].date.month}/${pair[0].date.year}'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // After
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(pair[1].file, fit: BoxFit.cover),
                      ),
                      if (pair[1].weight != null)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: _label(
                              '${pair[1].weight!.toStringAsFixed(1)} kg'),
                        ),
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: _label(
                            '${pair[1].date.day}/${pair[1].date.month}/${pair[1].date.year}'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ── Weight diff badge + days ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              weightDiffBadge(),
              const SizedBox(width: 10),
              Text(
                'in $days days',
                style:
                const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedPhotoSlivers(List<ProgressPhoto> photos) {
    final Map<String, List<ProgressPhoto>> grouped = {};
    for (final p in photos) {
      final key =
          "${p.date.year}-${p.date.month.toString().padLeft(2, '0')}";
      grouped.putIfAbsent(key, () => []).add(p);
    }
    final List<Widget> slivers = [];
    for (final entry in grouped.entries) {
      slivers.add(SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
          child: Text(
            entry.key,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      ));
      slivers.add(SliverGrid(
        delegate: SliverChildBuilderDelegate(
              (_, i) => _buildPhotoTile(entry.value[i]),
          childCount: entry.value.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
      ));
    }
    return slivers;
  }

  Widget _buildPhotoTile(ProgressPhoto photo) {
    final isSelected = compareStart == photo;
    return GestureDetector(
      onTap: () {
        if (compareStart != null) {
          final first = compareStart!;
          setState(() => compareStart = null);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PhotoCompareScreen(
                before: first.file,
                after: photo.file,
              ),
            ),
          );
        } else {
          _openFullScreen(photo);
        }
      },
      onLongPress: () => setState(() => compareStart = photo),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(photo.file, fit: BoxFit.cover),
          if (photo.weight != null)
            Positioned(
              top: 4,
              left: 4,
              child: _label('${photo.weight!.toStringAsFixed(1)} kg'),
            ),
          Positioned(
            bottom: 4,
            left: 4,
            child: _label(
                '${photo.date.day}/${photo.date.month}/${photo.date.year}'),
          ),
          // Delete button
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: () => _deletePhoto(photo),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(3),
                child: const Icon(Icons.close,
                    color: Colors.white, size: 14),
              ),
            ),
          ),
          if (isSelected)
            Positioned.fill(
              child: Container(
                color: Colors.blue.withOpacity(0.4),
                child: const Icon(Icons.compare_arrows,
                    color: Colors.white, size: 32),
              ),
            ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      color: Colors.black54,
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return "$mins:${secs.toString().padLeft(2, '0')}";
  }

  Widget _buildDayDetails() {
    final dateKey =
        "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

    // Steps for this day
    final steps = stepsMap[dateKey];

    // Runs for this day
    final dayRuns = runs.where((r) =>
    r.startedAt.year == selectedDate.year &&
        r.startedAt.month == selectedDate.month &&
        r.startedAt.day == selectedDate.day);

    // Weight for this day
    final dayWeight = weightLogs.firstWhere(
          (w) =>
      w.date.year == selectedDate.year &&
          w.date.month == selectedDate.month &&
          w.date.day == selectedDate.day,
      orElse: () => _WeightLog(date: selectedDate, weight: -1),
    );

    // Program logs for this day — group by program+week+day
    final dayLogs = logs.where((l) =>
    l.date.year == selectedDate.year &&
        l.date.month == selectedDate.month &&
        l.date.day == selectedDate.day);

    // Deduplicate to unique program sessions (same programId+week+day = one session)
    final Map<String, ProgressLog> sessionMap = {};
    for (final l in dayLogs) {
      final key = "${l.programId}_${l.weekNumber}_${l.dayNumber}";
      sessionMap.putIfAbsent(key, () => l);
    }
    final sessions = sessionMap.values.toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date heading
          Text(
            "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          // ✅ Steps card
          if (steps != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF00C9A7)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions_walk, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Steps",
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        steps.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // ✅ Program session cards
          if (sessions.isNotEmpty) ...[
            const Text(
              "Workout",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...sessions.map((session) {
              final program = programMap[session.programId];
              return _buildProgramSessionCard(session, program);
            }),
            const SizedBox(height: 12),
          ],

          // Weight
          if (dayWeight.weight != -1)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                "⚖️  Weight: ${dayWeight.weight.toStringAsFixed(1)} kg",
                style: const TextStyle(fontSize: 14),
              ),
            ),

          // Runs
          if (dayRuns.isEmpty && sessions.isEmpty && steps == null && dayWeight.weight == -1)
            const Text("No data for this day")
          else if (dayRuns.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Runs",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                ...dayRuns.map((run) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.directions_run),
                    title: Text(
                        "${(run.distance / 1000).toStringAsFixed(2)} km"),
                    subtitle: Text(
                        "Time: ${_formatDuration(run.duration)}\n"
                            "Pace: ${run.pace?.toStringAsFixed(2) ?? '--'} min/km"),
                  ),
                )),
              ],
            ),
        ],
      ),
    );
  }

// ✅ New helper — program session card with image background
  Widget _buildProgramSessionCard(ProgressLog session, Program? program) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      height: 110,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.grey[850],
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          if (program != null && program.imageUrl.isNotEmpty)
            Image.network(
              program.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.grey[800]),
            ),

          // Dark overlay so text is readable
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.65),
                  Colors.black.withOpacity(0.35),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  program?.name ?? "Program #${session.programId}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _sessionBadge("Week ${session.weekNumber}"),
                    const SizedBox(width: 8),
                    _sessionBadge("Day ${session.dayNumber}"),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white30),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  List<ProgressPhoto>? _getBestTransformation() {
    if (photos.length < 2) return null;
    double bestScore = 0;
    List<ProgressPhoto>? bestPair;
    for (int i = 0; i < photos.length; i++) {
      for (int j = i + 1; j < photos.length; j++) {
        final a = photos[i];
        final b = photos[j];
        if (a.weight == null || b.weight == null) continue;
        final diff = (b.weight! - a.weight!).abs();
        if (diff > bestScore) {
          bestScore = diff;
          bestPair = [a, b];
        }
      }
    }
    return bestPair;
  }
}

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

class OutdoorRun {
  final DateTime startedAt;
  final DateTime endedAt;
  final int duration;
  final double distance;
  final double? pace;

  OutdoorRun({
    required this.startedAt,
    required this.endedAt,
    required this.duration,
    required this.distance,
    this.pace,
  });

  factory OutdoorRun.fromMap(Map<String, dynamic> e) {
    return OutdoorRun(
      startedAt: DateTime.parse(e['started_at']),
      endedAt: DateTime.parse(e['ended_at']),
      duration: e['duration_seconds'],
      distance: (e['distance_meters'] as num).toDouble(),
      pace: (e['avg_pace_min_per_km'] as num?)?.toDouble(),
    );
  }
}