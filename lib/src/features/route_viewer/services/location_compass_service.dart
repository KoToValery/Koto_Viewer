import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/errors/app_error_handler.dart';
import 'web_compass/web_compass.dart';

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
    if (!kIsWeb && !Platform.isAndroid && !Platform.isIOS) {
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
    } on PlatformException catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'LocationCompassService.checkPermission.platform');
      return LocationPermissionState.unsupported;
    } on TimeoutException catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'LocationCompassService.checkPermission.timeout');
      return LocationPermissionState.unsupported;
    } on Exception catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'LocationCompassService.checkPermission');
      return LocationPermissionState.unsupported;
    }
  }

  /// Request location permission on-demand (when user taps My Location).
  static Future<LocationPermissionState> requestPermission() async {
    if (!kIsWeb && !Platform.isAndroid && !Platform.isIOS) {
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
    } on PlatformException catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'LocationCompassService.requestPermission.platform');
      return LocationPermissionState.unsupported;
    } on TimeoutException catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'LocationCompassService.requestPermission.timeout');
      return LocationPermissionState.unsupported;
    } on Exception catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'LocationCompassService.requestPermission');
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
    } on PlatformException catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'LocationCompassService.getCurrentPosition.platform');
      return null;
    } on TimeoutException catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'LocationCompassService.getCurrentPosition.timeout');
      return null;
    } on Exception catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'LocationCompassService.getCurrentPosition');
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
    } on PlatformException catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'LocationCompassService.getPositionStream.platform');
      return null;
    } on Exception catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'LocationCompassService.getPositionStream');
      return null;
    }
  }

  /// Request compass permission (specifically required on iOS 13+ Safari & iOS PWA).
  /// Should be invoked directly from a user gesture (e.g. tapping the location button).
  static Future<bool> requestCompassPermission() async {
    if (kIsWeb) {
      return await WebCompassPlatform.requestPermission();
    }
    return true;
  }

  /// Stream compass events with deadband filtering to prevent jitter and excessive rebuilds.
  /// Only emits when heading changes by at least [minDeltaDegrees] (default: 2.5°).
  static Stream<CompassHeadingData>? getFilteredCompassStream({
    double minDeltaDegrees = 2.5,
  }) {
    if (kIsWeb) {
      return WebCompassPlatform.getCompassStream(minDeltaDegrees: minDeltaDegrees);
    }

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
    } on PlatformException catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'LocationCompassService.getFilteredCompassStream.platform');
      return null;
    } on Exception catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'LocationCompassService.getFilteredCompassStream');
      return null;
    }
  }

  /// Stream compass heading events (0-360 degrees) with deadband filtering.
  static Stream<double?>? getCompassStream({double minDeltaDegrees = 2.5}) {
    try {
      return getFilteredCompassStream(minDeltaDegrees: minDeltaDegrees)
          ?.map((data) => data.heading);
    } on PlatformException catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'LocationCompassService.getCompassStream.platform');
      return null;
    } on Exception catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'LocationCompassService.getCompassStream');
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
