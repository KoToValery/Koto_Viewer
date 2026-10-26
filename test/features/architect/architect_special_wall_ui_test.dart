import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_wall_type.dart';
import 'package:kotoview/src/features/architect/models/architect_elevation.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/models/architect_column.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/rendering/architect_wall_layers.dart';
import 'package:kotoview/src/features/architect/services/architect_panel_supports.dart';
import 'package:kotoview/src/features/architect/services/architect_selection.dart';
import 'package:kotoview/src/features/architect/widgets/architect_element_properties_dialog.dart';
import 'package:kotoview/src/features/architect/rendering/architect_special_wall_geometry.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/cad_3d/rendering/cad_3d_mesh_painter.dart';
import 'package:kotoview/src/features/cad_3d/rendering/cad_3d_camera.dart';
import 'package:kotoview/src/features/cad_3d/rendering/cad_3d_backend.dart';
import 'package:kotoview/src/features/dxf_3d_viewer/models/mesh_3d.dart';
import 'package:kotoview/src/features/architect/services/architect_building_elevation.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/widgets/architect_wall_composition_editor.dart';
import 'architect_special_wall_systems_test.dart' as fixtures;
import 'architect_elevation_ui_test.dart' as qa;

Future<void> save(String name, ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  await File('docs/images/$name.png').writeAsBytes(data!.buffer.asUint8List());
  image.dispose();
}

Future<void> drawMesh(
  Canvas canvas,
  Mesh3D mesh,
  Size size,
  Cad3DCamera camera,
) async {
  final backend = Cad3DNativeDepthBackend();
  ui.Image? frame;
  try {
    if (backend.isAvailable && backend.setMesh(mesh)) {
      frame = await backend.render(
        camera: camera,
        viewport: size,
        modelScale:
            math.min(size.width, size.height) * .55 / mesh.bounds.maxDimension,
      );
    }
    Cad3DMeshPainter(
      mesh: mesh,
      camera: camera,
      theme: Cad3DTheme.lightStudio,
      showGrid: false,
      gpuImage: frame,
    ).paint(canvas, size);
  } finally {
    frame?.dispose();
    backend.dispose();
  }
}

