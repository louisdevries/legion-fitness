import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import 'photo_compare_screen.dart';

class ProgressReportScreen extends StatefulWidget {
  final List photos;
  final List weightLogs;

  const ProgressReportScreen({
    super.key,
    required this.photos,
    required this.weightLogs,
  });

  @override
  State<ProgressReportScreen> createState() =>
      _ProgressReportScreenState();
}

class _ProgressReportScreenState
    extends State<ProgressReportScreen> {
  final GlobalKey _shareKey = GlobalKey();

  dynamic selectedCompare;

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No data for report')),
      );
    }

    final sortedPhotos = [...widget.photos]
      ..sort((a, b) => a.date.compareTo(b.date));

    final first = sortedPhotos.first;
    final last = sortedPhotos.last;

    final diff = (first.weight != null && last.weight != null)
        ? last.weight! - first.weight!
        : null;

    Map<String, List> grouped = {};
    for (var p in widget.photos) {
      final key =
          '${p.date.year}-${p.date.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(p);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareReport,
          )
        ],
      ),
      body: RepaintBoundary(
        key: _shareKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              /// 🔥 TRANSFORMATION
              _card(
                color: Colors.deepPurple,
                child: Column(
                  children: [
                    const Text(
                      'Transformation',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _image(first)),
                        const SizedBox(width: 8),
                        Expanded(child: _image(last)),
                      ],
                    ),
                    if (diff != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          '${diff > 0 ? '+' : ''}${diff.toStringAsFixed(1)} kg',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                          ),
                        ),
                      )

                  ],
                ),
              ),

              /// 📅 MONTHLY
              ...grouped.entries.map((entry) {
                final monthPhotos = entry.value
                  ..sort((a, b) => a.date.compareTo(b.date));

                if (monthPhotos.length < 2) {
                  return const SizedBox();
                }

                final start = monthPhotos.first;
                final end = monthPhotos.last;

                final monthDiff =
                (start.weight != null && end.weight != null)
                    ? end.weight! - start.weight!
                    : null;

                return _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _image(start)),
                          const SizedBox(width: 6),
                          Expanded(child: _image(end)),
                        ],
                      ),
                      if (monthDiff != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Change: ${monthDiff > 0 ? '+' : ''}${monthDiff.toStringAsFixed(1)} kg',
                            style:
                            const TextStyle(color: Colors.white70),
                          ),
                        )

                    ],
                  ),
                );
              }),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// 🖼 IMAGE
  Widget _image(dynamic photo) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _handleImageTap(photo),
          child: SizedBox(
            height: 180,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.file(
                    photo.file,
                    fit: BoxFit.cover,
                  ),
                ),
                if (photo.weight != null)
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: _label('${photo.weight} kg'),
                  ),

                Positioned(
                  top: 6,
                  right: 6,
                  child: _label('Tap'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatDate(photo.date),
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  /// 🔁 TAP LOGIC
  void _handleImageTap(dynamic photo) {
    if (selectedCompare == null) {
      setState(() => selectedCompare = photo);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select second photo')),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PhotoCompareScreen(
            before: selectedCompare.file,
            after: photo.file,
          ),
        ),
      );

      selectedCompare = null;
    }
  }

  /// 🧱 CARD
  Widget _card({required Widget child, Color? color}) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color ?? Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  /// 🏷 LABEL
  Widget _label(String text) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      color: Colors.black54,
      child: Text(
        text,
        style:
        const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  /// 📅 DATE
  String _formatDate(DateTime d) {
    return '${d.day}/${d.month}/${d.year}';
  }

  /// 📤 SHARE (UPDATED API)
  Future<void> _shareReport() async {
    try {
      RenderRepaintBoundary boundary =
      _shareKey.currentContext!.findRenderObject()
      as RenderRepaintBoundary;

      ui.Image image =
      await boundary.toImage(pixelRatio: 3.0);

      ByteData? byteData =
      await image.toByteData(format: ui.ImageByteFormat.png);

      final pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await Directory.systemTemp.createTemp();
      final file = File('${tempDir.path}/report.png');

      await file.writeAsBytes(pngBytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'My fitness progress 🚀',
        ),
      );
    } catch (e) {
      debugPrint('Share error: $e');
    }
  }
}