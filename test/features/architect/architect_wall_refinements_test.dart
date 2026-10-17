import 'architect_tool_test_helper.dart' as tool_ui;
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_wall_type.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_hatch.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_layers.dart';
import 'package:kotoview/src/features/architect/services/architect_selection.dart';
import 'package:kotoview/src/features/architect/widgets/architect_workspace_view_bar.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_new_point_test.dart' as points;
import 'architect_workspace_interaction_test.dart' as workspace;

class HatchCanvas implements Canvas {
  double angle = 0;
  final stack = <double>[];
  final directions = <double>[];
  int dots = 0;
  @override
  void save() => stack.add(angle);
  @override
  void restore() => angle = stack.removeLast();
  @override
  void rotate(double value) => angle += value;
  @override
  void translate(double x, double y) {}
  @override
  void clipPath(Path path, {bool doAntiAlias = true}) {}
  @override
  Rect getLocalClipBounds() => const Rect.fromLTWH(-2, -1, 5, 2);
  @override
  void drawLine(Offset a, Offset b, Paint paint) =>
      directions.add(math.atan2((b - a).dy, (b - a).dx) + angle);
  @override
  void drawCircle(Offset center, double radius, Paint paint) => dots++;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  test('Every core pattern follows each wall at 45 degrees', () {
    final signatures = <(int, int)>{};
    for (final material in WallCoreMaterial.values) {
      for (final angle in [0.0, .31, math.pi / 2, 2.7]) {
        final wall = ArchitectWall(
          id: 'w',
          startPoint: Offset.zero,
          endPoint: Offset(4 * math.cos(angle), 4 * math.sin(angle)),
          coreMaterialOverride: material,
        );
        final canvas = HatchCanvas();
        ArchitectWallHatch.paint(
          canvas,
          wall,
          Path()..addRect(const Rect.fromLTWH(-2, -1, 5, 2)),
          80,
          Colors.grey,
        );
        expect(canvas.directions, isNotEmpty);
        for (final direction in canvas.directions) {
          expect((direction - angle).abs(), closeTo(math.pi / 4, 1e-9));
        }
        signatures.add((canvas.directions.length, canvas.dots));
      }
    }
    expect(signatures, hasLength(4));
  });

  test(
    'Junction hatch regions cover the core once, including angled and T joints',
    () {
      for (final angle in [math.pi / 4, math.pi / 2, math.pi * .75]) {
        final a = ArchitectWall(
          id: 'a',
          startPoint: const Offset(-3, 0),
          endPoint: Offset.zero,
          thickness: .37,
          wallTypeId: 'ext_25_12_eps',
        );
        final b = ArchitectWall(
          id: 'b',
          startPoint: Offset.zero,
          endPoint: Offset(3 * math.cos(angle), 3 * math.sin(angle)),
          thickness: .37,
          wallTypeId: 'ext_25_12_eps',
          coreMaterialOverride: WallCoreMaterial.timber,
        );
        for (final walls in [
          [a, b],
          [a.copyWith(endPoint: const Offset(3, 0)), b],
        ]) {
          final layers = ArchitectWallLayers.build(walls, []);
          final reversed = ArchitectWallLayers.build(
            walls.reversed.toList(),
            [],
          );
          for (var x = -.6; x < .6; x += .031) {
            for (var y = -.6; y < .6; y += .027) {
              final point = Offset(x + .00013, y + .00017);
              final owners = layers.coreRegions.values
                  .where((p) => p.contains(point))
                  .length;
              expect(owners, layers.core.contains(point) ? 1 : 0);
              for (final id in ['a', 'b']) {
                expect(
                  layers.coreRegions[id]!.contains(point),
                  reversed.coreRegions[id]!.contains(point),
                );
              }
            }
          }
          expect(
            ui.Path.combine(
              ui.PathOperation.difference,
              layers.core,
              layers.body,
            ).getBounds().isEmpty,
            isTrue,
          );
        }
      }
    },
  );

