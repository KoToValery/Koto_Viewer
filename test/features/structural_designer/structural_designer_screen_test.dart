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
  });
}
