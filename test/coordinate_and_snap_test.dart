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

    test('DxfLayer isThick defaults to false and can be toggled', () {
      final layer = DxfLayer(name: 'Parcels');
      expect(layer.isThick, isFalse);

      layer.isThick = true;
      expect(layer.isThick, isTrue);

      final copy = layer.copyWith(isThick: false);
      expect(copy.isThick, isFalse);
    });
  });
}
