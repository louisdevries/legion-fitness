import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';

// Use existing models and services
import '../models/saved_route.dart';
import '../services/route_service.dart';
import '../services/location_service.dart';
import '../utils/route_utils.dart';
import '../utils/map_gesture_handler.dart';
import '../models/run_state.dart';
import '../main.dart';

const String mapboxToken = "pk.eyJ1IjoibG91aXNkZXZyaWVzIiwiYSI6ImNtbnlsZ3d1dDAzMXgycXNlcXlyaHJrdmwifQ.bDTfupr74bI5qnK7VCgBHg";



class OutdoorRunScreen extends StatefulWidget {
  final Function(bool)? onRunModeChanged;

  const OutdoorRunScreen({super.key, this.onRunModeChanged});

  @override
  State<OutdoorRunScreen> createState() => _OutdoorRunScreenState();
}

class _OutdoorRunScreenState extends State<OutdoorRunScreen> {
  final MapController _mapController = MapController();
  StreamSubscription<LatLng>? _positionStream;
  Timer? _timer;
  MapGestureHandler? _gestureHandler;

  late RunState _state;

  // 🔒 NEW: lock mode
  bool _isLocked = false;

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

  // ==================== LOCK ====================

  void _toggleLock() {
    setState(() {
      _isLocked = !_isLocked;
    });
  }

  // ==================== RUN CONTROLS ====================

  Future<void> _startRun() async {
    await LocationService.startBackgroundMode();

    widget.onRunModeChanged?.call(true); // 🔥 ENTER RUN MODE

    setState(() {
      _state = _state.copyWith(
        isRunning: true,
        isPaused: false,
        elapsedSeconds: 0,
        totalDistanceMeters: 0,
        actualRunPath: [],
        plannedRoute: [],
        routePoints: [],
      );

      _isLocked = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_state.isPaused && mounted) {
        setState(() {
          _state = _state.copyWith(
            elapsedSeconds: _state.elapsedSeconds + 1,
          );
        });
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
    setState(() => _state = _state.copyWith(isPaused: !_state.isPaused));
  }

  void _stopRun() {
    _timer?.cancel();
    _positionStream?.cancel();
    LocationService.stopBackgroundMode();

    widget.onRunModeChanged?.call(false); // 🔥 EXIT RUN MODE

    setState(() {
      _state = _state.copyWith(
        isRunning: false,
        isPaused: false,
        routePoints: List.from(_state.actualRunPath),
        plannedRoute: [],
      );

      _isLocked = false;
    });
  }

  // ==================== DRAWING ====================

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
    if (!_state.isDrawing || _isLocked) return;

    final point = _gestureHandler?.offsetToLatLng(details.localPosition);
    if (point != null) {
      setState(() {
        _state = _state.copyWith(
          isCurrentlyDrawing: true,
          rawDrawnPoints: List.from(_state.rawDrawnPoints)..add(point),
        );
      });
      _gestureHandler?.updateLastOffset(details.localPosition);
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_state.isDrawing || !_state.isCurrentlyDrawing || _isLocked) return;

    if (_gestureHandler!.shouldAddPoint(details.localPosition)) {
      final point = _gestureHandler!.offsetToLatLng(details.localPosition);
      if (point != null) {
        final updated = List<LatLng>.from(_state.rawDrawnPoints)..add(point);
        final smoothed = RouteUtils.smoothRoute(updated);

        setState(() {
          _state = _state.copyWith(
            rawDrawnPoints: updated,
            routePoints: smoothed,
            totalDistanceMeters: RouteUtils.calculateRouteDistance(smoothed),
          );
        });

        _gestureHandler!.updateLastOffset(details.localPosition);
      }
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!_state.isDrawing) return;

    _gestureHandler?.resetOffset();

    final smoothed = RouteUtils.smoothRoute(_state.rawDrawnPoints);

    setState(() {
      _state = _state.copyWith(
        isCurrentlyDrawing: false,
        routePoints: smoothed,
        totalDistanceMeters: RouteUtils.calculateRouteDistance(smoothed),
      );
    });
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    if (_state.currentPosition == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return WillPopScope(
      onWillPop: () async => !_isLocked,
      child: Scaffold(
        appBar: _buildAppBar(),
        body: Stack(
          children: [
            Column(
              children: [
                if (_buildInfoBanner() != null) _buildInfoBanner()!,
                Expanded(child: _buildMap()),
                _buildStatsBar(),
                _buildControls(),
              ],
            ),

            if (_isLocked) _buildLockOverlay(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text("Outdoor Run"),
      actions: [
        IconButton(
          icon: Icon(_isLocked ? Icons.lock : Icons.lock_open),
          onPressed: _toggleLock,
        ),
        if (!_state.isRunning)
          IconButton(
            icon: Icon(_state.isDrawing ? Icons.check : Icons.edit),
            onPressed: _toggleDrawing,
          ),
      ],
    );
  }

  Widget? _buildInfoBanner() {
    if (_isLocked) {
      return Container(
        padding: const EdgeInsets.all(8),
        color: Colors.red.withValues(alpha: 0.15),
        child: const Row(
          children: [
            Icon(Icons.lock, color: Colors.red),
            SizedBox(width: 8),
            Text("Screen Locked - tap lock to unlock"),
          ],
        ),
      );
    }

    return null;
  }

  Widget _buildMap() {
    return GestureDetector(
      onPanStart: (!_isLocked && _state.isDrawing) ? _handlePanStart : null,
      onPanUpdate: (!_isLocked && _state.isDrawing) ? _handlePanUpdate : null,
      onPanEnd: (!_isLocked && _state.isDrawing) ? _handlePanEnd : null,

      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _state.currentPosition!,
          initialZoom: 17,
          interactionOptions: InteractionOptions(
            flags: _isLocked
                ? InteractiveFlag.none
                : InteractiveFlag.all,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate:
            "https://api.mapbox.com/styles/v1/mapbox/outdoors-v12/tiles/{z}/{x}/{y}?access_token=$mapboxToken",
            tileSize: 512,
            zoomOffset: -1,
          ),

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

          if (_state.routePoints.isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _state.routePoints,
                  strokeWidth: 4,
                  color: Colors.blue,
                ),
              ],
            ),

          MarkerLayer(
            markers: [
              Marker(
                point: _state.currentPosition!,
                width: 40,
                height: 40,
                child: const Icon(Icons.my_location, color: Colors.red),
              ),
            ],
          ),
        ],
      ),

    );
  }

  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat("Time", _state.formattedTime),
          _stat("Distance", "${_state.distanceKm.toStringAsFixed(2)} km"),
          _stat("Pace", _state.formattedPace),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
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
                child: const Text("Clear"),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _cancelDrawing,
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
  double _unlockProgress = 0.0;
  Widget _buildLockOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, color: Colors.white, size: 60),
              const SizedBox(height: 16),
              const Text(
                "Screen Locked",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 20),

              // 🔓 SLIDE BAR
              GestureDetector(
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _unlockProgress += details.delta.dx / 200;
                    _unlockProgress = _unlockProgress.clamp(0.0, 1.0);
                  });
                },
                onHorizontalDragEnd: (_) {
                  if (_unlockProgress > 0.9) {
                    HapticFeedback.mediumImpact();
                    _toggleLock();
                  }
                  setState(() => _unlockProgress = 0.0);
                },
                child: Container(
                  width: 260,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Stack(
                    children: [
                      // progress fill
                      FractionallySizedBox(
                        widthFactor: _unlockProgress,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),

                      // text
                      const Center(
                        child: Text(
                          "Slide to unlock",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}