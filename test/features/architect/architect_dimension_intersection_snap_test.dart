import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_grid_axis.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/rendering/architect_snap_helper.dart';
import 'package:kotoview/src/features/architect/services/architect_dimension_chain.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'architect_dimension_chain_test.dart' as dimensions;
import 'architect_editing_test.dart' as editing;
import 'architect_tool_test_helper.dart' as tool_ui;
import 'architect_workspace_interaction_test.dart' as workspace;

typedef Scene = ({
  String name,
  ArchitectStorey storey,
  List<StructuralGridAxis> axes,
  Offset target,
});
const horizontal = ArchitectCadPrimitive(
  id: 'horizontal',
  type: CadPrimitiveType.line,
  startPoint: Offset(0, 1.2),
  endPoint: Offset(8, 1.2),
);
const vertical = ArchitectCadPrimitive(
  id: 'vertical',
  type: CadPrimitiveType.line,
  startPoint: Offset(2, -1),
  endPoint: Offset(2, 4),
);

List<Scene> scenes() => [
  (
    name: 'CAD crossing beside an endpoint',
    target: const Offset(2, 1.2),
    axes: const [],
    storey: const ArchitectStorey(
      id: 's',
      name: 'Floor',
      cadPrimitives: [
        horizontal,
        vertical,
        ArchitectCadPrimitive(
          id: 'near-endpoint',
          type: CadPrimitiveType.line,
          startPoint: Offset(2.04, 1.21),
          endPoint: Offset(2.35, 1.21),
        ),
      ],
    ),
  ),
  (
    name: 'wall face junction',
    target: const Offset(.15, .15),
    axes: const [],
    storey: const ArchitectStorey(
      id: 's',
      name: 'Floor',
      walls: [
        ArchitectWall(
          id: 'h',
          startPoint: Offset(-2, 0),
          endPoint: Offset(5, 0),
          thickness: .3,
        ),
        ArchitectWall(
          id: 'v',
          startPoint: Offset(0, -2),
          endPoint: Offset(0, 3),
          thickness: .3,
        ),
      ],
    ),
  ),
  (
    name: 'opening jamb and wall face',
    target: const Offset(1.4, .15),
    axes: const [],
    storey: const ArchitectStorey(
      id: 's',
      name: 'Floor',
      walls: [
        ArchitectWall(
          id: 'host',
          startPoint: Offset(0, 0),
          endPoint: Offset(8, 0),
          thickness: .3,
          windows: [
            ArchitectWindow(
              id: 'window',
              wallId: 'host',
              offsetRatio: .25,
              width: 1.2,
              uuid: 'window',
            ),
          ],
        ),
      ],
    ),
  ),
  (
    name: 'slab edge and CAD line',
    target: const Offset(2, 1.3),
    axes: const [],
    storey: const ArchitectStorey(
      id: 's',
      name: 'Floor',
      cadPrimitives: [vertical],
      slabs: [
        ArchitectSlab(
          id: 'slab',
          polygon: [
            Offset(0, 1.3),
            Offset(6, 1.3),
            Offset(6, 3.7),
            Offset(0, 3.7),
          ],
        ),
      ],
    ),
  ),
  (
    name: 'infinite grid axis and finite CAD line',
    target: const Offset(2, 1.2),
    axes: const [
      StructuralGridAxis(
        id: 'axis',
        name: '1',
        start: Offset(2, -5),
        end: Offset(2, -4),
      ),
    ],
    storey: const ArchitectStorey(
      id: 's',
      name: 'Floor',
      cadPrimitives: [horizontal],
    ),
  ),
  (
    name: 'circle and line tangent',
    target: const Offset(2, 2),
    axes: const [],
    storey: const ArchitectStorey(
      id: 's',
      name: 'Floor',
      cadPrimitives: [
        ArchitectCadPrimitive(
          id: 'circle',
          type: CadPrimitiveType.circle,
          startPoint: Offset(2, 1),
          endPoint: Offset(3, 1),
        ),
        ArchitectCadPrimitive(
          id: 'tangent',
          type: CadPrimitiveType.line,
          startPoint: Offset(0, 2),
          endPoint: Offset(8, 2),
        ),
      ],
    ),
  ),
];

