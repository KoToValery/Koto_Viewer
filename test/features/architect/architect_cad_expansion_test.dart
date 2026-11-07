import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_roof.dart';
import 'package:kotoview/src/features/architect/services/architect_spline_geometry.dart';

void main() {
  group('1. Standalone CAD Arc', () {
    test('Constructs arc with bulge and computes correct radius and center', () {
      // Semicircle from (0, 0) to (10, 0) with bulge = 1.0 (radius = 5.0, center = (5, 0))
      const start = Offset(0, 0);
      const end = Offset(10, 0);
      const bulge = 1.0;

      final arcPrim = ArchitectCadPrimitive(
        id: 'arc-1',
        type: CadPrimitiveType.arc,
        startPoint: start,
        endPoint: end,
        arcBulge: bulge,
      );

      expect(arcPrim.isCurved, isTrue);
      expect(arcPrim.arc, isNotNull);
      expect((arcPrim.arc!.radius - 5.0).abs(), lessThan(1e-4));
      expect((arcPrim.arc!.center.dx - 5.0).abs(), lessThan(1e-4));
      expect((arcPrim.arc!.center.dy - 0.0).abs(), lessThan(1e-4));

      // JSON round-trip
      final json = arcPrim.toJson();
      final revived = ArchitectCadPrimitive.fromJson(json);
      expect(revived.id, equals('arc-1'));
      expect(revived.type, equals(CadPrimitiveType.arc));
      expect(revived.arcBulge, closeTo(1.0, 1e-6));
    });
  });

  group('2. Mask / Wipeout Contour', () {
    test('Constructs mask primitive and validates polygon corners and border', () {
      final poly = [
        const Offset(0, 0),
        const Offset(4, 0),
        const Offset(4, 3),
        const Offset(0, 3),
      ];

      final mask = ArchitectCadPrimitive(
        id: 'mask-1',
        type: CadPrimitiveType.mask,
        startPoint: poly.first,
        endPoint: poly.last,
        polygon: poly,
        maskBorder: true,
      );

      expect(mask.isPolygon, isTrue);
      expect(mask.polygonCorners.length, equals(4));
      expect(mask.maskBorder, isTrue);

      final json = mask.toJson();
      final revived = ArchitectCadPrimitive.fromJson(json);
      expect(revived.id, equals('mask-1'));
      expect(revived.type, equals(CadPrimitiveType.mask));
      expect(revived.maskBorder, isTrue);
      expect(revived.polygon!.length, equals(4));
    });
  });

  group('3. Multileader Annotation', () {
    test('Constructs multileader with arrow, landing, note, and style', () {
      const arrowPoint = Offset(1.0, 2.0);
      const landingPoint = Offset(3.0, 4.0);

      final leader = ArchitectAnnotation(
        id: 'mleader-1',
        position: landingPoint,
        text: 'Detail A: 200mm RC wall with 100mm mineral wool',
        hasLeader: true,
        leaderArrowPoint: arrowPoint,
        leaderLandingPoint: landingPoint,
        leaderArrowStyle: ArchitectLineEndCap.arrowFilled,
        leaderArrowSize: 0.25,
        leaderLandingLength: 0.40,
      );

      expect(leader.hasLeader, isTrue);
      expect(leader.leaderArrowPoint, equals(arrowPoint));
      expect(leader.leaderLandingPoint, equals(landingPoint));
      expect(leader.leaderArrowStyle, equals(ArchitectLineEndCap.arrowFilled));
      expect(leader.leaderArrowSize, equals(0.25));
      expect(leader.leaderLandingLength, equals(0.40));

      final json = leader.toJson();
      final revived = ArchitectAnnotation.fromJson(json);
      expect(revived.id, equals('mleader-1'));
      expect(revived.hasLeader, isTrue);
      expect(revived.leaderArrowPoint, equals(arrowPoint));
      expect(revived.leaderArrowStyle, equals(ArchitectLineEndCap.arrowFilled));
      expect(revived.leaderArrowSize, equals(0.25));
      expect(revived.leaderLandingLength, equals(0.40));
    });
  });

  group('4. Advanced Polyline with Mixed Arc Segments & Width', () {
    test('Stores per-segment bulges and customWidth with roundtrip', () {
      final points = [
        const Offset(0, 0),
        const Offset(5, 0),
        const Offset(5, 5),
        const Offset(0, 5),
      ];
      // Segment 0 straight (0.0), segment 1 curved (0.414 = 90 deg arc), segment 2 straight (0.0)
      final bulges = [0.0, 0.41421356, 0.0];

      final polyline = ArchitectCadPrimitive(
        id: 'poly-1',
        type: CadPrimitiveType.polyline,
        startPoint: points.first,
        endPoint: points.last,
        polygon: points,
        bulges: bulges,
        customWidth: 0.15,
      );

      expect(polyline.bulges, equals(bulges));
      expect(polyline.customWidth, equals(0.15));

      final json = polyline.toJson();
      final revived = ArchitectCadPrimitive.fromJson(json);
      expect(revived.id, equals('poly-1'));
      expect(revived.type, equals(CadPrimitiveType.polyline));
      expect(revived.bulges, equals(bulges));
      expect(revived.customWidth, equals(0.15));
    });
  });

  group('5. Spline Geometry and Catmull-Rom Bezier Spline', () {
    test('Interpolates Catmull-Rom cubic Bezier curves through fit points', () {
      final fitPoints = [
        const Offset(0, 0),
        const Offset(3, 2),
        const Offset(6, 1),
        const Offset(10, 4),
      ];

      final path = ArchitectSplineGeometry.generatePath(fitPoints);
      expect(path, isNotNull);

      final samples = ArchitectSplineGeometry.samplePoints(fitPoints);
      expect(samples.length, greaterThan(fitPoints.length));
      expect((samples.first - fitPoints.first).distance, lessThan(1e-4));
      expect((samples.last - fitPoints.last).distance, lessThan(1e-4));

      // Hit testing along spline
      final sampleOnCurve = samples[samples.length ~/ 2];
      final distOnCurve = ArchitectSplineGeometry.distanceToPoint(fitPoints, sampleOnCurve);
      expect(distOnCurve, lessThan(1e-4));

      final distFar = ArchitectSplineGeometry.distanceToPoint(fitPoints, const Offset(0, 50));
      expect(distFar, greaterThan(10.0));

      // JSON roundtrip
      final splinePrim = ArchitectCadPrimitive(
        id: 'spline-1',
        type: CadPrimitiveType.spline,
        startPoint: fitPoints.first,
        endPoint: fitPoints.last,
        polygon: fitPoints,
      );
      final json = splinePrim.toJson();
      final revived = ArchitectCadPrimitive.fromJson(json);
      expect(revived.id, equals('spline-1'));
      expect(revived.type, equals(CadPrimitiveType.spline));
      expect(revived.polygon!.length, equals(4));
    });
  });

  group('6. Ellipse and Elliptical Arc', () {
    test('Constructs ellipse with radii, rotation and angles', () {
      final ellipse = ArchitectCadPrimitive(
        id: 'ellipse-1',
        type: CadPrimitiveType.ellipse,
        startPoint: const Offset(-4, -2),
        endPoint: const Offset(4, 2),
        radiusX: 4.0,
        radiusY: 2.0,
        rotationDeg: 30.0,
        isArc: true,
        startAngleDeg: 0.0,
        endAngleDeg: 180.0,
      );

      expect(ellipse.radiusX, equals(4.0));
      expect(ellipse.radiusY, equals(2.0));
      expect(ellipse.rotationDeg, equals(30.0));
      expect(ellipse.isArc, isTrue);
      expect(ellipse.startAngleDeg, equals(0.0));
      expect(ellipse.endAngleDeg, equals(180.0));

      final json = ellipse.toJson();
      final revived = ArchitectCadPrimitive.fromJson(json);
      expect(revived.id, equals('ellipse-1'));
      expect(revived.type, equals(CadPrimitiveType.ellipse));
      expect(revived.radiusX, equals(4.0));
      expect(revived.radiusY, equals(2.0));
      expect(revived.rotationDeg, equals(30.0));
      expect(revived.isArc, isTrue);
      expect(revived.startAngleDeg, equals(0.0));
      expect(revived.endAngleDeg, equals(180.0));
    });
  });

  group('7. Roof Slope Arrow', () {
    test('Constructs slope arrow, formats slope, and attaches to roof plane', () {
      final arrow = ArchitectRoofSlopeArrow(
        id: 'slope-1',
        roofPlaneId: 'plane-1',
        position: const Offset(5.0, 5.0),
        format: RoofSlopeFormat.both,
        direction: RoofSlopeDirection.downslope,
      );

      expect(arrow.format, equals(RoofSlopeFormat.both));
      expect(arrow.direction, equals(RoofSlopeDirection.downslope));

      final plane = ArchitectRoofPlane(
        id: 'plane-1',
        storeyId: 'storey-1',
        points: [
          const Offset(0, 0),
          const Offset(10, 0),
          const Offset(10, 8),
          const Offset(0, 8),
        ],
        slopeDegrees: 25.0,
        slopeArrows: [arrow],
      );

      expect(plane.slopeArrows.length, equals(1));
      expect(plane.containsPoint(const Offset(5, 5)), isTrue);
      expect(plane.containsPoint(const Offset(20, 20)), isFalse);

      // Verify slope formatting
      expect(plane.formatSlope(RoofSlopeFormat.percent), contains('%'));
      expect(plane.formatSlope(RoofSlopeFormat.degree), contains('°'));
      expect(plane.formatSlope(RoofSlopeFormat.both), contains('%'));
      expect(plane.formatSlope(RoofSlopeFormat.both), contains('°'));

      final json = plane.toJson();
      final revived = ArchitectRoofPlane.fromJson(json);
      expect(revived.slopeArrows.length, equals(1));
      expect(revived.slopeArrows.first.id, equals('slope-1'));
      expect(revived.slopeArrows.first.format, equals(RoofSlopeFormat.both));
    });
  });

  group('8. Line Options: Terminating End Caps & Curved Line', () {
    test('Line with arrow/dot end caps and cap size roundtrip', () {
      final lineWithCaps = ArchitectCadPrimitive(
        id: 'line-caps-1',
        type: CadPrimitiveType.line,
        startPoint: const Offset(0, 0),
        endPoint: const Offset(10, 0),
        startCap: ArchitectLineEndCap.dotFilled,
        endCap: ArchitectLineEndCap.arrowFilled,
        capSize: 0.25,
      );

      expect(lineWithCaps.startCap, equals(ArchitectLineEndCap.dotFilled));
      expect(lineWithCaps.endCap, equals(ArchitectLineEndCap.arrowFilled));
      expect(lineWithCaps.capSize, equals(0.25));

      final json = lineWithCaps.toJson();
      final revived = ArchitectCadPrimitive.fromJson(json);
      expect(revived.startCap, equals(ArchitectLineEndCap.dotFilled));
      expect(revived.endCap, equals(ArchitectLineEndCap.arrowFilled));
      expect(revived.capSize, equals(0.25));
    });

    test('Curved CAD line with bulge computes arc and preserves end caps', () {
      // Curved line curving by 45 degrees
      final bulge = math.tan(45 * math.pi / 180 / 4);
      final curvedLine = ArchitectCadPrimitive(
        id: 'curved-line-1',
        type: CadPrimitiveType.line,
        startPoint: const Offset(0, 0),
        endPoint: const Offset(8, 0),
        arcBulge: bulge,
        startCap: ArchitectLineEndCap.none,
        endCap: ArchitectLineEndCap.arrowOpen,
      );

      expect(curvedLine.isCurved, isTrue);
      expect(curvedLine.arc, isNotNull);
      expect(curvedLine.endCap, equals(ArchitectLineEndCap.arrowOpen));

      final json = curvedLine.toJson();
      final revived = ArchitectCadPrimitive.fromJson(json);
      expect(revived.isCurved, isTrue);
      expect(revived.arcBulge, closeTo(bulge, 1e-6));
      expect(revived.endCap, equals(ArchitectLineEndCap.arrowOpen));
    });
  });
}
