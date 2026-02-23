import 'package:latlong2/latlong.dart';
import '../models/saved_route.dart';
import '../models/generated_route.dart';

class RunState {
  final bool isRunning;
  final bool isPaused;
  final bool isDrawing;
  final bool isGenerating;

  final List<LatLng> routePoints;
  final List<LatLng> plannedRoute;
  final List<LatLng> actualRunPath;
  final List<LatLng> rawDrawnPoints;

  final double totalDistanceMeters;
  final int elapsedSeconds;

  final LatLng? currentPosition;
  final List<SavedRoute> savedRoutes;
  final SavedRoute? selectedRoute;

  final bool isCurrentlyDrawing;

  // Route generation
  final List<GeneratedRoute> generatedRoutes;
  final GeneratedRoute? selectedGeneratedRoute;

  RunState({
    this.isRunning = false,
    this.isPaused = false,
    this.isDrawing = false,
    this.isGenerating = false,
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
    List<GeneratedRoute>? generatedRoutes,
    this.selectedGeneratedRoute,
  })  : routePoints = routePoints ?? [],
        plannedRoute = plannedRoute ?? [],
        actualRunPath = actualRunPath ?? [],
        rawDrawnPoints = rawDrawnPoints ?? [],
        savedRoutes = savedRoutes ?? [],
        generatedRoutes = generatedRoutes ?? [];

  RunState copyWith({
    bool? isRunning,
    bool? isPaused,
    bool? isDrawing,
    bool? isGenerating,
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
    List<GeneratedRoute>? generatedRoutes,
    GeneratedRoute? selectedGeneratedRoute,
    bool clearGeneratedRoutes = false,
  }) {
    return RunState(
      isRunning: isRunning ?? this.isRunning,
      isPaused: isPaused ?? this.isPaused,
      isDrawing: isDrawing ?? this.isDrawing,
      isGenerating: isGenerating ?? this.isGenerating,
      routePoints: routePoints ?? this.routePoints,
      plannedRoute: plannedRoute ?? this.plannedRoute,
      actualRunPath: actualRunPath ?? this.actualRunPath,
      rawDrawnPoints: rawDrawnPoints ?? this.rawDrawnPoints,
      totalDistanceMeters:
      totalDistanceMeters ?? this.totalDistanceMeters,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      currentPosition: currentPosition ?? this.currentPosition,
      savedRoutes: savedRoutes ?? this.savedRoutes,
      selectedRoute:
      clearSelectedRoute ? null : (selectedRoute ?? this.selectedRoute),
      isCurrentlyDrawing:
      isCurrentlyDrawing ?? this.isCurrentlyDrawing,
      generatedRoutes:
      clearGeneratedRoutes ? [] : (generatedRoutes ?? this.generatedRoutes),
      selectedGeneratedRoute:
      selectedGeneratedRoute ?? this.selectedGeneratedRoute,
    );
  }

  String get formattedTime {
    final m = elapsedSeconds ~/ 60;
    final s = elapsedSeconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  double get distanceKm => totalDistanceMeters / 1000.0;

  double get pace =>
      distanceKm > 0 ? elapsedSeconds / 60 / distanceKm : 0;

  String get formattedPace {
    return pace == 0 ? "--" : "${pace.toStringAsFixed(1)} min/km";
  }
}
