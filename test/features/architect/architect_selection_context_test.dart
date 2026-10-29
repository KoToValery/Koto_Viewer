import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_grid_axis.dart';
import 'package:kotoview/src/features/architect/models/architect_zone.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/widgets/architect_tool_palette.dart';
import 'package:kotoview/src/features/architect/widgets/architect_wall_drafting_panel.dart';
import 'package:kotoview/src/features/architect/widgets/architect_radial_menu.dart';
import 'architect_manual_selection_test.dart' as selection;
import 'architect_workspace_interaction_test.dart' as workspace;

const polygon = [Offset(-1, -1), Offset(1, -1), Offset(1, 1), Offset(-1, 1)];
ArchitectProject project(ArchitectStorey storey, {bool axes = false}) =>
    ArchitectProject(
      id: 'context',
      name: 'Selection',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      activeStoreyId: storey.id,
      storeys: [storey],
      gridAxes: axes
          ? const [
              StructuralGridAxis(
                id: 'axis',
                name: 'A',
                start: Offset(-3, 0),
                end: Offset(3, 0),
              ),
            ]
          : const [],
    );
ArchitectToolPalette palette(WidgetTester tester) =>
    tester.widget(find.byType(ArchitectToolPalette));
Future<void> open(WidgetTester tester, ArchitectCommandController c) async {
  await workspace.open(tester, c);
  workspace
      .camera(tester)
      .fit(const Rect.fromLTWH(-5, -4, 10, 8), padding: 160);
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, Offset point) async {
  await tester.tapAt(workspace.screen(tester, point));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final cases = <(ArchitectTool, ArchitectStorey, Offset, String)>[
    (
      ArchitectTool.wall,
      const ArchitectStorey(
        id: 's',
        name: 'Floor',
        walls: [
          ArchitectWall(
            id: 'wall',
            startPoint: Offset(-3, 0),
            endPoint: Offset(3, 0),
          ),
        ],
      ),
      Offset.zero,
      'wall',
    ),
    (
      ArchitectTool.door,
      const ArchitectStorey(
        id: 's',
        name: 'Floor',
        walls: [
          ArchitectWall(
            id: 'host',
            startPoint: Offset(-3, 0),
            endPoint: Offset(3, 0),
            doors: [
              ArchitectDoor(
                id: 'door',
                wallId: 'host',
                offsetRatio: .5,
                uuid: 'door',
              ),
            ],
          ),
        ],
      ),
      Offset.zero,
      'door',
    ),
    (
      ArchitectTool.window,
      const ArchitectStorey(
        id: 's',
        name: 'Floor',
        walls: [
          ArchitectWall(
            id: 'host',
            startPoint: Offset(-3, 0),
            endPoint: Offset(3, 0),
            windows: [
              ArchitectWindow(
                id: 'window',
                wallId: 'host',
                offsetRatio: .5,
                uuid: 'window',
              ),
            ],
          ),
        ],
      ),
      Offset.zero,
      'window',
    ),
    (
      ArchitectTool.column,
      const ArchitectStorey(
        id: 's',
        name: 'Floor',
        columns: [ArchitectColumn(id: 'column', position: Offset.zero)],
      ),
      Offset.zero,
      'column',
    ),
    (
      ArchitectTool.beam,
      const ArchitectStorey(
        id: 's',
        name: 'Floor',
        beams: [
          ArchitectBeam(
            id: 'beam',
            startPoint: Offset(-2, 0),
            endPoint: Offset(2, 0),
          ),
        ],
      ),
      Offset.zero,
      'beam',
    ),
    (
      ArchitectTool.slab,
      const ArchitectStorey(
        id: 's',
        name: 'Floor',
        slabs: [ArchitectSlab(id: 'slab', polygon: polygon)],
      ),
      Offset.zero,
      'slab',
    ),
    (
      ArchitectTool.roof,
      ArchitectStorey(
        id: 's',
        name: 'Floor',
        roofs: [ArchitectRoofPlane(id: 'roof', storeyId: 's', points: polygon)],
      ),
      Offset.zero,
      'roof',
    ),
    (
      ArchitectTool.opening,
      const ArchitectStorey(
        id: 's',
        name: 'Floor',
        openings: [ArchitectOpening(id: 'opening', boundary: polygon)],
      ),
      Offset.zero,
      'opening',
    ),
    (
      ArchitectTool.stair,
      const ArchitectStorey(
        id: 's',
        name: 'Floor',
        stairs: [
          ArchitectStair(
            id: 'stair',
            startPoint: Offset(-2, 0),
            endPoint: Offset(2, 0),
          ),
        ],
      ),
      Offset.zero,
      'stair',
    ),
    (
      ArchitectTool.zone,
      const ArchitectStorey(
        id: 's',
        name: 'Floor',
        zones: [
          ArchitectZone(
            id: 'zone',
            name: 'Room',
            category: ArchitectZoneCategory.living,
            polygon: polygon,
          ),
        ],
      ),
      Offset.zero,
      'zone',
    ),
    (
      ArchitectTool.axis,
      const ArchitectStorey(id: 's', name: 'Floor'),
      Offset.zero,
      'axis',
    ),
    (
      ArchitectTool.dimension,
      const ArchitectStorey(
        id: 's',
        name: 'Floor',
        dimensions: [
          ArchitectDimension(
            id: 'dimension',
            startPoint: Offset(-2, 0),
            endPoint: Offset(2, 0),
          ),
        ],
      ),
      const Offset(0, .5),
      'dimension',
    ),
    (
      ArchitectTool.level,
      const ArchitectStorey(
        id: 's',
        name: 'Floor',
        elevationMarkers: [
          ArchitectElevationMarker(
            id: 'level',
            position: Offset.zero,
            elevation: 0,
          ),
        ],
      ),
      Offset.zero,
      'level',
    ),
    (
      ArchitectTool.text,
      const ArchitectStorey(
        id: 's',
        name: 'Floor',
        annotations: [
          ArchitectAnnotation(id: 'text', position: Offset.zero, text: 'Text'),
        ],
      ),
      Offset.zero,
      'text',
    ),
    (
      ArchitectTool.cadLine,
      const ArchitectStorey(
        id: 's',
        name: 'Floor',
        cadPrimitives: [
          ArchitectCadPrimitive(
            id: 'line',
            type: CadPrimitiveType.line,
            startPoint: Offset(-2, 0),
            endPoint: Offset(2, 0),
          ),
        ],
      ),
      Offset.zero,
      'line',
    ),
    (
      ArchitectTool.cadRect,
      const ArchitectStorey(
        id: 's',
        name: 'Floor',
        cadPrimitives: [
          ArchitectCadPrimitive(
            id: 'rect',
            type: CadPrimitiveType.rect,
            startPoint: Offset(-1, -1),
            endPoint: Offset(1, 1),
          ),
        ],
      ),
      const Offset(0, -1),
      'rect',
    ),
    (
      ArchitectTool.cadCircle,
      const ArchitectStorey(
        id: 's',
        name: 'Floor',
        cadPrimitives: [
          ArchitectCadPrimitive(
            id: 'circle',
            type: CadPrimitiveType.circle,
            startPoint: Offset.zero,
            endPoint: Offset(1, 0),
          ),
        ],
      ),
      const Offset(1, 0),
      'circle',
    ),
    (
      ArchitectTool.component,
      const ArchitectStorey(
        id: 's',
        name: 'Floor',
        components: [
          ArchitectComponentInstance(
            id: 'component',
            definitionId: 'fixture',
            position: Offset.zero,
          ),
        ],
      ),
      const Offset(0, .3),
      'component',
    ),
  ];
  for (final (tool, storey, point, id) in cases) {
    testWidgets(
      'General selection activates $tool and empty space exits without drawing',
      (tester) async {
        final c = ArchitectCommandController(
          project(storey, axes: tool == ArchitectTool.axis),
        );
        addTearDown(c.dispose);
        final original = c.project;
        await open(tester, c);
        expect(palette(tester).activeTool, ArchitectTool.pan);
        await tap(tester, point);
        expect(palette(tester).activeTool, tool);
        expect(workspace.overlay(tester).selectedElementIds, {id});
        expect(c.project, same(original));
        expect(c.canUndo, isFalse);
        await tester.tap(find.byKey(const ValueKey('architect-tool-pan')));
        await tester.pumpAndSettle();
        expect(palette(tester).activeTool, ArchitectTool.pan);
        expect(workspace.overlay(tester).selectedElementIds, isEmpty);
        await tap(tester, point);
        expect(palette(tester).activeTool, tool);
        await tap(tester, const Offset(3, 2));
        expect(palette(tester).activeTool, ArchitectTool.pan);
        expect(workspace.overlay(tester).selectedElementIds, isEmpty);
        await tap(tester, const Offset(3, 2));
        expect(c.project, same(original));
        expect(c.canUndo, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }
  const mixed = ArchitectStorey(
    id: 's',
    name: 'Floor',
    walls: [
      ArchitectWall(
        id: 'wall',
        startPoint: Offset(-3, 0),
        endPoint: Offset(3, 0),
      ),
    ],
    columns: [ArchitectColumn(id: 'column', position: Offset(0, 2))],
  );
  for (final tool in [ArchitectTool.door, ArchitectTool.window]) {
    testWidgets('Automatically selected $tool retains its context menu', (
      tester,
    ) async {
      final fixture = cases.firstWhere((entry) => entry.$1 == tool);
      final c = ArchitectCommandController(project(fixture.$2));
      addTearDown(c.dispose);
      await open(tester, c);
      await tap(tester, fixture.$3);
      expect(palette(tester).activeTool, tool);
      await selection.holdMenu(tester, fixture.$3);
      expect(find.byType(ArchitectRadialMenu), findsOneWidget);
      expect(c.canUndo, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Choosing a tool exits explicit multi-selection', (tester) async {
    final c = ArchitectCommandController(project(mixed));
    addTearDown(c.dispose);
    await open(tester, c);
    await tap(tester, const Offset(1, 0));
    await tester.tap(find.byKey(const ValueKey('architect-multi-select')));
    await tester.pumpAndSettle();
    expect(palette(tester).multiSelect, isTrue);
    palette(tester).onToolChanged(ArchitectTool.wall);
    await tester.pumpAndSettle();
    expect(palette(tester).activeTool, ArchitectTool.wall);
    expect(palette(tester).multiSelect, isFalse);
    expect(workspace.overlay(tester).selectedElementIds, isEmpty);
    expect(c.canUndo, isFalse);
  });
  testWidgets(
    'single selection replaces unlike elements and active tool toggles back to general',
    (tester) async {
      final c = ArchitectCommandController(project(mixed));
      addTearDown(c.dispose);
      await open(tester, c);
      await tap(tester, const Offset(1, 0));
      expect(palette(tester).activeTool, ArchitectTool.wall);
      await tap(tester, const Offset(0, 2));
      expect(palette(tester).activeTool, ArchitectTool.column);
      expect(workspace.overlay(tester).selectedElementIds, {'column'});
      final button = find.byKey(const ValueKey('architect-tool-pan'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(palette(tester).activeTool, ArchitectTool.pan);
      expect(workspace.overlay(tester).selectedElementIds, isEmpty);
      expect(c.canUndo, isFalse);
    },
  );
  testWidgets(
    'mixed selection requires its explicit button and leaving clears selection',
    (tester) async {
      final c = ArchitectCommandController(project(mixed));
      addTearDown(c.dispose);
      await open(tester, c);
      final button = find.byKey(const ValueKey('architect-multi-select'));
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(palette(tester).multiSelect, isTrue);
      await tap(tester, const Offset(1, 0));
      await tap(tester, const Offset(0, 2));
      expect(palette(tester).activeTool, ArchitectTool.select);
      expect(workspace.overlay(tester).selectedElementIds, {'wall', 'column'});
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(palette(tester).multiSelect, isFalse);
      expect(palette(tester).activeTool, ArchitectTool.pan);
      expect(workspace.overlay(tester).selectedElementIds, isEmpty);
      expect(c.canUndo, isFalse);
    },
  );
  testWidgets(
    'a held empty point after automatic selection never resumes placement',
    (tester) async {
      final c = ArchitectCommandController(project(mixed));
      addTearDown(c.dispose);
      await open(tester, c);
      await tap(tester, const Offset(1, 0));
      final original = c.project;
      final g = await tester.startGesture(
        workspace.screen(tester, const Offset(3, 2)),
        kind: PointerDeviceKind.touch,
      );
      await tester.pump(const Duration(milliseconds: 800));
      await g.up();
      await tester.pumpAndSettle();
      expect(c.project, same(original));
      expect(workspace.overlay(tester).activeDraftStart, isNull);
      expect(c.canUndo, isFalse);
    },
  );
  testWidgets(
    'default-selected wall accepts a numeric clearance edit and Undo restores it',
    (tester) async {
      final c = ArchitectCommandController(
        project(
          const ArchitectStorey(
            id: 's',
            name: 'Floor',
            walls: [
              ArchitectWall(
                id: 'wall',
                startPoint: Offset(-3, 0),
                endPoint: Offset(3, 0),
              ),
              ArchitectWall(
                id: 'neighbor',
                startPoint: Offset(-3, 3),
                endPoint: Offset(3, 3),
              ),
            ],
          ),
        ),
      );
      addTearDown(c.dispose);
      await open(tester, c);
      await tap(tester, const Offset(1, 0));
      final original = c.project;
      final badge = find.byKey(const ValueKey('wall-clearance-neighbor'));
      expect(badge, findsOneWidget);
      await tester.tap(badge);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      final panel = tester.widget<BimDistanceDraftingPanel>(
        find.byType(BimDistanceDraftingPanel),
      );
      panel.onLength(1.5);
      await tester.tap(find.byKey(const ValueKey('wall-end')));
      await tester.pumpAndSettle();
      expect(c.undoCount, 1);
      expect(
        c.project.activeStorey.walls.first.startPoint.dy.abs(),
        greaterThan(.5),
      );
      expect(
        c.project.activeStorey.walls.last,
        same(original.activeStorey.walls.last),
      );
      c.undo();
      await tester.pumpAndSettle();
      expect(c.project, same(original));
      expect(tester.takeException(), isNull);
    },
  );
}
