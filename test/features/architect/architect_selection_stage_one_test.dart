import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/rendering/architect_canvas_palette.dart';
import 'package:kotoview/src/features/architect/rendering/architect_selection_painter.dart';
import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_marquee_tool.dart';
import 'package:kotoview/src/features/architect/widgets/architect_selection_control.dart';
import 'package:kotoview/src/features/architect/widgets/architect_tool_palette.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_tool_test_helper.dart' as tools;
import 'architect_workspace_interaction_test.dart' as workspace;

List<Offset> box(double x, double y, double width, double height) => [
  Offset(x, y),
  Offset(x + width, y),
  Offset(x + width, y + height),
  Offset(x, y + height),
];
const scene = ArchitectStorey(
  id: 's',
  name: '',
  columns: [
    ArchitectColumn(id: 'inside', position: Offset(2, 1)),
    ArchitectColumn(id: 'outside', position: Offset(7, 5)),
  ],
);
Future<void> drag(
  WidgetTester tester,
  Offset a,
  Offset b, {
  int pointer = 1,
}) async {
  final g = await tester.startGesture(
    workspace.screen(tester, a),
    pointer: pointer,
  );
  await g.moveTo(workspace.screen(tester, b));
  await tester.pump();
  await g.up();
  await tester.pumpAndSettle();
}

