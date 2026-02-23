import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class RouteUtils {
  /// Smooth the route using a simple averaging algorithm
  static List<LatLng> smoothRoute(List<LatLng> points) {
    if (points.length < 3) return points;

    List<LatLng> smoothed = [];
    
    // Keep first point
    smoothed.add(points.first);
    
    // Smooth middle points using moving average
    for (int i = 1; i < points.length - 1; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final next = points[i + 1];
      
      // Simple average of surrounding points
      final smoothLat = (prev.latitude + curr.latitude + next.latitude) / 3;
      final smoothLng = (prev.longitude + curr.longitude + next.longitude) / 3;
      
      smoothed.add(LatLng(smoothLat, smoothLng));
    }
    
    // Keep last point
    smoothed.add(points.last);
    
    // Further reduce points if too many (snap to road-like behavior)
    return reducePoints(smoothed);
  }

  /// Reduce number of points while maintaining shape (Douglas-Peucker-inspired)
  static List<LatLng> reducePoints(List<LatLng> points) {
    if (points.length < 10) return points;

    List<LatLng> reduced = [points.first];
    
    // Keep every nth point based on total points, but adapt to curves
    for (int i = 1; i < points.length - 1; i++) {
      final prev = reduced.last;
      final curr = points[i];
      
      // Calculate distance from last kept point
      final dist = Geolocator.distanceBetween(
        prev.latitude,
        prev.longitude,
        curr.latitude,
        curr.longitude,
      );
      
      // Keep point if it's at least 10 meters from last kept point
      if (dist > 10) {
        reduced.add(curr);
      }
    }
    
    reduced.add(points.last);
    
    return reduced;
  }

  /// Calculate total distance of the route
  static double calculateRouteDistance(List<LatLng> points) {
    if (points.length < 2) return 0;

    double distance = 0;
    for (int i = 0; i < points.length - 1; i++) {
      distance += Geolocator.distanceBetween(
        points[i].latitude,
        points[i].longitude,
        points[i + 1].latitude,
        points[i + 1].longitude,
      );
    }
    return distance;
  }
}
