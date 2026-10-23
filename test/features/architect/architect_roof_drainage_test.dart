import 'package:flutter_test/flutter_test.dart';
import 'dart:math' as math;
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_elements.dart';
import 'package:kotoview/src/features/architect/rendering/architect_roof_drainage_mesh.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_drainage_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/architect/models/architect_elevation.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/services/architect_building_elevation.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/services/architect_element_tool.dart';
import 'package:kotoview/src/features/architect/services/architect_selection.dart';
import 'architect_roof_junction_test.dart' as junction;

const pipe = ArchitectDownpipe(id: 'pipe', offset: 2);
ArchitectProject drainageProject({bool bay = false, double angle = 45}) {
  final roof = ArchitectRoofPlane(
    id: 'roof',
    storeyId: 's',
    points: const [Offset(0, 0), Offset(6, 0), Offset(6, 4), Offset(0, 4)],
    baseElevationOffset: 7,
    eavesOverhang: 0,
    drainage: ArchitectRoofDrainage(
      showGutter: true,
      downpipes: [pipe.copyWith(bendAngle: angle)],
    ),
  );
  return ArchitectProject(
    id: 'p',
    name: 'Drainage',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    activeStoreyId: 's',
    storeys: [
      ArchitectStorey(
        id: 's',
        name: 'Roof',
        height: 7,
        roofs: [roof],
        walls: [
          const ArchitectWall(
            id: 'facade',
            startPoint: Offset(0, 1),
            endPoint: Offset(6, 1),
          ),
          if (bay)
            const ArchitectWall(
              id: 'bay',
              startPoint: Offset(0, .4),
              endPoint: Offset(6, .4),
              baseOffset: 3,
              height: 1.5,
              followStoreyHeight: false,
            ),
        ],
      ),
    ],
  );
}

