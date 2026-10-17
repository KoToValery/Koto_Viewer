import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/cad_3d/cad_3d_controller.dart';
import 'package:kotoview/src/features/cad_3d/models/mesh_3d.dart';
import 'package:kotoview/src/features/cad_3d/rendering/cad_3d_backend.dart';
import 'package:kotoview/src/features/cad_3d/rendering/cad_3d_camera.dart';
import 'package:kotoview/src/features/cad_3d/rendering/cad_3d_feature_edges.dart';
import 'package:kotoview/src/features/cad_3d/rendering/cad_3d_gpu_bindings.dart';
import 'package:kotoview/src/features/cad_3d/rendering/cad_3d_mesh_painter.dart';
import 'package:kotoview/src/features/cad_3d/widgets/cad_3d_viewport.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall.dart';
import 'package:kotoview/src/features/architect/models/architect_zone.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/architect/widgets/architect_3d_viewport.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';
import 'package:kotoview/src/features/structural_designer/widgets/structural_3d_viewport.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/dxf_3d_viewer_screen.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/widgets/ifc_bim_sheet.dart';
import '../architect/architect_elevation_ui_test.dart' as qa;
import '../architect/architect_workspace_interaction_test.dart' as workspace;

ArchitectProject project() => ArchitectProject(
  id: 'p',
  name: 'House',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  activeStoreyId: 's',
  storeys: const [
    ArchitectStorey(
      id: 's',
      name: 'Ground',
      walls: [
        ArchitectWall(id: 'w', startPoint: Offset.zero, endPoint: Offset(8, 0)),
        ArchitectWall(
          id: 'w2',
          startPoint: Offset(8, 0),
          endPoint: Offset(8, 5),
        ),
        ArchitectWall(
          id: 'w3',
          startPoint: Offset(8, 5),
          endPoint: Offset(0, 5),
        ),
        ArchitectWall(
          id: 'w4',
          startPoint: Offset(0, 5),
          endPoint: Offset.zero,
        ),
      ],
    ),
  ],
);

Widget host(Widget child, {String language = 'en', GlobalKey? capture}) =>
    MaterialApp(
      locale: Locale(language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: RepaintBoundary(key: capture, child: child),
      ),
    );

Cad3DMeshPainter painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((p) => p.painter)
    .whereType<Cad3DMeshPainter>()
    .single;

class DeferredBackend extends Cad3DRenderBackend {
  int uploads = 0;
  bool disposed = false;
  final frames = <Completer<ui.Image?>>[];
  final cameras = <Cad3DCamera>[];
  final ratios = <double>[];
  @override
  bool get isAvailable => true;
  @override
  bool supports(Cad3DShadingMode mode) => mode == Cad3DShadingMode.smoothShaded;
  @override
  bool setMesh(Mesh3D mesh, {Color? color}) {
    uploads++;
    return true;
  }

  @override
  Future<ui.Image?> render({
    required Cad3DCamera camera,
    required Size viewport,
    required double modelScale,
    double pixelRatio = 1,
  }) {
    cameras.add(camera);
    ratios.add(pixelRatio);
    final result = Completer<ui.Image?>();
    frames.add(result);
    return result.future;
  }

  @override
  void dispose() => disposed = true;
}

