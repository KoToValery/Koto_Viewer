import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_wall_type.dart';
import 'package:kotoview/src/features/architect/rendering/architect_path_solid.dart';
import 'package:kotoview/src/features/architect/rendering/architect_mesh_boolean.dart';
import 'package:kotoview/src/features/architect/rendering/architect_special_wall_geometry.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_layers.dart';
import 'package:kotoview/src/features/architect/services/architect_wall_overshoot_detector.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_wall_compositions.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/models/mesh_3d.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/services/architect_panel_supports.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_placement.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/rendering/architect_mesh_section.dart';
import 'package:kotoview/src/features/architect/services/architect_wall_connection_policy.dart';

ArchitectWall special(
  String id,
  ArchitectWallSystemKind kind,
  Offset a,
  Offset b, {
  double height = .65,
}) {
  final type = ArchitectWallType.standardCatalog(
    includeSpecial: true,
  ).firstWhere((t) => t.system.kind == kind);
  return ArchitectWall(
    id: id,
    startPoint: a,
    endPoint: b,
    system: type.system,
    layers: type.resolvedLayers,
    thickness: type.totalThickness,
    location: type.resolvedLocation,
    loadBearing: type.isLoadBearing,
    followStoreyHeight: false,
    height: height,
  );
}

ArchitectProject project(List<ArchitectWall> walls) => ArchitectProject(
  id: 'p',
  name: '',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  activeStoreyId: 's',
  storeys: [ArchitectStorey(id: 's', name: '', walls: walls)],
);
double volume(List<Triangle3D> mesh) => mesh
    .fold<double>(0, (value, t) => value + t.v0.dot(t.v1.cross(t.v2)) / 6)
    .abs();
bool inside(List<Triangle3D> mesh, Vector3 p) {
  const ray = Vector3(.317, .593, .739);
  var count = 0;
  for (final t in mesh) {
    final a = t.v1 - t.v0, b = t.v2 - t.v0, h = ray.cross(b), det = a.dot(h);
    if (det.abs() < 1e-10) continue;
    final f = 1 / det, s = p - t.v0, u = f * s.dot(h);
    if (u < 0 || u > 1) continue;
    final q = s.cross(a), v = f * ray.dot(q);
    if (v < 0 || u + v > 1) continue;
    if (f * b.dot(q) > 1e-8) count++;
  }
  return count.isOdd;
}