ArchitectProject project(Scene scene) => ArchitectProject(
  id: 'p',
  name: 'Project',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  activeStoreyId: 's',
  storeys: [scene.storey],
  gridAxes: scene.axes,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'New point favors an intersection; ordinary tools retain endpoint priority',
    () {
      final scene = scenes().first;
      final raw = scene.target + const Offset(.008, .006);
      final normal = ArchitectSnapHelper.snapFree(
        rawPoint: raw,
        project: project(scene),
        tolerance: .1,
      );
      expect(normal.snapLabel, 'Endpoint');
      final point = ArchitectSnapHelper.snapFree(
        rawPoint: raw,
        project: project(scene),
        tolerance: .1,
        preferIntersections: true,
      );
      expect(point.snapLabel, 'Intersection');
      expect((point.point - scene.target).distance, lessThan(1e-9));
    },
  );

  for (final scene in scenes()) {
    test('Intersection snap supports ${scene.name}', () {
      final point = ArchitectSnapHelper.snapFree(
        rawPoint: scene.target + const Offset(.008, .006),
        project: project(scene),
        tolerance: .1,
        preferIntersections: true,
        excludeWallAxes: true,
      );
      expect(point.snapLabel, anyOf('Intersection', 'Axis intersection'));
      expect((point.point - scene.target).distance, lessThan(1e-9));
    });

    for (final style in [
      ArchitectDimensionStyle.exterior,
      ArchitectDimensionStyle.interior,
    ]) {
      testWidgets('$style New point keeps exactly one point at ${scene.name}', (
        tester,
      ) async {
        final original = ArchitectDimensionChain.build(
          id: 'dim',
          style: style,
          direction: const Offset(1, 0),
          offset: 4.5,
          anchors: const [
            ArchitectDimensionAnchor(point: Offset(-3, 0)),
            ArchitectDimensionAnchor(point: Offset(8, 0)),
          ],
        );
        final model = editing.seeded(
          scene.storey.copyWith(dimensions: [original]),
        );
        addTearDown(model.dispose);
        model.replaceView(model.project.copyWith(gridAxes: scene.axes));
        await workspace.open(tester, model);
        await tool_ui.choose(tester, Icons.pan_tool_rounded);
        await tester.pumpAndSettle();
        await workspace.wallTap(
          tester,
          (original.lineStart + original.lineEnd) / 2,
        );
        expect(workspace.overlay(tester).selectedElementIds, {'dim'});
        await tester.tap(
          find.byKey(const ValueKey('architect-dimension-new-point')),
        );
        await tester.pumpAndSettle();
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        final raw = scene.target + const Offset(.008, .006);
        await mouse.addPointer(
          location: workspace.screen(tester, raw + const Offset(.3, .3)),
        );
        await mouse.moveTo(workspace.screen(tester, raw));
        await tester.pump();
        expect(
          workspace.overlay(tester).activeSnapLabel,
          anyOf('Intersection', 'Axis intersection'),
        );
        expect(
          (workspace.overlay(tester).cursorPosition! - scene.target).distance,
          lessThan(1e-9),
        );
        await workspace.wallTap(tester, raw);
        await mouse.removePointer();
        final draft = dimensions.preview(tester)!;
        expect(draft.anchors, hasLength(3));
        expect(
          draft.anchors.where((a) => (a.point - scene.target).distance < 1e-9),
          hasLength(1),
        );
        await tester.tap(
          find.byKey(const ValueKey('architect-dimension-confirm')),
        );
        await tester.pumpAndSettle();
        final saved = model.project.activeStorey.dimensions.single;
        expect(saved.anchors, hasLength(3));
        expect(
          saved.anchors.where((a) => (a.point - scene.target).distance < 1e-9),
          hasLength(1),
        );
        expect(saved.lineStart.dy, closeTo(original.lineStart.dy, 1e-9));
        expect(model.undoCount, 1);
        final loaded = ArchitectProject.fromJson(model.project.toJson());
        expect(
          ArchitectDimensionChain.resolve(
            loaded,
          ).activeStorey.dimensions.single.anchors.map((a) => a.point),
          saved.anchors.map((a) => a.point),
        );
        model.undo();
        expect(
          model.project.activeStorey.dimensions.single.anchors,
          hasLength(2),
        );
        model.redo();
        expect(
          model.project.activeStorey.dimensions.single.anchors,
          hasLength(3),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  test('Finite line extensions do not create imaginary intersections', () {
    const scene = (
      name: 'separated',
      target: Offset(2, 1.2),
      axes: <StructuralGridAxis>[],
      storey: ArchitectStorey(
        id: 's',
        name: 'Floor',
        cadPrimitives: [
          horizontal,
          ArchitectCadPrimitive(
            id: 'short',
            type: CadPrimitiveType.line,
            startPoint: Offset(2, 1.25),
            endPoint: Offset(2, 3),
          ),
        ],
      ),
    );
    final snap = ArchitectSnapHelper.snapFree(
      rawPoint: scene.target,
      project: project(scene),
      tolerance: .1,
      preferIntersections: true,
    );
    expect(snap.snapLabel, isNot('Intersection'));
  });

  test('Underlay intersections honor layer visibility and magnetic toggle', () {
    final scene = scenes().last;
    final empty = project(
      scene,
    ).updateActiveStorey(const ArchitectStorey(id: 's', name: 'Floor'));
    final underlay = DxfDocument(
      entities: [
        DxfLine(layer: 'h', p1: const Offset(0, 1), p2: const Offset(4, 1)),
        DxfLine(layer: 'v', p1: const Offset(2, 0), p2: const Offset(2, 3)),
      ],
      layers: {},
      blocks: {},
      bounds: const Rect.fromLTWH(0, 0, 4, 3),
      entityStats: {},
      headerVars: {},
    );
    ArchitectSnapResult snap({
      Map<String, bool> visibility = const {},
      bool magnetic = true,
    }) => ArchitectSnapHelper.snapFree(
      rawPoint: const Offset(2.01, 1.01),
      project: empty,
      tolerance: .1,
      preferIntersections: true,
      underlay: underlay,
      visibility: visibility,
      magnetic: magnetic,
    );
    expect(snap().snapLabel, 'Intersection');
    expect((snap().point - const Offset(2, 1)).distance, lessThan(1e-9));
    expect(snap(visibility: {'v': false}).snapLabel, isNot('Intersection'));
    expect(snap(magnetic: false).isSnapped, isFalse);
  });
}
