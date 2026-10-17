// Run explicitly; this is a CPU diagnostic, not a device FPS benchmark:
// flutter test --no-pub tool/benchmarks/architect_3d_benchmark.dart
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/models/mesh_3d.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/rendering/cad_3d_camera.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/rendering/cad_3d_mesh_painter.dart';

ArchitectProject benchmarkProject(int floors, {bool roof = false}) {
  final date = DateTime.utc(2026, 10, 17);
  return ArchitectProject(
    id: 'benchmark',
    name: 'Synthetic diagnostic',
    createdAt: date,
    updatedAt: date,
    activeStoreyId: 's0',
    storeys: [
      for (var floor = 0; floor < floors; floor++)
        ArchitectStorey(
          id: 's$floor',
          name: '$floor',
          elevation: floor * 3.0,
          walls: [
            for (var room = 0; room < 10; room++)
              for (var edge = 0; edge < 4; edge++)
                ArchitectWall(
                  id: '$floor/$room/$edge',
                  startPoint: [
                    Offset(room * 5.0, 0),
                    Offset(room * 5.0 + 4, 0),
                    Offset(room * 5.0 + 4, 4),
                    Offset(room * 5.0, 4),
                  ][edge],
                  endPoint: [
                    Offset(room * 5.0 + 4, 0),
                    Offset(room * 5.0 + 4, 4),
                    Offset(room * 5.0, 4),
                    Offset(room * 5.0, 0),
                  ][edge],
                ),
          ],
          roofs: roof && floor == floors - 1
              ? [
                  ArchitectRoofPlane(
                    id: 'roof',
                    storeyId: 's$floor',
                    points: const [
                      Offset(0, 0),
                      Offset(49, 0),
                      Offset(49, 4),
                      Offset(0, 4),
                    ],
                    eavesEdgeIndex: 0,
                    baseElevationOffset: 2.8,
                    assembly: ArchitectRoofAssembly.fromPreset(
                      ArchitectRoofPreset.warmPitched,
                    ),
                  ),
                ]
              : const [],
        ),
    ],
  );
}

Map<String, double> _measure(void Function() action) {
  for (var i = 0; i < 5; i++) {
    action();
  }
  final samples = <int>[];
  for (var i = 0; i < 30; i++) {
    final timer = Stopwatch()..start();
    action();
    timer.stop();
    samples.add(timer.elapsedMicroseconds);
  }
  samples.sort();
  return {
    'medianMs': samples[samples.length ~/ 2] / 1000,
    'p95Ms': samples[(samples.length * .95).ceil() - 1] / 1000,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('report architectural build and Canvas recording cost', () {
    final originalDebugPrint = debugPrint;
    final subdivisionMessages = <String>{};
    // Capture the painter's existing subdivision diagnostics without timing I/O.
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null && message.contains('Subdivided')) {
        subdivisionMessages.add(
          message.replaceFirst(RegExp(r' in \d+ms$'), ''),
        );
      }
    };
    addTearDown(() => debugPrint = originalDebugPrint);
    final camera = Cad3DCamera();
    void paint(Mesh3D mesh) {
      final recorder = PictureRecorder();
      Cad3DMeshPainter(
        mesh: mesh,
        camera: camera,
      ).paint(Canvas(recorder), const Size(1200, 800));
      recorder.endRecording().dispose();
    }

    for (final floors in [1, 5, 20]) {
      for (final roof in [false, true]) {
        final project = benchmarkProject(floors, roof: roof);
        Mesh3D build() => Architect3dBuilder.buildProjectMesh(project);
        final mesh = build();
        // One fully visible group isolates the subdivision bypass. This does
        // not measure the benefit of a spatial index or element-level culling.
        final groupedMesh = Mesh3D(
          name: mesh.name,
          triangles: mesh.triangles,
          bounds: mesh.bounds,
          surfaceArea: mesh.surfaceArea,
          volume: mesh.volume,
          groups: [ElementMeshGroup(id: 'all', triangles: mesh.triangles)],
        );
        final result = {
          'floors': floors,
          'walls': floors * 40,
          'roof': roof,
          'triangles': mesh.triangleCount,
          'groups': mesh.groups?.length ?? 0,
          'build': _measure(() {
            build();
          }),
          'cachedMeshPaint': _measure(() => paint(mesh)),
          'groupedMeshPaint': _measure(() => paint(groupedMesh)),
          'rebuildAndPaint': _measure(() => paint(build())),
        };
        originalDebugPrint('ARCHITECT_3D_BENCHMARK ${jsonEncode(result)}');
      }
    }
    for (final message in subdivisionMessages) {
      originalDebugPrint(message);
    }
  });
}
