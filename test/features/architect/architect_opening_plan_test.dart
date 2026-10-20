import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_door.dart';
import 'package:kotoview/src/features/architect/models/architect_fenestration_style.dart';
import 'package:kotoview/src/features/architect/models/architect_window.dart';

class _PlanCanvas implements Canvas {
  final lines = <(Offset, Offset, double)>[];
  final circles = <(Offset, double)>[];
  final texts = <(double, double, double)>[];
  final stack = <(double, double, Offset)>[];
  final textCorners = <List<Offset>>[];
  final paths = <Path>[];
  Offset origin = Offset.zero;
  Offset rotatePoint(Offset p) => Offset(
    p.dx * math.cos(angle) - p.dy * math.sin(angle),
    p.dx * math.sin(angle) + p.dy * math.cos(angle),
  );
  double textScale = 1;
  double angle = 0;

  @override
  void save() => stack.add((textScale, angle, origin));
  @override
  void restore() {
    final state = stack.removeLast();
    textScale = state.$1;
    angle = state.$2;
    origin = state.$3;
  }

  @override
  void translate(double x, double y) =>
      origin += rotatePoint(Offset(x, y) * textScale);
  @override
  void drawPath(Path path, Paint paint) => paths.add(path);
  @override
  void scale(double sx, [double? sy]) => textScale *= sx;
  @override
  void rotate(double radians) => angle += radians;
  @override
  void drawLine(Offset a, Offset b, Paint paint) =>
      lines.add((a, b, paint.strokeWidth));
  @override
  void drawCircle(Offset center, double radius, Paint paint) =>
      circles.add((center, radius));
  @override
  void drawParagraph(ui.Paragraph paragraph, Offset offset) {
    texts.add((
      paragraph.maxIntrinsicWidth * textScale,
      paragraph.height * textScale,
      angle,
    ));
    final rect = Rect.fromLTWH(
      offset.dx,
      offset.dy,
      paragraph.maxIntrinsicWidth,
      paragraph.height,
    );
    textCorners.add([
      for (final p in [
        rect.topLeft,
        rect.topRight,
        rect.bottomLeft,
        rect.bottomRight,
      ])
        origin + rotatePoint(p * textScale),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const style = ArchitectFenestrationStyle(
    id: 'test-window',
    name: 'Test',
    rootSubdivision: FenestrationSubdivision(
      id: 'root',
      pane: FenestrationPane(id: 'p'),
    ),
  );
  const window = ArchitectWindow(
    id: 'w',
    wallId: 'wall',
    offsetRatio: .5,
    uuid: 'w',
    width: 1.2,
    height: 1.4,
    sillHeight: .85,
    specId: 'W12',
  );
  final door = ArchitectDoor(
    id: 'd',
    wallId: 'wall',
    offsetRatio: .5,
    uuid: 'd',
    width: 1.2,
    height: 1.4,
    sillHeight: .85,
    specId: 'W12',
  );

  test(
    'Windows share door text sizes, dimensions and ID at every zoom and angle',
    () {
      for (final angle in [0.0, math.pi / 2, 2.6]) {
        final end = Offset(4 * math.cos(angle), 4 * math.sin(angle));
        for (final zoom in [8.0, 20.0, 100.0]) {
          final reference = _PlanCanvas();
          door.paint2D(
            canvas: reference,
            wallStart: Offset.zero,
            wallEnd: end,
            wallThickness: .37,
            zoomScale: zoom,
          );
          expect(reference.texts, hasLength(4));
          expect(reference.texts[0].$2, closeTo(.10, 1e-9));
          expect(reference.texts.last.$2, closeTo(.14, 1e-9));
          for (final candidate in [window, window.copyWith(style: style)]) {
            final canvas = _PlanCanvas();
            candidate.paint2D(
              canvas: canvas,
              wallStart: Offset.zero,
              wallEnd: end,
              wallThickness: .37,
              zoomScale: zoom,
            );
            expect(canvas.texts, hasLength(4));
            for (var i = 0; i < 4; i++) {
              expect(canvas.texts[i].$1, reference.texts[i].$1);
              expect(canvas.texts[i].$2, reference.texts[i].$2);
            }
            final n = Offset(-math.sin(angle), math.cos(angle));
            double along(Offset p) =>
                (p - end / 2).dx * n.dx + (p - end / 2).dy * n.dy;
            // Every dimension glyph clears the wall; sill height is opposite.
            for (final corners in canvas.textCorners.take(2)) {
              expect(corners.every((p) => along(p) > .37 / 2 + .07), isTrue);
            }
            expect(
              canvas.textCorners[2].every((p) => along(p) < -.37 / 2 - .07),
              isTrue,
            );
            expect(canvas.circles.single.$2, reference.circles.single.$2);
            for (final point in [
              canvas.circles.single.$1,
              canvas.textCorners[2].reduce((a, b) => a + b) / 4,
            ]) {
              expect(
                candidate.containsPoint(
                  point,
                  wallStart: Offset.zero,
                  wallEnd: end,
                  wallThickness: .37,
                  tolerance: 0,
                ),
                isTrue,
              );
            }
            expect(canvas.stack, isEmpty);
          }
        }
      }
    },
  );

  test(
    'Default and library windows draw a thin sill beyond the exterior face',
    () {
      for (final angle in [0.0, math.pi / 2, 2.6]) {
        final u = Offset(math.cos(angle), math.sin(angle));
        final n = Offset(-u.dy, u.dx);
        for (final sign in [-1.0, 1.0]) {
          for (final candidate in [window, window.copyWith(style: style)]) {
            final canvas = _PlanCanvas();
            candidate.paint2D(
              canvas: canvas,
              wallStart: Offset.zero,
              wallEnd: u * 4,
              wallThickness: .37,
              zoomScale: 100,
              exteriorSign: sign,
            );
            final ledgeCenter = u * 2 + n * (sign * (.37 / 2 + .04));
            final a = ledgeCenter - u * (.6 + .05);
            final b = ledgeCenter + u * (.6 + .05);
            final sills = canvas.lines.where(
              (line) =>
                  (line.$1 - a).distance < 1e-9 &&
                  (line.$2 - b).distance < 1e-9,
            );
            expect(sills, hasLength(1));
            expect(sills.single.$3, closeTo(.008, 1e-9));
          }
        }
      }
    },
  );

  test('Window ID badge is selectable, including rotated walls', () {
    for (final angle in [0.0, math.pi / 2, 2.6]) {
      final u = Offset(math.cos(angle), math.sin(angle));
      final n = Offset(-u.dy, u.dx);
      final center = u * 2;
      final drawn = _PlanCanvas();
      window.paint2D(
        canvas: drawn,
        wallStart: Offset.zero,
        wallEnd: u * 4,
        wallThickness: .37,
        zoomScale: 100,
      );
      expect(
        window.containsPoint(
          drawn.circles.single.$1 + n * .10,
          wallStart: Offset.zero,
          wallEnd: u * 4,
          wallThickness: .37,
          tolerance: 0,
        ),
        isTrue,
      );
      expect(
        window.containsPoint(
          center + n * 1,
          wallStart: Offset.zero,
          wallEnd: u * 4,
          wallThickness: .37,
          tolerance: 0,
        ),
        isFalse,
      );
    }
    expect(
      window.containsPoint(
        Offset.zero,
        wallStart: Offset.zero,
        wallEnd: Offset.zero,
        wallThickness: .37,
      ),
      isFalse,
    );
  });

  test('Floor-level windows omit wall-face projection and raised sill', () {
    for (final candidate in [window, window.copyWith(style: style)]) {
      for (final sill in [0.0, .15, .85]) {
        final canvas = _PlanCanvas();
        candidate
            .copyWith(sillHeight: sill)
            .paint2D(
              canvas: canvas,
              wallStart: Offset.zero,
              wallEnd: const Offset(4, 0),
              wallThickness: .37,
              zoomScale: 100,
            );
        for (final y in [-.185, .185]) {
          final faces = canvas.lines.where(
            (l) =>
                (l.$1 - Offset(1.4, y)).distance < 1e-8 &&
                (l.$2 - Offset(2.6, y)).distance < 1e-8,
          );
          expect(faces.length, sill > 0 ? 1 : 0);
        }
        expect(canvas.texts.length, sill > 0 ? 4 : 3);
      }
    }
  });

  test(
    'Operable library panes show sash profiles that fixed glazing omits',
    () {
      final fixed = _PlanCanvas(), operable = _PlanCanvas();
      final opening = window.copyWith(style: style);
      opening.paint2D(
        canvas: fixed,
        wallStart: Offset.zero,
        wallEnd: const Offset(4, 0),
        wallThickness: .37,
        zoomScale: 100,
      );
      opening
          .copyWith(
            style: style.copyWith(
              rootSubdivision: const FenestrationSubdivision(
                id: 'root',
                pane: FenestrationPane(id: 'p', paneType: PaneType.tiltAndTurn),
              ),
            ),
          )
          .paint2D(
            canvas: operable,
            wallStart: Offset.zero,
            wallEnd: const Offset(4, 0),
            wallThickness: .37,
            zoomScale: 100,
          );
      expect(operable.paths.length, fixed.paths.length + 2);
      expect(operable.lines.length, fixed.lines.length + 2);
    },
  );
}
