import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/core/l10n/generated/app_localizations.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/rendering/architect_picture_cache.dart';
import 'package:kotoview/src/features/architect/rendering/architect_vector_scene.dart';
import 'package:kotoview/src/features/architect/services/architect_sheet_geometry.dart';
import 'package:kotoview/src/features/architect/widgets/architect_sheet_viewport.dart';

ArchitectVectorScene _scene({String label = 'Room'}) {
  final canvas = ArchitectVectorCanvas();
  canvas.drawRect(const Rect.fromLTWH(0, 0, 30, 20), Paint());
  canvas.text(
    label,
    const Offset(3, 3),
    const TextStyle(fontSize: 3),
    'room',
    ArchitectAnnotationRole.roomName,
  );
  return ArchitectVectorScene(List.unmodifiable(canvas.operations), 100);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'ArchitectNoto',
    )..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))).load();
  });

  test(
    'pictures reuse measured text and remain vector at arbitrary zoom',
    () async {
      final cache = ArchitectPictureCache();
      final scene = _scene();
      final text = scene.operations.whereType<ArchitectVectorText>().single;
      cache.beginFrame();
      final first = cache.obtain('source', () => scene);
      final bounds = text.bounds;
      expect(text.debugLayoutCount, 1);
      cache.endFrame();
      for (var i = 0; i < 12; i++) {
        cache.beginFrame();
        expect(
          identical(
            cache.obtain('source', () => throw StateError('rebuilt')),
            first,
          ),
          isTrue,
        );
        expect(text.bounds, bounds);
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)..scale(i + 1.0);
        canvas.drawPicture(first.picture);
        recorder.endRecording().dispose();
        cache.endFrame();
      }
      expect(cache.recordings, 1);
      expect(text.debugLayoutCount, 1);
      final image = await first.picture.toImage(90, 60);
      expect(image.width, 90);
      image.dispose();
      cache.dispose();
      expect(first.isDisposed, isTrue);
      cache.dispose();
    },
  );

  test('inactive LRU eviction never disposes a picture used by this frame', () {
    final cache = ArchitectPictureCache(maxInactiveBytes: 0);
    cache.beginFrame();
    final first = cache.obtain('first', _scene);
    cache.endFrame();
    expect(first.isDisposed, isFalse);
    cache.beginFrame();
    final second = cache.obtain('second', _scene);
    cache.endFrame();
    expect(first.isDisposed, isTrue);
    expect(second.isDisposed, isFalse);
    expect(cache.evictions, 1);
    expect(cache.inactiveBytes, 0);
    cache.dispose();
    expect(second.isDisposed, isTrue);
  });

  test('revision invalidation rebuilds while the old picture is released', () {
    final cache = ArchitectPictureCache();
    cache.beginFrame();
    final first = cache.obtain((1, 'view'), _scene);
    cache.endFrame();
    cache.clear();
    expect(first.isDisposed, isTrue);
    cache.beginFrame();
    final next = cache.obtain((2, 'view'), () => _scene(label: 'Changed'));
    expect(identical(first.picture, next.picture), isFalse);
    expect(cache.recordings, 2);
    cache.dispose();
  });

  testWidgets(
    'viewport culls offscreen placements and shares a source picture across frames',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final key = GlobalKey<ArchitectSheetViewportState>();
      final requested = <String>[];
      const first = ArchitectDrawingPlacement(
        id: 'first',
        drawingId: 'same',
        frame: Rect.fromLTWH(40, 40, 50, 40),
        anchor: Offset.zero,
        showTitle: false,
      );
      final second = first.copyWith(
        id: 'second',
        frame: const Rect.fromLTWH(120, 40, 60, 50),
      );
      final outside = first.copyWith(
        id: 'outside',
        drawingId: 'offscreen',
        frame: const Rect.fromLTWH(1200, 40, 50, 40),
      );
      final sheet = ArchitectSheet(
        id: 'sheet',
        placements: [first, second, outside],
      );
      Future<void> pump(Object revision) => tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ArchitectSheetViewport(
              key: key,
              sheet: sheet,
              contentRevision: revision,
              buildScene: (_) => const ArchitectVectorScene([], 1),
              buildPaper: (_) => const ArchitectVectorScene([], 1),
              buildContent: (place) {
                requested.add(place.drawingId);
                expect(place.frame.topLeft, Offset.zero);
                expect(place.anchor, Offset.zero);
                expect(place.rotation, 0);
                expect(place.crop, isNull);
                return _scene(label: place.drawingId);
              },
              onSelect: (_) {},
              onMove: (_) {},
              onOpenSource: (_) {},
              onPlace: (_) {},
              onCancelPlacement: () {},
              onCrop: (_) {},
              onCancelCrop: () {},
            ),
          ),
        ),
      );
      await pump(1);
      await tester.pumpAndSettle();
      expect(requested, ['same']);
      final originalRecordings = key.currentState!.debugPictureRecordings;
      key.currentState!.navigation.panBy(const Offset(20, 10));
      await tester.pumpAndSettle();
      expect(requested, ['same']);
      expect(key.currentState!.debugPictureRecordings, originalRecordings);
      await pump(2);
      await tester.pumpAndSettle();
      expect(requested, ['same', 'same']);
      key.currentState!.navigation.panBy(const Offset(-2000, 0));
      await tester.pumpAndSettle();
      expect(requested, contains('offscreen'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'retained layers match composed rotation, anchor, concave crop and title block',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(640, 480));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final boundaryKey = GlobalKey();
      final sheet = ArchitectSheet(
        id: 'visual',
        widthMm: 200,
        heightMm: 150,
        placements: [
          const ArchitectDrawingPlacement(
            id: 'rotated',
            drawingId: 'source',
            frame: Rect.fromLTWH(55, 45, 55, 40),
            anchor: Offset(.5, .4),
            rotation: 30,
            scale: 100,
            showTitle: false,
            crop: [
              Offset(0, 0),
              Offset(55, 0),
              Offset(55, 20),
              Offset(25, 20),
              Offset(25, 40),
              Offset(0, 40),
            ],
          ),
          const ArchitectDrawingPlacement(
            id: 'overlap',
            drawingId: 'source',
            frame: Rect.fromLTWH(140, 115, 60, 30),
            anchor: Offset.zero,
            scale: 100,
            showTitle: false,
          ),
          const ArchitectDrawingPlacement(
            id: 'staged',
            drawingId: 'source',
            frame: Rect.fromLTWH(-5, 10, 20, 15),
            anchor: Offset.zero,
            scale: 100,
            showTitle: false,
          ),
        ],
      );
      final source = ArchitectVectorCanvas()
        ..drawRect(
          const Rect.fromLTWH(-20, -10, 100, 70),
          Paint()..color = Colors.red,
        )
        ..drawRect(
          const Rect.fromLTWH(10, 5, 15, 10),
          Paint()..color = Colors.blue,
        );
      final sourceScene = ArchitectVectorScene(source.operations, 100);
      void background(ArchitectVectorCanvas canvas) {
        canvas.sources(const {}, 'sheet-paper');
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 200, 150),
          Paint()..color = Colors.white,
        );
      }

      void foreground(ArchitectVectorCanvas canvas) {
        canvas.sources(const {}, 'sheet-title-block');
        canvas.drawRect(
          const Rect.fromLTWH(150, 120, 35, 20),
          Paint()..color = Colors.black,
        );
      }

      ArchitectVectorScene content(ArchitectDrawingPlacement place) {
        final canvas = ArchitectVectorCanvas()
          ..translate(place.frame.left, place.frame.top)
          ..rotate(place.rotation * math.pi / 180)
          ..translate(
            -place.anchor.dx * 1000 / place.scale,
            -place.anchor.dy * 1000 / place.scale,
          );
        sourceScene.paint(canvas);
        return ArchitectVectorScene(canvas.operations, 1);
      }

      ArchitectVectorScene composed(ArchitectSheet sheet) {
        final canvas = ArchitectVectorCanvas();
        background(canvas);
        for (final place in sheet.placements) {
          canvas.save();
          canvas.clipPath(ArchitectSheetGeometry.clipPath(place));
          content(place).paint(canvas);
          canvas.restore();
        }
        foreground(canvas);
        return ArchitectVectorScene(canvas.operations, 1);
      }

      Future<List<int>> pixels(bool optimized) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: RepaintBoundary(
                key: boundaryKey,
                child: ArchitectSheetViewport(
                  key: ValueKey(optimized),
                  sheet: sheet,
                  buildScene: composed,
                  buildPaper: optimized
                      ? (_) {
                          final canvas = ArchitectVectorCanvas();
                          background(canvas);
                          foreground(canvas);
                          return ArchitectVectorScene(canvas.operations, 1);
                        }
                      : null,
                  buildContent: optimized ? content : null,
                  contentRevision: 1,
                  onSelect: (_) {},
                  onMove: (_) {},
                  onOpenSource: (_) {},
                  onPlace: (_) {},
                  onCancelPlacement: () {},
                  onCrop: (_) {},
                  onCancelCrop: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return (await tester.runAsync(() async {
          final image =
              await (boundaryKey.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final data = await image.toByteData();
          image.dispose();
          return data!.buffer.asUint8List();
        }))!;
      }

      final reference = await pixels(false), retained = await pixels(true);
      var different = 0;
      for (var i = 0; i < reference.length; i++) {
        if ((reference[i] - retained[i]).abs() > 8) different++;
      }
      // Nested display-list transforms may differ at anti-aliased path edges.
      expect(different / reference.length, lessThan(.001));
      expect(tester.takeException(), isNull);
    },
  );
}
