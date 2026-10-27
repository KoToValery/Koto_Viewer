import 'package:kotoview/src/features/architect/widgets/architect_tool_palette.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'architect_tool_test_helper.dart' as tool_ui;
import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_wall_type.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/models/architect_zone.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_layers.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_network.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_snap.dart';
import 'package:kotoview/src/features/architect/rendering/architect_dimension_layout.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_selection.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'architect_workspace_interaction_test.dart' as workspace;

ArchitectWall wall(String id, Offset a, Offset b, {bool exterior = false}) =>
    ArchitectWall(
      id: id,
      startPoint: a,
      endPoint: b,
      thickness: exterior ? .37 : .25,
      wallTypeId: exterior ? 'ext_25_12_eps' : null,
    );
const polygon = [Offset(-1, -1), Offset(1, -1), Offset(1, 1), Offset(-1, 1)];
ArchitectCommandController seeded(
  ArchitectStorey storey, {
  List<StructuralGridAxis> axes = const [],
}) {
  final base = workspace.commands();
  final project = base.project.copyWith(
    storeys: [storey],
    gridAxes: axes,
    sections: const [],
    elevations: const [],
    wallTypes: ArchitectWallType.standardCatalog(),
  );
  base.dispose();
  return ArchitectCommandController(project);
}

Future<void> selectTool(WidgetTester tester, String name) async {
  final icon = switch (name) {
    'wall' => Icons.line_weight_rounded,
    'door' => Icons.meeting_room_rounded,
    'window' => Icons.window_rounded,
    'column' => Icons.view_column_rounded,
    'beam' => Icons.horizontal_rule_rounded,
    'slab' => Icons.layers_rounded,
    'opening' => Icons.crop_free_rounded,
    'stair' => Icons.stairs_rounded,
    'zone' => Icons.space_dashboard_rounded,
    'dimension' => Icons.straighten_rounded,
    'level' => Icons.change_history_rounded,
    'text' => Icons.title_rounded,
    'CAD' => Icons.timeline_rounded,
    'axis' => Icons.grid_on_rounded,
    _ => throw ArgumentError(name),
  };
  await tool_ui.prepare(tester, icon);
  await tester.tap(find.byIcon(icon));
  await tester.pumpAndSettle();
}

Future<void> ensureSelectionTool(WidgetTester tester) async {
  // Selection is explicitly chosen; drawing tools no longer acquire elements.
  final palette = tester.widget<ArchitectToolPalette>(find.byType(ArchitectToolPalette));
  if (palette.activeTool != ArchitectTool.select) {
    await tester.tap(find.byKey(const ValueKey('architect-tool-select')));
    await tester.pumpAndSettle();
  }
}

Future<void> hold(WidgetTester tester, Offset point) async {
  await ensureSelectionTool(tester);
  final g = await tester.startGesture(workspace.screen(tester, point));
  await tester.pump(const Duration(milliseconds: 451));
  await g.up();
  await tester.pumpAndSettle();
}

