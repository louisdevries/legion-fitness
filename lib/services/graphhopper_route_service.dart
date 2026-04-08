import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/generated_route.dart';

class GraphHopperRouteService {
  /// Generate multiple round-trip routes that follow real roads
  static Future<List<GeneratedRoute>> generateRoundTrip({
    required LatLng start,
    required double targetDistanceKm,
    int maxResults = 3,
  }) async {
    developer.log('📍 Generating routes from: ${start.latitude},${start.longitude}');
    developer.log('🎯 Target distance: ${targetDistanceKm}km');

    return _generateOptimizedWaypointRoutes(start, targetDistanceKm, maxResults);
  }

  static Future<List<GeneratedRoute>> _generateOptimizedWaypointRoutes(
      LatLng start,
      double targetDistanceKm,
      int count,
      ) async {
    final routes = <GeneratedRoute>[];

    for (int i = 0; i < count; i++) {
      try {
        developer.log('🔄 Generating route ${i + 1}...');
        final route = await _generateOptimizedRoute(
          start: start,
          targetDistanceKm: targetDistanceKm,
          variation: i,
        );
        if (route != null) {
          routes.add(route);
          final diff = (route.distanceKm - targetDistanceKm).abs();
          developer.log('✅ Route ${i + 1}: ${route.distanceKm.toStringAsFixed(2)}km (diff: ${diff.toStringAsFixed(2)}km)');
        }
      } catch (e) {
        developer.log('❌ Failed to generate route $i', error: e);
      }
    }

    if (routes.isEmpty) {
      developer.log('⚠️ All routes failed, using fallback');
      return _generateFallbackRoutes(start, targetDistanceKm, count);
    }

    return routes;
  }

  static Future<GeneratedRoute?> _generateOptimizedRoute({
    required LatLng start,
    required double targetDistanceKm,
    required int variation,
  }) async {
    const int numWaypoints = 4; // Using 4 waypoints for better distance control
    const int maxAttempts = 8;
    const double tolerance = 0.4; // 400m tolerance

    // Better initial bounds based on target distance
    // Key insight: waypoint radius should be roughly target_distance / (π * 1.5)
    // This accounts for routing detours
    double minRadius = (targetDistanceKm * 1000) * 0.08; // 8% of target
    double maxRadius = (targetDistanceKm * 1000) * 0.35; // 35% of target
    double currentRadius = (targetDistanceKm * 1000) * 0.18; // Start at 18%

    GeneratedRoute? bestRoute;
    double bestDistanceDiff = double.infinity;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      developer.log('  Attempt ${attempt + 1}: radius ${(currentRadius / 1000).toStringAsFixed(2)}km');

      final waypoints = _generateWaypoints(
        start: start,
        radiusMeters: currentRadius,
        numWaypoints: numWaypoints,
        variation: variation,
      );

      final allPoints = [start, ...waypoints, start];
      final routedPoints = await _routeThroughWaypoints(allPoints);

      if (routedPoints.isEmpty) {
        developer.log('  ⚠️ Routing failed');
        maxRadius = currentRadius * 0.8;
        currentRadius = (minRadius + maxRadius) / 2;
        continue;
      }

      double actualDistance = 0;
      for (int i = 0; i < routedPoints.length - 1; i++) {
        actualDistance += Geolocator.distanceBetween(
          routedPoints[i].latitude,
          routedPoints[i].longitude,
          routedPoints[i + 1].latitude,
          routedPoints[i + 1].longitude,
        );
      }

      final actualDistanceKm = actualDistance / 1000;
      final distanceDiff = (actualDistanceKm - targetDistanceKm).abs();

      developer.log('  → ${actualDistanceKm.toStringAsFixed(2)}km (diff: ${distanceDiff.toStringAsFixed(2)}km)');

      if (distanceDiff < bestDistanceDiff) {
        bestDistanceDiff = distanceDiff;
        final routeNames = ['Scenic Loop', 'Quick Circuit', 'Explorer Route'];
        bestRoute = GeneratedRoute(
          points: routedPoints,
          distanceKm: actualDistanceKm,
          label: routeNames[variation % routeNames.length],
        );
      }

      if (distanceDiff <= tolerance) {
        developer.log('  ✅ Within tolerance!');
        break;
      }

      // Improved binary search logic
      final ratio = actualDistanceKm / targetDistanceKm;

      if (ratio < 0.85) {
        // Much too short, increase aggressively
        minRadius = currentRadius;
        currentRadius = currentRadius * 1.3;
        if (currentRadius > maxRadius) {
          maxRadius = currentRadius;
        }
      } else if (ratio < 0.95) {
        // Slightly short, increase moderately
        minRadius = currentRadius;
        currentRadius = (currentRadius + maxRadius) / 2;
      } else if (ratio > 1.15) {
        // Much too long, decrease aggressively
        maxRadius = currentRadius;
        currentRadius = currentRadius * 0.7;
        if (currentRadius < minRadius) {
          minRadius = currentRadius;
        }
      } else if (ratio > 1.05) {
        // Slightly long, decrease moderately
        maxRadius = currentRadius;
        currentRadius = (minRadius + currentRadius) / 2;
      }

      if ((maxRadius - minRadius) < 20) {
        developer.log('  ℹ️ Converged');
        break;
      }
    }

