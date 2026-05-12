import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class GeocodeResult {
  final String displayName;
  final String shortName;
  final LatLng location;

  GeocodeResult({
    required this.displayName,
    required this.shortName,
    required this.location,
  });
}

class GeocodingService {
  static const String _mapboxToken =
      "pk.eyJ1IjoibG91aXNkZXZyaWVzIiwiYSI6ImNtbnlsZ3d1dDAzMXgycXNlcXlyaHJrdmwifQ.bDTfupr74bI5qnK7VCgBHg";

  /// Reverse-geocode a lat/lng into a human-readable place name.
  /// Falls back to a coordinate label if the geocoder returns nothing.
  static Future<GeocodeResult> reverseGeocode(LatLng point) async {
    final params = <String, String>{
      'access_token': _mapboxToken,
      'limit': '1',
      'types': 'address,poi,place,locality,neighborhood',
    };

    final uri = Uri.https(
      'api.mapbox.com',
      '/geocoding/v5/mapbox.places/${point.longitude},${point.latitude}.json',
      params,
    );

    try {
      final resp =
      await http.get(uri).timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final features = (data['features'] as List?) ?? [];
        if (features.isNotEmpty) {
          final f = features.first;
          final placeName = (f['place_name'] ?? f['text'] ?? '').toString();
          final text = (f['text'] ?? placeName).toString();
          if (placeName.isNotEmpty) {
            return GeocodeResult(
              displayName: placeName,
              shortName: text.isNotEmpty ? text : _coordLabel(point),
              location: point,
            );
          }
        }
      } else {
        developer.log('Mapbox reverse HTTP ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      developer.log('Mapbox reverse-geocode error: $e');
    }

    // Fallback: coord-based label so the waypoint still has a usable name.
    final label = _coordLabel(point);
    return GeocodeResult(
      displayName: 'Pinned location ($label)',
      shortName: 'Pin $label',
      location: point,
    );
  }

  /// Reverse-geocode a list of points in parallel. Used to generate a
  /// nice default route name like "9th Ave → Crots St → Park Rd".
  static Future<List<GeocodeResult>> reverseGeocodeBatch(
      List<LatLng> points) async {
    return Future.wait(points.map(reverseGeocode));
  }

  static String _coordLabel(LatLng p) =>
      '${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)}';

  /// Route through an ordered list of lat/lngs.
  ///
  /// Hits FOSSGIS's profile-specific OSRM servers (foot + car in parallel)
  /// and picks the result with lower deviation from the user's straight-line
  /// waypoint chain. This naturally fits both contexts:
  ///   - Suburban grid: car stays on streets while foot detours through
  ///     alleys → car wins (lower deviation).
  ///   - Park/campus: foot follows trails directly while car has to reach
  ///     a road → foot wins.
  static Future<List<LatLng>> routeThroughWaypoints(
      List<LatLng> waypoints) async {
    if (waypoints.length < 2) return waypoints;

    final results = await Future.wait([
      _routeWithProfile('routed-foot', waypoints),
      _routeWithProfile('routed-car', waypoints),
    ]);

    final footRoute = results[0];
    final carRoute = results[1];

    if (footRoute.isEmpty && carRoute.isEmpty) {
      developer.log(
          'Both FOSSGIS profiles failed, falling back to OSRM demo');
      return _fallbackRouteViaOsrmDemo(waypoints);
    }
    if (footRoute.isEmpty) return carRoute;
    if (carRoute.isEmpty) return footRoute;

    final footDev = _routeDeviation(footRoute, waypoints);
    final carDev = _routeDeviation(carRoute, waypoints);

    developer.log(
      'Route deviation — foot: ${footDev.toStringAsFixed(0)}m, '
          'car: ${carDev.toStringAsFixed(0)}m '
          '→ picked ${footDev <= carDev ? "foot" : "car"} '
          '(${footRoute.length} vs ${carRoute.length} pts)',
    );

    return footDev <= carDev ? footRoute : carRoute;
  }

  static Future<List<LatLng>> _routeWithProfile(
      String serverPath,
      List<LatLng> waypoints,
      ) async {
    try {
      final coords =
      waypoints.map((p) => '${p.longitude},${p.latitude}').join(';');

      final uri = Uri.parse(
        'https://routing.openstreetmap.de/$serverPath/route/v1/driving/$coords'
            '?overview=full&geometries=geojson',
      );

      final resp = await http.get(uri).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) {
        developer.log('FOSSGIS $serverPath HTTP ${resp.statusCode}');
        return [];
      }

      final data = jsonDecode(resp.body);
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return [];

      final geometry = routes[0]['geometry']['coordinates'] as List;
      return geometry
          .map<LatLng>((c) => LatLng(
        (c[1] as num).toDouble(),
        (c[0] as num).toDouble(),
      ))
          .toList();
    } catch (e) {
      developer.log('FOSSGIS $serverPath routing error: $e');
      return [];
    }
  }

  static Future<List<LatLng>> _fallbackRouteViaOsrmDemo(
      List<LatLng> waypoints) async {
    try {
      final coords =
      waypoints.map((p) => '${p.longitude},${p.latitude}').join(';');
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$coords'
            '?overview=full&geometries=geojson',
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return [];
      final data = jsonDecode(resp.body);
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return [];
      final geometry = routes[0]['geometry']['coordinates'] as List;
      return geometry
          .map<LatLng>((c) => LatLng(
        (c[1] as num).toDouble(),
        (c[0] as num).toDouble(),
      ))
          .toList();
    } catch (e) {
      developer.log('OSRM fallback error: $e');
      return [];
    }
  }

  static double _routeDeviation(
      List<LatLng> route,
      List<LatLng> waypoints,
      ) {
    if (waypoints.length < 2 || route.isEmpty) return 0;

    double total = 0;
    for (final p in route) {
      double minDist = double.infinity;
      for (int i = 0; i < waypoints.length - 1; i++) {
        final d = _distanceFromSegment(p, waypoints[i], waypoints[i + 1]);
        if (d < minDist) minDist = d;
      }
      total += minDist;
    }
    return total;
  }

  static double _distanceFromSegment(LatLng p, LatLng a, LatLng b) {
    const double metersPerDegLat = 111320.0;
    final metersPerDegLng =
        111320.0 * math.cos(a.latitude * math.pi / 180);

    double toX(LatLng pt) => (pt.longitude - a.longitude) * metersPerDegLng;
    double toY(LatLng pt) => (pt.latitude - a.latitude) * metersPerDegLat;

    final px = toX(p), py = toY(p);
    final bx = toX(b), by = toY(b);
    final dx = bx, dy = by;
    final segLenSq = dx * dx + dy * dy;
    if (segLenSq == 0) {
      return math.sqrt(px * px + py * py);
    }
    double t = (px * dx + py * dy) / segLenSq;
    if (t < 0) t = 0;
    if (t > 1) t = 1;
    final projX = t * dx;
    final projY = t * dy;
    final ddx = px - projX;
    final ddy = py - projY;
    return math.sqrt(ddx * ddx + ddy * ddy);
  }
}