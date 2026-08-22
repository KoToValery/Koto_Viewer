import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/models/coordinate_system.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_snap_helper.dart';

void main() {
  group('Coordinate System Detection & Country Coverage Tests', () {
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

    test('Detects Swiss Grid LV95 bounding box', () {
      const swissBounds = Rect.fromLTRB(2600000, 1200000, 2610000, 1205000);
      final crs = CoordinateSystem.detectFromBounds(swissBounds);
      expect(crs, CoordinateSystem.swissLv95);
    });

    test('Detects Greek Grid GGRS87 bounding box', () {
      const greekBounds = Rect.fromLTRB(470000, 4200000, 480000, 4210000);
      final crs = CoordinateSystem.detectFromBounds(greekBounds);
      expect(crs, CoordinateSystem.greeceGgrs87);
    });

    test('Detects Romanian Stereo 70 bounding box', () {
      const stereoBounds = Rect.fromLTRB(500000, 500000, 505000, 505000);
      final crs = CoordinateSystem.detectFromBounds(stereoBounds);
      expect(crs, CoordinateSystem.romaniaStereo70);
    });

    test('Detects Local / Non-projected coordinates', () {
      const localBounds = Rect.fromLTRB(0, 0, 150, 100);
      final crs = CoordinateSystem.detectFromBounds(localBounds);
      expect(crs, CoordinateSystem.localCartesian);
    });

    test('Contains official national systems across major countries with flags and EPSG', () {
      expect(CoordinateSystem.fromId('bgs_2005_cadastral').epsg, 'EPSG:7801');
      expect(CoordinateSystem.fromId('romania_stereo70').epsg, 'EPSG:31700');
      expect(CoordinateSystem.fromId('greece_ggrs87').epsg, 'EPSG:2100');
      expect(CoordinateSystem.fromId('germany_etrs89_utm32').epsg, 'EPSG:25832');
      expect(CoordinateSystem.fromId('france_rgf93_lambert93').epsg, 'EPSG:2154');
      expect(CoordinateSystem.fromId('uk_osgb36_bng').epsg, 'EPSG:27700');
      expect(CoordinateSystem.fromId('swiss_lv95').epsg, 'EPSG:2056');
      expect(CoordinateSystem.fromId('austria_mgi_gk').epsg, 'EPSG:31258');
      expect(CoordinateSystem.fromId('italy_monte_mario_1').epsg, 'EPSG:3003');
      expect(CoordinateSystem.fromId('spain_etrs89_utm30').epsg, 'EPSG:25830');
      expect(CoordinateSystem.fromId('poland_etrf2000_cs2000').epsg, 'EPSG:2177');
      expect(CoordinateSystem.fromId('czech_sjtsk_krovak').epsg, 'EPSG:5514');
      expect(CoordinateSystem.fromId('hungary_hd72_eov').epsg, 'EPSG:23700');
      expect(CoordinateSystem.fromId('netherlands_rd_new').epsg, 'EPSG:28992');
      expect(CoordinateSystem.fromId('belgium_lambert2008').epsg, 'EPSG:3812');
      expect(CoordinateSystem.fromId('serbia_mgi_zone7').epsg, 'EPSG:31277');
      expect(CoordinateSystem.fromId('macedonia_mgi_zone7').epsg, 'EPSG:6316');
      expect(CoordinateSystem.fromId('turkey_itrf96_tm30').epsg, 'EPSG:5256');
      expect(CoordinateSystem.fromId('croatia_htrs96_tm').epsg, 'EPSG:3765');
      expect(CoordinateSystem.fromId('slovenia_d96_tm').epsg, 'EPSG:3794');
      expect(CoordinateSystem.fromId('usa_nad83_spcs').country, 'United States');
      expect(CoordinateSystem.values.length, greaterThanOrEqualTo(20));
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
