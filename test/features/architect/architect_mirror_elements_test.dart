import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_element_tool.dart';
import 'package:kotoview/src/features/bim_editing/geometry/bim_grid_axis.dart';
import 'package:kotoview/src/features/bim_projects/controllers/bim_viewport_controller.dart';
import 'package:kotoview/src/features/architect/widgets/architect_transform_point_input.dart';
import 'package:kotoview/src/features/bim_editing/widgets/bim_edit_actions.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_element_group_test.dart' as groups;
import 'architect_workspace_interaction_test.dart' as workspace;

ArchitectCommandController seededController({
  List<ArchitectWall> walls = const [],
  List<ArchitectColumn> columns = const [],
  List<ArchitectBeam> beams = const [],
  List<ArchitectSlab> slabs = const [],
  List<ArchitectRoofPlane> roofs = const [],
  List<ArchitectOpening> openings = const [],
  List<ArchitectDimension> dimensions = const [],
  List<BimGridAxis> gridAxes = const [],
}) {
  return ArchitectCommandController(
    ArchitectProject(
      id: 'p',
      name: 'Workspace',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      activeStoreyId: 's',
      gridAxes: gridAxes,
      storeys: [
        ArchitectStorey(
          id: 's',
          name: 'Floor',
          walls: walls,
          columns: columns,
          beams: beams,
          slabs: slabs,
          roofs: roofs,
          openings: openings,
          dimensions: dimensions,
        ),
      ],
    ),
  );
}

Future<void> openWorkspace(
  WidgetTester tester,
  ArchitectCommandController commands,
) async {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ArchitectWorkspaceScreen(commandController: commands),
    ),
  );
  await tester.pumpAndSettle();
}

