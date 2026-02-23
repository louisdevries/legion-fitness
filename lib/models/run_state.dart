import 'package:latlong2/latlong.dart';
import '../models/saved_route.dart';

class RunState {
  final bool isRunning;
  final bool isPaused;
  final bool isDrawing;

  final List<LatLng> routePoints; // Current route being drawn/run
  final List<LatLng> plannedRoute; // Ghost route to follow (saved route)
  final List<LatLng> actualRunPath; // Actual path taken during run
  final List<LatLng> rawDrawnPoints; // Store raw drawn points before smoothing

  final double totalDistanceMeters;
  final int elapsedSeconds;

  final LatLng? currentPosition;
  final List<SavedRoute> savedRoutes;
  final SavedRoute? selectedRoute;

  final bool isCurrentlyDrawing;

  RunState({
    this.isRunning = false,
    this.isPaused = false,
    this.isDrawing = false,
    List<LatLng>? routePoints,
    List<LatLng>? plannedRoute,
    List<LatLng>? actualRunPath,
    List<LatLng>? rawDrawnPoints,
    this.totalDistanceMeters = 0,
    this.elapsedSeconds = 0,
    this.currentPosition,
    List<SavedRoute>? savedRoutes,
    this.selectedRoute,
    this.isCurrentlyDrawing = false,
  })  : routePoints = routePoints ?? [],
        plannedRoute = plannedRoute ?? [],
        actualRunPath = actualRunPath ?? [],
        rawDrawnPoints = rawDrawnPoints ?? [],
        savedRoutes = savedRoutes ?? [];

  RunState copyWith({
    bool? isRunning,
    bool? isPaused,
    bool? isDrawing,
    List<LatLng>? routePoints,
    List<LatLng>? plannedRoute,
    List<LatLng>? actualRunPath,
    List<LatLng>? rawDrawnPoints,
    double? totalDistanceMeters,
    int? elapsedSeconds,
    LatLng? currentPosition,
    List<SavedRoute>? savedRoutes,
    SavedRoute? selectedRoute,
    bool? isCurrentlyDrawing,
    bool clearSelectedRoute = false,
  }) {
    return RunState(
      isRunning: isRunning ?? this.isRunning,
      isPaused: isPaused ?? this.isPaused,
      isDrawing: isDrawing ?? this.isDrawing,
      routePoints: routePoints ?? this.routePoints,
      plannedRoute: plannedRoute ?? this.plannedRoute,
      actualRunPath: actualRunPath ?? this.actualRunPath,
      rawDrawnPoints: rawDrawnPoints ?? this.rawDrawnPoints,
      totalDistanceMeters: totalDistanceMeters ?? this.totalDistanceMeters,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      currentPosition: currentPosition ?? this.currentPosition,
      savedRoutes: savedRoutes ?? this.savedRoutes,
      selectedRoute: clearSelectedRoute ? null : (selectedRoute ?? this.selectedRoute),
      isCurrentlyDrawing: isCurrentlyDrawing ?? this.isCurrentlyDrawing,
    );
  }

  String get formattedTime {
    final m = elapsedSeconds ~/ 60;
    final s = elapsedSeconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  double get distanceKm => totalDistanceMeters / 1000.0;

  double get pace => distanceKm > 0 ? elapsedSeconds / 60 / distanceKm : 0;

  String get formattedPace {
    return pace == 0 ? "--" : "${pace.toStringAsFixed(1)} min/km";
  }
}