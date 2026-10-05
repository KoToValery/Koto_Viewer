import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/bim_projects/models/bim_work_project.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_export_service.dart';
import 'package:kotoview/src/features/bim_projects/services/bim_project_library_service.dart';
import 'package:kotoview/src/features/bim_projects/services/dxf_document_transformer.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BimWorkProject & BimStoreyUnderlay Models', () {
    test('BimStoreyUnderlay serialization and getters', () {
      const underlay = BimStoreyUnderlay(
        storeyId: 'storey_1',
        name: 'Floor 1',
        elevation: 0.0,
        height: 3.0,
        sourceFileName: 'arch_floor1.dxf',
        underlayFileName: 'underlays/storey_1.dxf',
        controlPoint: Offset(100.0, 200.0),
        unitScale: 1.0,
        layerVisibility: {'WALLS': true, 'FURNITURE': false},
        wallsDetected: true,
      );

      expect(underlay.hasUnderlay, isTrue);
      expect(underlay.isControlPointSet, isTrue);
      expect(underlay.elevation, equals(0.0));
      expect(underlay.elevationLabel, equals('±0.00'));

      const underlayUpper = BimStoreyUnderlay(
        storeyId: 'storey_2',
        name: 'Floor 2',
        elevation: 3.20,
      );
      expect(underlayUpper.elevationLabel, equals('+3.20'));

      const underlayBasement = BimStoreyUnderlay(
        storeyId: 'storey_b',
        name: 'Basement',
        elevation: -2.80,
      );
      expect(underlayBasement.elevationLabel, equals('-2.80'));

      const structLevel = StoreyLevel(
        id: 'lvl_1',
        name: '±0.00',
        elevation: 0.0,
      );
      expect(structLevel.elevationLabel, equals('±0.00'));

      const structLevel2 = StoreyLevel(
        id: 'lvl_2',
        name: '+3.00',
        elevation: 3.0,
      );
      expect(structLevel2.elevationLabel, equals('+3.00'));

      final jsonMap = underlay.toJson();
      final restored = BimStoreyUnderlay.fromJson(jsonMap);

      expect(restored.storeyId, equals('storey_1'));
      expect(restored.name, equals('Floor 1'));
      expect(restored.elevation, equals(0.0));
      expect(restored.elevationLabel, equals('±0.00'));
      expect(restored.controlPoint, equals(const Offset(100.0, 200.0)));
      expect(restored.layerVisibility['WALLS'], isTrue);
      expect(restored.layerVisibility['FURNITURE'], isFalse);
      expect(restored.wallsDetected, isTrue);
    });

    test('BimWorkProject alignment status & reference storey', () {
      final p = BimWorkProject(
        id: 'test_p1',
        name: 'Office Tower',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        storeys: const [
          BimStoreyUnderlay(
            storeyId: 'basement_1',
            name: 'Basement -1',
            elevation: -3.0,
            underlayFileName: 'underlays/b1.dxf',
            controlPoint: Offset(50, 50),
          ),
          BimStoreyUnderlay(
            storeyId: 'ground',
            name: 'Ground Floor',
            elevation: 0.0,
            underlayFileName: 'underlays/ground.dxf',
            controlPoint: Offset(50, 50),
          ),
          BimStoreyUnderlay(
            storeyId: 'floor_1',
            name: 'Floor 1',
            elevation: 3.0,
            underlayFileName: 'underlays/f1.dxf',
            controlPoint: Offset(50, 50),
          ),
        ],
        alignmentConfirmed: true,
      );

      expect(p.isAligned, isTrue);
      expect(p.allControlPointsPlaced, isTrue);
      expect(p.hasAnyUnderlay, isTrue);
      expect(p.underlaysCount, equals(3));
      expect(p.referenceStorey?.storeyId, equals('ground'));

      final jsonMap = p.toJson();
      final restored = BimWorkProject.fromJson(jsonMap);

      expect(restored.id, equals('test_p1'));
      expect(restored.storeys.length, equals(3));
      expect(restored.isAligned, isTrue);
    });
  });

  group('DxfDocumentTransformer', () {
    test('Transforms lines, circles, and polylines correctly by offset and scale', () {
      final doc = DxfDocument(
        layers: {'WALLS': DxfLayer(name: 'WALLS', colorIndex: 7)},
        blocks: {},
        entities: [
          const DxfLine(
            p1: Offset(10, 20),
            p2: Offset(30, 40),
            layer: 'WALLS',
          ),
          const DxfCircle(
            center: Offset(15, 25),
            radius: 5,
            layer: 'WALLS',
          ),
          const DxfLwPolyline(
            vertices: [
              DxfPolylineVertex(x: 10, y: 10),
              DxfPolylineVertex(x: 20, y: 10),
              DxfPolylineVertex(x: 20, y: 20),
            ],
            isClosed: true,
            layer: 'WALLS',
          ),
        ],
        headerVars: {},
        bounds: const Rect.fromLTWH(10, 10, 20, 30),
        entityStats: {},
      );

      // Storey local control point is at (10, 20)
      // Reference control point is at (100, 200)
      // Scale is 2.0
      // p_project = 2 * (p_local - (10, 20)) + (100, 200)
      final transformed = DxfDocumentTransformer.transformBetweenControlPoints(
        source: doc,
        sourceControlPoint: const Offset(10, 20),
        targetControlPoint: const Offset(100, 200),
        scale: 2.0,
      );

      // Line start was (10, 20) -> should become exactly (100, 200)
      final line = transformed.entities[0] as DxfLine;
      expect(line.p1, equals(const Offset(100, 200)));

      // Line end was (30, 40) -> 2 * ((30, 40) - (10, 20)) + (100, 200) = 2*(20, 20) + (100, 200) = (140, 240)
      expect(line.p2, equals(const Offset(140, 240)));

      // Circle center was (15, 25) -> 2*(5, 5) + (100, 200) = (110, 210)
      final circle = transformed.entities[1] as DxfCircle;
      expect(circle.center, equals(const Offset(110, 210)));
      expect(circle.radius, equals(10.0)); // 5 * 2.0

      // Inverse formula verification:
      // p_local = (p_project - targetControlPoint) / scale + sourceControlPoint
      final recoveredLineEnd = (line.p2 - const Offset(100, 200)) / 2.0 + const Offset(10, 20);
      expect(recoveredLineEnd, equals(const Offset(30, 40)));
    });
  });

  group('BimProjectLibraryService & BimExportService', () {
    late Directory tempDir;
    late BimProjectLibraryService libraryService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('koto_bim_test_');
      libraryService = BimProjectLibraryService(customRootDir: tempDir);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Creates project, saves manifest, loads structural model and exports ZIP', () async {
      final project = await libraryService.createProject(
        name: 'Varna Sea Residence',
        location: 'Varna, Bulgaria',
        storeys: const [
          BimStoreyUnderlay(
            storeyId: 'st_0',
            name: 'Ground Floor',
            elevation: 0.0,
            height: 3.0,
            controlPoint: Offset(50, 50),
          ),
          BimStoreyUnderlay(
            storeyId: 'st_1',
            name: 'Floor 1',
            elevation: 3.0,
            height: 2.80,
            controlPoint: Offset(50, 50),
          ),
        ],
      );

      expect(project.id, isNotEmpty);
      expect(project.name, equals('Varna Sea Residence'));
      expect(project.location, equals('Varna, Bulgaria'));

      // Verify list projects
      final allProjects = await libraryService.listProjects();
      expect(allProjects.length, equals(1));
      expect(allProjects.first.id, equals(project.id));

      // Create structural columns and beams on ground floor
      final struct = StructuralProject(
        title: project.name,
        storeys: [
          StoreyLevel(
            id: 'st_0',
            name: 'Ground Floor',
            elevation: 0.0,
            height: 3.0,
            columns: const [
              StructuralColumn(
                id: 'col_1',
                center: Offset(50, 50),
                width: 0.25,
                height: 0.25,
              ),
            ],
            shearWalls: const [
              StructuralShearWall(
                id: 'wall_1',
                start: Offset(50, 50),
                end: Offset(54, 50),
                thickness: 0.25,
              ),
            ],
          ),
          const StoreyLevel(
            id: 'st_1',
            name: 'Floor 1',
            elevation: 3.0,
            height: 2.80,
          ),
        ],
      );

      final saveOk = await libraryService.saveStructuralProject(project.id, struct);
      expect(saveOk, isTrue);

      final loadedStruct = await libraryService.loadStructuralProject(project.id);
      expect(loadedStruct, isNotNull);
      expect(loadedStruct!.storeys.first.columns.length, equals(1));
      expect(loadedStruct.storeys.first.shearWalls.length, equals(1));

      // Test Export Project ZIP
      final zipFile = await BimExportService.exportProjectZip(
        project: project,
        structural: loadedStruct,
        outputDirectory: tempDir,
      );

      expect(await zipFile.exists(), isTrue);

      // Read ZIP contents and verify entries
      final zipBytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(zipBytes);

      final entryNames = archive.files.map((f) => f.name).toList();
      expect(entryNames, contains('±0.00_st_0.dxf'));
      expect(entryNames, contains('+3.00_st_1.dxf'));
      expect(entryNames, contains('Varna Sea Residence_model.bim.json'));
      expect(entryNames, contains('project.json'));

      // Verify JSON model in zip matches struct
      final bimJsonFile = archive.findFile('Varna Sea Residence_model.bim.json')!;
      final bimJsonString = utf8.decode(bimJsonFile.content as List<int>);
      final bimJsonMap = jsonDecode(bimJsonString) as Map<String, dynamic>;
      expect(bimJsonMap['title'], equals('Varna Sea Residence'));

      // Test Rename
      final renameOk = await libraryService.renameProject(project.id, 'Varna Sea Palace');
      expect(renameOk, isTrue);
      final renamedProject = await libraryService.loadProject(project.id);
      expect(renamedProject?.name, equals('Varna Sea Palace'));

      // Test Delete
      final deleteOk = await libraryService.deleteProject(project.id);
      expect(deleteOk, isTrue);
      final afterDelete = await libraryService.listProjects();
      expect(afterDelete.isEmpty, isTrue);
    });

    test('attachUnderlayFile converts DXF and updates project storeys correctly', () async {
      final tempDir = await Directory.systemTemp.createTemp('bim_test_underlay_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final libraryService = BimProjectLibraryService(customRootDir: tempDir);
      final project = await libraryService.createProject(
        name: 'Underlay Test Project',
        storeys: const [
          BimStoreyUnderlay(storeyId: 's1', name: 'Storey 1', elevation: 0.0),
        ],
      );

      final dummyDxf = File('${tempDir.path}/sample.dxf');
      await dummyDxf.writeAsString('0\nSECTION\n2\nHEADER\n0\nENDSEC\n0\nEOF\n');

      final updatedStorey = await libraryService.attachUnderlayFile(
        project.id,
        's1',
        dummyDxf,
      );

      expect(updatedStorey.hasUnderlay, isTrue);
      expect(updatedStorey.underlayFileName, endsWith('/working.kcad'));

      final underlayFile = await libraryService.getUnderlayFile(project.id, updatedStorey.underlayFileName!);
      expect(underlayFile, isNotNull);
      expect(await underlayFile!.exists(), isTrue);
    });
  });
}
