import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_slab_assembly.dart';
import 'package:kotoview/src/features/architect/widgets/architect_composition_controls.dart';
import 'package:kotoview/src/features/architect/widgets/architect_roof_layer_editor.dart';
import 'package:kotoview/src/features/architect/widgets/architect_roof_layers_dialog.dart';
import 'package:kotoview/src/features/architect/widgets/architect_roof_number_field.dart';
import 'package:kotoview/src/features/architect/widgets/architect_slab_layers_dialog.dart';
import 'architect_slab_assembly_test.dart' as slab_fixture;
import 'architect_roof_drainage_test.dart' as roof_fixture;

Widget host(WidgetBuilder open, {String locale = 'en'}) => MaterialApp(
  locale: Locale(locale),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Builder(builder: open)),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'inline thickness preserves unchanged imperial precision and rejects invalid input',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const original = .000123456789;
      final changed = <double>[];
      bool? valid;
      await tester.pumpWidget(
        host(
          (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: ArchitectCompositionLayerRow(
              title: 'Thermal insulation between rafters',
              thickness: 'unused',
              onEdit: () {},
              thicknessEditor: ArchitectCompositionThicknessField(
                value: original,
                unit: ArchitectUnit.inches,
                onChanged: changed.add,
                onValidityChanged: (value) => valid = value,
              ),
              actions: IconButton(
                onPressed: () {},
                icon: const Icon(Icons.more_vert),
              ),
            ),
          ),
        ),
      );
      final input = find.byType(TextFormField);
      await tester.enterText(
        input,
        architectCompositionNumber(original, ArchitectUnit.inches),
      );
      expect(changed, isEmpty);
      await tester.enterText(input, '0');
      await tester.pumpAndSettle();
      expect(valid, isFalse);
      expect(changed, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.enterText(input, '0.5');
      await tester.pumpAndSettle();
      expect(valid, isTrue);
      expect(changed.single, closeTo(.0127, 1e-12));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('layer rows reflow long dimensions and enlarged text on phones', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var opened = false;
    await tester.pumpWidget(
      host(
        (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: ArchitectCompositionLayerRow(
            title: 'Thermal insulation between rafters',
            thickness: '1234.56789 mm',
            detail: 'Insulation',
            onEdit: () => opened = true,
            actions: IconButton(
              onPressed: () {},
              icon: const Icon(Icons.more_vert),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(ListTile));
    expect(opened, isTrue);
  });

  testWidgets('search and favorites stay usable above a phone keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    int? selection;
    await tester.pumpWidget(
      host(
        (context) => TextButton(
          child: const Text('Open'),
          onPressed: () async {
            selection = await showArchitectCompositionPicker<int>(
              context,
              title: 'Catalog',
              selectedId: '0',
              preferenceKey: 'test-composition-favorites',
              choices: [
                for (var i = 0; i < 40; i++)
                  ArchitectCompositionChoice(
                    id: '$i',
                    label: 'Option $i',
                    value: i,
                  ),
              ],
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('composition-search')),
      'Option 35',
    );
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('composition-choice-35'));
    await tester.tap(
      find.descendant(of: row, matching: find.byType(IconButton)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(selection, isNull);
    await tester.tap(find.byKey(const ValueKey('composition-choice-35')));
    await tester.pumpAndSettle();
    expect(selection, 35);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('test-composition-favorites'), ['35']);
    tester.view.viewInsets = const FakeViewPadding();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Favorites'));
    await tester.pumpAndSettle();
    expect(find.text('Option 35'), findsOneWidget);
    expect(find.text('Option 0'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final locale in ['bg', 'en']) {
    testWidgets(
      'slab compact editor uses project units and explicit shared scope ($locale)',
      (tester) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final assembly = ArchitectSlabCatalog.preset(SlabUsage.intermediate);
        final p = slab_fixture
            .slabProject(assembly: assembly)
            .copyWith(units: ArchitectUnit.centimeters);
        ArchitectProject? result;
        await tester.pumpWidget(
          host(
            (context) => TextButton(
              child: const Text('Open'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ArchitectSlabLayersDialog(
                  project: p,
                  slab: p.activeStorey.slabs.single,
                  onApply: (value) {
                    result = value;
                    return true;
                  },
                ),
              ),
            ),
            locale: locale,
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final core = find.byKey(const ValueKey('slab-core-thickness'));
        expect(tester.widget<TextField>(core).controller!.text, '20');
        expect(
          find.byKey(const ValueKey('slab-edit-scope-true')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('slab-core-offset')), findsNothing);
        final finish = find.byKey(
          const ValueKey('slab-layer-thickness-finish'),
        );
        await tester.ensureVisible(finish);
        await tester.enterText(
          find.descendant(of: finish, matching: find.byType(TextFormField)),
          '1.2',
        );
        await tester.ensureVisible(core);
        await tester.enterText(core, '22.5');
        await tester.ensureVisible(
          find.byKey(const ValueKey('slab-details-tab')),
        );
        await tester.tap(find.byKey(const ValueKey('slab-details-tab')));
        await tester.pumpAndSettle();
        final offset = find.byKey(const ValueKey('slab-core-offset'));
        await tester.enterText(offset, '1.5');
        await tester.tap(find.byKey(const ValueKey('slab-layers-save')));
        await tester.pumpAndSettle();
        expect(
          result!.activeStorey.slabs.single.thickness,
          closeTo(.225, 1e-12),
        );
        expect(
          result!.activeStorey.slabs.single.coreTopOffset,
          closeTo(.015, 1e-12),
        );
        expect(p.activeStorey.slabs.single.thickness, .2);
        final savedAssembly = result!.slabAssemblies.firstWhere(
          (a) => a.id == result!.activeStorey.slabs.single.assemblyId,
        );
        expect(savedAssembly.above.first.thickness, closeTo(.012, 1e-12));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'roof layer editing uses project units without changing other planes',
    (tester) async {
      final p = roof_fixture.drainageProject().copyWith(
        units: ArchitectUnit.centimeters,
      );
      final roof = p.activeStorey.roofs.first;
      ArchitectRoofLayersResult? result;
      await tester.pumpWidget(
        host(
          (context) => TextButton(
            child: const Text('Open'),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => ArchitectRoofLayersDialog(
                project: p,
                roof: roof,
                initialAssembly: roof.assembly,
                initialSlopeDegrees: roof.slopeDegrees,
                initialEavesOverhang: roof.eavesOverhang,
                initialEavesCut: roof.eavesCut,
                initialTab: 1,
                onApply: (value) => result = value,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final covering = find.byKey(const ValueKey('roof-layer-covering'));
      await tester.ensureVisible(covering);
      final inline = find.byKey(
        const ValueKey('roof-inline-thickness-covering'),
      );
      await tester.enterText(
        find.descendant(of: inline, matching: find.byType(TextFormField)),
        '1.25',
      );
      await tester.tap(
        find.descendant(of: covering, matching: find.text('Clay roof tiles')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<RoofLayerEditorDialog>(find.byType(RoofLayerEditorDialog))
            .unit,
        ArchitectUnit.centimeters,
      );
      final number = find.byKey(const ValueKey('roof-layer-thickness-input'));
      expect(tester.widget<ArchitectRoofNumberField>(number).unit, 'cm');
      await tester.enterText(
        find.descendant(of: number, matching: find.byType(TextFormField)),
        '1.5',
      );
      await tester.tap(find.byKey(const ValueKey('roof-layer-save')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('roof-layer-actions-covering')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplicate layer'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('roof-layers-apply')));
      await tester.pumpAndSettle();
      expect(result!.assembly.layers.first.thickness, .015);
      expect(result!.assembly.layers[1].thickness, .015);
      expect(
        result!.assembly.layers[1].id,
        isNot(result!.assembly.layers.first.id),
      );
      expect(result!.applyToGroup, isFalse);
      expect(roof.assembly.layers.first.thickness, .04);
      expect(tester.takeException(), isNull);
    },
  );
}
