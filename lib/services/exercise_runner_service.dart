import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../services/progress_service.dart';

class ExerciseRunnerService {
  final AudioPlayer tickPlayer = AudioPlayer();
  final AudioPlayer dingPlayer = AudioPlayer();

  Future<void> precacheMedia(String? url, BuildContext context) async {
    if (url == null || url.isEmpty) return;
    try {
      await precacheImage(CachedNetworkImageProvider(url), context);
    } catch (_) {}
  }

  Future<void> playTick() async {
    await tickPlayer.play(AssetSource('sounds/tick.wav'));
  }

  Future<void> playDing() async {
    await dingPlayer.play(AssetSource('sounds/ding.wav'));
  }

  Future<void> logSet({
    required Map<String, dynamic> exercise,
    required bool isTimed,
    required int lastSelectedSeconds,
    required int lastSelectedReps,
    double? weightUsedKg,
  }) async {
    await ProgressService.logExercise(
      programId: exercise['program_id'],
      exerciseId: exercise['exercise_id'],
      weekNumber: exercise['week_number'],
      dayNumber: exercise['day_number'],
      repsCompleted: isTimed ? lastSelectedSeconds : lastSelectedReps,
      weightUsedKg: weightUsedKg,
    );
  }

  void dispose() {
    tickPlayer.dispose();
    dingPlayer.dispose();
  }
}