  test(
    'Following walls update with the storey, custom walls and parapets keep their heights',
    () {
      final storey = ArchitectStorey(
        id: 's',
        name: 'Floor',
        height: 3,
        walls: const [
          ArchitectWall(
            id: 'auto',
            startPoint: Offset.zero,
            endPoint: Offset(4, 0),
            height: 3,
          ),
          ArchitectWall(
            id: 'manual',
            startPoint: Offset(0, 2),
            endPoint: Offset(4, 2),
            height: 2.2,
            followStoreyHeight: false,
          ),
          ArchitectWall(
            id: 'parapet',
            startPoint: Offset(0, 4),
            endPoint: Offset(4, 4),
            height: 1.05,
            wallTypeId: 'parapet_12',
          ),
        ],
      );
      final next = storey.copyWith(height: 3.6);
      expect(next.walls.map((w) => w.height), [3.6, 2.2, 1.05]);
      final project = editing.seeded(next).project;
      final restored = ArchitectProject.fromJson(project.toJson());
      expect(
        restored.activeStorey.copyWith(height: 4).walls.map((w) => w.height),
        [4, 2.2, 1.05],
      );
      final mesh = Architect3dBuilder.buildProjectMesh(restored);
      expect(
        mesh.triangles.expand((t) => [t.v0.z, t.v1.z, t.v2.z]).reduce(math.max),
        closeTo(3.6, 1e-9),
      );
    },
  );

  test(
    'Material and height properties persist and Undo in one transaction',
    () {
      final model = editing.seeded(points.fixture('wall'));
      addTearDown(model.dispose);
      final original = model.project;
      model.execute(
        const SetArchitectElementProperties(
          storeyId: 's',
          elementIds: {'p'},
          values: {'height': 2.1},
          textValues: {
            'followStoreyHeight': 'false',
            'coreMaterial': 'panel',
            'insulationMaterial': 'stoneWool',
          },
        ),
      );
      var wall = model.project.activeStorey.walls.single;
      expect(wall.coreMaterial, WallCoreMaterial.panel);
      expect(wall.insulationMaterial, WallInsulationMaterial.stoneWool);
      expect(wall.followStoreyHeight, isFalse);
      expect(wall.height, 2.1);
      model.execute(
        const SetArchitectElementProperties(
          storeyId: 's',
          elementIds: {'p'},
          textValues: {'followStoreyHeight': 'true'},
        ),
      );
      expect(
        model.project.activeStorey.walls.single.height,
        model.project.activeStorey.height,
      );
      model.undo();
      model.undo();
      expect(model.project, same(original));
      expect(
        () => model.execute(
          const SetArchitectElementProperties(
            storeyId: 's',
            elementIds: {'p'},
            textValues: {'coreMaterial': 'unknown'},
          ),
        ),
        throwsArgumentError,
      );
      expect(model.project, same(original));
    },
  );

  for (final kind in ['wall', 'beam', 'line', 'rect', 'slab', 'opening']) {
    testWidgets(
      'Quick tap selects an existing $kind without starting a draft',
      (tester) async {
        final model = editing.seeded(points.fixture(kind));
        addTearDown(model.dispose);
        await workspace.open(tester, model);
        await editing.selectTool(
          tester,
          kind == 'line' || kind == 'rect' ? 'CAD' : kind,
        );
        if (kind == 'rect') {
          await tool_ui.choose(tester, Icons.crop_square_rounded);
          await tester.pumpAndSettle();
        }
        await workspace.wallTap(
          tester,
          ['rect', 'slab', 'opening'].contains(kind)
              ? const Offset(2, 2)
              : const Offset(2, 0),
        );
        await tester.pumpAndSettle();
        expect(workspace.overlay(tester).selectedElementId, 'p');
        expect(workspace.overlay(tester).activeDraftStart, isNull);
        expect(
          find.byKey(const ValueKey('architect-draft-cancel')),
          findsNothing,
        );
        expect(model.canUndo, isFalse);
      },
    );
  }

  for (final tool in ['wall', 'beam', 'CAD', 'axis', 'zone', 'slab']) {
    testWidgets(
      'Floating X cancels the first point for $tool after camera navigation',
      (tester) async {
        final model = workspace.commands();
        addTearDown(model.dispose);
        await workspace.open(tester, model);
        await editing.selectTool(tester, tool);
        await workspace.wallTap(tester, const Offset(1, 1));
        await tester.pumpAndSettle();
        final cancel = find.byKey(const ValueKey('architect-draft-cancel'));
        expect(cancel, findsOneWidget);
        workspace.camera(tester).panBy(const Offset(45, -20));
        await tester.pump();
        await tester.tap(cancel);
        await tester.pumpAndSettle();
        expect(cancel, findsNothing);
        expect(workspace.overlay(tester).activeDraftStart, isNull);
        expect(workspace.overlay(tester).zoneDraftingPoints, isEmpty);
        expect(workspace.overlay(tester).slabDraftPoints, isEmpty);
        expect(model.canUndo, isFalse);
      },
    );
  }

