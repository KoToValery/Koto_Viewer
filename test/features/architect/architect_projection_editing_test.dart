import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/architect/services/architect_building_elevation.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_projection_editing.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_geometry.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/models/mesh_3d.dart';
import 'architect_elevation_test.dart' as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'lateral alignment uses actual jambs across floors and preserves host constraints',
    () {
      final p = fixture.elevationProject();
      final upper = p.storeys.last;
      final wall = upper.walls.first;
      final project = p.copyWith(
        storeys: [
          p.storeys.first,
          upper.copyWith(
            walls: [
              wall.copyWith(
                windows: [
                  wall.windows.first.copyWith(offsetRatio: .23),
                  ...wall.windows.skip(1),
                ],
              ),
              ...upper.walls.skip(1),
            ],
          ),
        ],
      );
      final geometry = ArchitectBuildingElevation.build(
        project,
        fixture.facade,
      );
      final aligned = ArchitectProjectionEditing.align(
        project,
        'w00',
        'left',
        fixture.facade.centre,
        fixture.facade.right,
        geometry.elementPaths.keys,
      );
      final before = ArchitectProjectionEditing.openingBounds(
        project,
        'w10',
        fixture.facade.centre,
        fixture.facade.right,
      )!;
      final after = ArchitectProjectionEditing.openingBounds(
        aligned,
        'w00',
        fixture.facade.centre,
        fixture.facade.right,
      )!;
      expect(after.left, closeTo(before.left, 1e-6));
      expect(after.top, .9);
      expect(aligned.activeStoreyId, p.activeStoreyId);
      expect(
        aligned.activeStorey.walls.first.windows.first.offsetRatio,
        closeTo(.23, 1e-6),
      );
    },
  );
  test(
    'facade retains visible opening identities without exposing rear windows',
    () {
      final p = fixture.elevationProject();
      final drawing = ArchitectBuildingElevation.build(p, fixture.facade);
      expect(
        drawing.elementPaths.keys,
        containsAll(['w00', 'w01', 'd', 'w10', 'front0']),
      );
      final path = drawing.elementPaths['w00']!;
      expect(
        ArchitectProjectionEditing.pick(
          p,
          drawing.elementPaths,
          path.getBounds().center,
          .02,
        ),
        'w00',
      );
      final rear = p.activeStorey.walls.firstWhere((w) => w.id == 'back0');
      final front = p.activeStorey.walls.firstWhere((w) => w.id == 'front0');
      final next = p.updateActiveStorey(
        p.activeStorey.copyWith(
          walls: [
            for (final w in p.activeStorey.walls)
              if (w.id == rear.id)
                rear.copyWith(
                  windows: [
                    front.windows.first.copyWith(
                      id: 'rear-window',
                      wallId: rear.id,
                    ),
                  ],
                )
              else
                w,
          ],
        ),
      );
      expect(
        ArchitectBuildingElevation.build(next, fixture.facade).elementPaths,
        isNot(contains('rear-window')),
      );
    },
  );
  test(
    'opening cut regions have their own identity and wall hatches do not overlap them',
    () {
      final p = fixture.elevationProject();
      const cut = ArchitectSection(
        id: 'cut',
        start: Offset(-1, 0),
        end: Offset(9, 0),
      );
      final data = ArchitectBuildingSection.build(p, cut);
      final opening = data.elementPaths['w00']!;
      expect(opening.getBounds().height, greaterThan(1));
      final overlap = Path.combine(
        PathOperation.intersect,
        opening,
        data.elementPaths['front0']!,
      );
      expect(overlap.getBounds().isEmpty, isTrue);
      expect(
        ArchitectProjectionEditing.pick(
          p,
          data.elementPaths,
          opening.getBounds().center,
          .1,
        ),
        'w00',
      );
    },
  );
  test(
    'clearances use nearest jambs, finished floor and actual slab underside',
    () {
      final p = fixture.elevationProject();
      List<ArchitectOpeningMeasure> measures(ArchitectProject project) =>
          ArchitectProjectionEditing.measures(
            project,
            'w00',
            fixture.facade.centre,
            fixture.facade.right,
          );
      final m = measures(p);
      expect(
        m.singleWhere((m) => m.kind == ArchitectOpeningDistance.left).value,
        closeTo(.95, 1e-6),
      );
      expect(
        m.singleWhere((m) => m.kind == ArchitectOpeningDistance.right).value,
        closeTo(1.1, 1e-6),
      );
      expect(
        m.singleWhere((m) => m.kind == ArchitectOpeningDistance.sill).value,
        closeTo(.9, 1e-6),
      );
      expect(
        m.singleWhere((m) => m.kind == ArchitectOpeningDistance.head).value,
        closeTo(.5, 1e-6),
      );
      for (final kind in ArchitectOpeningDistance.values) {
        final initial = m.singleWhere((m) => m.kind == kind);
        final target = initial.value / 2;
        final result = ArchitectProjectionEditing.distance(
          p,
          'w00',
          initial,
          target,
          fixture.facade.right,
        );
        expect(
          measures(result).singleWhere((m) => m.kind == kind).value,
          closeTo(target, 1e-6),
        );
      }
      final noSlabs = p.copyWith(
        storeys: [for (final s in p.storeys) s.copyWith(slabs: [])],
      );
      expect(
        measures(noSlabs).any((m) => m.kind == ArchitectOpeningDistance.head),
        isFalse,
      );
    },
  );
  test(
    'edits preserve storey, style, pane count and shared undo, rejecting collisions',
    () {
      final base = fixture.elevationProject();
      final source = base.copyWith(
        activeStoreyId: 's1',
        storeys: [
          for (final s in base.storeys)
            if (s.id != 's0')
              s
            else
              s.copyWith(
                walls: [
                  for (final w in s.walls)
                    if (w.id != 'front0')
                      w
                    else
                      w.copyWith(
                        windows: [
                          for (final win in w.windows)
                            if (win.id == 'w00')
                              win.copyWith(panesCount: 3)
                            else
                              win,
                        ],
                      ),
                ],
              ),
        ],
      );
      final controller = ArchitectCommandController(source);
      addTearDown(controller.dispose);
      controller.commit(
        ArchitectProjectionEditing.move(
          controller.project,
          'w00',
          const Offset(.2, .1),
          const Offset(1, 0),
          elevation: true,
        ),
      );
      expect(controller.project.activeStoreyId, 's1');
      final win = controller.project.storeys.first.walls.first.windows.first;
      expect(win.panesCount, 3);
      expect(win.sillHeight, closeTo(1, 1e-6));
      expect(win.offsetRatio, closeTo(1.8 / 8, 1e-6));
      expect(controller.undoCount, 1);
      controller.undo();
      expect(
        controller.project.storeys.first.walls.first.windows.first.sillHeight,
        .9,
      );
      controller.redo();
      expect(
        controller.project.storeys.first.walls.first.windows.first.sillHeight,
        closeTo(1, 1e-6),
      );
      expect(
        () => ArchitectProjectionEditing.move(
          controller.project,
          'w00',
          const Offset(2, 0),
          const Offset(1, 0),
          elevation: true,
        ),
        throwsArgumentError,
      );
      expect(
        () => ArchitectProjectionEditing.move(
          controller.project,
          'w00',
          const Offset(0, 3),
          const Offset(1, 0),
          elevation: false,
        ),
        throwsArgumentError,
      );
      final changed = ArchitectProjectionEditing.properties(
        controller.project,
        'w00',
        {'height': 1.2},
        {},
      );
      expect(changed.activeStoreyId, 's1');
      expect(changed.storeys.first.walls.first.windows.first.height, 1.2);
    },
  );
  test(
    'oblique facade movement stays on host and section movement remains vertical',
    () {
      final p = fixture.elevationProject();
      const axis = Offset(.8, .6);
      final moved = ArchitectProjectionEditing.move(
        p,
        'w00',
        const Offset(.16, .1),
        axis,
        elevation: true,
      );
      expect(
        moved.activeStorey.walls.first.windows.first.offsetRatio,
        closeTo(1.8 / 8, 1e-6),
      );
      final vertical = ArchitectProjectionEditing.move(
        p,
        'w00',
        const Offset(10, .1),
        axis,
        elevation: false,
      );
      expect(
        vertical.activeStorey.walls.first.windows.first.offsetRatio,
        p.activeStorey.walls.first.windows.first.offsetRatio,
      );
      expect(
        vertical.activeStorey.walls.first.windows.first.sillHeight,
        closeTo(1, 1e-6),
      );
    },
  );
  test(
    'roof placement is persisted once; manual move changes section and real mesh equally',
    () {
      final controller = ArchitectCommandController(fixture.elevationProject());
      addTearDown(controller.dispose);
      final roof = ArchitectRoofPlane(
        id: 'r',
        storeyId: 's1',
        points: [
          const Offset(-.5, -.5),
          const Offset(8.5, -.5),
          const Offset(8.5, 3),
          const Offset(-.5, 3),
        ],
        baseElevationOffset: 12,
        eavesOverhang: .5,
        slopeDegrees: 20,
      );
      controller.execute(CreateArchitectRoofPlane(storeyId: 's1', roof: roof));
      final placed = controller.project.storeys.last.roofs.single;
      expect(placed.baseElevationOffset, 3);
      const cut = ArchitectSection(
        id: 'roof-cut',
        start: Offset(4, -2),
        end: Offset(4, 4),
      );
      final before = ArchitectRoofGeometry.buildSectionSlices(
        storey: controller.project.storeys.last,
        sectionLine: cut,
      ).single;
      double meshMin(ArchitectProject p) {
        final sources = <Triangle3D, String>{};
        final mesh = Architect3dBuilder.buildProjectMesh(
          p,
          previewGeometry: false,
          sources: sources,
        );
        return mesh.triangles
            .where((t) => sources[t] == 'r')
            .expand((t) => [t.v0.z, t.v1.z, t.v2.z])
            .reduce(math.min);
      }

      final z0 = meshMin(controller.project);
      controller.commit(
        ArchitectProjectionEditing.move(
          controller.project,
          'r',
          const Offset(0, .35),
          const Offset(0, 1),
          elevation: false,
        ),
      );
      expect(
        controller.project.storeys.last.roofs.single.attachToWalls,
        isFalse,
      );
      final after = ArchitectRoofGeometry.buildSectionSlices(
        storey: controller.project.storeys.last,
        sectionLine: cut,
      ).single;
      expect(
        after.bottomProfile.first.dy - before.bottomProfile.first.dy,
        closeTo(.35, 1e-6),
      );
      expect(meshMin(controller.project) - z0, closeTo(.35, 1e-6));
      controller.undo();
      expect(
        controller.project.storeys.last.roofs.single.baseElevationOffset,
        3,
      );
      controller.redo();
      expect(
        controller.project.storeys.last.roofs.single.baseElevationOffset,
        closeTo(3.35, 1e-6),
      );
    },
  );
  test(
    'a roof-only storey attaches to the lower wall top in model coordinates',
    () {
      final base = fixture.elevationProject();
      final roof = ArchitectRoofPlane(
        id: 'r',
        storeyId: 'roof',
        points: [
          const Offset(0, 0),
          const Offset(8, 0),
          const Offset(8, 4),
          const Offset(0, 4),
        ],
        baseElevationOffset: 9,
      );
      final p = base.copyWith(
        storeys: [
          base.storeys.first,
          ArchitectStorey(id: 'roof', name: '', elevation: 3, roofs: [roof]),
        ],
      );
      final controller = ArchitectCommandController(p);
      addTearDown(controller.dispose);
      expect(
        controller.project.storeys.last.roofs.single.baseElevationOffset,
        0,
      );
      final stored = ArchitectProject.fromJson(controller.project.toJson());
      expect(stored.storeys.last.roofs.single.baseElevationOffset, 0);
    },
  );
  test(
    'resolved roof positions survive wall edits and reload; renderers never reattach',
    () {
      final base = fixture.elevationProject();
      final roof = ArchitectRoofPlane(
        id: 'stored',
        storeyId: 's1',
        points: [
          const Offset(-.5, -.5),
          const Offset(8.5, -.5),
          const Offset(8.5, 4),
          const Offset(-.5, 4),
        ],
        baseElevationOffset: 4,
        attachToWalls: true,
        placementResolved: true,
      );
      final project = base.copyWith(
        storeys: [
          base.storeys.first,
          base.storeys.last.copyWith(roofs: [roof]),
        ],
      );
      final controller = ArchitectCommandController(project);
      addTearDown(controller.dispose);
      expect(
        controller.project.storeys.last.roofs.single.baseElevationOffset,
        4,
      );
      final changed = controller.project.copyWith(
        storeys: [
          controller.project.storeys.first,
          controller.project.storeys.last.copyWith(height: 5),
        ],
      );
      controller.commit(changed);
      final reopened = ArchitectCommandController(
        ArchitectProject.fromJson(controller.project.toJson()),
      );
      addTearDown(reopened.dispose);
      expect(reopened.project.storeys.last.roofs.single.baseElevationOffset, 4);
      const cut = ArchitectSection(
        id: 'cut',
        start: Offset(4, -2),
        end: Offset(4, 5),
      );
      final before = ArchitectRoofGeometry.buildSectionSlices(
        storey: project.storeys.last,
        sectionLine: cut,
      ).single;
      final after = ArchitectRoofGeometry.buildSectionSlices(
        storey: project.storeys.last.copyWith(
          roofs: [roof.copyWith(baseElevationOffset: 5)],
        ),
        sectionLine: cut,
      ).single;
      expect(
        after.bottomProfile.first.dy - before.bottomProfile.first.dy,
        closeTo(1, 1e-6),
      );
    },
  );
}
