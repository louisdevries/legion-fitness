import 'package:latlong2/latlong.dart';
import 'dart:convert';

class SavedRoute {
  final int? id;
  final String userId;
  final String name;
  final List<LatLng> points;
  final double distanceKm;

  SavedRoute({
    this.id,
    required this.userId,
    required this.name,
    required this.points,
    required this.distanceKm,
  });

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'name': name,
      'points': jsonEncode(points.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList()),
      'distance_km': distanceKm,
    };
  }

  factory SavedRoute.fromMap(Map<String, dynamic> map) {
    final List<dynamic> pointsList = jsonDecode(map['points'] as String);
    return SavedRoute(
      id: map['id'] as int?,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      points: pointsList.map((p) => LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble())).toList(),
      distanceKm: (map['distance_km'] as num).toDouble(),
    );
  }
}