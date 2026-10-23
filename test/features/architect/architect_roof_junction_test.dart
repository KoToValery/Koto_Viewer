import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/architect/rendering/architect_path_solid.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_junctions.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/models/mesh_3d.dart';

List<ArchitectRoofPlane> tRoofs({
  double wingSlope = 30,
  double wingHeight = 3,
}) {
  ArchitectRoofPlane plane(String id, String group, List<Offset> points) =>
      ArchitectRoofPlane(
        id: id,
        roofGroupId: group,
        storeyId: 's',
        points: points,
        slopeDegrees: group == 'main' ? 30 : wingSlope,
        baseElevationOffset: group == 'main' ? 3 : wingHeight,
        eavesOverhang: 0,
      );
  return [
    plane('north', 'main', const [
      Offset(0, 0),
      Offset(12, 0),
      Offset(12, 3),
      Offset(0, 3),
    ]),
    plane('south', 'main', const [
      Offset(12, 6),
      Offset(0, 6),
      Offset(0, 3),
      Offset(12, 3),
    ]),
    plane('west', 'wing', const [
      Offset(4, 12),
      Offset(4, 2),
      Offset(6, 2),
      Offset(6, 12),
    ]),
    plane('east', 'wing', const [
      Offset(8, 2),
      Offset(8, 12),
      Offset(6, 12),
      Offset(6, 2),
    ]),
  ];
}

ArchitectProject tProject(List<ArchitectRoofPlane> roofs) => ArchitectProject(
  id: 'p',
  name: 'T roof',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  activeStoreyId: 's',
  storeys: [ArchitectStorey(id: 's', name: 'Roof', roofs: roofs)],
);

double area(Path path) =>
    ArchitectPathSolid.contours(path).fold(0.0, (sum, contour) {
      var value = 0.0;
      for (var i = 0; i < contour.length; i++) {
        final a = contour[i], b = contour[(i + 1) % contour.length];
        value += a.dx * b.dy - b.dx * a.dy;
      }
      return sum + value / 2;
    }).abs();

