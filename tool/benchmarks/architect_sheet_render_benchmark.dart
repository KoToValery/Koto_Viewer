// CPU/display-list diagnostic, not an Android FPS claim:
// flutter test --no-pub tool/benchmarks/architect_sheet_render_benchmark.dart
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/rendering/architect_picture_cache.dart';
import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';
import 'package:kotoview/src/features/architect/services/architect_drawing_publisher.dart';
import 'package:kotoview/src/features/architect/services/architect_sheet_composer.dart';
import 'package:kotoview/src/features/architect/services/architect_sheet_geometry.dart';
import 'package:kotoview/src/features/architect/widgets/architect_sheet_viewport.dart';
import 'package:kotoview/src/features/bim_editing/interaction/bim_polygon_editor.dart';

Future<Map<String, double>> measureWidgetAction(
  Future<void> Function() action, {
  VoidCallback? onWarmed,
}) async {
  for (var i = 0; i < 3; i++) {
    await action();
  }
  onWarmed?.call();
  final samples = <int>[];
  for (var i = 0; i < 16; i++) {
    final timer = Stopwatch()..start();
    await action();
    samples.add(timer.elapsedMicroseconds);
  }
  samples.sort();
  return {
    'medianMs': samples[samples.length ~/ 2] / 1000,
    'p95Ms': samples[(samples.length * .95).ceil() - 1] / 1000,
  };
}

Map<String, double> measure(void Function() action) {
  for (var i = 0; i < 3; i++) {
    action();
  }
  final samples = <int>[];
  for (var i = 0; i < 24; i++) {
    final timer = Stopwatch()..start();
    action();
    samples.add(timer.elapsedMicroseconds);
  }
  samples.sort();
  return {
    'medianMs': samples[samples.length ~/ 2] / 1000,
    'p95Ms': samples[(samples.length * .95).ceil() - 1] / 1000,
  };
}

