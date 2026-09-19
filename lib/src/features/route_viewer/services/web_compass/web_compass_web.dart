import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;
import '../location_compass_service.dart';

/// Web implementation for device orientation and compass heading.
/// Specifically handles iOS Safari & iOS PWA (WebKit) permissions and webkitCompassHeading.
class WebCompassPlatform {
  static bool get isSupported => true;

  /// Request permission for DeviceOrientation (required on iOS 13+ Safari & iOS PWA).
  /// Must be invoked in response to a user action (e.g. button tap).
  static Future<bool> requestPermission() async {
    try {
      final windowObj = web.window as JSObject;
      if (windowObj.has('DeviceOrientationEvent')) {
        final JSAny? devEvent = windowObj['DeviceOrientationEvent'];
        if (devEvent.isA<JSObject>()) {
          final devObj = devEvent as JSObject;
          if (devObj.has('requestPermission')) {
            final JSPromise promise = devObj.callMethod('requestPermission'.toJS);
            final JSAny? res = await promise.toDart;
            return res?.dartify().toString().toLowerCase() == 'granted';
          }
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Streams compass heading events with deadband filtering.
  static Stream<CompassHeadingData>? getCompassStream({double minDeltaDegrees = 2.5}) {
    StreamController<CompassHeadingData>? controller;
    web.EventListener? orientationListener;
    web.EventListener? absoluteListener;
    double? lastEmittedHeading;

    void handleEvent(web.Event event) {
      if (controller == null || controller.isClosed) return;

      double? heading;
      double? accuracy;

      try {
        final jsEvent = event as JSObject;

        // 1. iOS Safari & iOS PWA (WebKit): webkitCompassHeading provides 0-360° (0 = North)
        if (jsEvent.has('webkitCompassHeading')) {
          final JSAny? val = jsEvent['webkitCompassHeading'];
          if (val != null) {
            final Object? dartVal = val.dartify();
            if (dartVal is num) {
              heading = dartVal.toDouble();
            }
          }

          if (jsEvent.has('webkitCompassAccuracy')) {
            final JSAny? accVal = jsEvent['webkitCompassAccuracy'];
            if (accVal != null) {
              final Object? dartAcc = accVal.dartify();
              if (dartAcc is num && dartAcc >= 0) {
                accuracy = dartAcc.toDouble();
              }
            }
          }
        }
      } catch (_) {}

      // 2. Android Chrome / Standard W3C DeviceOrientation fallback
      if (heading == null && event.isA<web.DeviceOrientationEvent>()) {
        final devOri = event as web.DeviceOrientationEvent;
        final num? alpha = devOri.alpha;
        if (alpha != null) {
          heading = (360.0 - alpha.toDouble()) % 360.0;
          accuracy = devOri.absolute ? 15.0 : 30.0;
        }
      }

      if (heading == null) return;

      // Deadband filtering to prevent jitter and unnecessary widget rebuilds
      if (lastEmittedHeading != null) {
        double diff = (heading - lastEmittedHeading!).abs();
        if (diff > 180.0) diff = 360.0 - diff;
        if (diff < minDeltaDegrees) {
          return;
        }
      }

      lastEmittedHeading = heading;
      controller.add(CompassHeadingData(
        heading: heading,
        accuracy: accuracy,
      ));
    }

    controller = StreamController<CompassHeadingData>.broadcast(
      onListen: () {
        final jsHandler = ((web.Event e) => handleEvent(e)).toJS;
        orientationListener = jsHandler;
        web.window.addEventListener('deviceorientation', orientationListener);

        final windowObj = web.window as JSObject;
        if (windowObj.has('ondeviceorientationabsolute')) {
          absoluteListener = jsHandler;
          web.window.addEventListener('deviceorientationabsolute', absoluteListener);
        }
      },
      onCancel: () {
        if (orientationListener != null) {
          web.window.removeEventListener('deviceorientation', orientationListener);
          orientationListener = null;
        }
        if (absoluteListener != null) {
          web.window.removeEventListener('deviceorientationabsolute', absoluteListener);
          absoluteListener = null;
        }
      },
    );

    return controller.stream;
  }
}
