import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_grid_preset.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_grid_axis.dart';
import 'package:kotoview/src/features/architect/services/architect_grid_axis_tool.dart';
import 'package:kotoview/src/features/architect/widgets/architect_grid_scheme.dart';
import 'package:kotoview/src/features/architect/widgets/architect_project_wizard_dialog.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_workspace_interaction_test.dart' as workspace;

void main() {
  test(
    'Wall axis stays on its core when another axis is only nearly parallel',
    () {
      const other = StructuralGridAxis(
        id: 'a',
        name: 'A',
        start: Offset(-2, 3),
        end: Offset(8, 3),
      );
      final wall = editing.wall(
        'w',
        Offset.zero,
        const Offset(4, .02),
        exterior: true,
      );
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: 's', walls: [wall]),
        axes: [other],
      );
      addTearDown(model.dispose);
      final tool = ArchitectGridAxisTool();
      addTearDown(tool.dispose);
      final result = tool
          .placeOnWall(project: model.project, wall: wall, isBulgarian: false)!
          .$2;
      expect(result.start, wall.coreCenterStart);
      expect(result.end, wall.coreCenterEnd);
    },
  );
  testWidgets(
    'Parallel endpoints update live in the workspace and pinch cancels the group',
    (tester) async {
      const a = StructuralGridAxis(
        id: 'a',
        name: 'A',
        start: Offset.zero,
        end: Offset(8, 0),
      );
      const b = StructuralGridAxis(
        id: 'b',
        name: 'B',
        start: Offset(1, 3),
        end: Offset(6, 3),
      );
      final model = editing.seeded(
        const ArchitectStorey(id: 's', name: 's'),
        axes: [a, b],
      );
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await editing.selectTool(tester, 'axis');
      await editing.hold(tester, const Offset(4, 0));
      final old = model.project;
      final g = await tester.startGesture(
        workspace.screen(tester, a.end),
        pointer: 81,
      );
      await tester.pump(const Duration(milliseconds: 281));
      await g.moveTo(workspace.screen(tester, const Offset(9, 0)));
      await tester.pump();
      expect(
        workspace.overlay(tester).project.gridAxes[1].end,
        const Offset(9, 3),
      );
      expect(model.project, same(old));
      final second = await tester.startGesture(
        workspace.screen(tester, const Offset(2, 2)),
        pointer: 82,
      );
      await second.up();
      await g.up();
      await tester.pumpAndSettle();
      expect(model.project, same(old));
      expect(workspace.overlay(tester).project.gridAxes[1].end, b.end);
    },
  );

  testWidgets(
    '360 by 800 wizard exposes the picker and keypad without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const key = ValueKey('grid-phone-preview');
      if (const bool.fromEnvironment('UPDATE_ARCHITECT_GRID_PREVIEW')) {
        await tester.runAsync(() async {
          final font = FontLoader('Roboto')
            ..addFont(
              Future.value(
                ByteData.sublistView(
                  await File('C:/Windows/Fonts/arial.ttf').readAsBytes(),
                ),
              ),
            );
          await font.load();
          final icons = FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
          await icons.load();
        });
      }
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData.dark(),
            locale: const Locale('bg'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (ctx) => TextButton(
                  onPressed: () => ArchitectProjectWizardDialog.show(ctx),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('architect-wizard-step-1')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('architect-grid-picker')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      Future<void> capture(String path) async {
        if (!const bool.fromEnvironment('UPDATE_ARCHITECT_GRID_PREVIEW')) {
          return;
        }
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(key),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(path).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('docs/images/architect_grid_scheme_phone.png');
      await tester.ensureVisible(find.byKey(const ValueKey('grid-gap-x-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('grid-gap-x-1')));
      await tester.pumpAndSettle();
      expect(find.byType(EditableText), findsNothing);
      expect(tester.takeException(), isNull);
      await capture('docs/images/architect_grid_spacing_phone.png');
    },
  );
  test(
    'Individual bays generate cumulative positions and survive project save',
    () {
      final project = ArchitectProject.starterWithCatalog(
        name: 'Grid',
        spacingsX: [4, 5, 3],
        spacingsY: [2, 7],
      );
      final saved = ArchitectProject.fromJson(project.toJson());
      final vertical = saved.gridAxes.where((a) => a.isVertical).toList();
      final horizontal = saved.gridAxes.where((a) => !a.isVertical).toList();
      expect(vertical.map((a) => a.start.dx), [0, 4, 9, 12]);
      expect(horizontal.map((a) => a.start.dy), [0, 2, 9]);
      expect(
        vertical.every((a) => a.start.dy == -1.5 && a.end.dy == 10.5),
        isTrue,
      );
      expect(
        horizontal.every((a) => a.start.dx == -1.5 && a.end.dx == 13.5),
        isTrue,
      );
      expect(
        ArchitectGridPreset.standardPresets().last.generateAxes(
          spacingsX: [4],
          spacingsY: [5],
        ),
        isEmpty,
      );
      expect(
        () => ArchitectGridPreset.standardPresets().first.generateAxes(
          spacingsX: [0],
          spacingsY: [5],
        ),
        throwsArgumentError,
      );
    },
  );

  for (final angle in [0.0, .63]) {
    test(
      'Dragging a handle previews all parallels, preserves spacing, cancel and Undo ($angle)',
      () {
        Offset rotate(Offset p) => Offset(
          p.dx * math.cos(angle) - p.dy * math.sin(angle),
          p.dx * math.sin(angle) + p.dy * math.cos(angle),
        );
        final a = StructuralGridAxis(
          id: 'a',
          name: 'A',
          start: rotate(Offset.zero),
          end: rotate(const Offset(8, 0)),
        );
        final b = StructuralGridAxis(
          id: 'b',
          name: 'B',
          start: rotate(const Offset(6, 3)),
          end: rotate(const Offset(1, 3)),
        );
        final c = StructuralGridAxis(
          id: 'c',
          name: '1',
          start: rotate(const Offset(4, -1)),
          end: rotate(const Offset(4, 6)),
        );
        final model = editing.seeded(
          const ArchitectStorey(id: 's', name: 's'),
          axes: [a, b, c],
        );
        addTearDown(model.dispose);
        final tool = ArchitectGridAxisTool();
        addTearDown(tool.dispose);
        final old = model.project;
        tool.startHandleDrag(a, false);
        tool.updateHandleDrag(rotate(const Offset(12, .03)), old.gridAxes, 100);
        final preview = tool.previewAxes(old.gridAxes);
        expect(
          (preview[1].start - rotate(const Offset(12, 3))).distance,
          lessThan(1e-8),
        );
        expect(
          (preview[1].end - rotate(const Offset(0, 3))).distance,
          lessThan(1e-8),
        );
        expect(preview[2], same(c));
        expect(model.project, same(old));
        tool.cancelHandleDrag();
        expect(tool.previewAxes(old.gridAxes), same(old.gridAxes));
        tool.startHandleDrag(a, false);
        tool.updateHandleDrag(rotate(const Offset(12, 0)), old.gridAxes, 100);
        model.commit(tool.commitHandleDrag(old, false)!);
        expect(
          (model.project.gridAxes[1].start - rotate(const Offset(12, 3)))
              .distance,
          lessThan(1e-8),
        );
        model.undo();
        expect(model.project, same(old));
      },
    );
  }

  test(
    'Body movement aligns extents without moving parallel line positions',
    () {
      final a = const StructuralGridAxis(
        id: 'a',
        name: 'A',
        start: Offset.zero,
        end: Offset(8, 0),
      );
      final b = const StructuralGridAxis(
        id: 'b',
        name: 'B',
        start: Offset(1, 3),
        end: Offset(6, 3),
      );
      final model = editing.seeded(
        const ArchitectStorey(id: 's', name: 's'),
        axes: [a, b],
      );
      addTearDown(model.dispose);
      final tool = ArchitectGridAxisTool();
      addTearDown(tool.dispose);
      tool.startMoving(a, const Offset(4, 0));
      tool.updateMoving(const Offset(6, 1), model.project.gridAxes, 100);
      final preview = tool.previewAxes(model.project.gridAxes);
      expect(preview[0].start, const Offset(2, 1));
      expect(preview[1].start, const Offset(2, 3));
      expect(preview[1].end, const Offset(10, 3));
      final committed = tool.commitMoving(model.project, false)!;
      expect(
        committed.gridAxes.firstWhere((a) => a.id == 'b').start,
        const Offset(2, 3),
      );
    },
  );

  test('New draft previews and commits the same aligned extents', () {
    const source = StructuralGridAxis(
      id: 'a',
      name: 'A',
      start: Offset(-2, 0),
      end: Offset(8, 0),
    );
    final model = editing.seeded(
      const ArchitectStorey(id: 's', name: 's'),
      axes: [source],
    );
    addTearDown(model.dispose);
    final tool = ArchitectGridAxisTool();
    addTearDown(tool.dispose);
    tool.startDrafting(const Offset(1, 3));
    tool.updateDrafting(const Offset(4, 3), model.project, 100);
    expect(tool.draftStart, const Offset(-2, 3));
    expect(tool.draftEnd, const Offset(8, 3));
    final next = tool
        .commitDrafting(project: model.project, isBulgarian: false)!
        .$2;
    expect(next.start, const Offset(-2, 3));
    expect(next.end, const Offset(8, 3));
    tool.startDrafting(const Offset(1, 5));
    tool.updateDrafting(const Offset(1.01, 5), model.project, 100);
    expect(
      tool.commitDrafting(project: model.project, isBulgarian: false),
      isNull,
    );
  });

  for (final reference in WallReferenceLine.values) {
    test(
      'Axis on insulated wall follows core, aligns and avoids duplicates ($reference)',
      () {
        final wall = editing
            .wall('w', Offset.zero, const Offset(4, 0), exterior: true)
            .copyWith(referenceLine: reference);
        final model = editing.seeded(
          ArchitectStorey(id: 's', name: 's', walls: [wall]),
        );
        addTearDown(model.dispose);
        final tool = ArchitectGridAxisTool();
        addTearDown(tool.dispose);
        final result = tool.placeOnWall(
          project: model.project,
          wall: wall,
          isBulgarian: false,
        )!;
        expect(result.$2.start, wall.coreCenterStart);
        expect(result.$2.end, wall.coreCenterEnd);
        expect(
          tool
              .placeOnWall(project: result.$1, wall: wall, isBulgarian: false)!
              .$1,
          same(result.$1),
        );
      },
    );
  }

  testWidgets(
    'Axis tool click on wall places a core axis and Undo restores the project',
    (tester) async {
      final wall = editing
          .wall('w', const Offset(-2, 0), const Offset(2, 0), exterior: true)
          .copyWith(referenceLine: WallReferenceLine.outer);
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: 's', walls: [wall]),
      );
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await editing.selectTool(tester, 'axis');
      final old = model.project;
      await tester.tapAt(
        workspace.screen(tester, wall.coreCenterStart + wall.unitVector * 2),
      );
      await tester.pumpAndSettle();
      expect(model.project.gridAxes.single.start, wall.coreCenterStart);
      expect(model.project.gridAxes.single.end, wall.coreCenterEnd);
      model.undo();
      await tester.pumpAndSettle();
      expect(model.project, same(old));
    },
  );

  for (final locale in ['en', 'bg']) {
    testWidgets('Phone grid picker and individual keypad work in $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var xs = <double>[4, 4, 4], ys = <double>[5, 5];
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (ctx, set) => SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ArchitectGridScheme(
                    spacingsX: xs,
                    spacingsY: ys,
                    unit: ArchitectUnit.centimeters,
                    onChanged: (x, y) => set(() {
                      xs = x;
                      ys = y;
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final rect = tester.getRect(
        find.byKey(const ValueKey('architect-grid-picker')),
      );
      final gesture = await tester.startGesture(
        rect.topLeft + const Offset(10, 10),
      );
      await gesture.moveTo(
        rect.topLeft + Offset(rect.width * 2.5 / 8, rect.height * 1.5 / 6),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(xs, hasLength(3));
      expect(ys, hasLength(2));
      await tester.tap(find.byKey(const ValueKey('grid-gap-x-1')));
      await tester.pumpAndSettle();
      expect(find.byType(EditableText), findsNothing);
      for (final key in ['6', '5', '0']) {
        await tester.tap(find.byKey(ValueKey('wall-key-$key')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const ValueKey('wall-end')));
      await tester.pumpAndSettle();
      expect(xs[1], 6.5);
      expect(xs[0], 4);
      expect(xs[2], 4);
      expect(ys, [5, 5]);
      await tester.tap(find.byKey(const ValueKey('grid-gap-y-0')));
      await tester.pumpAndSettle();
      for (final key in ['3', '0', '0']) {
        await tester.tap(find.byKey(ValueKey('wall-key-$key')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const ValueKey('wall-end')));
      await tester.pumpAndSettle();
      expect(ys, [3, 5]);
      expect(xs, [4, 6.5, 4]);
      await tester.tapAt(
        rect.topLeft + Offset(rect.width * 7.5 / 8, rect.height * 1.5 / 6),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('grid-gap-x-7')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('grid-gap-x-7')));
      await tester.pumpAndSettle();
      for (final key in ['7', '0', '0']) {
        await tester.tap(find.byKey(ValueKey('wall-key-$key')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const ValueKey('wall-end')));
      await tester.pumpAndSettle();
      expect(xs.last, 7);
      expect(xs[1], 6.5);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Wizard creates the selected bay count and individual spacings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    ArchitectProject? result;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                result = await ArchitectProjectWizardDialog.show(ctx);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('architect-grid-picker')),
    );
    await tester.pumpAndSettle();
    final rect = tester.getRect(
      find.byKey(const ValueKey('architect-grid-picker')),
    );
    await tester.tapAt(
      rect.topLeft + Offset(rect.width * 2.5 / 8, rect.height * 1.5 / 6),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('grid-gap-x-1')));
    await tester.tap(find.byKey(const ValueKey('grid-gap-x-1')));
    await tester.pumpAndSettle();
    for (final digit in ['5', '0', '0']) {
      await tester.tap(find.byKey(ValueKey('wall-key-$digit')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('wall-end')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(result!.gridAxes, hasLength(7));
    expect(result!.gridAxes.where((a) => a.isVertical).map((a) => a.start.dx), [
      0,
      7.2,
      12.2,
      19.4,
    ]);
  });
}
