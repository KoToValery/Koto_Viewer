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
  });
}
