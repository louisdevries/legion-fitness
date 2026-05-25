import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../services/local_workout_service.dart';
import '../services/sync_service.dart';
import 'package:legion_fitness/main.dart';

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
    if (AppSettings.muteTimerSounds.value) return;
    await tickPlayer.play(AssetSource('sounds/tick.wav'));
  }

  Future<void> playDing() async {
    if (AppSettings.muteTimerSounds.value) return;
    await dingPlayer.play(AssetSource('sounds/ding.wav'));
  }

  Future<void> logSet({
    required Map<String, dynamic> exercise,
    required bool isTimed,
    required int lastSelectedSeconds,
    required int lastSelectedReps,
    required int setIndex,
    required int repsCompleted,
    double? weightUsedKg,
  }) async {
    await LocalWorkoutService.logSet(
      exercise: exercise,
      isTimed: isTimed,
      reps: lastSelectedReps,
      seconds: lastSelectedSeconds,
      setIndex: setIndex,
      repsCompleted: repsCompleted,
      weightUsedKg: weightUsedKg,
    );
    SyncService.trySync();
  }

  void dispose() {
    tickPlayer.dispose();
    dingPlayer.dispose();
  }
}