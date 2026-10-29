import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall_type.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/services/architect_wall_catalog.dart';
import 'package:kotoview/src/features/architect/services/architect_wall_compositions.dart';
import 'package:kotoview/src/features/architect/widgets/architect_wall_type_picker.dart';
import 'package:kotoview/src/features/architect/widgets/architect_wall_composition_editor.dart';
import 'package:kotoview/src/features/architect/widgets/architect_wall_types_manager.dart';
import 'architect_wall_compositions_test.dart' as data;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Groups preserve identity, core materials and parapet finishes',
    () {
      final catalog = ArchitectWallType.standardCatalog();
      final insulated = catalog.first;
      final other = insulated.copyWith(
        id: 'other',
        insulationThickness: .15,
        totalThickness: .40,
      );
      final groups = ArchitectWallCatalogGroup.build([
        insulated,
        other,
        catalog[2],
        catalog[3],
        catalog.last,
        catalog.last.copyWith(
          id: 'handrail',
          parapetFinish: ParapetFinish.handrailPipes,
        ),
      ]);
      expect(groups.first.types.map((t) => t.id), [
        insulated.id,
        'other',
        catalog[2].id,
      ]);
      expect(groups.length, 4);
      expect(
        ArchitectWallCategory.of(catalog[3]),
        ArchitectWallCategory.interior,
      );
      expect(
        ArchitectWallCategory.of(
          catalog[3].copyWith(location: ArchitectWallLocation.exterior),
        ),
        ArchitectWallCategory.exterior,
      );
      expect(groups.expand((g) => g.types).length, 6);
    },
  );

  test(
    'Unused unnamed project variants survive later edits and JSON; only orphan local drafts are removed',
    () {
      final p = data.project([data.wall('w', Offset.zero, const Offset(4, 0))]);
      final saved = data.composition.copyWith(
        id: 'wall_type_saved',
        name: '',
        isCatalogType: true,
      );
      final local = data.composition.copyWith(
        id: 'wall_type_local',
        name: '',
        isCatalogType: false,
      );
      final first = SetArchitectWallComposition(type: saved).apply(p);
      final second = SetArchitectWallComposition(
        type: local,
        storeyId: 's',
        wallIds: {'w'},
      ).apply(first);
      expect(second.wallTypes.any((t) => t.id == saved.id), isTrue);
      final restored = ArchitectProject.fromJson(
        jsonDecode(jsonEncode(second.toJson())) as Map<String, dynamic>,
      );
      expect(
        restored.wallTypes.firstWhere((t) => t.id == saved.id).isCatalogType,
        isTrue,
      );
      final finalProject = SetArchitectWallComposition(
        type: data.composition,
        storeyId: 's',
        wallIds: {'w'},
      ).apply(restored);
      expect(finalProject.wallTypes.any((t) => t.id == local.id), isFalse);
      expect(finalProject.wallTypes.any((t) => t.id == saved.id), isTrue);
      expect(
        finalProject.activeStorey.walls.single.coreCenterStart,
        p.activeStorey.walls.single.coreCenterStart,
      );
      final legacy = saved.toJson()..remove('isCatalogType');
      expect(ArchitectWallType.fromJson(legacy).isCatalogType, isTrue);
      final empty = p.copyWith(wallTypes: []);
      expect(
        SetArchitectWallComposition(type: saved).apply(empty).wallTypes.length,
        8,
      );
    },
  );

  test('Explicit parapet semantics survive arbitrary IDs and heights', () {
    final type = ArchitectWallType.standardCatalog().last.copyWith(
      id: 'custom',
      customHeight: 1.8,
    );
    final old = data
        .wall('w', Offset.zero, const Offset(4, 0))
        .copyWith(height: 1.8);
    final next = SetArchitectWallComposition(
      type: type,
      storeyId: 's',
      wallIds: {'w'},
    ).apply(data.project([old])).activeStorey.walls.single;
    expect(next.isParapet, isTrue);
    expect(
      ArchitectWall.fromJson(
        jsonDecode(jsonEncode(next.toJson())) as Map<String, dynamic>,
      ).isParapet,
      isTrue,
    );
    expect(old.copyWith(height: .8, parapet: false).isParapet, isFalse);
  });

  testWidgets('Search remains usable above the phone keyboard', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final types = ArchitectWallType.standardCatalog();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('Open'),
              onPressed: () => showArchitectWallTypePicker(
                context,
                types: types,
                activeType: types.first,
                allowVariant: true,
                allowManage: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('wall-catalog-search')),
      'EPS',
    );
    await tester.pumpAndSettle();
    expect(
      tester.getBottomLeft(find.byType(ArchitectWallCatalogBrowser)).dy,
      lessThanOrEqualTo(340),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Selected-wall composition can be saved as an independent reusable type',
    (tester) async {
      final original = data.project([
        data.wall('a', Offset.zero, const Offset(4, 0)),
        data.wall('b', const Offset(0, 3), const Offset(4, 3)),
      ]);
      ArchitectProject? changed;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Open'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => ArchitectWallCompositionEditor(
                    project: original.copyWith(
                      units: ArchitectUnit.centimeters,
                    ),
                    type: data.composition.copyWith(
                      id: 'local',
                      isCatalogType: false,
                    ),
                    allowTypeSelection: true,
                    onApply: (type, _, edited) {
                      expect(edited, isTrue);
                      changed = SetArchitectWallComposition(
                        type: type,
                        storeyId: 's',
                        wallIds: {'a'},
                      ).apply(original);
                      return true;
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('wall-layer-thickness-eps')),
        '15',
      );
      await tester.ensureVisible(find.text('Type details'));
      await tester.tap(find.text('Type details'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('wall-save-to-catalog')),
      );
      await tester.tap(find.byKey(const ValueKey('wall-save-to-catalog')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('wall-composition-save')));
      await tester.pumpAndSettle();
      expect(changed!.wallTypes.last.isCatalogType, isTrue);
      expect(changed!.activeStorey.walls.first.insulationThickness, .15);
      expect(
        changed!.activeStorey.walls.last,
        same(original.activeStorey.walls.last),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Manager edits a used type across floors, with explicit affected count',
    (tester) async {
      final original = data.project([
        data.wall('a', Offset.zero, const Offset(4, 0)),
      ]);
      var project = original.copyWith(
        units: ArchitectUnit.centimeters,
        storeys: [
          original.activeStorey,
          ArchitectStorey(
            id: 'upper',
            name: '1',
            elevation: 3,
            walls: [data.wall('upper-wall', Offset.zero, const Offset(4, 0))],
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Open'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => ArchitectWallTypesManager(
                    project: project,
                    onApply: (next) {
                      project = next;
                      return true;
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('wall-type-row-layered')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('wall-layer-thickness-eps')),
        '15',
      );
      final l = AppLocalizations.of(
        tester.element(find.byType(ArchitectWallCompositionEditor)),
      )!;
      expect(find.text(l.wallTypeApply(2)), findsNWidgets(2));
      await tester.tap(find.byKey(const ValueKey('wall-composition-save')));
      await tester.pumpAndSettle();
      expect(
        project.storeys.every((s) => s.walls.single.insulationThickness == .15),
        isTrue,
      );
      expect(project.wallTypes.length, 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['bg', 'en']) {
    testWidgets(
      'Many variants, global search and project favorites on a 320px phone ($language)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final catalog = ArchitectWallType.standardCatalog();
        final types = [
          ...catalog,
          for (var i = 1; i <= 25; i++)
            catalog.first.copyWith(
              id: 'v$i',
              name: '',
              insulationThickness: i / 100,
              totalThickness: .25 + i / 100,
            ),
          catalog.last.copyWith(id: 'needle', name: 'Needle'),
        ];
        ArchitectWallType? chosen;
        Future<void> open(String id) => tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                height: 700,
                child: ArchitectWallCatalogBrowser(
                  key: ValueKey(id),
                  projectId: 'test',
                  types: types,
                  activeType: catalog.first,
                  unit: ArchitectUnit.centimeters,
                  onSelect: (t) => chosen = t,
                ),
              ),
            ),
          ),
        );
        await open('first');
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(ValueKey('wall-favorite-${catalog.first.id}')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('wall-favorites-filter')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('architect-wall-type-ext_25_12_eps')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('architect-wall-type-ext_25_brick')),
          findsNothing,
        );
        await open('second');
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<IconButton>(
                find.byKey(ValueKey('wall-favorite-${catalog.first.id}')),
              )
              .isSelected,
          isTrue,
        );
        final l = AppLocalizations.of(
          tester.element(find.byType(ArchitectWallCatalogBrowser)),
        )!;
        await tester.tap(find.byTooltip(l.search));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('wall-catalog-search')),
          'Needle',
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('architect-wall-type-needle')),
        );
        await tester.pumpAndSettle();
        expect(chosen!.id, 'needle');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'A variant adds coatings explicitly and inserts a selected material at a chosen boundary',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      ArchitectWallType? saved;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Open'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => ArchitectWallCompositionEditor(
                    project: data
                        .project([])
                        .copyWith(units: ArchitectUnit.centimeters),
                    type: ArchitectWallType.standardCatalog().first.copyWith(
                      id: 'variant',
                    ),
                    isNewType: true,
                    typeUseCount: 0,
                    onApply: (type, _, _) {
                      saved = type;
                      return true;
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('wall-layer-thickness-core')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('wall-layer-coatings')));
      await tester.pumpAndSettle();
      expect(find.text('Total: 39 cm'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('wall-layer-add')));
      await tester.tap(find.byKey(const ValueKey('wall-layer-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('wall-layer-position')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Before 1').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('wall-new-layer-thickness')),
        '0,75',
      );
      await tester.tap(find.byKey(const ValueKey('wall-layer-insert')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('wall-composition-save')));
      await tester.pumpAndSettle();
      expect(saved, isNotNull);
      expect(saved!.layers.length, 5);
      expect(saved!.layers.first.material, ArchitectMaterial.plaster);
      expect(saved!.layers.first.thickness, .0075);
      expect(saved!.totalThickness, closeTo(.3975, 1e-9));
      expect(saved!.name, isEmpty);
      expect(saved!.isCatalogType, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
