import 'architect_tool_test_helper.dart' as tools;
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_marquee_tool.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_selection_stage_one_test.dart' as stage;
import 'architect_workspace_interaction_test.dart' as workspace;

Future<void> option(WidgetTester tester, String kind, String value) async {
  await tester.tap(find.byKey(ValueKey('architect-selection-$kind')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('architect-selection-$kind-$value')));
  await tester.pumpAndSettle();
}

Future<void> fit(WidgetTester tester) async {
  workspace.camera(tester).fit(const Rect.fromLTWH(-2, -2, 12, 10));
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, Offset point) async {
  await tester.tapAt(workspace.screen(tester, point));
  await tester.pumpAndSettle();
}

Future<void> capturePhone(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_SELECTION_NEXT')) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('capture-next')),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '.dart_tool/selection-next-$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  test('Membership operations do not mutate inputs and Add is idempotent', () {
    const current = {'a', 'b'}, hits = {'b', 'c'};
    expect(
      ArchitectMarqueeTool.combine(
        current,
        hits,
        ArchitectSelectionOperation.replace,
      ),
      hits,
    );
    final added = ArchitectMarqueeTool.combine(
      current,
      hits,
      ArchitectSelectionOperation.add,
    );
    expect(added, {'a', 'b', 'c'});
    expect(
      ArchitectMarqueeTool.combine(
        added,
        hits,
        ArchitectSelectionOperation.add,
      ),
      added,
    );
    expect(
      ArchitectMarqueeTool.combine(
        current,
        hits,
        ArchitectSelectionOperation.remove,
      ),
      {'a'},
    );
    expect(current, {'a', 'b'});
    expect(hits, {'b', 'c'});
  });
  test(
    'Contained selection respects native outlines, holes and concave frames',
    () {
      final model = editing.seeded(
        ArchitectStorey(
          id: 's',
          name: '',
          columns: const [
            ArchitectColumn(
              id: 'circle',
              position: Offset(2, 2),
              width: 2,
              depth: 2,
              shape: ColumnShape.circular,
            ),
            ArchitectColumn(
              id: 'rotated',
              position: Offset(7, 2),
              width: 2,
              depth: 2,
              rotationDeg: 45,
            ),
          ],
          slabs: [
            ArchitectSlab(
              id: 'slab',
              polygon: stage.box(0, 5, 10, 10),
              holes: [stage.box(2, 7, 4, 4)],
            ),
          ],
          cadPrimitives: const [
            ArchitectCadPrimitive(
              id: 'bridge',
              type: CadPrimitiveType.line,
              startPoint: Offset(.5, 3),
              endPoint: Offset(3.5, 3),
            ),
          ],
        ),
      );
      addTearDown(model.dispose);
      Set<String> hits(
        List<Offset> polygon,
        ArchitectSelectionRelation relation,
      ) => ArchitectMarqueeTool.evaluateSelection(
        storey: model.project.activeStorey,
        project: model.project,
        polygon: polygon,
        relation: relation,
      );
      expect(
        hits(stage.box(1.5, 1.5, 1, 1), ArchitectSelectionRelation.crossing),
        contains('circle'),
      );
      expect(
        hits(stage.box(1.5, 1.5, 1, 1), ArchitectSelectionRelation.contained),
        isNot(contains('circle')),
      );
      expect(
        hits(stage.box(1, 1, 2, 2), ArchitectSelectionRelation.contained),
        contains('circle'),
      );
      expect(
        hits(stage.box(6, 1, 2, 2), ArchitectSelectionRelation.contained),
        isNot(contains('rotated')),
      );
      expect(
        hits(stage.box(5.5, .5, 3, 3), ArchitectSelectionRelation.contained),
        contains('rotated'),
      );
      expect(
        hits(stage.box(3, 8, 1, 1), ArchitectSelectionRelation.crossing),
        isEmpty,
      );
      expect(
        hits(stage.box(0, 5, 10, 10), ArchitectSelectionRelation.contained),
        contains('slab'),
      );
      const concave = [
        Offset(0, 0),
        Offset(4, 0),
        Offset(4, 4),
        Offset(3, 4),
        Offset(3, 1),
        Offset(1, 1),
        Offset(1, 4),
        Offset(0, 4),
      ];
      expect(
        hits(concave, ArchitectSelectionRelation.crossing),
        contains('bridge'),
      );
      expect(
        hits(concave, ArchitectSelectionRelation.contained),
        isNot(contains('bridge')),
      );
    },
  );
  testWidgets('Add and Remove taps are explicit and never edit geometry', (
    tester,
  ) async {
    final model = editing.seeded(stage.scene);
    addTearDown(model.dispose);
    await workspace.open(tester, model);
    await tools.chooseMulti(
      tester,
      operation: ArchitectSelectionOperation.replace,
    );
    await fit(tester);
    await tap(tester, const Offset(2, 1));
    await option(tester, 'operation', 'add');
    await tap(tester, const Offset(2, 1));
    expect(workspace.overlay(tester).selectedElementIds, {'inside'});
    await tap(tester, const Offset(7, 5));
    expect(workspace.overlay(tester).selectedElementIds, {'inside', 'outside'});
    await option(tester, 'operation', 'remove');
    await tap(tester, const Offset(2, 1));
    expect(workspace.overlay(tester).selectedElementIds, {'outside'});
    await tap(tester, const Offset(2, 1));
    expect(workspace.overlay(tester).selectedElementIds, {'outside'});
    await tap(tester, const Offset(7, 5));
    expect(workspace.overlay(tester).selectedElementIds, isEmpty);
    expect(model.project.activeStorey.columns.map((c) => c.position), [
      const Offset(2, 1),
      const Offset(7, 5),
    ]);
    expect(model.canUndo, isFalse);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Preview shows additions and removals; Cancel preserves committed selection',
    (tester) async {
      final model = editing.seeded(stage.scene);
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tools.chooseMulti(
        tester,
        operation: ArchitectSelectionOperation.replace,
      );
      await fit(tester);
      await tap(tester, const Offset(2, 1));
      await option(tester, 'operation', 'add');
      final gesture = await tester.startGesture(
        workspace.screen(tester, const Offset(5, 3)),
      );
      await gesture.moveTo(workspace.screen(tester, const Offset(8, 6)));
      await tester.pump();
      expect(workspace.overlay(tester).selectionPreviewIds, {
        'inside',
        'outside',
      });
      expect(workspace.overlay(tester).selectionPreviewAddedIds, {'outside'});
      expect(workspace.overlay(tester).selectedElementIds, {'inside'});
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('architect-selection-control-count')),
            )
            .data,
        '2',
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).selectedElementIds, {
        'inside',
        'outside',
      });
      await option(tester, 'operation', 'remove');
      await tap(tester, const Offset(0, 0));
      final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        pointer: 77,
      );
      await mouse.addPointer(
        location: workspace.screen(tester, const Offset(4, 3)),
      );
      await mouse.moveTo(workspace.screen(tester, const Offset(4, 3)));
      await tester.pump();
      expect(workspace.overlay(tester).selectionPreviewRemovedIds, {'inside'});
      expect(workspace.overlay(tester).selectionPreviewIds, {'outside'});
      await tester.tap(find.byKey(const ValueKey('architect-select-cancel')));
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).selectedElementIds, {
        'inside',
        'outside',
      });
      await mouse.removePointer();
      await stage.drag(tester, const Offset(0, 0), const Offset(4, 3));
      expect(workspace.overlay(tester).selectedElementIds, {'outside'});
      expect(model.canUndo, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Contained groups require every member; Crossing selects the whole group',
    (tester) async {
      final model = editing.seeded(
        stage.scene.copyWith(
          groups: const [
            ArchitectElementGroup(id: 'g', elementIds: {'inside', 'outside'}),
          ],
        ),
      );
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tools.chooseMulti(
        tester,
        operation: ArchitectSelectionOperation.replace,
      );
      await fit(tester);
      await option(tester, 'relation', 'contained');
      await stage.drag(tester, const Offset(0, 0), const Offset(4, 3));
      expect(workspace.overlay(tester).selectedElementIds, isEmpty);
      await option(tester, 'relation', 'crossing');
      await stage.drag(tester, const Offset(0, 0), const Offset(4, 3));
      expect(workspace.overlay(tester).selectedElementIds, {
        'inside',
        'outside',
      });
      expect(model.canUndo, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Polygon preview and Finish use committed vertices rather than cursor position',
    (tester) async {
      final model = editing.seeded(stage.scene);
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tools.chooseMulti(
        tester,
        operation: ArchitectSelectionOperation.replace,
      );
      await fit(tester);
      await tester.tap(find.text('Polygon'));
      await tester.pumpAndSettle();
      for (final p in stage.box(0, 0, 4, 3)) {
        await tap(tester, p);
      }
      final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        pointer: 78,
      );
      await mouse.addPointer(
        location: workspace.screen(tester, const Offset(8, 6)),
      );
      await mouse.moveTo(workspace.screen(tester, const Offset(8, 6)));
      await tester.pump();
      final preview = workspace.overlay(tester);
      expect(preview.marqueePolygon, stage.box(0, 0, 4, 3));
      expect(preview.selectionPreviewIds, {'inside'});
      expect(
        (preview.marqueeCandidate! - const Offset(8, 6)).distance,
        lessThan(1e-7),
      );
      await tester.tap(find.byKey(const ValueKey('architect-select-finish')));
      await tester.pumpAndSettle();
      expect(
        workspace.overlay(tester).selectedElementIds,
        preview.selectionPreviewIds,
      );
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
    },
  );
  for (final locale in ['bg', 'en']) {
    for (final brightness in Brightness.values) {
      testWidgets('Phone popup contrast and touch targets: $locale $brightness', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const capture = bool.fromEnvironment('CAPTURE_SELECTION_NEXT');
        if (capture) {
          await tester.runAsync(() async {
            await (FontLoader('Roboto')..addFont(
                  Future.value(
                    ByteData.sublistView(
                      await File('C:/Windows/Fonts/arial.ttf').readAsBytes(),
                    ),
                  ),
                ))
                .load();
            await (FontLoader('MaterialIcons')
                  ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
                .load();
          });
        }
        final model = editing.seeded(stage.scene);
        addTearDown(model.dispose);
        final scheme = ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: brightness,
        );
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('capture-next'),
            child: MaterialApp(
              locale: Locale(locale),
              theme: ThemeData(colorScheme: scheme, useMaterial3: true),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: ArchitectWorkspaceScreen(commandController: model),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tools.chooseMulti(
          tester,
          operation: ArchitectSelectionOperation.replace,
        );
        final l = await AppLocalizations.delegate.load(Locale(locale));
        if (locale == 'bg') {
          await capturePhone(tester, '${brightness.name}-idle');
        }
        for (final kind in ['operation', 'relation']) {
          final control = find.byKey(ValueKey('architect-selection-$kind'));
          expect(
            tester.getSize(control).shortestSide,
            greaterThanOrEqualTo(44),
          );
          await tester.tap(control);
          await tester.pumpAndSettle();
          final text = find.text(
            kind == 'operation'
                ? l.architectSelectRemove
                : l.architectSelectContained,
          );
          final widget = tester.widget<Text>(text);
          final fg = widget.style!.color!;
          final bg = scheme.surfaceContainerHigh;
          final a = fg.computeLuminance(), b = bg.computeLuminance();
          expect(
            a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05),
            greaterThanOrEqualTo(4.5),
          );
          if (locale == 'bg') {
            await capturePhone(tester, '${brightness.name}-$kind');
          }
          await tester.tap(
            find.byKey(
              ValueKey(
                'architect-selection-$kind-${kind == "operation" ? "remove" : "contained"}',
              ),
            ),
          );
          await tester.pumpAndSettle();
        }
        await option(tester, 'operation', 'replace');
        await fit(tester);
        await stage.drag(tester, const Offset(0, 0), const Offset(8, 6));
        await option(tester, 'operation', 'remove');
        final g = await tester.startGesture(
          workspace.screen(tester, const Offset(0, 0)),
        );
        await g.moveTo(workspace.screen(tester, const Offset(4, 3)));
        await tester.pump();
        expect(workspace.overlay(tester).selectionPreviewRemovedIds, {
          'inside',
        });
        if (locale == 'bg') {
          await capturePhone(tester, '${brightness.name}-preview');
        }
        await g.up();
        await tester.pumpAndSettle();
        expect(workspace.overlay(tester).selectedElementIds, {'outside'});
        expect(tester.takeException(), isNull);
      });
    }
  }
  test('Polygon hint is declared once per supported locale', () {
    for (final locale in ['bg', 'en']) {
      final source = File('lib/l10n/app_$locale.arb').readAsStringSync();
      expect(
        RegExp('"architectSelectPolygonHint"\\s*:').allMatches(source),
        hasLength(1),
      );
    }
  });
}
