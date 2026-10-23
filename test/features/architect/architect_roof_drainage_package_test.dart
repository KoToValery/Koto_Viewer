import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/architect/rendering/architect_roof_drainage_mesh.dart';
import 'package:kotoview/src/features/architect/services/architect_roof_drainage_geometry.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/cad_3d/models/mesh_3d.dart';
import 'package:kotoview/src/features/cad_3d/rendering/cad_3d_camera.dart';
import 'package:kotoview/src/features/cad_3d/rendering/cad_3d_mesh_painter.dart';
import 'package:kotoview/src/features/cad_3d/rendering/cad_3d_gpu_bindings.dart';
import 'architect_roof_drainage_test.dart' as fixture;

ArchitectProject packageProject() => ArchitectProject.fromJson(
  jsonDecode(
    File(
      'test/fixtures/bim_package_roof_drainage_corners.json',
    ).readAsStringSync(),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('gutter keeps its curved floor on both sides of an outlet', () {
    final project = fixture.drainageProject(),
        floor = project.activeStorey,
        roof = floor.roofs.single;
    final z =
        ArchitectRoofDrainageGeometry.gutterElevation(
          floor,
          roof,
          Offset.zero,
        ) -
        roof.drainage.gutterDepth;
    for (final x in [1.0, 3.0, 5.0]) {
      final section = ArchitectBuildingSection.build(
        project,
        ArchitectSection(id: 'test', start: Offset(x, -1), end: Offset(x, 2)),
      );
      final path = section.regions
          .where((r) => r.customFillColor?.toARGB32() == 0xffeeeeee)
          .single
          .path;
      expect(
        path.contains(Offset(.95, z + .0005)),
        isTrue,
        reason: 'Missing channel floor at $x',
      );
      expect(path.contains(Offset(.95, z + .04)), isFalse);
    }
  });

  test(
    'package corner outlet reaches a facade without moving off the gutter',
    () {
      final project = packageProject();
      final floor = project.storeys.last;
      final roof = floor.roofs.first;
      final pipe = roof.drainage.downpipes.single;
      final route = ArchitectRoofDrainageGeometry.route(
        project,
        floor,
        roof,
        pipe,
      );
      expect(route.status, ArchitectDownpipeStatus.ready);
      final (a, b) = ArchitectRoofDrainageGeometry.eaves(roof);
      final onEaves = a + (b - a) / (b - a).distance * pipe.offset;
      final expected =
          onEaves -
          roof.slopeDirection *
              ArchitectRoofDrainageGeometry.gutterOffset(roof);
      expect(
        (Offset(route.points.first.x, route.points.first.y) - expected)
            .distance,
        lessThan(1e-8),
      );
      expect(route.inward.dx.abs(), greaterThan(.1));
      expect(route.points.last.z, pipe.outletElevation);
      expect(route.angles, everyElement(closeTo(pipe.bendAngle, 1e-5)));
      for (final t in ArchitectRoofDrainageMesh.build(project, floor, roof)) {
        expect(t.area, greaterThan(1e-12));
        expect(
          [
            t.v0,
            t.v1,
            t.v2,
          ].every((p) => p.x.isFinite && p.y.isFinite && p.z.isFinite),
          isTrue,
        );
      }
    },
  );

  test(
    'package exposed eaves accept downpipes at both ends and the middle',
    () {
      final project = packageProject(), floor = project.storeys.last;
      for (final roof in floor.roofs) {
        final (start, end) = ArchitectRoofDrainageGeometry.eaves(roof);
        final axis = (end - start) / (end - start).distance;
        for (final (a, b) in ArchitectRoofDrainageGeometry.visibleEaves(
          project,
          floor,
          roof,
        )) {
          final length = (b - a).distance;
          if (length < .7) continue;
          for (final along in [.3, length / 2, length - .3]) {
            final onEaves = a + (b - a) / length * along;
            final offset =
                (onEaves - start).dx * axis.dx + (onEaves - start).dy * axis.dy;
            final pipe = ArchitectDownpipe(id: 'probe', offset: offset);
            final next = roof.copyWith(
              drainage: roof.drainage.copyWith(downpipes: [pipe]),
            );
            final route = ArchitectRoofDrainageGeometry.route(
              project,
              floor,
              next,
              pipe,
            );
            expect(
              route.status,
              ArchitectDownpipeStatus.ready,
              reason: '${roof.id}: $onEaves',
            );
          }
        }
      }
    },
  );

  test('gutter lips sit below the covering rather than below the rafters', () {
    final project = fixture.drainageProject(),
        floor = project.activeStorey,
        roof = floor.roofs.single;
    final geometry = ArchitectRoofDrainageGeometry.build(project, floor, roof);
    final eave = ArchitectRoofDrainageGeometry.eaves(roof).$1;
    expect(
      geometry.gutters.single.elevation,
      closeTo(floor.elevation + roof.topElevationAt(eave) - .04, 1e-8),
    );
    expect(
      geometry.routes.single.points.first.z,
      closeTo(
        geometry.gutters.single.elevation - roof.drainage.gutterDepth,
        1e-8,
      ),
    );
  });

  test('finished detailed roof covers the eaves and both verges', () {
    final project = fixture.drainageProject(), floor = project.activeStorey;
    final roof = floor.roofs.single.copyWith(
      drainage: const ArchitectRoofDrainage(),
    );
    final mesh = Architect3dBuilder.buildProjectMesh(
      project.copyWith(
        storeys: [
          floor.copyWith(walls: [], roofs: [roof]),
        ],
      ),
    );
    final cover = mesh.triangles.where(
      (t) => t.normal.z > .1 && t.color!.r > t.color!.g * 1.4,
    );
    for (final point in [
      const Offset(.02, .02),
      const Offset(5.98, .02),
      const Offset(5.98, 2),
      const Offset(5.98, 3.98),
    ]) {
      expect(
        cover.any(
          (t) =>
              (Path()..addPolygon([
                    Offset(t.v0.x, t.v0.y),
                    Offset(t.v1.x, t.v1.y),
                    Offset(t.v2.x, t.v2.y),
                  ], true))
                  .contains(point),
        ),
        isTrue,
        reason: 'Uncovered roof at $point',
      );
    }
  });

  test(
    'capture package and drainage details with the application 3D painter',
    () async {
      if (!const bool.fromEnvironment('ROOF_DRAINAGE_QA_CAPTURE')) return;
      final project = packageProject();
      final sources = <Triangle3D, String>{};
      final building = Architect3dBuilder.buildProjectMesh(
        project,
        sources: sources,
      );
      final roofIds = {
        for (final s in project.storeys)
          for (final roof in s.roofs) roof.id,
      };
      final roofTriangles = building.triangles
          .where((t) => roofIds.contains(sources[t]))
          .toList();
      for (final t in roofTriangles) {
        expect(
          [
            t.v0,
            t.v1,
            t.v2,
          ].every((v) => v.x.isFinite && v.y.isFinite && v.z.isFinite),
          isTrue,
          reason: 'Non-finite triangle: ${t.v0}, ${t.v1}, ${t.v2}',
        );
      }
      final mesh = Mesh3D(name: 'Package roofs', triangles: roofTriangles);
      await capture(mesh, 'roof-package.png', yaw: -.7, pitch: .72, zoom: 1.5);
      final sample = fixture.drainageProject();
      final roof = sample.activeStorey.roofs.single;
      final drainage = ArchitectRoofDrainageMesh.build(
        sample,
        sample.activeStorey,
        roof,
      );
      await capture(
        Mesh3D(
          name: 'Drainage detail',
          triangles: crop(
            drainage,
            const BoundingBox3D(
              min: Vector3(1.5, -.2, 6.4),
              max: Vector3(2.5, 1, 7.5),
            ),
          ),
        ),
        'gutter-outlet-detail.png',
        yaw: -.7,
        pitch: .55,
        zoom: 1.5,
      );
      await capture(
        Mesh3D(name: 'Drainage', triangles: drainage),
        'drainage.png',
        yaw: -.6,
        pitch: .1,
        zoom: 1.6,
      );
    },
  );
}

// Crop long gutter facets before a close camera moves through their far ends.
List<Triangle3D> crop(List<Triangle3D> triangles, BoundingBox3D box) {
  final result = <Triangle3D>[];
  for (final triangle in triangles) {
    var polygon = [triangle.v0, triangle.v1, triangle.v2];
    for (final distance in <double Function(Vector3)>[
      (p) => p.x - box.min.x,
      (p) => box.max.x - p.x,
      (p) => p.y - box.min.y,
      (p) => box.max.y - p.y,
      (p) => p.z - box.min.z,
      (p) => box.max.z - p.z,
    ]) {
      final next = <Vector3>[];
      for (var i = 0; i < polygon.length; i++) {
        final a = polygon[i],
            b = polygon[(i + 1) % polygon.length],
            da = distance(a),
            db = distance(b);
        if (da >= 0) next.add(a);
        if ((da >= 0) != (db >= 0)) next.add(a + (b - a) * (da / (da - db)));
      }
      polygon = next;
      if (polygon.isEmpty) break;
    }
    for (var i = 1; i + 1 < polygon.length; i++) {
      result.add(
        Triangle3D(
          v0: polygon.first,
          v1: polygon[i],
          v2: polygon[i + 1],
          color: triangle.color,
        ),
      );
    }
  }
  return result;
}

Future<void> capture(
  Mesh3D mesh,
  String name, {
  required double yaw,
  required double pitch,
  required double zoom,
}) async {
  const size = Size(1500, 1200);
  final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
  canvas.drawColor(const Color(0xfff5f5f7), BlendMode.src);
  final camera = Cad3DCamera(yaw: yaw, pitch: pitch, zoom: zoom);
  final renderer = Cad3DGpuRenderer();
  ui.Image? frame;
  if (renderer.setMesh(mesh)) {
    frame = await renderer.renderFrame(
      camera: camera,
      viewport: size,
      modelScale: 1200 * .55 / mesh.bounds.maxDimension,
    );
  }
  Cad3DMeshPainter(
    mesh: mesh,
    camera: camera,
    theme: Cad3DTheme.lightStudio,
    showGrid: false,
    gpuImage: frame,
  ).paint(canvas, size);
  final picture = recorder.endRecording(),
      image = await picture.toImage(size.width.toInt(), size.height.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('build/roof-drainage-qa/$name');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(data!.buffer.asUint8List());
  image.dispose();
  frame?.dispose();
  renderer.dispose();
  picture.dispose();
}
