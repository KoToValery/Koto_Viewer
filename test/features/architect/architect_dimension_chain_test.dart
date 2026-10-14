import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/rendering/architect_dimension_chain_preview.dart';
import 'package:kotoview/src/features/architect/rendering/architect_dimension_layout.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_dimension_chain.dart';
import 'package:kotoview/src/features/architect/services/architect_element_tool.dart';
import 'package:kotoview/src/features/architect/widgets/architect_radial_menu.dart';
import 'package:kotoview/src/features/architect/models/architect_grid_axis.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_workspace_interaction_test.dart' as workspace;

ArchitectStorey scene() => const ArchitectStorey(
  id: 's',
  name: 'Floor',
  walls: [
    ArchitectWall(id: 'a', startPoint: Offset(0, 0), endPoint: Offset(0, 3)),
    ArchitectWall(id: 'b', startPoint: Offset(3, 0), endPoint: Offset(3, 3)),
    ArchitectWall(id: 'c', startPoint: Offset(6, 0), endPoint: Offset(6, 3)),
  ],
  cadPrimitives: [
    ArchitectCadPrimitive(
      id: 'reference',
      type: CadPrimitiveType.line,
      startPoint: Offset(-1, 4),
      endPoint: Offset(7, 4),
    ),
  ],
);

ArchitectDimension chain(ArchitectStorey storey) =>
    ArchitectDimensionChain.build(
      id: 'd',
      anchors: [
        for (final wall in storey.walls)
          ...ArchitectDimensionChain.wallFaces(wall, const Offset(0, 1.5)),
      ],
      direction: const Offset(1, 0),
      offset: 2,
    );

List<double> lengths(ArchitectDimension d) => [
  for (var i = 1; i < d.dimensionPoints.length; i++)
    (d.dimensionPoints[i] - d.dimensionPoints[i - 1]).distance,
];

ArchitectDimension? preview(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.byKey(const ValueKey('architect-dimension-chain-preview')),
            )
            .painter
        is ArchitectDimensionChainPreview
    ? (tester
                  .widget<CustomPaint>(
                    find.byKey(
                      const ValueKey('architect-dimension-chain-preview'),
                    ),
                  )
                  .painter
              as ArchitectDimensionChainPreview)
          .dimension
    : null;

