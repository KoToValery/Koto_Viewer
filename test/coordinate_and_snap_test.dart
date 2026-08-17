import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/models/coordinate_system.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_snap_helper.dart';

void main() {
  group('Coordinate System Detection Tests', () {
    test('Detects BGS 2005 Cadastral bounding box', () {
      const bgsBounds = Rect.fromLTRB(4750000, 8550000, 4752000, 8553000);
      final crs = CoordinateSystem.detectFromBounds(bgsBounds);
      expect(crs, CoordinateSystem.bgs2005Cadastral);
    });

    test('Detects BGS 2005 UTM 35N bounding box', () {
      const utmBounds = Rect.fromLTRB(320000, 4680000, 325000, 4685000);
      final crs = CoordinateSystem.detectFromBounds(utmBounds);
      expect(crs, CoordinateSystem.bgs2005Utm35n);
    });

    test('Detects WGS84 GPS Latitude/Longitude coordinates', () {
      const wgsBounds = Rect.fromLTRB(23.3, 42.6, 23.4, 42.7);
      final crs = CoordinateSystem.detectFromBounds(wgsBounds);
      expect(crs, CoordinateSystem.wgs84Geo);
    });

    test('Detects Local / Non-projected coordinates', () {
      const localBounds = Rect.fromLTRB(0, 0, 150, 100);
      final crs = CoordinateSystem.detectFromBounds(localBounds);
      expect(crs, CoordinateSystem.localCartesian);
    });
  });

  group('CAD Snap Helper Tests', () {
    test('Snaps to line endpoints, midpoint, and circle center', () {
      final doc = DxfDocument(
        layers: {'0': DxfLayer(name: '0')},
        blocks: {},
        entities: [
          const DxfLine(
            p1: Offset(100.0, 200.0),
            p2: Offset(200.0, 200.0),
          ),
          const DxfCircle(
            center: Offset(300.0, 300.0),
            radius: 50.0,
          ),
        ],
        headerVars: {},
        bounds: const Rect.fromLTRB(100, 200, 350, 350),
        entityStats: {'LINE': 1, 'CIRCLE': 1},
      );

      // 1. Snap to endpoint (100, 200)
      final snap1 = DxfSnapHelper.findSnapPoint(
        document: doc,
        cadPoint: const Offset(102.0, 199.0),
        toleranceCad: 10.0,
      );
      expect(snap1, isNotNull);
      expect(snap1!.point, const Offset(100.0, 200.0));
      expect(snap1.type, DxfSnapType.endpoint);

      // 2. Snap to midpoint (150, 200)
      final snap2 = DxfSnapHelper.findSnapPoint(
        document: doc,
        cadPoint: const Offset(151.0, 201.0),
        toleranceCad: 10.0,
      );
      expect(snap2, isNotNull);
      expect(snap2!.point, const Offset(150.0, 200.0));
      expect(snap2.type, DxfSnapType.midpoint);

      // 3. Snap to circle center (300, 300)
      final snap3 = DxfSnapHelper.findSnapPoint(
        document: doc,
        cadPoint: const Offset(298.0, 301.0),
        toleranceCad: 10.0,
      );
      expect(snap3, isNotNull);
      expect(snap3!.point, const Offset(300.0, 300.0));
      expect(snap3.type, DxfSnapType.center);

      // 4. Far query outside tolerance
      final snap4 = DxfSnapHelper.findSnapPoint(
        document: doc,
        cadPoint: const Offset(500.0, 500.0),
        toleranceCad: 10.0,
      );
      expect(snap4, isNull);
    });

    test('Snaps to arbitrary position along a line segment (Nearest / On Segment)', () {
      final doc = DxfDocument(
        layers: {'0': DxfLayer(name: '0')},
        blocks: {},
        entities: [
          const DxfLine(
            p1: Offset(100.0, 200.0),
            p2: Offset(200.0, 200.0),
          ),
          const DxfLine(
            p1: Offset(0.0, 0.0),
            p2: Offset(100.0, 100.0),
          ),
        ],
        headerVars: {},
        bounds: const Rect.fromLTRB(0, 0, 200, 200),
        entityStats: {'LINE': 2},
      );

      // Snap at arbitrary position on horizontal line (x=125, away from midpoint 150 and endpoint 100)
      final snapHorizontal = DxfSnapHelper.findSnapPoint(
        document: doc,
        cadPoint: const Offset(125.0, 203.0),
        toleranceCad: 10.0,
      );
      expect(snapHorizontal, isNotNull);
      expect(snapHorizontal!.point.dx, closeTo(125.0, 1e-4));
      expect(snapHorizontal.point.dy, closeTo(200.0, 1e-4));
      expect(snapHorizontal.type, DxfSnapType.nearest);

      // Snap at arbitrary position on diagonal line (x=30, y=30)
      final snapDiag = DxfSnapHelper.findSnapPoint(
        document: doc,
        cadPoint: const Offset(31.0, 29.0),
        toleranceCad: 10.0,
      );
      expect(snapDiag, isNotNull);
      expect(snapDiag!.point.dx, closeTo(30.0, 1e-4));
      expect(snapDiag.point.dy, closeTo(30.0, 1e-4));
      expect(snapDiag.type, DxfSnapType.nearest);
    });

    test('Snaps to arbitrary point on circle and arc curves', () {
      final doc = DxfDocument(
        layers: {'0': DxfLayer(name: '0')},
        blocks: {},
        entities: [
          const DxfCircle(
            center: Offset(100.0, 100.0),
            radius: 50.0,
          ),
        ],
        headerVars: {},
        bounds: const Rect.fromLTRB(50, 50, 150, 150),
        entityStats: {'CIRCLE': 1},
      );

      // Snap onto circle circumference at top (100, 150)
      final snapCircleTop = DxfSnapHelper.findSnapPoint(
        document: doc,
        cadPoint: const Offset(100.0, 152.0),
        toleranceCad: 10.0,
      );
      expect(snapCircleTop, isNotNull);
      expect(snapCircleTop!.point.dx, closeTo(100.0, 1e-4));
      expect(snapCircleTop.point.dy, closeTo(150.0, 1e-4));
      expect(snapCircleTop.type, DxfSnapType.nearest);
    });

    test('DxfSnapHelper geometric projection helper tests', () {
      // 1. Point projection onto line segment
      final pOnSeg = DxfSnapHelper.closestPointOnSegment(
        const Offset(50.0, 10.0),
        const Offset(0.0, 0.0),
        const Offset(100.0, 0.0),
      );
      expect(pOnSeg, const Offset(50.0, 0.0));

      // 2. Point clamped to segment start/end
      final pClamped = DxfSnapHelper.closestPointOnSegment(
        const Offset(150.0, 10.0),
        const Offset(0.0, 0.0),
        const Offset(100.0, 0.0),
      );
      expect(pClamped, const Offset(100.0, 0.0));

      // 3. Point projection on circle
      final pCircle = DxfSnapHelper.closestPointOnCircle(
        const Offset(100.0, 200.0),
        const Offset(100.0, 100.0),
        50.0,
      );
      expect(pCircle, const Offset(100.0, 150.0));
    });

    test('Snaps to Perpendicular (Right Angle 90°) point on a line segment given basePoint', () {
      final doc = DxfDocument(
        layers: {'0': DxfLayer(name: '0')},
        blocks: {},
        entities: [
          // Horizontal line from (0, 200) to (300, 200)
          const DxfLine(
            p1: Offset(0.0, 200.0),
            p2: Offset(300.0, 200.0),
          ),
          // Diagonal line from (0, 0) to (200, 200)
          const DxfLine(
            p1: Offset(0.0, 0.0),
            p2: Offset(200.0, 200.0),
          ),
        ],
        headerVars: {},
        bounds: const Rect.fromLTRB(0, 0, 300, 200),
        entityStats: {'LINE': 2},
      );

      // 1. Measuring from P1(120, 50) towards the horizontal line at y=200
      // The perpendicular foot is at (120, 200)
      final snapPerpHoriz = DxfSnapHelper.findSnapPoint(
        document: doc,
        cadPoint: const Offset(122.0, 198.0),
        toleranceCad: 10.0,
        basePoint: const Offset(120.0, 50.0),
      );
      expect(snapPerpHoriz, isNotNull);
      expect(snapPerpHoriz!.point.dx, closeTo(120.0, 1e-4));
      expect(snapPerpHoriz.point.dy, closeTo(200.0, 1e-4));
      expect(snapPerpHoriz.type, DxfSnapType.perpendicular);

      // 2. Measuring from P1(0, 100) towards the diagonal line (0,0)->(200,200)
      // The perpendicular foot is at (50, 50)
      final snapPerpDiag = DxfSnapHelper.findSnapPoint(
        document: doc,
        cadPoint: const Offset(51.0, 49.0),
        toleranceCad: 10.0,
        basePoint: const Offset(0.0, 100.0),
      );
      expect(snapPerpDiag, isNotNull);
      expect(snapPerpDiag!.point.dx, closeTo(50.0, 1e-4));
      expect(snapPerpDiag.point.dy, closeTo(50.0, 1e-4));
      expect(snapPerpDiag.type, DxfSnapType.perpendicular);
    });

    test('DxfLayer isThick defaults to false and can be toggled', () {
      final layer = DxfLayer(name: 'Parcels');
      expect(layer.isThick, isFalse);

      layer.isThick = true;
      expect(layer.isThick, isTrue);

      final copy = layer.copyWith(isThick: false);
      expect(copy.isThick, isFalse);
    });

    test('DxfLayer supports AutoCAD customLineweight (Original, 0.12mm, 0.25mm, 0.35mm, 0.70mm)', () {
      final layer = DxfLayer(name: 'Walls', lineweight: 0.35);
      expect(layer.customLineweight, isNull);
      expect(layer.lineweight, 0.35);

      // Set to 0.12 mm
      layer.customLineweight = 0.12;
      expect(layer.customLineweight, 0.12);

      // Set to 0.70 mm
      layer.customLineweight = 0.70;
      expect(layer.customLineweight, 0.70);
      expect(layer.isThick, isTrue);

      // Revert to Original (null)
      layer.customLineweight = null;
      expect(layer.customLineweight, isNull);
    });
  });
}
