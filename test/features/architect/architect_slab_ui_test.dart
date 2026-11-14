import 'architect_projection_test_helper.dart' as projection;
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/models/architect_slab_assembly.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/services/architect_polygon_editor.dart';
import 'package:kotoview/src/features/architect/widgets/architect_building_sections_screen.dart';
import 'package:kotoview/src/features/architect/widgets/architect_slab_layers_dialog.dart';
import 'package:kotoview/src/features/architect/widgets/architect_tool_palette.dart';
import 'package:kotoview/src/features/bim_editing/interaction/bim_polygon_editor.dart';
import 'architect_drawing_controls_revision_test.dart' as revision;
import 'architect_editing_test.dart' as editing;
import 'architect_slab_assembly_test.dart' as fixture;
import 'architect_workspace_interaction_test.dart' as workspace;
import 'architect_tool_test_helper.dart' as tools;

Widget host(Widget child, String locale, {GlobalKey? capture}) =>
    RepaintBoundary(
      key: capture,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'TestReadable', useMaterial3: true),
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );

Future<void> capturePhone(
  WidgetTester tester,
  GlobalKey key,
  String name,
) async {
  if (!const bool.fromEnvironment('SLAB_QA_CAPTURE')) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/architect-slab-qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    // Real glyphs for inspectable screenshots, without network font downloads.
    final file = File('C:/Windows/Fonts/arial.ttf');
    if (!Platform.isWindows || !file.existsSync()) return;
    final bytes = file.readAsBytesSync();
    final loader = FontLoader('TestReadable')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'workspace opens slab layers through properties and saves to shared history',
    (tester) async {
      final controller = ArchitectCommandController(fixture.slabProject());
      addTearDown(controller.dispose);
      await workspace.open(tester, controller);
      await tools.choose(tester, Icons.near_me_outlined);
      await projection.settleProjection(tester);
      await workspace.wallTap(tester, const Offset(2, 2));
      await projection.settleProjection(tester);
      await tester.tap(
        find.byKey(const ValueKey('architect-selection-properties')),
      );
      await projection.settleProjection(tester);

      expect(find.byType(ArchitectSlabLayersDialog), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('slab-core-thickness')),
        '.22',
      );
      await tester.tap(find.byKey(const ValueKey('slab-layers-save')));
      await projection.settleProjection(tester);
      expect(
        controller.project.activeStorey.slabs.single.assemblyId,
        isNotNull,
      );
      expect(controller.project.activeStorey.slabs.single.thickness, .22);
      controller.undo();
      await projection.settleProjection(tester);
      expect(controller.project.activeStorey.slabs.single.assemblyId, isNull);
      await tester.tap(find.byKey(const ValueKey('architect-view-section')));
      await projection.settleProjection(tester);
      await tester.tap(
        find.byKey(const ValueKey('architect-building-sections')),
      );
      await projection.settleProjection(tester);
      expect(find.byType(ArchitectBuildingSectionsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final locale in ['bg', 'en']) {
    testWidgets('slab editor fits phone and edits a lower layer ($locale)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final a = ArchitectSlabCatalog.preset(SlabUsage.basement);
      final p = fixture.slabProject(assembly: a);
      final key = GlobalKey();
      await tester.pumpWidget(
        host(
          Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: FilledButton(
                  onPressed: () => showDialog<void>(
                    context: ctx,
                    builder: (_) => ArchitectSlabLayersDialog(
                      project: p,
                      slab: p.activeStorey.slabs.single,
                      onApply: (_) => true,
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
          locale,
          capture: key,
        ),
      );
      await tester.tap(find.text('Open'));
      await projection.settleProjection(tester);
      expect(tester.takeException(), isNull);
      final lower = find.widgetWithText(
        ChoiceChip,
        locale == 'bg' ? 'Под бетона' : 'Below concrete',
      );
      await tester.ensureVisible(lower);
      await tester.tap(lower);
      await projection.settleProjection(tester);
      expect(tester.takeException(), isNull);
      final xps = find.widgetWithText(ListTile, 'XPS');
      await tester.ensureVisible(xps);
      await tester.tap(find.descendant(of: xps, matching: find.text('XPS')));
      await projection.settleProjection(tester);
      expect(
        find.text(
          AppLocalizations.of(
            tester.element(find.byType(ArchitectSlabLayersDialog)),
          )!.architectPropertyThickness,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(locale == 'bg' ? 'Отказ' : 'Cancel').last);
      await projection.settleProjection(tester);
      await capturePhone(tester, key, 'layers-$locale');
    });

    testWidgets(
      'section detail rendering, history and lost link fit phone ($locale)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final a = ArchitectSlabCatalog.preset(SlabUsage.invertedRoof);
        final p = fixture
            .slabProject(
              assembly: a,
              plate: fixture.slab.copyWith(slopeDirection: 0),
            )
            .copyWith(
              sections: [
                fixture.cut.copyWith(
                  details: [
                    const ArchitectSlabDetail(
                      id: 'd',
                      slabId: 'slab',
                      station: 5,
                      textOffset: Offset(1, 2),
                    ),
                  ],
                ),
              ],
            );
        final controller = ArchitectCommandController(p);
        addTearDown(controller.dispose);
        final key = GlobalKey();
        await tester.pumpWidget(
          host(
            ArchitectBuildingSectionsScreen(controller: controller),
            locale,
            capture: key,
          ),
        );
        await projection.settleProjection(tester);
        expect(tester.takeException(), isNull);
        await capturePhone(tester, key, 'section-$locale');
        controller.commit(
          controller.project.updateActiveStorey(
            controller.project.activeStorey.copyWith(slabs: []),
          ),
        );
        await projection.settleProjection(tester);
        expect(tester.takeException(), isNull);
        controller.undo();
        await projection.settleProjection(tester);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('cut line and viewing side save a section and undo removes it', (
    tester,
  ) async {
    final controller = ArchitectCommandController(fixture.slabProject());
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(ArchitectBuildingSectionsScreen(controller: controller), 'en'),
    );
    await projection.settleProjection(tester);
    final bounds = tester.getRect(
      find.byKey(const ValueKey('building-section-plan')),
    );
    await tester.tapAt(bounds.centerLeft + const Offset(30, 0));
    await tester.pump();
    await tester.tapAt(bounds.centerRight - const Offset(30, 0));
    await projection.settleProjection(tester);
    expect(controller.project.sections, isEmpty);
    await tester.tapAt(bounds.center + const Offset(0, 30));
    await projection.settleProjection(tester);
    expect(controller.project.sections, hasLength(1));
    expect(
      find.byKey(const ValueKey('section-add-slab-detail')),
      findsOneWidget,
    );
    controller.undo();
    await projection.settleProjection(tester);
    expect(controller.project.sections, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'two detail taps associate the actual slab and undo preserves its identity',
    (tester) async {
      final a = ArchitectSlabCatalog.preset(SlabUsage.intermediate);
      final controller = ArchitectCommandController(
        fixture.slabProject(assembly: a).copyWith(sections: [fixture.cut]),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        host(ArchitectBuildingSectionsScreen(controller: controller), 'en'),
      );
      await projection.settleProjection(tester);
      await tester.tap(find.byKey(const ValueKey('section-add-slab-detail')));
      await projection.settleProjection(tester);
      Offset screen(Offset model) {
        final rect = tester.getRect(
          find.byKey(const ValueKey('building-section-view')),
        );
        final bounds = ArchitectBuildingSection.build(
          controller.project,
          fixture.cut,
        ).bounds.inflate(.8);
        final sx = rect.width / bounds.width, sy = rect.height / bounds.height;
        final scale = sx < sy ? sx : sy;
        return rect.center +
            Offset(
              (fixture.cut.drawingStation(model.dx) - bounds.center.dx) * scale,
              -(model.dy - bounds.center.dy) * scale,
            );
      }

      await tester.tapAt(screen(const Offset(4, -.1)));
      await projection.settleProjection(tester);
      await tester.tapAt(screen(const Offset(7, .5)));
      await projection.settleProjection(tester);
      final detail = controller.project.sections.single.details.single;
      expect(detail.slabId, fixture.slab.id);
      expect(detail.station, closeTo(4, 1e-8));
      controller.undo();
      await projection.settleProjection(tester);
      expect(controller.project.sections.single.details, isEmpty);
      controller.redo();
      await projection.settleProjection(tester);
      expect(controller.project.sections.single.details.single.id, detail.id);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'slab drafting avoids duplicate canvas confirmation overlay',
    (tester) async {
      final draftModel = workspace.commands();
      addTearDown(draftModel.dispose);
      await workspace.open(tester, draftModel);
      await revision.tool(tester, ArchitectTool.slab);
      for (final point in const [Offset(0, 0), Offset(4, 0), Offset(4, 3)]) {
        await workspace.wallTap(tester, point);
      }
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('slab-draft-finish')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('slab-draft-cancel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('architect-draft-confirm')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('architect-draft-cancel')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('slab-draft-finish')));
      await tester.pumpAndSettle();
      expect(draftModel.project.activeStorey.slabs, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'slab new-point editing shows a single confirmation banner',
    (tester) async {
      final editModel = ArchitectCommandController(fixture.slabProject());
      addTearDown(editModel.dispose);
      await workspace.open(tester, editModel);
      await workspace.wallTap(tester, const Offset(2, 2));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('hatch-edit-new-point')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('architect-new-point-banner')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('architect-generic-command-overlay')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('polygon-edit-close')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('architect-command-apply')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('architect-command-cancel')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'offset edit handles stay constant in screen pixels at high zoom (> 80x)',
    () {
      const poly = [Offset(0, 0), Offset(4, 0), Offset(4, 4), Offset(0, 4)];
      const highScale = 200.0;
      const offsetLengthPx = 50.0;

      final edgeHandle = ArchitectPolygonEditor.offsetEdgeHandle(
        poly,
        0,
        highScale,
        offsetLengthPx,
      );
      final vertexHandle = ArchitectPolygonEditor.offsetVertexHandle(
        poly,
        0,
        highScale,
        offsetLengthPx,
      );

      expect((edgeHandle - const Offset(2, 0)).distance, closeTo(0.25, 1e-9));
      expect((vertexHandle - Offset.zero).distance, closeTo(0.25, 1e-9));

      final editor = BimPolygonEditor<Offset>(
        pointOf: (o) => o,
        isSnapped: (_) => false,
      );
      expect(
        editor.start(
          'slab',
          poly,
          edgeHandle,
          highScale,
          offsetLengthPx: offsetLengthPx,
        ),
        isTrue,
      );
      expect(editor.isOffsetHandle, isTrue);
      expect(editor.edge, isTrue);

      editor.cancel();
      final outdatedDistancePoint =
          const Offset(2, 0) + (edgeHandle - const Offset(2, 0)) / 0.25 * 0.625;
      expect(
        editor.start(
          'slab',
          poly,
          outdatedDistancePoint,
          highScale,
          offsetLengthPx: offsetLengthPx,
        ),
        isFalse,
      );
    },
  );

  testWidgets(
    'slab new-point mode allows free off-grid positioning along the edge',
    (tester) async {
      final model = ArchitectCommandController(fixture.slabProject());
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      workspace.camera(tester).fit(const Rect.fromLTWH(-1, -1, 12, 6));
      await tester.pumpAndSettle();

      await workspace.wallTap(tester, const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).selectedElementId, 'slab');

      await tester.tap(find.byKey(const ValueKey('hatch-edit-new-point')));
      await tester.pumpAndSettle();

      await tester.tapAt(workspace.screen(tester, const Offset(2.14, 0.005)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('architect-command-apply')));
      await tester.pumpAndSettle();

      final poly = model.project.activeStorey.slabs.single.polygon;
      expect(poly, hasLength(5));
      expect(poly[1].dy, closeTo(0, 1e-6));
      expect(poly[1].dx, inInclusiveRange(2.11, 2.17));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selected slab in correction mode moves only via Drag tool, not standard drag',
    (tester) async {
      final model = ArchitectCommandController(fixture.slabProject());
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      workspace.camera(tester).fit(const Rect.fromLTWH(-2, -2, 14, 8));
      await tester.pumpAndSettle();

      await workspace.wallTap(tester, const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).selectedElementId, 'slab');
      final originalPolygon = List<Offset>.from(
        model.project.activeStorey.slabs.single.polygon,
      );

      // Standard mouse drag inside slab body must not move it.
      final mouseDrag = await tester.startGesture(
        workspace.screen(tester, const Offset(2, 2)),
        kind: PointerDeviceKind.mouse,
      );
      await mouseDrag.moveTo(workspace.screen(tester, const Offset(4, 3)));
      await tester.pump();
      await mouseDrag.up();
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.slabs.single.polygon, originalPolygon);
      expect(model.canUndo, isFalse);

      // Standard drag near outside of slab contour must not grab or move it.
      final nearDrag = await tester.startGesture(
        workspace.screen(tester, const Offset(2.5, -0.3)),
        kind: PointerDeviceKind.mouse,
      );
      await nearDrag.moveTo(workspace.screen(tester, const Offset(2.5, -1.3)));
      await tester.pump();
      await nearDrag.up();
      await tester.pumpAndSettle();
      expect(model.project.activeStorey.slabs.single.polygon, originalPolygon);
      expect(model.canUndo, isFalse);

      // Explicit Drag tool moves the selected slab cleanly.
      final palette = tester.widget<ArchitectToolPalette>(
        find.byType(ArchitectToolPalette),
      );
      palette.onToolChanged(ArchitectTool.drag);
      await tester.pumpAndSettle();
      await tester.tapAt(workspace.screen(tester, Offset.zero));
      await tester.pump();
      await tester.tapAt(workspace.screen(tester, const Offset(1.5, 1.0)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('architect-command-apply')));
      await tester.pumpAndSettle();

      expect(
        model.project.activeStorey.slabs.single.polygon.first,
        const Offset(1.5, 1.0),
      );
      expect(model.canUndo, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tapping outside a selected slab deselects it and lets other elements select',
    (tester) async {
      final project = fixture.slabProject(
        walls: [
          editing.wall('w1', const Offset(12, 0), const Offset(12, 4)),
          editing.wall('w2', const Offset(0, 0), const Offset(10, 0)),
        ],
      );
      final model = ArchitectCommandController(project);
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      workspace.camera(tester).fit(const Rect.fromLTWH(-4, -4, 18, 12));
      await tester.pumpAndSettle();

      // Select slab.
      await workspace.wallTap(tester, const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).selectedElementId, 'slab');

      // Tapping empty space outside slab automatically deselects it.
      await workspace.wallTap(tester, const Offset(-2, -2));
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).selectedElementId, isNull);
      expect(find.byKey(const ValueKey('polygon-edit-close')), findsNothing);

      // Other elements select normally after slab deselection.
      await workspace.wallTap(tester, const Offset(12, 2));
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).selectedElementId, 'w1');

      // Re-select slab and tap directly onto another element (both distant and on-edge).
      await workspace.wallTap(tester, const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).selectedElementId, 'slab');

      await workspace.wallTap(tester, const Offset(12, 2));
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).selectedElementId, 'w1');

      await workspace.wallTap(tester, const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).selectedElementId, 'slab');

      await workspace.wallTap(tester, const Offset(5, 0));
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).selectedElementId, 'w2');
      expect(tester.takeException(), isNull);
    },
  );
}