bool onBoundary(Path path, Offset p) {
  for (final contour in ArchitectPathSolid.contours(path)) {
    for (var i = 0; i < contour.length; i++) {
      final a = contour[i], d = contour[(i + 1) % contour.length] - a;
      final t = ((p - a).dx * d.dx + (p - a).dy * d.dy) / d.distanceSquared;
      if (t >= -1e-5 && t <= 1 + 1e-5 && (a + d * t - p).distance < 1e-5) {
        return true;
      }
    }
  }
  return false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'T gables form two exact valleys without overlapping or missing plan area',
    () {
      final roofs = tRoofs();
      final json = [for (final r in roofs) r.toJson()];
      final resolved = ArchitectRoofJunctions.resolve(roofs);
      expect(resolved.trimmed, containsAll(['south', 'west', 'east']));
      expect(area(resolved.footprints['south']!), closeTo(32, 1e-4));
      expect(area(resolved.footprints['west']!), closeTo(14, 1e-4));
      expect(
        resolved.footprints.values.map(area).reduce((a, b) => a + b),
        closeTo(96, 1e-4),
      );
      for (var i = 0; i < roofs.length; i++) {
        for (final other in roofs.skip(i + 1)) {
          expect(
            area(
              Path.combine(
                PathOperation.intersect,
                resolved.footprint(roofs[i]),
                resolved.footprint(other),
              ),
            ),
            lessThan(1e-5),
          );
        }
      }
      for (final p in [
        const Offset(4, 6),
        const Offset(6, 4),
        const Offset(8, 6),
      ]) {
        expect(onBoundary(resolved.footprints['south']!, p), isTrue);
      }
      expect([for (final r in roofs) r.toJson()], json);
      expect(
        resolved.footprints['south']!.contains(const Offset(5.8, 5.5)),
        isFalse,
      );
      expect(
        resolved.footprints['west']!.contains(const Offset(5.8, 5.5)),
        isTrue,
      );
    },
  );

  for (final slope in [20.0, 38.0]) {
    test(
      'different slopes ($slope) use real plane intersections and ignore creation order',
      () {
        final roofs = tRoofs(wingSlope: slope, wingHeight: 3.2);
        final forward = ArchitectRoofJunctions.resolve(roofs);
        final backward = ArchitectRoofJunctions.resolve(
          roofs.reversed.toList(),
        );
        for (final roof in roofs) {
          expect(
            area(
              Path.combine(
                PathOperation.xor,
                forward.footprint(roof),
                backward.footprint(roof),
              ),
            ),
            lessThan(1e-5),
          );
        }
        for (var x = .13; x < 12; x += .37) {
          for (var y = .17; y < 12; y += .41) {
            final p = Offset(x, y);
            final candidates = roofs.where((r) => r.containsPoint(p)).toList();
            if (candidates.isEmpty) continue;
            final visible = roofs
                .where((r) => forward.footprint(r).contains(p))
                .toList();
            expect(visible, hasLength(1));
            expect(
              visible.single.topElevationAt(p),
              closeTo(
                candidates.map((r) => r.topElevationAt(p)).reduce(math.max),
                1e-5,
              ),
            );
          }
        }
      },
    );
  }

  test(
    'separate height levels are not joined and coplanar duplicates have stable ownership',
    () {
      final roofs = tRoofs(wingHeight: 10);
      expect(ArchitectRoofJunctions.resolve(roofs).trimmed, isEmpty);
      final a = roofs.first,
          b = a.copyWith(id: 'duplicate', roofGroupId: 'other');
      final resolved = ArchitectRoofJunctions.resolve([a, b]);
      expect(
        resolved.footprints.values.map(area).reduce((a, b) => a + b),
        closeTo(area(Path()..addPolygon(a.points, true)), 1e-4),
      );
      final overlappingAssembly = a.copyWith(
        id: 'raised',
        roofGroupId: 'raised',
        baseElevationOffset: a.baseElevationOffset + .1,
      );
      final joined = ArchitectRoofJunctions.resolve([a, overlappingAssembly]);
      expect(joined.footprints[a.id]!.getBounds().isEmpty, isTrue);
      expect(area(joined.footprints['raised']!), closeTo(36, 1e-4));
    },
  );

  test(
    'section intervals follow the derived valleys while keeping the original slope datum',
    () {
      final project = tProject(tRoofs());
      final slices = ArchitectRoofGeometry.buildSectionSlices(
        storey: project.activeStorey,
        sectionLine: const ArchitectSection(
          id: 'cut',
          start: Offset(0, 5),
          end: Offset(12, 5),
        ),
      )..sort((a, b) => a.fromS.compareTo(b.fromS));
      expect(slices, hasLength(4));
      expect(slices.map((s) => s.fromS), [0, 5, 6, 7]);
      expect(slices.map((s) => s.toS), [5, 6, 7, 12]);
      final p = const Offset(5.8, 5.5);
      final wing = project.activeStorey.roofs.firstWhere((r) => r.id == 'west');
      expect(
        ArchitectRoofGeometry.roofUndersideZAt(project.activeStorey, p),
        closeTo(wing.undersideElevationAt(p), 1e-5),
      );
    },
  );

  for (final detailed in [false, true]) {
    test(
      '3D ${detailed ? 'framing' : 'shell'} stays inside the trimmed envelopes',
      () {
        final project = tProject(tRoofs());
        final resolved = ArchitectRoofJunctions.of(project.activeStorey);
        final sources = <Triangle3D, String>{};
        final mesh = Architect3dBuilder.buildProjectMesh(
          project,
          previewGeometry: detailed,
          sources: sources,
        );
        expect(mesh.triangles, isNotEmpty);
        for (final triangle in mesh.triangles) {
          final id = sources[triangle]!;
          final c = (triangle.v0 + triangle.v1 + triangle.v2) * (1 / 3);
          final p = Offset(c.x, c.y), footprint = resolved.footprints[id]!;
          expect(
            footprint.contains(p) || onBoundary(footprint, p),
            isTrue,
            reason: '$id at $p',
          );
        }
        if (!detailed) {
          final internalValleyFaces = mesh.triangles.where(
            (t) =>
                t.normal.z.abs() < 1e-7 &&
                [t.v0, t.v1, t.v2].every(
                  (v) =>
                      (v.x + v.y - 10).abs() < 1e-5 &&
                      v.x >= 4 - 1e-5 &&
                      v.x <= 6 + 1e-5,
                ),
          );
          expect(internalValleyFaces, isEmpty);
        }
      },
    );
  }

  test(
    'rotated roofs keep the same valleys and elevations away from the origin',
    () {
      final roofs = tRoofs();
      final angle = 31 * math.pi / 180;
      Offset transform(Offset p) => Offset(
        p.dx * math.cos(angle) - p.dy * math.sin(angle) + 19.37,
        p.dx * math.sin(angle) + p.dy * math.cos(angle) - 6.12,
      );
      final rotated = [
        for (final roof in roofs)
          roof.copyWith(points: roof.points.map(transform).toList()),
      ];
      final resolved = ArchitectRoofJunctions.resolve(rotated);
      expect(
        resolved.footprints.values.map(area).reduce((a, b) => a + b),
        closeTo(96, 1e-3),
      );
      for (var i = 0; i < roofs.length; i++) {
        final p = const Offset(5.8, 5.5);
        expect(
          rotated[i].topElevationAt(transform(p)),
          closeTo(roofs[i].topElevationAt(p), 1e-8),
        );
      }
      expect(
        onBoundary(
          resolved.footprints['south']!,
          transform(const Offset(6, 4)),
        ),
        isTrue,
      );
    },
  );

  test(
    'roof junctions use world elevation across storeys in plan, mesh and sections',
    () {
      final roofs = tRoofs();
      final lower = ArchitectStorey(
        id: 's',
        name: 'Main',
        roofs: roofs.take(2).toList(),
      );
      final upper = ArchitectStorey(
        id: 'upper',
        name: 'Wing',
        elevation: 3,
        roofs: [
          for (final roof in roofs.skip(2))
            roof.copyWith(storeyId: 'upper', baseElevationOffset: 0),
        ],
      );
      final project = tProject([]).copyWith(storeys: [lower, upper]);
      final joined = ArchitectRoofJunctions.of(lower, project: project);
      expect(area(joined.footprints['south']!), closeTo(32, 1e-4));
      expect(
        area(
          ArchitectRoofJunctions.of(
            upper,
            project: project,
          ).footprints['west']!,
        ),
        closeTo(14, 1e-4),
      );
      const cut = ArchitectSection(
        id: 'cut',
        start: Offset(0, 5),
        end: Offset(12, 5),
      );
      final slices = [
        ...ArchitectRoofGeometry.buildSectionSlices(
          storey: lower,
          project: project,
          sectionLine: cut,
        ),
        ...ArchitectRoofGeometry.buildSectionSlices(
          storey: upper,
          project: project,
          sectionLine: cut,
        ),
      ]..sort((a, b) => a.fromS.compareTo(b.fromS));
      expect(slices.map((s) => s.fromS), [0, 5, 6, 7]);
      final mesh = Architect3dBuilder.buildProjectMesh(
        project,
        previewGeometry: false,
      );
      expect(
        mesh.triangles.where(
          (t) =>
              t.normal.z.abs() < 1e-7 &&
              [t.v0, t.v1, t.v2].every(
                (v) =>
                    (v.x + v.y - 10).abs() < 1e-5 &&
                    v.x >= 4 - 1e-5 &&
                    v.x <= 6 + 1e-5,
              ),
        ),
        isEmpty,
      );
      final raised = project.copyWith(
        storeys: [lower, upper.copyWith(elevation: 12)],
      );
      expect(
        ArchitectRoofJunctions.of(lower, project: raised).trimmed,
        isEmpty,
      );
    },
  );

  test(
    'moving or deleting the intersecting roof restores the covered surface automatically',
    () {
      final roofs = tRoofs();
      final project = tProject(roofs);
      expect(
        ArchitectRoofJunctions.of(project.activeStorey).trimmed,
        isNotEmpty,
      );
      final changed = project.activeStorey.copyWith(
        roofs: roofs.take(2).toList(),
      );
      expect(ArchitectRoofJunctions.of(changed).trimmed, isEmpty);
      expect(
        area(ArchitectRoofJunctions.of(changed).footprints['south']!),
        closeTo(36, 1e-4),
      );
      // Roof properties are mutable in the legacy model; cached derived paths
      // must still refresh when a property changes without a list replacement.
      roofs[2].baseElevationOffset = 20;
      roofs[3].baseElevationOffset = 20;
      expect(ArchitectRoofJunctions.of(project.activeStorey).trimmed, isEmpty);
    },
  );
}
