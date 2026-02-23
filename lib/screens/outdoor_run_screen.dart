import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Use existing models and services
import '../models/saved_route.dart';
import '../services/route_service.dart';

// Use new utility files
import '../services/location_service.dart';
import '../utils/route_utils.dart';
import '../utils/map_gesture_handler.dart';
import '../models/run_state.dart';
import '../main.dart'; // Import AppSettings for loading

class OutdoorRunScreen extends StatefulWidget {
  const OutdoorRunScreen({super.key});

  @override
  State<OutdoorRunScreen> createState() => _OutdoorRunScreenState();
}

class _OutdoorRunScreenState extends State<OutdoorRunScreen> {
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionStream;
  Timer? _timer;
  MapGestureHandler? _gestureHandler;

  late RunState _state;

  @override
  void initState() {
    super.initState();
    _state = RunState();
    _initializeLocation();
    _loadRoutes();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionStream?.cancel();
    LocationService.stopBackgroundMode();
    super.dispose();
  }

  // ==================== INITIALIZATION ====================

  Future<void> _initializeLocation() async {
    final location = await LocationService.getCurrentLocation();
    if (location != null && mounted) {
      setState(() => _state = _state.copyWith(currentPosition: location));
    }
  }

  Future<void> _loadRoutes() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final routes = await RouteService.getRoutes(user.id);
      if (mounted) {
        setState(() => _state = _state.copyWith(savedRoutes: routes));
      }
    }
  }

  // ==================== RUN CONTROLS ====================

  Future<void> _startRun() async {
    await LocationService.startBackgroundMode();

    final plannedRoute = _state.selectedRoute != null
        ? List<LatLng>.from(_state.routePoints)
        : <LatLng>[];

    setState(() {
      _state = _state.copyWith(
        isRunning: true,
        isPaused: false,
        elapsedSeconds: 0,
        totalDistanceMeters: 0,
        actualRunPath: [],
        plannedRoute: plannedRoute,
        routePoints: [],
      );
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_state.isPaused && mounted) {
        setState(() => _state = _state.copyWith(
          elapsedSeconds: _state.elapsedSeconds + 1,
        ));
      }
    });

    _positionStream = LocationService.startTracking(
      onLocationUpdate: _handleLocationUpdate,
    );
  }

  void _handleLocationUpdate(LatLng newPoint) {
    double distance = _state.totalDistanceMeters;

    if (_state.actualRunPath.isNotEmpty) {
      final last = _state.actualRunPath.last;
      distance += Geolocator.distanceBetween(
        last.latitude,
        last.longitude,
        newPoint.latitude,
        newPoint.longitude,
      );
    }

    final updatedPath = List<LatLng>.from(_state.actualRunPath)..add(newPoint);

    if (mounted) {
      setState(() {
        _state = _state.copyWith(
          actualRunPath: updatedPath,
          currentPosition: newPoint,
          totalDistanceMeters: distance,
        );
      });
      _mapController.move(newPoint, _mapController.camera.zoom);
    }
  }

  void _pauseRun() {
    if (mounted) {
      setState(() => _state = _state.copyWith(isPaused: !_state.isPaused));
    }
  }

  void _stopRun() {
    _timer?.cancel();
    _positionStream?.cancel();
    LocationService.stopBackgroundMode();

    if (mounted) {
      setState(() {
        _state = _state.copyWith(
          isRunning: false,
          isPaused: false,
          routePoints: List.from(_state.actualRunPath),
          plannedRoute: [],
        );
      });
    }
  }

  // ==================== DRAWING CONTROLS ====================

  void _toggleDrawing() {
    setState(() {
      _state = _state.copyWith(
        isDrawing: !_state.isDrawing,
        routePoints: _state.isDrawing ? _state.routePoints : [],
        rawDrawnPoints: _state.isDrawing ? _state.rawDrawnPoints : [],
        totalDistanceMeters: _state.isDrawing ? _state.totalDistanceMeters : 0,
        clearSelectedRoute: !_state.isDrawing,
        plannedRoute: [],
      );
    });

    if (_state.isDrawing) {
      _gestureHandler = MapGestureHandler(
        mapController: _mapController,
        context: context,
      );
    }
  }

  void _handlePanStart(DragStartDetails details) {
    if (!_state.isDrawing || _gestureHandler == null) return;

    final point = _gestureHandler!.offsetToLatLng(details.localPosition);
    if (point != null) {
      final updatedPoints = List<LatLng>.from(_state.rawDrawnPoints)..add(point);
      setState(() {
        _state = _state.copyWith(
          isCurrentlyDrawing: true,
          rawDrawnPoints: updatedPoints,
        );
      });
      _gestureHandler!.updateLastOffset(details.localPosition);
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_state.isDrawing || !_state.isCurrentlyDrawing || _gestureHandler == null) return;

    if (_gestureHandler!.shouldAddPoint(details.localPosition)) {
      final point = _gestureHandler!.offsetToLatLng(details.localPosition);
      if (point != null) {
        final updatedRaw = List<LatLng>.from(_state.rawDrawnPoints)..add(point);
        final smoothed = RouteUtils.smoothRoute(updatedRaw);
        final distance = RouteUtils.calculateRouteDistance(smoothed);

        setState(() {
          _state = _state.copyWith(
            rawDrawnPoints: updatedRaw,
            routePoints: smoothed,
            totalDistanceMeters: distance,
          );
        });
        _gestureHandler!.updateLastOffset(details.localPosition);
      }
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!_state.isDrawing || _gestureHandler == null) return;

    _gestureHandler!.resetOffset();

    if (_state.rawDrawnPoints.isNotEmpty) {
      final smoothed = RouteUtils.smoothRoute(_state.rawDrawnPoints);
      final distance = RouteUtils.calculateRouteDistance(smoothed);

      setState(() {
        _state = _state.copyWith(
          isCurrentlyDrawing: false,
          routePoints: smoothed,
          totalDistanceMeters: distance,
        );
      });

      // Automatically snap to roads when user finishes drawing
      _snapToRoads();
    }
  }

  void _clearRoute() {
    setState(() {
      _state = _state.copyWith(
        routePoints: [],
        rawDrawnPoints: [],
        totalDistanceMeters: 0,
      );
    });
  }

  void _cancelDrawing() {
    setState(() {
      _state = _state.copyWith(
        isDrawing: false,
        routePoints: [],
        rawDrawnPoints: [],
        totalDistanceMeters: 0,
        clearSelectedRoute: true,
      );
    });
  }

  Future<void> _snapToRoads() async {
    if (_state.routePoints.isEmpty) return;

    AppSettings.showLoading();

    try {
      final snappedPoints = await RouteService.snapToRoads(_state.routePoints);
      if (snappedPoints.isNotEmpty && mounted) {
        final distance = RouteUtils.calculateRouteDistance(snappedPoints);
        setState(() {
          _state = _state.copyWith(
            routePoints: snappedPoints,
            totalDistanceMeters: distance,
          );
        });
      }
    } catch (e) {
      print('Error snapping to roads: $e');
    } finally {
      AppSettings.hideLoading();
    }
  }

  // ==================== ROUTE MANAGEMENT ====================

  Future<void> _saveRoute() async {
    if (_state.routePoints.isEmpty) {
      _showSnackBar('Draw a route first!');
      return;
    }

    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Save Route"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(hintText: "Route Name"),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Text(
              "Distance: ${_state.distanceKm.toStringAsFixed(2)} km",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: const Text("Save"),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        _showSnackBar('Please log in to save routes');
        return;
      }

      final route = SavedRoute(
        userId: user.id,
        name: name,
        points: _state.routePoints,
        distanceKm: _state.distanceKm,
      );

      try {
        await RouteService.saveRoute(route);
        await _loadRoutes();

        if (mounted) {
          setState(() {
            _state = _state.copyWith(
              isDrawing: false,
              routePoints: [],
              rawDrawnPoints: [],
              totalDistanceMeters: 0,
            );
          });
          _showSnackBar('Route "$name" saved successfully!');
        }
      } catch (e) {
        _showSnackBar('Error saving route: $e');
      }
    }
  }

  void _onRouteSelected(SavedRoute? route) {
    setState(() {
      _state = _state.copyWith(
        selectedRoute: route,
        routePoints: route != null ? List.from(route.points) : [],
        totalDistanceMeters: route != null ? route.distanceKm * 1000 : 0,
      );
    });

    if (route != null && route.points.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(route.points),
            padding: const EdgeInsets.all(70),
          ),
        );
      });
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    if (_state.currentPosition == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_buildInfoBanner() != null) _buildInfoBanner()!,
          Expanded(child: _buildMap()),
          _buildStatsBar(),
          _buildControls(),
        ],
      ),
    );
  }

  PreferredSizeWidget? _buildAppBar() {
    if (_state.isRunning) return null;

    return AppBar(
      title: const Text("Outdoor Run"),
      actions: [
        IconButton(
          icon: Icon(_state.isDrawing ? Icons.check : Icons.edit),
          onPressed: _state.isDrawing ? _saveRoute : _toggleDrawing,
          tooltip: _state.isDrawing ? 'Save Route' : 'Draw Route',
        ),
      ],
    );
  }

  Widget? _buildInfoBanner() {
    if (!_state.isRunning && !_state.isDrawing && _state.savedRoutes.isNotEmpty) {
      return Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: DropdownButton<SavedRoute>(
          isExpanded: true,
          hint: const Text("Select a saved route"),
          value: _state.selectedRoute,
          items: _state.savedRoutes.map((r) => DropdownMenuItem(
            value: r,
            child: Text("${r.name} (${r.distanceKm.toStringAsFixed(2)} km)"),
          )).toList(),
          onChanged: _onRouteSelected,
        ),
      );
    }

    if (_state.isDrawing) {
      return Container(
        padding: const EdgeInsets.all(8),
        color: Colors.green.shade50,
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Draw your route by dragging on the map",
                style: TextStyle(color: Colors.green.shade900),
              ),
            ),
          ],
        ),
      );
    }

    if (_state.isRunning && _state.plannedRoute.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(8),
        color: Colors.blue.shade50,
        child: Row(
          children: [
            const Icon(Icons.route, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Following saved route - ghost path shown in light blue",
                style: TextStyle(color: Colors.blue.shade900, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    return null;
  }

  Widget _buildMap() {
    return GestureDetector(
      onPanStart: _state.isDrawing ? _handlePanStart : null,
      onPanUpdate: _state.isDrawing ? _handlePanUpdate : null,
      onPanEnd: _state.isDrawing ? _handlePanEnd : null,
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _state.currentPosition!,
          initialZoom: 17,
          interactionOptions: InteractionOptions(
            flags: _state.isDrawing ? InteractiveFlag.none : InteractiveFlag.all,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
            userAgentPackageName: 'com.yourapp.app',
          ),
          // Ghost route layer
          if (_state.isRunning && _state.plannedRoute.isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _state.plannedRoute,
                  strokeWidth: 6,
                  color: Colors.lightBlue.withOpacity(0.4),
                  borderStrokeWidth: 2,
                  borderColor: Colors.white.withOpacity(0.6),
                ),
              ],
            ),
          // Actual run path layer
          if (_state.isRunning && _state.actualRunPath.isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _state.actualRunPath,
                  strokeWidth: 4,
                  color: Colors.green,
                ),
              ],
            ),
          // Regular route layer
          if (!_state.isRunning && _state.routePoints.isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _state.routePoints,
                  strokeWidth: 4,
                  color: _state.isDrawing ? Colors.green : Colors.blue,
                ),
              ],
            ),
          _buildMarkers(),
        ],
      ),
    );
  }

  Widget _buildMarkers() {
    final markers = <Marker>[
      // Current position marker
      Marker(
        point: _state.currentPosition!,
        width: 40,
        height: 40,
        child: const Icon(Icons.my_location, color: Colors.red, size: 36),
      ),
    ];

    // Drawing mode markers
    if (_state.routePoints.isNotEmpty && _state.isDrawing) {
      markers.addAll([
        Marker(
          point: _state.routePoints.first,
          width: 30,
          height: 30,
          child: Container(
            decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
          ),
        ),
        Marker(
          point: _state.routePoints.last,
          width: 30,
          height: 30,
          child: Container(
            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            child: const Icon(Icons.stop, color: Colors.white, size: 20),
          ),
        ),
      ]);
    }

    // Running mode ghost route markers
    if (_state.isRunning && _state.plannedRoute.isNotEmpty) {
      markers.addAll([
        Marker(
          point: _state.plannedRoute.first,
          width: 25,
          height: 25,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.lightBlue.withOpacity(0.7),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.flag, color: Colors.white, size: 14),
          ),
        ),
        Marker(
          point: _state.plannedRoute.last,
          width: 25,
          height: 25,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.lightBlue.withOpacity(0.7),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.location_on, color: Colors.white, size: 14),
          ),
        ),
      ]);
    }

    return MarkerLayer(markers: markers);
  }

  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statBox("Time", _state.formattedTime),
          _statBox("Distance", "${_state.distanceKm.toStringAsFixed(2)} km"),
          _statBox("Pace", _state.formattedPace),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildControls() {
    if (!_state.isRunning) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _startRun,
                child: const Text("Start Run"),
              ),
            ),
            if (_state.isDrawing) ...[
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _clearRoute,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text("Clear"),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _cancelDrawing,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                child: const Text("Cancel"),
              ),
            ]
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton(
            onPressed: _pauseRun,
            child: Text(_state.isPaused ? "Resume" : "Pause"),
          ),
          ElevatedButton(
            onPressed: _stopRun,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Stop"),
          ),
        ],
      ),
    );
  }
}
