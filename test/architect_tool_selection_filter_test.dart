import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_zone.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/services/architect_element_tool.dart';

void main() {
  group('ArchitectTool Selection Scoping Tests', () {
    final tool = ArchitectElementTool();

    // Wall is positioned outside the slab/roof/zone rectangle [1..10, 1..10]
    final wall = ArchitectWall(
      id: 'w1',
      startPoint: const Offset(1, -2),
      endPoint: const Offset(9, -2),
      thickness: 0.25,
      height: 2.8,
    );

    final slab = ArchitectSlab(
      id: 's1',
      polygon: const [
        Offset(1, 1),
        Offset(9, 1),
        Offset(9, 9),
        Offset(1, 9),
      ],
      thickness: 0.20,
    );

    final zone = ArchitectZone(
      id: 'z1',
      name: 'Living Room',
      category: ArchitectZoneCategory.living,
      polygon: const [
        Offset(1, 1),
        Offset(9, 1),
        Offset(9, 9),
        Offset(1, 9),
      ],
    );

    final roof = ArchitectRoofPlane(
      id: 'r1',
      storeyId: 'st1',
      points: const [
        Offset(1, 1),
        Offset(9, 1),
        Offset(9, 9),
        Offset(1, 9),
      ],
      slopeDegrees: 25.0,
    );

    final column = ArchitectColumn(
      id: 'col1',
      position: const Offset(5, 5),
      width: 0.3,
      depth: 0.3,
    );

    final dimension = ArchitectDimension(
      id: 'dim1',
      startPoint: const Offset(1, -5),
      endPoint: const Offset(9, -5),
      offsetDistance: 0.5,
    );

    final storey = ArchitectStorey(
      id: 'st1',
      name: 'Ground Floor',
      elevation: 0,
      height: 2.8,
      walls: [wall],
      slabs: [slab],
      zones: [zone],
      roofs: [roof],
      columns: [column],
      dimensions: [dimension],
    );

    test('Dimension tool only hits dimensions, not walls, slabs, roofs, zones, or columns', () {
      // Point on the dimension line (at y = -4.5)
      final dimHit = tool.hitTestForTool(
        storey,
        const Offset(5, -4.5),
        100.0,
        ArchitectTool.dimension,
      );
      expect(dimHit, equals('dim1'));

      // Point inside zone, slab, roof (Offset(5, 5)) - must NOT hit zone, slab, column, or roof
      final insideHit = tool.hitTestForTool(
        storey,
        const Offset(5, 5),
        100.0,
        ArchitectTool.dimension,
      );
      expect(insideHit, isNull);

      // Point on wall (Offset(5, -2)) - must NOT hit wall
      final wallHit = tool.hitTestForTool(
        storey,
        const Offset(5, -2),
        100.0,
        ArchitectTool.dimension,
      );
      expect(wallHit, isNull);
    });

    test('Wall tool only hits walls, not slabs, roofs, zones, or dimensions', () {
      final wallHit = tool.hitTestForTool(
        storey,
        const Offset(5, -2),
        100.0,
        ArchitectTool.wall,
      );
      expect(wallHit, equals('w1'));

      final slabHit = tool.hitTestForTool(
        storey,
        const Offset(5, 5),
        100.0,
        ArchitectTool.wall,
      );
      expect(slabHit, isNull);
    });

    test('Slab tool only hits slabs, not walls or dimensions', () {
      final slabHit = tool.hitTestForTool(
        storey,
        const Offset(5, 5),
        100.0,
        ArchitectTool.slab,
      );
      expect(slabHit, equals('s1'));

      final wallHit = tool.hitTestForTool(
        storey,
        const Offset(5, -2),
        100.0,
        ArchitectTool.slab,
      );
      expect(wallHit, isNull);
    });

    test('Roof tool only hits roofs, not walls or dimensions', () {
      final roofHit = tool.hitTestForTool(
        storey,
        const Offset(5, 5),
        100.0,
        ArchitectTool.roof,
      );
      expect(roofHit, equals('r1'));

      final wallHit = tool.hitTestForTool(
        storey,
        const Offset(5, -2),
        100.0,
        ArchitectTool.roof,
      );
      expect(wallHit, isNull);
    });

    test('Select tool can hit elements', () {
      final wallHit = tool.hitTestForTool(
        storey,
        const Offset(5, -2),
        100.0,
        ArchitectTool.select,
      );
      expect(wallHit, equals('w1'));

      final dimHit = tool.hitTestForTool(
        storey,
        const Offset(5, -4.5),
        100.0,
        ArchitectTool.select,
      );
      expect(dimHit, equals('dim1'));
    });
  });
}
