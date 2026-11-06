import '../services/architect_drain_surface.dart';
// === SECTION: FLOOR DRAIN PAINTER HELPER ===
// Table of Contents:
// 1. PLAN DRAWING (floor tint, contour lines, fall arrows, thresholds)
// 2. DRAIN SYMBOLS (round grate, linear channel)
// 3. SELECTION HANDLES
//
// Print-first: dark ink on white, thin neutral rules, a barely visible tint.
// Colour (warning red) is always paired with a "!" mark.

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/architect_floor_drain.dart';
import '../models/architect_project.dart';
import '../models/architect_wall.dart';
import '../services/architect_floor_drain_geometry.dart';
import 'architect_canvas_palette.dart';

class ArchitectFloorDrainPainterHelper {
  ArchitectFloorDrainPainterHelper._();

  static const _ink = Color(0xFF263238);
  static const _rule = Color(0xFF607D8B);
  static const _warning = Color(0xFFC62828);

  // ===========================================================================
  // 1. PLAN DRAWING
  // ===========================================================================

  static void draw({
    required Canvas canvas,
    required ArchitectStorey storey,
    required double zoomScale,
    ArchitectCanvasPalette palette = const ArchitectCanvasPalette.light(),
    Set<String> selectedIds = const {},
    List<ArchitectWall>? walls,
  }) {
    for (final drain in storey.floorDrains) {
      if (drain.polygon.length < 3) continue;
      drawOne(
        canvas: canvas,
        drain: drain,
        walls: walls ?? storey.walls,
        zoomScale: zoomScale,
        palette: palette,
        selected: selectedIds.contains(drain.id),
      );
    }
  }

  static void drawOne({
    required Canvas canvas,
    required ArchitectFloorDrain drain,
    required List<ArchitectWall> walls,
    required double zoomScale,
    required ArchitectCanvasPalette palette,
    bool selected = false,
    bool preview = false,
  }) {
    final field = ArchitectFloorDrainGeometry.field(drain, walls);
    final floor = ArchitectContourPaths.of(drain);
    final ink = palette.foreground(_ink);
    final rule = palette.foreground(_rule);
    final warning = field.issues.isNotEmpty;

    // Very light tint marks the wet area without darkening a monochrome print.
    canvas.drawPath(
      floor,
      Paint()
        ..color = (palette.isDark ? Colors.white : _rule).withValues(
          alpha: preview ? .12 : .06,
        )
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      floor,
      Paint()
        ..color = selected
            ? const Color(0xFF00E5FF)
            : rule.withValues(alpha: .7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (selected ? 2.2 : 0.5) / zoomScale,
    );

    // Contours and arrows are clipped to the floor so they never cross walls.
    canvas.save();
    canvas.clipPath(floor);
    final contourPaint = Paint()
      ..color = rule.withValues(alpha: .75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.45 / zoomScale;
    for (final (a, b) in ArchitectDrainSurface.of(drain).folds) {
      if ((b - a).distance < drain.halfWidth * .25) continue;
      canvas.drawLine(a, b, contourPaint);
    }
    final arrowPaint = Paint()
      ..color = ink.withValues(alpha: .8)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 0.7 / zoomScale;
    for (final (from, to) in field.arrows) {
      _arrow(canvas, from, to, arrowPaint);
    }
    canvas.restore();

    _drawThresholds(canvas, field, zoomScale, ink);

    if (drain.isLinear) {
      _linearSymbol(canvas, drain, zoomScale, ink, palette.background, warning);
    } else {
      _roundSymbol(canvas, drain, zoomScale, ink, palette.background, warning);
    }
  }

  static void _drawThresholds(
    Canvas canvas,
    ArchitectDrainField field,
    double zoomScale,
    Color ink,
  ) {
    final paint = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 / zoomScale;
    for (final t in field.thresholds) {
      canvas.drawLine(t.start, t.end, paint);
      final u = (t.end - t.start) / (t.end - t.start).distance;
      final n = Offset(-u.dy, u.dx) * 0.05;
      canvas.drawLine(t.start - n, t.start + n, paint);
      canvas.drawLine(t.end - n, t.end + n, paint);
    }
  }

  // ===========================================================================
  // 2. DRAIN SYMBOLS
  // ===========================================================================

  static void _roundSymbol(
    Canvas canvas,
    ArchitectFloorDrain drain,
    double zoomScale,
    Color ink,
    Color paper,
    bool warning,
  ) {
    final c = drain.position;
    final r = drain.size / 2;
    final line = (warning ? _warning : ink);
    final stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 / zoomScale;
    final hair = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5 / zoomScale;
    canvas.drawCircle(c, r, Paint()..color = Colors.white);
    canvas.drawCircle(c, r, stroke);
    canvas.drawCircle(c, r * .62, hair);
    // Eight radial slots of the grate between the rings.
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 + math.pi / 8;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * (r * .70), c + d * (r * .92), hair);
    }
    // Outlet: quartered centre.
    canvas.drawLine(c - Offset(r * .62, 0), c + Offset(r * .62, 0), hair);
    canvas.drawLine(c - Offset(0, r * .62), c + Offset(0, r * .62), hair);
    canvas.drawCircle(c, r * .16, Paint()..color = Colors.white);
    canvas.drawCircle(c, r * .16, hair);
  }