/// Replay the previous screen path, deliberately laying out text per frame.
void legacyPaint(ArchitectVectorScene scene, Canvas canvas) {
  for (final op in scene.operations) {
    canvas.save();
    if (op.clip != null) canvas.clipPath(op.clip!);
    if (op is ArchitectVectorText) {
      canvas.translate(op.position.dx, op.position.dy);
      canvas.rotate(op.rotation);
      final text = TextPainter(
        text: TextSpan(
          text: op.text,
          style: TextStyle(
            fontFamily: 'ArchitectNoto',
            fontSize: op.size,
            color: op.color,
            fontWeight: op.weight,
            fontStyle: op.fontStyle,
            decoration: op.decoration,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset.zero);
      text.dispose();
    } else {
      op.paint(canvas);
    }
    canvas.restore();
  }
}

void record(void Function(Canvas) paint) {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder)..scale(2));
  recorder.endRecording().dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('ArchitectNoto')
          ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/NotoSans-Bold.ttf')))
        .load();
  });
  test(
    'report attached Layout cold generation and warm display costs',
    () async {
      final project = ArchitectProject.fromJson(
        jsonDecode(
              File(
                'test/fixtures/architect_layout_two_views_2026_11_05.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>,
      );
      final l = lookupAppLocalizations(const Locale('bg'));
      final sourceSheet = project.document.sheets.single;
      final results = <Map<String, Object>>[];
      final sources = <Object, ArchitectVectorScene>{};
      for (final count in [1, 2, 4, 8]) {
        final sheet = sourceSheet.copyWith(
          placements: [
            for (var i = 0; i < count; i++)
              sourceSheet.placements[i % 2].copyWith(
                id: 'view-$i',
                number: '${i + 1}',
                frame: sourceSheet.placements[i % 2].frame.shift(
                  Offset((i ~/ 2) * 305, 0),
                ),
              ),
          ],
        );
        final cold = Stopwatch()..start();
        final scene = ArchitectSheetComposer.compose(
          project,
          sheet,
          l,
          allowMissing: true,
          previewOutsideSheet: true,
          drawingScenes: sources,
        );
        final cache = ArchitectPictureCache();
        cache.beginFrame();
        final picture = cache.obtain(sheet, () => scene);
        cache.endFrame();
        final coldMs = cold.elapsedMicroseconds / 1000;
        final legacy = measure(
          () => record((canvas) => legacyPaint(scene, canvas)),
        );
        final retained = measure(
          () => record((canvas) => canvas.drawPicture(picture.picture)),
        );
        results.add({
          'placements': count,
          'operations': scene.operations.length,
          'textOperations': scene.operations
              .whereType<ArchitectVectorText>()
              .length,
          'coldSceneAndPictureMs': coldMs,
          'pictureBytes': picture.bytes,
          'legacyPerFrame': legacy,
          'retainedPerFrame': retained,
          'medianSpeedup':
              legacy['medianMs']! / math.max(.000001, retained['medianMs']!),
        });
        cache.dispose();
      }
      final sourceTimer = Stopwatch()..start();
      final source = ArchitectDrawingPublisher.build(
        project,
        project.document.drawings.single,
        100,
        l,
      );
      final sourceMs = sourceTimer.elapsedMicroseconds / 1000;
      final output = {
        'kind': 'CPU display-list recording; not device UI/raster FrameTiming',
        'sourceOperations': source.operations.length,
        'warmSourceLookupMs': sourceMs,
        'results': results,
      };
      final folder = Directory('build/architect_layout_benchmark')
        ..createSync(recursive: true);
      File(
        '${folder.path}/render.json',
      ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(output));
      // ignore: avoid_print
      print('ARCHITECT_SHEET_BENCHMARK ${jsonEncode(output)}');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  testWidgets(
    'report fixture actions through the optimized viewport',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(960, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final project = ArchitectProject.fromJson(
        jsonDecode(
              File(
                'test/fixtures/architect_layout_two_views_2026_11_05.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>,
      );
      final l = lookupAppLocalizations(const Locale('bg'));
      final original = project.document.sheets.single;
      final results = <Map<String, Object>>[];
      for (final count in [1, 2, 4, 8]) {
        final placements = [
          for (var i = 0; i < count; i++)
            original.placements[i % 2].copyWith(
              id: 'view-$i',
              number: '${i + 1}',
              frame: original.placements[i % 2].frame.shift(
                Offset((i ~/ 2) * 305, 0),
              ),
            ),
        ];
        final complete = original.copyWith(placements: placements);
        var shown = original.copyWith(
          placements: placements.take(count - 1).toList(),
        );
        String? selected;
        var cropping = false;
        late StateSetter update;
        final key = GlobalKey<ArchitectSheetViewportState>();
        final sourceScenes = <Object, ArchitectVectorScene>{};
        var sourceBuilds = 0;
        ArchitectVectorScene compose(
          ArchitectSheet sheet, {
          Set<String> exclude = const {},
        }) => ArchitectSheetComposer.compose(
          project,
          sheet,
          l,
          allowMissing: true,
          previewOutsideSheet: true,
          excludePlacements: exclude,
          drawingScenes: sourceScenes,
        );
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('bg'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return ArchitectSheetViewport(
                    key: key,
                    sheet: shown,
                    buildScene: compose,
                    buildPaper: (sheet) => compose(
                      sheet,
                      exclude: sheet.placements.map((p) => p.id).toSet(),
                    ),
                    contentRevision: project,
                    paperRevision: project,
                    buildContent: (place) {
                      sourceBuilds++;
                      return ArchitectSheetComposer.placementContent(
                        project,
                        place,
                        l,
                        drawingScenes: sourceScenes,
                      );
                    },
                    selectedId: selected,
                    cropMode: cropping,
                    drawingLabel: (place) =>
                        '${place.number}  ${l.architectSheetPlan}  1:${place.scale}',
                    onSelect: (id) => update(() => selected = id),
                    onMove: (_) {},
                    onOpenSource: (_) {},
                    onPlace: (_) {},
                    onCancelPlacement: () {},
                    onCrop: (_) {},
                    onCancelCrop: () => update(() => cropping = false),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final state = key.currentState!;
        // Include every staged drawing in view, so 4/8 are not accidentally
        // benchmarks of the offscreen culling case alone.
        final bounds = placements.fold(
          Rect.fromLTWH(0, 0, shown.widthMm, shown.heightMm),
          (Rect bounds, place) => bounds.expandToInclude(place.frame),
        );
        final zoom = math.min(936 / bounds.width, 616 / bounds.height);
        state.transform.value = Matrix4.identity()
          ..translateByDouble(
            12 - bounds.left * zoom,
            12 - bounds.top * zoom,
            0,
            1,
          )
          ..scaleByDouble(zoom, zoom, 1, 1);
        await tester.pump();
        final addTimer = Stopwatch()..start();
        update(() => shown = complete);
        await tester.pump();
        final addMs = addTimer.elapsedMicroseconds / 1000;
        final recordingBaseline = state.debugPictureRecordings;
        final sourceBaseline = sourceBuilds;
        final first = placements.first;
        Offset global(Offset paper) =>
            tester.getTopLeft(
              find.byKey(const ValueKey('architect-sheet-viewport-input')),
            ) +
            state.paperToScreen(paper);
        final select = await measureWidgetAction(() async {
          // Synthetic tap timestamps are zero; a blank tap also clears the
          // double-click candidate before selecting the same drawing again.
          await tester.tapAt(global(Offset(shown.widthMm - 5, 5)));
          await tester.pump();
          await tester.tapAt(global(first.frame.center));
          await tester.pump(const Duration(milliseconds: 400));
          expect(selected, first.id);
        });
        expect(
          state.debugPictureRecordings,
          recordingBaseline,
          reason: 'select',
        );
        final drag = await measureWidgetAction(() async {
          final gesture = await tester.startGesture(global(first.frame.center));
          await gesture.moveBy(const Offset(10, 6));
          await tester.pump();
          await gesture.moveBy(const Offset(10, 6));
          await tester.pump();
          await gesture.up();
          await tester.pump();
        });
        expect(state.debugPictureRecordings, recordingBaseline, reason: 'drag');
        var zoomIn = true;
        final zoomAction = await measureWidgetAction(() async {
          const focal = Offset(480, 320);
          state.navigation.navigate(
            previousFocal: focal,
            focal: focal,
            scaleFactor: zoomIn ? 1.01 : 1 / 1.01,
          );
          zoomIn = !zoomIn;
          await tester.pump();
        });
        expect(state.debugPictureRecordings, recordingBaseline, reason: 'zoom');
        var cropWarmRecordings = recordingBaseline;
        final crop = await measureWidgetAction(() async {
          update(() => cropping = true);
          await tester.pump();
          final contour = ArchitectSheetGeometry.contour(first);
          final handle = BimPolygonEditor.offsetEdgeHandle(
            contour,
            2,
            state.pixelsPerMm,
            36,
          );
          final gesture = await tester.startGesture(global(handle));
          await gesture.moveBy(const Offset(0, -8));
          await tester.pump();
          await gesture.up();
          await tester.pump();
          update(() => cropping = false);
          await tester.pump();
        }, onWarmed: () => cropWarmRecordings = state.debugPictureRecordings);
        expect(sourceBuilds, sourceBaseline);
        expect(
          state.debugPictureRecordings,
          cropWarmRecordings,
          reason: 'warm crop',
        );
        expect(sourceBuilds, count == 1 ? 1 : 2);
        expect(tester.takeException(), isNull);
        results.add({
          'placements': count,
          'addOneDrawingMs': addMs,
          'select': select,
          'drag': drag,
          'zoom': zoomAction,
          'crop': crop,
          'sharedSourcePictures': sourceBuilds,
          'cropPreparationPictureRecordings':
              cropWarmRecordings - recordingBaseline,
          'warmAdditionalPictureRecordings':
              state.debugPictureRecordings - cropWarmRecordings,
          'cacheBytes': state.debugPictureBytes,
        });
      }
      final output = {
        'kind':
            'host Flutter widget CPU action duration; not Android UI/raster FrameTiming',
        'samplesPerWarmAction': 16,
        'results': results,
      };
      final folder = Directory('build/architect_layout_benchmark')
        ..createSync(recursive: true);
      File(
        '${folder.path}/viewport.json',
      ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(output));
      // ignore: avoid_print
      print('ARCHITECT_VIEWPORT_BENCHMARK ${jsonEncode(output)}');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