Architect2dPainter overlay(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((e) => e.painter)
    .whereType<Architect2dPainter>()
    .firstWhere((e) => e.layer == ArchitectPaintLayer.interaction);

BimViewportController camera(WidgetTester tester) => overlay(tester).viewport!;

Offset screen(WidgetTester tester, Offset point) =>
    tester.getTopLeft(find.byKey(const ValueKey('architect-viewport-input'))) +
    camera(tester).toScreen(point);

void main() {
  test(
    'Oblique reflection around an external anchor preserves implicit hatch corners and holes',
    () {
      const hatch = ArchitectCadPrimitive(
        id: 'h',
        type: CadPrimitiveType.hatch,
        startPoint: Offset(2, 3),
        endPoint: Offset(6, 5),
        holes: [
          [Offset(3, 3.5), Offset(4, 3.5), Offset(4, 4), Offset(3, 4)],
        ],
      );
      final (result, _) = ArchitectElementTool().mirrorElementById(
        const ArchitectStorey(id: 's', name: '', cadPrimitives: [hatch]),
        'h',
        origin: const Offset(1, 1),
        direction: const Offset(2, 1),
      );
      final mirrored = result.cadPrimitives.single;
      final expected = [
        const Offset(4.8, -.6),
        const Offset(7.2, 2.6),
        const Offset(5.6, 3.8),
        const Offset(3.2, .6),
      ];
      expect(mirrored.polygon, hasLength(4));
      for (var i = 0; i < 4; i++) {
        expect((mirrored.polygon![i] - expected[i]).distance, lessThan(1e-8));
      }
      expect(
        (mirrored.holes.single.first - const Offset(4.2, 1.1)).distance,
        lessThan(1e-8),
      );
      expect(mirrored.hatchAngle, closeTo(53.130102354156, 1e-8));
    },
  );

  for (final copy in [false, true]) {
    testWidgets(
      'Arbitrary mirror anchor and second point snap, preview, ${copy ? 'copy' : 'move'} and undo',
      (tester) async {
        final model = editing.seeded(
          const ArchitectStorey(
            id: 's',
            name: '',
            cadPrimitives: [
              ArchitectCadPrimitive(
                id: 'selected',
                type: CadPrimitiveType.line,
                startPoint: Offset(2, 3),
                endPoint: Offset(6, 3),
              ),
              ArchitectCadPrimitive(
                id: 'guide',
                type: CadPrimitiveType.line,
                startPoint: Offset(1, 1),
                endPoint: Offset(3, 2),
              ),
            ],
          ),
        );
        addTearDown(model.dispose);
        await workspace.open(tester, model);
        workspace.camera(tester).fit(const Rect.fromLTRB(-4, -4, 10, 10));
        await tester.pumpAndSettle();
        final before = model.project.activeStorey.toJson();
        Future<void> start() async {
          await editing.contextHold(tester, const Offset(4, 3));
          await groups.action(
            tester,
            copy ? BimEditAction.mirrorCopy : BimEditAction.mirrorMove,
          );
        }

        await start();
        await tester.tapAt(workspace.screen(tester, const Offset(3, 2)));
        await tester.pump();
        await tester.tap(
          find.byKey(const ValueKey('architect-mirror-pick-anchor')),
        );
        await tester.pump();
        await tester.tapAt(workspace.screen(tester, const Offset(1.02, 1.01)));
        await tester.pump();
        final marker =
            tester
                    .widget<CustomPaint>(
                      find.byKey(const ValueKey('architect-transform-snap')),
                    )
                    .painter!
                as ArchitectTransformSnapPainter;
        expect(marker.result.isSnapped, isTrue);
        expect(marker.result.point, const Offset(1, 1));
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(
          location: workspace.screen(tester, const Offset(3.02, 2.01)),
        );
        await mouse.moveTo(workspace.screen(tester, const Offset(3.01, 2.02)));
        await tester.pump();
        final preview = workspace
            .overlay(tester)
            .project
            .activeStorey
            .cadPrimitives;
        final mirrored = copy ? preview.last : preview.first;
        expect(
          (mirrored.startPoint - const Offset(3.2, .6)).distance,
          lessThan(1e-8),
        );
        expect(
          (mirrored.endPoint - const Offset(5.6, 3.8)).distance,
          lessThan(1e-8),
        );
        final previewId = mirrored.id;
        expect(model.project.activeStorey.toJson(), before);
        await tester.tap(
          find.byKey(const ValueKey('architect-mirror-cancel-btn')),
        );
        await tester.pumpAndSettle();
        expect(workspace.overlay(tester).project.activeStorey.toJson(), before);
        await mouse.removePointer();
        await start();
        await tester.tapAt(workspace.screen(tester, const Offset(1, 1)));
        await tester.pump();
        await tester.tapAt(workspace.screen(tester, const Offset(3, 2)));
        await tester.pumpAndSettle();
        final committed = model.project.activeStorey.cadPrimitives;
        expect(committed, hasLength(copy ? 3 : 2));
        final finalMirror = copy ? committed.last : committed.first;
        expect(
          (finalMirror.startPoint - const Offset(3.2, .6)).distance,
          lessThan(1e-8),
        );
        if (!copy) expect(finalMirror.id, previewId);
        model.undo();
        await tester.pumpAndSettle();
        expect(model.project.activeStorey.toJson(), before);
        expect(tester.takeException(), isNull);
      },
    );
  }
  group('ArchitectElementTool - mirrorElementById', () {
    test('mirrors wall across vertical axis with door and inverted hinge', () {
      final wall = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(1, 1),
        endPoint: const Offset(1, 5),
        thickness: 0.25,
        exteriorSide: WallExteriorSide.left,
        arcBulge: 0.4,
        doors: [
          ArchitectDoor(
            id: 'd1',
            wallId: 'w1',
            uuid: 'u-d1',
            offsetRatio: 0.3,
            width: 0.9,
            height: 2.1,
            isHingeLeft: true,
          ),
        ],
        windows: [
          ArchitectWindow(
            id: 'win1',
            wallId: 'w1',
            uuid: 'u-win1',
            offsetRatio: 0.7,
            width: 1.2,
            height: 1.5,
            sillHeight: 0.9,
          ),
        ],
      );

      final storey = ArchitectStorey(id: 's', name: 'Floor', walls: [wall]);
      // Vertical mirror line: x = 0 (origin (0, 0), direction (0, 1))
      final (nextStorey, targetId) = ArchitectElementTool().mirrorElementById(
        storey,
        'w1',
        origin: const Offset(0, 0),
        direction: const Offset(0, 1),
        isDuplicate: false,
      );

      expect(targetId, 'w1');
      final mirrored = nextStorey.walls.firstWhere((w) => w.id == 'w1');
      // x was 1 -> becomes -1
      expect(mirrored.startPoint.dx, closeTo(-1, 0.001));
      expect(mirrored.startPoint.dy, closeTo(1, 0.001));
      expect(mirrored.endPoint.dx, closeTo(-1, 0.001));
      expect(mirrored.endPoint.dy, closeTo(5, 0.001));
      // Exterior side flips from left to right
      expect(mirrored.exteriorSide, WallExteriorSide.right);
      // Arc bulge negates
      expect(mirrored.arcBulge, closeTo(-0.4, 0.001));
      // Door hinge flips
      expect(mirrored.doors.length, 1);
      expect(mirrored.doors.first.isHingeLeft, false);
      expect(mirrored.doors.first.offsetRatio, closeTo(0.3, 0.001));
      // Window is kept
      expect(mirrored.windows.length, 1);
      expect(mirrored.windows.first.offsetRatio, closeTo(0.7, 0.001));
    });

    test('mirrors column position and reflects rotation angle', () {
      final col = ArchitectColumn(
        id: 'c1',
        position: const Offset(2, 3),
        width: 0.4,
        depth: 0.4,
        rotationDeg: 30.0,
      );
      final storey = ArchitectStorey(id: 's', name: 'Floor', columns: [col]);
      // Horizontal mirror line: y = 0 (origin (0, 0), direction (1, 0))
      final (nextStorey, targetId) = ArchitectElementTool().mirrorElementById(
        storey,
        'c1',
        origin: const Offset(0, 0),
        direction: const Offset(1, 0),
        isDuplicate: true,
      );

      expect(targetId, isNot('c1'));
      final mirrored = nextStorey.columns.firstWhere((c) => c.id == targetId);
      expect(mirrored.position.dx, closeTo(2, 0.001));
      expect(mirrored.position.dy, closeTo(-3, 0.001));
      // 30 deg mirrored over horizontal axis becomes -30 deg (or 330 deg)
      final normAngle = (mirrored.rotationDeg % 360 + 360) % 360;
      expect(normAngle, closeTo(330, 0.1));
    });

    test('mirrors beam start and end points', () {
      final beam = ArchitectBeam(
        id: 'b1',
        startPoint: const Offset(1, 2),
        endPoint: const Offset(5, 6),
        width: 0.25,
        depth: 0.5,
      );
      final storey = ArchitectStorey(id: 's', name: 'Floor', beams: [beam]);
      // Diagonal line y = x (origin (0,0), direction (1,1))
      final (nextStorey, targetId) = ArchitectElementTool().mirrorElementById(
        storey,
        'b1',
        origin: const Offset(0, 0),
        direction: const Offset(1, 1),
        isDuplicate: false,
      );

      expect(targetId, 'b1');
      final mirrored = nextStorey.beams.firstWhere((b) => b.id == 'b1');
      // Across y = x, (x, y) -> (y, x)
      expect(mirrored.startPoint.dx, closeTo(2, 0.001));
      expect(mirrored.startPoint.dy, closeTo(1, 0.001));
      expect(mirrored.endPoint.dx, closeTo(6, 0.001));
      expect(mirrored.endPoint.dy, closeTo(5, 0.001));
    });

    test('mirrors slab polygon and reverses vertex order', () {
      final slab = ArchitectSlab(
        id: 'sl1',
        polygon: const [Offset(0, 0), Offset(4, 0), Offset(4, 3), Offset(0, 3)],
        thickness: 0.2,
      );
      final storey = ArchitectStorey(id: 's', name: 'Floor', slabs: [slab]);
      // Mirror across x = 0 (vertical)
      final (nextStorey, targetId) = ArchitectElementTool().mirrorElementById(
        storey,
        'sl1',
        origin: const Offset(0, 0),
        direction: const Offset(0, 1),
        isDuplicate: true,
      );

      expect(targetId, isNot('sl1'));
      final mirrored = nextStorey.slabs.firstWhere((s) => s.id == targetId);
      expect(mirrored.polygon.length, 4);
      // Vertex order reversed to maintain polygon winding
      expect(mirrored.polygon[0].dx, closeTo(0, 0.001));
      expect(mirrored.polygon[0].dy, closeTo(3, 0.001));
      expect(mirrored.polygon[1].dx, closeTo(-4, 0.001));
      expect(mirrored.polygon[1].dy, closeTo(3, 0.001));
      expect(mirrored.polygon[2].dx, closeTo(-4, 0.001));
      expect(mirrored.polygon[2].dy, closeTo(0, 0.001));
      expect(mirrored.polygon[3].dx, closeTo(0, 0.001));
      expect(mirrored.polygon[3].dy, closeTo(0, 0.001));
    });

    test('mirrors roof contour and adjusts eavesEdgeIndex', () {
      final roof = ArchitectRoofPlane(
        id: 'r1',
        storeyId: 's',
        points: const [Offset(0, 0), Offset(6, 0), Offset(6, 4), Offset(0, 4)],
        eavesEdgeIndex: 0,
      );
      final storey = ArchitectStorey(id: 's', name: 'Floor', roofs: [roof]);
      // Mirror across vertical line x = 3 (origin (3, 0), direction (0, 1))
      final (nextStorey, targetId) = ArchitectElementTool().mirrorElementById(
        storey,
        'r1',
        origin: const Offset(3, 0),
        direction: const Offset(0, 1),
        isDuplicate: false,
      );

      expect(targetId, 'r1');
      final mirrored = nextStorey.roofs.firstWhere((r) => r.id == 'r1');
      expect(mirrored.points.length, 4);
      // eavesEdgeIndex recalculated for reversed polygon
      expect(mirrored.eavesEdgeIndex, 2);
    });
  });

  group('MirrorArchitectElements Command & Undo/Redo', () {
    test('mirrors wall with isDuplicate: true, then undoes and redoes', () {
      final wall = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(2, 0),
        endPoint: const Offset(2, 4),
        thickness: 0.25,
      );
      final controller = seededController(walls: [wall]);
      addTearDown(controller.dispose);

      final cmd = MirrorArchitectElements(
        storeyId: 's',
        elementIds: const {'w1'},
        origin: const Offset(0, 0),
        direction: const Offset(0, 1), // Vertical mirror at x = 0
        isDuplicate: true,
      );

      controller.execute(cmd);
      var currentWalls = controller.project.activeStorey.walls;
      expect(currentWalls.length, 2);
      final newWall = currentWalls.firstWhere((w) => w.id != 'w1');
      expect(newWall.startPoint.dx, closeTo(-2, 0.001));
      expect(newWall.endPoint.dx, closeTo(-2, 0.001));

      // Undo
      controller.undo();
      currentWalls = controller.project.activeStorey.walls;
      expect(currentWalls.length, 1);
      expect(currentWalls.first.id, 'w1');

      // Redo
      controller.redo();
      currentWalls = controller.project.activeStorey.walls;
      expect(currentWalls.length, 2);
    });

    test('mirrors wall with isDuplicate: false (move in-place)', () {
      final wall = ArchitectWall(
        id: 'w1',
        startPoint: const Offset(2, 0),
        endPoint: const Offset(2, 4),
        thickness: 0.25,
      );
      final controller = seededController(walls: [wall]);
      addTearDown(controller.dispose);

      final cmd = MirrorArchitectElements(
        storeyId: 's',
        elementIds: const {'w1'},
        origin: const Offset(0, 0),
        direction: const Offset(0, 1),
        isDuplicate: false,
      );

      controller.execute(cmd);
      var currentWalls = controller.project.activeStorey.walls;
      expect(currentWalls.length, 1);
      expect(currentWalls.first.id, 'w1');
      expect(currentWalls.first.startPoint.dx, closeTo(-2, 0.001));
      expect(currentWalls.first.endPoint.dx, closeTo(-2, 0.001));

      controller.undo();
      currentWalls = controller.project.activeStorey.walls;
      expect(currentWalls.first.startPoint.dx, closeTo(2, 0.001));
    });

    test('mirrors grid axis line and coordinates', () {
      final axis = BimGridAxis(
        id: 'ax1',
        name: '1',
        start: const Offset(2, -2),
        end: const Offset(2, 10),
      );
      final controller = seededController(gridAxes: [axis]);
      addTearDown(controller.dispose);

      final cmd = MirrorArchitectElements(
        storeyId: 's',
        elementIds: const {'ax1'},
        origin: const Offset(0, 0),
        direction: const Offset(0, 1), // x = 0
        isDuplicate: true,
      );

      controller.execute(cmd);
      expect(controller.project.gridAxes.length, 2);
      final newAxis = controller.project.gridAxes.firstWhere(
        (a) => a.id != 'ax1',
      );
      expect(newAxis.start.dx, closeTo(-2, 0.001));
      expect(newAxis.end.dx, closeTo(-2, 0.001));
    });
  });

  group('Interactive Mirror UI Workflow', () {
    testWidgets(
      'selection bar triggers mirror copy, anchor pick, vertical axis, and commit',
      (tester) async {
        final wall = ArchitectWall(
          id: 'w1',
          startPoint: const Offset(2, 1),
          endPoint: const Offset(2, 5),
          thickness: 0.25,
        );
        final controller = seededController(walls: [wall]);
        addTearDown(controller.dispose);
        await openWorkspace(tester, controller);

        // 1. Select the wall by tapping near (2, 3)
        await tester.tapAt(screen(tester, const Offset(2, 3)));
        await tester.pumpAndSettle();

        // Verify selection bar has mirror copy button
        final mirrorCopyBtn = find.byKey(
          const ValueKey('architect-selection-mirror-copy'),
        );
        expect(mirrorCopyBtn, findsOneWidget);

        // 2. Tap Mirror Copy button
        await tester.tap(mirrorCopyBtn);
        await tester.pumpAndSettle();

        // Banner should now be visible asking for anchor point
        final banner = find.byKey(const ValueKey('architect-mirror-banner'));
        expect(banner, findsOneWidget);
        expect(
          find.descendant(of: banner, matching: find.textContaining('anchor')),
          findsOneWidget,
        );

        // 3. Pick anchor at (0, 3) in open canvas space
        await tester.tapAt(screen(tester, const Offset(0, 3)));
        await tester.pumpAndSettle();

        // Banner now asks for axis or quick buttons (Vertical / Horizontal)
        expect(
          find.byKey(const ValueKey('architect-mirror-vertical-btn')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('architect-mirror-horizontal-btn')),
          findsOneWidget,
        );

        // 4. Tap Vertical axis quick button
        await tester.tap(
          find.byKey(const ValueKey('architect-mirror-vertical-btn')),
        );
        await tester.pumpAndSettle();

        // Banner dismissed, mirror committed
        expect(
          find.byKey(const ValueKey('architect-mirror-banner')),
          findsNothing,
        );

        // Verify that activeStorey now has 2 walls, one at x = 2, one at x = -2
        final walls = controller.project.activeStorey.walls;
        expect(walls.length, 2);
        final mirrored = walls.firstWhere((w) => w.id != 'w1');
        expect(mirrored.startPoint.dx, closeTo(-2, 0.01));
        expect(mirrored.endPoint.dx, closeTo(-2, 0.01));
      },
    );
  });
}
