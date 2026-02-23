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
  LatLng? offsetToLatLng(Offset offset) {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;

    final point = mapController.camera.pointToLatLng(
      math.Point(offset.dx, offset.dy),
    );
    return point;
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
