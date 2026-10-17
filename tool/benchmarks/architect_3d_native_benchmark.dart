// CPU/native frame diagnostic, including image conversion. Not device FPS.
// flutter test --no-pub tool/benchmarks/architect_3d_native_benchmark.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/cad_3d/rendering/cad_3d_camera.dart';
import 'package:kotoview/src/features/cad_3d/rendering/cad_3d_gpu_bindings.dart';
import 'architect_3d_benchmark.dart' as fixture;

void main() {
  testWidgets('report cached native architectural frames', (tester) async {
    if (!Cad3DGpuBindings.instance.isAvailable) {
      debugPrint('ARCHITECT_NATIVE_BENCHMARK unavailable');
      return;
    }
    await tester.runAsync(() async {
      for (final floors in [1, 5, 20]) {
        final mesh = Architect3dBuilder.buildProjectMesh(
          fixture.benchmarkProject(floors, roof: true),
        );
        final renderer = Cad3DGpuRenderer();
        try {
          final uploadTimer = Stopwatch()..start();
          expect(renderer.setMesh(mesh), isTrue);
          uploadTimer.stop();
          final camera = Cad3DCamera();
          Future<void> frame(double pixelRatio) async {
            camera.yaw += .01;
            final image = await renderer.renderFrame(
              camera: camera,
              viewport: const Size(1200, 800),
              modelScale: 800 * .55 / mesh.bounds.maxDimension,
              pixelRatio: pixelRatio,
            );
            expect(image, isNotNull);
            image!.dispose();
          }

          for (final pixelRatio in [1.0, 384 / 1200]) {
            for (var i = 0; i < 3; i++) {
              await frame(pixelRatio);
            }
            final samples = <int>[];
            for (var i = 0; i < 20; i++) {
              final timer = Stopwatch()..start();
              await frame(pixelRatio);
              timer.stop();
              samples.add(timer.elapsedMicroseconds);
            }
            samples.sort();
            debugPrint(
              'ARCHITECT_NATIVE_BENCHMARK ${jsonEncode({'floors': floors, 'triangles': mesh.triangleCount, 'pixelRatio': pixelRatio, 'uploadMs': uploadTimer.elapsedMicroseconds / 1000, 'frameMedianMs': samples[10] / 1000, 'frameP95Ms': samples[18] / 1000})}',
            );
          }
        } finally {
          renderer.dispose();
        }
      }
    });
  });
}
