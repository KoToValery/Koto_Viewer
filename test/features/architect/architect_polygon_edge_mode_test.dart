import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/services/architect_polygon_displacement.dart';
import 'package:kotoview/src/features/architect/services/architect_polygon_geometry.dart';

void main() {
  group('ArchitectPolygonEdgeMode - Segment Drag Behavior', () {
    const square = [
      Offset(0, 0),
      Offset(4, 0),
      Offset(4, 4),
      Offset(0, 4),
    ];

    test('ArchitectPolygonEdgeMode.move displaces existing vertices without creating new points', () {
      final moved = ArchitectPolygonGeometry.offsetEdge(
        square,
        0, // Bottom edge (0,0) -> (4,0)
        1.0,
        mode: ArchitectPolygonEdgeMode.move,
      );

      expect(moved, isNotNull);
      expect(moved!.length, equals(4), reason: 'Default move mode must not add new points');
    });

    test('ArchitectPolygonEdgeMode.pull creates 2 new vertices (extrusions)', () {
      final pulled = ArchitectPolygonGeometry.offsetEdge(
        square,
        0, // Bottom edge
        1.0,
        mode: ArchitectPolygonEdgeMode.pull,
      );

      expect(pulled, isNotNull);
      expect(pulled!.length, equals(6), reason: 'Pull mode creates 2 new vertices');
    });

    test('ArchitectPolygonDisplacement respects default move mode', () {
      final disp = ArchitectPolygonDisplacement.fromDrag(
        polygon: square,
        index: 0,
        edge: true,
        target: const Offset(2, -1),
        mode: ArchitectPolygonEdgeMode.move,
      );

      expect(disp, isNotNull);
      final result = disp!.atDistance(1.0);
      expect(result, isNotNull);
      expect(result!.length, equals(4));
    });
  });
}
