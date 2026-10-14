import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_snap_helper.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_snap.dart';
import 'package:kotoview/src/features/bim_projects/models/bim_coordinate_frame.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/structural_designer/rendering/structural_pointer_painter.dart';
import 'architect_editing_test.dart' as editing;
import 'architect_workspace_interaction_test.dart' as workspace;

const line = ArchitectCadPrimitive(
  id: 'line',
  type: CadPrimitiveType.line,
  startPoint: Offset(0, 0),
  endPoint: Offset(8, 0),
);
ArchitectProject project(ArchitectStorey storey) => ArchitectProject(
  id: 'p',
  name: 'p',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  storeys: [storey],
  activeStoreyId: storey.id,
);
ArchitectSnapResult snap(
  ArchitectStorey storey,
  Offset raw, {
  Offset? anchor,
}) => anchor == null
    ? ArchitectSnapHelper.snapFree(
        project: project(storey),
        rawPoint: raw,
        tolerance: .1,
      )
    : ArchitectSnapHelper.snapWithAnchor(
        project: project(storey),
        rawPoint: raw,
        anchor: anchor,
        tolerance: .1,
      );

void main() {
  test(
    'CAD line endpoints, midpoint, arbitrary edge and crossing are exact',
    () {
      const floor = ArchitectStorey(
        id: 's',
        name: 's',
        cadPrimitives: [
          line,
          ArchitectCadPrimitive(
            id: 'vertical',
            type: CadPrimitiveType.line,
            startPoint: Offset(3, -4),
            endPoint: Offset(3, 4),
          ),
        ],
      );
      for (final query in <(Offset, Offset, String)>[
        (const Offset(.04, -.03), Offset.zero, 'Endpoint'),
        (const Offset(4.04, .03), const Offset(4, 0), 'Midpoint'),
        (const Offset(2.1, .03), const Offset(2.1, 0), 'Edge'),
        (const Offset(3.03, .04), const Offset(3, 0), 'Intersection'),
      ]) {
        final result = snap(floor, query.$1);
        expect((result.point - query.$2).distance, lessThan(1e-10));
        expect(result.snapLabel, query.$3);
      }
    },
  );

  test('Rectangle has four corners and all four edges', () {
    const floor = ArchitectStorey(
      id: 's',
      name: 's',
      cadPrimitives: [
        ArchitectCadPrimitive(
          id: 'r',
          type: CadPrimitiveType.rect,
          startPoint: Offset(0, 0),
          endPoint: Offset(6, 4),
        ),
      ],
    );
    for (final point in const [
      Offset.zero,
      Offset(6, 0),
      Offset(6, 4),
      Offset(0, 4),
    ]) {
      expect(snap(floor, point + const Offset(.03, .03)).point, point);
    }
    expect(snap(floor, const Offset(6.03, 1.3)).point, const Offset(6, 1.3));
  });

  test('Circles retain exact radius and analytic crossings', () {
    const circle = ArchitectCadPrimitive(
      id: 'c',
      type: CadPrimitiveType.circle,
      startPoint: Offset.zero,
      endPoint: Offset(2, 0),
    );
    final floor = ArchitectStorey(
      id: 's',
      name: 's',
      cadPrimitives: [
        circle,
        const ArchitectCadPrimitive(
          id: 'l',
          type: CadPrimitiveType.line,
          startPoint: Offset(-4, 1),
          endPoint: Offset(4, 1),
        ),
      ],
    );
    final cross = snap(floor, Offset(math.sqrt(3) + .02, 1.02));
    expect(cross.snapLabel, 'Intersection');
    expect((cross.point - Offset(math.sqrt(3), 1)).distance, lessThan(1e-10));
    final free = snap(
      const ArchitectStorey(id: 's', name: 's', cadPrimitives: [circle]),
      const Offset(1.43, 1.43),
    );
    expect(free.point.distance, closeTo(2, 1e-10));
    expect(snap(floor, const Offset(.03, .03)).snapLabel, 'Center');
  });

  test('Every physical element supplies edges, corners or centers', () {
    for (final entry in <(ArchitectStorey, Offset)>[
      (
        const ArchitectStorey(
          id: 's',
          name: 's',
          beams: [
            ArchitectBeam(
              id: 'b',
              startPoint: Offset.zero,
              endPoint: Offset(8, 0),
              width: .4,
            ),
          ],
        ),
        const Offset(1.3, .2),
      ),
      (
        const ArchitectStorey(
          id: 's',
          name: 's',
          stairs: [
            ArchitectStair(
              id: 't',
              startPoint: Offset.zero,
              endPoint: Offset(8, 0),
              width: 1,
            ),
          ],
        ),
        const Offset(1.3, .5),
      ),
      (
        const ArchitectStorey(
          id: 's',
          name: 's',
          slabs: [
            ArchitectSlab(
              id: 'p',
              polygon: [Offset.zero, Offset(6, 0), Offset(6, 4), Offset(0, 4)],
            ),
          ],
        ),
        const Offset(6, 1.3),
      ),
      (
        const ArchitectStorey(
          id: 's',
          name: 's',
          openings: [
            ArchitectOpening(
              id: 'o',
              boundary: [Offset.zero, Offset(6, 0), Offset(6, 4), Offset(0, 4)],
            ),
          ],
        ),
        const Offset(6, 1.3),
      ),
      (
        const ArchitectStorey(
          id: 's',
          name: 's',
          columns: [
            ArchitectColumn(id: 'c', position: Offset.zero, width: 2, depth: 2),
          ],
        ),
        const Offset(1, .3),
      ),
    ]) {
      final result = snap(entry.$1, entry.$2 + const Offset(.02, .02));
      expect(result.isSnapped, isTrue);
      expect((result.point - entry.$2).distance, lessThan(.03));
    }
    const rotated = ArchitectStorey(
      id: 's',
      name: 's',
      columns: [
        ArchitectColumn(
          id: 'c',
          position: Offset.zero,
          width: 2,
          depth: 2,
          rotationDeg: 45,
        ),
      ],
    );
    expect(
      (snap(rotated, Offset(.02, math.sqrt(2) + .03)).point -
              Offset(0, math.sqrt(2)))
          .distance,
      lessThan(1e-10),
    );
  });

  test('Wall faces and insulation corners are usable by generic tools', () {
    for (final ref in [
      WallReferenceLine.center,
      WallReferenceLine.inner,
      WallReferenceLine.outer,
    ]) {
      final wall = ArchitectWall(
        id: 'w',
        startPoint: Offset.zero,
        endPoint: const Offset(6, 0),
        thickness: .37,
        insulationThicknessOverride: .12,
        referenceLine: ref,
      );
      final floor = ArchitectStorey(id: 's', name: 's', walls: [wall]);
      for (final corner in [...wall.polygonCorners, ...wall.coreCorners]) {
        expect(
          (snap(floor, corner + const Offset(.02, .01)).point - corner)
              .distance,
          lessThan(1e-10),
        );
      }
    }
    final floor = const ArchitectStorey(
      id: 's',
      name: 's',
      cadPrimitives: [line],
    );
    final result = ArchitectWallSnap.resolve(
      raw: const Offset(2.1, .03),
      project: project(floor),
      scale: 100,
    );
    expect(result.point, const Offset(2.1, 0));
  });

  test('Perpendicular and parallel drafting give visible bounded guides', () {
    const floor = ArchitectStorey(id: 's', name: 's', cadPrimitives: [line]);
    final perpendicular = snap(
      floor,
      const Offset(2.03, .04),
      anchor: const Offset(2, 3),
    );
    expect(perpendicular.point, const Offset(2, 0));
    expect(perpendicular.magneticGuides, isNotEmpty);
    final alignment = ArchitectSnapHelper.snapFree(
      rawPoint: const Offset(8.03, 3),
      project: project(floor),
      tolerance: .1,
      alignment: true,
    );
    expect(alignment.snapLabel, 'Alignment');
    expect(alignment.point, const Offset(8, 3));
    expect(alignment.magneticGuides, isNotEmpty);
    final ortho = snap(
      const ArchitectStorey(id: 's', name: 's'),
      const Offset(4, .09),
      anchor: Offset.zero,
    );
    expect((ortho.point - const Offset(4, 0)).distance, lessThan(1e-10));
    expect(ortho.magneticGuides, isNotEmpty);
    final tooFar = snap(
      const ArchitectStorey(id: 's', name: 's'),
      const Offset(100, 3),
      anchor: Offset.zero,
    );
    expect(tooFar.isSnapped, isFalse);
  });

  test('Underlay snap uses frame, visible layers and mixed intersections', () {
    final doc = DxfDocument(
      layers: {'cad': DxfLayer(name: 'cad')},
      blocks: {},
      headerVars: {},
      bounds: const Rect.fromLTWH(1000, 2000, 8000, 8000),
      entityStats: {},
      entities: [
        const DxfLine(
          layer: 'cad',
          p1: Offset(4000, -2000),
          p2: Offset(4000, 6000),
        ),
      ],
    );
    const frame = BimCoordinateFrame(
      origin: Offset(1000, 2000),
      unitsPerMeter: 1000,
    );
    final p = project(
      const ArchitectStorey(id: 's', name: 's', cadPrimitives: [line]),
    );
    final result = ArchitectSnapHelper.snapFree(
      rawPoint: const Offset(3.03, .04),
      project: p,
      tolerance: .1,
      underlay: doc,
      frame: frame,
    );
    expect(result.snapLabel, 'Intersection');
    expect(result.point, const Offset(3, 0));
    final hidden = ArchitectSnapHelper.snapFree(
      rawPoint: const Offset(3.03, .04),
      project: p,
      tolerance: .1,
      underlay: doc,
      frame: frame,
      visibility: const {'cad': false},
    );
    expect(hidden.snapLabel, 'Edge');
    expect(hidden.point.dx, 3.03);
  });

  test('Magnet disables object, direction and alignment capture', () {
    final result = ArchitectSnapHelper.snapWithAnchor(
      rawPoint: const Offset(2.03, .04),
      anchor: Offset.zero,
      project: project(
        const ArchitectStorey(id: 's', name: 's', cadPrimitives: [line]),
      ),
      tolerance: .1,
      magnetic: false,
      alignment: true,
    );
    expect(result.isSnapped, isFalse);
    expect((result.point - const Offset(2.03, .04)).distance, lessThan(1e-10));
  });

  test('Moving lines snap with their own endpoints without self capture', () {
    const floor = ArchitectStorey(
      id: 's',
      name: 's',
      cadPrimitives: [
        line,
        ArchitectCadPrimitive(
          id: 'moving',
          type: CadPrimitiveType.line,
          startPoint: Offset(0, 3),
          endPoint: Offset(2, 3),
        ),
      ],
    );
    final p = project(floor);
    final result = ArchitectSnapHelper.snapTranslation(
      project: p,
      elementIds: {'moving'},
      delta: const Offset(7.96, -2.96),
      tolerance: .1,
    );
    expect((result.point - const Offset(8, -3)).distance, lessThan(1e-10));
    expect(result.magneticGuides, isNotEmpty);
    final alone = project(
      const ArchitectStorey(id: 's', name: 's', cadPrimitives: [line]),
    );
    final noSelf = ArchitectSnapHelper.snapTranslation(
      project: alone,
      elementIds: {'line'},
      delta: const Offset(.03, .04),
      tolerance: .1,
    );
    expect(noSelf.isSnapped, isFalse);
    expect(noSelf.point, const Offset(.03, .04));
  });

  for (final tool in <(IconData, String)>[
    (Icons.timeline_rounded, 'line'),
    (Icons.horizontal_rule_rounded, 'beam'),
    (Icons.stairs_rounded, 'stair'),
    (Icons.crop_square_rounded, 'rect'),
    (Icons.radio_button_unchecked_rounded, 'circle'),
    (Icons.straighten_rounded, 'dimension'),
  ]) {
    testWidgets(
      '${tool.$2} quick taps capture the same existing line endpoint',
      (tester) async {
        final model = editing.seeded(
          const ArchitectStorey(id: 's', name: 's', cadPrimitives: [line]),
        );
        addTearDown(model.dispose);
        await workspace.open(tester, model);
        await tester.ensureVisible(find.byIcon(tool.$1));
        await tester.tap(find.byIcon(tool.$1));
        await tester.pumpAndSettle();
        await workspace.wallTap(tester, const Offset(1, -.4));
        await workspace.wallTap(tester, const Offset(8.03, .03));
        if (tool.$2 == 'circle') {
          await tester.tap(find.byKey(const ValueKey('shape-save')));
          await tester.pump();
        }
        final floor = model.project.activeStorey;
        final endpoint = switch (tool.$2) {
          'beam' => floor.beams.single.endPoint,
          'stair' => floor.stairs.single.endPoint,
          'dimension' => floor.dimensions.single.endPoint,
          _ => floor.cadPrimitives.last.endPoint,
        };
        expect(endpoint, const Offset(8, 0));
        if (!{'beam', 'stair', 'dimension'}.contains(tool.$2)) {
          expect(floor.cadPrimitives, hasLength(2));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Held line shows intersection snap and releases at that exact marker',
    (tester) async {
      final model = editing.seeded(
        const ArchitectStorey(
          id: 's',
          name: 's',
          cadPrimitives: [
            line,
            ArchitectCadPrimitive(
              id: 'v',
              type: CadPrimitiveType.line,
              startPoint: Offset(3, -4),
              endPoint: Offset(3, 4),
            ),
          ],
        ),
      );
      addTearDown(model.dispose);
      await workspace.open(tester, model);
      await tester.ensureVisible(find.byIcon(Icons.timeline_rounded));
      await tester.tap(find.byIcon(Icons.timeline_rounded));
      await tester.pumpAndSettle();
      await workspace.wallTap(tester, const Offset(1, -.4));
      final gesture = await tester.startGesture(
        workspace.screen(tester, const Offset(3.03, .04)) + const Offset(0, 64),
      );
      await tester.pump(const Duration(milliseconds: 281));
      final marker =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('architect-offset-pointer')),
                  )
                  .painter!
              as StructuralPointerPainter;
      expect(marker.snapType, isNotNull);
      expect(
        (workspace.camera(tester).toModel(marker.effectivePlacementPosition) -
                const Offset(3, 0))
            .distance,
        lessThan(1e-10),
      );
      expect(workspace.overlay(tester).magneticGuides, isNotEmpty);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        model.project.activeStorey.cadPrimitives.last.endPoint,
        const Offset(3, 0),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Global magnet can be switched manually for CAD lines', (
    tester,
  ) async {
    final model = editing.seeded(
      const ArchitectStorey(id: 's', name: 's', cadPrimitives: [line]),
    );
    addTearDown(model.dispose);
    await workspace.open(tester, model);
    await tester.ensureVisible(find.byIcon(Icons.timeline_rounded));
    await tester.tap(find.byIcon(Icons.timeline_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('architect-magnet')));
    await tester.pump();
    await workspace.wallTap(tester, const Offset(1, -.4));
    await workspace.wallTap(tester, const Offset(8.03, .03));
    expect(
      (model.project.activeStorey.cadPrimitives.last.endPoint -
              const Offset(8.03, .03))
          .distance,
      lessThan(1e-10),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Line body magnet preview commits once and Undo restores it', (
    tester,
  ) async {
    final model = editing.seeded(
      const ArchitectStorey(
        id: 's',
        name: 's',
        cadPrimitives: [
          line,
          ArchitectCadPrimitive(
            id: 'moving',
            type: CadPrimitiveType.line,
            startPoint: Offset(0, 3),
            endPoint: Offset(2, 3),
          ),
        ],
      ),
    );
    addTearDown(model.dispose);
    await workspace.open(tester, model);
    await tester.ensureVisible(find.byIcon(Icons.timeline_rounded));
    await tester.tap(find.byIcon(Icons.timeline_rounded));
    await tester.pumpAndSettle();
    await editing.hold(tester, const Offset(1, 3));
    expect(workspace.overlay(tester).selectedElementId, 'moving');
    final old = model.project;
    final gesture = await tester.startGesture(
      workspace.screen(tester, const Offset(1, 3)),
    );
    await tester.pump(const Duration(milliseconds: 281));
    await gesture.moveTo(workspace.screen(tester, const Offset(6.96, .04)));
    await tester.pump();
    expect(identical(model.project, old), isTrue);
    final preview = workspace
        .overlay(tester)
        .project
        .activeStorey
        .cadPrimitives
        .last;
    expect((preview.endPoint - const Offset(8, 0)).distance, lessThan(1e-10));
    expect(workspace.overlay(tester).magneticGuides, isNotEmpty);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      model.project.activeStorey.cadPrimitives.last.toJson(),
      preview.toJson(),
    );
    expect(
      model.project.activeStorey.cadPrimitives.first.toJson(),
      line.toJson(),
    );
    model.undo();
    expect(identical(model.project, old), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Phone line endpoint snap works with the offset pointer and shared header magnet',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = editing.seeded(
        const ArchitectStorey(id: 's', name: 's', cadPrimitives: [line]),
      );
      addTearDown(model.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('bg'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ArchitectWorkspaceScreen(commandController: model),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byIcon(Icons.timeline_rounded));
      await tester.tap(find.byIcon(Icons.timeline_rounded));
      await tester.pumpAndSettle();
      final inputRect = tester.getRect(
        find.byKey(const ValueKey('architect-viewport-input')),
      );
      final magnetRect = tester.getRect(
        find.byKey(const ValueKey('architect-magnet')),
      );
      expect(tester.getRect(find.byType(AppBar)).contains(magnetRect.center), isTrue);
      expect(inputRect.contains(magnetRect.center), isFalse);
      final finger =
          workspace.screen(tester, const Offset(.03, .04)) +
          const Offset(0, 64);
      expect(inputRect.contains(finger), isTrue);
      final gesture = await tester.startGesture(finger);
      await tester.pump(const Duration(milliseconds: 281));
      final marker =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('architect-offset-pointer')),
                  )
                  .painter!
              as StructuralPointerPainter;
      expect(
        (workspace.camera(tester).toModel(marker.effectivePlacementPosition))
            .distance,
        lessThan(1e-10),
      );
      await gesture.up();
      await tester.pump();
      expect(workspace.overlay(tester).activeDraftStart, Offset.zero);
      expect(tester.takeException(), isNull);
    },
  );
}
