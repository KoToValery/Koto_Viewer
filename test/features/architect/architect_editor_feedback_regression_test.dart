import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_grid_axis.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_line_style.dart';
import 'package:kotoview/src/features/architect/rendering/architect_clearance_obstacles.dart';
import 'package:kotoview/src/features/architect/rendering/architect_dynamic_dimension_layout.dart';
import 'package:kotoview/src/features/architect/rendering/architect_line_pattern.dart';
import 'package:kotoview/src/features/architect/rendering/architect_grid_axis_painter_helper.dart';
import 'package:kotoview/src/features/architect/rendering/architect_line_presentation.dart';
import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';
import 'package:kotoview/src/features/architect/screens/architect_workspace_screen.dart';
import 'package:kotoview/src/features/architect/services/architect_command_controller.dart';
import 'package:kotoview/src/features/architect/services/architect_element_tool.dart';
import 'package:kotoview/src/features/architect/services/architect_selection_candidates.dart';
import 'package:kotoview/src/features/architect/services/architect_wall_overshoot_detector.dart';
import 'package:kotoview/src/features/architect/services/architect_wall_relations.dart';
import 'package:kotoview/src/features/architect/widgets/architect_dynamic_dimension_painter.dart';
import 'package:kotoview/src/features/architect/widgets/architect_wall_overshoot_banner.dart';

import 'architect_editing_test.dart' as editing;
import 'architect_workspace_interaction_test.dart' as workspace;

const capture = ValueKey('architect-feedback-capture');
bool get capturePreview =>
    Platform.environment['UPDATE_ARCHITECT_FEEDBACK_PREVIEW'] == 'true';
ArchitectProject package() => ArchitectProject.fromJson(
  jsonDecode(
    File(
      'test/fixtures/bim_package_dynamic_feedback_2026_11_04.json',
    ).readAsStringSync(),
  ),
);