Future<void> contextHold(WidgetTester tester, Offset point) async {
  await ensureSelectionTool(tester);
  final gesture = await tester.startGesture(workspace.screen(tester, point));
  await tester.pump(const Duration(milliseconds: 701));
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  test(
    'Axis lies in brick; inner/outer and flipped exterior are physical faces',
    () {
      for (final side in WallExteriorSide.values) {
        for (final ref in [
          WallReferenceLine.center,
          WallReferenceLine.inner,
          WallReferenceLine.outer,
        ]) {
          final w = wall(
            'w',
            Offset.zero,
            const Offset(4, 0),
            exterior: true,
          ).copyWith(referenceLine: ref, exteriorSide: side);
          final layers = ArchitectWallLayers.build([w], []);
          final sign = w.exteriorSign;
          if (ref == WallReferenceLine.center) {
            expect(w.coreCenterStart, Offset.zero);
            expect(layers.core.getBounds().center.dy, closeTo(0, 1e-7));
          } else {
            final face =
                w.centerStart +
                w.normalVector *
                    sign *
                    (ref == WallReferenceLine.inner
                        ? -w.thickness / 2
                        : w.thickness / 2);
            expect(face.distance, closeTo(0, 1e-9));
          }
          final saved = ArchitectWall.fromJson(w.toJson());
          expect(saved.exteriorSide, side);
          expect(saved.polygonCorners, w.polygonCorners);
        }
      }
    },
  );
  test(
    'Axis crossing wins a closer axis projection; orthogonal capture is stronger',
    () {
      final model = seeded(
        const ArchitectStorey(id: 's', name: 's'),
        axes: const [
          StructuralGridAxis(
            id: 'x',
            name: 'X',
            start: Offset(-5, 0),
            end: Offset(5, 0),
          ),
          StructuralGridAxis(
            id: 'y',
            name: 'Y',
            start: Offset(0, -5),
            end: Offset(0, 5),
          ),
        ],
      );
      addTearDown(model.dispose);
      final snap = ArchitectWallSnap.resolve(
        raw: const Offset(.06, .08),
        project: model.project,
        scale: 100,
      );
      expect(snap.point, Offset.zero);
      expect(snap.snapLabel, 'Axis intersection');
      final empty = workspace.commands();
      addTearDown(empty.dispose);
      for (final end in [
        const Offset(2, .24),
        const Offset(.24, 2),
        const Offset(-2, .24),
      ]) {
        final s = ArchitectWallSnap.resolve(
          raw: end,
          anchor: Offset.zero,
          project: empty.project,
          scale: 100,
        );
        expect(s.point.dx.abs() < 1e-9 || s.point.dy.abs() < 1e-9, isTrue);
      }
    },
  );
  test(
    'Dimension badge never overlaps walls for all angles, references and scales',
    () {
      for (final scale in [25.0, 100.0, 500.0]) {
        for (var degrees = 0; degrees < 360; degrees += 15) {
          for (final ref in [
            WallReferenceLine.center,
            WallReferenceLine.inner,
            WallReferenceLine.outer,
          ]) {
            final angle = degrees * math.pi / 180;
            final w = wall(
              'w',
              Offset.zero,
              Offset(math.cos(angle) * 4, math.sin(angle) * 4),
              exterior: true,
            ).copyWith(referenceLine: ref);
            final body = ArchitectWallNetwork.body([w]);
            final rect = ArchitectDimensionLayout.wallBadge(
              w,
              const Size(95, 24),
              scale,
              obstacles: body,
            );
            expect(
              Path.combine(
                PathOperation.intersect,
                body,
                Path()..addRect(rect),
              ).computeMetrics(),
              isEmpty,
            );
          }
        }
      }
    },
  );
  test(
    'Group move carries each selected wall and its openings once; single Undo restores all',
    () {
      final a = wall('a', Offset.zero, const Offset(4, 0)).addDoor(
        const ArchitectDoor(id: 'd', wallId: 'a', offsetRatio: .5, uuid: 'd'),
      );
      final model = seeded(
        ArchitectStorey(
          id: 's',
          name: 's',
          walls: [a, wall('b', const Offset(4, 0), const Offset(4, 3))],
          columns: const [ArchitectColumn(id: 'c', position: Offset(1, 2))],
        ),
      );
      addTearDown(model.dispose);
      final old = model.project;
      model.execute(
        const MoveArchitectElements(
          storeyId: 's',
          elementIds: {'a', 'b', 'c', 'd'},
          delta: Offset(1, 1),
        ),
      );
      expect(model.project.activeStorey.walls[0].endPoint, const Offset(5, 1));
      expect(
        model.project.activeStorey.walls[1].startPoint,
        const Offset(5, 1),
      );
      expect(model.project.activeStorey.walls[0].doors.single.offsetRatio, .5);
      expect(
        model.project.activeStorey.columns.single.position,
        const Offset(2, 3),
      );
      model.undo();
      expect(identical(model.project, old), isTrue);
      model.execute(
        const MoveArchitectElements(
          storeyId: 's',
          elementIds: {'d'},
          delta: Offset(.5, 0),
        ),
      );
      expect(
        model.project.activeStorey.walls[0].doors.single.offsetRatio,
        .625,
      );
    },
  );
  test(
    'Extend start preserves opening position; join three walls is atomic and rejects invalid edits',
    () {
      final a = wall('a', Offset.zero, const Offset(4, 0)).addDoor(
        const ArchitectDoor(id: 'd', wallId: 'a', offsetRatio: .5, uuid: 'd'),
      );
      final model = seeded(ArchitectStorey(id: 's', name: 's', walls: [a]));
      addTearDown(model.dispose);
      model.execute(
        const ExtendArchitectWall(
          storeyId: 's',
          wallId: 'a',
          target: Offset(-2, 0),
        ),
      );
      final w = model.project.activeStorey.walls.single;
      expect(
        w.startPoint.dx + w.length * w.doors.single.offsetRatio,
        closeTo(2, 1e-9),
      );
      final extended = model.project;
      expect(
        () => model.execute(
          const ExtendArchitectWall(
            storeyId: 's',
            wallId: 'a',
            target: Offset(1, 0),
          ),
        ),
        throwsArgumentError,
      );
      expect(identical(model.project, extended), isTrue);
      final group = seeded(
        ArchitectStorey(
          id: 's',
          name: 's',
          walls: [
            wall('a', Offset.zero, const Offset(2, 0)),
            wall('b', const Offset(3, 1), const Offset(3, 4)),
            wall('c', const Offset(5, 5), const Offset(1, 5)),
          ],
        ),
      );
      addTearDown(group.dispose);
      final old = group.project;
      group.execute(
        const JoinArchitectWalls(storeyId: 's', wallIds: {'a', 'b', 'c'}),
      );
      expect(group.project.activeStorey.walls[0].endPoint, const Offset(3, 0));
      expect(
        group.project.activeStorey.walls[1].startPoint,
        const Offset(3, 0),
      );
      expect(group.project.activeStorey.walls[1].endPoint, const Offset(3, 5));
      group.undo();
      expect(identical(group.project, old), isTrue);
    },
  );
  test(
    'Wall layer and mixed element properties persist, validate and Undo together',
    () {
      final model = seeded(
        ArchitectStorey(
          id: 's',
          name: 's',
          walls: [wall('a', Offset.zero, const Offset(4, 0), exterior: true)],
          columns: const [ArchitectColumn(id: 'c', position: Offset(1, 2))],
          slabs: const [ArchitectSlab(id: 'sl', polygon: polygon)],
        ),
      );
      addTearDown(model.dispose);
      final old = model.project;
      model.execute(
        const SetArchitectElementProperties(
          storeyId: 's',
          elementIds: {'a'},
          values: {
            'height': 3.2,
            'coreThickness': .3,
            'insulationThicknessOverride': .15,
          },
          textValues: {'exteriorSide': 'right', 'referenceLine': 'inner'},
        ),
      );
      final w = model.project.activeStorey.walls.single;
      expect(w.thickness, closeTo(.45, 1e-9));
      expect(w.coreThickness, closeTo(.3, 1e-9));
      expect(w.height, 3.2);
      expect(ArchitectWall.fromJson(w.toJson()).insulationThickness, .15);
      model.undo();
      expect(identical(model.project, old), isTrue);
      model.execute(
        const SetArchitectElementProperties(
          storeyId: 's',
          elementIds: {'a', 'c'},
          values: {'height': 3.5},
        ),
      );
      expect(model.project.activeStorey.columns.single.height, 3.5);
      expect(model.project.activeStorey.walls.single.height, 3.5);
      expect(
        () => model.execute(
          const SetArchitectElementProperties(
            storeyId: 's',
            elementIds: {'a'},
            values: {'coreThickness': -1},
          ),
        ),
        throwsArgumentError,
      );
      expect(
        ArchitectSelection.bounds(model.project, 'sl'),
        const Rect.fromLTRB(-1, -1, 1, 1),
      );
    },
  );

  final cases = <(String, ArchitectStorey, Offset)>[
    (
      'wall',
      ArchitectStorey(
        id: 's',
        name: 's',
        walls: [wall('a', const Offset(-2, 0), const Offset(2, 0))],
      ),
      Offset.zero,
    ),
    (
      'door',
      ArchitectStorey(
        id: 's',
        name: 's',
        walls: [
          wall('a', const Offset(-2, 0), const Offset(2, 0)).addDoor(
            const ArchitectDoor(
              id: 'd',
              wallId: 'a',
              offsetRatio: .5,
              uuid: 'd',
            ),
          ),
        ],
      ),
      Offset.zero,
    ),
    (
      'window',
      ArchitectStorey(
        id: 's',
        name: 's',
        walls: [
          wall('a', const Offset(-2, 0), const Offset(2, 0)).addWindow(
            const ArchitectWindow(
              id: 'win',
              wallId: 'a',
              offsetRatio: .5,
              uuid: 'win',
            ),
          ),
        ],
      ),
      Offset.zero,
    ),
    (
      'column',
      const ArchitectStorey(
        id: 's',
        name: 's',
        columns: [ArchitectColumn(id: 'c', position: Offset.zero)],
      ),
      Offset.zero,
    ),
    (
      'beam',
      const ArchitectStorey(
        id: 's',
        name: 's',
        beams: [
          ArchitectBeam(
            id: 'b',
            startPoint: Offset(-2, 0),
            endPoint: Offset(2, 0),
          ),
        ],
      ),
      Offset.zero,
    ),
    (
      'slab',
      const ArchitectStorey(
        id: 's',
        name: 's',
        slabs: [ArchitectSlab(id: 'sl', polygon: polygon)],
      ),
      Offset.zero,
    ),
    (
      'zone',
      const ArchitectStorey(
        id: 's',
        name: 's',
        zones: [
          ArchitectZone(
            id: 'z',
            name: 'z',
            category: ArchitectZoneCategory.custom,
            polygon: polygon,
            isAutoBoundary: false,
          ),
        ],
      ),
      Offset.zero,
    ),
    (
      'opening',
      const ArchitectStorey(
        id: 's',
        name: 's',
        openings: [ArchitectOpening(id: 'o', boundary: polygon)],
      ),
      Offset.zero,
    ),
    (
      'stair',
      const ArchitectStorey(
        id: 's',
        name: 's',
        stairs: [
          ArchitectStair(
            id: 'st',
            startPoint: Offset(-2, 0),
            endPoint: Offset(2, 0),
          ),
        ],
      ),
      Offset.zero,
    ),
    (
      'dimension',
      const ArchitectStorey(
        id: 's',
        name: 's',
        dimensions: [
          ArchitectDimension(
            id: 'dim',
            startPoint: Offset(-2, 0),
            endPoint: Offset(2, 0),
          ),
        ],
      ),
      const Offset(0, .5),
    ),
    (
      'level',
      const ArchitectStorey(
        id: 's',
        name: 's',
        elevationMarkers: [
          ArchitectElevationMarker(
            id: 'e',
            position: Offset.zero,
            elevation: 0,
          ),
        ],
      ),
      Offset.zero,
    ),
    (
      'text',
      const ArchitectStorey(
        id: 's',
        name: 's',
        annotations: [
          ArchitectAnnotation(id: 't', position: Offset.zero, text: 't'),
        ],
      ),
      Offset.zero,
    ),
    (
      'CAD',
      const ArchitectStorey(
        id: 's',
        name: 's',
        cadPrimitives: [
          ArchitectCadPrimitive(
            id: 'cad',
            type: CadPrimitiveType.line,
            startPoint: Offset(-2, 0),
            endPoint: Offset(2, 0),
          ),
        ],
      ),
      Offset.zero,
    ),
  ];
  for (final c in cases) {
    test('Move preserves geometry and exposes properties for ${c.$1}', () {
      final model = seeded(c.$2);
      addTearDown(model.dispose);
      final ids = ArchitectSelection.records(
        model.project.toJson(),
        's',
      ).map((e) => e['id'] as String).toSet();
      model.execute(
        MoveArchitectElements(
          storeyId: 's',
          elementIds: ids,
          delta: const Offset(1, .5),
        ),
      );
      for (final id in ids) {
        expect(ArchitectSelection.record(model.project, id)['id'], id);
        expect(
          ArchitectSelection.outline(model.project, id).getBounds().isFinite,
          isTrue,
        );
        ArchitectSelection.fields(model.project, id);
      }
      final moved = ArchitectSelection.bounds(model.project, ids.first)!;
      model.undo();
      final original = ArchitectSelection.bounds(model.project, ids.first)!;
      expect(
        (moved.center -
                original.center -
                (c.$1 == 'dimension'
                    ? const Offset(0, .5)
                    : const Offset(1, .5)))
            .distance,
        lessThan(1e-7),
      );
    });
    testWidgets(
      'Hold selects ${c.$1} and opens its properties without changing geometry',
      (tester) async {
        final model = seeded(c.$2);
        addTearDown(model.dispose);
        final old = model.project;
        await workspace.open(tester, model);
        await selectTool(tester, c.$1);
        await hold(tester, c.$3);
        expect(
          find.byKey(const ValueKey('architect-selection-properties')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('architect-selection-properties')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('architect-properties-save')),
          findsOneWidget,
        );
        expect(model.project, same(old));
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('Axis hold offers shared properties and group movement', (
    tester,
  ) async {
    final model = seeded(
      const ArchitectStorey(id: 's', name: 's'),
      axes: const [
        StructuralGridAxis(
          id: 'x',
          name: 'X',
          start: Offset(-2, 0),
          end: Offset(2, 0),
        ),
      ],
    );
    addTearDown(model.dispose);
    await workspace.open(tester, model);
    await selectTool(tester, 'axis');
    await hold(tester, Offset.zero);
    await tester.tap(
      find.byKey(const ValueKey('architect-selection-properties')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'A');
    await tester.tap(find.byKey(const ValueKey('architect-properties-save')));
    await tester.pumpAndSettle();
    expect(model.project.gridAxes.single.name, 'A');
    model.execute(
      const MoveArchitectElements(
        storeyId: 's',
        elementIds: {'x'},
        delta: Offset(1, 1),
      ),
    );
    expect(model.project.gridAxes.single.start, const Offset(-1, 1));
    expect(tester.takeException(), isNull);
  });
  test('Stored rotated dimension text avoids the complete wall network', () {
    final body = ArchitectWallNetwork.body([
      wall('a', const Offset(-4, 0), const Offset(4, 0), exterior: true),
      wall('b', const Offset(0, -4), const Offset(0, 4), exterior: true),
    ]);
    for (final n in [
      const Offset(1, 0),
      const Offset(0, 1),
      const Offset(.70710678, .70710678),
    ]) {
      final center = ArchitectDimensionLayout.clearTextPosition(
        Offset.zero,
        const Size(96, 35),
        100,
        n,
        body,
      );
      final rect = Rect.fromCenter(center: center, width: .96, height: .35);
      expect(
        Path.combine(
          PathOperation.intersect,
          body,
          Path()..addRect(rect),
        ).computeMetrics(),
        isEmpty,
      );
    }
  });
  testWidgets(
    'Multi select previews a group, cancels on pinch, moves once and Undoes',
    (tester) async {
      final model = seeded(
        ArchitectStorey(
          id: 's',
          name: 's',
          walls: [
            wall('a', const Offset(-2, 0), const Offset(2, 0)),
            wall('b', const Offset(2, 0), const Offset(2, 3)),
          ],
        ),
      );
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await selectTool(tester, 'wall');
      await hold(tester, Offset.zero);
      await tester.tap(find.byKey(const ValueKey('architect-multi-select')));
      await tester.pump();
      await hold(tester, const Offset(2, 2));
      expect(workspace.overlay(tester).selectedElementIds, {'a', 'b'});
      await tester.tap(find.byKey(const ValueKey('architect-selection-move')));
      await tester.pump();
      final old = model.project;
      final first = await tester.startGesture(
        workspace.screen(tester, Offset.zero),
        pointer: 81,
      );
      await tester.pump(const Duration(milliseconds: 451));
      await first.moveTo(workspace.screen(tester, const Offset(0, 1)));
      await tester.pump();
      expect(
        workspace.overlay(tester).project.activeStorey.walls.first.startPoint,
        const Offset(-2, 1),
      );
      final second = await tester.startGesture(
        workspace.screen(tester, const Offset(2, 2)),
        pointer: 82,
      );
      await second.up();
      await first.up();
      await tester.pump();
      expect(identical(model.project, old), isTrue);
      final move = await tester.startGesture(
        workspace.screen(tester, Offset.zero),
      );
      await tester.pump(const Duration(milliseconds: 281));
      await move.moveTo(workspace.screen(tester, const Offset(0, 1)));
      await move.up();
      await tester.pump();
      expect(
        model.project.activeStorey.walls[1].startPoint,
        const Offset(2, 1),
      );
      await tester.tap(find.byKey(const ValueKey('architect-undo')));
      await tester.pump();
      expect(identical(model.project, old), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Existing wall layers edit with local keypad and Extend picks another wall',
    (tester) async {
      final model = seeded(
        ArchitectStorey(
          id: 's',
          name: 's',
          walls: [
            wall('a', Offset.zero, const Offset(2, 0), exterior: true),
            wall('b', const Offset(3, 1), const Offset(3, 4)),
          ],
        ),
      );
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await selectTool(tester, 'wall');
      await hold(tester, const Offset(1, 0));
      await tester.tap(
        find.byKey(const ValueKey('architect-selection-properties')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('architect-property-coreThickness')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(EditableText), findsNothing);
      for (final key in ['0', '.', '3']) {
        await tester.tap(find.byKey(ValueKey('wall-key-$key')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const ValueKey('wall-end')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('architect-properties-save')));
      await tester.pumpAndSettle();
      expect(
        model.project.activeStorey.walls.first.coreThickness,
        closeTo(.3, 1e-9),
      );
      await tester.tap(find.byKey(const ValueKey('architect-wall-actions')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('wall-extend')));
      await tester.pumpAndSettle();
      await tester.tapAt(workspace.screen(tester, const Offset(3, 2)));
      await tester.pumpAndSettle();
      expect(
        model.project.activeStorey.walls.first.endPoint,
        const Offset(3, 0),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Phone selection and wall properties stay inside 360 by 800', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = seeded(
      ArchitectStorey(
        id: 's',
        name: 's',
        walls: [
          wall('a', const Offset(-1, 0), const Offset(1, 0), exterior: true),
        ],
      ),
    );
    addTearDown(model.dispose);
    const key = ValueKey('architect-edit-preview');
    if (const bool.fromEnvironment('UPDATE_ARCHITECT_EDIT_PREVIEW')) {
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
          home: ArchitectWorkspaceScreen(commandController: model),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await selectTool(tester, 'wall');
    await hold(tester, Offset.zero);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('architect-selection-bar')))
          .height,
      lessThanOrEqualTo(48),
    );
    if (const bool.fromEnvironment('UPDATE_ARCHITECT_EDIT_PREVIEW')) {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(key),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await File(
          'docs/images/architect_wall_actions_phone.png',
        ).writeAsBytes(bytes.buffer.asUint8List());
        image.dispose();
      });
    }
    for (final key in [
      'architect-wall-flip',
      'architect-wall-cut',
      'architect-wall-parallel',
    ]) {
      final button = find.byKey(ValueKey(key));
      final rect = tester.getRect(button);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(360));
      expect(
        find.descendant(
          of: find.byKey(ValueKey(key == 'architect-wall-parallel'
            ? 'architect-selection-bar' : 'architect-wall-floating-actions')),
          matching: button,
        ),
        findsOneWidget,
      );
    }
    for (final id in [
      'architect-multi-select',
      'architect-selection-properties',
      'architect-selection-move',
      'architect-clear-selection',
    ]) {
      final rect = tester.getRect(find.byKey(ValueKey(id)));
      expect(rect.right, lessThanOrEqualTo(360));
      expect(rect.bottom, lessThanOrEqualTo(800));
    }
    await tester.tap(
      find.byKey(const ValueKey('architect-selection-properties')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('UPDATE_ARCHITECT_EDIT_PREVIEW')) {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(key),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await File(
          'docs/images/architect_wall_properties_phone.png',
        ).writeAsBytes(bytes.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
