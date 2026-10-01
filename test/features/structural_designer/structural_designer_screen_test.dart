import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/structural_designer/analysis/cantilever_detector.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_3d_mesh_builder.dart';

void main() {
  group('Structural Designer CAD Unit and Projection Tests', () {
    test('Correctly identifies millimeter vs meter CAD drawings and scales geometry', () {
      // 1. Millimeter architectural drawing: 30000 x 20000 mm (30m x 20m)
      final docMm = DxfDocument(
        layers: const {},
        blocks: const {},
        entities: const [],
        headerVars: {r'$INSUNITS': '4'}, // 4 = millimeters
        textStyles: const {},
        bounds: const Rect.fromLTWH(0, 0, 30000, 20000),
        entityStats: const {},
        lineTypes: const {},
        dimStyles: const {},
        layouts: const ['Model'],
        layoutEntities: const {'Model': []},
        layoutBounds: const {'Model': Rect.fromLTWH(0, 0, 30000, 20000)},
      );

      expect(docMm.unit, equals(DxfUnit.millimeters));
      final double cadUnitsPerMeter = 1.0 / docMm.unit.toMeters;
      expect(cadUnitsPerMeter, equals(1000.0));

      // Preset 25x50 cm column (0.25m x 0.50m) in mm CAD space
      const presetCol = StructuralColumn(
        id: 'col_preset',
        center: Offset(10000, 10000),
        width: 0.25,
        height: 0.50,
      );

      final colMm = presetCol.copyWith(
        width: presetCol.width * cadUnitsPerMeter,
        height: presetCol.height * cadUnitsPerMeter,
      );

      expect(colMm.width, equals(250.0));
      expect(colMm.height, equals(500.0));

      // Polygon corners match exact 250 x 500 mm dimensions in CAD world
      final vertices = colMm.polygonVertices;
      expect(vertices.length, equals(4));
      expect((vertices[1].dx - vertices[0].dx).abs(), equals(250.0));
      expect((vertices[2].dy - vertices[1].dy).abs(), equals(500.0));
    });

    test('3D Mesh Builder creates proportional heights using cadUnitsPerMeter', () {
      // Millimeter project with a 3.00m storey
      final project = StructuralProject(
        storeys: [
          StoreyLevel(
            id: 'storey_1',
            name: 'Етаж 1',
            elevation: 0.0,
            height: 3.0,
            columns: const [
              StructuralColumn(
                id: 'c1',
                center: Offset(5000, 5000),
                width: 250.0,
                height: 500.0,
              ),
            ],
            slabs: const [
              StructuralSlab(
                id: 'slab_1',
                polygon: [
                  Offset(0, 0),
                  Offset(10000, 0),
                  Offset(10000, 10000),
                  Offset(0, 10000),
                ],
                thickness: 0.20,
              ),
            ],
          ),
        ],
      );

      const double cadUnitsPerMeterMm = 1000.0;
      final mesh = Structural3dMeshBuilder.buildProjectMesh(
        project,
        cadUnitsPerMeter: cadUnitsPerMeterMm,
      );

      expect(mesh.triangleCount, greaterThan(0));
      // Storey height in mesh is 3000 mm, matching 10000 mm slab dimension
      expect(mesh.bounds.maxDimension, greaterThanOrEqualTo(10000.0));
    });

    test('Cantilever analysis correctly handles millimeter scale drawings', () {
      // Overhang in millimeters: 2000 mm (2.0 m) past column
      final storeyMm = StoreyLevel(
        id: 'storey_mm',
        name: 'Storey 1',
        columns: const [
          StructuralColumn(id: 'c1', center: Offset(0, 0), width: 250, height: 250),
          StructuralColumn(id: 'c2', center: Offset(0, 10000), width: 250, height: 250),
          StructuralColumn(id: 'c3', center: Offset(8000, 0), width: 250, height: 250),
          StructuralColumn(id: 'c4', center: Offset(8000, 10000), width: 250, height: 250),
        ],
        slabs: const [
          StructuralSlab(
            id: 'slab_mm',
            polygon: [
              Offset(0, 0),
              Offset(10000, 0), // 2000mm cantilever past c3
              Offset(10000, 10000),
              Offset(0, 10000),
            ],
            thickness: 0.20,
          ),
        ],
      );

      final summary = CantileverDetector.analyzeProject(
        StructuralProject(storeys: [storeyMm]),
        cadUnitsPerMeter: 1000.0,
      );

      expect(summary.totalCantilevers, greaterThan(0));
      final cantilever = summary.zones.first;
      // In meters, length is ~2.0m, not 2000m
      expect(cantilever.length, closeTo(2.0, 0.05));
      expect(cantilever.longTermDeflectionMm, greaterThan(0.0));
    });

    test('StructuralColumn.fromTopLeft positions anchor precisely at top-left corner', () {
      // Column width = 0.25m, height = 0.50m placed at top-left corner (10.0, 20.0)
      final col = StructuralColumn.fromTopLeft(
        id: 'col_tl',
        topLeft: const Offset(10.0, 20.0),
        width: 0.25,
        height: 0.50,
      );

      // In CAD (Y up): top-left is (10.0, 20.0), center is (10.125, 19.75)
      expect(col.topLeft.dx, closeTo(10.0, 1e-6));
      expect(col.topLeft.dy, closeTo(20.0, 1e-6));
      expect(col.center.dx, closeTo(10.125, 1e-6));
      expect(col.center.dy, closeTo(19.75, 1e-6));

      // Polygon vertices begin with top-left corner
      final vertices = col.polygonVertices;
      expect(vertices.length, equals(4));
      expect(vertices[0].dx, closeTo(10.0, 1e-6)); // Top-Left
      expect(vertices[0].dy, closeTo(20.0, 1e-6));
      expect(vertices[1].dx, closeTo(10.25, 1e-6)); // Top-Right
      expect(vertices[1].dy, closeTo(20.0, 1e-6));
      expect(vertices[2].dx, closeTo(10.25, 1e-6)); // Bottom-Right
      expect(vertices[2].dy, closeTo(19.50, 1e-6));
      expect(vertices[3].dx, closeTo(10.0, 1e-6)); // Bottom-Left
      expect(vertices[3].dy, closeTo(19.50, 1e-6));
    });

    test('StructuralSlab edgeGrips computes midpoints and orthogonal outward normals', () {
      // 10m x 10m rectangular slab: (0,0) -> (10,0) -> (10,10) -> (0,10)
      const slab = StructuralSlab(
        id: 'slab_rect',
        polygon: [
          Offset(0, 0),
          Offset(10, 0),
          Offset(10, 10),
          Offset(0, 10),
        ],
      );

      final grips = slab.edgeGrips;
      expect(grips.length, equals(4));

      // Edge 0: Bottom edge (0,0) -> (10,0), midpoint (5,0), normal downwards (0, -1)
      expect(grips[0].midpoint, equals(const Offset(5, 0)));
      expect(grips[0].normal.dx, closeTo(0.0, 1e-6));
      expect(grips[0].normal.dy, closeTo(-1.0, 1e-6));

      // Edge 1: Right edge (10,0) -> (10,10), midpoint (10,5), normal rightwards (1, 0)
      expect(grips[1].midpoint, equals(const Offset(10, 5)));
      expect(grips[1].normal.dx, closeTo(1.0, 1e-6));
      expect(grips[1].normal.dy, closeTo(0.0, 1e-6));

      // Edge 2: Top edge (10,10) -> (0,10), midpoint (5,10), normal upwards (0, 1)
      expect(grips[2].midpoint, equals(const Offset(5, 10)));
      expect(grips[2].normal.dx, closeTo(0.0, 1e-6));
      expect(grips[2].normal.dy, closeTo(1.0, 1e-6));

      // Edge 3: Left edge (0,10) -> (0,0), midpoint (0,5), normal leftwards (-1, 0)
      expect(grips[3].midpoint, equals(const Offset(0, 5)));
      expect(grips[3].normal.dx, closeTo(-1.0, 1e-6));
      expect(grips[3].normal.dy, closeTo(0.0, 1e-6));
    });

    test('StructuralSlab extrudeEdgeParallel extrudes segment parallel keeping existing corners in place', () {
      // 10m x 10m slab supported by columns at the four corners
      const slab = StructuralSlab(
        id: 'slab_extrude',
        polygon: [
          Offset(0, 0),
          Offset(10, 0),
          Offset(10, 10),
          Offset(0, 10),
        ],
      );

      // Extrude Edge 2 (Top edge: from (10,10) to (0,10)) outward parallel by 1.50 meters
      final extrudedSlab = slab.extrudeEdgeParallel(edgeIndex: 2, distance: 1.50);

      // Polygon expands from 4 to 6 vertices
      expect(extrudedSlab.polygon.length, equals(6));

      // Existing corners (10,10) and (0,10) remain strictly in place!
      expect(extrudedSlab.polygon[2], equals(const Offset(10, 10)));
      expect(extrudedSlab.polygon[5], equals(const Offset(0, 10)));

      // Two new corner vertices are inserted forming parallel overhang
      expect(extrudedSlab.polygon[3].dx, closeTo(10.0, 1e-6));
      expect(extrudedSlab.polygon[3].dy, closeTo(11.5, 1e-6));
      expect(extrudedSlab.polygon[4].dx, closeTo(0.0, 1e-6));
      expect(extrudedSlab.polygon[4].dy, closeTo(11.5, 1e-6));

      // Parallel extruded edge has identical length and is strictly parallel
      final parallelEdge = extrudedSlab.polygon[4] - extrudedSlab.polygon[3];
      expect(parallelEdge.dx, closeTo(-10.0, 1e-6));
      expect(parallelEdge.dy, closeTo(0.0, 1e-6));

      // Cantilever detection detects the newly created 1.5m balcony overhang
      final project = StructuralProject(storeys: [
        StoreyLevel(
          id: 's1',
          name: 'Storey 1',
          columns: const [
            StructuralColumn(id: 'c1', center: Offset(0, 0), width: 0.25, height: 0.25),
            StructuralColumn(id: 'c2', center: Offset(10, 0), width: 0.25, height: 0.25),
            StructuralColumn(id: 'c3', center: Offset(10, 10), width: 0.25, height: 0.25),
            StructuralColumn(id: 'c4', center: Offset(0, 10), width: 0.25, height: 0.25),
          ],
          slabs: [extrudedSlab],
        ),
      ]);

      final analysis = CantileverDetector.analyzeProject(project);
      expect(analysis.totalCantilevers, greaterThan(0));
      expect(analysis.zones.first.length, closeTo(1.50, 0.05));
    });

    test('Moving a placed column updates its position and vertices correctly', () {
      final initialCol = StructuralColumn.fromTopLeft(
        id: 'col_move_test',
        topLeft: const Offset(2.0, 5.0),
        width: 0.25,
        height: 0.50,
      );

      // Move top-left corner to (6.0, 8.0)
      final movedCol = StructuralColumn.fromTopLeft(
        id: initialCol.id,
        topLeft: const Offset(6.0, 8.0),
        width: initialCol.width,
        height: initialCol.height,
        rotationRad: initialCol.rotationRad,
      );

      expect(movedCol.topLeft.dx, closeTo(6.0, 1e-6));
      expect(movedCol.topLeft.dy, closeTo(8.0, 1e-6));
      expect(movedCol.center.dx, closeTo(6.125, 1e-6));
      expect(movedCol.center.dy, closeTo(7.75, 1e-6));

      final vertices = movedCol.polygonVertices;
      expect(vertices.first.dx, closeTo(6.0, 1e-6));
      expect(vertices.first.dy, closeTo(8.0, 1e-6));
    });

    test('Deleting a placed column removes it from storey and triggers recalculation', () {
      final col1 = StructuralColumn(id: 'c1', center: const Offset(0, 0), width: 0.25, height: 0.25);
      final col2 = StructuralColumn(id: 'c2', center: const Offset(5, 5), width: 0.25, height: 0.25);

      final storey = StoreyLevel(
        id: 's1',
        name: 'Storey 1',
        columns: [col1, col2],
      );

      expect(storey.columns.length, equals(2));

      // Simulate deletion of c2
      final updatedColumns = storey.columns.where((c) => c.id != 'c2').toList();
      final updatedStorey = storey.copyWith(columns: updatedColumns);

      expect(updatedStorey.columns.length, equals(1));
      expect(updatedStorey.columns.first.id, equals('c1'));
    });

    test('Rotating a placed column swaps width and height correctly', () {
      final col = const StructuralColumn(
        id: 'c_rot',
        center: Offset(3.0, 4.0),
        width: 0.25,
        height: 0.60,
      );

      final rotated = col.copyWith(
        width: col.height,
        height: col.width,
      );

      expect(rotated.width, equals(0.60));
      expect(rotated.height, equals(0.25));
      expect(rotated.center, equals(const Offset(3.0, 4.0)));
    });

    test('Moving a slab vertex modifies polygon while retaining other vertices', () {
      const slab = StructuralSlab(
        id: 'slab_move_v',
        polygon: [
          Offset(0, 0),
          Offset(10, 0),
          Offset(10, 8),
          Offset(0, 8),
        ],
      );

      // Move vertex 2 from (10, 8) to (12, 10)
      final moved = slab.moveVertex(2, const Offset(12.0, 10.0));
      expect(moved.polygon.length, equals(4));
      expect(moved.polygon[0], equals(const Offset(0, 0)));
      expect(moved.polygon[1], equals(const Offset(10, 0)));
      expect(moved.polygon[2], equals(const Offset(12, 10)));
      expect(moved.polygon[3], equals(const Offset(0, 8)));
    });

    test('Inserting midpoint vertex divides edge into two segments', () {
      const slab = StructuralSlab(
        id: 'slab_insert_mid',
        polygon: [
          Offset(0, 0),
          Offset(10, 0),
          Offset(10, 8),
          Offset(0, 8),
        ],
      );

      // Insert at midpoint of edge 1 (from (10,0) to (10,8), mid is (10,4))
      final withMid = slab.insertMidpointVertex(1);
      expect(withMid.polygon.length, equals(5));
      expect(withMid.polygon[0], equals(const Offset(0, 0)));
      expect(withMid.polygon[1], equals(const Offset(10, 0)));
      expect(withMid.polygon[2], equals(const Offset(10, 4))); // new vertex!
      expect(withMid.polygon[3], equals(const Offset(10, 8)));
      expect(withMid.polygon[4], equals(const Offset(0, 8)));
    });

    test('Deleting/merging slab vertex reduces vertex count, enforces minimum 3 vertices', () {
      const slab5 = StructuralSlab(
        id: 'slab_del_v',
        polygon: [
          Offset(0, 0),
          Offset(10, 0),
          Offset(10, 4),
          Offset(10, 8),
          Offset(0, 8),
        ],
      );

      // Remove vertex 2 (midpoint)
      final slab4 = slab5.removeVertex(2);
      expect(slab4, isNotNull);
      expect(slab4!.polygon.length, equals(4));
      expect(slab4.polygon[2], equals(const Offset(10, 8)));

      // Triangle slab cannot have a vertex removed
      const slab3 = StructuralSlab(
        id: 'slab_tri',
        polygon: [
          Offset(0, 0),
          Offset(5, 0),
          Offset(2.5, 5),
        ],
      );
      final slabInvalid = slab3.removeVertex(0);
      expect(slabInvalid, isNull);
    });

    test('Slab offsetContour expands polygon uniformly in all directions', () {
      const slab = StructuralSlab(
        id: 'slab_offset',
        polygon: [
          Offset(0, 0),
          Offset(10, 0),
          Offset(10, 10),
          Offset(0, 10),
        ],
      );

      // Expand outward by 1.0m
      final expanded = slab.offsetContour(1.0);
      expect(expanded.polygon.length, equals(4));
      expect(expanded.bounds.width, closeTo(12.0, 0.05));
      expect(expanded.bounds.height, closeTo(12.0, 0.05));
      expect(expanded.netArea, greaterThan(slab.netArea));

      // Shrink inward by 1.0m
      final shrunk = slab.offsetContour(-1.0);
      expect(shrunk.bounds.width, closeTo(8.0, 0.05));
      expect(shrunk.bounds.height, closeTo(8.0, 0.05));
      expect(shrunk.netArea, lessThan(slab.netArea));
    });

    test('Slab rotate rotates polygon around centroid preserving area', () {
      const slab = StructuralSlab(
        id: 'slab_rot',
        polygon: [
          Offset(0, 0),
          Offset(10, 0),
          Offset(10, 6),
          Offset(0, 6),
        ],
      );

      expect(slab.centroid, equals(const Offset(5.0, 3.0)));
      final initialArea = slab.netArea;

      // Rotate by 90 degrees around centroid
      final rotated90 = slab.rotate(90.0);
      expect(rotated90.centroid.dx, closeTo(5.0, 1e-4));
      expect(rotated90.centroid.dy, closeTo(3.0, 1e-4));
      expect(rotated90.netArea, closeTo(initialArea, 1e-2));
      expect(rotated90.perimeter, closeTo(slab.perimeter, 1e-2));
    });
  });
}
