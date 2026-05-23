import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';

import '../models/saved_route.dart';
import '../services/route_service.dart';
import '../services/location_service.dart';
import '../services/run_service.dart';
import '../services/geocoding_service.dart';
import '../utils/route_utils.dart';
import '../utils/map_gesture_handler.dart';
import '../models/run_state.dart';
import '../widgets/tap_route_builder.dart';
import '../services/achievement_service.dart';
import '../services/xp_service.dart';

const String mapboxToken =
    "pk.eyJ1IjoibG91aXNkZXZyaWVzIiwiYSI6ImNtbnlsZ3d1dDAzMXgycXNlcXlyaHJrdmwifQ.bDTfupr74bI5qnK7VCgBHg";

class OutdoorRunScreen extends StatefulWidget {
  final Function(bool)? onRunModeChanged;

  const OutdoorRunScreen({super.key, this.onRunModeChanged});

  @override
  State<OutdoorRunScreen> createState() => _OutdoorRunScreenState();
}

class _OutdoorRunScreenState extends State<OutdoorRunScreen> {
  final MapController _mapController = MapController();
  final GlobalKey _mapKey = GlobalKey();

  StreamSubscription<LatLng>? _positionStream;
  Timer? _timer;
  MapGestureHandler? _gestureHandler;
  DateTime? _startTime;

  late RunState _state;

  // Lock mode (during runs)
  bool _isLocked = false;
  double _unlockProgress = 0.0;

  // Drawing mode sub-state — when true, finger pans the map instead of drawing
  bool _panInsteadOfDraw = false;

