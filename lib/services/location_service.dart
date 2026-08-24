import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  // ==================== DEV CONFIG ====================

  static const bool _useDevLocation = false; // ⚡ Set to false for real GPS

  static const LatLng _devStartLocation = LatLng(
    -26.2041,
    28.0473,
  );

  static LatLng? _overrideLocation;

  static void setDebugLocation(LatLng location) {
    _overrideLocation = location;
  }

  static void clearDebugLocation() {
    _overrideLocation = null;
  }

  // ==================== LOCATION ACCESS ====================

  static Future<LatLng?> getCurrentLocation() async {
    // Use override if set
    if (_overrideLocation != null) return _overrideLocation;

    // DEV location for testing (disabled in production)
    if (_useDevLocation) return _devStartLocation;

    // Check GPS service
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return null;
    }

    // Check permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    // Return real GPS location
    final pos = await Geolocator.getCurrentPosition(
      locationSettings:
          const LocationSettings(accuracy: LocationAccuracy.bestForNavigation),
    );
    return LatLng(pos.latitude, pos.longitude);
  }

  // ==================== TRACKING ====================

  static StreamSubscription<LatLng> startTracking({
    required Function(LatLng) onLocationUpdate,
  }) {
    // DEV MODE (stationary but valid)
    if (_overrideLocation != null || _useDevLocation) {
      final LatLng start = _overrideLocation ?? _devStartLocation;
      return Stream<LatLng>.periodic(
        const Duration(seconds: 1),
            (_) => start,
      ).listen(onLocationUpdate);
    }

    // REAL GPS STREAM
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
      ),
    ).map((pos) => LatLng(pos.latitude, pos.longitude))
        .listen(onLocationUpdate);
  }

  // ==================== BACKGROUND MODE ====================

  static Future<void> startBackgroundMode() async {
    const androidConfig = FlutterBackgroundAndroidConfig(
      notificationTitle: "Outdoor Run",
      notificationText: "Tracking your run in the background",
      notificationImportance: AndroidNotificationImportance.normal,
      enableWifiLock: true,
    );

    await FlutterBackground.initialize(androidConfig: androidConfig);
    await FlutterBackground.enableBackgroundExecution();
  }

  static Future<void> stopBackgroundMode() async {
    await FlutterBackground.disableBackgroundExecution();
  }
}