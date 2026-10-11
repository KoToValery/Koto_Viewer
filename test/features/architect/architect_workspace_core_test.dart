import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_grid_axis.dart';
import 'package:kotoview/src/features/architect/models/architect_zone.dart';
import 'package:kotoview/src/features/architect/rendering/architect_snap_helper.dart';
import 'package:kotoview/src/features/architect/rendering/architect_zone_snap.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_zone_tool.dart';
import 'package:kotoview/src/features/bim_projects/models/bim_coordinate_frame.dart';
import 'package:kotoview/src/features/bim_projects/controllers/bim_viewport_controller.dart';
import 'package:kotoview/src/features/structural_designer/analysis/structural_geometry_units.dart';

ArchitectProject project({
  List<ArchitectWall> walls = const [],
  List<StructuralGridAxis> axes = const [],
  ArchitectUnit units = ArchitectUnit.meters,
}) => ArchitectProject(
  id: 'p',
  name: 'Test',
  units: units,
  gridAxes: axes,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  activeStoreyId: 's',
  storeys: [ArchitectStorey(id: 's', name: 'Floor', walls: walls)],
);

void main() {
  test(
    'Floor navigation is separate from Undo history and keeps the viewed floor',
    () {
      final original = project().copyWith(
        storeys: const [
          ArchitectStorey(id: 's', name: 'Floor 1'),
          ArchitectStorey(id: 's2', name: 'Floor 2'),
        ],
      );
      final commands = ArchitectCommandController(original);
      addTearDown(commands.dispose);
      commands.activateStorey('s2');
      expect(commands.canUndo, isFalse);
      commands.execute(
        const CreateArchitectWall(
          storeyId: 's',
          wall: ArchitectWall(
            id: 'w',
            startPoint: Offset.zero,
            endPoint: Offset(5, 0),
          ),
        ),
      );
      commands.undo();
      expect(commands.project.activeStoreyId, 's2');
      commands.activateStorey('s');
      expect(commands.canRedo, isTrue);
      commands.redo();
      expect(commands.project.activeStoreyId, 's');
      expect(commands.project.activeStorey.walls.single.id, 'w');
    },
  );
  test(
    'CAD metre/mm/inch frames round-trip without quantizing imported coordinates',
    () {
      for (final units in [1.0, 1000.0, 1 / .0254]) {
        final frame = BimCoordinateFrame(
          origin: const Offset(25000, -47000),
          unitsPerMeter: units,
        );
        const point = Offset(-2.123456789, 4.456789123);
        expect(
          (frame.toModel(frame.toCad(point)) - point).distance,
          lessThan(1e-10),
        );
        final structural = StructuralGeometryUnits(units, frame.origin);
        expect(
          (structural.toMetres(frame.toCad(point)) - point).distance,
          lessThan(1e-9),
        );
      }
    },
  );

  test('Metric/imperial drafting steps are separate from model precision', () {
    expect(
      BimPrecisionPolicy.metric.inputValue(1.23456),
      closeTo(1.235, 1e-12),
    );
    expect(
      BimPrecisionPolicy.imperial.inputValue(.0254 / 16),
      closeTo(.0015875, 1e-12),
    );
    expect(ArchitectUnit.inches.format(.0254 / 16), '0 1/16 in');
    expect(ArchitectUnit.feet.format(.3048 + .0254 * 3.5), '1′ 3 1/2″');
  });

  test(
    'Camera focal point, resizing and zoom bounds preserve model coordinates',
    () {
      final camera = BimViewportController();
      addTearDown(camera.dispose);
      camera.resize(const Size(800, 600));
      camera.fit(const Rect.fromLTRB(-10, -5, 10, 5));
      const focal = Offset(230, 140);
      final anchor = camera.toModel(focal);
      camera.navigate(
        previousFocal: focal,
        focal: focal + const Offset(30, 50),
        scaleFactor: 2,
      );
      expect(
        (camera.toModel(focal + const Offset(30, 50)) - anchor).distance,
        lessThan(1e-10),
      );
      final center = camera.toModel(camera.size.center(Offset.zero));
      camera.resize(const Size(1000, 800));
      expect(
        (camera.toModel(camera.size.center(Offset.zero)) - center).distance,
        lessThan(1e-10),
      );
      camera.navigate(previousFocal: focal, focal: focal, scaleFactor: 1e20);
      expect(camera.scale, BimViewportController.maxScale);
      expect(camera.visibleRect.isFinite, isTrue);
    },
  );

  test(
    'Endpoint snap chooses nearest geometry, independent of wall ordering',
    () {
      const farther = ArchitectWall(
        id: 'a',
        startPoint: Offset(1.1, 0),
        endPoint: Offset(4, 0),
      );
      const nearer = ArchitectWall(
        id: 'b',
        startPoint: Offset(1.01, 0),
        endPoint: Offset(5, 0),
      );
      for (final walls in [
        [farther, nearer],
        [nearer, farther],
      ]) {
        expect(
          ArchitectSnapHelper.snapFree(
            rawPoint: const Offset(1, 0),
            project: project(walls: walls),
            tolerance: .15,
          ).point,
          nearer.startPoint,
        );
      }
    },
  );

  test('Angle capture cannot move long segments beyond the capture radius', () {
    const raw = Offset(10, .8);
    final snap = ArchitectSnapHelper.snapWithAnchor(
      anchor: Offset.zero,
      rawPoint: raw,
      project: project(),
      tolerance: .12,
    );
    expect(snap.isSnapped, isFalse);
    expect((snap.point - raw).distance, lessThan(.001));
  });

  test('Axis intersections and imported submillimetre vertices remain exact', () {
    final p = project(
      axes: const [
        StructuralGridAxis(
          id: 'a',
          name: 'A',
          start: Offset(1.1234567, -5),
          end: Offset(1.1234567, 5),
        ),
        StructuralGridAxis(
          id: 'b',
          name: 'B',
          start: Offset(-5, 2.7654321),
          end: Offset(5, 2.7654321),
        ),
      ],
    );
    final snap = ArchitectSnapHelper.snapFree(
      rawPoint: const Offset(1.13, 2.77),
      project: p,
      tolerance: .1,
    );
    // A projection may be closer than the intersection; either remains on the exact imported axis.
    expect(snap.isSnapped, isTrue);
    expect(snap.point.dy, 2.7654321);
    final exact = ArchitectSnapHelper.snapFree(
      rawPoint: const Offset(1.1234567, 2.7654321),
      project: p,
    );
    expect(
      (exact.point - const Offset(1.1234567, 2.7654321)).distance,
      lessThan(1e-10),
    );
  });

  test('Zone axis snapping caps the combined correction at its radius', () {
    final p = project(
      axes: const [
        StructuralGridAxis(
          id: 'a',
          name: 'A',
          start: Offset(0, -5),
          end: Offset(0, 5),
        ),
        StructuralGridAxis(
          id: 'b',
          name: 'B',
          start: Offset(-5, 0),
          end: Offset(5, 0),
        ),
      ],
    );
    const raw = Offset(.09, .09);
    final snap = ArchitectZoneSnap.snap(raw: raw, project: p, tolerance: .1);
    expect((snap.point - raw).distance, lessThanOrEqualTo(.1 + 1e-9));
  });

  test(
    'Batch automation commits once and rollback leaves history and model untouched',
    () {
      final commands = ArchitectCommandController(project());
      addTearDown(commands.dispose);
      var events = 0;
      commands.addListener(() => events++);
      commands.executeBatch(const [
        CreateArchitectWall(
          storeyId: 's',
          wall: ArchitectWall(
            id: 'w',
            startPoint: Offset.zero,
            endPoint: Offset(3, 0),
          ),
        ),
        PlaceArchitectColumn(
          storeyId: 's',
          column: ArchitectColumn(id: 'c', position: Offset(2, 2)),
        ),
      ]);
      expect(events, 1);
      final revision = commands.project;
      expect(
        () => commands.executeBatch(const [
          MoveArchitectElement(
            storeyId: 's',
            elementId: 'w',
            delta: Offset(1, 2),
          ),
          PlaceArchitectColumn(
            storeyId: 's',
            column: ArchitectColumn(
              id: 'bad',
              position: Offset.zero,
              width: -1,
            ),
          ),
        ]),
        throwsArgumentError,
      );
      expect(commands.project, same(revision));
      expect(events, 1);
      commands.undo();
      expect(commands.project.activeStorey.walls, isEmpty);
      expect(commands.project.activeStorey.columns, isEmpty);
      commands.redo();
      expect(commands.project, same(revision));
      commands.execute(
        const MoveArchitectElement(
          storeyId: 's',
          elementId: 'w',
          delta: Offset(1, 2),
        ),
      );
      expect(
        commands.project.activeStorey.walls.single.startPoint,
        const Offset(1, 2),
      );
    },
  );

  test('Rapid automation IDs do not collide', () {
    final ids = {
      for (var i = 0; i < 10000; i++) ArchitectElementId.next('wall'),
    };
    expect(ids.length, 10000);
  });

  test(
    'Model editing preserves 5 mm niches and cancelling a drag restores its snapshot',
    () {
      const polygon = [
        Offset(0, 0),
        Offset(3, 0),
        Offset(3, 3),
        Offset(2, 3),
        Offset(2, 3.005),
        Offset(1, 3.005),
        Offset(1, 3),
        Offset(0, 3),
      ];
      final tool = ArchitectZoneTool();
      addTearDown(tool.dispose);
      final zone = ArchitectZone(
        id: 'z',
        name: 'Room',
        category: ArchitectZoneCategory.living,
        polygon: polygon,
      );
      tool.startEditingZone(zone);
      expect(tool.commitEditingZone()!.polygon, polygon);
      tool.startEditingZone(zone);
      tool.toggleMoveWholeZoneMode();
      tool.startMovingZone(const Offset(.5, .5));
      tool.updateMovingZone(const Offset(1.5, 1.5));
      tool.cancelMovingZone();
      expect(tool.editingPolygon, polygon);
      expect(tool.canUndoEdit, isFalse);
    },
  );
}
