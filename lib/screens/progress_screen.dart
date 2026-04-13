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
    final programLogs = await ProgressService.getUserProgress();
    final exerciseList = await ExerciseService.getAllExercises();
    final programData =
    await Supabase.instance.client.from('fitness_programs').select();
    final loadedPrograms =
    programData.map<Program>((p) => Program.fromMap(p)).toList();
    programMap = {for (final p in loadedPrograms) p.id: p};
    final data = await Supabase.instance.client
        .from('weight_logs')
        .select()
        .eq('user_id', user.id)
        .order('logged_at');
    final weights = data
        .map<_WeightLog>((e) => _WeightLog(
      date: DateTime.parse(e['logged_at']),
      weight: (e['weight_kg'] as num).toDouble(),
    ))
        .toList();
    if (mounted) {
      setState(() {
        logs = programLogs;
        exercises = exerciseList;
        programs = loadedPrograms;
        weightLogs = weights;
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
          const Center(child: Text('Exercise view')),
          _photosTab(),
        ],
      ),
    );
  }

  Widget _overviewTab() {
    if (weightLogs.isEmpty) {
      return const Center(child: Text('No weight data yet'));
    }
    final sorted = [...weightLogs]..sort((a, b) => a.date.compareTo(b.date));
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: sorted
                  .asMap()
                  .entries
                  .map((e) => FlSpot(e.key.toDouble(), e.value.weight))
                  .toList(),
              isCurved: true,
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