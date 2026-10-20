import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_grid_axis.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/rendering/architect_dimension_layout.dart';
import 'package:kotoview/src/features/architect/services/architect_dimension_chain.dart';
import 'package:kotoview/src/features/architect/services/architect_element_tool.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_dimension_chain_test.dart' as dimensions;
import 'architect_workspace_interaction_test.dart' as workspace;

const facade = ArchitectWall(
  id: 'front',
  startPoint: Offset(0, 0),
  endPoint: Offset(10, 0),
  windows: [
    ArchitectWindow(
      id: 'win',
      wallId: 'front',
      offsetRatio: .2,
      width: 1.2,
      uuid: 'win',
    ),
  ],
  doors: [
    ArchitectDoor(
      id: 'door',
      wallId: 'front',
      offsetRatio: .7,
      width: 1,
      uuid: 'door',
    ),
  ],
);
const back = ArchitectWall(
  id: 'back',
  startPoint: Offset(0, -4),
  endPoint: Offset(10, -4),
  windows: [
    ArchitectWindow(
      id: 'back-win',
      wallId: 'back',
      offsetRatio: .5,
      width: 2,
      uuid: 'back-win',
    ),
  ],
);
const axes = [
  StructuralGridAxis(
    id: 'a',
    name: '1',
    start: Offset(.2, -8),
    end: Offset(.2, 4),
  ),
  StructuralGridAxis(
    id: 'b',
    name: '2',
    start: Offset(4, -8),
    end: Offset(4, 4),
  ),
  StructuralGridAxis(
    id: 'c',
    name: '3',
    start: Offset(9.8, -8),
    end: Offset(9.8, 4),
  ),
  StructuralGridAxis(
    id: 'outside',
    name: '4',
    start: Offset(12, -8),
    end: Offset(12, 4),
  ),
  StructuralGridAxis(
    id: 'parallel',
    name: 'A',
    start: Offset(0, 0),
    end: Offset(10, 0),
  ),
];
ArchitectDimension dimension() => ArchitectDimensionChain.build(
  id: 'dim',
  direction: const Offset(1, 0),
  offset: 2,
  anchors: const [
    ArchitectDimensionAnchor(point: Offset(0, 0)),
    ArchitectDimensionAnchor(point: Offset(4, 0)),
    ArchitectDimensionAnchor(point: Offset(10, 0)),
  ],
);
ArchitectStorey scene() => ArchitectStorey(
  id: 's',
  name: 'Floor',
  walls: const [facade, back],
  dimensions: [dimension()],
);
List<double> spans(DimensionTier tier) => [
  for (final s in tier.segments) (s.$2 - s.$1).distance,
];
void expectValues(Iterable<double> actual, List<double> expected) =>
    expect(actual, orderedEquals(expected.map((v) => closeTo(v, 1e-6))));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Facade centerline ends do not duplicate measured wall faces at junctions',
    () {
      final original = dimensions.scene();
      final storey = original.copyWith(
        walls: [
          ...original.walls,
          facade.copyWith(endPoint: const Offset(6, 0), windows: [], doors: []),
        ],
      );
      final dim = dimensions.chain(storey).copyWith(offsetDistance: -3);
      final rows = ArchitectDimensionLayout.layoutTiers(
        dimension: dim,
        scale: 100,
        storey: storey,
      );
      final structural = rows.firstWhere((t) => t.tierIndex == 2);
      expect(structural.points, hasLength(dim.dimensionPoints.length));
      expectValues(spans(structural), dimensions.lengths(dim));
    },
  );

  test(
    'Automatically dimensions facade openings, wall sections, overall and axes in order',
    () {
      final tiers = ArchitectDimensionLayout.layoutTiers(
        dimension: dimension(),
        scale: 100,
        storey: scene(),
        gridAxes: axes,
      );
      expect(tiers.map((t) => t.tierIndex), [1, 2, 3, 4]);
      expectValues(tiers[0].points.map((p) => p.dx), [
        0,
        1.4,
        2.6,
        6.5,
        7.5,
        10,
      ]);
      expectValues(spans(tiers[1]), [4, 6]);
      expectValues(spans(tiers[2]), [10]);
      expectValues(spans(tiers[3]), [3.8, 5.8]);
      expectValues(tiers.map((t) => t.line.$1.dy), [2, 2.45, 2.9, 3.35]);
      expect(dimension().anchors.any((a) => a.feature == 'opening'), isFalse);
    },
  );

  test(
    'Automatic openings follow facade side and exclude the opposite facade',
    () {
      final dim = dimension().copyWith(offsetDistance: -6);
      final tiers = ArchitectDimensionLayout.layoutTiers(
        dimension: dim,
        scale: 100,
        storey: scene(),
        gridAxes: axes,
      );
      expectValues(tiers.first.points.map((p) => p.dx), [0, 4, 6, 10]);
      expectValues(tiers.map((t) => t.line.$1.dy), [-6, -6.45, -6.9, -7.35]);
    },
  );

  test('Multiple stepped facade walls contribute their own openings', () {
    final first = facade.copyWith(
      endPoint: const Offset(4, 0),
      doors: [],
      windows: [
        const ArchitectWindow(
          id: 'first',
          wallId: 'front',
          offsetRatio: .5,
          width: 1,
          uuid: 'first',
        ),
      ],
    );
    final second = facade.copyWith(
      id: 'step',
      startPoint: const Offset(4, 1),
      endPoint: const Offset(10, 1),
      doors: [],
      windows: [
        const ArchitectWindow(
          id: 'second',
          wallId: 'step',
          offsetRatio: .5,
          width: 2,
          uuid: 'second',
        ),
      ],
    );
    final tiers = ArchitectDimensionLayout.layoutTiers(
      dimension: dimension(),
      scale: 100,
      storey: scene().copyWith(walls: [first, second, back]),
    );
    expectValues(tiers.first.points.map((p) => p.dx), [0, 1.5, 2.5, 6, 8, 10]);
    expectValues(spans(tiers[1]), [4, 6]);
  });

  test(
    'Empty rows are omitted; two endpoints still produce overall; Interior stays one row',
    () {
      final dim = ArchitectDimensionChain.build(
        id: 'd',
        direction: const Offset(1, 0),
        anchors: const [
          ArchitectDimensionAnchor(point: Offset(0, 0)),
          ArchitectDimensionAnchor(point: Offset(10, 0)),
        ],
      );
      List<DimensionTier> rows(
        ArchitectDimension d,
        List<StructuralGridAxis> grid,
      ) => ArchitectDimensionLayout.layoutTiers(
        dimension: d,
        scale: 100,
        gridAxes: grid,
      );
      expect(rows(dim, const []).map((t) => t.tierIndex), [2, 3]);
      expect(
        rows(dim.copyWith(showOverall: false), axes).map((t) => t.tierIndex),
        [2, 4],
      );
      expect(rows(dim, [axes.first]).map((t) => t.tierIndex), [2, 3]);
      final interior = ArchitectDimensionLayout.layoutTiers(
        dimension: dim.copyWith(style: ArchitectDimensionStyle.interior),
        scale: 100,
        storey: scene(),
        gridAxes: axes,
      );
      expect(interior, hasLength(1));
    },
  );

  test(
    'Four rows retain exact geometry at every zoom and rotated or reversed measurement',
    () {
      for (final angle in [0.0, math.pi / 2, .6]) {
        Offset rotate(Offset p) => Offset(
          p.dx * math.cos(angle) - p.dy * math.sin(angle),
          p.dx * math.sin(angle) + p.dy * math.cos(angle),
        );
        final walls = [
          for (final w in [facade, back])
            w.copyWith(
              startPoint: rotate(w.startPoint),
              endPoint: rotate(w.endPoint),
            ),
        ];
        final grid = [
          for (final a in axes)
            a.copyWith(start: rotate(a.start), end: rotate(a.end)),
        ];
        for (final reverse in [false, true]) {
          final dim = ArchitectDimensionChain.build(
            id: 'd',
            direction: rotate(Offset(reverse ? -1 : 1, 0)),
            offset: reverse ? -2 : 2,
            anchors: [
              for (final a in dimension().anchors) a.at(rotate(a.point)),
            ],
          );
          final tiers = ArchitectDimensionLayout.layoutTiers(
            dimension: dim,
            scale: 100,
            storey: scene().copyWith(walls: walls),
            gridAxes: grid,
          );
          expect(tiers, hasLength(4));
          expectValues(spans(tiers[2]), [10]);
          for (final zoom in [10.0, 50.0, 300.0]) {
            final zoomed = ArchitectDimensionLayout.layoutTiers(
              dimension: dim,
              scale: zoom,
              storey: scene().copyWith(walls: walls),
              gridAxes: grid,
            );
            expect(zoomed.map((t) => t.line), tiers.map((t) => t.line));
          }
        }
      }
    },
  );

  test('Opening and axis edits regenerate rows after save, undo and redo', () {
    final model = editing.seeded(scene());
    addTearDown(model.dispose);
    model.execute(
      UpdateArchitectWall(
        storeyId: 's',
        wall: facade.copyWith(
          windows: [facade.windows.single.copyWith(offsetRatio: .3, width: 2)],
        ),
      ),
    );
    List<DimensionTier> rows(ArchitectProject p) =>
        ArchitectDimensionLayout.layoutTiers(
          dimension: p.activeStorey.dimensions.single,
          scale: 100,
          storey: p.activeStorey,
          gridAxes: p.gridAxes,
        );
    expectValues(rows(model.project).first.points.map((p) => p.dx), [
      0,
      2,
      4,
      6.5,
      7.5,
      10,
    ]);
    model.undo();
    expectValues(rows(model.project).first.points.map((p) => p.dx), [
      0,
      1.4,
      2.6,
      6.5,
      7.5,
      10,
    ]);
    model.redo();
    final saved = ArchitectProject.fromJson(
      jsonDecode(jsonEncode(model.project.copyWith(gridAxes: axes).toJson())),
    );
    expect(rows(saved).map((t) => t.tierIndex), [1, 2, 3, 4]);
    expectValues(rows(saved).first.points.map((p) => p.dx), [
      0,
      2,
      4,
      6.5,
      7.5,
      10,
    ]);
    final moved = saved.copyWith(
      gridAxes: [
        axes.first,
        axes[1].copyWith(start: const Offset(5, -8), end: const Offset(5, 4)),
        axes[2],
      ],
    );
    expectValues(spans(rows(moved).last), [4.8, 4.8]);
  });

  testWidgets(
    'The outer axis row selects and drags its dimension with Dimension active',
    (tester) async {
      final seed = editing.seeded(scene());
      final model = ArchitectCommandController(
        seed.project.copyWith(gridAxes: axes),
      );
      seed.dispose();
      addTearDown(model.dispose);
      await dimensions.startChain(tester, model);
      final rows = ArchitectDimensionLayout.layoutTiers(
        dimension: dimension(),
        scale: workspace.camera(tester).scale,
        storey: scene(),
        gridAxes: axes,
      );
      final pick = (rows.last.line.$1 + rows.last.line.$2) / 2;
      final tool = ArchitectElementTool();
      addTearDown(tool.dispose);
      expect(
        tool.hitTestForTool(
          scene(),
          pick,
          100,
          ArchitectTool.dimension,
          gridAxes: axes,
        ),
        'dim',
      );
      await tester.longPressAt(workspace.screen(tester, pick));
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).selectedElementIds, {'dim'});
      final drag = await tester.startGesture(workspace.screen(tester, pick));
      await drag.moveTo(workspace.screen(tester, pick + const Offset(0, .7)));
      await drag.up();
      await tester.pump();
      expect(
        model.project.activeStorey.dimensions.single.offsetDistance,
        closeTo(2.7, .03),
      );
      expect(model.undoCount, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
