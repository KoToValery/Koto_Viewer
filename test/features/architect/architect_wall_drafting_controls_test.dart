import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_layers.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/widgets/architect_tool_palette.dart';
import 'package:kotoview/src/features/architect/widgets/architect_wall_reference_control.dart';
import 'architect_wall_core_snapping_test.dart' as core_snapping;

import 'architect_editing_test.dart' as editing;
import 'architect_workspace_interaction_test.dart' as workspace;

const captureKey = ValueKey('wall-drafting-controls-capture');
const source = ArchitectWall(
  id: 'source',
  startPoint: Offset(-3, -2),
  endPoint: Offset(3, -2),
  thickness: .25,
);

Future<void> open(
  WidgetTester tester,
  ArchitectCommandController model, {
  String language = 'en',
  Size size = const Size(1600, 1200),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepaintBoundary(
      key: captureKey,
      child: MaterialApp(
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ArchitectWorkspaceScreen(commandController: model),
      ),
    ),
  );
  await tester.pumpAndSettle();
  workspace.camera(tester).fit(const Rect.fromLTRB(-5, -5, 5, 5), padding: 40);
  await tester.pumpAndSettle();
  await editing.selectTool(tester, 'wall');
}

Future<void> command(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

Future<void> chooseReference(
  WidgetTester tester,
  WallReferenceLine reference, {
  bool toolbar = false,
}) async {
  if (!toolbar) {
    await command(tester, 'wall-panel-reference-${reference.name}');
    return;
  }
  final l = AppLocalizations.of(
    tester.element(find.byType(ArchitectWorkspaceScreen)),
  )!;
  final label = switch (reference) {
    WallReferenceLine.center => l.architectWallReferenceCenter,
    WallReferenceLine.inner => l.architectWallReferenceInner,
    WallReferenceLine.outer => l.architectWallReferenceOuter,
    WallReferenceLine.left => l.architectWallReferenceLeft,
    WallReferenceLine.right => l.architectWallReferenceRight,
  };
  await command(tester, 'wall-toolbar-reference');
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

ArchitectWall preview(WidgetTester tester) {
  final p = workspace.overlay(tester);
  return ArchitectWall(
    id: 'preview',
    startPoint: p.activeDraftStart!,
    endPoint: p.activeDraftEnd!,
    thickness: p.activeWallThickness,
    layers: p.activeWallLayers,
    referenceLine: p.activeWallReference,
    exteriorSide: p.activeWallExteriorSide,
    wallTypeId: p.activeWallTypeId,
    insulationThicknessOverride: p.activeWallInsulation,
  );
}

void expectIdleSelection(WidgetTester tester, String id) {
  final p = workspace.overlay(tester);
  expect(p.selectedElementIds, contains(id));
  expect(p.activeDraftStart, isNull);
  expect(p.activeDraftEnd, isNull);
  expect(find.byKey(const ValueKey('wall-length-input')), findsNothing);
  expect(
    tester
        .widget<ArchitectToolPalette>(find.byType(ArchitectToolPalette))
        .activeTool,
    ArchitectTool.wall,
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await (FontLoader('Roboto')
          ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/NotoSans-Bold.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final language in ['bg', 'en']) {
    for (final size in [const Size(360, 800), const Size(390, 844)]) {
      testWidgets(
        'Reference changes preserve keypad, geometry and phone layout ($language, $size)',
        (tester) async {
          final model = editing.seeded(
            const ArchitectStorey(id: 's', name: ''),
          );
          addTearDown(model.dispose);
          await open(tester, model, language: language, size: size);
          await workspace.wallTap(tester, const Offset(-2, 0));
          await workspace.wallTap(tester, const Offset(1, 0));
          await command(tester, 'wall-length-input');
          for (final key in ['4', '.', '2', '5']) {
            await command(tester, 'wall-key-$key');
          }
          final axis = preview(tester);
          for (final reference in [
            WallReferenceLine.inner,
            WallReferenceLine.outer,
            WallReferenceLine.center,
          ]) {
            await chooseReference(tester, reference);
            final current = preview(tester);
            expect(current.referenceLine, reference);
            expect(current.startPoint, axis.startPoint);
            expect(current.endPoint, axis.endPoint);
            expect(current.length, closeTo(4.25, 1e-9));
            if (reference != WallReferenceLine.center) {
              expect(current.centerStart, isNot(axis.centerStart));
            }
            final controls = tester.widgetList<ArchitectWallReferenceControl>(
              find.byType(ArchitectWallReferenceControl),
            );
            expect(controls, hasLength(2));
            expect(controls.every((c) => c.value == reference), isTrue);
            expect(find.byKey(const ValueKey('wall-key-0')), findsOneWidget);
            expect(model.canUndo, isFalse);
          }
          await chooseReference(tester, WallReferenceLine.outer, toolbar: true);
          expect(preview(tester).referenceLine, WallReferenceLine.outer);
          final beforeFlip = preview(tester);
          await command(tester, 'wall-panel-flip');
          expect(preview(tester).exteriorSide, isNot(beforeFlip.exteriorSide));
          expect(preview(tester).startPoint, beforeFlip.startPoint);
          expect(preview(tester).endPoint, beforeFlip.endPoint);
          expect(find.byKey(const ValueKey('wall-key-0')), findsOneWidget);
          await command(tester, 'wall-panel-curve');
          expect(workspace.overlay(tester).activeWallCurved, isTrue);
          expect(preview(tester).length, closeTo(4.25, 1e-9));
          await command(tester, 'wall-panel-curve');
          expect(workspace.overlay(tester).activeWallCurved, isFalse);
          expect(find.byKey(const ValueKey('wall-key-0')), findsOneWidget);
          expect(model.canUndo, isFalse);
          final next = tester.widget<IconButton>(
            find.byKey(const ValueKey('wall-continue')),
          );
          final colors = Theme.of(
            tester.element(find.byKey(const ValueKey('wall-continue'))),
          ).colorScheme;
          expect(next.style!.backgroundColor!.resolve({}), colors.primary);
          for (final key in [
            'wall-panel-reference',
            'wall-panel-reference-center',
            'wall-panel-reference-inner',
            'wall-panel-reference-outer',
            'wall-panel-flip',
            'wall-panel-curve',
            'wall-toolbar-reference',
            'wall-length-input',
            'wall-key-0',
            'wall-end',
            'wall-continue',
            'wall-cancel',
          ]) {
            final rect = tester.getRect(find.byKey(ValueKey(key)));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(size.width));
            expect(rect.top, greaterThanOrEqualTo(0));
            expect(rect.bottom, lessThanOrEqualTo(size.height));
            expect(find.byKey(ValueKey(key)).hitTestable(), findsOneWidget);
          }
          if (const bool.fromEnvironment('UPDATE_WALL_DRAFT_PREVIEW')) {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(captureKey),
            );
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 2);
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.png,
              ))!;
              await File(
                'scratch/wall_drafting_${language}_${size.width.toInt()}.png',
              ).writeAsBytes(bytes.buffer.asUint8List());
              image.dispose();
            });
          }
          final expected = preview(tester);
          await command(tester, 'wall-end');
          final placed = model.project.activeStorey.walls.single;
          expect(placed.referenceLine, expected.referenceLine);
          expect(placed.startPoint, expected.startPoint);
          expect(placed.endPoint, expected.endPoint);
          expect(placed.centerStart, expected.centerStart);
          expect(model.undoCount, 1);
          await workspace.wallTap(tester, placed.centerPointAt(.5));
          await tester.pumpAndSettle();
          expectIdleSelection(tester, placed.id);
          expect(model.undoCount, 1);
          model.undo();
          await tester.pumpAndSettle();
          expect(model.project.activeStorey.walls, isEmpty);
          model.redo();
          expect(
            model.project.activeStorey.walls.single.referenceLine,
            expected.referenceLine,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'Inside leading line keeps exterior on an upward then rightward chain',
    (tester) async {
      final model = editing.seeded(const ArchitectStorey(id: 's', name: ''));
      addTearDown(model.dispose);
      await open(tester, model);
      await workspace.wallTap(tester, const Offset(-2, -2));
      await workspace.wallTap(tester, const Offset(-2, 1));
      await chooseReference(tester, WallReferenceLine.inner);
      final first = preview(tester);
      expect(first.exteriorNormal.dx, lessThan(0));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.walls, hasLength(1));
      expect(workspace.overlay(tester).activeDraftStart, first.endPoint);
      await workspace.wallTap(tester, const Offset(1, 1));
      final second = preview(tester);
      expect(second.exteriorNormal.dy, greaterThan(0));
      expect(second.exteriorSide, first.exteriorSide);
      await command(tester, 'wall-end');
      expect(
        model.project.activeStorey.walls.last.exteriorSide,
        first.exteriorSide,
      );
      final saved = model.project.toJson();
      model.undo();
      model.redo();
      expect(model.project.toJson(), saved);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Starting on a core face compensates the new wall finishes', (
    tester,
  ) async {
    const host = ArchitectWall(
      id: 'host',
      startPoint: Offset(-3, -2),
      endPoint: Offset(3, -2),
      thickness: .385,
      layers: core_snapping.layers,
    );
    final model = editing.seeded(
      const ArchitectStorey(id: 's', name: '', walls: [host]),
    );
    addTearDown(model.dispose);
    await open(tester, model);
    final coreFace =
        (host.coreCenterStart + host.coreCenterEnd) / 2 +
        host.exteriorNormal * host.coreThickness / 2;
    final gesture = await tester.startGesture(
      workspace.screen(tester, coreFace) + const Offset(0, 64),
    );
    await tester.pump(const Duration(milliseconds: 281));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(workspace.overlay(tester).activeDraftStart, coreFace);
    expect(
      workspace.overlay(tester).activeWallReference,
      WallReferenceLine.outer,
    );
    await workspace.wallTap(tester, coreFace + const Offset(1.3, 0));
    final draft = preview(tester);
    final actualFace =
        draft.coreCenterStart + draft.exteriorNormal * draft.coreThickness / 2;
    expect((actualFace - coreFace).distance, lessThan(1e-7));
    expect((draft.endPoint - draft.startPoint).dy, closeTo(0, 1e-7));
    await command(tester, 'wall-end');
    final placed = model.project.activeStorey.walls.last;
    expect(
      (placed.coreCenterStart +
              placed.exteriorNormal * placed.coreThickness / 2 -
              coreFace)
          .distance,
      lessThan(1e-7),
    );
    expect(tester.takeException(), isNull);
  });

  for (final stop in ['wall-end', 'wall-cancel', 'wall-stop-drawing']) {
    for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
      for (final hold
          in kind == PointerDeviceKind.touch ? [false, true] : [false]) {
        testWidgets(
          'After $stop, $kind hold=$hold selects an existing wall without placement',
          (tester) async {
            final model = editing.seeded(
              const ArchitectStorey(id: 's', name: '', walls: [source]),
            );
            addTearDown(model.dispose);
            await open(tester, model);
            await workspace.wallTap(tester, const Offset(-2, 0));
            await workspace.wallTap(tester, const Offset(0, 0));
            await command(tester, 'wall-continue');
            await workspace.wallTap(tester, const Offset(0, 2));
            await command(tester, stop);
            final original = model.project.toJson();
            final undo = model.undoCount;
            final gesture = await tester.startGesture(
              workspace.screen(tester, source.centerPointAt(.5)),
              kind: kind,
            );
            if (hold) await tester.pump(const Duration(milliseconds: 600));
            await gesture.up();
            await tester.pumpAndSettle();
            expectIdleSelection(tester, source.id);
            expect(model.project.toJson(), original);
            expect(model.undoCount, undo);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets(
    'Manual references survive a chain and new starts, then automatic adoption resumes on tool change',
    (tester) async {
      final model = editing.seeded(
        const ArchitectStorey(id: 's', name: '', walls: [source]),
      );
      addTearDown(model.dispose);
      await open(tester, model);
      await workspace.wallTap(tester, const Offset(-2, 0));
      await workspace.wallTap(tester, const Offset(0, 0));
      await chooseReference(tester, WallReferenceLine.outer);
      await command(tester, 'wall-continue');
      final first = model.project.activeStorey.walls.last;
      final original = first.toJson();
      await workspace.wallTap(tester, const Offset(0, 2));
      expect(preview(tester).referenceLine, WallReferenceLine.outer);
      await chooseReference(tester, WallReferenceLine.inner);
      await command(tester, 'wall-continue');
      await workspace.wallTap(tester, const Offset(-1, 3));
      final expected = preview(tester);
      expect(expected.referenceLine, WallReferenceLine.inner);
      await command(tester, 'wall-end');
      final chain = model.project.activeStorey.walls.skip(1).toList();
      expect(chain.first.toJson(), original);
      expect(chain[1].startPoint, chain[0].endPoint);
      expect(chain[2].startPoint, chain[1].endPoint);
      expect(chain[2].centerStart, expected.centerStart);
      final layers = ArchitectWallLayers.build(chain, model.project.wallTypes);
      for (var x = -.8; x < .8; x += .073) {
        for (var y = -.8; y < 3.5; y += .071) {
          final p = Offset(x, y);
          expect(
            layers.coreRegions.values
                .where((region) => region.contains(p))
                .length,
            layers.core.contains(p) ? 1 : 0,
          );
        }
      }

      Future<void> aimedStart() async {
        final g = await tester.startGesture(
          workspace.screen(tester, source.coreCenterStart) +
              const Offset(0, 64),
        );
        await tester.pump(const Duration(milliseconds: 281));
        await g.up();
        await tester.pumpAndSettle();
      }

      await aimedStart();
      expect(
        workspace.overlay(tester).activeDraftStart,
        source.coreCenterStart,
      );
      expect(
        workspace.overlay(tester).activeWallReference,
        WallReferenceLine.inner,
      );
      await command(tester, 'wall-stop-drawing');
      await aimedStart();
      expect(
        workspace.overlay(tester).activeWallReference,
        WallReferenceLine.inner,
      );
      await command(tester, 'wall-stop-drawing');
      await editing.selectTool(tester, 'column');
      await editing.selectTool(tester, 'wall');
      await aimedStart();
      expect(
        workspace.overlay(tester).activeWallReference,
        WallReferenceLine.center,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Touch selection covers joined ends and near edges; a running draft still snaps to walls',
    (tester) async {
      const a = ArchitectWall(
        id: 'a',
        startPoint: Offset(-3, -2),
        endPoint: Offset(0, -2),
        thickness: .4,
      );
      const b = ArchitectWall(
        id: 'b',
        startPoint: Offset(0, -2),
        endPoint: Offset(0, 1),
        thickness: .4,
      );
      final model = editing.seeded(
        const ArchitectStorey(id: 's', name: '', walls: [a, b]),
      );
      addTearDown(model.dispose);
      await open(tester, model);
      final undo = model.undoCount;
      // Outside a's baseline span, inside the mitred wall outline.
      await workspace.wallTap(tester, const Offset(.1, -2.1));
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).selectedElementIds, isNotEmpty);
      expect(workspace.overlay(tester).activeDraftStart, isNull);
      await command(tester, 'architect-clear-selection');
      final near =
          a.centerPointAt(.5) +
          Offset(0, -.2 - 12 / workspace.camera(tester).scale);
      await workspace.wallTap(tester, near);
      await tester.pumpAndSettle();
      expectIdleSelection(tester, 'a');
      expect(model.undoCount, undo);
      await command(tester, 'architect-clear-selection');
      await workspace.wallTap(tester, const Offset(-2, 2));
      await workspace.wallTap(tester, a.coreCenterStart);
      expect(workspace.overlay(tester).selectedElementIds, isEmpty);
      expect(workspace.overlay(tester).activeDraftStart, isNotNull);
      expect(workspace.overlay(tester).activeDraftEnd, a.coreCenterStart);
      expect(find.byKey(const ValueKey('wall-length-input')), findsOneWidget);
      expect(model.undoCount, undo);
      expect(tester.takeException(), isNull);
    },
  );
}
