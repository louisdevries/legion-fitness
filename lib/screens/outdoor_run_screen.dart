import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_background/flutter_background.dart';

class OutdoorRunScreen extends StatefulWidget {
  const OutdoorRunScreen({super.key});

  @override
  State<OutdoorRunScreen> createState() => _OutdoorRunScreenState();
}

class _OutdoorRunScreenState extends State<OutdoorRunScreen> {
  final MapController mapController = MapController();
  StreamSubscription<Position>? positionStream;

  bool isRunning = false;
  bool isPaused = false;

  List<LatLng> routePoints = [];
  double totalDistanceMeters = 0;
  int elapsedSeconds = 0;
  Timer? timer;

  LatLng? currentPosition;

  @override
  void initState() {
    super.initState();
    initLocation();
  }

  Future<void> initLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    final pos = await Geolocator.getCurrentPosition();
    setState(() {
      currentPosition = LatLng(pos.latitude, pos.longitude);
    });
  }

  Future<void> startBackgroundMode() async {
    final androidConfig = FlutterBackgroundAndroidConfig(
      notificationTitle: "Outdoor Run",
      notificationText: "Tracking your run in the background",
      notificationImportance: AndroidNotificationImportance.normal,
      enableWifiLock: true,
    );

    await FlutterBackground.initialize(androidConfig: androidConfig);
    await FlutterBackground.enableBackgroundExecution();
  }



  void startRun() async {
    await startBackgroundMode(); // start background tracking

    setState(() {
      isRunning = true;
      isPaused = false;
      elapsedSeconds = 0;
      totalDistanceMeters = 0;
      routePoints.clear();
    });

    // Timer for elapsed seconds
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isPaused) {
        setState(() => elapsedSeconds++);
      }
    });

    // Location stream (runs even when app is backgrounded)
    positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
      ),
    ).listen((pos) {
      final newPoint = LatLng(pos.latitude, pos.longitude);

      if (routePoints.isNotEmpty) {
        final last = routePoints.last;
        final d = Geolocator.distanceBetween(
          last.latitude,
          last.longitude,
          newPoint.latitude,
          newPoint.longitude,
        );
        totalDistanceMeters += d;
      }

      routePoints.add(newPoint);
      currentPosition = newPoint;

      // Only update map if screen is active
      if (mounted) {
        setState(() {});
        mapController.move(newPoint, mapController.camera.zoom);
      }
    });
  }

  void pauseRun() {
    setState(() => isPaused = !isPaused);
  }

  void stopRun() {
    timer?.cancel();
    positionStream?.cancel();
    FlutterBackground.disableBackgroundExecution(); // stop foreground service

    setState(() {
      isRunning = false;
      isPaused = false;
    });

    // TODO: Save run to database
  }

  String formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    timer?.cancel();
    positionStream?.cancel();
    FlutterBackground.disableBackgroundExecution();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (currentPosition == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final km = totalDistanceMeters / 1000.0;
    final pace = km > 0 ? elapsedSeconds / 60 / km : 0;

    return Scaffold(
      body: Column(
        children: [
          // 🗺️ MAP
          Expanded(
            child: FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: currentPosition!,
                initialZoom: 17,
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  userAgentPackageName: 'com.yourapp.app',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      strokeWidth: 4,
                      color: Colors.blue,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: currentPosition!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.red,
                        size: 36,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 📊 STATS
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                statBox("Time", formatTime(elapsedSeconds)),
                statBox("Distance", "${km.toStringAsFixed(2)} km"),
                statBox(
                    "Pace",
                    pace == 0
                        ? "--"
                        : "${pace.toStringAsFixed(1)} min/km"),
              ],
            ),
          ),

          // 🎮 CONTROLS (LOCK UI WHILE RUNNING)
          if (!isRunning)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: startRun,
                child: const Text("Start"),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: pauseRun,
                    child: Text(isPaused ? "Resume" : "Pause"),
                  ),
                  ElevatedButton(
                    onPressed: stopRun,
                    style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text("Stop"),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget statBox(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
