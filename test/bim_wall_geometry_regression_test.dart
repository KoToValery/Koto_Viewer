import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/structural_designer/analysis/wall_axis_detector.dart';
import 'wall_pen_and_stair_rejection_test.dart' as f;
import 'package:kotoview/src/features/structural_designer/analysis/structural_column_detector.dart';

void main() {
  test(
    'new package walls reject treads and chimney alignment on both levels',
    () {
      // Original wall primitives and compact closed tread outlines, in cm.
      final data =
          jsonDecode(
                File(
                  'test/fixtures/bim_oct11_wall_detection.json',
                ).readAsStringSync(),
              )
              as Map;
      final axes = <List<(Offset, Offset)>>[];
      for (final raw in data.values) {
        final entities = <DxfEntity>[];
        for (final v in raw as List) {
          final points = (v['points'] as List)
              .map(
                (p) =>
                    Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
              )
              .toList();
          entities.add(
            points.length == 2 && v['closed'] != true
                ? DxfLine(
                    p1: points.first,
                    p2: points.last,
                    layer: v['layer'],
                    lineWeight: (v['pen'] as num).toDouble(),
                  )
                : DxfLwPolyline(
                    vertices: points
                        .map((p) => DxfPolylineVertex(x: p.dx, y: p.dy))
                        .toList(),
                    isClosed: v['closed'] == true,
                    layer: v['layer'],
                    lineWeight: (v['pen'] as num).toDouble(),
                  ),
          );
        }
        final d = f.doc(
          entities,
          layers: {
            'стени': DxfLayer(name: 'стени'),
            'стълби': DxfLayer(name: 'стълби'),
          },
        );
        final r = WallAxisDetector.detect(d, forceScaleFactor: .1);
        expect(
          r.detectedColumns.where((c) => c.sourceLayer == 'стълби'),
          isEmpty,
        );
        expect(
          r.snappedCenterlines.any(
            (a) =>
                (a.$1.dy - a.$2.dy).abs() < .01 &&
                (a.$1.dy - 231.154).abs() < .1,
          ),
          isFalse,
        );
        expect(
          r.snappedCenterlines.any(
            (a) =>
                (a.$1.dx - a.$2.dx).abs() < .01 &&
                (a.$1.dx + 636.077).abs() < .1,
          ),
          isFalse,
        );
        axes.add(r.snappedCenterlines);
      }
      for (final level in axes) {
        expect(
          level.where(
            (a) =>
                (a.$1.dx - a.$2.dx).abs() < .01 &&
                (a.$1.dx + 634.827).abs() < .1,
          ),
          hasLength(1),
        );
      }
    },
  );
  test('thin closed treads cannot return through the column detector', () {
    DxfLwPolyline rectangle(double x, double pen) => DxfLwPolyline(
      layer: 'columns',
      lineWeight: pen,
      isClosed: true,
      vertices: [
        DxfPolylineVertex(x: x, y: 0),
        DxfPolylineVertex(x: x + 280, y: 0),
        DxfPolylineVertex(x: x + 280, y: 900),
        DxfPolylineVertex(x: x, y: 900),
      ],
    );
    final d = f.doc(
      [...f.pair(0, pen: .30), rectangle(500, .13), rectangle(1500, .30)],
      layers: {
        'plan': DxfLayer(name: 'plan'),
        'columns': DxfLayer(name: 'columns'),
      },
    );
    final r = WallAxisDetector.detect(d, forceScaleFactor: 1);
    expect(r.detectedColumns, hasLength(1));
    expect(r.detectedColumns.single.bounds.left, 1500);
    expect(
      StructuralColumnDetector.detect(
        d,
        wallPairs: r.selectedWallPairs,
        scale: 1,
      ).map((c) => c.bounds.left),
      [1500],
    );
    expect(
      r.wallContourSegments.any((s) => s.$1 == const Offset(500, 900)),
      isFalse,
    );
  });
  test('a short offset jamb does not displace the main wall axis', () {
    final d = f.doc([
      ...f.pair(0, pen: .30),
      const DxfLine(
        p1: Offset(4100, 25),
        p2: Offset(4230, 25),
        layer: 'plan',
        lineWeight: .30,
      ),
      const DxfLine(
        p1: Offset(4100, 275),
        p2: Offset(4230, 275),
        layer: 'plan',
        lineWeight: .30,
      ),
    ]);
    final r = WallAxisDetector.detect(d, forceScaleFactor: 1);
    expect(r.snappedCenterlines, hasLength(1));
    expect(r.snappedCenterlines.single.$1.dy, closeTo(125, .01));
    expect(r.snappedCenterlines.single.$2.dy, closeTo(125, .01));
  });
  test(
    'compact unhatched shaft remains a contour but cannot create a grid axis',
    () {
      final d = f.doc([
        ...f.pair(0, pen: .30),
        const DxfLine(
          p1: Offset(600, 2000),
          p2: Offset(800, 2000),
          layer: 'plan',
          lineWeight: .30,
        ),
        const DxfLine(
          p1: Offset(600, 2250),
          p2: Offset(800, 2250),
          layer: 'plan',
          lineWeight: .30,
        ),
      ]);
      final r = WallAxisDetector.detect(d, forceScaleFactor: 1);
      expect(r.selectedWallPairs, hasLength(2));
      expect(r.snappedCenterlines, hasLength(1));
      expect(r.wallContourSegments.any((s) => s.$1.dy >= 2000), isTrue);
    },
  );
  test('nearby perpendicular wall does not suppress the door jamb cap', () {
    final d = f.doc([
      ...f.pair(0, pen: .30),
      const DxfLine(
        p1: Offset(4250, 0),
        p2: Offset(4250, 3000),
        layer: 'plan',
        lineWeight: .30,
      ),
      const DxfLine(
        p1: Offset(4500, 0),
        p2: Offset(4500, 3000),
        layer: 'plan',
        lineWeight: .30,
      ),
    ]);
    final r = WallAxisDetector.detect(d, forceScaleFactor: 1);
    expect(
      r.closureSegments.any(
        (s) =>
            (s.$1 - const Offset(4000, 0)).distance < 1 &&
                (s.$2 - const Offset(4000, 250)).distance < 1 ||
            (s.$2 - const Offset(4000, 0)).distance < 1 &&
                (s.$1 - const Offset(4000, 250)).distance < 1,
      ),
      isTrue,
    );
  });
}
