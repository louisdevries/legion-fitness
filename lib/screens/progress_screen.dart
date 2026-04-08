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
  bool isLoading = true;

  List<ProgressLog> logs = [];
  List<Exercise> exercises = [];
  List<Program> programs = [];
  Map<int, Program> programMap = {};

  List<_WeightLog> weightLogs = [];
  List<ProgressPhoto> photos = [];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));

    loadData();
    loadLocalPhotos();
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
    final picked = await _picker.pickImage(source: ImageSource.camera);
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

  Future<void> _addOrUpdateWeight() async {
    final controller = TextEditingController();

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log your weight'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Weight (kg)',
            hintText: 'e.g. 75.5',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () {
                final val = double.tryParse(controller.text);
                if (val != null && val >= 30) Navigator.pop(context, val);
              },
              child: const Text('Save')),
        ],
      ),
    );

    if (result == null) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    await Supabase.instance.client.from('weight_logs').insert({
      'user_id': user.id,
      'weight_kg': result,
      'logged_at': DateTime.now().toIso8601String(),
    });

    if (mounted) {
      setState(() {
        weightLogs.add(_WeightLog(date: DateTime.now(), weight: result));
      });
    }
  }

  Future<void> _shareBestTransformation(List<ProgressPhoto> bestPair) async {
    if (bestPair.isEmpty) return;

    final includeLabels = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Include weight labels?'),
        content:
        const Text('Do you want to include weight and date labels on the shared image?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes')),
        ],
      ),
    );

    final messenger = ScaffoldMessenger.of(context);

    try {
      // Load images
      final img1 = await decodeImageFromList(bestPair[0].file.readAsBytesSync());
      final img2 = await decodeImageFromList(bestPair[1].file.readAsBytesSync());

      final width = img1.width + img2.width;
      final height = img1.height > img2.height ? img1.height : img2.height;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      );

      // Draw first image
      canvas.drawImage(img1, Offset.zero, Paint());
      // Draw second image right next to first
      canvas.drawImage(img2, Offset(img1.width.toDouble(), 0), Paint());

      if (includeLabels ?? false) {
        final textPainter = TextPainter(
          textDirection: TextDirection.ltr,
        );

        // First image labels
        textPainter.text = TextSpan(
          text:
          '${bestPair[0].weight?.toStringAsFixed(1) ?? ''}kg\n${bestPair[0].date.day}/${bestPair[0].date.month}/${bestPair[0].date.year}',
          style: const TextStyle(color: Colors.white, fontSize: 24),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(10, 10));

        // Second image labels
        textPainter.text = TextSpan(
          text:
          '${bestPair[1].weight?.toStringAsFixed(1) ?? ''}kg\n${bestPair[1].date.day}/${bestPair[1].date.month}/${bestPair[1].date.year}',
          style: const TextStyle(color: Colors.white, fontSize: 24),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(img1.width + 10, 10));
      }

      final picture = recorder.endRecording();
      final fused = await picture.toImage(width, height);
      final byteData = await fused.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final fusedFile = File('${tempDir.path}/transformation.png');
      await fusedFile.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          text: 'Check out my fitness transformation! 💪',
          files: [XFile(fusedFile.path)],
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed to share: $e')));
    }
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
        body: Center(
          child: Text('Sign up or log in to track your progress'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProgressReportScreen(
                    photos: photos,
                    weightLogs: weightLogs,
                  ),
                ),
              );
            },
          )
        ],
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
          onPressed: addPhoto, child: const Icon(Icons.camera_alt))
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [_overviewTab(), _exerciseTab(), _photosTab()],
      ),
    );
  }

  Widget _overviewTab() {
    if (weightLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No weight data yet'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _addOrUpdateWeight,
              child: const Text('Add Weight'),
            ),
          ],
        ),
      );
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

  Widget _exerciseTab() {
    return const Center(child: Text('Exercise view here'));
  }

  Widget _photosTab() {
    if (photos.isEmpty) {
      return const Center(
        child: Text('No progress photos yet\nTap the camera below'),
      );
    }

    final bestPair = _getBestTransformation();

    return Column(
      children: [
        if (bestPair != null)
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.deepPurple,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text(
                  '🔥 Best Transformation',
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 160,
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PhotoCompareScreen(
                                  before: bestPair[0].file,
                                  after: bestPair[1].file,
                                ),
                              ),
                            );
                          },
                          child:
                          Image.file(bestPair[0].file, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Image.file(bestPair[1].file, fit: BoxFit.cover),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${bestPair[0].weight ?? ''}kg → ${bestPair[1].weight ?? ''}kg',
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.share, color: Colors.white),
                      onPressed: () => _shareBestTransformation(bestPair),
                    ),
                  ],
                ),
              ],
            ),
          ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: photos.length,
            itemBuilder: (_, i) {
              return GestureDetector(
                onTap: () async {
                  final selected = await showModalBottomSheet<int>(
                    context: context,
                    builder: (_) {
                      return GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                        ),
                        itemCount: photos.length,
                        itemBuilder: (_, j) {
                          return GestureDetector(
                            onTap: () => Navigator.pop(context, j),
                            child:
                            Image.file(photos[j].file, fit: BoxFit.cover),
                          );
                        },
                      );
                    },
                  );

                  if (selected == null || selected == i) return;

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PhotoCompareScreen(
                        before: photos[i].file,
                        after: photos[selected].file,
                      ),
                    ),
                  );
                },
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          photos[i].file,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    if (photos[i].weight != null)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          color: Colors.black54,
                          child: Text(
                            '${photos[i].weight}kg',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        color: Colors.black54,
                        child: Text(
                          '${photos[i].date.day}/${photos[i].date.month}/${photos[i].date.year}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () async {
                          photos[i].file.deleteSync();
                          photos.removeAt(i);
                          await _savePhotoMeta();
                          if (mounted) setState(() {});
                        },
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
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