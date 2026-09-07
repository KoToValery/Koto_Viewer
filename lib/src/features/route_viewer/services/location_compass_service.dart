import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';

enum LocationPermissionState {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
  unsupported,
}

class LocationCompassService {
  /// Check if location is permitted without prompting the user.
  static Future<LocationPermissionState> checkPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      // Basic check for desktop / unsupported
      return LocationPermissionState.granted;
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationPermissionState.serviceDisabled;
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        return LocationPermissionState.granted;
      } else if (permission == LocationPermission.deniedForever) {
        return LocationPermissionState.deniedForever;
      } else {
        return LocationPermissionState.denied;
      }
    } catch (e) {
      debugPrint('Location permission check error: $e');
      return LocationPermissionState.unsupported;
    }
  }

  /// Request location permission on-demand (when user taps My Location).
  static Future<LocationPermissionState> requestPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return LocationPermissionState.granted;
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationPermissionState.serviceDisabled;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        return LocationPermissionState.granted;
      } else if (permission == LocationPermission.deniedForever) {
        return LocationPermissionState.deniedForever;
      } else {
        return LocationPermissionState.denied;
      }
    } catch (e) {
      debugPrint('Location permission request error: $e');
      return LocationPermissionState.unsupported;
    }
  }

  /// Get current GPS position once.
  static Future<Position?> getCurrentPosition() async {
    try {
      final state = await checkPermission();
      if (state != LocationPermissionState.granted) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint('Error getting current position: $e');
      return null;
    }
  }

  /// Stream position updates for real-time tracking.
  static Stream<Position>? getPositionStream() {
    try {
      return Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 3, // Update every 3 meters
        ),
      );
    } catch (e) {
      debugPrint('Error getting position stream: $e');
      return null;
    }
  }

  /// Stream compass heading events (0-360 degrees).
  static Stream<double?>? getCompassStream() {
    try {
      return FlutterCompass.events?.map((event) => event.heading);
    } catch (e) {
      debugPrint('Error getting compass stream: $e');
      return null;
    }
  }
}
