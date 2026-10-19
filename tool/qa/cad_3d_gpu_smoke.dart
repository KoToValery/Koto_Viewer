// Real Windows plugin/texture smoke test (flutter_tester has no plugin host).
// flutter build windows --debug --target tool/qa/cad_3d_gpu_smoke.dart
// Run from repo root. Captures and report are written under build/cad-3d-qa.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion_flutter.dart' as gpu;
// ignore: implementation_imports
import 'package:thermion_flutter/src/platform/src/frame_scheduler.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/cad_3d/cad_3d_controller.dart';
import 'package:kotoview/src/features/cad_3d/rendering/cad_3d_mesh_painter.dart';
import 'package:kotoview/src/features/cad_3d/widgets/cad_3d_gpu_surface.dart';
import 'cad_3d_material_fixture.dart';

final output = Directory('build/cad-3d-qa')..createSync(recursive: true);
void report(Object value) => File(
  '${output.path}/gpu-smoke.json',
).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(value));

void main() {
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      Timer(const Duration(seconds: 90), () {
        report({'passed': false, 'error': 'GPU smoke timed out'});
        exit(2);
      });
      runApp(const MaterialApp(home: Scaffold(body: Smoke())));
    },
    (error, stack) {
      report({'passed': false, 'error': '$error', 'stack': '$stack'});
      exit(1);
    },
  );
}

class Smoke extends StatefulWidget {
  const Smoke({super.key});
  @override
  State<Smoke> createState() => _SmokeState();
}

class _SmokeState extends State<Smoke> {
  final controller = Cad3DController();
  final mesh = const bool.fromEnvironment('CAD_3D_MATERIAL_QA')
      ? materialFixture()
      : Architect3dBuilder.buildProjectMesh(
          ArchitectProject(
            id: 'gpu-qa',
            name: 'QA',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
            activeStoreyId: 's',
            storeys: const [
              ArchitectStorey(
                id: 's',
                name: '0',
                walls: [
                  ArchitectWall(
                    id: 'a',
                    startPoint: Offset.zero,
                    endPoint: Offset(8, 0),
                  ),
                  ArchitectWall(
                    id: 'b',
                    startPoint: Offset(8, 0),
                    endPoint: Offset(8, 5),
                  ),
                  ArchitectWall(
                    id: 'c',
                    startPoint: Offset(8, 5),
                    endPoint: Offset(0, 5),
                  ),
                  ArchitectWall(
                    id: 'd',
                    startPoint: Offset(0, 5),
                    endPoint: Offset.zero,
                  ),
                  ArchitectWall(
                    id: 'e',
                    startPoint: Offset(4, 0),
                    endPoint: Offset(4, 3),
                  ),
                ],
              ),
            ],
          ),
        );
  gpu.ThermionViewer? viewer;
  bool started = false;
  bool visible = true;
  Cad3DShadingMode mode = Cad3DShadingMode.smoothShaded;
  int cycle = 0;
  final captures = <String>[];