void main() {
  test(
    'display shell removes shared contacts without changing section volumes',
    () {
      List<Triangle3D> box(double x) => ArchitectPathSolid.extrude(
        Path()..addRect(Rect.fromLTWH(x, 0, 1, 1)),
        0,
        1,
        const Color(0xff000000),
      );
      final solids = [box(0), box(1)],
          shell = ArchitectMeshBoolean.exposedSurfaces(solids);
      expect(solids.map(volume), everyElement(closeTo(1, 1e-8)));
      expect(
        shell
            .expand((s) => s)
            .where(
              (t) => [t.v0, t.v1, t.v2].every((v) => (v.x - 1).abs() < 1e-7),
            ),
        isEmpty,
      );
      final section = ArchitectMeshSection.horizontal(solids.first, .5);
      expect(section.contains(const Offset(.5, .5)), isTrue);
      expect(
        shell
            .expand((s) => s)
            .every(
              (t) => [
                t.v0,
                t.v1,
                t.v2,
              ].every((v) => v.x.isFinite && v.y.isFinite && v.z.isFinite),
            ),
        isTrue,
      );
    },
  );
  test(
    'panel standoff brackets bridge the actual column face and horizontal panels use column rails',
    () {
      final source =
          special(
            'p',
            ArchitectWallSystemKind.sandwichPanels,
            const Offset(0, .3),
            const Offset(3, .3),
            height: 2.4,
          ).copyWith(
            systemPlacement: const ArchitectWallSystemPlacement(
              columnIds: ['c1', 'c2'],
              mountingOffset: .05,
            ),
          );
      final floor = ArchitectStorey(
        id: 's',
        name: '',
        walls: [source],
        columns: const [
          ArchitectColumn(
            id: 'c1',
            position: Offset.zero,
            width: .3,
            depth: .3,
          ),
          ArchitectColumn(
            id: 'c2',
            position: Offset(3, 0),
            width: .3,
            depth: .3,
          ),
        ],
      );
      final bound = ArchitectPanelSupports.synchronize(floor);
      final components = ArchitectSpecialWallGeometry.build(bound);
      final brackets = components
          .where((c) => c.id.startsWith('bracket_'))
          .toList();
      expect(brackets, isNotEmpty);
      expect(
        brackets.any(
          (c) => inside(c.triangles, const Vector3(.01, .175, .0015)),
        ),
        isTrue,
      );
      expect(
        components
            .where((c) => c.id.startsWith('rail_'))
            .any((c) => inside(c.triangles, const Vector3(1, .201, .025))),
        isTrue,
      );
      expect(
        components
            .where((c) => c.id.startsWith('rail_'))
            .any((c) => inside(c.triangles, const Vector3(1, .25, .025))),
        isFalse,
        reason: 'The RHS cavity must remain empty',
      );
      expect(components.every((c) => c.bounds.min.z >= -1e-7), isTrue);
      final horizontal = bound.copyWith(
        walls: [
          bound.walls.single.copyWith(
            system: source.system.copyWith(horizontalPanels: true),
          ),
        ],
      );
      final verticalRails = ArchitectSpecialWallGeometry.build(
        horizontal,
      ).where((c) => c.id.startsWith('rail_')).toList();
      expect(verticalRails.length, 2);
      expect(
        verticalRails.every(
          (c) => c.bounds.max.x <= .051 || c.bounds.min.x >= 2.949,
        ),
        isTrue,
        reason:
            'Vertical supports for horizontal panels must follow the bound columns',
      );
    },
  );
  test('hollow support section preserves its central void', () {
    final outside = ArchitectPathSolid.extrude(
      Path()..addRect(const Rect.fromLTWH(0, 0, .1, .05)),
      0,
      1,
      const Color(0xff000000),
    );
    final hole = ArchitectPathSolid.extrude(
      Path()..addRect(const Rect.fromLTWH(.004, .004, .092, .042)),
      -.1,
      1.1,
      const Color(0xff000000),
    );
    final tube = ArchitectMeshBoolean.subtract(outside, hole);
    final cut = ArchitectMeshSection.horizontal(tube, .5);
    expect(cut.contains(const Offset(.002, .025)), isTrue);
    expect(cut.contains(const Offset(.05, .025)), isFalse);
  });
  test(
    'T and X log contacts remain clean after reversing both montage directions',
    () {
      for (final crossed in [false, true]) {
        final a = special(
          'a',
          ArchitectWallSystemKind.roundLogs,
          const Offset(1, 0),
          const Offset(-1, 0),
        );
        final b = special(
          'b',
          ArchitectWallSystemKind.roundLogs,
          crossed ? const Offset(0, 1) : Offset.zero,
          const Offset(0, -1),
        );
        final floor = project([b, a]).activeStorey;
        ArchitectWallConnectionPolicy.validateStorey(floor);
        final components = ArchitectSpecialWallGeometry.build(floor);
        final layouts = ArchitectSpecialWallGeometry.logLayouts([a, b]);
        expect(layouts['b']!.phase, .5);
        if (crossed) {
          expect(layouts['b']!.from, 0);
          expect(layouts['b']!.to, 2);
        }
        for (final point in [
          const Vector3(.021, .032, .057),
          const Vector3(-.037, -.04, .17),
          const Vector3(.04, .03, .29),
        ]) {
          expect(
            components.where((c) => inside(c.triangles, point)).length,
            lessThanOrEqualTo(1),
          );
        }
      }
    },
  );
  test(
    'changing the diameter of one joined wall cannot silently break its joint',
    () {
      final a = special(
        'a',
        ArchitectWallSystemKind.roundLogs,
        Offset.zero,
        const Offset(2, 0),
      );
      final b = special(
        'b',
        ArchitectWallSystemKind.roundLogs,
        const Offset(2, 0),
        const Offset(2, 2),
      );
      expect(
        () => UpdateArchitectWall(
          storeyId: 's',
          wall: a.copyWith(thickness: .3),
        ).apply(project([a, b])),
        throwsArgumentError,
      );
      final controller = ArchitectCommandController(project([a, b]));
      addTearDown(controller.dispose);
      controller.execute(
        MoveArchitectElements(
          storeyId: 's',
          elementIds: {'a', 'b'},
          delta: const Offset(1, 2),
        ),
      );
      expect(controller.project.activeStorey.walls.first.system.isLog, isTrue);
      expect(
        ArchitectSpecialWallGeometry.logLayouts(
          controller.project.activeStorey.walls,
        )['a']!.to,
        closeTo(2.36, 1e-9),
      );
      controller.undo();
      expect(
        controller.project.activeStorey.walls.first.startPoint,
        Offset.zero,
      );
      controller.redo();
      expect(
        controller.project.activeStorey.walls.first.startPoint,
        const Offset(1, 2),
      );
    },
  );
  test(
    'log roof preset bears above the last course without a concrete ring beam',
    () {
      final wall = special(
        'a',
        ArchitectWallSystemKind.roundLogs,
        Offset.zero,
        const Offset(2, 0),
        height: 2.4,
      );
      final roof = ArchitectRoofPlane(
        id: 'r',
        storeyId: 's',
        points: const [
          Offset(-.5, -.5),
          Offset(2.5, -.5),
          Offset(2.5, 1.5),
          Offset(-.5, 1.5),
        ],
        assembly: ArchitectRoofAssembly.fromPreset(
          ArchitectRoofPreset.logTimber,
        ),
      );
      final p = project([wall]);
      final placed = ArchitectRoofPlacement.resolve(
        p.copyWith(
          storeys: [
            p.activeStorey.copyWith(roofs: [roof]),
          ],
        ),
      );
      final r = placed.activeStorey.roofs.single;
      expect(r.assembly.timber.hasRingBeam, isFalse);
      expect(
        r.undersideElevationAt(const Offset(1, 0)) -
            r.assembly.timber.wallPlateHeight,
        closeTo(2.4, 1e-9),
      );
      final components = ArchitectSpecialWallGeometry.build(
        placed.activeStorey,
        project: placed,
      );
      // Under the downhill side of the plate its underside is lower than 2.4.
      expect(
        components.any(
          (c) => inside(c.triangles, const Vector3(1, -.05, 2.395)),
        ),
        isFalse,
      );
    },
  );
  test(
    'published opening section retains casing and its settlement clearance',
    () {
      final wall =
          special(
            'a',
            ArchitectWallSystemKind.roundLogs,
            Offset.zero,
            const Offset(2, 0),
            height: 2.4,
          ).copyWith(
            system: const ArchitectWallSystem(
              kind: ArchitectWallSystemKind.roundLogs,
              settlementAllowance: .04,
            ),
            doors: [
              const ArchitectDoor(
                id: 'd',
                wallId: 'a',
                uuid: 'u',
                offsetRatio: .5,
                width: .8,
                height: 2,
              ),
            ],
          );
      final data = ArchitectBuildingSection.build(
        project([wall]),
        const ArchitectSection(
          id: 'cut',
          name: '',
          start: Offset(1, -.5),
          end: Offset(1, .5),
        ),
      );
      final wood = data.regions.where((r) => r.sourceId == 'a').toList();
      expect(wood.any((r) => r.path.contains(const Offset(.5, 2.025))), isTrue);
      expect(wood.any((r) => r.path.contains(const Offset(.5, 2.07))), isFalse);
    },
  );
  test(
    'column bindings place facade in front or between actual column faces and follow edits once',
    () {
      final panel = special(
        'panel',
        ArchitectWallSystemKind.sandwichPanels,
        const Offset(0, .25),
        const Offset(3, .25),
      );
      final floor = ArchitectStorey(
        id: 's',
        name: '',
        walls: [panel],
        columns: const [
          ArchitectColumn(
            id: 'c1',
            position: Offset.zero,
            width: .3,
            depth: .3,
          ),
          ArchitectColumn(
            id: 'c2',
            position: Offset(3, 0),
            width: .3,
            depth: .3,
          ),
        ],
      );
      final bound = ArchitectPanelSupports.synchronize(floor);
      expect(bound.walls.single.systemPlacement.columnIds, ['c1', 'c2']);
      expect(bound.walls.single.centerStart.dy, closeTo(.25, 1e-9));
      final moved = bound.copyWith(
        columns: [
          bound.columns.first.copyWith(position: const Offset(-.5, 0)),
          bound.columns.last,
        ],
      );
      final result = ArchitectPanelSupports.synchronize(moved, previous: bound);
      expect(result.walls.single.startPoint.dx, closeTo(-.5, 1e-9));
      final repeated = ArchitectPanelSupports.synchronize(
        result,
        previous: bound,
      );
      expect(repeated.walls.single.startPoint, result.walls.single.startPoint);
      final between = bound.copyWith(
        walls: [
          bound.walls.single.copyWith(
            system: panel.system.copyWith(
              panelMount: ArchitectPanelMount.betweenColumns,
            ),
          ),
        ],
      );
      final infill = ArchitectPanelSupports.synchronize(
        between,
        previous: bound,
      ).walls.single;
      expect(infill.startPoint.dx, closeTo(.15, 1e-9));
      expect(infill.endPoint.dx, closeTo(2.85, 1e-9));
      expect(infill.centerStart.dy, closeTo(.05, 1e-9));
      final deleted = ArchitectPanelSupports.synchronize(
        bound.copyWith(columns: [bound.columns.first]),
        previous: bound,
      );
      expect(deleted.walls.single.systemPlacement.columnIds, ['c1', 'c2']);
      expect(deleted.walls.single.startPoint, bound.walls.single.startPoint);
    },
  );
  test(
    'log opening casing occupies its own cut and leaves the configured settlement space',
    () {
      final wall =
          special(
            'a',
            ArchitectWallSystemKind.roundLogs,
            Offset.zero,
            const Offset(2, 0),
            height: 2.4,
          ).copyWith(
            system: const ArchitectWallSystem(
              kind: ArchitectWallSystemKind.roundLogs,
              settlementAllowance: .04,
            ),
            doors: [
              const ArchitectDoor(
                uuid: 'door-uuid',
                id: 'door',
                wallId: 'a',
                offsetRatio: .5,
                width: .8,
                height: 2,
              ),
            ],
          );
      final components = ArchitectSpecialWallGeometry.build(
        project([wall]).activeStorey,
      );
      expect(components.any((c) => c.id.startsWith('casing_')), isTrue);
      for (final p in [const Vector3(1, 0, 1), const Vector3(1, 0, 2.07)]) {
        expect(components.any((c) => inside(c.triangles, p)), isFalse);
      }
      expect(
        components.any((c) => inside(c.triangles, const Vector3(.575, 0, 1))),
        isTrue,
      );
      expect(
        components.any((c) => inside(c.triangles, const Vector3(1, 0, 2.025))),
        isTrue,
      );
    },
  );
  test(
    'closed solid difference preserves volume and creates the cut faces',
    () {
      List<Triangle3D> cube(double x, double size) =>
          ArchitectPathSolid.extrude(
            Path()..addRect(Rect.fromLTWH(x, 0, size, 1)),
            0,
            1,
            const Color(0xff000000),
          );
      final cut = ArchitectMeshBoolean.subtract(cube(0, 1), cube(.75, 1));
      expect(volume(cut), closeTo(.75, 1e-7));
      expect(inside(cut, const Vector3(.5, .5, .5)), isTrue);
      expect(inside(cut, const Vector3(.9, .5, .5)), isFalse);
    },
  );
  test(
    'old records remain layered; all new types round-trip without depth duplication',
    () {
      for (final type in ArchitectWallType.standardCatalog(
        includeSpecial: true,
      )) {
        final restored = ArchitectWallType.fromJson(type.toJson());
        expect(restored.totalThickness, closeTo(type.totalThickness, 1e-9));
        expect(restored.system.signature, type.system.signature);
      }
      final old =
          special(
              'a',
              ArchitectWallSystemKind.roundLogs,
              Offset.zero,
              const Offset(2, 0),
            ).toJson()
            ..remove('system')
            ..remove('systemPlacement');
      expect(
        ArchitectWall.fromJson(old).system.kind,
        ArchitectWallSystemKind.layered,
      );
    },
  );
  test(
    'diameter changes round profile and course pitch without flattening',
    () {
      final wall = special(
        'a',
        ArchitectWallSystemKind.roundLogs,
        Offset.zero,
        const Offset(2, 0),
      );
      final next = wall.copyWith(thickness: .32);
      next.validateGeometry();
      expect(next.layers.single.thickness, closeTo(.32, 1e-9));
      expect(next.system.pitch(next.thickness), closeTo(.288, 1e-9));
      final components = ArchitectSpecialWallGeometry.build(
        project([next]).activeStorey,
      );
      final full = components.firstWhere((c) => c.id == 'log_1');
      expect(full.bounds.sizeY, closeTo(.32, .0001));
      expect(full.bounds.max.z, closeTo(.288 + .16, .0001));
    },
  );
  test(
    'orthogonal courses alternate half a pitch and tails start at the outside face',
    () {
      final a = special(
        'a',
        ArchitectWallSystemKind.roundLogs,
        Offset.zero,
        const Offset(2, 0),
      );
      final b = special(
        'b',
        ArchitectWallSystemKind.roundLogs,
        const Offset(2, 0),
        const Offset(2, 2),
      );
      final layouts = ArchitectSpecialWallGeometry.logLayouts([b, a]);
      expect(layouts['b']!.phase - layouts['a']!.phase, .5);
      expect(layouts['a']!.to, closeTo(2 + .12 + .24, 1e-9));
      expect(layouts['b']!.from, closeTo(-.12 - .24, 1e-9));
      final components = ArchitectSpecialWallGeometry.build(
        project([a, b]).activeStorey,
      );
      expect(
        components.every(
          (c) => c.triangles.isNotEmpty && volume(c.triangles) > 0,
        ),
        isTrue,
      );
      // Sample the actual crossing: exactly one component may own each point.
      for (var x = 1.91; x < 2.12; x += .041) {
        for (var y = -.091; y < .12; y += .041) {
          for (var z = .023; z < .6; z += .071) {
            final point = Vector3(x, y, z);
            expect(
              components.where((c) => inside(c.triangles, point)).length,
              lessThanOrEqualTo(1),
              reason: 'Overlapping wood at $point',
            );
          }
        }
      }
    },
  );
  test(
    'log plans keep nominal diameter while physical sections keep round chords',
    () {
      final wall = special(
        'a',
        ArchitectWallSystemKind.roundLogs,
        Offset.zero,
        const Offset(2, 0),
      );
      final layers = ArchitectWallLayers.build(
        [wall],
        [],
        cutPlaneHeight: .216,
      );
      expect(layers.body.contains(const Offset(1, 0)), isTrue);
      expect(layers.body.getBounds().height, closeTo(.24, .002));
      final narrow = ArchitectWallLayers.build([wall], [], cutPlaneHeight: .31);
      expect(narrow.body.getBounds().height, closeTo(.24, .00001));
      final components = ArchitectSpecialWallGeometry.build(
        project([wall]).activeStorey,
      );
      final physical = components
          .map((c) => c.at(.31))
          .fold<Path>(
            Path(),
            (a, b) => Path.combine(PathOperation.union, a, b),
          );
      expect(physical.getBounds().height, lessThan(.24));
      expect(physical.getBounds().height, greaterThan(.1));
    },
  );
  test('split is a montage edit and does not create physical tails', () {
    final wall = special(
      'a',
      ArchitectWallSystemKind.roundLogs,
      Offset.zero,
      const Offset(2, 0),
    );
    final next = SplitArchitectWall(
      storeyId: 's',
      wallId: 'a',
      newWallId: 'b',
      ratio: .5,
    ).apply(project([wall]));
    final layouts = ArchitectSpecialWallGeometry.logLayouts(
      next.activeStorey.walls,
    );
    expect(layouts['a']!.phase, layouts['b']!.phase);
    expect(layouts['a']!.to, 1);
    expect(layouts['b']!.from, 0);
    expect(
      ArchitectWall.fromJson(
        next.activeStorey.walls.last.toJson(),
      ).system.isLog,
      isTrue,
    );
  });
  test(
    'automatic overshoot correction protects an intentional tail but detects a bad montage line',
    () {
      final a = special(
        'a',
        ArchitectWallSystemKind.roundLogs,
        Offset.zero,
        const Offset(2.36, 0),
      );
      final b = special(
        'b',
        ArchitectWallSystemKind.roundLogs,
        const Offset(2, 0),
        const Offset(2, 2),
      );
      expect(ArchitectWallOvershootDetector.detectForWall(a, [a, b]), isEmpty);
      final wrong = a.copyWith(endPoint: const Offset(2.18, 0));
      expect(
        ArchitectWallOvershootDetector.detectForWall(wrong, [wrong, b]),
        isNotEmpty,
      );
    },
  );
  test(
    'composition changes persist the construction system and 100+100 panel depth',
    () {
      final type = ArchitectWallType.standardCatalog(
        includeSpecial: true,
      ).firstWhere((t) => t.system.isPanel);
      final ordinary = const ArchitectWall(
        id: 'a',
        startPoint: Offset.zero,
        endPoint: Offset(2, 0),
      );
      final result = SetArchitectWallComposition(
        type: type,
        storeyId: 's',
        wallIds: {'a'},
      ).apply(project([ordinary]));
      final wall = result.activeStorey.walls.single;
      expect(wall.thickness, closeTo(.2, 1e-9));
      expect(wall.system.supportDepth, .1);
      expect(
        wall.resolvedLayers.fold<double>(0, (v, l) => v + l.thickness),
        closeTo(.1, 1e-9),
      );
    },
  );
  test(
    'frame has separate boards, steel and insulation with an actual cavity',
    () {
      final wall = special(
        'a',
        ArchitectWallSystemKind.studFrame,
        Offset.zero,
        const Offset(1.2, 0),
      );
      final components = ArchitectSpecialWallGeometry.build(
        project([wall]).activeStorey,
      );
      expect(
        components.map((c) => c.layer.material).toSet(),
        containsAll([
          ArchitectMaterial.plasterboard,
          ArchitectMaterial.steel,
          ArchitectMaterial.stoneWool,
        ]),
      );
      final steel = components
          .where((c) => c.layer.material == ArchitectMaterial.steel)
          .toList();
      expect(
        steel.fold<double>(0, (v, c) => v + volume(c.triangles)),
        lessThan(.01),
      );
      final section = ArchitectWallLayers.build([wall], [], cutPlaneHeight: .3);
      expect(section.body.contains(const Offset(.3, .025)), isFalse);
    },
  );
}