void main() {
  setUpAll(qa.loadQaFonts);
  testWidgets('a deleted panel support can be removed and saved on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final wall = fixtures
        .special(
          'a',
          ArchitectWallSystemKind.sandwichPanels,
          Offset.zero,
          const Offset(3, 0),
          height: 2.4,
        )
        .copyWith(
          systemPlacement: const ArchitectWallSystemPlacement(
            columnIds: ['deleted'],
          ),
        );
    final p = fixtures.project([wall]);
    var saved = p;
    var applied = false;
    await tester.pumpWidget(
      qa.host(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('Open'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ArchitectElementPropertiesDialog(
                  project: p,
                  elementIds: {'a'},
                  onApply: (values, texts) {
                    saved = SetArchitectElementProperties(
                      storeyId: 's',
                      elementIds: {'a'},
                      values: values,
                      textValues: texts,
                    ).apply(p);
                    applied = true;
                    return true;
                  },
                ),
              ),
            ),
          ),
        ),
        'bg',
        GlobalKey(),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final supports = find.byKey(const ValueKey('wall-panel-supports'));
    await tester.ensureVisible(supports);
    await tester.tap(supports);
    await tester.pumpAndSettle();
    final remove = find.byKey(const ValueKey('wall-panel-remove-missing'));
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('architect-properties-save')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(applied, isTrue);
    expect(saved.activeStorey.walls.single.systemPlacement.columnIds, isEmpty);
  });
  for (final language in ['bg', 'en']) {
    for (final dark in [false, true]) {
      for (final kind in ArchitectWallSystemKind.values.where(
        (k) => k != ArchitectWallSystemKind.layered,
      )) {
        testWidgets(
          'special composition saves at ${dark ? 390 : 320}px ${dark ? "dark" : "light"}: $language $kind',
          (tester) async {
            tester.view.physicalSize = dark
                ? const Size(390, 844)
                : const Size(320, 800);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final capture = GlobalKey();
            final type = ArchitectWallType.standardCatalog(
              includeSpecial: true,
            ).firstWhere((t) => t.system.kind == kind);
            ArchitectWallType? saved;
            final p = fixtures.project([]);
            await tester.pumpWidget(
              RepaintBoundary(
                key: capture,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: ThemeData(
                    fontFamily: 'TestReadable',
                    useMaterial3: true,
                    brightness: dark ? Brightness.dark : Brightness.light,
                  ),
                  locale: Locale(language),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: Scaffold(
                    body: Builder(
                      builder: (context) => TextButton(
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) => ArchitectWallCompositionEditor(
                            project: p,
                            type: type,
                            onApply: (value, _, _) {
                              saved = value;
                              return true;
                            },
                          ),
                        ),
                        child: const Text('Open'),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.text('Open'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            if (kind == ArchitectWallSystemKind.roundLogs) {
              await tester.enterText(
                find.byKey(const ValueKey('wall-system-overlap')),
                '15',
              );
              await tester.pumpAndSettle();
            }
            if (const bool.fromEnvironment('SPECIAL_WALL_QA')) {
              final boundary =
                  capture.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              await tester.runAsync(() async {
                await save(
                  'architect_special_${kind.name}_$language${dark ? "_dark" : ""}',
                  await boundary.toImage(pixelRatio: 2),
                );
              });
            }
            await tester.tap(
              find.byKey(const ValueKey('wall-composition-save')),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(saved, isNotNull);
            expect(saved!.system.kind, kind);
            if (kind == ArchitectWallSystemKind.roundLogs) {
              expect(saved!.system.overlapPercent, 15);
            }
            expect(saved!.totalThickness, closeTo(type.totalThickness, 1e-9));
          },
        );
      }
    }
  }
  testWidgets(
    'log section and facade have real course contours without mesh facets',
    (tester) async {
      final a = fixtures.special(
        'a',
        ArchitectWallSystemKind.roundLogs,
        Offset.zero,
        const Offset(3, 0),
        height: 2.8,
      );
      final b = fixtures.special(
        'b',
        ArchitectWallSystemKind.roundLogs,
        const Offset(3, 0),
        const Offset(3, 2),
        height: 2.8,
      );
      final p = fixtures.project([a, b]);
      final timer = Stopwatch()..start();
      final initialMesh = Architect3dBuilder.buildProjectMesh(p);
      debugPrint(
        'Log QA: ${initialMesh.triangles.length} triangles in ${timer.elapsedMilliseconds} ms',
      );
      const view = ArchitectElevation(
        id: 'e',
        start: Offset(-1, -2),
        end: Offset(4, -2),
      );
      final facade = ArchitectBuildingElevation.build(p, view);
      debugPrint(
        'Log QA facade: ${facade.faces.length} contours in ${timer.elapsedMilliseconds} ms',
      );
      expect(facade.faces.length, lessThan(80));
      expect(facade.bounds.bottom, closeTo(2.8, .001));
      for (var z = .01; z < 2.8; z += .017) {
        expect(
          facade.faces.any((path) => path.contains(Offset(-.5, z))),
          isTrue,
          reason: 'The published facade must cover every course at z=$z',
        );
      }
      const cut = ArchitectSection(
        id: 's',
        name: 'A',
        start: Offset(1, -1),
        end: Offset(1, 1),
      );
      final section = ArchitectBuildingSection.build(p, cut);
      expect(section.regions.length, greaterThan(5));
      if (!const bool.fromEnvironment('SPECIAL_WALL_QA')) return;
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
        canvas.drawColor(Colors.white, BlendMode.src);
        void drawPaths(Iterable<ui.Path> paths, Rect box, Rect viewport) {
          final scale =
              math.min(
                viewport.width / box.width,
                viewport.height / box.height,
              ) *
              .85;
          canvas.save();
          canvas.translate(viewport.center.dx, viewport.center.dy);
          canvas.scale(scale, -scale);
          canvas.translate(-box.center.dx, -box.center.dy);
          for (final path in paths) {
            canvas.drawPath(path, Paint()..color = Colors.white);
            canvas.drawPath(
              path,
              Paint()
                ..color = Colors.black
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1 / scale,
            );
          }
          canvas.restore();
        }

        drawPaths(
          facade.faces,
          facade.bounds,
          const Rect.fromLTWH(0, 0, 1000, 650),
        );
        drawPaths(
          section.regions.map((r) => r.path),
          section.bounds,
          const Rect.fromLTWH(1000, 0, 450, 650),
        );
        final picture = recorder.endRecording();
        await save(
          'architect_log_wall_facade_section',
          await picture.toImage(1450, 650),
        );
        picture.dispose();
        final mesh = Architect3dBuilder.buildProjectMesh(p);
        final iso = ui.PictureRecorder(), paper = Canvas(iso);
        paper.drawColor(Colors.white, BlendMode.src);
        await drawMesh(
          paper,
          mesh,
          const Size(1100, 750),
          Cad3DCamera(zoom: 1.05),
        );
        final isoPicture = iso.endRecording();
        await save(
          'architect_log_wall_3d',
          await isoPicture.toImage(1100, 750),
        );
        isoPicture.dispose();
        final components = ArchitectSpecialWallGeometry.build(
          p.activeStorey,
          project: p,
        );
        expect(components, isNotEmpty);
      });
    },
  );
  for (final kind in [
    ArchitectWallSystemKind.studFrame,
    ArchitectWallSystemKind.sandwichPanels,
  ]) {
    testWidgets(
      '$kind publishes separate plan and section materials with an open door',
      (tester) async {
        final wall = fixtures
            .special('a', kind, Offset.zero, const Offset(3, 0), height: 2.4)
            .copyWith(
              doors: const [
                ArchitectDoor(
                  uuid: 'd',
                  id: 'd',
                  wallId: 'a',
                  offsetRatio: .5,
                  width: .8,
                  height: 2,
                ),
              ],
            );
        var p = fixtures.project([wall]);
        if (kind == ArchitectWallSystemKind.sandwichPanels) {
          p = ArchitectPanelSupports.resolve(
            p.copyWith(
              storeys: [
                p.activeStorey.copyWith(
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
                ),
              ],
            ),
          );
        }
        final plan = ArchitectWallLayers.forProject(p);
        expect(
          plan.materials.map((r) => r.layer.material).toSet().length,
          greaterThanOrEqualTo(
            kind == ArchitectWallSystemKind.studFrame ? 3 : 2,
          ),
        );
        expect(
          plan.body.contains(
            p.activeStorey.walls.single.centerStart + const Offset(1.5, 0),
          ),
          isFalse,
        );
        final section = ArchitectBuildingSection.build(
          p,
          const ArchitectSection(
            id: 's',
            name: 'A',
            start: Offset(2.5, -.5),
            end: Offset(2.5, .5),
          ),
        );
        expect(
          section.regions.where((r) => r.sourceId == 'a').length,
          greaterThanOrEqualTo(3),
        );
        final mesh = Architect3dBuilder.buildProjectMesh(p);
        expect(mesh.triangles, isNotEmpty);
        expect(
          mesh.triangles.every(
            (t) => [
              t.v0,
              t.v1,
              t.v2,
            ].every((v) => v.x.isFinite && v.y.isFinite && v.z.isFinite),
          ),
          isTrue,
        );
        if (!const bool.fromEnvironment('SPECIAL_WALL_QA')) return;
        await tester.runAsync(() async {
          final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
          canvas.drawColor(Colors.white, BlendMode.src);
          void draw(Iterable<Path> paths, Rect box, Rect viewport) {
            final scale =
                math.min(
                  viewport.width / box.width,
                  viewport.height / box.height,
                ) *
                .85;
            canvas.save();
            canvas.translate(viewport.center.dx, viewport.center.dy);
            canvas.scale(scale, -scale);
            canvas.translate(-box.center.dx, -box.center.dy);
            for (final path in paths) {
              canvas.drawPath(path, Paint()..color = Colors.white);
              canvas.drawPath(
                path,
                Paint()
                  ..color = Colors.black
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1 / scale,
              );
            }
            canvas.restore();
          }

          draw(
            plan.materials.map((r) => r.path),
            plan.body.getBounds(),
            const Rect.fromLTWH(0, 0, 850, 250),
          );
          draw(
            section.regions.map((r) => r.path),
            section.bounds,
            const Rect.fromLTWH(200, 270, 450, 580),
          );
          canvas.save();
          canvas.translate(850, 0);
          await drawMesh(
            canvas,
            mesh,
            const Size(750, 900),
            Cad3DCamera(zoom: .9),
          );
          canvas.restore();
          final picture = recorder.endRecording();
          await save(
            'architect_${kind.name}_plan_section_3d',
            await picture.toImage(1600, 900),
          );
          picture.dispose();
        });
      },
    );
  }
}
