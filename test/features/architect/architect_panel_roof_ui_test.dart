import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_roof.dart';
import 'package:kotoview/src/features/architect/models/architect_section.dart';
import 'package:kotoview/src/features/architect/models/architect_elevation.dart';
import 'package:kotoview/src/features/architect/widgets/architect_roof_layers_dialog.dart';
import 'package:kotoview/src/features/architect/services/architect_building_section.dart';
import 'package:kotoview/src/features/architect/services/architect_building_elevation.dart';
import 'package:kotoview/src/features/architect/rendering/architect_3d_builder.dart';
import 'package:kotoview/src/features/architect/rendering/architect_roof_painter_helper.dart';
import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';
import 'package:kotoview/src/features/cad_3d/rendering/cad_3d_camera.dart';
import 'architect_panel_roof_test.dart' as fixture;
import 'architect_elevation_ui_test.dart' as fonts;
import 'architect_special_wall_ui_test.dart' as image_qa;

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('PANEL_ROOF_QA')) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(
    () async => image_qa.save(name, await boundary.toImage(pixelRatio: 2)),
  );
}

Future<void> open(
  WidgetTester tester, {
  required GlobalKey key,
  String language = 'bg',
  bool dark = false,
  bool membrane = false,
  int tab = 1,
  required ValueChanged<ArchitectRoofLayersResult> save,
}) async {
  tester.view.physicalSize = dark ? const Size(390, 844) : const Size(320, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final p = fixture.panelRoofProject(membrane: membrane),
      r = p.activeStorey.roofs.single;
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'TestReadable',
          brightness: dark ? Brightness.dark : Brightness.light,
        ),
        locale: Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('Open'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ArchitectRoofLayersDialog(
                  initialAssembly: r.assembly,
                  initialSlopeDegrees: r.slopeDegrees,
                  initialEavesOverhang: r.eavesOverhang,
                  initialEavesCut: r.eavesCut,
                  initialBaseElevationOffset: r.baseElevationOffset,
                  initialAttachToWalls: r.attachToWalls,
                  initialDrainage: r.drainage,
                  project: p,
                  roof: r,
                  initialTab: tab,
                  onApply: save,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  setUpAll(() async {
    await fonts.loadQaFonts();
    await (FontLoader(
      'ArchitectNoto',
    )..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))).load();
  });
  for (final language in ['bg', 'en']) {
    for (final dark in [false, true]) {
      for (final membrane in [false, true]) {
        testWidgets(
          'panel roof phone editor $language dark=$dark membrane=$membrane saves geometry',
          (tester) async {
            ArchitectRoofLayersResult? result;
            final key = GlobalKey();
            await open(
              tester,
              key: key,
              language: language,
              dark: dark,
              membrane: membrane,
              save: (r) => result = r,
            );
            final thickness = find.descendant(
              of: find.byKey(const ValueKey('roof-panel-thickness')),
              matching: find.byType(TextFormField),
            );
            await tester.ensureVisible(thickness);
            await tester.enterText(thickness, '120');
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await capture(
              tester,
              key,
              'architect_panel_roof_${membrane ? "membrane" : "pitched"}_${language}_${dark ? "dark" : "light"}',
            );
            await tester.tap(find.byKey(const ValueKey('roof-layers-apply')));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(result, isNotNull);
            expect(result!.assembly.panels!.thickness, .12);
            expect(result!.assembly.panels!.membrane, membrane);
            expect(result!.changes, contains(ArchitectRoofSetting.assembly));
          },
        );
      }
    }
  }
  for (final language in ['bg', 'en']) {
    testWidgets(
      'internal gutter choice is localized and saved atomically $language',
      (tester) async {
        ArchitectRoofLayersResult? result;
        final key = GlobalKey();
        await open(
          tester,
          key: key,
          language: language,
          tab: 2,
          save: (r) => result = r,
        );
        final section = find.byKey(const ValueKey('roof-drainage-section'));
        await tester.ensureVisible(section);
        await tester.tap(section);
        await tester.pumpAndSettle();
        final position = find.byKey(
          const ValueKey('roof-gutter-position-external'),
        );
        await tester.ensureVisible(position);
        await tester.tap(position);
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(ArchitectRoofLayersDialog)),
            l = AppLocalizations.of(context)!;
        await tester.tap(find.text(l.roofGutterInternal).last);
        await tester.pumpAndSettle();
        await capture(tester, key, 'architect_panel_roof_internal_$language');
        await tester.tap(find.byKey(const ValueKey('roof-layers-apply')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(result!.drainage.position, ArchitectGutterPosition.internal);
        expect(result!.drainage.profile, ArchitectGutterProfile.box);
        expect(result!.changes, contains(ArchitectRoofSetting.gutterPosition));
      },
    );
  }
  testWidgets('invalid panel pitch remains editable and cannot be saved', (
    tester,
  ) async {
    var saved = false;
    await open(tester, key: GlobalKey(), tab: 0, save: (_) => saved = true);
    final slope = find.descendant(
      of: find.byKey(const ValueKey('roof-slope-input')),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(slope, '0');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('roof-layers-apply')));
    await tester.pumpAndSettle();
    expect(saved, isFalse);
    expect(find.byType(ArchitectRoofLayersDialog), findsOneWidget);
  });
  for (final internal in [false, true]) {
    for (final membrane in [false, true]) {
      testWidgets(
        'actual roof plan section elevation and 3D internal=$internal membrane=$membrane',
        (tester) async {
          final p = fixture.panelRoofProject(
            internal: internal,
            membrane: membrane,
            overhang: internal ? 0 : .5,
          );
          final timer = Stopwatch()..start();
          final section = ArchitectBuildingSection.build(
            p,
            const ArchitectSection(
              id: 's',
              start: Offset(2, -1),
              end: Offset(2, 5),
            ),
          );
          final facade = ArchitectBuildingElevation.build(
            p,
            const ArchitectElevation(
              id: 'e',
              start: Offset(-1, -2),
              end: Offset(7, -2),
            ),
          );
          final mesh = Architect3dBuilder.buildProjectMesh(p);
          debugPrint(
            'Panel roof QA: ${mesh.triangles.length} triangles, ${facade.faces.length} facade contours, ${timer.elapsedMilliseconds} ms',
          );
          expect(
            section.regions.where((r) => r.sourceId == 'roof'),
            isNotEmpty,
          );
          expect(facade.faces, isNotEmpty);
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
          if (!const bool.fromEnvironment('PANEL_ROOF_QA')) return;
          await tester.runAsync(() async {
            final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
            canvas.drawColor(Colors.white, BlendMode.src);
            void draw(Iterable<ui.Path> paths, Rect bounds, Rect box) {
              final scale =
                  math.min(
                    box.width / bounds.width,
                    box.height / bounds.height,
                  ) *
                  .9;
              canvas.save();
              canvas.translate(box.center.dx, box.center.dy);
              canvas.scale(scale, -scale);
              canvas.translate(-bounds.center.dx, -bounds.center.dy);
              for (final path in paths) {
                canvas.drawPath(path, Paint()..color = Colors.white);
                canvas.drawPath(
                  path,
                  Paint()
                    ..color = Colors.black
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = .8 / scale,
                );
              }
              canvas.restore();
            }

            draw(
              section.regions.map((r) => r.path),
              section.bounds,
              const Rect.fromLTWH(0, 260, 800, 330),
            );
            draw(
              facade.faces,
              facade.bounds,
              const Rect.fromLTWH(0, 590, 800, 310),
            );
            final bounds = p.activeStorey.roofs.single.bounds.inflate(.3),
                planScale = math.min(760 / bounds.width, 230 / bounds.height);
            canvas.save();
            canvas.translate(400, 130);
            canvas.scale(planScale, planScale);
            canvas.translate(-bounds.center.dx, -bounds.center.dy);
            ArchitectTextScope(
              p.document,
              'roof',
              100,
              planScale,
              publication: true,
            ).run(
              () => ArchitectRoofPainterHelper.paintRoofs(
                canvas: canvas,
                storey: p.activeStorey,
                project: p,
                scale: planScale,
                selectedIds: {},
              ),
            );
            canvas.restore();
            canvas.save();
            canvas.translate(800, 0);
            await image_qa.drawMesh(
              canvas,
              mesh,
              const Size(800, 900),
              Cad3DCamera(zoom: 1.1),
            );
            canvas.restore();
            final picture = recorder.endRecording();
            await image_qa.save(
              'architect_panel_roof_${membrane ? "membrane" : "pitched"}_${internal ? "internal" : "external"}',
              await picture.toImage(1600, 900),
            );
            picture.dispose();
          });
        },
      );
    }
  }
}
