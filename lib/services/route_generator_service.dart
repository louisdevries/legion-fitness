import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/generated_route.dart';

class RouteGeneratorService {
  // 🔑 Put your OpenRouteService key here
  static const String _apiKey = 'YOUR_OPENROUTESERVICE_API_KEY';

  /// Generates loop routes starting & ending near the user
  static Future<List<GeneratedRoute>> generateRoutesByDistance({
    required LatLng start,
    required double targetDistanceKm,
  }) async {
    final List<GeneratedRoute> results = [];

    // Different seeds = different route shapes
    final seeds = [1, 2, 3, 4];

    for (int i = 0; i < seeds.length; i++) {
      final points = await _fetchRoundTripRoute(
        start: start,
        distanceMeters: (targetDistanceKm * 1000).toInt(),
        seed: seeds[i],
      );

      if (points.length > 2) {
        results.add(
          GeneratedRoute(
            points: points,
            distanceKm: _calculateDistance(points),
            label: 'Option ${i + 1}',
          ),
        );
      }
    }

    return results;
  }

  /// Calls OpenRouteService round-trip API
  static Future<List<LatLng>> _fetchRoundTripRoute({
    required LatLng start,
    required int distanceMeters,
    required int seed,
  }) async {
    final uri = Uri.parse(
      'https://api.openrouteservice.org/v2/directions/foot-walking/geojson',
    );

    try {
      final response = await http.post(
        uri,
        headers: {
          'Authorization': _apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "coordinates": [
            [start.longitude, start.latitude]
          ],
          "options": {
            "round_trip": {
              "length": distanceMeters,
              "points": 3,
              "seed": seed
            }
          }
        }),
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final coords =
        data['features'][0]['geometry']['coordinates'] as List;

        return coords
            .map<LatLng>((c) => LatLng(c[1], c[0]))
            .toList();
      }
    } catch (e) {
      developer.log('Route generation failed', error: e);
    }

    return [];
  }

  /// Simple distance calculator (meters → km)
  static double _calculateDistance(List<LatLng> points) {
    const distance = Distance();
    double total = 0;

    for (int i = 1; i < points.length; i++) {
      total += distance(points[i - 1], points[i]);
    }

    return total / 1000;
  }
}