  Future<void> capture() async {
    if (started) return;
    started = true;
    await Future<void>.delayed(const Duration(seconds: 2));
    final v = viewer!;
    // Capture shares Filament's renderer with the native frame scheduler.
    // Pause it before the diagnostic begin/render/read/end sequence.
    gpu.ThermionFlutterPlugin.instance.pauseFrameScheduler();
    while (FrameScheduler.instance.isRendering) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    await (v.app as dynamic).drainRequestFrameHooks();
    await v.app.flush();
    final viewport = await v.view.getViewport();
    final images = await v.app.capture(
      v.app.renderManager.getAttachedSwapChains(v.view).single,
      view: v.view,
      captureRenderTarget: true,
      pixelDataType: gpu.PixelDataType.UBYTE,
    );
    gpu.ThermionFlutterPlugin.instance.resumeFrameScheduler();
    final pixels = images.single.$2;
    final width = viewport.width;
    final height = viewport.height;
    if (pixels.length != width * height * 4) {
      throw StateError('Unexpected capture size');
    }
    final unique = <int>{};
    for (var i = 0; i < pixels.length; i += 4) {
      unique.add((pixels[i] << 16) | (pixels[i + 1] << 8) | pixels[i + 2]);
    }
    if (unique.length < 50) {
      throw StateError('GPU capture appears empty: ${unique.length} colors');
    }
    if (const bool.fromEnvironment('CAD_3D_MATERIAL_QA') && cycle == 0) {
      var red = 0, green = 0, blue = 0;
      for (var i = 0; i < pixels.length; i += 4) {
        final r = pixels[i], g = pixels[i + 1], b = pixels[i + 2];
        if (r > g * 1.5 && r > b * 1.5) red++;
        if (g > r * 1.5 && g > b * 1.5) green++;
        if (b > r * 1.5 && b > g * 1.5) blue++;
      }
      if (red < 500 || green < 500 || blue < 500) {
        throw StateError('Texture quadrants missing: $red/$green/$blue');
      }
    }
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final image = await completer.future;
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final path = '${output.path}/filament-${mode.name}-$cycle.png';
    File(path).writeAsBytesSync(png!.buffer.asUint8List());
    image.dispose();
    captures.add(path);
    if (cycle < 3) {
      cycle++;
      controller.drag(const Offset(30, 10));
      setState(
        () => mode = [
          Cad3DShadingMode.smoothShaded,
          Cad3DShadingMode.cadShadedEdges,
          Cad3DShadingMode.wireframe,
          Cad3DShadingMode.xray,
        ][cycle],
      );
      started = false;
      unawaited(capture());
    } else if (cycle == 3) {
      cycle++;
      setState(() => visible = false);
      await Future<void>.delayed(const Duration(seconds: 1));
      started = false;
      setState(() {
        visible = true;
        mode = Cad3DShadingMode.smoothShaded;
      });
    } else {
      setState(() => visible = false);
      await Future<void>.delayed(const Duration(seconds: 1));
      if ((await v.app.getSwapChains()).isNotEmpty) {
        throw StateError('Swapchains survived viewport teardown');
      }
      // Drain the plugin scheduler before destroying the shared test engine;
      // native window/plugin teardown must happen only after its render thread.
      gpu.ThermionFlutterPlugin.instance.pauseFrameScheduler();
      while (FrameScheduler.instance.isRendering) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      await v.app.flush();
      await v.app.destroy();
      report({
        'passed': true,
        'triangles': mesh.triangles.length,
        'width': width,
        'height': height,
        'uniqueColors': unique.length,
        'captures': captures,
        'cycles': cycle + 1,
      });
      // Let the Flutter engine perform native window/plugin teardown. dart:io
      // exit can make a successful Windows run terminate as a native crash.
      await WidgetsBinding.instance.exitApplication(ui.AppExitType.required);
    }
  }

  @override
  Widget build(BuildContext context) => Align(
    child: SizedBox(
      width: cycle == 1
          ? 640
          : cycle == 3
          ? 360
          : double.infinity,
      height: cycle == 1 ? 400 : double.infinity,
      child: LayoutBuilder(
        builder: (_, constraints) {
          controller.viewport = constraints.biggest;
          controller.maxDimension = mesh.bounds.maxDimension;
          return visible
              ? Cad3DGpuSurface(
                  mesh: mesh,
                  controller: controller,
                  theme: Cad3DTheme.lightStudio,
                  shadingMode: mode,
                  showGrid: true,
                  active: true,
                  onViewerCreated: (value) => viewer = value,
                  onReady: (_) => unawaited(capture()),
                  onFailure: () {
                    report({'passed': false, 'error': 'GPU backend failed'});
                    exit(1);
                  },
                )
              : const SizedBox.expand();
        },
      ),
    ),
  );
}
