import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapGestureHandler {
  final MapController mapController;
  final BuildContext context;
  
  Offset? lastDrawOffset;

  MapGestureHandler({
    required this.mapController,
    required this.context,
  });

  /// Convert screen coordinates to lat/lng
  /// Uses manual calculation based on map center, zoom, and pixel offset
  LatLng? offsetToLatLng(Offset offset) {
    try {
      final camera = mapController.camera;
      final center = camera.center;
      final zoom = camera.zoom;

      // Get the size of the map widget
      final RenderBox? box = context.findRenderObject() as RenderBox?;
      if (box == null) return null;

      final size = box.size;
      final centerX = size.width / 2;
      final centerY = size.height / 2;

      // Calculate offset from center in pixels
      final dx = offset.dx - centerX;
      final dy = offset.dy - centerY;

      // Calculate meters per pixel at this zoom level and latitude
      // Formula: 156543.03392 * cos(lat) / (2^zoom)
      final metersPerPixel = 156543.03392 * 
          math.cos(center.latitude * math.pi / 180) / 
          math.pow(2, zoom);

      // Convert pixels to meters
      final metersX = dx * metersPerPixel;
      final metersY = -dy * metersPerPixel; // Negative because screen Y increases downward

      // Convert meters to degrees
      // 1 degree latitude ≈ 111,320 meters
      // 1 degree longitude ≈ 111,320 * cos(latitude) meters
      final latOffset = metersY / 111320;
      final lngOffset = metersX / (111320 * math.cos(center.latitude * math.pi / 180));

      return LatLng(
        center.latitude + latOffset,
        center.longitude + lngOffset,
      );
    } catch (e) {
      print('Error converting offset to LatLng: $e');
      return null;
    }
  }

  /// Check if the user has moved enough to add a new point
  bool shouldAddPoint(Offset currentOffset) {
    if (lastDrawOffset == null) return true;
    
    final distance = (currentOffset - lastDrawOffset!).distance;
    return distance > 5; // 5 pixels threshold
  }

  void updateLastOffset(Offset offset) {
    lastDrawOffset = offset;
  }

  void resetOffset() {
    lastDrawOffset = null;
  }
}