    return bestRoute;
  }

  static List<LatLng> _generateWaypoints({
    required LatLng start,
    required double radiusMeters,
    required int numWaypoints,
    required int variation,
  }) {
    final waypoints = <LatLng>[];
    final baseAngle = variation * (2 * math.pi / 3);

    for (int i = 0; i < numWaypoints; i++) {
      final angle = baseAngle + (2 * math.pi * i / numWaypoints);

      // Add variety between routes but keep consistent per variation
      final random = math.Random(variation * 100 + i);
      final radiusVariation = radiusMeters * (0.85 + random.nextDouble() * 0.3); // 85-115%

      final latOffset = radiusVariation * math.cos(angle) / 111320;
      final lngOffset = radiusVariation * math.sin(angle) /
          (111320 * math.cos(start.latitude * math.pi / 180));

      waypoints.add(LatLng(
        start.latitude + latOffset,
        start.longitude + lngOffset,
      ));
    }

    return waypoints;
  }

  static Future<List<LatLng>> _routeThroughWaypoints(List<LatLng> waypoints) async {
    if (waypoints.length < 2) return waypoints;

    try {
      final coords = waypoints
          .map((p) => '${p.longitude},${p.latitude}')
          .join(';');

      final uri = Uri.parse(
          'https://router.project-osrm.org/route/v1/foot/$coords?overview=full&geometries=geojson'
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return [];
      }

      final data = jsonDecode(response.body);

      if (data['routes'] == null || data['routes'].isEmpty) {
        return [];
      }

      final route = data['routes'][0];
      final geometry = route['geometry']['coordinates'] as List;

      return geometry
          .map<LatLng>((coord) => LatLng(coord[1], coord[0]))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static List<GeneratedRoute> _generateFallbackRoutes(
      LatLng start,
      double distanceKm,
      int count,
      ) {
    final routes = <GeneratedRoute>[];

    for (int i = 0; i < count; i++) {
      final points = _generateCircle(start, distanceKm, i);

      double actualDistance = 0;
      for (int j = 0; j < points.length - 1; j++) {
        actualDistance += Geolocator.distanceBetween(
          points[j].latitude,
          points[j].longitude,
          points[j + 1].latitude,
          points[j + 1].longitude,
        );
      }

      routes.add(GeneratedRoute(
        points: points,
        distanceKm: actualDistance / 1000,
        label: 'Circle ${i + 1}',
      ));
    }

    return routes;
  }

  static List<LatLng> _generateCircle(LatLng start, double distanceKm, int variation) {
    final List<LatLng> points = [start];
    final baseRadius = distanceKm * 1000 / (2 * math.pi);
    final numPoints = 20;
    final startAngle = variation * (2 * math.pi / 3);

    for (int i = 1; i < numPoints; i++) {
      final angle = startAngle + (2 * math.pi * i / numPoints);
      final latOffset = baseRadius * math.cos(angle) / 111320;
      final lngOffset = baseRadius * math.sin(angle) /
          (111320 * math.cos(start.latitude * math.pi / 180));

      points.add(LatLng(
        start.latitude + latOffset,
        start.longitude + lngOffset,
      ));
    }

    points.add(start);
    return points;
  }
}