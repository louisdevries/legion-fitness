import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../services/local_workout_service.dart';
import '../services/sync_service.dart';
import 'package:legion_fitness/models/pending_completion.dart';
import 'package:legion_fitness/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ExerciseRunnerService {
  final AudioPlayer tickPlayer = AudioPlayer();
  final AudioPlayer dingPlayer = AudioPlayer();

  Future<void> precacheMedia(String? url, BuildContext context) async {
    if (url == null || url.isEmpty) return;
    try {
      await precacheImage(CachedNetworkImageProvider(url), context);
    } catch (_) {}
  }

  Future<void> queueCompletion({
    required int programId,
    required int weekNumber,
    required int dayNumber,
    required int exerciseId,
    required int setIndex,
    required int repsCompleted,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('completion_queue') ?? [];

    final item = PendingCompletion(
      programId: programId,
      weekNumber: weekNumber,
      dayNumber: dayNumber,
      exerciseId: exerciseId,
      setIndex: setIndex,
      repsCompleted: repsCompleted,
      // unique per set, not per exercise
      localId: '$programId-$weekNumber-$dayNumber-$exerciseId-$setIndex',
    );

    list.add(jsonEncode(item.toJson()));
    await prefs.setStringList('completion_queue', list);
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