Future<void> phone(
  WidgetTester tester,
  ArchitectCommandController model,
  String language,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepaintBoundary(
      key: capture,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Roboto'),
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ArchitectWorkspaceScreen(commandController: model),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> snapshot(WidgetTester tester, String name) async {
  if (!capturePreview) return;
  await tester.runAsync(() async {
    final image =
        await (tester.renderObject(find.byKey(capture))
                as RenderRepaintBoundary)
            .toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory('build/editor_feedback').createSync(recursive: true);
    File(
      'build/editor_feedback/$name.png',
    ).writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final family in ['Roboto', 'ArchitectNoto']) {
      await (FontLoader(family)
            ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/NotoSans-Bold.ttf')))
          .load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'attached project dimensions retain their real finished-face endpoints',
    () {
      final walls = package().activeStorey.walls;
      final wall = walls.firstWhere(
        (w) => (w.startPoint.dx - 3.584).abs() < 1e-8,
      );
      final gaps = ArchitectWallClearance.nearest(wall, walls)
        ..sort((a, b) => a.distance.compareTo(b.distance));
      expect(gaps.map((g) => g.distance), [
        closeTo(1.084, 1e-8),
        closeTo(5.916, 1e-8),
      ]);
      expect(gaps.first.start.dx, closeTo(3.459, 1e-8));
      expect(gaps.first.end.dx, closeTo(2.375, 1e-8));
      expect(gaps.last.end.dx, closeTo(9.625, 1e-8));
      final dim = ArchitectDynamicDimensionLayout.place(
        start: const Offset(160, 240),
        end: const Offset(900, 240),
        available: const Rect.fromLTRB(8, 64, 382, 600),
        viewport: const Rect.fromLTRB(8, 8, 382, 664),
        excluded: [const Rect.fromLTWH(180, 180, 100, 100)],
        intersectsWall: (_) => false,
      );
      expect(dim.measuredEnd, const Offset(900, 240));
      expect(dim.endOutside, isTrue);
      expect(dim.visibleLine!.$2.dx, 382);
      expect(dim.label.right, lessThanOrEqualTo(382));
      expect(
        dim.label.overlaps(const Rect.fromLTWH(180, 180, 100, 100)),
        isFalse,
      );
    },
  );

  test(
    'a displaced value retains a leader; obstacle queries handle edges and interiors',
    () {
      final dim = ArchitectDynamicDimensionLayout.place(
        start: const Offset(150, 160),
        end: const Offset(180, 160),
        available: const Rect.fromLTRB(8, 64, 382, 600),
        viewport: const Rect.fromLTRB(8, 8, 382, 664),
        excluded: [const Rect.fromLTWH(100, 64, 160, 260)],
        intersectsWall: (_) => false,
      );
      expect(dim.hasLeader, isTrue);
      final obstacles = ArchitectClearanceObstacles.forPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(const Rect.fromLTWH(0, 0, 8, 8))
          ..addRect(const Rect.fromLTWH(2, 2, 4, 4)),
      );
      expect(obstacles.intersects(const Rect.fromLTWH(3, 3, 1, 1)), isFalse);
      expect(obstacles.intersects(const Rect.fromLTWH(1, 3, 2, 1)), isTrue);
      expect(obstacles.intersects(const Rect.fromLTWH(-1, -1, 10, 10)), isTrue);
    },
  );

  test(
    'Trim preserves a connected return, detached end and hosted opening',
    () {
      final a = editing.wall('a', Offset.zero, const Offset(4.37, 0));
      final b = editing.wall('b', const Offset(4, 0), const Offset(4, 3));
      final tailReturn = editing.wall(
        'return',
        const Offset(4.37, 0),
        const Offset(4.37, -3),
      );
      expect(
        ArchitectWallOvershootDetector.detectForWall(a, [a, b]),
        isNotEmpty,
      );
      expect(
        ArchitectWallOvershootDetector.detectForWall(a, [a, b, tailReturn]),
        isEmpty,
      );
      final detached = a.copyWith(connectEnd: false);
      expect(
        ArchitectWallOvershootDetector.detectForWall(detached, [detached, b]),
        isEmpty,
      );
      final withDoor = a.addDoor(
        const ArchitectDoor(
          id: 'door',
          uuid: 'door',
          wallId: 'a',
          offsetRatio: .98,
          width: .12,
        ),
      );
      expect(
        ArchitectWallOvershootDetector.detectForWall(withDoor, [withDoor, b]),
        isEmpty,
      );
    },
  );

  test(
    'Trim revalidates stale suggestions and changes paired walls in one Undo',
    () {
      final a = editing.wall('a', Offset.zero, const Offset(4.15, 0));
      final b = editing.wall('b', const Offset(4, -.25), const Offset(4, 3));
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: '', walls: [a, b]),
      );
      addTearDown(model.dispose);
      final original = model.project;
      final os = ArchitectWallOvershootDetector.detectForWall(
        a,
        original.activeStorey.walls,
      ).single;
      final command = ArchitectWallOvershootDetector.createTrimCommands(
        storeyId: 's',
        overshoot: os,
      ).single;
      model.execute(command);
      expect(
        model.project.activeStorey.walls.first.endPoint,
        const Offset(4, 0),
      );
      expect(
        model.project.activeStorey.walls.last.startPoint,
        const Offset(4, 0),
      );
      expect(model.undoCount, 1);
      model.undo();
      expect(model.project, same(original));
      final returnWall = editing.wall(
        'return',
        const Offset(4.15, 0),
        const Offset(4.15, -3),
      );
      final changed = original.updateActiveStorey(
        original.activeStorey.copyWith(walls: [a, b, returnWall]),
      );
      expect(command.apply(changed), same(changed));
      final moved = original.updateActiveStorey(
        original.activeStorey.copyWith(
          walls: [
            a.copyWith(endPoint: const Offset(4.3, 0)),
            b,
          ],
        ),
      );
      expect(command.apply(moved), same(moved));
    },
  );

  test(
    'Trim retains the absolute position of an opening on the kept portion',
    () {
      final a = editing
          .wall('a', const Offset(4, -.37), const Offset(4, 4))
          .addDoor(
            const ArchitectDoor(
              id: 'd',
              uuid: 'd',
              wallId: 'a',
              offsetRatio: .6,
              width: .8,
            ),
          );
      final b = editing.wall('b', Offset.zero, const Offset(4, 0));
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: '', walls: [a, b]),
      );
      addTearDown(model.dispose);
      final os = ArchitectWallOvershootDetector.detectForWall(
        a,
        model.project.activeStorey.walls,
      ).single;
      model.execute(
        ArchitectWallOvershootDetector.createTrimCommands(
          storeyId: 's',
          overshoot: os,
        ).single,
      );
      final next = model.project.activeStorey.walls.first;
      expect(
        next.referencePointAt(next.doors.single.offsetRatio).dy,
        closeTo(a.referencePointAt(a.doors.single.offsetRatio).dy, 1e-8),
      );
    },
  );

  test(
    'screen dash dimensions are stable and clipping preserves contour phase',
    () {
      for (final zoom in [40.0, 200.0, 20000.0]) {
        expect(
          ArchitectLinePresentation.patternUnits(zoom, .1) * zoom,
          closeTo(96 / 25.4, 1e-8),
        );
        expect(
          ArchitectLinePresentation.stroke(zoom, .15) * zoom,
          closeTo(1.2, 1e-8),
        );
      }
      final project = package();
      ArchitectTextScope(
        project.document,
        'plan:storey_0',
        100,
        20000,
        publication: true,
      ).run(() {
        expect(ArchitectLinePresentation.patternUnits(20000, .1), .1);
        expect(ArchitectLinePresentation.stroke(20000, .15), .015);
      });
      const style = ArchitectLineStyle(
        id: 'test',
        name: 'Test',
        segmentsMm: [12, 4, 2, 4],
      );
      final source = Path()
        ..moveTo(0, 0)
        ..lineTo(100000, 0);
      final clipped = ArchitectLinePattern.path(
        source,
        style,
        1,
        visibleBounds: const Rect.fromLTRB(44001, -1, 44221, 1),
      );
      final lengths = clipped.computeMetrics().map((m) => m.length).toList();
      expect(lengths.length, lessThan(100));
      for (final metric in clipped.computeMetrics()) {
        final phase =
            metric.getTangentForOffset(metric.length / 2)!.position.dx % 22;
        expect(phase < 12.01 || (phase >= 15.99 && phase <= 18.01), isTrue);
      }
      expect(lengths.every((v) => v <= 12.01), isTrue);
    },
  );

  test(
    'axis pixels remain thin and dash-dot remains visible at maximum zoom',
    () async {
      final project = package().copyWith(
        gridAxes: const [
          StructuralGridAxis(
            id: 'axis',
            name: 'A',
            start: Offset(-10, 0),
            end: Offset(10, 0),
            bubbleAtStart: false,
            bubbleAtEnd: false,
          ),
        ],
      );
      for (final zoom in [40.0, 200.0, 20000.0]) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)..drawColor(Colors.white, BlendMode.src);
        canvas.clipRect(const Rect.fromLTWH(0, 0, 512, 96));
        canvas.translate(0, 48);
        canvas.scale(zoom);
        ArchitectTextScope(project.document, 'plan:storey_0', 100, zoom).run(
          () {
            ArchitectGridAxisPainterHelper.drawAxes(
              canvas: canvas,
              project: project,
              zoomScale: zoom,
            );
          },
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(512, 96);
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        bool red(int x, int y) {
          final at = (y * 512 + x) * 4;
          return data.getUint8(at) > data.getUint8(at + 1) + 30 &&
              data.getUint8(at + 1) < 210;
        }

        final rows = [
          for (var y = 0; y < 96; y++)
            if ([for (var x = 0; x < 512; x++) red(x, y)].any((v) => v)) y,
        ];
        expect(rows.length, inInclusiveRange(1, 3));
        var run = 0;
        final lengths = <int>[];
        for (var x = 0; x < 512; x++) {
          if (red(x, rows.first)) {
            run++;
          } else if (run > 0) {
            lengths.add(run);
            run = 0;
          }
        }
        expect(lengths.any((v) => v >= 11 && v <= 13), isTrue);
        expect(lengths.any((v) => v >= 1 && v <= 3), isTrue);
        if (zoom == 20000 && capturePreview) {
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          Directory('build/editor_feedback').createSync(recursive: true);
          File(
            'scratch/architect_axis_max_zoom.png',
          ).writeAsBytesSync(png!.buffer.asUint8List());
        }
        image.dispose();
        picture.dispose();
      }
    },
  );

  test(
    'curved point insertion follows the arc and preserves radius and connectivity',
    () {
      final wall = editing
          .wall('arc', const Offset(-2, 0), const Offset(2, 0))
          .copyWith(arcBulge: -.5);
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: '', walls: [wall]),
      );
      addTearDown(model.dispose);
      final pick = wall.referencePointAt(.3);
      model.execute(
        InsertArchitectElementPoint(
          storeyId: 's',
          elementId: wall.id,
          newElementId: 'second',
          point: pick,
        ),
      );
      final pieces = model.project.activeStorey.walls;
      expect(pieces.first.endPoint.dx, closeTo(pick.dx, 1e-8));
      expect(pieces.first.endPoint.dy, closeTo(pick.dy, 1e-8));
      expect(pieces.first.connectEnd && pieces.last.connectStart, isTrue);
      for (final piece in pieces) {
        expect(piece.arc!.radius, closeTo(wall.arc!.radius, 1e-8));
      }
      expect(
        pieces.fold<double>(0, (v, w) => v + w.length),
        closeTo(wall.length, 1e-8),
      );
    },
  );

  test(
    '100-wall scene reuses exact arc skins and selects inside/near caps analytically',
    () {
      final walls = [
        for (var i = 0; i < 100; i++)
          editing
              .wall(
                'wall$i',
                Offset((i % 10) * 10, (i ~/ 10) * 10),
                Offset((i % 10) * 10 + 4, (i ~/ 10) * 10),
              )
              .copyWith(arcBulge: i % 10 == 0 ? -.5 : 0),
      ];
      final model = editing.seeded(
        ArchitectStorey(id: 's', name: '', walls: walls),
      );
      addTearDown(model.dispose);
      final wall = model.project.activeStorey.walls.first;
      expect(wall.polygonCorners, same(wall.polygonCorners));
      expect(
        wall.copyWith(arcBulge: -.4).polygonCorners,
        isNot(same(wall.polygonCorners)),
      );
      final midpoint = wall.centerPointAt(.5);
      expect(ArchitectSelectionCandidates.wallHit(wall, midpoint, 0), isTrue);
      final cap = wall.centerPointAt(0) - wall.tangentAt(0) * .05;
      expect(ArchitectSelectionCandidates.wallHit(wall, cap, 0), isFalse);
      expect(ArchitectSelectionCandidates.wallHit(wall, cap, .06), isTrue);
      final tool = ArchitectElementTool();
      addTearDown(tool.dispose);
      final timings = <int>[];
      for (var i = 0; i < 20; i++) {
        final timer = Stopwatch()..start();
        final hits = ArchitectSelectionCandidates.planHits(
          model.project,
          tool,
          midpoint,
          100,
          allowed: (_) => true,
        );
        timer.stop();
        timings.add(timer.elapsedMicroseconds);
        expect(hits, contains(wall.id));
      }
      final sorted = timings.toList()..sort();
      expect(
        sorted[18],
        lessThan(100000),
        reason: 'Selection p95 on the test host must stay below 100 ms',
      );
      if (capturePreview) {
        Directory('build/editor_feedback').createSync(recursive: true);
        File(
          'build/editor_feedback/architect_curve_selection_profile.json',
        ).writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert({
            'runtime': 'Flutter tester',
            'platform': Platform.operatingSystem,
            'walls': 100,
            'curves': 10,
            'selections': timings.length,
            'firstMs': timings.first / 1000,
            'p95Ms': sorted[18] / 1000,
            'maxMs': sorted.last / 1000,
          }),
        );
      }
    },
  );

  testWidgets('Trim banner previews, cancels and confirms one atomic Undo', (
    tester,
  ) async {
    final model = editing.seeded(
      ArchitectStorey(
        id: 's',
        name: '',
        walls: [
          editing.wall('a', Offset.zero, const Offset(4.37, 0)),
          editing.wall('b', const Offset(4, 0), const Offset(4, 3)),
        ],
      ),
    );
    addTearDown(model.dispose);
    await phone(tester, model, 'en');
    final original = model.project;
    final banner = find.byType(ArchitectWallOvershootBanner);
    expect(banner, findsOneWidget);
    tester.widget<ArchitectWallOvershootBanner>(banner).onTrim();
    await tester.pumpAndSettle();
    expect(banner, findsNothing);
    expect(model.project, same(original));
    expect(model.canUndo, isFalse);
    expect(
      workspace.overlay(tester).project.activeStorey.walls.first.endPoint.dx,
      4,
    );
    await tester.tap(find.byKey(const ValueKey('architect-command-cancel')));
    await tester.pumpAndSettle();
    expect(model.project, same(original));
    expect(banner, findsOneWidget);
    tester.widget<ArchitectWallOvershootBanner>(banner).onTrim();
    await tester.pumpAndSettle();
    await editing.acceptGeometryCommand(tester);
    expect(model.project.activeStorey.walls.first.endPoint.dx, 4);
    expect(model.undoCount, 1);
    model.undo();
    await tester.pumpAndSettle();
    expect(model.project, same(original));
    expect(tester.takeException(), isNull);
  });

  for (final language in ['bg', 'en']) {
    testWidgets(
      'package phone dimensions show real witnesses and an offscreen continuation ($language)',
      (tester) async {
        final model = ArchitectCommandController(package());
        addTearDown(model.dispose);
        await phone(tester, model, language);
        workspace
            .camera(tester)
            .fit(const Rect.fromLTWH(1.7, 6, 4.5, 3.6), padding: 20);
        await tester.pumpAndSettle();
        await editing.ensureSelectionTool(tester);
        await workspace.wallTap(tester, const Offset(3.584, 7.8));
        await tester.pumpAndSettle();
        final paint =
            tester
                    .widget<CustomPaint>(
                      find.byKey(
                        const ValueKey('architect-dynamic-dimensions'),
                      ),
                    )
                    .painter!
                as ArchitectDynamicDimensionPainter;
        expect(paint.dimensions, hasLength(2));
        expect(paint.dimensions.any((d) => d.endOutside), isTrue);
        expect(
          paint.dimensions.every(
            (d) => (d.start - d.measuredStart).distance >= 23.9,
          ),
          isTrue,
        );
        await snapshot(tester, 'architect_dynamic_clearances_$language');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'New point grip survives repeated releases and commits only with check ($language)',
      (tester) async {
        final model = editing.seeded(
          ArchitectStorey(
            id: 's',
            name: '',
            walls: [editing.wall('wall', Offset.zero, const Offset(8, 0))],
          ),
        );
        addTearDown(model.dispose);
        await phone(tester, model, language);
        workspace.camera(tester).fit(const Rect.fromLTWH(-1, -3, 10, 6));
        await tester.pumpAndSettle();
        await editing.contextHold(tester, const Offset(2, 0));
        await tester.tap(
          find.byKey(const ValueKey('architect-radial-newPoint')),
        );
        await tester.pumpAndSettle();
        final original = model.project;
        for (final x in [3.0, 5.0, 4.0]) {
          final painter = workspace.overlay(tester);
          expect(painter.newPointCandidate, isNotNull);
          expect(
            painter.newPointHandleOffset!.distance,
            greaterThanOrEqualTo(48),
          );
          final origin = tester.getTopLeft(
            find.byKey(const ValueKey('architect-viewport-input')),
          );
          final grip =
              origin +
              workspace.camera(tester).toScreen(painter.newPointCandidate!) +
              painter.newPointHandleOffset!;
          final target =
              workspace.screen(tester, Offset(x, 0)) +
              painter.newPointHandleOffset!;
          final drag = await tester.startGesture(grip);
          await drag.moveTo(target);
          await tester.pump();
          // The preview must track the finger, rather than jump on release.
          expect(workspace.overlay(tester).newPointCandidate!.dx,
            closeTo(x, .01));
          expect(model.project, same(original));
          await drag.up();
          await tester.pumpAndSettle();
          expect(model.project, same(original));
          expect(
            workspace.overlay(tester).newPointCandidate!.dx,
            closeTo(x, .01),
          );
          expect(
            find.byKey(const ValueKey('architect-new-point-banner')),
            findsOneWidget,
          );
        }
        final camera = workspace.camera(tester);
        final focal = camera.size.center(Offset.zero);
        camera.navigate(previousFocal: focal, focal: focal, scaleFactor: 1.5);
        await tester.pumpAndSettle();
        expect(
          workspace.overlay(tester).newPointCandidate!.dx,
          closeTo(4, .01),
        );
        expect(
          workspace.overlay(tester).newPointHandleOffset!.distance,
          greaterThanOrEqualTo(48),
        );
        await tester.tapAt(workspace.screen(tester, Offset.zero));
        await tester.pumpAndSettle();
        expect(workspace.overlay(tester).newPointValid, isFalse);
        expect(
          tester
              .widget<IconButton>(
                find.byKey(const ValueKey('architect-command-apply')),
              )
              .onPressed,
          isNull,
        );
        expect(model.project, same(original));
        await tester.tapAt(workspace.screen(tester, const Offset(4, 0)));
        await tester.pumpAndSettle();
        await snapshot(tester, 'architect_new_point_$language');
        await editing.acceptGeometryCommand(tester);
        expect(model.project.activeStorey.walls, hasLength(2));
        expect(
          model.project.activeStorey.walls.first.endPoint.dx,
          closeTo(4, .01),
        );
        expect(model.undoCount, 1);
        model.undo();
        await tester.pumpAndSettle();
        expect(model.project, same(original));
        await editing.contextHold(tester, const Offset(2, 0));
        await tester.tap(
          find.byKey(const ValueKey('architect-radial-newPoint')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('architect-command-cancel')),
        );
        await tester.pumpAndSettle();
        expect(model.project, same(original));
        expect(model.canRedo, isTrue);
        model.redo();
        await tester.pumpAndSettle();
        expect(model.project.activeStorey.walls, hasLength(2));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