  static void _linearSymbol(
    Canvas canvas,
    ArchitectFloorDrain drain,
    double zoomScale,
    Color ink,
    Color paper,
    bool warning,
  ) {
    final line = (warning ? _warning : ink);
    final stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 / zoomScale;
    final hair = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5 / zoomScale;
    canvas.save();
    canvas.translate(drain.position.dx, drain.position.dy);
    canvas.rotate(drain.angle);
    final outer = Rect.fromCenter(
      center: Offset.zero,
      width: drain.size,
      height: drain.width,
    );
    canvas.drawRect(outer, Paint()..color = Colors.white);
    canvas.drawRect(outer, stroke);
    final inset = drain.width * .2;
    canvas.drawRect(outer.deflate(inset), hair);
    // Grate bars across the channel, roughly every 40 mm.
    final bars = (drain.size / 0.04).floor();
    for (var i = 1; i < bars; i++) {
      final x = -drain.size / 2 + drain.size * i / bars;
      if (x.abs() < drain.width * .35) continue;
      canvas.drawLine(
        Offset(x, -drain.width / 2 + inset),
        Offset(x, drain.width / 2 - inset),
        hair,
      );
    }
    // Outlet in the middle of the channel.
    final outlet = drain.width * .26;
    canvas.drawCircle(Offset.zero, outlet, Paint()..color = Colors.white);
    canvas.drawCircle(Offset.zero, outlet, hair);
    canvas.drawLine(Offset(-outlet, 0), Offset(outlet, 0), hair);
    canvas.drawLine(Offset(0, -outlet), Offset(0, outlet), hair);
    canvas.restore();
  }

  static void _arrow(Canvas canvas, Offset from, Offset to, Paint paint) {
    canvas.drawLine(from, to, paint);
    final v = to - from;
    if (v.distance < 1e-9) return;
    final u = v / v.distance;
    final n = Offset(-u.dy, u.dx);
    const head = 0.055;
    canvas.drawLine(to, to - u * head + n * head * .55, paint);
    canvas.drawLine(to, to - u * head - n * head * .55, paint);
  }

  // ===========================================================================
  // 3. SELECTION HANDLES
  // ===========================================================================

  /// Point of the leader-line grip: an offset handle keeps the drain visible
  /// under a finger, the same way wall end points do.
  static Offset offsetHandle(ArchitectFloorDrain drain, double clearance) {
    var dir = drain.centroid - drain.position;
    dir = dir.distance < 0.05 ? const Offset(0, -1) : dir / dir.distance;
    return drain.position + dir * (clearance + drain.halfWidth);
  }

  static void drawHandles({
    required Canvas canvas,
    required ArchitectFloorDrain drain,
    required double zoomScale,
    required double handleOffsetLength,
  }) {
    final scale = math.max(zoomScale, 80.0);
    const color = Color(0xFF00BCD4);
    canvas.drawCircle(drain.position, 3.5 / scale, Paint()..color = color);
    if (handleOffsetLength <= 0) return;
    final handle = offsetHandle(drain, handleOffsetLength / zoomScale);
    canvas.drawLine(
      drain.position,
      handle,
      Paint()
        ..color = const Color(0xFF00E5FF)
        ..strokeWidth = 1.6 / scale
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(
      handle,
      5.5 / scale,
      Paint()..color = const Color(0xFF1E1E26),
    );
    canvas.drawCircle(
      handle,
      5.5 / scale,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 / scale,
    );
  }
}

/// Cached fill path of a drain floor including holes.
class ArchitectContourPaths {
  ArchitectContourPaths._();
  static final _cache = Expando<Path>();
  static Path of(ArchitectFloorDrain drain) => _cache[drain] ??= _build(drain);
  static Path _build(ArchitectFloorDrain drain) {
    var result = Path()..addPolygon(drain.polygon, true);
    for (final hole in drain.holes) {
      result = Path.combine(
        PathOperation.difference,
        result,
        Path()..addPolygon(hole, true),
      );
    }
    return result;
  }
}
