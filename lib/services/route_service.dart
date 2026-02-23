import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/saved_route.dart';

class RouteService {
  static final supabase = Supabase.instance.client;

  static Future<void> saveRoute(SavedRoute route) async {
    await supabase.from('saved_routes').insert(route.toMap());
  }

  static Future<List<SavedRoute>> getRoutes(String userId) async {
    final response = await supabase
        .from('saved_routes')
        .select()
        .eq('user_id', userId);

    return (response as List).map((map) => SavedRoute.fromMap(map)).toList();
  }

  static Future<void> deleteRoute(int id) async {
    await supabase.from('saved_routes').delete().eq('id', id);
  }

  /// Snaps a list of points to the nearest roads using OSRM Match API
  static Future<List<LatLng>> snapToRoads(List<LatLng> points) async {
    if (points.length < 2) return points;

    // OSRM Match API limit is 100 points. Downsample if needed.
    List<LatLng> sampledPoints = points;
    if (points.length > 95) {
      double step = points.length / 90;
      sampledPoints = [];
      for (int i = 0; i < 90; i++) {
        sampledPoints.add(points[(i * step).toInt()]);
      }
      sampledPoints.add(points.last);
    }

    final coordinates = sampledPoints
        .map((p) => '${p.longitude},${p.latitude}')
        .join(';');

    // Use 'foot' profile for better running route matching
    // Use 'radiuses' to give the matcher some flexibility (30 meters)
    final radiuses = List.generate(sampledPoints.length, (_) => '30').join(';');
    
    final url = 'https://router.project-osrm.org/match/v1/foot/$coordinates'
        '?overview=full'
        '&geometries=polyline'
        '&radiuses=$radiuses';

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok' && data['matchings'] != null && data['matchings'].isNotEmpty) {
          // Extract geometry from the best matching
          final geometry = data['matchings'][0]['geometry'];
          final snapped = _decodePolyline(geometry);
          if (snapped.isNotEmpty) return snapped;
        }
      }
    } catch (e) {
      print('OSRM Snapping Error: $e');
    }

    return points; // Return original if snapping failed
  }

  /// Decodes a polyline string into a list of LatLng points (Precision 5)
  static List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }
}
