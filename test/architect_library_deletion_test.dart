import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/features/architect/models/architect_line_style.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_slab_assembly.dart';
import 'package:kotoview/src/features/architect/models/architect_wall_type.dart';
import 'package:kotoview/src/features/architect/models/architect_fenestration_style.dart';
import 'package:kotoview/src/features/architect/services/architect_line_styles.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_assemblies.dart';
import 'package:kotoview/src/features/architect/services/architect_slab_assemblies.dart';
import 'package:kotoview/src/features/architect/services/architect_wall_compositions.dart';
import 'package:kotoview/src/features/architect/services/fenestration_library_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Architectural Library Deletion', () {
    test('ArchitectSlabLibrary save and delete', () async {
      const slabAssembly = ArchitectSlabAssembly(
        id: 'test_slab_1',
        customName: 'Custom Slab Test',
        usage: SlabUsage.intermediate,
        above: [],
        below: [],
      );

      final saved = await ArchitectSlabLibrary.save(slabAssembly);
      expect(saved, isTrue);

      var list = await ArchitectSlabLibrary.load();
      expect(list.any((a) => a.id == 'test_slab_1'), isTrue);

      final deleted = await ArchitectSlabLibrary.delete('test_slab_1');
      expect(deleted, isTrue);

      list = await ArchitectSlabLibrary.load();
      expect(list.any((a) => a.id == 'test_slab_1'), isFalse);
    });

    test('ArchitectRoofLibrary save and delete', () async {
      final roofAssembly = ArchitectRoofAssembly.fromPreset(
        ArchitectRoofPreset.pitchedTiles,
      ).copyWith(
        id: 'test_roof_1',
        customName: 'Custom Pitch Roof',
      );

      final saved = await ArchitectRoofLibrary.save(roofAssembly);
      expect(saved, isTrue);

      var list = await ArchitectRoofLibrary.load();
      expect(list.any((a) => a.id == 'test_roof_1'), isTrue);
      expect(list.firstWhere((a) => a.id == 'test_roof_1').customName, 'Custom Pitch Roof');

      final deleted = await ArchitectRoofLibrary.delete('test_roof_1');
      expect(deleted, isTrue);

      list = await ArchitectRoofLibrary.load();
      expect(list.any((a) => a.id == 'test_roof_1'), isFalse);
    });

    test('ArchitectLineStyleLibrary and DeleteArchitectLineStyle', () async {
      const customStyle = ArchitectLineStyle(
        id: 'custom_dash_1',
        name: 'Custom Line',
        segmentsMm: [4.0, 2.0],
      );

      final saved = await ArchitectLineStyleLibrary.save(customStyle);
      expect(saved, isTrue);

      var list = await ArchitectLineStyleLibrary.load();
      expect(list.any((s) => s.id == 'custom_dash_1'), isTrue);

      final deleted = await ArchitectLineStyleLibrary.delete('custom_dash_1');
      expect(deleted, isTrue);

      list = await ArchitectLineStyleLibrary.load();
      expect(list.any((s) => s.id == 'custom_dash_1'), isFalse);

      // Model command test
      final project = ArchitectProject.starter(name: 'Test Proj').copyWith(
        lineStyles: [customStyle],
      );
      final updated = const DeleteArchitectLineStyle('custom_dash_1').apply(project);
      expect(updated.lineStyles.any((s) => s.id == 'custom_dash_1'), isFalse);
    });

    test('DeleteArchitectWallType removes custom wall type from project', () {
      final customWall = ArchitectWallType(
        id: 'wall_custom_1',
        name: 'Custom Wall 30cm',
        totalThickness: 0.30,
        usage: WallUsage.exterior,
      );

      final project = ArchitectProject.starter(name: 'Test Proj').copyWith(
        wallTypes: [customWall],
      );
      expect(project.wallTypes.any((t) => t.id == 'wall_custom_1'), isTrue);

      final updated = DeleteArchitectWallType(customWall.id).apply(project);
      expect(updated.wallTypes.any((t) => t.id == 'wall_custom_1'), isFalse);
    });

    test('FenestrationLibraryService delete custom style', () async {
      final service = FenestrationLibraryService.instance;
      await service.init();

      final customWindow = ArchitectFenestrationStyle.standardCatalog()
          .first
          .copyWith(id: 'custom_window_1', name: 'Custom Big Window');

      await service.saveStyle(customWindow);
      expect(service.getAllStyles().any((s) => s.id == 'custom_window_1'), isTrue);

      final deleted = await service.deleteStyle('custom_window_1');
      expect(deleted, isTrue);
      expect(service.getAllStyles().any((s) => s.id == 'custom_window_1'), isFalse);
    });
  });
}
