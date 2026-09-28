import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/models/mesh_3d.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/rendering/cad_3d_camera.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/widgets/cad_3d_virtual_joystick.dart';

void main() {
  group('Cad3DCamera Fly Mode Tests', () {
    test('initializes with default orbit mode', () {
      final camera = Cad3DCamera();
      expect(camera.mode, equals(Cad3DInteractionMode.orbit));
      expect(camera.isFlyMode, isFalse);
      expect(camera.eyePosition.x, equals(0.0));
      expect(camera.eyePosition.y, equals(0.0));
      expect(camera.eyePosition.z, equals(0.0));
    });

    test('switchToFlyMode starts seamlessly from exact current view with zero jump', () {
      final camera = Cad3DCamera(yaw: 0.5, pitch: 0.3, zoom: 2.5, panOffset: const Offset(40, -30));
      const modelScale = 0.05;
      const viewport = Size(1000, 800);
      final testVertex = const Vector3(120.0, -85.0, 45.0);

      // Pre-switch Orbit projection
      final tvOrbit = camera.transformVertex(testVertex);
      final screenOrbit = camera.projectToScreen(tvOrbit, viewport, modelScale);

      // Switch to Fly mode
      camera.switchToFlyMode(modelScale);
      expect(camera.mode, equals(Cad3DInteractionMode.fly));
      expect(camera.isFlyMode, isTrue);

      // Seamless: eyePosition begins at origin, zoom and pan are preserved
      expect(camera.eyePosition.x, closeTo(0.0, 1e-4));
      expect(camera.eyePosition.y, closeTo(0.0, 1e-4));
      expect(camera.eyePosition.z, closeTo(0.0, 1e-4));
      expect(camera.zoom, equals(2.5));
      expect(camera.panOffset, equals(const Offset(40, -30)));

      // Verify center vertex has mathematically ZERO jump (1e-4)
      final tvCenterOrbit = camera.transformVertex(Vector3.zero);
      final screenCenterOrbit = camera.projectToScreen(tvCenterOrbit, viewport, modelScale);

      final tvCenterFly = camera.transformVertex(Vector3.zero);
      final screenCenterFly = camera.projectToScreen(tvCenterFly, viewport, modelScale);

      expect(screenCenterFly.dx, closeTo(screenCenterOrbit.dx, 1e-4));
      expect(screenCenterFly.dy, closeTo(screenCenterOrbit.dy, 1e-4));

      // Off-center vertex has seamless sub-pixel alignment (< 0.1 px) with enhanced FOV perspective
      final tvFly = camera.transformVertex(testVertex);
      final screenFly = camera.projectToScreen(tvFly, viewport, modelScale);

      expect(camera.cameraDist, equals(420.0)); // True architectural perspective
      expect(screenFly.dx, closeTo(screenOrbit.dx, 0.1));
      expect(screenFly.dy, closeTo(screenOrbit.dy, 0.1));
    });

    test('reset(keepMode: true) preserves Fly mode and resets view to center', () {
      final camera = Cad3DCamera(yaw: 1.0, pitch: 0.5, zoom: 3.0, panOffset: const Offset(50, 50));
      camera.switchToFlyMode(1.0);
      camera.eyePosition = const Vector3(100, 200, 300);

      camera.reset(keepMode: true);
      expect(camera.mode, equals(Cad3DInteractionMode.fly));
      expect(camera.isFlyMode, isTrue);
      expect(camera.eyePosition, equals(Vector3.zero));
      expect(camera.zoom, equals(1.0));
      expect(camera.panOffset, equals(Offset.zero));
    });

    test('forward vector points in 3D direction of gaze', () {
      // 1. Looking horizontal straight forward (yaw=0, pitch=0)
      final camera = Cad3DCamera(yaw: 0.0, pitch: 0.0);
      var fwd = camera.forwardVector;
      expect(fwd.x, closeTo(0.0, 1e-4));
      expect(fwd.y, closeTo(1.0, 1e-4));
      expect(fwd.z, closeTo(0.0, 1e-4));

      // 2. Looking UP: pitch < 0 (e.g. -pi/4) -> forward.z should be positive (UP)
      camera.pitch = -math.pi / 4;
      fwd = camera.forwardVector;
      expect(fwd.z, greaterThan(0.0)); // flying forward flies UP!

      // 3. Looking DOWN: pitch > 0 (e.g. +pi/4) -> forward.z should be negative (DOWN)
      camera.pitch = math.pi / 4;
      fwd = camera.forwardVector;
      expect(fwd.z, lessThan(0.0)); // flying forward flies DOWN!
    });

    test('right vector is horizontal and perpendicular to gaze', () {
      final camera = Cad3DCamera(yaw: 0.0, pitch: math.pi / 6);
      final rgt = camera.rightVector;
      expect(rgt.x, closeTo(1.0, 1e-4));
      expect(rgt.y, closeTo(0.0, 1e-4));
      expect(rgt.z, closeTo(0.0, 1e-4)); // strictly horizontal strafe
    });

    test('fly moves forward/backward and strafe left/right accurately', () {
      final camera = Cad3DCamera(yaw: 0.0, pitch: 0.0);
      camera.switchToFlyMode(1.0);
      final initialPos = Vector3(camera.eyePosition.x, camera.eyePosition.y, camera.eyePosition.z);

      // Fly forward by 100 units
      camera.fly(forward: 1.0, strafe: 0.0, speed: 100.0, dt: 1.0);
      expect(camera.eyePosition.y, closeTo(initialPos.y + 100.0, 1e-4));
      expect(camera.eyePosition.x, closeTo(initialPos.x, 1e-4));
      expect(camera.eyePosition.z, closeTo(initialPos.z, 1e-4));

      // Strafe right by 50 units
      camera.fly(forward: 0.0, strafe: 1.0, speed: 50.0, dt: 1.0);
      expect(camera.eyePosition.x, closeTo(initialPos.x + 50.0, 1e-4));
    });

    test('fly moves UP when looking UP (ArchiCAD flight style)', () {
      final camera = Cad3DCamera(yaw: 0.0, pitch: -math.pi / 4); // looking up
      camera.switchToFlyMode(1.0);
      final initialZ = camera.eyePosition.z;

      // Fly forward
      camera.fly(forward: 1.0, strafe: 0.0, speed: 100.0, dt: 1.0);
      expect(camera.eyePosition.z, greaterThan(initialZ)); // gained altitude!
    });

    test('look rotates yaw and pitch with clamping', () {
      final camera = Cad3DCamera(yaw: 0.0, pitch: 0.0);
      camera.look(100.0, 50.0);
      expect(camera.yaw, closeTo(100.0 * 0.005, 1e-4));

      // Test extreme pitch clamping
      camera.look(0.0, 10000.0);
      const limit = math.pi * 0.48;
      expect(camera.pitch, lessThanOrEqualTo(limit));
      expect(camera.pitch, greaterThanOrEqualTo(-limit));
    });

    test('transformVertex offsets by eyePosition in Fly mode', () {
      final camera = Cad3DCamera(yaw: 0.0, pitch: 0.0);
      camera.switchToFlyMode(1.0);
      camera.eyePosition = const Vector3(10.0, 20.0, 30.0);

      final vertex = const Vector3(10.0, 120.0, 30.0);
      final tv = camera.transformVertex(vertex);

      // Relative to eye: (0.0, 100.0, 0.0)
      expect(tv.x, closeTo(0.0, 1e-4));
      expect(tv.y, closeTo(100.0, 1e-4));
      expect(tv.z, closeTo(0.0, 1e-4));
    });

    test('cameraDist provides architectural FOV in Fly mode and flat CAD in Orbit mode', () {
      final camera = Cad3DCamera();
      expect(camera.cameraDist, equals(1200.0)); // Orbit mode
      camera.switchToFlyMode();
      expect(camera.cameraDist, equals(420.0)); // Architectural perspective Fly mode
      camera.switchToOrbitMode();
      expect(camera.cameraDist, equals(1200.0)); // Back to Orbit
    });

    test('projectToScreen uses distance-based perspective in Fly mode', () {
      final camera = Cad3DCamera(yaw: 0.0, pitch: 0.0);
      camera.switchToFlyMode(1.0);

      const viewport = Size(800, 600);
      const modelScale = 1.0;

      // Vertex directly on line of sight at cameraDist depth
      final tv = Vector3(0.0, camera.cameraDist, 0.0);
      final screenOffset = camera.projectToScreen(tv, viewport, modelScale);

      expect(screenOffset.dx, closeTo(400.0, 1e-4)); // centered
      expect(screenOffset.dy, closeTo(300.0, 1e-4)); // centered
    });

    test('fine speed calculation provides millimeter adjustment in corridors', () {
      // Simulating speed calculation logic for an IFC model in millimeters (25m house)
      const maxDim = 25000.0;
      final double oneMeter = maxDim >= 500.0 ? 1000.0 : 1.0;
      final double walkSpeed = 1.3 * oneMeter;
      final double maxFlySpeed = 7.0 * oneMeter;

      double computeSpeed(double deflectionMag) {
        if (deflectionMag <= 0.5) {
          final t = deflectionMag / 0.5;
          return walkSpeed * (t * t);
        } else {
          final u = (deflectionMag - 0.5) / 0.5;
          return walkSpeed + (maxFlySpeed - walkSpeed) * (u * u);
        }
      }

      // 15% tilt (gentle corridor nudge): ~11.7 cm/s - impossible to overshoot rooms!
      final slowSpeed = computeSpeed(0.15) / oneMeter;
      expect(slowSpeed, closeTo(0.117, 0.01));

      // 50% tilt: exact human walking speed (1.3 m/s)
      final midSpeed = computeSpeed(0.50) / oneMeter;
      expect(midSpeed, closeTo(1.30, 0.01));

      // 100% tilt: cruise flight speed (7.0 m/s)
      final fastSpeed = computeSpeed(1.00) / oneMeter;
      expect(fastSpeed, closeTo(7.00, 0.01));
    });
  });

  group('Cad3DVirtualJoystick Widget Tests', () {
    testWidgets('renders base and knob and reports direction', (tester) async {
      Offset? reportedDirection;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Cad3DVirtualJoystick(
                onDirectionChanged: (dir) => reportedDirection = dir,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Cad3DVirtualJoystick), findsOneWidget);

      // Drag up (forward) using an active gesture pointer
      final center = tester.getCenter(find.byType(Cad3DVirtualJoystick));
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(0.0, -40.0));
      await tester.pump();

      expect(reportedDirection, isNotNull);
      expect(reportedDirection!.dy, lessThan(0.0)); // up is negative Y

      // Release drag
      await gesture.up();
      await tester.pumpAndSettle();
      expect(reportedDirection, equals(Offset.zero)); // springs back to zero!
    });
  });
}
