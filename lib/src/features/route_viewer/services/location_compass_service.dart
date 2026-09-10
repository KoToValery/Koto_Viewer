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

  /// Stream compass events with deadband filtering to prevent jitter and excessive rebuilds.
  /// Only emits when heading changes by at least [minDeltaDegrees] (default: 2.5°).
  static Stream<CompassHeadingData>? getFilteredCompassStream({
    double minDeltaDegrees = 2.5,
  }) {
    try {
      double? lastEmittedHeading;
      return FlutterCompass.events
          ?.where((event) => event.heading != null)
          .where((event) {
            final double current = event.heading!;
            if (lastEmittedHeading == null) {
              lastEmittedHeading = current;
              return true;
            }
            double diff = (current - lastEmittedHeading!).abs();
            if (diff > 180.0) diff = 360.0 - diff;
            if (diff >= minDeltaDegrees) {
              lastEmittedHeading = current;
              return true;
            }
            return false;
          })
          .map((event) => CompassHeadingData(
                heading: event.heading!,
                accuracy: event.accuracy,
              ));
    } catch (e) {
      debugPrint('Error getting filtered compass stream: $e');
      return null;
    }
  }

  /// Stream compass heading events (0-360 degrees) with deadband filtering.
  static Stream<double?>? getCompassStream({double minDeltaDegrees = 2.5}) {
    try {
      return getFilteredCompassStream(minDeltaDegrees: minDeltaDegrees)
          ?.map((data) => data.heading);
    } catch (e) {
      debugPrint('Error getting compass stream: $e');
      return null;
    }
  }
}

/// Represents compass heading and sensor accuracy.
class CompassHeadingData {
  final double heading;
  final double? accuracy;

  const CompassHeadingData({
    required this.heading,
    this.accuracy,
  });

  /// On Android, accuracy == null indicates SENSOR_STATUS_UNRELIABLE (-1).
  /// On iOS, accuracy > 35 degrees indicates low/poor calibration.
  bool get isUnreliable => accuracy == null || accuracy! > 35.0;
}
