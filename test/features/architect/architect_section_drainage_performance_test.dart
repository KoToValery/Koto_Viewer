import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/cad_3d/models/mesh_3d.dart' show Vector3;
import 'package:kotoview/src/features/architect/rendering/architect_mesh_section.dart';
import 'package:kotoview/src/features/architect/rendering/architect_roof_drainage_mesh.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_drainage_geometry.dart';

ArchitectProject attachedDrainageProject() => ArchitectProject.fromJson(
  jsonDecode(
    File(
      'test/fixtures/bim_package_sections_2026_10_28.json',
    ).readAsStringSync(),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'worker visibility and synchronous publication retain the same section geometry',
    () async {
      final project = attachedDrainageProject();
      for (final cut in [
        ...project.sections,
        project.sections.first.copyWith(
          steps: const [Offset(3, .5), Offset(7, -.3)],
          viewDepth: 8,
        ),
        project.sections.first.reversed(),
      ]) {
        final synchronous = ArchitectBuildingSection.build(
          project,
          cut,
        ).forView(cut);
        final asynchronous = (await ArchitectBuildingSection.buildAsync(
          project,
          cut,
        )).forView(cut);
        expect(asynchronous.bounds, synchronous.bounds);
        expect(asynchronous.regions.length, synchronous.regions.length);
        expect(
          asynchronous.background!.faces.length,
          synchronous.background!.faces.length,
        );
        expect(
          asynchronous.elementPaths.keys.toSet(),
          synchronous.elementPaths.keys.toSet(),
        );
        for (final id in synchronous.elementPaths.keys) {
          final a = asynchronous.elementPaths[id]!.getBounds();
          final b = synchronous.elementPaths[id]!.getBounds();
          expect(
            [a.left, a.top, a.right, a.bottom],
            orderedEquals([
              closeTo(b.left, 1e-5),
              closeTo(b.top, 1e-5),
              closeTo(b.right, 1e-5),
              closeTo(b.bottom, 1e-5),
            ]),
            reason: '${cut.name}, ${cut.steps.length} steps, source $id',
          );
        }
      }
    },
  );

  test(
    'actual package cut and projection selection contours are normalized and cached',
    () {
      final project = attachedDrainageProject();
      for (final cut in project.sections) {
        final watch = Stopwatch()..start();
        final data = ArchitectBuildingSection.build(project, cut).forView(cut);
        final builtMs = watch.elapsedMilliseconds;
        watch.reset();
        final paths = data.elementPaths;
        expect(
          watch.elapsedMilliseconds,
          lessThan(2000),
          reason:
              '${cut.name}: selection must not enter native PathOps on overlapping tube facets',
        );
        expect(identical(paths, data.elementPaths), isTrue);
        expect(
          paths.keys,
          containsAll(data.regions.map((r) => r.sourceId).toSet()),
        );
        for (final region in data.regions) {
          for (final metric in region.path.computeMetrics()) {
            final point = metric
                .getTangentForOffset(metric.length / 2)!
                .position;
            expect(
              paths[region.sourceId]!
                  .getBounds()
                  .inflate(.00001)
                  .contains(point),
              isTrue,
            );
          }
        }
        // Report the complete path, rather than benchmarking only build().
        // ignore: avoid_print
        print(
          '${cut.name}: build ${builtMs}ms, selectable paths ${watch.elapsedMilliseconds}ms',
        );
      }
    },
  );

  test('local outlet refinement keeps pipe shells closed and thin-walled', () {
    final project = attachedDrainageProject();
    for (final floor in project.storeys) {
      for (final roof in floor.roofs.where(
        (r) => r.drainage.downpipes.isNotEmpty,
      )) {
        final all = ArchitectRoofDrainageMesh.build(
          project,
          floor,
          roof,
          details: false,
        );
        expect(
          all.length,
          lessThan(2200),
          reason: 'Outlet samples must not propagate through the whole tube',
        );
        final pipe = ArchitectRoofDrainageMesh.build(
          project,
          floor,
          roof,
          includeGutters: false,
          details: false,
        );
        final edges = <String, int>{};
        String key(Vector3 p) =>
            '${(p.x * 1e6).round()}:${(p.y * 1e6).round()}:${(p.z * 1e6).round()}';
        for (final t in pipe) {
          expect(t.area, greaterThan(1e-12));
          final vertices = [t.v0, t.v1, t.v2];
          for (var i = 0; i < 3; i++) {
            final ends = [key(vertices[i]), key(vertices[(i + 1) % 3])]..sort();
            edges.update(ends.join('/'), (n) => n + 1, ifAbsent: () => 1);
          }
        }
        expect(
          edges.values,
          everyElement(2),
          reason:
              'The 64-to-16 profile transition must have no cracks or T-junctions',
        );
        final route = ArchitectRoofDrainageGeometry.build(
          project,
          floor,
          roof,
        ).routes.single;
        final end = route.points.last;
        final section = ArchitectMeshSection.horizontal(pipe, end.z + .2);
        final centre = Offset(end.x, end.y);
        expect(
          section.contains(centre),
          isFalse,
          reason: 'The bore must remain open',
        );
        final radius =
            (route.pipe.diameter / 2 -
                ArchitectRoofDrainageMesh.thickness / 2) *
            math.cos(math.pi / 16);
        final side = Offset(-route.inward.dy, route.inward.dx);
        final across =
            side * math.cos(math.pi / 16) +
            route.inward * math.sin(math.pi / 16);
        expect(
          section.contains(centre + across * radius),
          isTrue,
          reason: 'The sheet must retain its real wall thickness',
        );
      }
    }
  });

  test(
    'batched selection union preserves reflected winding and hollow contours',
    () {
      final hollow = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(const Rect.fromLTWH(0, 0, 2, 2))
        ..addRect(const Rect.fromLTWH(.2, .2, 1.6, 1.6));
      final reverse = Path()
        ..addPolygon(const [
          Offset(2, 0),
          Offset(2, 2),
          Offset(3, 2),
          Offset(3, 0),
        ], true);
      final union = ArchitectMeshSection.unionPaths([hollow, reverse]);
      expect(union.contains(const Offset(1, 1)), isFalse);
      expect(union.contains(const Offset(.1, 1)), isTrue);
      expect(union.contains(const Offset(2.5, 1)), isTrue);
    },
  );
}
