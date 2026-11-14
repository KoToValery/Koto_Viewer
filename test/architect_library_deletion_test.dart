import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_hatch_pattern.dart';
import 'package:kotoview/src/features/architect/models/architect_line_style.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_slab_assembly.dart';
import 'package:kotoview/src/features/architect/models/architect_wall_type.dart';
import 'package:kotoview/src/features/architect/models/architect_fenestration_style.dart';
import 'package:kotoview/src/features/architect/services/architect_decorative_library_service.dart';
import 'package:kotoview/src/features/architect/services/architect_hatch_patterns.dart';
import 'package:kotoview/src/features/architect/services/architect_line_styles.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_assemblies.dart';
import 'package:kotoview/src/features/architect/services/architect_slab_assemblies.dart';
import 'package:kotoview/src/features/architect/services/architect_wall_compositions.dart';
import 'package:kotoview/src/features/architect/services/architect_wall_library.dart';
import 'package:kotoview/src/features/architect/services/component_library_service.dart';
import 'package:kotoview/src/features/architect/services/fenestration_library_service.dart';
import 'package:kotoview/src/features/architect/widgets/architect_wall_types_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ArchitectWallLibrary.clearCustomCacheForTesting();
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

    test('Factory presets cannot be deleted across all element libraries', () async {
      // Wall factory presets (standard, factory_*, railing)
      expect(ArchitectWallType.isFactoryId('ext_25_12_eps'), isTrue);
      expect(ArchitectWallType.isFactoryId('factory_brick_120'), isTrue);
      expect(ArchitectWallType.isFactoryId('factory_railing_solidCap'), isTrue);
      expect(ArchitectWallType.isFactoryId('round_logs_240'), isTrue);
      expect(ArchitectWallLibrary.presets.every((t) => t.isFactoryPreset), isTrue);

      final starterProject = ArchitectProject.starterWithCatalog(name: 'Proj');
      expect(
        () => const DeleteArchitectWallType('ext_25_12_eps').apply(starterProject),
        throwsArgumentError,
      );
      expect(
        () => const DeleteArchitectWallType('factory_brick_120').apply(starterProject),
        throwsArgumentError,
      );
      expect(
        () => const DeleteArchitectWallType('factory_railing_solidCap').apply(starterProject),
        throwsArgumentError,
      );
      expect(await ArchitectWallLibrary.deleteCustomType('ext_25_12_eps'), isFalse);

      // Slabs & roofs
      expect(await ArchitectSlabLibrary.delete('slab-ground'), isFalse);
      expect(await ArchitectSlabLibrary.delete('slab-intermediate'), isFalse);
      expect(await ArchitectRoofLibrary.delete('preset_pitchedTiles'), isFalse);
      expect(await ArchitectRoofLibrary.delete(''), isFalse);

      // Line styles & hatch patterns
      expect(await ArchitectLineStyleLibrary.delete('dashed'), isFalse);
      expect(await ArchitectHatchPatternLibrary.delete('diagonal'), isFalse);
      expect(
        await ArchitectHatchPatternLibrary.save(ArchitectHatchPattern.diagonal),
        isFalse,
      );

      // Openings, components, decorative
      final fenService = FenestrationLibraryService.instance;
      await fenService.init();
      expect(
        await fenService.deleteStyle(ArchitectFenestrationStyle.standardCatalog().first.id),
        isFalse,
      );

      final compService = ComponentLibraryService.instance;
      await compService.init();
      expect(
        await compService.deleteCustomScript(compService.getAllDefinitions().first.id),
        isFalse,
      );

      final decorService = ArchitectDecorativeLibraryService.instance;
      await decorService.init();
      expect(
        await decorService.deleteTemplate(
          ArchitectDecorativeElement.standardCatalog().first.id,
        ),
        isFalse,
      );
    });

    test('Custom wall types and hatch patterns share cleanly across projects', () async {
      const customWall = ArchitectWallType(
        id: 'wall_type_cross_1',
        name: 'Cross-Project Wall 32cm',
        usage: WallUsage.exterior,
        totalThickness: 0.32,
        brickThickness: 0.20,
        insulationThickness: 0.12,
        isCatalogType: true,
      );
      final projectA = ArchitectProject.starterWithCatalog(name: 'Project A').copyWith(
        wallTypes: [
          ...ArchitectWallType.standardCatalog(),
          customWall,
        ],
      );
      await ArchitectWallLibrary.syncFromProject(projectA);

      const customHatch = ArchitectHatchPattern(
        id: 'custom_hatch_cross_1',
        name: 'Cross Hatch',
        layers: [
          ArchitectHatchLayer(
            angleDeg: 45,
            spacingMm: 10,
            lineStyle: ArchitectLineStyle.solid,
          ),
        ],
      );
      expect(await ArchitectHatchPatternLibrary.save(customHatch), isTrue);

      // Simulate cold cache in Project B (only SharedPreferences has data)
      ArchitectWallLibrary.clearCustomCacheForTesting();
      final loadedWalls = await ArchitectWallLibrary.loadCustomTypes();
      expect(loadedWalls.any((t) => t.id == 'wall_type_cross_1'), isTrue);

      final projectB = ArchitectProject.starterWithCatalog(name: 'Project B');
      final availableInB = ArchitectWallLibrary.available(projectB.wallTypes);
      expect(availableInB.any((t) => t.id == 'wall_type_cross_1'), isTrue);

      final mergedB = ArchitectWallLibrary.mergeCustomTypes(projectB);
      expect(mergedB.wallTypes.any((t) => t.id == 'wall_type_cross_1'), isTrue);

      final loadedHatches = await ArchitectHatchPatternLibrary.load();
      expect(loadedHatches.any((h) => h.id == 'custom_hatch_cross_1'), isTrue);

      // Deleting custom hatch works; factory remains
      expect(await ArchitectHatchPatternLibrary.delete('custom_hatch_cross_1'), isTrue);
      expect(await ArchitectHatchPatternLibrary.load(), isEmpty);

      // Deleting custom wall removes from global catalog
      expect(await ArchitectWallLibrary.deleteCustomType('wall_type_cross_1'), isTrue);
      expect(
        ArchitectWallLibrary.available(projectB.wallTypes)
            .any((t) => t.id == 'wall_type_cross_1'),
        isFalse,
      );
    });

    testWidgets(
      'ArchitectWallTypesManager hides Delete on factory walls and allows deleting custom walls',
      (tester) async {
        const customWall = ArchitectWallType(
          id: 'wall_custom_ui_1',
          name: 'Custom Studio Wall',
          usage: WallUsage.interior,
          totalThickness: 0.14,
          brickThickness: 0.14,
          isCatalogType: true,
        );
        await ArchitectWallLibrary.saveCustomType(customWall);
        var project = ArchitectProject.starterWithCatalog(name: 'UI Test');

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ArchitectWallTypesManager(
                project: project,
                onApply: (next) {
                  project = next;
                  return true;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Factory wall row ('ext_25_12_eps') menu must NOT have a delete item
        final factoryInk = find.byKey(const ValueKey('wall-type-row-ext_25_12_eps'));
        expect(factoryInk, findsOneWidget);
        final factoryRow = find.ancestor(
          of: factoryInk,
          matching: find.byType(Row),
        ).first;
        final factoryMenu = find.descendant(
          of: factoryRow,
          matching: find.byType(PopupMenuButton<String>),
        );
        await tester.tap(factoryMenu);
        await tester.pumpAndSettle();
        final l = AppLocalizations.of(tester.element(find.byType(ArchitectWallTypesManager)))!;
        expect(find.text(l.wallTypeCopy), findsOneWidget);
        expect(find.text(l.delete), findsNothing);

        // Close popup menu
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();

        // Switch to Interior tab where customWall lives
        await tester.tap(find.text(l.wallCategoryInterior));
        await tester.pumpAndSettle();

        final customInk = find.byKey(const ValueKey('wall-type-row-wall_custom_ui_1'));
        expect(customInk, findsOneWidget);
        final customRow = find.ancestor(
          of: customInk,
          matching: find.byType(Row),
        ).first;
        final customMenu = find.descendant(
          of: customRow,
          matching: find.byType(PopupMenuButton<String>),
        );
        await tester.tap(customMenu);
        await tester.pumpAndSettle();
        expect(find.text(l.delete), findsOneWidget);

        await tester.tap(find.text(l.delete));
        await tester.pumpAndSettle();
        // Confirm delete dialog
        await tester.tap(find.widgetWithText(FilledButton, l.delete));
        await tester.pumpAndSettle();

        expect(project.wallTypes.any((t) => t.id == 'wall_custom_ui_1'), isFalse);
        final remainingCustom = await ArchitectWallLibrary.loadCustomTypes();
        expect(remainingCustom.any((t) => t.id == 'wall_custom_ui_1'), isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
