import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_grid_axis.dart';
import 'package:kotoview/src/features/architect/rendering/architect_ghost_storey_painter.dart';
import 'package:kotoview/src/features/architect/services/architect_grid_axis_tool.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_workspace_interaction_test.dart' as workspace;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Automatic axes filter core thickness, merge fragments, align and Undo once',
    () {
      final model = editing.seeded(
        const ArchitectStorey(
          id: 's',
          name: 'Floor',
          walls: [
            ArchitectWall(
              id: 'a',
              startPoint: Offset(-3, 0),
              endPoint: Offset.zero,
              thickness: .37,
              wallTypeId: 'ext_25_12_eps',
            ),
            ArchitectWall(
              id: 'b',
              startPoint: Offset.zero,
              endPoint: Offset(2, 0),
            ),
            ArchitectWall(
              id: 'c',
              startPoint: Offset(-1, 3),
              endPoint: Offset(1, 3),
            ),
            ArchitectWall(
              id: 'narrow',
              startPoint: Offset(0, 5),
              endPoint: Offset(2, 5),
              thickness: .12,
            ),
          ],
        ),
      );
      addTearDown(model.dispose);
      final tool = ArchitectGridAxisTool();
      addTearDown(tool.dispose);
      final original = model.project;
      final result = tool.generateOnWalls(
        project: original,
        coreThickness: .25,
        isBulgarian: false,
      );
      expect(result.walls, 3);
      expect(result.added, 2);
      model.commit(result.project);
      expect(model.undoCount, 1);
      for (final axis in model.project.gridAxes) {
        expect(axis.id, startsWith('axis_auto_'));
        expect(axis.start.dx, -3);
        expect(axis.end.dx, 2);
        expect(axis.start.dy, axis.end.dy);
      }
      final again = tool.generateOnWalls(
        project: model.project,
        coreThickness: .25,
        isBulgarian: false,
      );
      expect(again.added, 0);
      model.commit(again.project);
      expect(model.undoCount, 1);
      model.undo();
      expect(model.project, same(original));
      model.redo();
      expect(model.project.gridAxes, hasLength(2));
      final narrow = tool.generateOnWalls(
        project: original,
        coreThickness: .12,
        isBulgarian: true,
      );
      expect(narrow.added, 1);
      expect(narrow.project.gridAxes.single.start.dy, 5);
      final none = tool.generateOnWalls(
        project: original,
        coreThickness: .20,
        isBulgarian: false,
      );
      expect(none.project, same(original));
      expect(none.walls, 0);
    },
  );

  for (final reference in WallReferenceLine.values) {
    test('Automatic oblique axis follows core with $reference reference', () {
      final wall = ArchitectWall(
        id: 'w',
        startPoint: const Offset(2, 1),
        endPoint: const Offset(5, 5),
        thickness: .37,
        wallTypeId: 'ext_25_12_eps',
        referenceLine: reference,
      );
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: 'Floor', walls: [wall]),
      );
      addTearDown(model.dispose);
      final tool = ArchitectGridAxisTool();
      addTearDown(tool.dispose);
      final result = tool.generateOnWalls(
        project: model.project,
        coreThickness: .25,
        isBulgarian: false,
      );
      expect(result.added, 1);
      expect(result.project.gridAxes.single.start, wall.coreCenterStart);
      expect(result.project.gridAxes.single.end, wall.coreCenterEnd);
      tool.selectAxis(result.project.gridAxes.single.id);
      tool.startHandleDrag(result.project.gridAxes.single, false);
      tool.updateHandleDrag(
        wall.coreCenterEnd + wall.unitVector,
        result.project.gridAxes,
        60,
      );
      final moved = tool.commitHandleDrag(result.project, false)!;
      expect(moved.gridAxes.single.length, closeTo(wall.length + 1, 1e-6));
    });
  }

  test(
    'Automatic axes use manual reference extents without overwriting them',
    () {
      final manual = const StructuralGridAxis(
        id: 'manual',
        name: 'Custom',
        start: Offset(-10, 4),
        end: Offset(10, 4),
      );
      final model = editing.seeded(
        const ArchitectStorey(
          id: 's',
          name: 'Floor',
          walls: [
            ArchitectWall(
              id: 'w',
              startPoint: Offset(-2, 0),
              endPoint: Offset(2, 0),
            ),
          ],
        ),
      );
      addTearDown(model.dispose);
      final project = model.project.copyWithGridAxes([manual]);
      final tool = ArchitectGridAxisTool();
      addTearDown(tool.dispose);
      final result = tool.generateOnWalls(
        project: project,
        coreThickness: .25,
        isBulgarian: false,
      );
      final original = result.project.gridAxes.firstWhere(
        (axis) => axis.id == 'manual',
      );
      final generated = result.project.gridAxes.firstWhere(
        (axis) => axis.id != 'manual',
      );
      expect(original.start, manual.start);
      expect(original.end, manual.end);
      expect(generated.start, const Offset(-10, 0));
      expect(generated.end, const Offset(10, 0));
    },
  );

  test('Display units leave geometry and history intact through Undo/Redo', () {
    final model = workspace.commands();
    addTearDown(model.dispose);
    model.execute(
      const CreateArchitectWall(
        storeyId: 's',
        wall: ArchitectWall(
          id: 'w',
          startPoint: Offset.zero,
          endPoint: Offset(4, 0),
        ),
      ),
    );
    model.setUnits(ArchitectUnit.millimeters);
    expect(model.undoCount, 1);
    expect(
      model.project.activeStorey.walls.single.endPoint,
      const Offset(4, 0),
    );
    model.undo();
    expect(model.project.units, ArchitectUnit.millimeters);
    expect(model.project.activeStorey.walls, isEmpty);
    model.redo();
    expect(model.project.units, ArchitectUnit.millimeters);
    expect(
      model.project.activeStorey.walls.single.endPoint,
      const Offset(4, 0),
    );
  });

  test('Ghost floors are only the nearest neighbors in elevation order', () {
    final model = workspace.commands();
    addTearDown(model.dispose);
    final project = model.project.copyWith(
      storeys: const [
        ArchitectStorey(id: 'far', name: 'Far', elevation: 12),
        ArchitectStorey(id: 'above', name: 'Above', elevation: 6),
        ArchitectStorey(id: 's', name: 'Current', elevation: 3),
        ArchitectStorey(id: 'below', name: 'Below', elevation: 0),
      ],
    );
    expect(ArchitectGhostStoreyPainter.neighbors(project).map((s) => s.id), [
      'below',
      'above',
    ]);
  });

  for (final language in ['en', 'bg']) {
    testWidgets(
      'Phone quick settings, units and small cancel control in $language',
      (tester) async {
        const previewKey = ValueKey('architect-settings-preview');
        final capture =
            language == 'bg' &&
            const bool.fromEnvironment('UPDATE_ARCHITECT_SETTINGS_PREVIEW');
        if (capture) {
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
        Future<void> preview(String path) async {
          if (!capture) return;
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(previewKey),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            await File(path).writeAsBytes(bytes.buffer.asUint8List());
            image.dispose();
          });
        }

        final model = workspace.commands();
        addTearDown(model.dispose);
        final floors = model.project.copyWith(
          storeys: const [
            ArchitectStorey(id: 's', name: 'Floor'),
            ArchitectStorey(
              id: 'upper',
              name: 'Upper',
              elevation: 3,
              walls: [
                ArchitectWall(
                  id: 'ghost',
                  startPoint: Offset.zero,
                  endPoint: Offset(4, 0),
                ),
              ],
            ),
          ],
        );
        model.restore(floors);
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final app = MaterialApp(
          theme: ThemeData.dark(),
          debugShowCheckedModeBanner: false,
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ArchitectWorkspaceScreen(commandController: model),
        );
        await tester.pumpWidget(RepaintBoundary(key: previewKey, child: app));
        await tester.pumpAndSettle();
        final l = AppLocalizations.of(
          tester.element(find.byType(ArchitectWorkspaceScreen)),
        )!;
        expect(find.text(l.architectStudioSubtitle), findsNothing);
        for (final key in [
          'architect-undo',
          'architect-redo',
          'architect-ghost-storeys',
          'architect-settings',
          'architect-more',
        ]) {
          final rect = tester.getRect(find.byKey(ValueKey(key)));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(360));
        }
        await tester.tap(find.byKey(const ValueKey('architect-ghost-storeys')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widgetList<CustomPaint>(find.byType(CustomPaint))
              .where((w) => w.painter is ArchitectGhostStoreyPainter),
          hasLength(1),
        );
        expect(model.canUndo, isFalse);
        await preview('docs/images/architect_quick_settings_phone.png');
        await tester.tap(find.byKey(const ValueKey('architect-settings')));
        await tester.pumpAndSettle();
        await preview('docs/images/architect_settings_phone.png');
        await tester.tap(
          find.byKey(const ValueKey('architect-settings-units')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('mm').last);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('architect-settings-dimension-scale')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('1:50').last);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('architect-settings-grid')));
        await tester.tap(find.byKey(const ValueKey('architect-settings-grid')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('architect-settings-save')));
        await tester.pumpAndSettle();
        expect(model.project.units, ArchitectUnit.millimeters);
        expect(model.project.dimensionScale, ArchitectDimensionScale.scale50);
        expect(
          workspace.overlay(tester).project.dimensionScale,
          ArchitectDimensionScale.scale50,
        );
        expect(model.canUndo, isFalse);
        expect(workspace.overlay(tester).paintGrid, isFalse);
        final preferences = await SharedPreferences.getInstance();
        expect(preferences.getBool('architect_ghost_storeys'), isTrue);
        expect(preferences.getBool('architect_drawing_grid'), isFalse);
        await editing.selectTool(tester, 'wall');
        // A ghost is view-only: clicking its footprint still starts on this empty floor.
        await workspace.wallTap(tester, const Offset(1, 0));
        await tester.pumpAndSettle();
        final cancel = find.byKey(const ValueKey('architect-draft-cancel'));
        expect(cancel, findsOneWidget);
        expect(
          tester.getSize(
            find.byKey(const ValueKey('architect-draft-cancel-mark')),
          ),
          const Size(22, 22),
        );
        await preview('docs/images/architect_small_draft_cancel_phone.png');
        await tester.tap(cancel);
        await tester.pumpAndSettle();
        expect(model.canUndo, isFalse);
        expect(cancel, findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Axis wall click wins over a crossing axis endpoint and uses core center',
    (tester) async {
      final wall = const ArchitectWall(
        id: 'w',
        startPoint: Offset(-2, 0),
        endPoint: Offset(2, 0),
        thickness: .37,
        wallTypeId: 'ext_25_12_eps',
        referenceLine: WallReferenceLine.outer,
      );
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: 'Floor', walls: [wall]),
      );
      addTearDown(model.dispose);
      model.replaceView(
        model.project.copyWithGridAxes([
          StructuralGridAxis(
            id: 'crossing',
            name: '1',
            start: wall.coreCenterStart + wall.unitVector * 2,
            end:
                wall.coreCenterStart + wall.unitVector * 2 + const Offset(0, 3),
          ),
        ]),
      );
      await workspace.open(tester, model);
      await editing.selectTool(tester, 'axis');
      await workspace.wallTap(
        tester,
        wall.coreCenterStart + wall.unitVector * 2,
      );
      await tester.pumpAndSettle();
      expect(model.project.gridAxes, hasLength(2));
      final axis = model.project.gridAxes.firstWhere((a) => a.id != 'crossing');
      expect(axis.start, wall.coreCenterStart);
      expect(axis.end, wall.coreCenterEnd);
      expect(model.undoCount, 1);
      model.undo();
      expect(model.project.gridAxes, hasLength(1));
    },
  );

  testWidgets(
    'Automatic axis button uses saved thickness and forms one Undo step',
    (tester) async {
      SharedPreferences.setMockInitialValues({'architect_axis_wall_core': .12});
      final model = editing.seeded(
        const ArchitectStorey(
          id: 's',
          name: 'Floor',
          walls: [
            ArchitectWall(
              id: 'a',
              startPoint: Offset.zero,
              endPoint: Offset(4, 0),
              thickness: .12,
            ),
            ArchitectWall(
              id: 'b',
              startPoint: Offset(0, 3),
              endPoint: Offset(4, 3),
            ),
          ],
        ),
      );
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await editing.selectTool(tester, 'axis');
      await tester.tap(find.byKey(const ValueKey('architect-axes-from-walls')));
      await tester.pumpAndSettle();
      expect(model.project.gridAxes, hasLength(1));
      expect(model.project.gridAxes.single.start.dy, 0);
      expect(model.undoCount, 1);
      await tester.tap(find.byKey(const ValueKey('architect-axes-from-walls')));
      await tester.pumpAndSettle();
      expect(model.project.gridAxes, hasLength(1));
      expect(model.undoCount, 1);
    },
  );
}
