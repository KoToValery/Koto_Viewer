import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_settings_commands.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_tool.dart';
import 'package:kotoview/src/features/architect/widgets/architect_roof_layers_dialog.dart';
import 'package:kotoview/src/features/architect/widgets/architect_roof_layer_editor.dart';
import 'package:kotoview/src/features/architect/widgets/architect_roof_bar.dart';
import 'package:kotoview/src/features/architect/widgets/architect_roof_number_field.dart';
import 'package:kotoview/src/features/architect/widgets/architect_auto_roof_preview_dialog.dart';
import 'architect_roof_drainage_test.dart' as fixture;

ArchitectProject groupProject() {
  final p = fixture.drainageProject();
  final a = p.activeStorey.roofs.first.copyWith(roofGroupId: 'group');
  final b = a.copyWith(
    id: 'other',
    slopeDegrees: 35,
    baseElevationOffset: 9,
    attachToWalls: false,
    eavesOverhang: .8,
    drainage: a.drainage.copyWith(
      material: ArchitectDrainageMaterial.copper,
      downpipes: [const ArchitectDownpipe(id: 'other-pipe', offset: 4)],
    ),
  );
  final annex = a.copyWith(id: 'annex', roofGroupId: 'annex');
  return p.copyWith(
    storeys: [
      p.activeStorey.copyWith(roofs: [a, b, annex]),
    ],
  );
}

