import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/models/architect_slab_assembly.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_wall_type.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/rendering/architect_column_snap.dart';
import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_layers.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart'
    hide ColumnShape;

ArchitectProject _projectWith({
  List<ArchitectWall> walls = const [],
  List<ArchitectColumn> columns = const [],
  List<ArchitectSlab> slabs = const [],
  List<StructuralGridAxis> gridAxes = const [],
}) {
  final now = DateTime(2026);
  final floor = ArchitectStorey(
    id: 'floor_1',
    name: 'Floor 1',
    walls: walls,
    columns: columns,
    slabs: slabs,
  );
  return ArchitectProject(
    id: 'p_col_test',
    name: 'Column Test',
    createdAt: now,
    updatedAt: now,
    storeys: [floor],
    activeStoreyId: floor.id,
    gridAxes: gridAxes,
    wallTypes: ArchitectWallType.standardCatalog(),
  );
}

void main() {
  group('Concrete column hatch & brick wall overlap', () {
    test('Rectangular and circular cut columns draw cover fill + concrete hatch', () {
      for (final shape in [ColumnShape.rectangular, ColumnShape.circular]) {
        final col = ArchitectColumn(
          id: 'col_${shape.name}',
          position: const Offset(1.0, 1.0),
          shape: shape,
          width: 0.25,
          depth: shape == ColumnShape.circular ? 0.25 : 0.35,
          label: 'C1',
        );
        final canvas = ArchitectVectorCanvas();
        col.paint2D(canvas: canvas, zoomScale: 80.0);

        final paths = canvas.operations.whereType<ArchitectVectorPath>().toList();
        expect(paths.where((p) => p.fill), hasLength(1));
        final clippedStrokes =
            paths.where((p) => !p.fill && p.clip != null).toList();
        expect(clippedStrokes, hasLength(1));
        expect(clippedStrokes.single.path.computeMetrics(), isNotEmpty);
        expect(paths.where((p) => !p.fill && p.clip == null), hasLength(1));
      }
    });

    test('Brick wall core and hatch layers exclude overlapping concrete column', () {
      final brickWall = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(4, 0),
        thickness: 0.25,
        coreMaterialOverride: WallCoreMaterial.brick,
      );
      const col = ArchitectColumn(
        id: 'c1',
        position: Offset(2.0, 0.0),
        width: 0.25,
        depth: 0.25,
        label: 'C1',
      );
      final project = _projectWith(walls: [brickWall], columns: [col]);
      final layers = ArchitectWallLayers.forProject(project);

      // Brick wall core & hatch regions remain outside column, removed inside.
      expect(layers.core.contains(const Offset(1.0, 0.0)), isTrue);
      expect(layers.core.contains(const Offset(2.0, 0.0)), isFalse);
      expect(layers.body.contains(const Offset(2.0, 0.0)), isFalse);
      expect(layers.coreRegions['w1']!.contains(const Offset(2.0, 0.0)), isFalse);

      // In full 2D scene, concrete column paints after brick walls.
      final canvas = ArchitectVectorCanvas();
      Architect2dPainter(
        project: project,
        zoomScale: 80.0,
        activeTool: ArchitectTool.select,
      ).paint(canvas, const ui.Size(600, 400));

      final wallIdx = canvas.operations.lastIndexWhere(
        (op) => op.sources.contains('w1'),
      );
      final colIdx = canvas.operations.indexWhere(
        (op) => op.sources.contains('c1'),
      );
      expect(wallIdx, greaterThanOrEqualTo(0));
      expect(colIdx, greaterThan(wallIdx));
    });

    test('Insulated brick wall preserves exterior insulation around embedded column', () {
      final extWall = ArchitectWall(
        id: 'w_ext',
        startPoint: Offset.zero,
        endPoint: const Offset(4, 0),
        thickness: 0.37,
        wallTypeId: 'ext_25_12_eps',
      );
      final coreY = extWall.coreCenterStart.dy;
      final col = ArchitectColumn(
        id: 'c_corner',
        position: Offset(2.0, coreY),
        width: 0.25,
        depth: 0.25,
      );
      final project = _projectWith(walls: [extWall], columns: [col]);
      final layers = ArchitectWallLayers.forProject(project);

      expect(layers.core.contains(Offset(2.0, coreY)), isFalse);
      expect(layers.core.contains(Offset(1.0, coreY)), isTrue);
      // Exterior EPS band (+y side) outside the column stays continuous.
      expect(layers.insulation.contains(Offset(2.0, coreY + 0.16)), isTrue);
    });

    test('Building section subtracts concrete columns from brick wall region', () {
      final brickWall = ArchitectWall(
        id: 'w_sec',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(4, 0),
        thickness: 0.25,
        coreMaterialOverride: WallCoreMaterial.brick,
      );
      const col = ArchitectColumn(
        id: 'c_sec',
        position: Offset(2.0, 0.0),
        width: 0.25,
        depth: 0.25,
      );
      final project = _projectWith(walls: [brickWall], columns: [col]);
      final section = ArchitectBuildingSection.build(
        project,
        const ArchitectSection(
          id: 'sec_1',
          start: Offset(0, 0),
          end: Offset(4, 0),
          viewDepth: 1.0,
        ),
      );

      final colRegions = section.regions
          .where((r) => r.sourceId == 'c_sec' && r.material == SlabMaterial.concrete)
          .toList();
      final wallRegions =
          section.regions.where((r) => r.sourceId == 'w_sec').toList();

      expect(colRegions, isNotEmpty);
      expect(wallRegions, isNotEmpty);
      // Mid-height point inside column is covered by concrete, excluded from brick.
      const insideCol = Offset(2.0, 1.4);
      expect(colRegions.any((r) => r.path.contains(insideCol)), isTrue);
      expect(wallRegions.any((r) => r.path.contains(insideCol)), isFalse);
      expect(wallRegions.any((r) => r.path.contains(const Offset(1.0, 1.4))), isTrue);
    });
  });

  group('Column placement snapping improvements', () {
    final lWalls = [
      ArchitectWall(
        id: 'w_horiz',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(6, 0),
        thickness: 0.25,
      ),
      ArchitectWall(
        id: 'w_vert',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(0, 6),
        thickness: 0.25,
      ),
    ];

    test('Outer corner vertex hover snaps 40x40 column flush inward to both outer faces', () {
      final project = _projectWith(walls: lWalls);
      // Outer corner vertex of two 25cm walls at (0,0) is (-0.125, -0.125).
      final snap = ArchitectColumnSnap.resolve(
        raw: const Offset(-0.12, -0.12),
        project: project,
        columnWidth: 0.40,
        columnDepth: 0.40,
        columnShape: ColumnShape.rectangular,
        tolerance: 0.10,
      );

      expect(snap.isSnapped, isTrue);
      expect(snap.snapLabel, 'Wall corner');
      // Center moves to (+0.075, +0.075) so min-x and min-y lie on -0.125.
      expect(snap.point.dx, closeTo(0.075, 1e-4));
      expect(snap.point.dy, closeTo(0.075, 1e-4));
    });

    test('Inner room corner snaps 25x25 column flush to interior wall faces', () {
      final project = _projectWith(walls: lWalls);
      // Inner room corner is (+0.125, +0.125); room-flush 25x25 center is (+0.25, +0.25).
      final snap = ArchitectColumnSnap.resolve(
        raw: const Offset(0.22, 0.23),
        project: project,
        columnWidth: 0.25,
        columnDepth: 0.25,
        columnShape: ColumnShape.rectangular,
        tolerance: 0.10,
      );

      expect(snap.isSnapped, isTrue);
      expect(snap.snapLabel, 'Wall corner');
      expect(snap.point.dx, closeTo(0.25, 1e-4));
      expect(snap.point.dy, closeTo(0.25, 1e-4));
    });

    test('Free wall end cap snaps column flush inside wall end', () {
      final wall = ArchitectWall(
        id: 'w_stub',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(4, 0),
        thickness: 0.25,
      );
      final project = _projectWith(walls: [wall]);
      final snap = ArchitectColumnSnap.resolve(
        raw: const Offset(0.02, 0.01),
        project: project,
        columnWidth: 0.25,
        columnDepth: 0.25,
        columnShape: ColumnShape.rectangular,
        tolerance: 0.10,
      );

      expect(snap.isSnapped, isTrue);
      expect(snap.snapLabel, 'Wall corner');
      expect(snap.point.dx, closeTo(0.125, 1e-4));
      expect(snap.point.dy, closeTo(0.0, 1e-4));
    });

    test('Continuous wall face snaps flush outside interior wall face instead of center', () {
      final wall = ArchitectWall(
        id: 'w_single',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(6, 0),
        thickness: 0.25,
      );
      final project = _projectWith(walls: [wall]);

      // Hover near room face (y > +0.125) -> snaps flush against interior face (y = +0.25).
      final flushRoom = ArchitectColumnSnap.resolve(
        raw: const Offset(3.0, 0.16),
        project: project,
        columnWidth: 0.25,
        columnDepth: 0.25,
        columnShape: ColumnShape.rectangular,
        tolerance: 0.10,
      );
      expect(flushRoom.isSnapped, isTrue);
      expect(flushRoom.snapLabel, 'Wall face');
      expect(flushRoom.point.dx, closeTo(3.0, 1e-4));
      expect(flushRoom.point.dy, closeTo(0.25, 1e-4));

      // Hover near wall core axis -> snaps centered inside wall (y = 0.0).
      final centered = ArchitectColumnSnap.resolve(
        raw: const Offset(3.0, 0.03),
        project: project,
        columnWidth: 0.25,
        columnDepth: 0.25,
        columnShape: ColumnShape.rectangular,
        tolerance: 0.10,
      );
      expect(centered.isSnapped, isTrue);
      expect(centered.snapLabel, 'Wall face');
      expect(centered.point.dy, closeTo(0.0, 1e-4));
    });

    test('Diagonal 45-degree wall rotates rectangular column and aligns flush to face', () {
      final diag = ArchitectWall(
        id: 'w_diag',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(4, 4),
        thickness: 0.25,
      );
      final project = _projectWith(walls: [diag]);
      final snap = ArchitectColumnSnap.resolve(
        raw: const Offset(2.0, 2.02),
        project: project,
        columnWidth: 0.50,
        columnDepth: 0.25,
        columnShape: ColumnShape.rectangular,
        tolerance: 0.10,
      );

      expect(snap.isSnapped, isTrue);
      expect(snap.snapLabel, 'Wall face');
      expect(snap.angleDeg, closeTo(45.0, 1e-3));
    });

    test('Circular column snaps tangent and flush to wall face keeping label upright', () {
      final wall = ArchitectWall(
        id: 'w_circ',
        startPoint: const Offset(0, 0),
        endPoint: const Offset(6, 0),
        thickness: 0.25,
      );
      final project = _projectWith(walls: [wall]);
      // D = 0.30 (r = 0.15); room face is y = +0.125 -> tangent center is +0.275.
      final snap = ArchitectColumnSnap.resolve(
        raw: const Offset(3.0, 0.24),
        project: project,
        columnWidth: 0.30,
        columnDepth: 0.30,
        columnShape: ColumnShape.circular,
        tolerance: 0.10,
      );

      expect(snap.isSnapped, isTrue);
      expect(snap.snapLabel, 'Wall face');
      expect(snap.point.dy, closeTo(0.275, 1e-4));
      expect(snap.angleDeg, isNull);
    });

    test('Slab corner snaps new column flush inside corner while grid intersection centers', () {
      const slab = ArchitectSlab(
        id: 'slab_1',
        polygon: [
          Offset(0, 0),
          Offset(6, 0),
          Offset(6, 4),
          Offset(0, 4),
        ],
      );
      final slabProject = _projectWith(slabs: [slab]);
      // Cursor at (0.14, 0.14): center is >0.10 away from (0,0), top-left corner at
      // (0.015, 0.015) is within tolerance 0.10 of slab corner (0,0).
      final slabCornerSnap = ArchitectColumnSnap.resolve(
        raw: const Offset(0.14, 0.14),
        project: slabProject,
        columnWidth: 0.25,
        columnDepth: 0.25,
        columnShape: ColumnShape.rectangular,
        tolerance: 0.10,
      );
      expect(slabCornerSnap.isSnapped, isTrue);
      expect(slabCornerSnap.point.dx, closeTo(0.125, 1e-4));
      expect(slabCornerSnap.point.dy, closeTo(0.125, 1e-4));

      // Grid intersection still centers column on the grid intersection point.
      const gridProjectWalls = <ArchitectWall>[];
      final gridProject = _projectWith(
        walls: gridProjectWalls,
        gridAxes: const [
          StructuralGridAxis(
            id: 'ax_1',
            name: '1',
            start: Offset(2.0, -1.0),
            end: Offset(2.0, 5.0),
          ),
          StructuralGridAxis(
            id: 'ax_A',
            name: 'A',
            start: Offset(-1.0, 2.0),
            end: Offset(5.0, 2.0),
          ),
        ],
      );
      final gridSnap = ArchitectColumnSnap.resolve(
        raw: const Offset(2.03, 1.98),
        project: gridProject,
        columnWidth: 0.25,
        columnDepth: 0.25,
        columnShape: ColumnShape.rectangular,
        tolerance: 0.10,
      );
      expect(gridSnap.isSnapped, isTrue);
      expect(gridSnap.point.dx, closeTo(2.0, 1e-4));
      expect(gridSnap.point.dy, closeTo(2.0, 1e-4));
    });
  });
}