Future<void> startChain(
  WidgetTester tester,
  ArchitectCommandController model,
) async {
  await workspace.open(tester, model);
  await editing.selectTool(tester, 'dimension');
  await tester.tap(find.byKey(const ValueKey('architect-dimension-chain')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Wall faces produce thicknesses and clear spans, including insulation and references',
    () {
      for (final reference in WallReferenceLine.values) {
        final s = scene().copyWith(
          walls: [
            for (final w in scene().walls)
              w.copyWith(
                referenceLine: reference,
                thickness: .37,
                wallTypeId: 'ext_25_12_eps',
              ),
          ],
        );
        final d = chain(s);
        expect(
          lengths(d),
          orderedEquals(
            [.37, 2.63, .37, 2.63, .37].map((v) => closeTo(v, 1e-9)),
          ),
        );
        expect(d.anchors, hasLength(6));
      }
    },
  );

  test(
    '3 m to 3.2 m updates the chain, deletion merges spans, Undo restores associations',
    () {
      final s = scene();
      final model = editing.seeded(s.copyWith(dimensions: [chain(s)]));
      addTearDown(model.dispose);
      final original = model.project;
      model.execute(
        MoveArchitectElement(
          storeyId: 's',
          elementId: 'b',
          delta: const Offset(.2, 0),
        ),
      );
      expect(
        lengths(model.project.activeStorey.dimensions.single)[1],
        closeTo(2.95, 1e-9),
      );
      expect(
        lengths(model.project.activeStorey.dimensions.single)[3],
        closeTo(2.55, 1e-9),
      );
      final moved = model.project;
      model.commit(
        model.project.updateActiveStorey(
          ArchitectElementTool().deleteElementById(
            model.project.activeStorey,
            'b',
          ),
        ),
      );
      final merged = model.project.activeStorey.dimensions.single;
      expect(merged.anchors, hasLength(4));
      expect(
        lengths(merged),
        orderedEquals([.25, 5.75, .25].map((v) => closeTo(v, 1e-9))),
      );
      model.undo();
      expect(model.project, same(moved));
      model.undo();
      expect(model.project, same(original));
      model.redo();
      model.redo();
      expect(
        model.project.activeStorey.dimensions.single.anchors,
        hasLength(4),
      );
    },
  );

  test(
    'Chain drag changes only perpendicular offset; geometry and bindings stay fixed',
    () {
      final s = scene();
      final model = editing.seeded(s.copyWith(dimensions: [chain(s)]));
      addTearDown(model.dispose);
      final original = model.project.activeStorey.dimensions.single;
      model.execute(
        const MoveArchitectElement(
          storeyId: 's',
          elementId: 'd',
          delta: Offset(7, -1),
        ),
      );
      final moved = model.project.activeStorey.dimensions.single;
      expect(moved.offsetDistance, 1);
      expect(moved.startPoint, original.startPoint);
      expect(moved.endPoint, original.endPoint);
      expect(
        moved.anchors.map((a) => a.toJson()),
        original.anchors.map((a) => a.toJson()),
      );
      expect(model.project.activeStorey.walls, scene().walls);
      model.undo();
      expect(model.project.activeStorey.dimensions.single.offsetDistance, 2);
    },
  );

  test(
    'Vertex and axis bindings survive JSON and deletion removes unusable dimensions',
    () {
      final model = editing.seeded(
        scene(),
        axes: [
          const StructuralGridAxis(
            id: 'axis',
            name: '1',
            start: Offset(0, -1),
            end: Offset(6, -1),
          ),
        ],
      );
      addTearDown(model.dispose);
      final axisAnchor = ArchitectDimensionChain.pickElement(
        model.project,
        'axis',
        const Offset(6, -1),
      )!;
      final lineAnchor = ArchitectDimensionChain.pickElement(
        model.project,
        'reference',
        const Offset(7, 4),
      )!;
      final d = ArchitectDimensionChain.build(
        id: 'd',
        anchors: [
          axisAnchor,
          lineAnchor,
          const ArchitectDimensionAnchor(point: Offset(10, 0)),
        ],
        direction: const Offset(1, 0),
      );
      model.commit(
        model.project.updateActiveStorey(
          model.project.activeStorey.copyWith(dimensions: [d]),
        ),
      );
      final loaded = ArchitectProject.fromJson(
        jsonDecode(jsonEncode(model.project.toJson())),
      );
      expect(
        loaded.activeStorey.dimensions.single.anchors.map((a) => a.toJson()),
        d.anchors.map((a) => a.toJson()),
      );
      model.execute(
        const MoveArchitectElement(
          storeyId: 's',
          elementId: 'reference',
          delta: Offset(1, 0),
        ),
      );
      expect(
        model.project.activeStorey.dimensions.single.anchors[1].point,
        const Offset(8, 4),
      );
      model.commit(model.project.copyWithGridAxes([]));
      expect(
        model.project.activeStorey.dimensions.single.anchors,
        hasLength(2),
      );
      model.commit(
        model.project.updateActiveStorey(
          model.project.activeStorey.copyWith(cadPrimitives: []),
        ),
      );
      expect(model.project.activeStorey.dimensions, isEmpty);
      model.undo();
      expect(
        model.project.activeStorey.dimensions.single.anchors,
        hasLength(2),
      );
    },
  );

  testWidgets(
    'Chain gathers faces, prompts on empty, finishes with placement and drags dynamically',
    (tester) async {
      final model = editing.seeded(scene());
      addTearDown(model.dispose);
      await startChain(tester, model);
      for (final x in [0.0, 3.0, 6.0]) {
        await workspace.wallTap(tester, Offset(x, 1.5));
      }
      expect(preview(tester)!.anchors, hasLength(6));
      expect(model.undoCount, 0);
      await workspace.wallTap(tester, const Offset(1.5, 3.3));
      expect(
        find.byKey(const ValueKey('architect-dimension-finish-dialog')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('architect-dimension-finish')),
      );
      await tester.pumpAndSettle();
      await workspace.wallTap(tester, const Offset(2, 3.2));
      expect(model.project.activeStorey.dimensions, hasLength(1));
      expect(model.undoCount, 1);
      final d = model.project.activeStorey.dimensions.single;
      expect(d.lineStart.dy, closeTo(3.2, .01));
      await tester.ensureVisible(find.byIcon(Icons.pan_tool_rounded));
      await tester.tap(find.byIcon(Icons.pan_tool_rounded));
      await tester.pumpAndSettle();
      await workspace.wallTap(tester, const Offset(2, 3.2));
      expect(workspace.overlay(tester).selectedElementIds, {d.id});
      final drag = await tester.startGesture(
        workspace.screen(tester, const Offset(2, 3.2)),
      );
      await tester.pump(const Duration(milliseconds: 281));
      await drag.moveTo(workspace.screen(tester, const Offset(2.6, 2.8)));
      await drag.up();
      await tester.pump();
      expect(
        model.project.activeStorey.dimensions.single.lineStart.dy,
        closeTo(2.8, .03),
      );
      expect(
        model.project.activeStorey.dimensions.single.startPoint,
        d.startPoint,
      );
      expect(model.undoCount, 2);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'Deleting the first witness preserves the positioned dimension line',
    () {
      final s = scene();
      final anchors = [
        for (var i = 0; i < s.walls.length; i++)
          ...ArchitectDimensionChain.wallFaces(s.walls[i], Offset(0, .5 + i)),
      ];
      final d = ArchitectDimensionChain.build(
        id: 'd',
        anchors: anchors,
        direction: const Offset(1, 0),
        offset: 3,
      );
      final model = editing.seeded(s.copyWith(dimensions: [d]));
      addTearDown(model.dispose);
      final lineY = d.lineStart.dy;
      model.commit(
        model.project.updateActiveStorey(
          ArchitectElementTool().deleteElementById(
            s.copyWith(dimensions: [d]),
            'a',
          ),
        ),
      );
      final next = model.project.activeStorey.dimensions.single;
      expect(next.lineStart.dy, lineY);
      expect(next.anchors, hasLength(4));
    },
  );

  test('An interior line point remains associative when endpoints change', () {
    final model = editing.seeded(scene());
    addTearDown(model.dispose);
    final anchor = ArchitectDimensionChain.pickElement(
      model.project,
      'reference',
      const Offset(3, 4),
    )!;
    expect(anchor.ratio, .5);
    final d = ArchitectDimensionChain.build(
      id: 'd',
      direction: const Offset(1, 0),
      anchors: [
        anchor,
        const ArchitectDimensionAnchor(point: Offset(10, 4)),
      ],
    );
    model.commit(
      model.project.updateActiveStorey(
        model.project.activeStorey.copyWith(dimensions: [d]),
      ),
    );
    model.commit(
      model.project.updateActiveStorey(
        model.project.activeStorey.copyWith(
          cadPrimitives: [
            model.project.activeStorey.cadPrimitives.single.copyWith(
              endPoint: const Offset(9, 4),
            ),
          ],
        ),
      ),
    );
    expect(
      model.project.activeStorey.dimensions.single.anchors.first.point,
      const Offset(4, 4),
    );
    expect(model.project.activeStorey.dimensions.single.length, 6);
  });

  testWidgets(
    'Exact chain offset uses project units and overall row is optional and selectable',
    (tester) async {
      final model = editing.seeded(scene());
      addTearDown(model.dispose);
      model.setUnits(ArchitectUnit.centimeters);
      await startChain(tester, model);
      await workspace.wallTap(tester, const Offset(0, 1.5));
      await workspace.wallTap(tester, const Offset(3, 1.5));
      await tester.tap(
        find.byKey(const ValueKey('architect-dimension-overall')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('architect-dimension-distance')),
      );
      await tester.pumpAndSettle();
      for (final digit in ['1', '0', '0']) {
        await tester.tap(find.byKey(ValueKey('shape-key-$digit')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const ValueKey('shape-save')));
      await tester.pumpAndSettle();
      final d = model.project.activeStorey.dimensions.single;
      expect(d.offsetDistance, 1);
      expect(d.showOverall, false);
      expect(model.undoCount, 1);
      final overall = ArchitectDimensionLayout.overallSegment(
        d.copyWith(showOverall: true),
        workspace.camera(tester).scale,
      )!;
      final tool = ArchitectElementTool();
      addTearDown(tool.dispose);
      expect(
        tool.hitTestElements(
          model.project.activeStorey.copyWith(
            dimensions: [d.copyWith(showOverall: true)],
          ),
          (overall.$1 + overall.$2) / 2,
          workspace.camera(tester).scale,
        ),
        contains(d.id),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Continue adds a free witness point; reference line sets direction; cancel adds no history',
    (tester) async {
      final model = editing.seeded(scene());
      addTearDown(model.dispose);
      await startChain(tester, model);
      await workspace.wallTap(tester, const Offset(0, 1.5));
      await workspace.wallTap(tester, const Offset(3, 1.5));
      await workspace.wallTap(tester, const Offset(1.5, 3.3));
      await tester.tap(
        find.byKey(const ValueKey('architect-dimension-continue')),
      );
      await tester.pumpAndSettle();
      await workspace.wallTap(tester, const Offset(2, 3.3));
      expect(preview(tester)!.anchors, hasLength(5));
      await tester.tap(
        find.byKey(const ValueKey('architect-dimension-direction')),
      );
      await tester.pump();
      await workspace.wallTap(tester, const Offset(2, 4));
      expect(preview(tester)!.unitVector, const Offset(1, 0));
      await tester.tap(find.byKey(const ValueKey('architect-draft-cancel')));
      await tester.pump();
      expect(preview(tester), isNull);
      expect(model.project.activeStorey.dimensions, isEmpty);
      expect(model.undoCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Single and multiple selection cycle overlaps and provide a group context menu',
    (tester) async {
      final model = editing.seeded(
        const ArchitectStorey(
          id: 's',
          name: 'Floor',
          columns: [ArchitectColumn(id: 'column', position: Offset.zero)],
          walls: [
            ArchitectWall(
              id: 'wall',
              startPoint: Offset(-3, 0),
              endPoint: Offset(3, 0),
            ),
          ],
        ),
      );
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tester.ensureVisible(find.byIcon(Icons.pan_tool_rounded));
      await tester.tap(find.byIcon(Icons.pan_tool_rounded));
      await tester.pump();
      await workspace.wallTap(tester, Offset.zero);
      expect(workspace.overlay(tester).selectedElementIds, {'column'});
      await workspace.wallTap(tester, Offset.zero);
      expect(workspace.overlay(tester).selectedElementIds, {'wall'});
      await tester.tap(find.byKey(const ValueKey('architect-multi-select')));
      await tester.pump();
      await workspace.wallTap(tester, Offset.zero);
      expect(workspace.overlay(tester).selectedElementIds, {'column', 'wall'});
      await tester.tap(
        find.byKey(const ValueKey('architect-selection-context')),
      );
      await tester.pumpAndSettle();
      final menu = tester.widget<ArchitectRadialMenu>(
        find.byType(ArchitectRadialMenu),
      );
      expect(menu.items.map((i) => i.action), [
        ArchitectRadialAction.move,
        ArchitectRadialAction.properties,
        ArchitectRadialAction.delete,
      ]);
      menu.onActionSelected(ArchitectRadialAction.delete);
      await tester.pump();
      expect(model.project.activeStorey.columns, isEmpty);
      expect(model.project.activeStorey.walls, isEmpty);
      expect(model.undoCount, 1);
      model.undo();
      await tester.pump();
      expect(model.project.activeStorey.columns, hasLength(1));
      expect(model.project.activeStorey.walls, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['en', 'bg']) {
    testWidgets(
      'Phone $language chain controls fit and render segmented dimensions',
      (tester) async {
        final model = editing.seeded(scene());
        addTearDown(model.dispose);
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundaryKey = GlobalKey();
        if (Platform.environment['UPDATE_ARCHITECT_CHAIN_PREVIEW'] == 'true') {
          await tester.runAsync(() async {
            await (FontLoader('Roboto')..addFont(
                  File(
                    'C:/Windows/Fonts/arial.ttf',
                  ).readAsBytes().then((b) => ByteData.sublistView(b)),
                ))
                .load();
            await (FontLoader('MaterialIcons')
                  ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
                .load();
          });
        }
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RepaintBoundary(
              key: boundaryKey,
              child: ArchitectWorkspaceScreen(commandController: model),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await editing.selectTool(tester, 'dimension');
        await tester.tap(
          find.byKey(const ValueKey('architect-dimension-chain')),
        );
        await tester.pump();
        for (final x in [0.0, 3.0, 6.0]) {
          await workspace.wallTap(tester, Offset(x, 1.5));
        }
        expect(preview(tester)!.anchors, hasLength(6));
        for (final key in [
          'architect-dimension-direction',
          'architect-dimension-distance',
          'architect-dimension-place',
        ]) {
          final rect = tester.getRect(find.byKey(ValueKey(key)));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(360));
        }
        if (language == 'bg' &&
            Platform.environment['UPDATE_ARCHITECT_CHAIN_PREVIEW'] == 'true') {
          await tester.tap(
            find.byKey(const ValueKey('architect-dimension-place')),
          );
          await tester.pump();
          await workspace.wallTap(tester, const Offset(2, 3.2));
          model.setUnits(ArchitectUnit.centimeters);
          await tester.pumpAndSettle();
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            File(
              'docs/images/architect_dimension_chain_phone.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