void main() {
  test(
    'Final rectangle point replaces a stale candidate and supports small boxes',
    () {
      final tool = ArchitectMarqueeTool()
        ..addPoint(Offset.zero)
        ..updateCandidate(const Offset(1, 1));
      tool.addPoint(const Offset(5, 4));
      expect(tool.previewPolygon, box(0, 0, 5, 4));
      expect(tool.finish(rectangleEnd: const Offset(6, 3)), box(0, 0, 6, 3));
      tool.cancel();
      tool.addPoint(Offset.zero);
      tool.addPoint(const Offset(.01, .01));
      expect(tool.finish(), box(0, 0, .01, .01));
    },
  );
  test(
    'Polygon completion ignores hover points and rejects degenerate/self-crossing frames',
    () {
      final tool = ArchitectMarqueeTool()..setMode(ArchitectSelectMode.polygon);
      for (final p in box(0, 0, 4, 3)) {
        tool.addPoint(p);
      }
      tool.updateCandidate(const Offset(20, 20));
      expect(tool.finish(), box(0, 0, 4, 3));
      tool.cancel();
      for (final p in [
        Offset.zero,
        const Offset(2, 2),
        const Offset(2, 0),
        const Offset(0, 2),
      ]) {
        tool.addPoint(p);
      }
      expect(tool.finish(), isEmpty);
      tool.setMode(ArchitectSelectMode.rectangle);
      tool.addPoint(Offset.zero);
      expect(tool.finish(rectangleEnd: const Offset(0, 3)), isEmpty);
    },
  );
  test(
    'Area selection respects holes, visibility, native footprints and hosted opening positions',
    () {
      final model = editing.seeded(
        ArchitectStorey(
          id: 's',
          name: '',
          slabs: [
            ArchitectSlab(
              id: 'slab',
              polygon: box(0, 0, 10, 10),
              holes: [box(2, 2, 4, 4)],
            ),
          ],
          cadPrimitives: [
            ArchitectCadPrimitive(
              id: 'hatch',
              type: CadPrimitiveType.hatch,
              startPoint: Offset.zero,
              endPoint: const Offset(10, 10),
              holes: [box(2, 2, 4, 4)],
            ),
          ],
          walls: [
            const ArchitectWall(
              id: 'wall',
              startPoint: Offset(0, 12),
              endPoint: Offset(10, 12),
              doors: [
                ArchitectDoor(
                  id: 'door',
                  wallId: 'wall',
                  uuid: 'door',
                  offsetRatio: .8,
                  width: 1,
                ),
              ],
            ),
          ],
          beams: [
            const ArchitectBeam(
              id: 'beam',
              startPoint: Offset(0, 14),
              endPoint: Offset(10, 14),
              width: 1,
            ),
          ],
          components: const [
            ArchitectComponentInstance(
              id: 'visible',
              definitionId: 'table',
              position: Offset(20, 20),
            ),
            ArchitectComponentInstance(
              id: 'hidden',
              definitionId: 'table',
              position: Offset(20, 20),
              isVisible: false,
            ),
          ],
        ),
      );
      addTearDown(model.dispose);
      Set<String> hits(List<Offset> p, {bool furniture = true}) =>
          ArchitectMarqueeTool.evaluateSelection(
            storey: model.project.activeStorey,
            project: model.project,
            polygon: p,
            includeComponents: furniture,
          );
      expect(hits(box(3, 3, 1, 1)), isEmpty);
      expect(hits(box(.5, .5, 1, 1)), containsAll(['slab', 'hatch']));
      expect(hits(box(0, 11.9, 1, .2)), contains('wall'));
      expect(hits(box(0, 11.9, 1, .2)), isNot(contains('door')));
      expect(hits(box(7.7, 11.8, .6, .4)), contains('door'));
      expect(hits(box(4, 14.2, .5, .2)), contains('beam'));
      expect(hits(box(19, 19, 3, 3)), {'visible'});
      expect(hits(box(19, 19, 3, 3), furniture: false), isEmpty);
    },
  );
  test(
    'Selection and marquee line weights remain constant at every zoom and theme',
    () {
      for (final scale in [10.0, 40.0, 200.0]) {
        for (final palette in [
          const ArchitectCanvasPalette.light(),
          const ArchitectCanvasPalette.dark(),
        ]) {
          final canvas = ArchitectVectorCanvas()..scale(scale);
          ArchitectSelectionPainter.outline(
            canvas,
            Path()..addRect(const Rect.fromLTWH(0, 0, 4, 3)),
            scale,
            palette,
          );
          expect(
            canvas.operations.whereType<ArchitectVectorPath>().map(
              (p) => p.width,
            ),
            [closeTo(5.5, 1e-5), closeTo(2.5, 1e-5)],
          );
          final frame = ArchitectVectorCanvas()..scale(scale);
          ArchitectSelectionPainter.marquee(
            frame,
            box(0, 0, 4, 3),
            [],
            scale,
            palette,
          );
          final strokes = frame.operations
              .whereType<ArchitectVectorPath>()
              .where((p) => !p.fill)
              .toList();
          expect(strokes.first.width, closeTo(4.5, 1e-5));
          expect(
            strokes.skip(1).every((p) => (p.width - 2).abs() < 1e-5),
            isTrue,
          );
        }
      }
    },
  );
  testWidgets(
    'Two taps and a stale preview reliably select the final rectangle',
    (tester) async {
      final model = editing.seeded(scene);
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      workspace.camera(tester).fit(const Rect.fromLTWH(-5, -5, 15, 12));
      await tester.pumpAndSettle();
      await tester.tapAt(workspace.screen(tester, const Offset(-1, -1)));
      await tester.pump();
      await tester.startGesture(
        workspace.screen(tester, const Offset(1, 1)),
        pointer: 41,
      );
      await tester.pump();
      await tester.sendEventToBinding(
        PointerUpEvent(
          pointer: 41,
          position: workspace.screen(tester, const Offset(4, 3)),
        ),
      );
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).selectedElementIds, {'inside'});
      expect(workspace.overlay(tester).marqueePoints, isEmpty);
      expect(
        find.byKey(const ValueKey('architect-selection-controls')),
        findsOneWidget,
      );
      expect(model.canUndo, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Drag box preserves camera, remains available after selection and clears stale primary on no hits',
    (tester) async {
      final model = editing.seeded(scene);
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      workspace.camera(tester).fit(const Rect.fromLTWH(-5, -5, 15, 12));
      await tester.pumpAndSettle();
      final before = workspace.camera(tester).translation;
      await drag(tester, const Offset(-1, -1), const Offset(4, 3));
      expect(workspace.overlay(tester).selectedElementIds, {'inside'});
      expect(workspace.camera(tester).translation, before);
      await drag(tester, const Offset(-4, -4), const Offset(-2, -2));
      expect(workspace.overlay(tester).selectedElementIds, isEmpty);
      expect(workspace.overlay(tester).selectedElementId, isNull);
      await drag(tester, const Offset(-1, -1), const Offset(4, 3));
      await tester.tap(
        find.byKey(const ValueKey('architect-selection-control-clear')),
      );
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).selectedElementIds, isEmpty);
      expect(
        find.byKey(const ValueKey('architect-selection-controls')),
        findsOneWidget,
      );
      await drag(tester, const Offset(-1, -1), const Offset(4, -1));
      expect(workspace.overlay(tester).marqueePoints, isEmpty);
      expect(workspace.overlay(tester).selectedElementIds, isEmpty);
      await drag(tester, const Offset(-1, -1), const Offset(4, 3));
      expect(workspace.overlay(tester).selectedElementIds, {'inside'});
      expect(model.canUndo, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Hand pans the canvas and never selects or starts a box', (
    tester,
  ) async {
    final model = editing.seeded(scene);
    addTearDown(model.dispose);
    await workspace.open(tester, model);
    workspace.camera(tester).fit(const Rect.fromLTWH(-5, -5, 15, 12));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('architect-tool-pan')));
    await tester.pumpAndSettle();
    final before = workspace.camera(tester).translation;
    final g = await tester.startGesture(
      workspace.screen(tester, const Offset(2, 1)),
    );
    await g.moveBy(const Offset(60, 35));
    await g.up();
    await tester.pumpAndSettle();
    expect(workspace.camera(tester).translation, before + const Offset(60, 35));
    expect(workspace.overlay(tester).selectedElementIds, isEmpty);
    expect(workspace.overlay(tester).marqueePoints, isEmpty);
    expect(
      find.byKey(const ValueKey('architect-selection-controls')),
      findsNothing,
    );
    await tools.choose(tester, Icons.near_me_outlined);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ArchitectToolPalette>(find.byType(ArchitectToolPalette))
          .activeTool,
      ArchitectTool.select,
    );
    expect(
      find.byKey(const ValueKey('architect-selection-controls')),
      findsOneWidget,
    );
    expect(model.canUndo, isFalse);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Pinch cancels an unfinished box without committing selection', (
    tester,
  ) async {
    final model = editing.seeded(scene);
    addTearDown(model.dispose);
    await workspace.open(tester, model);
    workspace.camera(tester).fit(const Rect.fromLTWH(-5, -5, 15, 12));
    await tester.pumpAndSettle();
    final first = await tester.startGesture(
      workspace.screen(tester, const Offset(-1, -1)),
      pointer: 51,
    );
    await first.moveTo(workspace.screen(tester, const Offset(4, 3)));
    await tester.pump();
    final second = await tester.startGesture(
      workspace.screen(tester, const Offset(5, 4)),
      pointer: 52,
    );
    await second.up();
    await first.up();
    await tester.pumpAndSettle();
    expect(workspace.overlay(tester).selectedElementIds, isEmpty);
    expect(workspace.overlay(tester).marqueePoints, isEmpty);
    expect(model.canUndo, isFalse);
    expect(tester.takeException(), isNull);
  });
  for (final locale in ['bg', 'en']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'Phone selection controls remain readable and reachable: $locale $brightness',
        (tester) async {
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          const capture = bool.fromEnvironment('CAPTURE_SELECTION_STAGE_ONE');
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
          final model = editing.seeded(scene);
          addTearDown(model.dispose);
          final scheme = brightness == Brightness.dark
              ? const ColorScheme.dark(
                  primary: Color(0xFF4F46E5),
                  surface: Color(0xFF1E293B),
                  onSurface: Color(0xFFF8FAFC),
                )
              : const ColorScheme.light(
                  primary: Color(0xFF4F46E5),
                  surface: Colors.white,
                  onSurface: Color(0xFF0F172A),
                );
          await tester.pumpWidget(
            RepaintBoundary(
              key: const ValueKey('selection-capture'),
              child: MaterialApp(
                locale: Locale(locale),
                theme: ThemeData(
                  brightness: brightness,
                  useMaterial3: true,
                  colorScheme: scheme,
                ),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: ArchitectWorkspaceScreen(commandController: model),
              ),
            ),
          );
          await tester.pumpAndSettle();
          workspace.camera(tester).fit(const Rect.fromLTWH(-1, -1, 10, 8));
          await tester.pumpAndSettle();
          await tester.tapAt(workspace.screen(tester, const Offset(2, 1)));
          await tester.pumpAndSettle();
          expect(workspace.overlay(tester).selectedElementIds, {'inside'});
          final controls = find.byType(ArchitectSelectionControl);
          final rect = tester.getRect(controls);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(360));
          final clear = find.byKey(
            const ValueKey('architect-selection-control-clear'),
          );
          expect(tester.getSize(clear).width, greaterThanOrEqualTo(44));
          final l = await AppLocalizations.delegate.load(Locale(locale));
          final text = find.descendant(
            of: controls,
            matching: find.text(l.architectSelectModeRect),
          );
          final fg = DefaultTextStyle.of(tester.element(text)).style.color!;
          final bg = scheme.surfaceContainerHighest;
          final a = fg.computeLuminance(), b = bg.computeLuminance();
          expect(
            a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05),
            greaterThanOrEqualTo(4.5),
          );
          if (capture && locale == 'bg') {
            await tester.runAsync(() async {
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(const ValueKey('selection-capture')),
              );
              final image = await boundary.toImage(pixelRatio: 2);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                '.dart_tool/selection-stage-one-${brightness.name}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.tap(find.text(l.architectSelectModePolygon));
          await tester.pumpAndSettle();
          for (final point in [
            const Offset(-.5, -.5),
            const Offset(4, -.5),
            const Offset(4, 3),
          ]) {
            await tester.tapAt(workspace.screen(tester, point));
            await tester.pumpAndSettle();
          }
          expect(
            tester
                .widget<IconButton>(
                  find.byKey(const ValueKey('architect-select-finish')),
                )
                .onPressed,
            isNotNull,
          );
          await tester.tap(
            find.byKey(const ValueKey('architect-select-finish')),
          );
          await tester.pumpAndSettle();
          expect(find.byType(ArchitectSelectionControl), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
