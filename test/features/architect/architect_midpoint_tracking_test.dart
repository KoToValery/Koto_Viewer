import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_midpoint_tracking.dart';
import 'package:kotoview/src/features/architect/rendering/architect_snap_helper.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_snap.dart';
import 'package:kotoview/src/features/architect/rendering/architect_2d_painter.dart';
import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/widgets/architect_tool_palette.dart';
import 'architect_workspace_interaction_test.dart' as workspace;

const baseline = ArchitectCadPrimitive(
  id: 'line',
  type: CadPrimitiveType.line,
  startPoint: Offset.zero,
  endPoint: Offset(8, 0),
);
ArchitectProject fixture({
  List<ArchitectCadPrimitive> lines = const [baseline],
}) => ArchitectProject(
  id: 'p',
  name: 'Midpoints',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  activeStoreyId: 's',
  storeys: [ArchitectStorey(id: 's', name: 'Floor', cadPrimitives: lines)],
);
void hover(
  ArchitectMidpointTracking tracking,
  ArchitectProject p,
  Offset raw, {
  double scale = 100,
  Object context = 'line',
  bool enabled = true,
  Set<String> excludedIds = const {},
}) => tracking.update(
  project: p,
  raw: raw,
  scale: scale,
  context: context,
  enabled: enabled,
  excludedIds: excludedIds,
);
ArchitectSnapResult resolve(
  ArchitectProject p,
  ArchitectMidpointTracking tracking,
  Offset raw, {
  Offset? anchor,
  bool magnetic = true,
  Set<String> excludedIds = const {},
}) => anchor == null
    ? ArchitectSnapHelper.snapFree(
        project: p,
        rawPoint: raw,
        tolerance: .1,
        magnetic: magnetic,
        excludedIds: excludedIds,
        midpointReferences: tracking.references,
      )
    : ArchitectSnapHelper.snapWithAnchor(
        project: p,
        rawPoint: raw,
        anchor: anchor,
        tolerance: .1,
        magnetic: magnetic,
        excludedIds: excludedIds,
        midpointReferences: tracking.references,
      );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'edge hover reveals its middle without changing the drawing or acquiring a remote guide',
    () {
      final p = fixture();
      final before = jsonEncode(p.toJson());
      final tracking = ArchitectMidpointTracking();
      hover(tracking, p, const Offset(1, .02));
      expect(tracking.hints, [const Offset(4, 0)]);
      expect(tracking.references, isEmpty);
      final snap = resolve(p, tracking, const Offset(1, .02));
      expect(snap.point, const Offset(1, 0));
      expect(snap.snapLabel, 'Edge');
      expect(jsonEncode(p.toJson()), before);
    },
  );
  test(
    'acquired middle supplies a bounded guide before drafting angle constraints',
    () {
      final p = fixture();
      final tracking = ArchitectMidpointTracking();
      hover(tracking, p, const Offset(4, .02));
      hover(tracking, p, const Offset(4.03, 4));
      expect(tracking.hints, [const Offset(4, 0)]);
      final snap = resolve(
        p,
        tracking,
        const Offset(4.03, 4),
        anchor: const Offset(1, 1),
      );
      expect(snap.point, const Offset(4, 4));
      expect(snap.snapLabel, 'Midpoint alignment');
      expect(snap.magneticGuides, [(const Offset(4, 0), const Offset(4, 4))]);
      expect(
        resolve(p, tracking, const Offset(4.3, 3.2)).snapLabel,
        isNot('Midpoint alignment'),
      );
      expect(
        resolve(p, tracking, const Offset(4.03, 4), magnetic: false).isSnapped,
        isFalse,
      );
      final wallSnap = ArchitectWallSnap.resolve(
        raw: const Offset(4.03, 4),
        anchor: const Offset(1, 1),
        project: p,
        scale: 100,
        midpointReferences: tracking.references,
      );
      expect(wallSnap.point, const Offset(4, 4));
    },
  );
  test('two acquired middles locate their guide intersection exactly', () {
    final p = fixture(
      lines: [
        baseline,
        const ArchitectCadPrimitive(
          id: 'other',
          type: CadPrimitiveType.line,
          startPoint: Offset(9, 1),
          endPoint: Offset(9, 7),
        ),
      ],
    );
    final tracking = ArchitectMidpointTracking();
    hover(tracking, p, const Offset(4, 0));
    hover(tracking, p, const Offset(9, 4));
    final snap = resolve(p, tracking, const Offset(4.03, 4.02));
    expect(snap.point, const Offset(4, 4));
    expect(snap.magneticGuides, hasLength(2));
  });
  test('inclined edges provide guides normal to their actual direction', () {
    final p = fixture(
      lines: [
        const ArchitectCadPrimitive(
          id: 'diagonal',
          type: CadPrimitiveType.line,
          startPoint: Offset.zero,
          endPoint: Offset(6, 8),
        ),
      ],
    );
    final tracking = ArchitectMidpointTracking();
    hover(tracking, p, const Offset(3, 4));
    final snap = resolve(p, tracking, const Offset(1.418, 5.224));
    expect((snap.point - const Offset(1.4, 5.2)).distance, lessThan(1e-8));
    expect(snap.snapLabel, 'Midpoint alignment');
  });
  test('real object endpoints retain priority over a tracked guide', () {
    final p = fixture(
      lines: [
        baseline,
        const ArchitectCadPrimitive(
          id: 'target',
          type: CadPrimitiveType.line,
          startPoint: Offset(4.03, 3),
          endPoint: Offset(6, 5),
        ),
      ],
    );
    final tracking = ArchitectMidpointTracking();
    hover(tracking, p, const Offset(4, 0));
    final snap = resolve(p, tracking, const Offset(4.04, 3.02));
    expect(snap.point, const Offset(4.03, 3));
    expect(snap.snapLabel, 'Endpoint');
    expect(
      resolve(
        p,
        tracking,
        const Offset(4.03, 4),
        excludedIds: {'line'},
      ).snapLabel,
      isNot('Midpoint alignment'),
    );
  });
  test(
    'references clear on cancellation, context change, exclusion and source deletion',
    () {
      final p = fixture();
      final tracking = ArchitectMidpointTracking();
      hover(tracking, p, const Offset(4, 0));
      hover(tracking, p, const Offset(4, 3), context: 'roof');
      expect(tracking.references, isEmpty);
      hover(tracking, p, const Offset(4, 0));
      hover(tracking, p, const Offset(4, 3), excludedIds: {'line'});
      expect(tracking.hints, isEmpty);
      hover(tracking, p, const Offset(4, 0));
      final deleted = p.updateActiveStorey(
        p.activeStorey.copyWith(cadPrimitives: []),
      );
      expect(
        resolve(deleted, tracking, const Offset(4.03, 3)).snapLabel,
        isNot('Midpoint alignment'),
      );
      hover(tracking, deleted, const Offset(4, 3));
      expect(tracking.hints, isEmpty);
      hover(tracking, p, const Offset(4, 0));
      hover(tracking, p, const Offset(4, 0), enabled: false);
      expect(tracking.hints, isEmpty);
      hover(tracking, p, const Offset(4, 0));
      tracking.clear();
      expect(tracking.hints, isEmpty);
    },
  );
  test(
    'short edges reveal a middle only when enough space is visible on screen',
    () {
      final p = fixture(
        lines: [
          const ArchitectCadPrimitive(
            id: 'short',
            type: CadPrimitiveType.line,
            startPoint: Offset.zero,
            endPoint: Offset(.2, 0),
          ),
        ],
      );
      final tracking = ArchitectMidpointTracking();
      hover(tracking, p, const Offset(.1, 0), scale: 40);
      expect(tracking.hints, isEmpty);
      hover(tracking, p, const Offset(.1, 0), scale: 400);
      expect(tracking.hints, [const Offset(.1, 0)]);
      expect(resolve(p, tracking, const Offset(.1, .01)).snapLabel, 'Midpoint');
    },
  );
  test('slab and roof contours expose the middle of each logical edge', () {
    final p = fixture(lines: []).updateActiveStorey(
      ArchitectStorey(
        id: 's',
        name: 'Floor',
        slabs: const [
          ArchitectSlab(
            id: 'slab',
            polygon: [Offset.zero, Offset(8, 0), Offset(8, 4), Offset(0, 4)],
          ),
        ],
        roofs: [
          ArchitectRoofPlane(
            id: 'roof',
            storeyId: 's',
            points: const [
              Offset(10, 0),
              Offset(16, 0),
              Offset(16, 4),
              Offset(10, 4),
            ],
          ),
        ],
      ),
    );
    final tracking = ArchitectMidpointTracking();
    hover(tracking, p, const Offset(2, .02));
    expect(tracking.hints, contains(const Offset(4, 0)));
    hover(tracking, p, const Offset(12, .02));
    expect(tracking.hints, contains(const Offset(13, 0)));
  });
  test('roof view discovers wall middles from the highest wall storey', () {
    final p = fixture().copyWith(
      activeStoreyId: 'roof',
      storeys: const [
        ArchitectStorey(
          id: 's',
          name: 'Floor',
          walls: [
            ArchitectWall(
              id: 'wall',
              startPoint: Offset.zero,
              endPoint: Offset(8, 0),
            ),
          ],
        ),
        ArchitectStorey(id: 'roof', name: 'Roof', isRoof: true),
      ],
    );
    final tracking = ArchitectMidpointTracking();
    hover(tracking, p, const Offset(2, 0));
    expect(tracking.hints, contains(const Offset(4, 0)));
    hover(tracking, p, const Offset(4, 0));
    expect(
      resolve(p, tracking, const Offset(4.03, 3)).point,
      const Offset(4, 3),
    );
  });

  test('midpoint marks exist only in the interaction layer', () {
    final p = fixture(lines: []);
    for (final layer in [
      ArchitectPaintLayer.model,
      ArchitectPaintLayer.interaction,
    ]) {
      final canvas = ArchitectVectorCanvas();
      Architect2dPainter(
        project: p,
        layer: layer,
        activeTool: ArchitectTool.select,
        zoomScale: 100,
        paintGrid: false,
        midpointHints: const [Offset(4, 4)],
      ).paint(canvas, const Size(800, 600));
      final marks = canvas.operations.whereType<ArchitectVectorPath>().where(
        (op) =>
            (op.path.getBounds().width - .1).abs() < 1e-6 &&
            (op.path.getBounds().height - .1).abs() < 1e-6,
      );
      expect(
        marks,
        layer == ArchitectPaintLayer.model ? isEmpty : hasLength(2),
      );
    }
  });
  testWidgets(
    'line hover reveals a midpoint and commits its tracked alignment',
    (tester) async {
      final commands = ArchitectCommandController(fixture());
      addTearDown(commands.dispose);
      await workspace.open(tester, commands);
      tester
          .widget<ArchitectToolPalette>(find.byType(ArchitectToolPalette))
          .onToolChanged(ArchitectTool.cadLine);
      await tester.pumpAndSettle();
      workspace
          .camera(tester)
          .fit(const Rect.fromLTWH(-1, -1, 10, 7), padding: 160);
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(
        location: workspace.screen(tester, const Offset(1, .02)),
      );
      await mouse.moveTo(workspace.screen(tester, const Offset(1, .02)));
      await tester.pump();
      expect(
        workspace.overlay(tester).midpointHints,
        contains(const Offset(4, 0)),
      );
      expect(commands.canUndo, isFalse);
      await mouse.moveTo(workspace.screen(tester, const Offset(4, 0)));
      await tester.pump();
      await mouse.moveTo(workspace.screen(tester, const Offset(1, 1)));
      await mouse.down(workspace.screen(tester, const Offset(1, 1)));
      await mouse.up();
      await tester.pump();
      await mouse.moveTo(workspace.screen(tester, const Offset(4.03, 4)));
      await tester.pump();
      expect(workspace.overlay(tester).activeSnapLabel, 'Align to midpoint');
      expect(
        (workspace.overlay(tester).activeDraftEnd! - const Offset(4, 4))
            .distance,
        lessThan(1e-8),
      );
      await mouse.down(workspace.screen(tester, const Offset(4.03, 4)));
      await mouse.up();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('wall-end')));
      await tester.pump();
      expect(
        (commands.project.activeStorey.cadPrimitives.last.endPoint -
                const Offset(4, 4))
            .distance,
        lessThan(1e-8),
      );
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'roof polygon keeps a wall midpoint guide ahead of its 45 degree guide',
    (tester) async {
      final p = fixture().copyWith(
        activeStoreyId: 'roof',
        storeys: const [
          ArchitectStorey(
            id: 's',
            name: 'Floor',
            walls: [
              ArchitectWall(
                id: 'wall',
                startPoint: Offset.zero,
                endPoint: Offset(8, 0),
              ),
            ],
          ),
          ArchitectStorey(id: 'roof', name: 'Roof', isRoof: true),
        ],
      );
      final commands = ArchitectCommandController(p);
      addTearDown(commands.dispose);
      await workspace.open(tester, commands);
      tester
          .widget<ArchitectToolPalette>(find.byType(ArchitectToolPalette))
          .onToolChanged(ArchitectTool.roof);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('roof-mode-poly')));
      await tester.pumpAndSettle();
      workspace
          .camera(tester)
          .fit(const Rect.fromLTWH(-1, -1, 10, 7), padding: 180);
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(
        location: workspace.screen(tester, const Offset(4, 0)),
      );
      await mouse.moveTo(workspace.screen(tester, const Offset(4, 0)));
      await tester.pump();
      expect(
        workspace.overlay(tester).midpointHints,
        contains(const Offset(4, 0)),
      );
      await mouse.moveTo(workspace.screen(tester, const Offset(1, 1)));
      await mouse.down(workspace.screen(tester, const Offset(1, 1)));
      await mouse.up();
      await tester.pump();
      await mouse.moveTo(workspace.screen(tester, const Offset(4.03, 4)));
      await tester.pump();
      expect(workspace.overlay(tester).activeSnapLabel, 'Align to midpoint');
      expect(
        (workspace.overlay(tester).roofTool!.candidatePoint! -
                const Offset(4, 4))
            .distance,
        lessThan(1e-8),
      );
      await mouse.down(workspace.screen(tester, const Offset(4.03, 4)));
      await mouse.up();
      await tester.pump();
      expect(
        (workspace.overlay(tester).roofTool!.draftPoints.last -
                const Offset(4, 4))
            .distance,
        lessThan(1e-8),
      );
      await tester.ensureVisible(find.byKey(const ValueKey('roof-draft-cancel')));
      await tester.tap(find.byKey(const ValueKey('roof-draft-cancel')));
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).midpointHints, isEmpty);
      expect(workspace.overlay(tester).roofTool!.draftPoints, isEmpty);
      tester
          .widget<ArchitectToolPalette>(find.byType(ArchitectToolPalette))
          .onToolChanged(ArchitectTool.select);
      await tester.pumpAndSettle();
      expect(workspace.overlay(tester).midpointHints, isEmpty);
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
    },
  );
}
