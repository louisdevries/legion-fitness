import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapGestureHandler {
  final MapController mapController;

  /// A GlobalKey attached to the FlutterMap widget itself.
  /// This is used to find the RenderBox of the *map* — not the whole screen —
  /// so screen→lat/lng conversion uses the correct origin and size.
  final GlobalKey mapKey;

  Offset? lastDrawOffset;

  MapGestureHandler({
    required this.mapController,
    required this.mapKey,
  });

  /// Convert screen coordinates (from a GestureDetector wrapping the map)
  /// to lat/lng using the map's actual size and center.
  LatLng? offsetToLatLng(Offset offset) {
    try {
      final camera = mapController.camera;
      final center = camera.center;
      final zoom = camera.zoom;

      final RenderBox? box =
      mapKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) return null;

      final size = box.size;
      final centerX = size.width / 2;
      final centerY = size.height / 2;

      // Pixel offset from the center of the map widget
      final dx = offset.dx - centerX;
      final dy = offset.dy - centerY;

      // Meters per pixel at this zoom level and latitude
      // Web Mercator approximation: 156543.03392 * cos(lat) / (2^zoom)
      final metersPerPixel = 156543.03392 *
          math.cos(center.latitude * math.pi / 180) /
          math.pow(2, zoom);

      final metersX = dx * metersPerPixel;
      final metersY = -dy * metersPerPixel; // screen Y grows downward

      // Convert meters to degrees
      final latOffset = metersY / 111320;
      final lngOffset =
          metersX / (111320 * math.cos(center.latitude * math.pi / 180));

      return LatLng(
        center.latitude + latOffset,
        center.longitude + lngOffset,
      );
    } catch (e) {
      debugPrint('Error converting offset to LatLng: $e');
      return null;
    }
  }

  /// Only add a new point if the finger has moved at least a few pixels.
  bool shouldAddPoint(Offset currentOffset) {
    if (lastDrawOffset == null) return true;
    final distance = (currentOffset - lastDrawOffset!).distance;
    return distance > 5;
  }

  void updateLastOffset(Offset offset) {
    lastDrawOffset = offset;
  }

  void resetOffset() {
    lastDrawOffset = null;
  }
}