import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/local_workout_service.dart';
import '../services/sync_service.dart';

class ExerciseRunnerService {
  final AudioPlayer tickPlayer = AudioPlayer();
  final AudioPlayer dingPlayer = AudioPlayer();

  // ─────────────────────────────────────────────
  // MEDIA PRELOAD (unchanged)
  // ─────────────────────────────────────────────

  Future<void> precacheMedia(String? url, BuildContext context) async {
    if (url == null || url.isEmpty) return;

    try {
      await precacheImage(
        CachedNetworkImageProvider(url),
        context,
      );
    } catch (_) {
      // ignore cache failures
    }
  }

  // ─────────────────────────────────────────────
  // SOUND (unchanged)
  // ─────────────────────────────────────────────

  Future<void> playTick() async {
    await tickPlayer.play(AssetSource('sounds/tick.wav'));
  }

  Future<void> playDing() async {
    await dingPlayer.play(AssetSource('sounds/ding.wav'));
  }

  // ─────────────────────────────────────────────
  // 🔥 NEW: OFFLINE-FIRST LOGGING
  // ─────────────────────────────────────────────

  Future<void> logSet({
    required Map<String, dynamic> exercise,
    required bool isTimed,
    required int lastSelectedSeconds,
    required int lastSelectedReps,
    double? weightUsedKg,
  }) async {
    // 1. WRITE LOCALLY FIRST (INSTANT, NO NETWORK WAIT)
    await LocalWorkoutService.logSet(
      exercise: exercise,
      isTimed: isTimed,
      reps: lastSelectedReps,
      seconds: lastSelectedSeconds,
      weightUsedKg: weightUsedKg,
    );

    // 2. FIRE AND FORGET SYNC (DO NOT BLOCK UI)
    SyncService.trySync(); // <- important: no await
  }

  // ─────────────────────────────────────────────
  // CLEANUP
  // ─────────────────────────────────────────────

  void dispose() {
    tickPlayer.dispose();
    dingPlayer.dispose();
  }
}