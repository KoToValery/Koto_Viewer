import 'dart:async';
import '../location_compass_service.dart';

/// Fallback stub for non-web platforms (Android, iOS native, Windows, macOS, Linux).
class WebCompassPlatform {
  static bool get isSupported => false;

  static Future<bool> requestPermission() async => true;

  static Stream<CompassHeadingData>? getCompassStream({double minDeltaDegrees = 2.5}) => null;
}
