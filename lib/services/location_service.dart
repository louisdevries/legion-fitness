import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  static Future<LatLng?> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    final pos = await Geolocator.getCurrentPosition();
    return LatLng(pos.latitude, pos.longitude);
  }

  static StreamSubscription<Position> startTracking({
    required Function(LatLng) onLocationUpdate,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
      ),
    ).listen((pos) {
      onLocationUpdate(LatLng(pos.latitude, pos.longitude));
    });
  }

  static Future<void> startBackgroundMode() async {
    final androidConfig = FlutterBackgroundAndroidConfig(
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