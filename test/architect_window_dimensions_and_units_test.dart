import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';

class _RecordingCanvas implements Canvas {
  final List<(Offset, double)> circles = [];
  final List<(Offset, Offset)> lines = [];
  final List<String> drawnTexts = [];

  @override
  void drawCircle(Offset c, double radius, Paint paint) {
    circles.add((c, radius));
  }

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    lines.add((p1, p2));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('Architectural Unit & Dimension Enhancements', () {
    test('BimDistanceUnit.trimZeros correctly strips trailing zeroes after decimal point', () {
      expect(BimDistanceUnit.trimZeros('12.00'), '12');
      expect(BimDistanceUnit.trimZeros('140.0'), '140');
      expect(BimDistanceUnit.trimZeros('85.0'), '85');
      expect(BimDistanceUnit.trimZeros('12.50'), '12.5');
      expect(BimDistanceUnit.trimZeros('12.55'), '12.55');
      expect(BimDistanceUnit.trimZeros('0.00'), '0');
      expect(BimDistanceUnit.trimZeros('-0.00'), '0');
      expect(BimDistanceUnit.trimZeros('100'), '100');
      expect(BimDistanceUnit.trimZeros('200'), '200');
    });

    test('Zone Area is strictly m² for all metric linear units (m, cm, mm)', () {
      for (final unit in [
        BimDistanceUnit.meters,
        BimDistanceUnit.centimeters,
        BimDistanceUnit.millimeters,
      ]) {
        final scope = ArchitectTextScope(
          const ArchitectDocument(),
          'plan',
          100,
          1.0,
          units: unit,
        );
        // 44.1325 m² -> 44.13 m²
        expect(scope.area(44.1325), '44.13 m²');
        // 44.00 m² -> 44 m² (trailing zeros stripped)
        expect(scope.area(44.00), '44 m²');
        // 12.00 m² -> 12 m²
        expect(scope.area(12.00), '12 m²');
      }
    });

    test('Zone Area is sq ft for imperial linear units (ft, in)', () {
      for (final unit in [BimDistanceUnit.feet, BimDistanceUnit.inches]) {
        final scope = ArchitectTextScope(
          const ArchitectDocument(),
          'plan',
          100,
          1.0,
          units: unit,
        );
        // 44.13 m² is approx 475.01 sq ft
        final areaStr = scope.area(44.13);
        expect(areaStr, contains('sq ft'));
        expect(areaStr, isNot(contains('.00')));
      }
    });

    test('Window dimensions and ID badge are placed on the exterior side', () {
      // Wall horizontal along X: from (10, 10) to (0, 10) (running leftwards, clockwise bottom wall)
      // Tangent u = (-1, 0), normal n = (0, -1) (points UP / interior)
      // When exteriorSign = -1, exteriorNormal = (0, 1) (points DOWN / exterior)
      const wallStart = Offset(10, 10);
      const wallEnd = Offset(0, 10);
      const wallThickness = 0.25;

      const window = ArchitectWindow(
        id: 'win1',
        uuid: 'UUID-WIN1',
        wallId: 'w_bottom',
        offsetRatio: 0.5, // at (5, 10)
        width: 1.4,
        height: 1.2,
        sillHeight: 0.85,
        specId: 'W1',
      );

      final canvas = _RecordingCanvas();
      window.paint2D(
        canvas: canvas,
        wallStart: wallStart,
        wallEnd: wallEnd,
        wallThickness: wallThickness,
        zoomScale: 100,
        exteriorSign: -1.0, // Exterior is at Y > 10 (DOWN)
      );

      // The ID badge circle must be on the exterior side (Y > 10)
      expect(canvas.circles, isNotEmpty);
      final badgeCenter = canvas.circles.first.$1;
      expect(badgeCenter.dy, greaterThan(10.0 + wallThickness / 2));

      // Window containsPoint must hit the badge on the exterior side
      expect(
        window.containsPoint(
          badgeCenter,
          wallStart: wallStart,
          wallEnd: wallEnd,
          wallThickness: wallThickness,
          exteriorSign: -1.0,
        ),
        isTrue,
      );

      // A point on the interior side (Y < 10) where the badge used to be should NOT hit the badge
      final interiorPoint = Offset(5, 10 - (badgeCenter.dy - 10));
      expect(
        window.containsPoint(
          interiorPoint,
          wallStart: wallStart,
          wallEnd: wallEnd,
          wallThickness: wallThickness,
          exteriorSign: -1.0,
        ),
        isFalse,
      );
    });
  });
}
