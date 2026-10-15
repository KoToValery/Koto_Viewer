import 'architect_tool_test_helper.dart' as tool_ui;
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
import 'package:kotoview/src/features/architect/models/architect_window.dart';
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

Future<void> captureDimensionPhone(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String path,
) async {
  if (Platform.environment['UPDATE_ARCHITECT_CHAIN_PREVIEW'] != 'true') return;
  await tester.pumpAndSettle();
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

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
  test('Interior row uses inward end faces and keeps partition thickness', () {
    final s = scene();
    final d = ArchitectDimensionChain.build(
      id: 'interior',
      anchors: chain(s).anchors,
      direction: const Offset(1, 0),
      style: ArchitectDimensionStyle.interior,
    );
    expect(d.startPoint.dx, closeTo(.125, 1e-9));
    expect(d.endPoint.dx, closeTo(5.875, 1e-9));
    expect(d.anchors, hasLength(6));
    expect(d.witnessPoints, hasLength(4));
    expect(
      lengths(d),
      orderedEquals([2.75, .25, 2.75].map((v) => closeTo(v, 1e-9))),
    );
    final withOpening = ArchitectDimensionChain.addAnchors(d, const [
      ArchitectDimensionAnchor(
        point: Offset(1, 1.5),
        elementId: 'window',
        feature: 'opening',
      ),
      ArchitectDimensionAnchor(
        point: Offset(2, 1.5),
        elementId: 'window',
        feature: 'opening',
        side: .5,
      ),
    ]);
    final tiers = ArchitectDimensionLayout.layoutTiers(
      dimension: withOpening,
      scale: 100,
    );
    expect(tiers, hasLength(1));
    expect(tiers.single.points, hasLength(6));
    expect(ArchitectDimensionLayout.overallSegment(withOpening, 100), isNull);
    final loaded = ArchitectDimension.fromJson(
      jsonDecode(jsonEncode(d.toJson())),
    );
    expect(loaded.style, ArchitectDimensionStyle.interior);
    expect(lengths(loaded), lengths(d));
    final old = d.toJson()..remove('style');
    expect(
      ArchitectDimension.fromJson(old).style,
      ArchitectDimensionStyle.exterior,
    );
  });

  for (final style in [
    ArchitectDimensionStyle.exterior,
    ArchitectDimensionStyle.interior,
  ]) {
    test(
      '$style adding an earlier wall preserves the line and all associations',
      () {
        final s = scene();
        final d = ArchitectDimensionChain.build(
          id: 'd',
          anchors: [
            ...ArchitectDimensionChain.wallFaces(
              s.walls[1],
              const Offset(3, 1),
            ),
            ...ArchitectDimensionChain.wallFaces(
              s.walls[2],
              const Offset(6, 2),
            ),
          ],
          direction: const Offset(1, 0),
          offset: -2,
          style: style,
        ).copyWith(customText: 'custom', showOverall: false);
        final additions = ArchitectDimensionChain.wallFaces(
          s.walls.first,
          const Offset(0, .4),
        );
        final extended = ArchitectDimensionChain.addAnchors(d, [
          ...additions,
          ...ArchitectDimensionChain.wallFaces(
            s.walls.first,
            const Offset(0, 2.5),
          ),
        ]);
        expect(extended.lineStart.dy, closeTo(d.lineStart.dy, 1e-9));
        expect(extended.anchors, hasLength(6));
        expect(extended.style, style);
        expect(extended.customText, 'custom');
        expect(extended.showOverall, false);
        final model = editing.seeded(s.copyWith(dimensions: [extended]));
        addTearDown(model.dispose);
        model.execute(
          const MoveArchitectElement(
            storeyId: 's',
            elementId: 'b',
            delta: Offset(.2, 0),
          ),
        );
        expect(model.project.activeStorey.dimensions.single.style, style);
        expect(
          lengths(model.project.activeStorey.dimensions.single),
          contains(closeTo(2.95, 1e-9)),
        );
      },
    );

    testWidgets(
      '$style adds a missed wall to a saved dimension in one undo step',
      (tester) async {
        final s = scene();
        final d = chain(
          s.copyWith(walls: [s.walls.first, s.walls.last]),
        ).copyWith(style: style);
        final model = editing.seeded(s.copyWith(dimensions: [d]));
        addTearDown(model.dispose);
        await workspace.open(tester, model);
        await tool_ui.prepare(tester, Icons.pan_tool_rounded);
        await tester.tap(find.byIcon(Icons.pan_tool_rounded));
        await tester.pump();
        final before = model.project.activeStorey.dimensions.single;
        await workspace.wallTap(
          tester,
          (before.lineStart + before.lineEnd) / 2 + const Offset(-1, 0),
        );
        expect(workspace.overlay(tester).selectedElementIds, {d.id});
        await tester.tap(
          find.byKey(const ValueKey('architect-dimension-add-walls')),
        );
        await tester.pump();
        await workspace.wallTap(tester, const Offset(3, .7));
        await workspace.wallTap(tester, const Offset(3, 2.1));
        expect(preview(tester)!.anchors, hasLength(6));
        expect(
          preview(tester)!.lineStart.dy,
          closeTo(before.lineStart.dy, 1e-9),
        );
        expect(
          model.project.activeStorey.dimensions.single.anchors,
          hasLength(4),
        );
        await tester.tap(
          find.byKey(const ValueKey('architect-dimension-place')),
        );
        await tester.pump();
        final saved = model.project.activeStorey.dimensions.single;
        expect(saved.id, d.id);
        expect(saved.style, style);
        expect(saved.anchors, hasLength(6));
        expect(saved.lineStart.dy, closeTo(before.lineStart.dy, 1e-9));
        expect(model.undoCount, 1);
        model.undo();
        expect(
          model.project.activeStorey.dimensions.single.anchors,
          hasLength(4),
        );
        model.redo();
        expect(
          model.project.activeStorey.dimensions.single.anchors,
          hasLength(6),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Interior tool places one row between the inward wall faces', (
    tester,
  ) async {
    final model = editing.seeded(scene());
    addTearDown(model.dispose);
    await startChain(tester, model);
    await tester.tap(
      find.byKey(const ValueKey('architect-dimension-interior')),
    );
    await tester.pump();
    for (final x in [0.0, 3.0, 6.0]) {
      await workspace.wallTap(tester, Offset(x, 1.5));
    }
    expect(preview(tester)!.style, ArchitectDimensionStyle.interior);
    expect(
      find.byKey(const ValueKey('architect-dimension-overall')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('architect-dimension-place')));
    await tester.pump();
    await workspace.wallTap(tester, const Offset(2, 2.2));
    final saved = model.project.activeStorey.dimensions.single;
    expect(
      [saved.startPoint.dx, saved.endPoint.dx]..sort(),
      orderedEquals([closeTo(.125, .001), closeTo(5.875, .001)]),
    );
    expect(saved.lineStart.dy, closeTo(2.2, .01));
    expect(
      ArchitectDimensionLayout.layoutTiers(dimension: saved, scale: 100),
      hasLength(1),
    );
    expect(model.undoCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Single dimension previews its targets and waits for line placement',
    (tester) async {
      final model = editing.seeded(scene());
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await editing.selectTool(tester, 'dimension');
      await workspace.wallTap(tester, const Offset(1, 1));
      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      await mouse.addPointer(
        location: workspace.screen(tester, const Offset(1, 1)),
      );
      await mouse.moveTo(workspace.screen(tester, const Offset(4, 2)));
      await tester.pump();
      expect(preview(tester), isNotNull);
      expect(preview(tester)!.style, ArchitectDimensionStyle.single);
      await mouse.removePointer();
      await workspace.wallTap(tester, const Offset(4, 2));
      expect(model.project.activeStorey.dimensions, isEmpty);
      final draft = preview(tester)!;
      final target = const Offset(2, 3.4);
      await workspace.wallTap(tester, target);
      final saved = model.project.activeStorey.dimensions.single;
      expect(saved.style, ArchitectDimensionStyle.single);
      expect(
        saved.anchors.map((a) => a.point),
        draft.anchors.map((a) => a.point),
      );
      expect(
        ArchitectDimensionChain.dot(target - saved.lineStart, saved.normal),
        closeTo(0, .01),
      );
      final tiers = ArchitectDimensionLayout.layoutTiers(
        dimension: saved,
        scale: 100,
      );
      final witnesses = ArchitectDimensionLayout.witnessSegments(saved, tiers);
      expect(witnesses, hasLength(2));
      for (var i = 0; i < witnesses.length; i++) {
        expect(
          (witnesses[i].$2 - saved.dimensionPoints[i]).distance,
          closeTo(.1, 1e-9),
        );
        expect((witnesses[i].$2 - witnesses[i].$1).distance, closeTo(.2, 1e-9));
        expect(
          (witnesses[i].$1 - saved.witnessPoints[i]).distance,
          greaterThan(.3),
        );
      }
      expect(model.undoCount, 1);
      expect(tester.takeException(), isNull);
    },
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Witnesses stay compact at every row, orientation and annotation scale',
    () {
      for (final style in ArchitectDimensionStyle.values) {
        for (final direction in [
          const Offset(1, 0),
          const Offset(0, 1),
          const Offset(.6, .8),
        ]) {
          for (final offset in [-5.0, 5.0]) {
            final dimension = ArchitectDimensionChain.build(
              id: 'compact',
              direction: direction,
              offset: offset,
              style: style,
              anchors: [
                for (final distance in [0.0, 3.0, 6.0])
                  ArchitectDimensionAnchor(point: direction * distance),
                for (final distance in [1.0, 2.0])
                  ArchitectDimensionAnchor(
                    point: direction * distance,
                    feature: 'opening',
                  ),
              ],
            );
            for (final scale in ArchitectDimensionScale.values) {
              final tiers = ArchitectDimensionLayout.layoutTiers(
                dimension: dimension,
                scale: 100,
              );
              expect(
                tiers,
                hasLength(style == ArchitectDimensionStyle.exterior ? 3 : 1),
              );
              final segments = ArchitectDimensionLayout.witnessSegments(
                dimension,
                tiers,
                dimensionScale: scale,
              );
              final points = tiers.expand((tier) => tier.points).toList();
              expect(segments, hasLength(points.length));
              for (var i = 0; i < segments.length; i++) {
                final segment = segments[i];
                expect(
                  ((segment.$1 + segment.$2) / 2 - points[i]).distance,
                  closeTo(0, 1e-9),
                );
                expect(
                  (segment.$2 - segment.$1).distance / scale.denominator * 1000,
                  closeTo(2, 1e-9),
                );
                expect(
                  ArchitectDimensionChain.dot(
                    segment.$2 - segment.$1,
                    direction,
                  ),
                  closeTo(0, 1e-9),
                );
                for (final endpoint in [segment.$1, segment.$2]) {
                  expect(
                    dimension.witnessPoints.every(
                      (p) => (endpoint - p).distance > 4,
                    ),
                    isTrue,
                  );
                }
              }
            }
          }
        }
      }
    },
  );

  test(
    'Dimension text has requested paper sizes and scale survives save and geometry undo',
    () {
      expect(ArchitectDimensionScale.scale50.textHeight, closeTo(.075, 1e-9));
      expect(ArchitectDimensionScale.scale100.textHeight, closeTo(.22, 1e-9));
      final s = scene();
      final model = editing.seeded(s.copyWith(dimensions: [chain(s)]));
      addTearDown(model.dispose);
      model.setDimensionScale(ArchitectDimensionScale.scale50);
      expect(model.undoCount, 0);
      final loaded = ArchitectProject.fromJson(
        jsonDecode(jsonEncode(model.project.toJson())),
      );
      expect(loaded.dimensionScale, ArchitectDimensionScale.scale50);
      final legacy = loaded.toJson()..remove('dimensionScale');
      expect(
        ArchitectProject.fromJson(legacy).dimensionScale,
        ArchitectDimensionScale.scale100,
      );
      model.execute(
        const MoveArchitectElement(
          storeyId: 's',
          elementId: 'b',
          delta: Offset(.2, 0),
        ),
      );
      model.setDimensionScale(ArchitectDimensionScale.scale100);
      expect(model.undoCount, 1);
      model.undo();
      expect(model.project.dimensionScale, ArchitectDimensionScale.scale100);
      expect(
        model.project.activeStorey.walls[1].startPoint,
        s.walls[1].startPoint,
      );
      model.redo();
      expect(model.project.dimensionScale, ArchitectDimensionScale.scale100);
      expect(
        model.project.activeStorey.walls[1].startPoint,
        s.walls[1].startPoint + const Offset(.2, 0),
      );
    },
  );

  test(
    'Wall faces dimension core thicknesses and clear spans without insulation',
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
            [.25, 2.75, .25, 2.75, .25].map((v) => closeTo(v, 1e-9)),
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
      await tool_ui.prepare(tester, Icons.pan_tool_rounded);
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
      await tool_ui.prepare(tester, Icons.pan_tool_rounded);
      await tester.tap(find.byIcon(Icons.pan_tool_rounded));
      await tester.pump();
      await workspace.wallTap(tester, Offset.zero);
      expect(workspace.overlay(tester).selectedElementIds, {'column'});
      await workspace.wallTap(tester, Offset.zero);
      expect(workspace.overlay(tester).selectedElementIds, {'column', 'wall'});
      await workspace.wallTap(tester, Offset.zero);
      expect(workspace.overlay(tester).selectedElementIds, {'wall'});
      await workspace.wallTap(tester, Offset.zero);
      expect(workspace.overlay(tester).selectedElementIds, isEmpty);
      await workspace.wallTap(tester, Offset.zero);
      await workspace.wallTap(tester, Offset.zero);
      expect(workspace.overlay(tester).selectedElementIds, {'column', 'wall'});
      final held = await tester.startGesture(workspace.screen(tester, const Offset(1, 0)));
      await tester.pump(const Duration(milliseconds: 750));
      await held.up();
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
          await captureDimensionPhone(
            tester,
            boundaryKey,
            'docs/images/architect_dimension_chain_phone.png',
          );
          model.setDimensionScale(ArchitectDimensionScale.scale50);
          await tester.pumpAndSettle();
          await captureDimensionPhone(
            tester,
            boundaryKey,
            'docs/images/architect_dimension_scale50_phone.png',
          );
          model.setDimensionScale(ArchitectDimensionScale.scale100);
          await tester.pumpAndSettle();
        }
        await tester.tap(
          find.byKey(const ValueKey('architect-dimension-interior')),
        );
        await tester.pump();
        for (final x in [0.0, 3.0, 6.0]) {
          await workspace.wallTap(tester, Offset(x, 1.5));
        }
        expect(preview(tester)!.style, ArchitectDimensionStyle.interior);
        expect(
          find.byKey(const ValueKey('architect-dimension-overall')),
          findsNothing,
        );
        for (final key in [
          'architect-dimension-direction',
          'architect-dimension-distance',
          'architect-dimension-place',
        ]) {
          expect(
            tester.getRect(find.byKey(ValueKey(key))).right,
            lessThanOrEqualTo(360),
          );
        }
        await tester.tap(
          find.byKey(const ValueKey('architect-dimension-place')),
        );
        await tester.pump();
        await workspace.wallTap(tester, const Offset(2, 1));
        if (language == 'bg') {
          await captureDimensionPhone(
            tester,
            boundaryKey,
            'docs/images/architect_dimension_interior_phone.png',
          );
        }
        await tester.tap(
          find.byKey(const ValueKey('architect-dimension-single')),
        );
        await tester.pump();
        await workspace.wallTap(tester, const Offset(.125, 2));
        await workspace.wallTap(tester, const Offset(2.875, 2));
        expect(preview(tester)!.style, ArchitectDimensionStyle.single);
        expect(
          tester
              .getRect(
                find.byKey(const ValueKey('architect-dimension-distance')),
              )
              .right,
          lessThanOrEqualTo(360),
        );
        if (language == 'bg') {
          await captureDimensionPhone(
            tester,
            boundaryKey,
            'docs/images/architect_dimension_single_phone.png',
          );
        }
        final count = model.project.activeStorey.dimensions.length;
        await tester.tap(find.byKey(const ValueKey('architect-draft-cancel')));
        await tester.pump();
        expect(preview(tester), isNull);
        expect(model.project.activeStorey.dimensions, hasLength(count));
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'Opening anchors provide both jambs and resolve associatively on host wall',
    () {
      const wall = ArchitectWall(
        id: 'wall_with_win',
        startPoint: Offset(0, 0),
        endPoint: Offset(6, 0),
        thickness: 0.25,
        windows: [
          ArchitectWindow(
            id: 'win1',
            wallId: 'wall_with_win',
            offsetRatio: 0.5,
            width: 1.20,
            uuid: 'w1',
          ),
        ],
      );
      final anchors = ArchitectDimensionChain.openingAnchors(wall, 'win1');
      expect(anchors, hasLength(2));
      expect(anchors[0].side, -0.5);
      expect(anchors[1].side, 0.5);
      expect(
        (anchors[1].point - anchors[0].point).distance,
        closeTo(1.20, 1e-6),
      );
      expect(anchors[0].point.dx, closeTo(2.40, 1e-6));
      expect(anchors[1].point.dx, closeTo(3.60, 1e-6));
    },
  );

  test(
    '3-tier dimension layout produces base, openings from outer corner, and overall tiers',
    () {
      const wall = ArchitectWall(
        id: 'host_wall',
        startPoint: Offset(0, 0),
        endPoint: Offset(6, 0),
        thickness: 0.25,
        windows: [
          ArchitectWindow(
            id: 'w1',
            wallId: 'host_wall',
            offsetRatio: 0.25,
            width: 1.20,
            uuid: 'u1',
          ),
          ArchitectWindow(
            id: 'w2',
            wallId: 'host_wall',
            offsetRatio: 0.75,
            width: 1.20,
            uuid: 'u2',
          ),
        ],
      );
      final storey = const ArchitectStorey(
        id: 's',
        name: 'Floor',
        walls: [wall],
      );
      final openingAnchors = [
        ...ArchitectDimensionChain.openingAnchors(wall, 'w1'),
        ...ArchitectDimensionChain.openingAnchors(wall, 'w2'),
      ];
      final dim = ArchitectDimensionChain.build(
        id: 'dim3tier',
        anchors: [
          const ArchitectDimensionAnchor(point: Offset(0, 0)),
          ...openingAnchors,
          const ArchitectDimensionAnchor(point: Offset(6, 0)),
        ],
        direction: const Offset(1, 0),
        offset: 1.5,
      );

      final tiers = ArchitectDimensionLayout.layoutTiers(
        dimension: dim,
        scale: 50.0,
        storey: storey,
      );

      expect(tiers, hasLength(3));
      expect(tiers[0].tierIndex, 1); // Base row
      expect(tiers[1].tierIndex, 2); // Openings row
      expect(tiers[2].tierIndex, 3); // Overall row

      // Tier 2 should start at wall exterior corner (0) and end at (6)
      final t2Points = tiers[1].points;
      expect(t2Points.first.dx, closeTo(0.0, 1e-4));
      expect(t2Points.last.dx, closeTo(6.0, 1e-4));

      // Segments on Tier 2: pier1, win1, pier2, win2, pier3
      final t2Segments = tiers[1].segments;
      expect(t2Segments, hasLength(5));
      final segLengths = [for (final s in t2Segments) (s.$2 - s.$1).distance];
      // sum of all segments must equal wall length (6.0)
      final totalT2 = segLengths.reduce((a, b) => a + b);
      expect(totalT2, closeTo(6.0, 1e-4));
      // Window opening widths should be 1.20
      expect(segLengths[1], closeTo(1.20, 1e-4));
      expect(segLengths[3], closeTo(1.20, 1e-4));

      // Tier 3 is the overall row (length 6.0)
      expect(
        (tiers[2].points[1] - tiers[2].points[0]).distance,
        closeTo(6.0, 1e-4),
      );
    },
  );
}
