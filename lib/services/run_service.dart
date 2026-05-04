import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';

class RunService {
  static final _client = Supabase.instance.client;

  static Future<void> saveRun({
    required String userId,
    required DateTime startedAt,
    required DateTime endedAt,
    required int durationSeconds,
    required double distanceMeters,
    required double? avgPace,
    required List<LatLng> route,
    int? routeId, // 🆕 optional saved-route this run was attempting
  }) async {
    final routeJson = route
        .map((p) => {
      'lat': p.latitude,
      'lng': p.longitude,
    })
        .toList();

    final response = await _client.from('outdoor_runs').insert({
      'user_id': userId,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt.toIso8601String(),
      'duration_seconds': durationSeconds,
      'distance_meters': distanceMeters,
      'avg_pace_min_per_km': avgPace,
      'route': routeJson,
      if (routeId != null) 'route_id': routeId,
    });

    return response;
  }
}