ui.Image frame() {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(Colors.red, BlendMode.src);
  final picture = recorder.endRecording();
  final image = picture.toImageSync(4, 4);
  picture.dispose();
  return image;
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('CAD_3D_QA_CAPTURE')) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final output = File('build/cad-3d-qa/$name.png');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(qa.loadQaFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'walk uses explicit model units even for a building larger than 500m',
    () {
      final controller = Cad3DController(camera: Cad3DCamera(yaw: 0, pitch: 0));
      addTearDown(controller.dispose);
      controller.maxDimension = 1200;
      controller.unitsPerMeter = 1;
      controller.setMode(Cad3DInteractionMode.fly);
      controller.walk(const Offset(0, -.5), .1);
      expect(controller.camera.eyePosition.y, closeTo(.13, 1e-8));
      controller.unitsPerMeter = 1000;
      controller.walk(const Offset(0, -.5), .1);
      expect(controller.camera.eyePosition.y, closeTo(130.13, 1e-8));
      final snapshot = controller.snapshot();
      controller.drag(const Offset(30, 0));
      expect(snapshot.yaw, 0);
      expect(controller.camera.yaw, isNot(0));
      controller.reset();
      expect(controller.mode, Cad3DInteractionMode.orbit);
      expect(controller.camera.eyePosition, Vector3.zero);
    },
  );

  test(
    'CAD contours suppress a coplanar diagonal and retain a sharp corner',
    () {
      final a = Triangle3D(
        v0: Vector3.zero,
        v1: const Vector3(1, 0, 0),
        v2: const Vector3(1, 1, 0),
      );
      final b = Triangle3D(
        v0: Vector3.zero,
        v1: const Vector3(1, 1, 0),
        v2: const Vector3(0, 1, 0),
      );
      final triangles = [a, b];
      final masks = Cad3DFeatureEdges.masks(triangles, 1);
      expect(masks[a]! & 4, 0);
      expect(masks[b]! & 1, 0);
      expect(masks[a]! & 3, 3);
      expect(identical(masks, Cad3DFeatureEdges.masks(triangles, 1)), isTrue);
      final c = Triangle3D(
        v0: Vector3.zero,
        v1: const Vector3(1, 0, 0),
        v2: const Vector3(0, 0, 1),
      );
      expect(Cad3DFeatureEdges.masks([a, c], 1)[a]! & 1, 1);
    },
  );

  test(
    'preview plates use each storey footprint and concave zones keep their area',
    () {
      const zone = ArchitectZone(
        id: 'z',
        name: 'L',
        category: ArchitectZoneCategory.living,
        polygon: [
          Offset(0, 0),
          Offset(4, 0),
          Offset(4, 1),
          Offset(1, 1),
          Offset(1, 4),
          Offset(0, 4),
        ],
      );
      final source = project();
      final mesh = Architect3dBuilder.buildProjectMesh(
        source.copyWith(
          storeys: [
            source.activeStorey.copyWith(zones: [zone]),
            const ArchitectStorey(
              id: 'upper',
              name: 'Upper',
              elevation: 3,
              walls: [
                ArchitectWall(
                  id: 'short',
                  startPoint: Offset.zero,
                  endPoint: Offset(2, 0),
                ),
              ],
            ),
          ],
        ),
      );
      final zoneTris = mesh.triangles.where(
        (t) => t.color == zone.color.withValues(alpha: .85),
      );
      expect(
        zoneTris.fold<double>(0, (sum, t) => sum + t.area),
        closeTo(7, 1e-8),
      );
      final plate = mesh.triangles.where(
        (t) =>
            t.color == const Color(0xFFB0BEC5) &&
            t.v0.z >= 2.79 &&
            t.v1.z >= 2.79 &&
            t.v2.z >= 2.79,
      );
      expect(plate, isNotEmpty);
      final bounds = BoundingBox3D.fromPoints(
        plate.expand((t) => [t.v0, t.v1, t.v2]).toList(),
      );
      expect(bounds.max.x, 3);
      expect(bounds.max.y, 1);
    },
  );

  for (final language in ['en', 'bg']) {
    testWidgets('phone navigation caches architectural geometry ($language)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = Cad3DController();
      addTearDown(controller.dispose);
      var source = project();
      final imageKey = GlobalKey();
      Future<void> open() => tester.pumpWidget(
        host(
          Architect3dViewport(project: source, controller: controller),
          language: language,
          capture: imageKey,
        ),
      );
      await open();
      await tester.pumpAndSettle();
      final original = painter(tester).mesh;
      final input = find.byKey(const ValueKey('cad-3d-input'));
      final before = controller.camera.yaw;
      await tester.drag(input, const Offset(90, 15));
      await tester.pumpAndSettle();
      expect(controller.camera.yaw, isNot(before));
      expect(identical(painter(tester).mesh, original), isTrue);
      final point = tester.getCenter(input);
      await tester.sendEventToBinding(
        PointerScrollEvent(position: point, scrollDelta: const Offset(0, -80)),
      );
      await tester.pump();
      expect(controller.camera.zoom, greaterThan(1));
      await tester.tap(find.byKey(const ValueKey('cad-3d-pan')));
      await tester.pumpAndSettle();
      await tester.drag(input, const Offset(40, 20));
      await tester.pumpAndSettle();
      expect(controller.camera.panOffset.distance, greaterThan(0));
      await tester.tap(find.byKey(const ValueKey('cad-3d-fly')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cad-3d-joystick')), findsOneWidget);
      final joystick = find.byKey(const ValueKey('cad-3d-joystick'));
      final gesture = await tester.startGesture(tester.getCenter(joystick));
      await gesture.moveBy(const Offset(0, -35));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.camera.eyePosition.length, greaterThan(0));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      final position = controller.camera.eyePosition;
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.camera.eyePosition, same(position));
      await gesture.up();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cad-3d-reset')));
      await tester.pumpAndSettle();
      expect(controller.camera.panOffset, Offset.zero);
      expect(controller.camera.zoom, 1);
      expect(find.byKey(const ValueKey('cad-3d-joystick')), findsNothing);
      source = source.copyWith(name: 'Renamed');
      await open();
      await tester.pumpAndSettle();
      expect(identical(painter(tester).mesh, original), isTrue);
      source = source.copyWith(
        storeys: [source.activeStorey.copyWith(height: 4)],
      );
      await open();
      await tester.pumpAndSettle();
      expect(identical(painter(tester).mesh, original), isFalse);
      if (Cad3DNativeDepthBackend.available) {
        for (var i = 0; i < 10 && painter(tester).gpuImage == null; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 25)),
          );
          await tester.pumpAndSettle();
        }
        expect(painter(tester).gpuImage, isNotNull);
      }
      await capture(tester, imageKey, 'architect-$language');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'native requests reject stale frames and do not reupload on camera motion',
    (tester) async {
      final controller = Cad3DController();
      addTearDown(controller.dispose);
      final backend = DeferredBackend();
      final mesh = Architect3dBuilder.buildProjectMesh(project());
      Widget view({Cad3DShadingMode mode = Cad3DShadingMode.smoothShaded}) =>
          host(
            Cad3DViewport(
              mesh: mesh,
              controller: controller,
              preferNativeDepth: true,
              backend: backend,
              shadingMode: mode,
            ),
          );
      await tester.pumpWidget(view());
      await tester.pump();
      expect(backend.uploads, 1);
      expect(backend.frames.length, 1);
      final oldYaw = backend.cameras.first.yaw;
      controller.drag(const Offset(30, 10));
      await tester.pump();
      expect(backend.cameras.first.yaw, oldYaw);
      backend.frames.first.complete(frame());
      await tester.pump();
      await tester.pump();
      expect(painter(tester).gpuImage, isNull);
      expect(backend.frames.length, 2);
      final current = frame();
      backend.frames.last.complete(current);
      await tester.pumpAndSettle();
      expect(painter(tester).gpuImage, same(current));
      expect(backend.uploads, 1);
      await tester.pumpWidget(view(mode: Cad3DShadingMode.wireframe));
      await tester.pump();
      expect(painter(tester).gpuImage, isNull);
      expect(backend.frames.length, 2);
      await tester.pumpWidget(const SizedBox());
      expect(backend.disposed, isTrue);
    },
  );

  testWidgets(
    'structural highlighting shares navigation and preserves geometry on orbit',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = StructuralProject(
        storeys: [
          StoreyLevel(
            id: 's',
            name: 'Ground',
            elevation: 0,
            columns: const [
              StructuralColumn(
                id: 'c',
                center: Offset.zero,
                width: .3,
                height: .3,
              ),
            ],
          ),
          StoreyLevel(
            id: 's2',
            name: 'Upper',
            elevation: 3,
            columns: const [
              StructuralColumn(
                id: 'c2',
                center: Offset.zero,
                width: .3,
                height: .3,
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        host(Structural3dViewport(project: source, onExit: () {})),
      );
      await tester.pumpAndSettle();
      final original = painter(tester).mesh;
      await tester.drag(
        find.byKey(const ValueKey('cad-3d-input')),
        const Offset(60, 10),
      );
      await tester.pumpAndSettle();
      expect(painter(tester).mesh, same(original));
      await tester.ensureVisible(find.text('Upper'));
      await tester.tap(find.text('Upper'));
      await tester.pumpAndSettle();
      expect(painter(tester).mesh, isNot(same(original)));
      await tester.tap(find.byKey(const ValueKey('cad-3d-fly')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cad-3d-joystick')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'native scene ownership restores separate viewers and survives disposal',
    (tester) async {
      if (!Cad3DNativeDepthBackend.available) return;
      final red = Cad3DGpuRenderer(), blue = Cad3DGpuRenderer();
      addTearDown(red.dispose);
      addTearDown(blue.dispose);
      Mesh3D triangle(Color color) => Mesh3D(
        name: 'native',
        triangles: [
          Triangle3D(
            v0: const Vector3(-1, 0, -1),
            v1: const Vector3(1, 0, -1),
            v2: const Vector3(0, 0, 1),
            color: color,
            isDoubleSided: true,
          ),
        ],
      );
      expect(red.setMesh(triangle(Colors.red)), isTrue);
      expect(blue.setMesh(triangle(Colors.blue)), isTrue);
      Future<(int, int)> channels(Cad3DGpuRenderer renderer) async {
        final image = await tester.runAsync(
          () => renderer.renderFrame(
            camera: Cad3DCamera(yaw: 0, pitch: 0),
            viewport: const Size(64, 64),
            modelScale: 12,
          ),
        );
        expect(image, isNotNull);
        final bytes = await tester.runAsync(() => image!.toByteData());
        image!.dispose();
        var r = 0, b = 0;
        for (var i = 0; i < bytes!.lengthInBytes; i += 4) {
          r += bytes.getUint8(i);
          b += bytes.getUint8(i + 2);
        }
        return (r, b);
      }

      final first = await channels(red);
      final second = await channels(blue);
      expect(first.$1, greaterThan(first.$2));
      expect(second.$2, greaterThan(second.$1));
      red.dispose();
      final remaining = await channels(blue);
      expect(remaining.$2, greaterThan(remaining.$1));
    },
  );

  testWidgets(
    'native motion lowers pixel work, refines on release and falls back on failure',
    (tester) async {
      final controller = Cad3DController();
      addTearDown(controller.dispose);
      final backend = DeferredBackend();
      await tester.pumpWidget(
        host(
          Cad3DViewport(
            mesh: Architect3dBuilder.buildProjectMesh(project()),
            controller: controller,
            backend: backend,
            preferNativeDepth: true,
          ),
        ),
      );
      await tester.pump();
      backend.frames.single.complete(frame());
      await tester.pumpAndSettle();
      expect(backend.ratios.single, 1);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('cad-3d-input'))),
      );
      await gesture.moveBy(const Offset(60, 10));
      await tester.pump();
      expect(backend.ratios.last, lessThan(1));
      backend.frames.last.complete(frame());
      await tester.pumpAndSettle();
      await gesture.up();
      await tester.pump();
      expect(backend.ratios.last, 1);
      backend.frames.last.complete(null);
      await tester.pumpAndSettle();
      expect(painter(tester).gpuImage, isNull);
      final count = backend.frames.length;
      controller.drag(const Offset(20, 0));
      await tester.pumpAndSettle();
      expect(backend.frames.length, count);
      expect(backend.uploads, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('IFC file loading and filtering retain the common camera', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('cad-3d-ifc-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/model.ifc')
      ..writeAsStringSync(r'''
ISO-10303-21;
HEADER;
FILE_SCHEMA(('IFC2X3'));
ENDSEC;
DATA;
#1=IFCPROJECT('P',$,'Building',$,$,$,$,(),$);
#10=IFCBUILDINGSTOREY('S',$,'Ground',$,$,$,$,$,.ELEMENT.,0.0);
#20=IFCCARTESIANPOINT((0.,0.,0.));
#21=IFCDIRECTION((0.,0.,1.));
#22=IFCDIRECTION((1.,0.,0.));
#23=IFCAXIS2PLACEMENT3D(#20,#21,#22);
#24=IFCLOCALPLACEMENT($,#23);
#100=IFCWALL('W',$,'Wall',$,$,#24,#101,$);
#101=IFCPRODUCTDEFINITIONSHAPE($,$,(#102));
#102=IFCSHAPEREPRESENTATION($,'Body','SweptSolid',(#103));
#103=IFCEXTRUDEDAREASOLID(#104,#23,#21,3.);
#104=IFCRECTANGLEPROFILEDEF(.AREA.,$,#23,.3,6.);
#200=IFCRELCONTAINEDINSPATIALSTRUCTURE('R',$,$,$,(#100),#10);
ENDSEC;
END-ISO-10303-21;
''');
    await tester.pumpWidget(
      host(Dxf3DViewerScreen(filePath: file.path, addToRecent: false)),
    );
    for (
      var i = 0;
      i < 20 && find.byType(Cad3DViewport).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    final view = tester.widget<Cad3DViewport>(find.byType(Cad3DViewport));
    expect(view.mesh.groups, hasLength(1));
    await tester.drag(
      find.byKey(const ValueKey('cad-3d-input')),
      const Offset(40, 10),
    );
    await tester.pumpAndSettle();
    final yaw = view.controller.camera.yaw;
    expect(
      tester.widget<Cad3DViewport>(find.byType(Cad3DViewport)).mesh,
      same(view.mesh),
    );
    await tester.tap(find.byIcon(Icons.fullscreen_exit_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.apartment_rounded));
    await tester.pumpAndSettle();
    final sheet = tester.widget<IfcBimSheet>(find.byType(IfcBimSheet));
    sheet.ifcModel.toggleCategory('Wall', false);
    sheet.onFiltersChanged();
    await tester.pump();
    final filtered = tester.widget<Cad3DViewport>(find.byType(Cad3DViewport));
    expect(filtered.mesh.triangles, isEmpty);
    expect(filtered.controller, same(view.controller));
    expect(filtered.controller.camera.yaw, yaw);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'workspace uses common 3D view without adding camera movements to undo',
    (tester) async {
      final commands = workspace.commands();
      addTearDown(commands.dispose);
      await workspace.open(tester, commands);
      await tester.tap(find.byTooltip('3D Model'));
      await tester.pumpAndSettle();
      expect(find.byType(Architect3dViewport), findsOneWidget);
      final mesh = painter(tester).mesh;
      final undo = commands.undoCount;
      await tester.drag(
        find.byKey(const ValueKey('cad-3d-input')),
        const Offset(60, 10),
      );
      await tester.pumpAndSettle();
      expect(painter(tester).mesh, same(mesh));
      expect(commands.undoCount, undo);
      await tester.tap(find.byTooltip('2D Plan'));
      await tester.pumpAndSettle();
      expect(find.byType(Cad3DViewport), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