  // ── Tap-to-build route mode ────────────────────────────────────────
  bool _isBuildingByTap = false;
  final List<LatLng> _buildPins = [];
  List<LatLng> _buildPreviewRoute = [];
  double _buildPreviewKm = 0;
  bool _buildIsRouting = false;
  Timer? _buildRouteDebounce;

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
    _buildRouteDebounce?.cancel();
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
    setState(() => _isLocked = !_isLocked);
  }

  // ==================== RUN CONTROLS ====================

  Future<void> _startRun() async {
    await LocationService.startBackgroundMode();
    _startTime = DateTime.now();
    widget.onRunModeChanged?.call(true);

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
          _state =
              _state.copyWith(elapsedSeconds: _state.elapsedSeconds + 1);
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

  void _stopRun() async {
    _timer?.cancel();
    _positionStream?.cancel();
    LocationService.stopBackgroundMode();
    widget.onRunModeChanged?.call(false);

    final user = Supabase.instance.client.auth.currentUser;
    final attemptedRouteId = _state.selectedRoute?.id;
    final priorBest = attemptedRouteId != null
        ? await RouteService.getBestTimeSecondsForRoute(attemptedRouteId)
        : null;

    if (user != null && _startTime != null) {
      try {
        final endTime = DateTime.now();

        if (_state.totalDistanceMeters < 50) {
          _showSnackBar("Run too short to save");
        } else {
          final avgPace = _state.totalDistanceMeters > 0
              ? (_state.elapsedSeconds / 60) /
              (_state.totalDistanceMeters / 1000)
              : null;

          await RunService.saveRun(
            userId: user.id,
            startedAt: _startTime!,
            endedAt: endTime,
            durationSeconds: _state.elapsedSeconds,
            distanceMeters: _state.totalDistanceMeters,
            avgPace: avgPace,
            route: _state.actualRunPath,
            routeId: attemptedRouteId,
          );

          final unlocked = await AchievementService.onRunCompleted(
            distanceMeters: _state.totalDistanceMeters,
          );
          if (mounted) {
            for (final a in unlocked) {
              _showSnackBar('🏆 Unlocked: ${a.label}');
            }
          }

          final runId = _startTime!.millisecondsSinceEpoch ~/ 1000;
          final xpGrants = await XpService.onRunCompleted(
            runId: runId,
            distanceMeters: _state.totalDistanceMeters,
          );
          if (mounted) {
            for (final g in xpGrants) {
              _showSnackBar(
                g.isLevelUp
                    ? '+${g.amount} XP — Level Up! Now Level ${g.newLevel}'
                    : '+${g.amount} XP · ${g.label}',
              );
            }
          }

          if (attemptedRouteId != null) {
            if (priorBest == null) {
              _showSnackBar(
                  "Run saved ✅ — first time on '${_state.selectedRoute!.name}'!");
            } else if (_state.elapsedSeconds < priorBest) {
              _showSnackBar(
                  "🏆 New best on '${_state.selectedRoute!.name}'! ${_formatDuration(_state.elapsedSeconds)} (was ${_formatDuration(priorBest)})");
            } else {
              _showSnackBar(
                  "Run saved ✅ — best on this route is still ${_formatDuration(priorBest)}");
            }
          } else {
            _showSnackBar("Run saved successfully ✅");
          }
        }
      } catch (e) {
        _showSnackBar("Failed to save run ❌");
        developer.log("Save run error: $e");
      }
    }

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
        totalDistanceMeters:
        _state.isDrawing ? _state.totalDistanceMeters : 0,
        clearSelectedRoute: !_state.isDrawing,
        plannedRoute: [],
      );
      _panInsteadOfDraw = false;
    });

    if (_state.isDrawing) {
      _gestureHandler = MapGestureHandler(
        mapController: _mapController,
        mapKey: _mapKey,
      );
    }
  }

  void _toggleDrawPanMode() {
    setState(() {
      _panInsteadOfDraw = !_panInsteadOfDraw;
      _state = _state.copyWith(isCurrentlyDrawing: false);
      _gestureHandler?.resetOffset();
    });
  }

  void _handlePanStart(DragStartDetails details) {
    if (!_state.isDrawing || _isLocked || _panInsteadOfDraw) return;
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
    if (!_state.isDrawing ||
        !_state.isCurrentlyDrawing ||
        _isLocked ||
        _panInsteadOfDraw) {
      return;
    }
    if (_gestureHandler!.shouldAddPoint(details.localPosition)) {
      final point = _gestureHandler!.offsetToLatLng(details.localPosition);
      if (point != null) {
        final updated = List<LatLng>.from(_state.rawDrawnPoints)..add(point);
        final smoothed = RouteUtils.smoothRoute(updated);
        setState(() {
          _state = _state.copyWith(
            rawDrawnPoints: updated,
            routePoints: smoothed,
            totalDistanceMeters:
            RouteUtils.calculateRouteDistance(smoothed),
          );
        });
        _gestureHandler!.updateLastOffset(details.localPosition);
      }
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!_state.isDrawing || _panInsteadOfDraw) return;
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
      _panInsteadOfDraw = false;
    });
  }

  // ==================== SAVE / SELECT ROUTES ====================

  Future<void> _saveDrawnRoute() async {
    if (_state.routePoints.length < 2) {
      _showSnackBar("Draw a route first");
      return;
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showSnackBar("You must be signed in to save routes");
      return;
    }

    final name = await _promptForRouteName();
    if (name == null || name.isEmpty) return;

    await _persistRoute(
      userId: user.id,
      name: name,
      points: _state.routePoints,
      distanceMeters: _state.totalDistanceMeters,
      exitDrawing: true,
    );
  }

  Future<void> _persistRoute({
    required String userId,
    required String name,
    required List<LatLng> points,
    required double distanceMeters,
    required bool exitDrawing,
  }) async {
    try {
      final route = SavedRoute(
        userId: userId,
        name: name,
        points: points,
        distanceKm: distanceMeters / 1000.0,
      );
      final inserted = await RouteService.saveRoute(route);

      if (!mounted) return;
      setState(() {
        _state = _state.copyWith(
          savedRoutes: [..._state.savedRoutes, inserted],
          selectedRoute: inserted,
          isDrawing: exitDrawing ? false : _state.isDrawing,
          routePoints: inserted.points,
          rawDrawnPoints: [],
        );
        if (exitDrawing) _panInsteadOfDraw = false;
      });

      if (inserted.points.isNotEmpty) {
        _mapController.move(
            inserted.points.first, _mapController.camera.zoom);
      }
      _showSnackBar("Route '$name' saved ✅");
    } catch (e) {
      developer.log("Save route error: $e");
      _showSnackBar("Failed to save route ❌");
    }
  }

  Future<String?> _promptForRouteName({String? initial}) async {
    final controller = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Name this route"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: "e.g. Park loop"),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _selectRoute(SavedRoute route) {
    setState(() {
      _state = _state.copyWith(
        selectedRoute: route,
        isDrawing: false,
        routePoints: route.points,
        rawDrawnPoints: [],
        totalDistanceMeters: route.distanceKm * 1000,
        plannedRoute: [],
      );
      _panInsteadOfDraw = false;
    });
    if (route.points.isNotEmpty) {
      _mapController.move(route.points.first, _mapController.camera.zoom);
    }
  }

  void _clearSelectedRoute() {
    setState(() {
      _state = _state.copyWith(
        clearSelectedRoute: true,
        routePoints: [],
        totalDistanceMeters: 0,
      );
    });
  }

  Future<void> _deleteSavedRoute(SavedRoute route) async {
    if (route.id == null) return;
    try {
      await RouteService.deleteRoute(route.id!);
      if (!mounted) return;
      setState(() {
        final updated =
        _state.savedRoutes.where((r) => r.id != route.id).toList();
        _state = _state.copyWith(
          savedRoutes: updated,
          clearSelectedRoute: _state.selectedRoute?.id == route.id,
          routePoints:
          _state.selectedRoute?.id == route.id ? [] : _state.routePoints,
        );
      });
      _showSnackBar("Route deleted");
    } catch (e) {
      developer.log("Delete route error: $e");
      _showSnackBar("Failed to delete route ❌");
    }
  }

  void _openRoutesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.3,
          builder: (ctx, scrollController) {
            return _RoutesSheet(
              routes: _state.savedRoutes,
              selectedId: _state.selectedRoute?.id,
              scrollController: scrollController,
              onSelect: (r) {
                Navigator.pop(ctx);
                _selectRoute(r);
              },
              onDelete: (r) async {
                final confirmed = await showDialog<bool>(
                  context: ctx,
                  builder: (dctx) => AlertDialog(
                    title: const Text("Delete route?"),
                    content: Text(
                        "'${r.name}' will be removed. Past runs against it are kept."),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dctx, false),
                        child: const Text("Cancel"),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        onPressed: () => Navigator.pop(dctx, true),
                        child: const Text("Delete"),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await _deleteSavedRoute(r);
                  if (mounted && Navigator.canPop(ctx)) Navigator.pop(ctx);
                }
              },
            );
          },
        );
      },
    );
  }

  // ==================== TAP-TO-BUILD ROUTE MODE ====================

  void _enterTapBuildMode() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showSnackBar('You must be signed in to save routes');
      return;
    }
    setState(() {
      _isBuildingByTap = true;
      _buildPins.clear();
      _buildPreviewRoute = [];
      _buildPreviewKm = 0;
      _buildIsRouting = false;
      _state = _state.copyWith(
        isDrawing: false,
        clearSelectedRoute: true,
        routePoints: [],
        rawDrawnPoints: [],
        plannedRoute: [],
      );
    });
  }

  void _exitTapBuildMode() {
    _buildRouteDebounce?.cancel();
    setState(() {
      _isBuildingByTap = false;
      _buildPins.clear();
      _buildPreviewRoute = [];
      _buildPreviewKm = 0;
      _buildIsRouting = false;
    });
  }

  void _addBuildPin(LatLng point) {
    setState(() => _buildPins.add(point));
    _scheduleBuildRouteRefresh();
  }

  void _removeBuildPin(int index) {
    if (index < 0 || index >= _buildPins.length) return;
    setState(() => _buildPins.removeAt(index));
    _scheduleBuildRouteRefresh();
  }

  void _undoBuildPin() {
    if (_buildPins.isEmpty) return;
    setState(() => _buildPins.removeLast());
    _scheduleBuildRouteRefresh();
  }

  void _clearBuildPins() {
    setState(() {
      _buildPins.clear();
      _buildPreviewRoute = [];
      _buildPreviewKm = 0;
    });
    _buildRouteDebounce?.cancel();
  }

  /// Debounce route refresh — when the user taps several pins quickly,
  /// only fire OSRM once after they stop.
  void _scheduleBuildRouteRefresh() {
    _buildRouteDebounce?.cancel();
    if (_buildPins.length < 2) {
      setState(() {
        _buildPreviewRoute = [];
        _buildPreviewKm = 0;
      });
      return;
    }
    setState(() => _buildIsRouting = true);
    _buildRouteDebounce = Timer(const Duration(milliseconds: 400), () async {
      final pins = List<LatLng>.from(_buildPins);
      final routed = await GeocodingService.routeThroughWaypoints(pins);
      if (!mounted) return;
      double meters = 0;
      for (int i = 0; i < routed.length - 1; i++) {
        meters += const Distance().as(
          LengthUnit.Meter,
          routed[i],
          routed[i + 1],
        );
      }
      setState(() {
        _buildPreviewRoute = routed;
        _buildPreviewKm = meters / 1000.0;
        _buildIsRouting = false;
      });
    });
  }

  Future<void> _saveBuiltRoute() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    if (_buildPreviewRoute.isEmpty) {
      _showSnackBar('Add at least 2 pins first');
      return;
    }

    // Reverse-geocode pins in parallel for a nice default name.
    final names = await GeocodingService.reverseGeocodeBatch(_buildPins);
    final summary = names.map((n) => n.shortName).join(' → ');

    if (!mounted) return;
    final name = await _promptForRouteName(
      initial: summary.length > 60 ? summary.substring(0, 60) : summary,
    );
    if (name == null || name.isEmpty) return;

    await _persistRoute(
      userId: user.id,
      name: name,
      points: _buildPreviewRoute,
      distanceMeters: _buildPreviewKm * 1000,
      exitDrawing: false,
    );
    _exitTapBuildMode();
  }

  // ==================== MAP TAP HANDLER ====================

  void _handleMapTap(TapPosition tapPos, LatLng latlng) {
    if (_isBuildingByTap) {
      _addBuildPin(latlng);
    }
  }

  // ==================== HELPERS ====================

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
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
                if (!_isBuildingByTap && _buildInfoBanner() != null)
                  _buildInfoBanner()!,
                Expanded(child: _buildMap()),
                if (!_isBuildingByTap) _buildStatsBar(),
                if (!_isBuildingByTap) _buildControls(),
              ],
            ),
            if (_isLocked) _buildLockOverlay(),
            if (_isBuildingByTap)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: TapRouteBuilderPanel(
                  pinCount: _buildPins.length,
                  routeKm: _buildPreviewKm,
                  isRouting: _buildIsRouting,
                  canSave: _buildPreviewRoute.length >= 2,
                  onUndo: _undoBuildPin,
                  onClear: _clearBuildPins,
                  onCancel: _exitTapBuildMode,
                  onSave: _saveBuiltRoute,
                ),
              ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text("Outdoor Run"),
      actions: [
        if (!_state.isRunning && !_isBuildingByTap)
          IconButton(
            tooltip: "My routes",
            icon: const Icon(Icons.route),
            onPressed: _openRoutesSheet,
          ),
        if (!_state.isRunning && !_isBuildingByTap)
          IconButton(
            tooltip: "Build by tapping the map",
            icon: const Icon(Icons.add_location_alt_outlined),
            onPressed: _enterTapBuildMode,
          ),
        IconButton(
          icon: Icon(_isLocked ? Icons.lock : Icons.lock_open),
          onPressed: _toggleLock,
        ),
        if (!_state.isRunning && !_isBuildingByTap)
          IconButton(
            tooltip: _state.isDrawing ? "Done" : "Draw a route",
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
    if (_state.isDrawing) {
      final isPan = _panInsteadOfDraw;
      return Container(
        padding: const EdgeInsets.all(8),
        color: (isPan ? Colors.orange : Colors.blue).withValues(alpha: 0.15),
        child: Row(
          children: [
            Icon(
              isPan ? Icons.pan_tool_alt : Icons.edit,
              color: isPan ? Colors.orange : Colors.blue,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isPan
                    ? "Pan mode — drag to move the map, pinch to zoom"
                    : "Draw mode — drag to draw your route",
              ),
            ),
          ],
        ),
      );
    }
    if (_state.selectedRoute != null && !_state.isRunning) {
      return Container(
        padding: const EdgeInsets.all(8),
        color: Colors.purple.withValues(alpha: 0.15),
        child: Row(
          children: [
            const Icon(Icons.flag, color: Colors.purple),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Attempting: ${_state.selectedRoute!.name} • "
                    "${_state.selectedRoute!.distanceKm.toStringAsFixed(2)} km",
              ),
            ),
            IconButton(
              tooltip: "Clear",
              icon: const Icon(Icons.close, size: 18),
              onPressed: _clearSelectedRoute,
            ),
          ],
        ),
      );
    }
    return null;
  }

  Widget _buildMap() {
    final bool drawingActive =
        _state.isDrawing && !_isLocked && !_panInsteadOfDraw;

    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: drawingActive ? _handlePanStart : null,
          onPanUpdate: drawingActive ? _handlePanUpdate : null,
          onPanEnd: drawingActive ? _handlePanEnd : null,
          child: FlutterMap(
            key: _mapKey,
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _state.currentPosition!,
              initialZoom: 17,
              interactionOptions: InteractionOptions(
                flags: (_isLocked || drawingActive)
                    ? InteractiveFlag.none
                    : InteractiveFlag.all,
              ),
              onTap: _handleMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate:
                "https://api.mapbox.com/styles/v1/mapbox/outdoors-v12/tiles/{z}/{x}/{y}?access_token=$mapboxToken",
                tileSize: 512,
                zoomOffset: -1,
              ),

              // Ghost route (selected saved route)
              if (_state.selectedRoute != null &&
                  _state.selectedRoute!.points.isNotEmpty &&
                  !_isBuildingByTap)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _state.selectedRoute!.points,
                      strokeWidth: 6,
                      color: Colors.purple.withValues(alpha: 0.35),
                      borderStrokeWidth: 2,
                      borderColor: Colors.purple.withValues(alpha: 0.5),
                    ),
                  ],
                ),

              // Live run path
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

              // Drawn preview (only when no saved route is selected and not building)
              if (_state.selectedRoute == null &&
                  _state.routePoints.isNotEmpty &&
                  !_isBuildingByTap)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _state.routePoints,
                      strokeWidth: 4,
                      color: Colors.blue,
                    ),
                  ],
                ),

              // Build mode: routed preview line
              if (_isBuildingByTap && _buildPreviewRoute.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _buildPreviewRoute,
                      strokeWidth: 5,
                      color: Colors.blue.withValues(alpha: 0.85),
                      borderStrokeWidth: 2,
                      borderColor: Colors.white.withValues(alpha: 0.6),
                    ),
                  ],
                ),

              // Build mode: pin markers
              if (_isBuildingByTap && _buildPins.isNotEmpty)
                MarkerLayer(
                  markers: [
                    for (int i = 0; i < _buildPins.length; i++)
                      Marker(
                        point: _buildPins[i],
                        width: 48,
                        height: 48,
                        alignment: Alignment.topCenter,
                        child: WaypointPin(
                          label: i == 0
                              ? 'A'
                              : i == _buildPins.length - 1
                              ? 'B'
                              : '$i',
                          color: i == 0
                              ? Colors.green
                              : i == _buildPins.length - 1
                              ? Colors.red
                              : Colors.blue,
                          onRemove: () => _removeBuildPin(i),
                        ),
                      ),
                  ],
                ),

              // User position marker
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
        ),

        // Floating draw/pan toggle while drawing
        if (_state.isDrawing && !_isLocked)
          Positioned(
            top: 12,
            right: 12,
            child: Material(
              elevation: 4,
              shape: const CircleBorder(),
              color: _panInsteadOfDraw ? Colors.orange : Colors.blue,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _toggleDrawPanMode,
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  child: Icon(
                    _panInsteadOfDraw ? Icons.edit : Icons.pan_tool_alt,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
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
                onPressed:
                _state.routePoints.length >= 2 ? _saveDrawnRoute : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text("Save"),
              ),
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
                      FractionallySizedBox(
                        widthFactor: _unlockProgress,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
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

// ==========================================================================
// Routes bottom sheet
// ==========================================================================

class _RoutesSheet extends StatelessWidget {
  final List<SavedRoute> routes;
  final int? selectedId;
  final ScrollController scrollController;
  final void Function(SavedRoute) onSelect;
  final void Function(SavedRoute) onDelete;

  const _RoutesSheet({
    required this.routes,
    required this.selectedId,
    required this.scrollController,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            "My Routes",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (routes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text(
                "No saved routes yet.\nDraw one with the pencil, or build one by tapping the map.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                itemCount: routes.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final r = routes[i];
                  final isSelected = r.id == selectedId;
                  return _RouteTile(
                    route: r,
                    isSelected: isSelected,
                    onTap: () => onSelect(r),
                    onDelete: () => onDelete(r),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _RouteTile extends StatelessWidget {
  final SavedRoute route;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _RouteTile({
    required this.route,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        Icons.route,
        color: isSelected ? Colors.purple : Colors.grey,
      ),
      title: Text(
        route.name,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Row(
        children: [
          Text("${route.distanceKm.toStringAsFixed(2)} km"),
          const SizedBox(width: 12),
          if (route.id != null)
            FutureBuilder<int?>(
              future: RouteService.getBestTimeSecondsForRoute(route.id!),
              builder: (ctx, snap) {
                if (!snap.hasData || snap.data == null) {
                  return const Text(
                    "No runs yet",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  );
                }
                final s = snap.data!;
                final m = s ~/ 60;
                final sec = s % 60;
                return Row(
                  children: [
                    const Icon(Icons.emoji_events,
                        size: 14, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text("${m}m ${sec}s",
                        style: const TextStyle(fontSize: 12)),
                  ],
                );
              },
            ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.red),
        onPressed: onDelete,
      ),
      onTap: onTap,
    );
  }
}