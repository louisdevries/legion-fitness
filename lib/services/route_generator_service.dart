import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/generated_route.dart';

class RouteGeneratorService {
  static const String _apiKey = 'a573c871-b965-4480-b307-d68a8cfe10fd';

  /// Generate multiple round-trip routes near a start location
  static Future<List<GeneratedRoute>> generateRoutesByDistance({
    required LatLng start,
    required double targetDistanceKm,
    int maxSeeds = 5,  // number of route variations
    int maxResults = 3, // return top N closest routes
  }) async {
    final List<GeneratedRoute> candidates = [];

    // Snap start point to road network
    final LatLng? snappedStart = await _snapToRoad(start);
    if (snappedStart == null) {
      developer.log('❌ Could not snap start point to road');
      return [];
    }
    developer.log('📍 Snapped start: $snappedStart');

    // Generate multiple routes using different seeds
    for (int seed = 1; seed <= maxSeeds; seed++) {
      final routes = await _fetchGraphHopperRoundTrip(
        start: snappedStart,
        distanceKm: targetDistanceKm,
        seed: seed,
      );
      candidates.addAll(routes);
    }

    // Remove duplicate routes (compare coordinates)
    final uniqueRoutes = <String, GeneratedRoute>{};
    for (var r in candidates) {
      final key = r.points.map((p) => '${p.latitude},${p.longitude}').join(';');
      uniqueRoutes[key] = r;
    }

    // Sort routes by closest distance to target
    final sortedRoutes = uniqueRoutes.values.toList()
      ..sort((a, b) =>
          (a.distanceKm - targetDistanceKm).abs()
              .compareTo((b.distanceKm - targetDistanceKm).abs()));

    final topRoutes = sortedRoutes.take(maxResults).toList();
    developer.log('✅ GH generated ${topRoutes.length} closest routes');

    return topRoutes;
  }

  /// Snap a point to the nearest road using GraphHopper
  static Future<LatLng?> _snapToRoad(LatLng point) async {
    try {
      final uri = Uri.parse(
        'https://graphhopper.com/api/1/snap?'
            'point=${point.latitude},${point.longitude}&'
            'key=$_apiKey',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        developer.log('❌ Snap API HTTP ${response.statusCode}', error: response.body);
        return null;
      }

      final data = jsonDecode(response.body);
      if (data['snapped_point'] != null) {
        final coords = data['snapped_point']['coordinates'];
        return LatLng(coords[1], coords[0]);
      }

      return null;
    } catch (e) {
      developer.log('❌ Snap API failed', error: e);
      return null;
    }
  }

  /// Fetch a single round-trip route from GraphHopper
  static Future<List<GeneratedRoute>> _fetchGraphHopperRoundTrip({
    required LatLng start,
    required double distanceKm,
    int seed = 1,
  }) async {
    final List<GeneratedRoute> results = [];

    try {
      // Make sure distance is in meters
      final int distanceMeters = (distanceKm * 1000).toInt();

      final uri = Uri.parse(
        'https://graphhopper.com/api/1/route?'
            'point=${start.latitude},${start.longitude}&'
            'vehicle=foot&'
            'locale=en&'
            'points_encoded=false&'
            'round_trip=true&'
            'round_trip.distance=$distanceMeters&'
            'round_trip.seed=$seed&'
            'instructions=false&'
            'key=$_apiKey',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        developer.log('❌ GH HTTP ${response.statusCode}', error: response.body);
        return [];
      }

      final data = jsonDecode(response.body);
      if (data['paths'] == null || data['paths'].isEmpty) return [];

      final path = data['paths'][0];
      final coords = (path['points']['coordinates'] as List)
          .map<LatLng>((c) => LatLng(c[1], c[0]))
          .toList();

      final distanceKmActual = (path['distance'] as num) / 1000;

      results.add(GeneratedRoute(
        points: coords,
        distanceKm: distanceKmActual.toDouble(),
        label: 'Option $seed',
      ));
    } catch (e) {
      developer.log('❌ GH round-trip failed', error: e);
    }

    return results;
  }
}