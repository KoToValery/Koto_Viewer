import 'dart:io';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_2d_painter.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_3d_mesh_builder.dart';
import 'package:kotoview/src/features/structural_designer/services/structural_persistence_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Structural BiM Designer v2 - Numbering & Resequencing Tests', () {
    test('renumberColumnsAfterDeletion removes numbering gaps sequentially (Bulgarian К1..Кn)', () {
      const col1 = StructuralColumn(id: 'c1', name: 'К1', center: Offset(0, 0), width: 0.25, height: 0.30);
      const col2 = StructuralColumn(id: 'c2', name: 'К2', center: Offset(3, 0), width: 0.25, height: 0.30);
      const col3 = StructuralColumn(id: 'c3', name: 'К3', center: Offset(6, 0), width: 0.25, height: 0.30);
      const col4 = StructuralColumn(id: 'c4', name: 'К4', center: Offset(9, 0), width: 0.25, height: 0.30);

      // Delete middle column К2
      final remaining = [col1, col3, col4];
      final renumbered = renumberColumnsAfterDeletion(remaining, col2, defaultPrefix: 'К');

      expect(renumbered.length, equals(3));
      expect(renumbered[0].displayName, equals('К1'));
      expect(renumbered[1].displayName, equals('К2')); // Was К3
      expect(renumbered[2].displayName, equals('К3')); // Was К4
    });

    test('renumberColumnsAfterDeletion removes numbering gaps sequentially (English C1..Cn)', () {
      const col1 = StructuralColumn(id: 'c1', name: 'C1', center: Offset(0, 0), width: 0.25, height: 0.30);
      const col2 = StructuralColumn(id: 'c2', name: 'C2', center: Offset(3, 0), width: 0.25, height: 0.30);
      const col3 = StructuralColumn(id: 'c3', name: 'C3', center: Offset(6, 0), width: 0.25, height: 0.30);

      // Delete first column C1
      final remaining = [col2, col3];
      final renumbered = renumberColumnsAfterDeletion(remaining, col1, defaultPrefix: 'C');

      expect(renumbered.length, equals(2));
      expect(renumbered[0].displayName, equals('C1')); // Was C2
      expect(renumbered[1].displayName, equals('C2')); // Was C3
    });

    test('renumberShearWallsAfterDeletion removes numbering gaps (Ш1..Шn and W1..Wn)', () {
      const wall1 = StructuralShearWall(id: 'w1', name: 'Ш1', start: Offset(0, 0), end: Offset(1.5, 0), thickness: 0.25);
      const wall2 = StructuralShearWall(id: 'w2', name: 'Ш2', start: Offset(0, 4), end: Offset(1.5, 4), thickness: 0.25);
      const wall3 = StructuralShearWall(id: 'w3', name: 'Ш3', start: Offset(0, 8), end: Offset(1.5, 8), thickness: 0.25);

      // Delete wall Ш2
      final remaining = [wall1, wall3];
      final renumbered = renumberShearWallsAfterDeletion(remaining, wall2, defaultPrefix: 'Ш');

      expect(renumbered.length, equals(2));
      expect(renumbered[0].displayName, equals('Ш1'));
      expect(renumbered[1].displayName, equals('Ш2')); // Was Ш3
    });

    test('resequenceGridAxes renumbers spatially: vertical axes -> 1, 2, 3; horizontal -> letters', () {
      // 3 vertical axes along X = 0, 4, 8
      const v1 = StructuralGridAxis(id: 'a1', name: '9', start: Offset(0, 0), end: Offset(0, 10));
      const v2 = StructuralGridAxis(id: 'a2', name: '3', start: Offset(4, 0), end: Offset(4, 10));
      const v3 = StructuralGridAxis(id: 'a3', name: '1', start: Offset(8, 0), end: Offset(8, 10));

      // 3 horizontal axes along Y = 0, 5, 10
      const h1 = StructuralGridAxis(id: 'b1', name: 'Z', start: Offset(-2, 0), end: Offset(12, 0));
      const h2 = StructuralGridAxis(id: 'b2', name: 'X', start: Offset(-2, 5), end: Offset(12, 5));
      const h3 = StructuralGridAxis(id: 'b3', name: 'Y', start: Offset(-2, 10), end: Offset(12, 10));

      final allAxes = [v3, v1, v2, h3, h1, h2];

      // Test Bulgarian sequencing (А, Б, В)
      final resequencedBg = resequenceGridAxes(allAxes, isBulgarian: true);
      final vertBg = resequencedBg.where((a) => (a.end.dx - a.start.dx).abs() < 1e-4).toList();
      final horizBg = resequencedBg.where((a) => (a.end.dy - a.start.dy).abs() < 1e-4).toList();

      expect(vertBg.map((a) => a.name).toList(), equals(['1', '2', '3']));
      expect(horizBg.map((a) => a.name).toList(), equals(['А', 'Б', 'В']));

      // Test English sequencing (A, B, C)
      final resequencedEn = resequenceGridAxes(allAxes, isBulgarian: false);
      final horizEn = resequencedEn.where((a) => (a.end.dy - a.start.dy).abs() < 1e-4).toList();
      expect(horizEn.map((a) => a.name).toList(), equals(['A', 'B', 'C']));
    });

    test('resequenceGridAxes handles inserting an axis in-between existing axes', () {
      const v1 = StructuralGridAxis(id: 'a1', name: '1', start: Offset(0, 0), end: Offset(0, 10));
      const v2 = StructuralGridAxis(id: 'a2', name: '2', start: Offset(6, 0), end: Offset(6, 10));
      // Inserted axis between 0 and 6: at X = 3
      const vNew = StructuralGridAxis(id: 'a_new', name: 'temp', start: Offset(3, 0), end: Offset(3, 10));

      final result = resequenceGridAxes([v1, v2, vNew], isBulgarian: true);
      expect(result.map((a) => a.name).toList(), equals(['1', '2', '3']));
      expect(result.firstWhere((a) => a.id == 'a1').name, equals('1'));
      expect(result.firstWhere((a) => a.id == 'a_new').name, equals('2'));
      expect(result.firstWhere((a) => a.id == 'a2').name, equals('3'));
    });
  });

  group('Structural BiM Designer v2 - Multi-Slab & Persistence Tests', () {
    test('Independent slab thicknesses and distinct color palettes', () {
      final slab1 = const StructuralSlab(
        id: 'slab_1',
        polygon: [Offset(0, 0), Offset(5, 0), Offset(5, 5), Offset(0, 5)],
        thickness: 0.16,
        colorValue: 0xFF00E5FF,
      );
      final slab2 = const StructuralSlab(
        id: 'slab_2',
        polygon: [Offset(5, 0), Offset(10, 0), Offset(10, 5), Offset(5, 5)],
        thickness: 0.22,
        colorValue: 0xFFFFB300,
      );

      expect(slab1.thickness, equals(0.16));
      expect(slab2.thickness, equals(0.22));
      expect(slab1.colorValue, isNot(equals(slab2.colorValue)));

      // 3D mesh building handles distinct thicknesses
      final project = StructuralProject(
        storeys: [
          StoreyLevel(
            id: 'st_1',
            name: 'Етаж 1',
            elevation: 0.0,
            height: 3.0,
            slabs: [slab1, slab2],
          ),
        ],
      );

      final mesh = Structural3dMeshBuilder.buildProjectMesh(project);
      expect(mesh.triangleCount, greaterThan(0));
    });

    test('StructuralPersistenceService round-trip serialization', () {
      final project = StructuralProject(
        storeys: [
          StoreyLevel(
            id: 'st_0',
            name: 'Кота 0.00',
            elevation: 0.0,
            height: 2.80,
            columns: const [
              StructuralColumn(
                id: 'col_1',
                name: 'К1',
                center: Offset(2.0, 3.0),
                width: 0.25,
                height: 0.30,
                thickness: 0.25,
              ),
            ],
            shearWalls: const [
              StructuralShearWall(
                id: 'wall_1',
                name: 'Ш1',
                start: Offset(1.0, 1.0),
                end: Offset(2.5, 1.0),
                thickness: 0.25,
              ),
            ],
            beams: const [
              StructuralBeam(
                id: 'beam_1',
                start: Offset(2.0, 3.0),
                end: Offset(5.0, 3.0),
                width: 0.25,
                depth: 0.50,
              ),
            ],
            gridAxes: const [
              StructuralGridAxis(
                id: 'axis_1',
                name: '1',
                start: Offset(2.0, 0.0),
                end: Offset(2.0, 10.0),
              ),
            ],
            slabs: const [
              StructuralSlab(
                id: 'slab_1',
                polygon: [
                  Offset(0, 0),
                  Offset(6, 0),
                  Offset(6, 6),
                  Offset(0, 6),
                ],
                openings: [
                  [Offset(1, 1), Offset(2, 1), Offset(2, 2), Offset(1, 2)],
                ],
                thickness: 0.20,
                colorValue: 0xFF26A69A,
              ),
            ],
          ),
        ],
      );

      final json = project.toJson();
      final restored = StructuralProject.fromJson(json);

      expect(restored.storeys.length, equals(1));
      final st = restored.storeys.first;
      expect(st.columns.length, equals(1));
      expect(st.columns.first.displayName, equals('К1'));
      expect(st.columns.first.width, equals(0.25));
      expect(st.columns.first.height, equals(0.30));

      expect(st.shearWalls.length, equals(1));
      expect(st.shearWalls.first.displayName, equals('Ш1'));
      expect(st.shearWalls.first.length, closeTo(1.50, 1e-4));

      expect(st.beams.length, equals(1));
      expect(st.beams.first.width, equals(0.25));
      expect(st.beams.first.depth, equals(0.50));

      expect(st.gridAxes.length, equals(1));
      expect(st.gridAxes.first.name, equals('1'));

      expect(st.slabs.length, equals(1));
      expect(st.slabs.first.thickness, equals(0.20));
      expect(st.slabs.first.colorValue, equals(0xFF26A69A));
      expect(st.slabs.first.openings.length, equals(1));
    });

    test('StructuralPersistenceService exports valid AutoCAD DXF file', () async {
      final project = StructuralProject(
        storeys: [
          StoreyLevel(
            id: 'st_0',
            name: 'Кота 0.00',
            elevation: 0.0,
            height: 2.80,
            columns: const [
              StructuralColumn(
                id: 'col_1',
                name: 'К1',
                center: Offset(2.0, 3.0),
                width: 0.25,
                height: 0.30,
              ),
            ],
            shearWalls: const [
              StructuralShearWall(
                id: 'wall_1',
                name: 'Ш1',
                start: Offset(1.0, 1.0),
                end: Offset(2.5, 1.0),
                thickness: 0.25,
              ),
            ],
            slabs: const [
              StructuralSlab(
                id: 'slab_1',
                polygon: [
                  Offset(0, 0),
                  Offset(5, 0),
                  Offset(5, 5),
                  Offset(0, 5),
                ],
                thickness: 0.20,
              ),
            ],
            gridAxes: const [
              StructuralGridAxis(
                id: 'axis_1',
                name: '1',
                start: Offset(2.0, 0.0),
                end: Offset(2.0, 8.0),
              ),
            ],
          ),
        ],
      );

      final file = await StructuralPersistenceService.exportToDxfFile(
        project: project,
        baseName: 'test_drawing',
        outputDirectory: Directory.systemTemp,
      );

      expect(await file.exists(), isTrue);
      final content = await file.readAsString();

      // Check standard AutoCAD DXF structure and layers
      expect(content, contains('SECTION'));
      expect(content, contains('HEADER'));
      expect(content, contains('S-COL'));
      expect(content, contains('S-WALL'));
      expect(content, contains('S-SLAB'));
      expect(content, contains('S-AXIS'));
      expect(content, contains('LWPOLYLINE'));
      expect(content, contains('EOF'));

      // Clean up temp file
      if (await file.exists()) {
        await file.delete();
      }
    });
  });
}