ArchitectDownpipeRoute route(ArchitectProject p) =>
    ArchitectRoofDrainageGeometry.build(
      p,
      p.activeStorey,
      p.activeStorey.roofs.single,
    ).routes.single;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('projecting slabs are cleared even without an additional bay wall', () {
    final p = drainageProject(), s = p.activeStorey;
    final next = p.copyWith(
      storeys: [
        s.copyWith(
          slabs: const [
            ArchitectSlab(
              id: 'ledge',
              polygon: [
                Offset(0, .1),
                Offset(6, .1),
                Offset(6, 2),
                Offset(0, 2),
              ],
              coreTopOffset: 3,
              thickness: .2,
            ),
          ],
        ),
      ],
    );
    final result = route(next);
    expect(result.status, ArchitectDownpipeStatus.ready);
    for (var i = 0; i + 1 < result.points.length; i++) {
      final a = result.points[i], b = result.points[i + 1];
      for (var j = 0; j <= 100; j++) {
        final p = a + (b - a) * (j / 100);
        if (p.z > 2.675 && p.z < 3.125) {
          expect(p.y, lessThanOrEqualTo(-.025 + 1e-5));
        }
      }
    }
  });
  test('box gutter has a valid open outlet and catches the roof drip line', () {
    final p = drainageProject(), s = p.activeStorey;
    final roof = s.roofs.single.copyWith(
      drainage: s.roofs.single.drainage.copyWith(
        profile: ArchitectGutterProfile.box,
      ),
    );
    final geometry = ArchitectRoofDrainageGeometry.build(p, s, roof);
    expect(
      geometry.planPath(roof.drainage.gutterWidth).contains(const Offset(3, 0)),
      isTrue,
    );
    final mesh = ArchitectRoofDrainageMesh.build(p, s, roof);
    expect(mesh, isNotEmpty);
    for (final t in mesh) {
      expect((t.v1 - t.v0).cross(t.v2 - t.v0).length, greaterThan(1e-12));
    }
  });
  test('mirroring the roof preserves the physical outlet position', () {
    final tool = ArchitectElementTool(), s = drainageProject().activeStorey;
    addTearDown(tool.dispose);
    final (mirrored, _) = tool.mirrorElementById(
      s,
      'roof',
      origin: Offset.zero,
      direction: const Offset(0, 1),
    );
    final roof = mirrored.roofs.single;
    final (a, b) = ArchitectRoofDrainageGeometry.eaves(roof);
    final point =
        a + (b - a) / (b - a).distance * roof.drainage.downpipes.single.offset;
    expect((point - const Offset(-2, 0)).distance, lessThan(1e-6));
  });
  test('intersecting T roofs keep gutters only on the exposed low eaves', () {
    final roofs = [
      for (final r in junction.tRoofs())
        r.copyWith(drainage: const ArchitectRoofDrainage(showGutter: true)),
    ];
    final p = junction.tProject(roofs);
    var length = 0.0;
    for (final roof in roofs) {
      final geometry = ArchitectRoofDrainageGeometry.build(
        p,
        p.activeStorey,
        roof,
      );
      for (final gutter in geometry.gutters) {
        length += (gutter.end - gutter.start).distance;
        final shift =
            roof.slopeDirection *
            ArchitectRoofDrainageGeometry.gutterOffset(roof);
        expect(
          roof.signedDistanceFromEaves(gutter.start + shift),
          closeTo(0, 1e-5),
        );
        expect(
          roof.signedDistanceFromEaves(gutter.end + shift),
          closeTo(0, 1e-5),
        );
      }
    }
    expect(length, closeTo(32, 1e-4));
  });
  test('rotated facades retain the same route and valid outlet geometry', () {
    final p = drainageProject(bay: true), s = p.activeStorey;
    final original = route(p);
    const angle = .541052068;
    Offset transform(Offset p) => Offset(
      p.dx * math.cos(angle) - p.dy * math.sin(angle) + 19.37,
      p.dx * math.sin(angle) + p.dy * math.cos(angle) - 6.12,
    );
    final roof = s.roofs.single.copyWith(
      points: s.roofs.single.points.map(transform).toList(),
    );
    final rotated = p.copyWith(
      storeys: [
        s.copyWith(
          roofs: [roof],
          walls: [
            for (final w in s.walls)
              w.copyWith(
                startPoint: transform(w.startPoint),
                endPoint: transform(w.endPoint),
              ),
          ],
        ),
      ],
    );
    final result = route(rotated);
    expect(result.status, ArchitectDownpipeStatus.ready);
    expect(result.points.length, original.points.length);
    for (var i = 0; i < result.points.length; i++) {
      expect(
        (Offset(result.points[i].x, result.points[i].y) -
                transform(Offset(original.points[i].x, original.points[i].y)))
            .distance,
        lessThan(1e-5),
      );
      expect(result.points[i].z, closeTo(original.points[i].z, 1e-5));
    }
    for (final t in ArchitectRoofDrainageMesh.build(
      rotated,
      rotated.activeStorey,
      roof,
    )) {
      expect((t.v1 - t.v0).cross(t.v2 - t.v0).length, greaterThan(1e-12));
    }
  });
  test(
    'roof drainage is visible and selectable in facade and cut geometry',
    () {
      final p = drainageProject(bay: true);
      final elevation = ArchitectBuildingElevation.build(
        p,
        const ArchitectElevation(
          id: 'e',
          start: Offset(8, -1),
          end: Offset(8, 5),
        ),
      );
      expect(
        elevation.elementPaths['roof']!.getBounds().height,
        greaterThan(6),
      );
      final section = ArchitectBuildingSection.build(
        p,
        const ArchitectSection(
          id: 'cut',
          start: Offset(2, -1),
          end: Offset(2, 5),
        ),
      );
      final pipeRegions = section.regions.where(
        (r) => r.sourceId == 'roof' && r.customFillColor != null,
      );
      expect(pipeRegions, isNotEmpty);
      expect(pipeRegions.first.path.getBounds().height, greaterThan(6));
      final tool = ArchitectElementTool();
      expect(
        tool.hitTestElements(
          p.activeStorey,
          const Offset(2, -.05),
          100,
          annotationProject: p,
        ),
        contains('roof'),
      );
      expect(
        ArchitectSelection.outline(p, 'roof').contains(const Offset(2, -.05)),
        isTrue,
      );
      tool.dispose();
    },
  );
  test(
    'shallow gutters remain routable and excessive diameter is reported',
    () {
      final p = drainageProject(), s = p.activeStorey;
      final roof = s.roofs.single.copyWith(
        drainage: s.roofs.single.drainage.copyWith(gutterDepth: .04),
      );
      expect(
        ArchitectRoofDrainageGeometry.route(p, s, roof, pipe).status,
        ArchitectDownpipeStatus.ready,
      );
      expect(
        ArchitectRoofDrainageGeometry.route(
          p,
          s,
          roof,
          pipe.copyWith(diameter: .2),
        ).status,
        ArchitectDownpipeStatus.blocked,
      );
      expect(
        ArchitectRoofDrainageGeometry.route(
          p,
          s,
          roof,
          pipe.copyWith(offset: 0),
        ).status,
        ArchitectDownpipeStatus.blocked,
      );
    },
  );
  test(
    'legacy roofs stay unchanged; settings survive project serialization',
    () {
      final p = drainageProject();
      final restored = ArchitectProject.fromJson(p.toJson());
      expect(
        restored.activeStorey.roofs.single.drainage.toJson(),
        p.activeStorey.roofs.single.drainage.toJson(),
      );
      final json = p.activeStorey.roofs.single.toJson()..remove('drainage');
      expect(ArchitectRoofPlane.fromJson(json).drainage.showGutter, isFalse);
    },
  );
  test(
    'straight facade uses a short neck, standard elbows and a vertical drop',
    () {
      final r = route(drainageProject());
      expect(r.status, ArchitectDownpipeStatus.ready);
      expect(r.points.length, 4);
      expect(r.points.first.x, closeTo(2, 1e-5));
      expect(r.points.last.z, closeTo(.15, 1e-5));
      expect(r.points.last.y, closeTo(.75, 1e-5));
      for (final angle in r.angles) {
        expect(angle, closeTo(45, 1e-5));
      }
    },
  );
  for (final angle in [45.0, 67.5]) {
    test('bay is cleared above and below using $angle degree fittings', () {
      final r = route(drainageProject(bay: true, angle: angle));
      expect(r.status, ArchitectDownpipeStatus.ready);
      expect(r.points.length, greaterThanOrEqualTo(8));
      for (final a in r.angles) {
        expect(a, closeTo(angle, 1e-4));
      }
      for (var i = 0; i + 1 < r.points.length; i++) {
        final a = r.points[i], b = r.points[i + 1];
        expect(a.z, greaterThan(b.z));
        for (var j = 0; j <= 100; j++) {
          final p = a + (b - a) * (j / 100);
          if (p.z > 2.875 && p.z < 4.625) {
            expect(p.y, lessThanOrEqualTo(.15 + 1e-5));
          }
        }
      }
    });
  }
  test(
    'changing bay geometry recomputes the route without editing the pipe',
    () {
      final p = drainageProject(bay: true), original = route(drainageProject());
      expect(route(p).points.length, greaterThan(original.points.length));
      expect(
        p.activeStorey.roofs.single.drainage.downpipes.single.toJson(),
        pipe.toJson(),
      );
    },
  );
  test(
    'missing facade and invalid placement never produce a crossing pipe',
    () {
      final p = drainageProject(), s = p.activeStorey, r = s.roofs.single;
      expect(
        route(p.copyWith(storeys: [s.copyWith(walls: [])])).status,
        ArchitectDownpipeStatus.noFacade,
      );
      expect(
        ArchitectRoofDrainageGeometry.route(
          p,
          s,
          r,
          pipe.copyWith(offset: 20),
        ).status,
        ArchitectDownpipeStatus.outsideEaves,
      );
      expect(
        ArchitectRoofDrainageGeometry.route(
          p,
          s,
          r,
          pipe.copyWith(outletElevation: 20),
        ).status,
        ArchitectDownpipeStatus.noFacade,
      );
      expect(
        ArchitectRoofDrainageGeometry.route(
          p,
          s,
          r,
          pipe.copyWith(waypoints: const [Offset(2, 5)]),
        ).status,
        ArchitectDownpipeStatus.blocked,
      );
    },
  );
  test(
    'gutter and downpipe visibility are independent and the mesh belongs to its roof',
    () {
      final p = drainageProject(), s = p.activeStorey, roof = s.roofs.single;
      final all = ArchitectRoofDrainageMesh.build(p, s, roof);
      expect(all, isNotEmpty);
      for (final t in all) {
        expect(
          [
            t.v0,
            t.v1,
            t.v2,
          ].every((v) => v.x.isFinite && v.y.isFinite && v.z.isFinite),
          isTrue,
        );
        expect((t.v1 - t.v0).cross(t.v2 - t.v0).length, greaterThan(1e-12));
      }
      final pipeOnly = roof.copyWith(
        drainage: roof.drainage.copyWith(showGutter: false),
      );
      final gutterOnly = roof.copyWith(
        drainage: roof.drainage.copyWith(showDownpipes: false),
      );
      expect(ArchitectRoofDrainageMesh.build(p, s, pipeOnly), isNotEmpty);
      expect(ArchitectRoofDrainageMesh.build(p, s, gutterOnly), isNotEmpty);
      expect(
        ArchitectRoofDrainageMesh.build(
          p,
          s,
          roof.copyWith(
            drainage: roof.drainage.copyWith(
              showGutter: false,
              showDownpipes: false,
            ),
          ),
        ),
        isEmpty,
      );
      final sources = <dynamic, String>{};
      Architect3dBuilder.buildProjectMesh(p, sources: sources.cast());
      expect(sources.values.where((id) => id == roof.id), isNotEmpty);
    },
  );
  test('invalid pipe settings are rejected at command boundary', () {
    final p = drainageProject();
    final roof = p.activeStorey.roofs.single;
    expect(
      () => UpdateArchitectRoofPlane(
        storeyId: 's',
        roof: roof.copyWith(
          drainage: roof.drainage.copyWith(
            downpipes: [pipe.copyWith(diameter: double.nan)],
          ),
        ),
      ).apply(p),
      throwsArgumentError,
    );
  });
}
