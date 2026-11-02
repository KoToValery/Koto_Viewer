import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_grid_axis.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_element_tool.dart';
import 'package:kotoview/src/features/architect/services/architect_projection_editing.dart';
import 'package:kotoview/src/features/architect/services/architect_selection_candidates.dart';
import 'package:kotoview/src/features/architect/widgets/architect_candidate_picker.dart';
import 'package:kotoview/src/features/architect/widgets/architect_projection_editor.dart';
import 'package:kotoview/src/features/architect/widgets/architect_radial_menu.dart';

import 'architect_editing_test.dart' as editing;
import 'architect_elevation_ui_test.dart' as qa;
import 'architect_workspace_interaction_test.dart' as workspace;

const scene = ArchitectStorey(
  id: 's',
  name: 'Ground',
  walls: [
    ArchitectWall(
      id: 'wall',
      startPoint: Offset(-3, 0),
      endPoint: Offset(3, 0),
    ),
  ],
  columns: [
    ArchitectColumn(id: 'column', position: Offset.zero),
    ArchitectColumn(id: 'other', position: Offset(2, 2)),
  ],
);

Future<void> phone(
  WidgetTester tester,
  ArchitectCommandController model, {
  String language = 'en',
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('touch-capture'),
      child: MaterialApp(
        theme: ThemeData(fontFamily: 'TestReadable'),
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: ArchitectWorkspaceScreen(commandController: model),
      ),
    ),
  );
  await tester.pumpAndSettle();
  workspace.camera(tester).fit(const Rect.fromLTWH(-4, -4, 8, 8), padding: 24);
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_TOUCH_CANDIDATES')) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('touch-capture')),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '.dart_tool/touch-candidates-$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(qa.loadQaFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'touch hits rank exact before nearby, respect holes, filters and zoom',
    () {
      final model = editing.seeded(
        scene.copyWith(
          slabs: [
            ArchitectSlab(
              id: 'slab',
              polygon: const [
                Offset(-5, -5),
                Offset(5, -5),
                Offset(5, 5),
                Offset(-5, 5),
              ],
              holes: const [
                [Offset(-2, -2), Offset(2, -2), Offset(2, 2), Offset(-2, 2)],
              ],
            ),
          ],
          columns: const [
            ArchitectColumn(id: 'column', position: Offset(0, .4)),
          ],
        ),
      );
      final tool = ArchitectElementTool();
      addTearDown(model.dispose);
      addTearDown(tool.dispose);
      for (final scale in [40.0, 100.0]) {
        final hits = ArchitectSelectionCandidates.planHits(
          model.project,
          tool,
          Offset.zero,
          scale,
          allowed: (_) => true,
        );
        expect(hits.first, 'wall');
        expect(hits.contains('column'), scale == 40);
        expect(hits, isNot(contains('slab')));
        expect(
          ArchitectSelectionCandidates.planHits(
            model.project,
            tool,
            Offset.zero,
            scale,
            allowed: (id) => id == 'wall',
          ),
          ['wall'],
        );
      }
    },
  );

  test('path proximity catches diagonal thin paths and hole boundaries', () {
    final diagonal = Path()
      ..moveTo(0, 0)
      ..lineTo(10, 10);
    expect(
      ArchitectSelectionCandidates.pathHit(diagonal, const Offset(5, 5.2), .2),
      isTrue,
    );
    expect(
      ArchitectSelectionCandidates.pathHit(diagonal, const Offset(5, 5.5), .2),
      isFalse,
    );
    final hole = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(const Rect.fromLTWH(0, 0, 10, 10))
      ..addRect(const Rect.fromLTWH(2, 2, 6, 6));
    expect(
      ArchitectSelectionCandidates.pathHit(hole, const Offset(5, 5), .22),
      isFalse,
    );
    expect(
      ArchitectSelectionCandidates.pathHit(hole, const Offset(2.1, 5), .22),
      isTrue,
    );
  });

  test('CAD circles and open polylines are picked at their strokes', () {
    final model = editing.seeded(
      const ArchitectStorey(
        id: 's',
        name: '',
        cadPrimitives: [
          ArchitectCadPrimitive(
            id: 'circle',
            type: CadPrimitiveType.circle,
            startPoint: Offset.zero,
            endPoint: Offset(3, 0),
          ),
        ],
      ),
    );
    final tool = ArchitectElementTool();
    addTearDown(model.dispose);
    addTearDown(tool.dispose);
    expect(
      ArchitectSelectionCandidates.planHits(
        model.project,
        tool,
        Offset.zero,
        100,
        allowed: (_) => true,
      ),
      isEmpty,
    );
    expect(
      ArchitectSelectionCandidates.planHits(
        model.project,
        tool,
        const Offset(3.15, 0),
        100,
        allowed: (_) => true,
      ),
      ['circle'],
    );
  });

  test(
    'projection pickAll keeps exact hits first and skips unknown/hidden ids',
    () {
      final model = editing.seeded(scene);
      addTearDown(model.dispose);
      final paths = {
        'column': Path()..addRect(const Rect.fromLTWH(.1, -.1, .1, .2)),
        'wall': Path()..addRect(const Rect.fromLTWH(-1, -.1, 2, .2)),
        'hidden': Path()..addRect(const Rect.fromLTWH(-1, -1, 2, 2)),
      };
      expect(
        ArchitectProjectionEditing.pickAll(
          model.project,
          paths,
          Offset.zero,
          .22,
        ),
        ['wall', 'column'],
      );
      expect(
        ArchitectProjectionEditing.pick(model.project, paths, Offset.zero, .22),
        'wall',
      );
      expect(
        ArchitectProjectionEditing.pickAll(model.project, {}, Offset.zero, .22),
        isEmpty,
      );
    },
  );

  for (final language in ['en', 'bg']) {
    testWidgets(
      'phone $language cycles and lists candidates without model edits',
      (tester) async {
        final model = editing.seeded(scene);
        addTearDown(model.dispose);
        final original = jsonEncode(model.project.toJson());
        var notifications = 0;
        model.addListener(() => notifications++);
        await phone(tester, model, language: language);
        await workspace.wallTap(tester, Offset.zero);
        await tester.pumpAndSettle();
        expect(find.byType(ArchitectCandidatePicker), findsOneWidget);
        final picker = tester.widget<ArchitectCandidatePicker>(
          find.byType(ArchitectCandidatePicker),
        );
        expect(picker.labels.map((e) => e.id), ['column', 'wall']);
        expect(workspace.overlay(tester).selectedElementIds, {'column'});
        await tapKey(tester, 'architect-candidate-next');
        expect(workspace.overlay(tester).selectedElementIds, {'wall'});
        await tapKey(tester, 'architect-candidate-next');
        expect(workspace.overlay(tester).selectedElementIds, {'column'});
        await tapKey(tester, 'architect-candidate-previous');
        expect(workspace.overlay(tester).selectedElementIds, {'wall'});
        await capture(tester, language);
        for (final key in [
          'architect-candidate-next',
          'architect-candidate-previous',
        ]) {
          final rect = tester.getRect(find.byKey(ValueKey(key)));
          expect(rect.width, greaterThanOrEqualTo(44));
          expect(rect.height, greaterThanOrEqualTo(44));
          expect(rect.bottom, lessThanOrEqualTo(800));
        }
        await tapKey(tester, 'architect-candidate-list');
        await capture(tester, 'list-$language');
        await tapKey(tester, 'architect-candidate-row-column');
        expect(workspace.overlay(tester).selectedElementIds, {'column'});
        expect(
          find.byKey(const ValueKey('architect-candidate-row-wall')),
          findsNothing,
        );
        expect(jsonEncode(model.project.toJson()), original);
        expect(model.undoCount, 0);
        expect(notifications, 0);
        workspace.camera(tester).panBy(const Offset(10, 0));
        await tester.pumpAndSettle();
        expect(find.byType(ArchitectCandidatePicker), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'multi previews and applies group membership without losing other picks',
    (tester) async {
      final model = editing.seeded(
        scene.copyWith(
          groups: [
            const ArchitectElementGroup(
              id: 'group',
              elementIds: {'column', 'wall'},
            ),
          ],
        ),
      );
      addTearDown(model.dispose);
      await phone(tester, model);
      await tapKey(tester, 'architect-multi-select');
      await workspace.wallTap(tester, const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).selectedElementIds, {'other'});
      await workspace.wallTap(tester, Offset.zero);
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).selectedElementIds, {'other'});
      expect(
        find.byKey(const ValueKey('architect-candidate-preview')),
        findsOneWidget,
      );
      await tapKey(tester, 'architect-candidate-next');
      expect(workspace.overlay(tester).selectedElementIds, {'other'});
      await capture(tester, 'multi');
      await tapKey(tester, 'architect-candidate-apply');
      expect(workspace.overlay(tester).selectedElementIds, {
        'other',
        'wall',
        'column',
      });
      await tapKey(tester, 'architect-candidate-list');
      await capture(tester, 'multi-list');
      await tapKey(tester, 'architect-candidate-row-column');
      expect(workspace.overlay(tester).selectedElementIds, {'other'});
      expect(
        find.byKey(const ValueKey('architect-candidate-row-wall')),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(180, 80));
      await tester.pumpAndSettle();
      expect(model.undoCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('large phone text keeps chooser and sheet inside the screen', (
    tester,
  ) async {
    final model = editing.seeded(scene);
    addTearDown(model.dispose);
    await phone(tester, model, language: 'bg', textScale: 1.6);
    await workspace.wallTap(tester, Offset.zero);
    await tester.pumpAndSettle();
    expect(find.byType(ArchitectCandidatePicker), findsOneWidget);
    await capture(tester, 'large-text');
    await tapKey(tester, 'architect-candidate-list');
    await capture(tester, 'large-text-list');
    await tapKey(tester, 'architect-candidate-close');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'holds, empty taps and explicit mode changes dismiss the chooser',
    (tester) async {
      final model = editing.seeded(scene);
      addTearDown(model.dispose);
      await phone(tester, model);
      await workspace.wallTap(tester, Offset.zero);
      await tester.pumpAndSettle();
      final hold = await tester.startGesture(
        workspace.screen(tester, Offset.zero),
      );
      await tester.pump(const Duration(milliseconds: 800));
      await hold.up();
      await tester.pumpAndSettle();
      expect(find.byType(ArchitectCandidatePicker), findsNothing);
      expect(find.byType(ArchitectRadialMenu), findsOneWidget);
      tester
          .widget<ArchitectRadialMenu>(find.byType(ArchitectRadialMenu))
          .onDismiss();
      await tester.pumpAndSettle();
      await workspace.wallTap(tester, Offset.zero);
      await tester.pumpAndSettle();
      expect(find.byType(ArchitectCandidatePicker), findsOneWidget);
      await workspace.wallTap(tester, const Offset(-2, -2));
      await tester.pumpAndSettle();
      expect(find.byType(ArchitectCandidatePicker), findsNothing);
      await workspace.wallTap(tester, Offset.zero);
      await tester.pumpAndSettle();
      await tapKey(tester, 'architect-multi-select');
      expect(find.byType(ArchitectCandidatePicker), findsNothing);
      expect(model.undoCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'many identical hits scroll and external revisions close the sheet',
    (tester) async {
      final model = editing.seeded(
        ArchitectStorey(
          id: 's',
          name: '',
          columns: [
            for (var i = 0; i < 16; i++)
              ArchitectColumn(id: 'c$i', position: Offset.zero),
          ],
        ),
      );
      addTearDown(model.dispose);
      await phone(tester, model);
      await workspace.wallTap(tester, Offset.zero);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ArchitectCandidatePicker>(
              find.byType(ArchitectCandidatePicker),
            )
            .labels
            .length,
        16,
      );
      await tapKey(tester, 'architect-candidate-list');
      final row = find.byKey(const ValueKey('architect-candidate-row-c15'));
      await tester.scrollUntilVisible(
        row,
        150,
        scrollable: find
            .descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(Scrollable),
            )
            .last,
      );
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).selectedElementIds, {'c15'});
      await tapKey(tester, 'architect-candidate-list');
      model.commit(
        model.project.updateActiveStorey(
          model.project.activeStorey.copyWith(columns: []),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ArchitectCandidatePicker), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('explicit Add, Remove and Replace apply only on confirmation', (
    tester,
  ) async {
    final model = editing.seeded(scene);
    addTearDown(model.dispose);
    await phone(tester, model);
    await tapKey(tester, 'architect-multi-select');
    await workspace.wallTap(tester, Offset.zero);
    await tester.pumpAndSettle();
    Future<void> operation(String value) async {
      await tapKey(tester, 'architect-selection-operation');
      await tapKey(tester, 'architect-selection-operation-$value');
    }

    await operation('add');
    expect(workspace.overlay(tester).selectedElementIds, isEmpty);
    await tapKey(tester, 'architect-candidate-apply');
    await tapKey(tester, 'architect-candidate-apply');
    expect(workspace.overlay(tester).selectedElementIds, {'column'});
    await operation('remove');
    expect(workspace.overlay(tester).selectedElementIds, {'column'});
    await tapKey(tester, 'architect-candidate-apply');
    expect(workspace.overlay(tester).selectedElementIds, isEmpty);
    await tapKey(tester, 'architect-candidate-next');
    await tapKey(tester, 'architect-candidate-apply');
    expect(workspace.overlay(tester).selectedElementIds, isEmpty);
    await operation('replace');
    await tapKey(tester, 'architect-candidate-apply');
    expect(workspace.overlay(tester).selectedElementIds, {'wall'});
    expect(model.undoCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('axis inspector layout retains the candidate snapshot', (
    tester,
  ) async {
    final model = editing.seeded(
      const ArchitectStorey(id: 's', name: ''),
      axes: const [
        StructuralGridAxis(
          id: 'a',
          name: 'A',
          start: Offset(-3, 0),
          end: Offset(3, 0),
        ),
        StructuralGridAxis(
          id: 'b',
          name: 'B',
          start: Offset(0, -3),
          end: Offset(0, 3),
        ),
      ],
    );
    addTearDown(model.dispose);
    await phone(tester, model);
    await workspace.wallTap(tester, Offset.zero);
    await tester.pumpAndSettle();
    expect(find.byType(ArchitectCandidatePicker), findsOneWidget);
    await tapKey(tester, 'architect-candidate-next');
    expect(workspace.overlay(tester).selectedElementIds, {'b'});
    expect(model.undoCount, 0);
    expect(tester.takeException(), isNull);
  });

  for (final elevation in [false, true]) {
    testWidgets(
      '${elevation ? 'facade' : 'section'} shares chooser and lists storeys',
      (tester) async {
        final model = editing.seeded(scene);
        addTearDown(model.dispose);
        final original = jsonEncode(model.project.toJson());
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Offset toScreen(Offset p) => const Offset(180, 300) + p * 50;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ArchitectProjectionEditor(
                controller: model,
                paths: {
                  'wall': Path()..addRect(const Rect.fromLTWH(-2, -1, 4, 2)),
                  'column': Path()..addRect(const Rect.fromLTWH(-1, -1, 2, 2)),
                },
                origin: Offset.zero,
                right: const Offset(1, 0),
                elevation: elevation,
                toView: (p) => (p - const Offset(180, 300)) / 50,
                toScreen: toScreen,
                scale: 50,
                onNavigate: (_, _, _) {},
              ),
            ),
          ),
        );
        await tester.tapAt(toScreen(Offset.zero));
        await tester.pumpAndSettle();
        expect(find.byType(ArchitectCandidatePicker), findsOneWidget);
        await tapKey(tester, 'architect-candidate-next');
        expect(
          tester
              .widget<ArchitectCandidatePicker>(
                find.byType(ArchitectCandidatePicker),
              )
              .index,
          1,
        );
        await tapKey(tester, 'architect-candidate-list');
        expect(find.text('Ground'), findsNWidgets(2));
        await tapKey(tester, 'architect-candidate-row-column');
        expect(
          tester
              .widget<ArchitectCandidatePicker>(
                find.byType(ArchitectCandidatePicker),
              )
              .index,
          0,
        );
        await tester.dragFrom(const Offset(30, 150), const Offset(30, 10));
        await tester.pumpAndSettle();
        expect(find.byType(ArchitectCandidatePicker), findsNothing);
        expect(jsonEncode(model.project.toJson()), original);
        expect(model.undoCount, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