void main() {
  test('Partial between-rafter insulation shares the framing depth', () {
    final assembly = ArchitectRoofAssembly.fromPreset(
      ArchitectRoofPreset.warmPitched,
    );
    final index = assembly.layers.indexWhere((l) => l.isBetweenRafters);
    final partial = assembly.copyWith(
      layers: [
        for (var i = 0; i < assembly.layers.length; i++)
          i == index
              ? assembly.layers[i].copyWith(thickness: .10)
              : assembly.layers[i],
      ],
    );
    expect(partial.totalThickness, assembly.totalThickness);
    expect(partial.layers[index].thickness, .10);
    expect(
      partial.layerDepth(partial.layers[index]),
      assembly.timber.rafterHeight,
    );
  });
  test(
    'Group edits preserve unedited pitches, elevations, pipe positions and style; one Undo',
    () {
      final p = groupProject(), model = ArchitectCommandController(p);
      final original = model.project.activeStorey.roofs;
      addTearDown(model.dispose);
      final settings = ArchitectRoofLayersResult(
        assembly: original.first.assembly,
        slopeDegrees: 22,
        eavesOverhang: 0,
        eavesCut: ArchitectRoofEavesCut.plumb,
        applyToGroup: true,
        drainage: original.first.drainage.copyWith(
          gutterWidth: .22,
          downpipes: [const ArchitectDownpipe(id: 'pipe', offset: 3)],
        ),
        changes: {ArchitectRoofSetting.gutterWidth, ArchitectRoofSetting.pipes},
      );
      model.execute(
        ApplyArchitectRoofSettings(
          storeyId: 's',
          roofId: 'roof',
          settings: settings,
        ),
      );
      final roofs = model.project.activeStorey.roofs;
      expect(roofs[1].slopeDegrees, 35);
      expect(roofs[1].baseElevationOffset, 9);
      expect(roofs[1].eavesOverhang, .8);
      expect(roofs[1].drainage.gutterWidth, .22);
      expect(roofs[1].drainage.material, ArchitectDrainageMaterial.copper);
      expect(roofs[1].drainage.downpipes.single.offset, 4);
      expect(roofs[1].drainage.downpipes.single.id, 'other-pipe');
      expect(roofs[0].drainage.downpipes.single.offset, 3);
      expect(roofs[2].toJson(), original[2].toJson());
      expect(model.undoCount, 1);
      model.undo();
      expect(
        model.project.activeStorey.roofs[1].toJson(),
        original[1].toJson(),
      );
    },
  );
  test(
    'A single pitch edit detaches only that plane and does not mutate defaults',
    () {
      final p = groupProject(), r = p.activeStorey.roofs.first;
      final tool = ArchitectRoofTool();
      addTearDown(tool.dispose);
      final next = ApplyArchitectRoofSettings(
        storeyId: 's',
        roofId: r.id,
        settings: ArchitectRoofLayersResult(
          assembly: r.assembly,
          slopeDegrees: 27.25,
          eavesOverhang: r.eavesOverhang,
          eavesCut: r.eavesCut,
          changes: {ArchitectRoofSetting.slope},
        ),
      ).apply(p);
      expect(next.activeStorey.roofs.first.isSlopeLocked, isFalse);
      expect(next.activeStorey.roofs[1], same(p.activeStorey.roofs[1]));
      expect(tool.slopeDegrees, 22);
      tool.setPreset(ArchitectRoofPreset.flatWarm);
      expect(tool.slopeDegrees, 22);
      expect(tool.eavesOverhang, .5);
    },
  );
  test(
    'Reviewed generation preserves other roofs and uses the customized assembly',
    () {
      final base = groupProject();
      final p = base.copyWith(
        storeys: [
          base.activeStorey.copyWith(
            walls: [
              ...base.activeStorey.walls,
              const ArchitectWall(
                id: 'side',
                startPoint: Offset(0, 1),
                endPoint: Offset(0, 5),
              ),
            ],
          ),
        ],
      );
      final tool = ArchitectRoofTool();
      addTearDown(tool.dispose);
      final changed = tool.activeAssembly.copyWith(
        preset: ArchitectRoofPreset.custom,
        layers: [
          ...tool.activeAssembly.layers.take(3),
          tool.activeAssembly.layers[3].copyWith(thickness: .0002),
          ...tool.activeAssembly.layers.skip(4),
        ],
      );
      tool.setAssembly(changed);
      final generated = ArchitectRoofTool.generateAutoRoof(
        project: p,
        type: AutoRoofType.shed,
        tool: tool,
      );
      expect(generated, isNotEmpty);
      expect(generated.first.assembly.layers[3].thickness, .0002);
      final model = ArchitectCommandController(p);
      addTearDown(model.dispose);
      model.execute(
        CreateReviewedArchitectRoofs(
          storeyId: 's',
          roofs: generated,
          replaceIds: {'roof', 'other'},
        ),
      );
      expect(model.project.activeStorey.roofs.first.id, 'annex');
      expect(model.project.activeStorey.roofs.length, generated.length + 1);
      expect(model.undoCount, 1);
      model.undo();
      expect(model.project.activeStorey.roofs.length, 3);
    },
  );

  test('Mansard edits reject a break beyond the supported roof run', () {
    final p = groupProject();
    final r = p.activeStorey.roofs.first.copyWith(isMansard: true);
    final project = p.copyWith(
      storeys: [
        p.activeStorey.copyWith(roofs: [r]),
      ],
    );
    expect(
      () => ApplyArchitectRoofSettings(
        storeyId: r.storeyId,
        roofId: r.id,
        settings: ArchitectRoofLayersResult(
          assembly: r.assembly,
          slopeDegrees: r.slopeDegrees,
          eavesOverhang: r.eavesOverhang,
          eavesCut: r.eavesCut,
          breakDistance: r.maxSlopeRun + 1,
          changes: {ArchitectRoofSetting.breakDistance},
        ),
      ).apply(project),
      throwsArgumentError,
    );
  });

  testWidgets('An automatic mansard break stays independent of tool defaults', (
    tester,
  ) async {
    final p = groupProject();
    final r = p.activeStorey.roofs.first.copyWith(
      isMansard: true,
      clearBreakDistance: true,
    );
    ArchitectRoofLayersResult? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('Open'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ArchitectRoofLayersDialog(
                  project: p,
                  roof: r,
                  initialAssembly: r.assembly,
                  initialSlopeDegrees: r.slopeDegrees,
                  initialEavesOverhang: r.eavesOverhang,
                  initialEavesCut: r.eavesCut,
                  initialBreakDistance: 1.8,
                  onApply: (v) => result = v,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('roof-break-input')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('roof-layers-apply')));
    await tester.pumpAndSettle();
    expect(result!.breakDistance, isNull);
    expect(result!.changes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final language in ['bg', 'en']) {
    for (final mm in [.2, 400.0]) {
      testWidgets(
        'Exact layer $mm mm opens and saves without clamping ($language)',
        (tester) async {
          tester.view.physicalSize = const Size(320, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final layer = ArchitectRoofLayer(
            id: 'fine',
            role: ArchitectRoofLayerRole.underlayment,
            material: ArchitectRoofMaterial.breathableMembrane,
            thickness: mm / 1000,
          );
          RoofLayerEditResult? result;
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    child: const Text('Open'),
                    onPressed: () async {
                      result = await showDialog<RoofLayerEditResult>(
                        context: context,
                        builder: (_) => RoofLayerEditorDialog(
                          layer: layer,
                          layers: [layer],
                          index: 0,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('roof-layer-save')));
          await tester.pumpAndSettle();
          expect(result!.layer.thickness, layer.thickness);
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets(
      'Preset change preserves shape and the scope is explicit ($language)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        ArchitectRoofLayersResult? result;
        final p = groupProject(), r = p.activeStorey.roofs.first;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  child: const Text('Open'),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => ArchitectRoofLayersDialog(
                      initialAssembly: r.assembly,
                      initialSlopeDegrees: 65.25,
                      initialEavesOverhang: .835,
                      initialEavesCut: r.eavesCut,
                      project: p,
                      roof: r,
                      initialTab: 1,
                      onApply: (v) => result = v,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final l = AppLocalizations.of(
          tester.element(find.byType(ArchitectRoofLayersDialog)),
        )!;
        await tester.tap(
          find.byKey(ValueKey('roof-preset-${r.assembly.preset.name}')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(l.architectRoofPresetFlatWarm).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text(l.roofUiShape));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('roof-overhang-input')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('roof-layers-apply')));
        await tester.pumpAndSettle();
        expect(result!.slopeDegrees, 65.25);
        expect(result!.eavesOverhang, .835);
        expect(result!.saveForNewRoofs, isFalse);
        expect(result!.applyToGroup, isFalse);
        expect(result!.changes, {ArchitectRoofSetting.assembly});
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Numeric percent entry and a group change are reviewed together',
    (tester) async {
      ArchitectRoofQuickValue? result;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Open'),
                onPressed: () async {
                  result = await showArchitectRoofNumber(
                    context,
                    label: 'Pitch',
                    value: 22,
                    unit: '°',
                    pitch: true,
                    max: 80,
                    groupCount: 2,
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DropdownButton<bool>, '°'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('%').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('roof-quick-value')),
        '100',
      );
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byKey(const ValueKey('roof-quick-value'))),
      )!;
      await tester.tap(find.byType(DropdownButtonFormField<bool>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.roofUiWholeRoof(2)).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.applyAction));
      await tester.pumpAndSettle();
      expect(result!.value, closeTo(45, 1e-9));
      expect(result!.applyToGroup, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [320.0, 390.0, 1200.0]) {
    for (final language in ['bg', 'en']) {
      testWidgets('Context bar fits all roof states at $width ($language)', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final tool = ArchitectRoofTool();
        addTearDown(tool.dispose);
        final p = groupProject();
        Future<void> show(ArchitectRoofPlane? roof, {int? edge}) =>
            tester.pumpWidget(
              MaterialApp(
                locale: Locale(language),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  bottomNavigationBar: ArchitectRoofBar(
                    tool: tool,
                    selectedRoof: roof,
                    selectedEdgeIndex: edge,
                    groupCount: 2,
                    onAutoRoof: (_) {},
                    onOpenLayersDialog: () {},
                    onSetSelectedEdgeAsEaves: () {},
                  ),
                ),
              ),
            );
        await show(null);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await show(p.activeStorey.roofs.first, edge: 1);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('roof-overhang-menu')), findsNothing);
        expect(find.byKey(const ValueKey('roof-open-assembly')), findsOneWidget);
        expect(tester.takeException(), isNull);
        tool.setDrawMode(RoofDrawMode.polygon);
        for (final point in const [Offset(0, 0), Offset(4, 0), Offset(4, 4)]) {
          tool.addDraftPoint(point, storey: p.activeStorey);
        }
        await show(null);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('roof-poly-finish-front')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets(
    'Auto preview can cancel and replace one group without touching the annex',
    (tester) async {
      final p = groupProject(),
          generated = [
            p.activeStorey.roofs.first.copyWith(
              id: 'new',
              roofGroupId: 'new-group',
            ),
          ];
      Set<String>? replace;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Open'),
                onPressed: () async {
                  replace = await showDialog<Set<String>>(
                    context: context,
                    builder: (_) => ArchitectAutoRoofPreviewDialog(
                      project: p,
                      generated: generated,
                      type: AutoRoofType.shed,
                      selectedRoofId: 'roof',
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(ArchitectAutoRoofPreviewDialog)),
      )!;
      await tester.tap(find.text(l.cancel));
      await tester.pumpAndSettle();
      expect(replace, isNull);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('roof-auto-apply')));
      await tester.pumpAndSettle();
      expect(replace, {'roof', 'other'});
      expect(tester.takeException(), isNull);
    },
  );
}
