import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/dxf_viewer/rendering/dxf_snap_helper.dart';
import 'package:kotoview/src/features/structural_designer/analysis/structural_measurement_snap.dart';

void main() {
  final document = DxfDocument.empty();
  const edge = (Offset(0, 0), Offset(10, 0));
  test('BIM endpoints, midpoints and nearest edge points use viewer snaps', () {
    for (final (raw, expected, type) in [
      (const Offset(.05, .05), Offset.zero, DxfSnapType.endpoint),
      (const Offset(5.05, .05), const Offset(5, 0), DxfSnapType.midpoint),
      (const Offset(3, .05), const Offset(3, 0), DxfSnapType.nearest),
    ]) {
      final result = StructuralMeasurementSnap.find(
        document: document,
        raw: raw,
        tolerance: .1,
        edges: [edge],
      );
      expect(result.snap?.point, expected);
      expect(result.snap?.type, type);
    }
  });
  test('perpendicular foot stays exact on a rotated BIM edge', () {
    final result = StructuralMeasurementSnap.find(
      document: document,
      raw: const Offset(4.04, 3.98),
      start: const Offset(2, 6),
      tolerance: .1,
      edges: [(Offset.zero, const Offset(10, 10))],
    );
    expect(result.snap?.point, const Offset(4, 4));
    expect(result.snap?.type, DxfSnapType.perpendicular);
    expect(result.guides, hasLength(2));
  });
  test('tracks parallel to a rotated reference edge from the first point', () {
    final result = StructuralMeasurementSnap.find(
      document: document,
      raw: const Offset(6, 8.05),
      start: const Offset(2, 4),
      tolerance: .1,
      edges: [(const Offset(2, 4), const Offset(3, 5))],
    );
    final direction = result.snap!.point - const Offset(2, 4);
    expect(direction.dx, closeTo(direction.dy, 1e-9));
    expect(result.guides, hasLength(2));
  });
  test('captures crossings between CAD and BIM edges', () {
    final cad = DxfDocument(
      layers: const {},
      blocks: const {},
      headerVars: const {},
      bounds: const Rect.fromLTWH(0, 0, 10, 10),
      entityStats: const {},
      entities: const [DxfLine(p1: Offset(3, -5), p2: Offset(3, 5))],
    );
    final result = StructuralMeasurementSnap.find(
      document: cad,
      raw: const Offset(3.03, .04),
      tolerance: .1,
      edges: [edge],
    );
    expect(result.snap?.point, const Offset(3, 0));
    expect(result.snap?.type, DxfSnapType.intersection);
  });
  test('exact endpoints win over directional tracking', () {
    final result = StructuralMeasurementSnap.find(
      document: document,
      raw: const Offset(.05, .05),
      start: const Offset(-3, .05),
      tolerance: .1,
      edges: [edge],
    );
    expect(result.snap?.point, Offset.zero);
    expect(result.snap?.type, DxfSnapType.endpoint);
  });
  test('points outside the capture distance stay unsnapped', () {
    final result = StructuralMeasurementSnap.find(
      document: document,
      raw: const Offset(3, 2),
      tolerance: .1,
      edges: [edge],
    );
    expect(result.snap, isNull);
  });
}