  testWidgets(
    'Parallel quick action constrains a body move even with snapping enabled',
    (tester) async {
      final wall = const ArchitectWall(
        id: 'w',
        startPoint: Offset.zero,
        endPoint: Offset(4, 3),
      );
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: 'Floor', walls: [wall]),
      );
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await editing.selectTool(tester, 'wall');
      await workspace.wallTap(tester, const Offset(1, .75));
      await tester.pumpAndSettle();
      for (final key in [
        'architect-wall-flip',
        'architect-wall-cut',
        'architect-wall-parallel',
      ]) {
        expect(find.byKey(ValueKey(key)), findsOneWidget);
      }
      final floating = find.byKey(
        const ValueKey('architect-wall-floating-actions'),
      );
      final selection = find.byKey(const ValueKey('architect-selection-bar'));
      expect(
        tester.getTopLeft(floating).dy,
        closeTo(
          tester.getBottomLeft(find.byType(ArchitectWorkspaceViewBar)).dy + 8,
          .1,
        ),
      );
      for (final key in [
        'architect-wall-flip',
        'architect-wall-cut',
        'architect-wall-parallel',
      ]) {
        final button = find.byKey(ValueKey(key));
        expect(find.descendant(of: floating, matching: button),
          key == 'architect-wall-parallel' ? findsNothing : findsOneWidget);
        expect(find.descendant(of: selection, matching: button),
          key == 'architect-wall-parallel' ? findsOneWidget : findsNothing);
      }
      await tester.tap(find.byKey(const ValueKey('architect-wall-parallel')));
      await tester.pump();
      final gesture = await tester.startGesture(
        workspace.screen(tester, const Offset(2, 1.5)),
      );
      await gesture.moveTo(workspace.screen(tester, const Offset(4, 3.5)));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      final moved = model.project.activeStorey.walls.single;
      final delta = moved.startPoint - wall.startPoint;
      expect(delta.distance, greaterThan(.01));
      expect(
        delta.dx * wall.unitVector.dx + delta.dy * wall.unitVector.dy,
        closeTo(0, 1e-9),
      );
      expect(moved.length, closeTo(wall.length, 1e-9));
      model.undo();
      expect(
        model.project.activeStorey.walls.single.startPoint,
        wall.startPoint,
      );
    },
  );

  testWidgets(
    'Wall properties expose default height follow, materials and leading line last',
    (tester) async {
      final model = editing.seeded(points.fixture('wall'));
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await editing.selectTool(tester, 'wall');
      await workspace.wallTap(tester, const Offset(1, 0));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('architect-selection-properties')),
      );
      await tester.pumpAndSettle();
      final follow = find.byKey(
        const ValueKey('architect-property-followStoreyHeight'),
      );
      expect(tester.widget<CheckboxListTile>(follow).value, isTrue);
      final height = find.byKey(const ValueKey('architect-property-height'));
      expect(tester.widget<ListTile>(height).onTap, isNull);
      await tester.tap(follow);
      await tester.pump();
      expect(tester.widget<ListTile>(height).onTap, isNotNull);
      final core = find.byKey(
        const ValueKey('architect-property-coreMaterial'),
      );
      await tester.tap(core);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Timber').last);
      await tester.pumpAndSettle();
      final insulation = find.byKey(
        const ValueKey('architect-property-insulationMaterial'),
      );
      await tester.ensureVisible(insulation);
      await tester.tap(insulation);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stone wool').last);
      await tester.pumpAndSettle();
      final reference = find.byKey(
        const ValueKey('architect-property-referenceLine'),
      );
      await tester.ensureVisible(reference);
      expect(find.text('Leading line'), findsOneWidget);
      expect(
        tester.getTopLeft(reference).dy,
        greaterThan(tester.getTopLeft(insulation).dy),
      );
      await tester.tap(find.byKey(const ValueKey('architect-properties-save')));
      await tester.pumpAndSettle();
      final wall = model.project.activeStorey.walls.single;
      expect(wall.followStoreyHeight, isFalse);
      expect(wall.coreMaterial, WallCoreMaterial.timber);
      expect(wall.insulationMaterial, WallInsulationMaterial.stoneWool);
      expect(tester.takeException(), isNull);
    },
  );
}
