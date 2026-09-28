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

    test('switchToFlyMode sets fly mode and computes initial eyePosition', () {
      final camera = Cad3DCamera(yaw: 0.0, pitch: 0.0);
      const modelScale = 1.0;

      camera.switchToFlyMode(modelScale);
      expect(camera.mode, equals(Cad3DInteractionMode.fly));
      expect(camera.isFlyMode, isTrue);

      // With yaw=0, pitch=0, forward vector is (0, 1, 0)
      // Camera eye should be placed at -1200 along forward vector: (0, -1200, 0)
      expect(camera.eyePosition.x, closeTo(0.0, 1e-4));
      expect(camera.eyePosition.y, closeTo(-1200.0, 1e-4));
      expect(camera.eyePosition.z, closeTo(0.0, 1e-4));
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

    test('projectToScreen uses distance-based perspective in Fly mode', () {
      final camera = Cad3DCamera(yaw: 0.0, pitch: 0.0);
      camera.switchToFlyMode(1.0);

      const viewport = Size(800, 600);
      const modelScale = 1.0;

      // Vertex directly on line of sight at depth 1200
      final tv = const Vector3(0.0, 1200.0, 0.0);
      final screenOffset = camera.projectToScreen(tv, viewport, modelScale);

      expect(screenOffset.dx, closeTo(400.0, 1e-4)); // centered
      expect(screenOffset.dy, closeTo(300.0, 1e-4)); // centered
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
