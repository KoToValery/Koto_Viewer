import 'architect_vector_scene.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import '../services/architect_stair_geometry.dart';
import '../services/architect_stair_railings.dart';
import '../widgets/architect_stair_labels.dart';
import 'architect_stair_mesh.dart';

class ArchitectStairPlanPainter {
  static void dashed(Canvas canvas, Path path, Paint paint, double scale) {
    final dash = 5 / scale, gap = 3 / scale;
    for (final metric in path.computeMetrics()) {
      for (var start = 0.0; start < metric.length; start += dash + gap) {
        canvas.drawPath(
          metric.extractPath(start, math.min(start + dash, metric.length)),
          paint,
        );
      }
    }
  }

  static void draw({
    required Canvas canvas,
    required ArchitectStair stair,
    required double scale,
    required Color color,
    Color background = Colors.white,
    double? cutHeight,
    ArchitectStorey? storey,
    ArchitectProject? project,
    AppLocalizations? l10n,
    bool labels = true,
    ArchitectDimensionScale dimensionScale = ArchitectDimensionScale.scale100,
  }) {
    architectDrawingSources(canvas, {stair.id}, 'stair');
    final plan = stair.plan, d = stair.design;
    final points = plan.walkingLine;
    VoidCallback? paintLabel;
    if (d != null &&
        d.showLabel &&
        labels &&
        l10n != null &&
        (ArchitectTextScope.current != null ||
            dimensionScale.textHeight * scale >= 5)) {
      final scope = ArchitectTextScope.current;
      final labelScale = scope == null ? 1 / scale : 1.0;
      final text = ArchitectTextPainter(
        elementId: stair.id,
        modelScale: labelScale,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        text: TextSpan(
          text: stairPlanLabel(l10n, stair),
          style: TextStyle(
            fontFamily: 'Roboto',
            color: color,
            fontSize: math.min(dimensionScale.textHeight * scale, 24.0),
            height: 1.15,
          ),
        ),
      )..layout();
      // Follow the longest segment of the ascent line, in readable direction.
      var a = plan.bounds.center, b = a + const Offset(1, 0);
      var longest = 0.0;
      for (var i = 1; i < points.length; i++) {
        final length = (points[i] - points[i - 1]).distance;
        if (length > longest) {
          longest = length;
          a = points[i - 1];
          b = points[i];
        }
      }
      var angle = math.atan2((b - a).dy, (b - a).dx);
      if (angle > math.pi / 2) angle -= math.pi;
      if (angle < -math.pi / 2) angle += math.pi;
      final at = (a + b) / 2;
      final fit = longest > 0
          ? math.min(
              1.0,
              longest * .85 / math.max(.001, text.width * labelScale),
            )
          : 1.0;

      final gap = scope == null
          ? 3.0
          : ArchitectDrawingScale(scope.denominator).paperToModel(.5) /
                labelScale;
      final offset = Offset(-text.width / 2, -text.height - gap);
      paintLabel = () {
        canvas.save();
        canvas.translate(at.dx, at.dy);
        canvas.rotate(angle);
        canvas.scale(labelScale * fit);
        text.paint(canvas, offset);
        canvas.restore();
      };
    }
    final geometry = ArchitectStairGeometry.of(stair);
    final cut = geometry.cut(cutHeight ?? double.infinity);
    final overheadClip = d?.shape == StairShape.spiralOverlap
        ? Path.combine(
            PathOperation.difference,
            Path()..addRect(plan.bounds.inflate(1)),
            cut.below,
          )
        : null;
    void overhead(Path path, Paint paint) {
      canvas.save();
      if (overheadClip != null) canvas.clipPath(overheadClip);
      dashed(canvas, path, paint, scale);
      canvas.restore();
    }

    final stroke = Paint()
      ..color = color
      ..strokeWidth = 1.2 / scale
      ..style = PaintingStyle.stroke;
    final thin = Paint()
      ..color = color
      ..strokeWidth = .8 / scale
      ..style = PaintingStyle.stroke;
    if (!cut.below.getBounds().isEmpty) {
      canvas.drawPath(cut.below, stroke);
    }
    overhead(cut.above, thin);
    for (var i = 0; i < plan.nosings.length; i++) {
      final (a, b) = plan.nosings[i];
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy);
      if (d != null &&
          d.startOffset + (i + 1) * d.riser >
              (cutHeight ?? double.infinity) + 1e-8) {
        overhead(path, thin);
      } else {
        canvas.drawPath(path, thin);
      }
    }
    if (points.length >= 2) {
      // The ascent symbol stays continuous and readable over the dashed steps.
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, thin);
      final scope = ArchitectTextScope.current;
      final radius = scope == null
          ? (stair.width * .055 * scale).clamp(4.5, 8.0) / scale
          : (stair.width * .055).clamp(
              ArchitectDrawingScale(scope.denominator).paperToModel(.5625),
              ArchitectDrawingScale(scope.denominator).paperToModel(1),
            );
      canvas.drawCircle(points.first, radius, stroke);
      final end = points.last, delta = end - points[points.length - 2];
      if (delta.distance > 1e-8) {
        final u = delta / delta.distance, n = Offset(-u.dy, u.dx);
        final size = math.min(.18, stair.width * .18);
        canvas.drawLine(end, end - u * size + n * size / 2, stroke);
        canvas.drawLine(end, end - u * size - n * size / 2, stroke);
      }
    }
    if (d != null && d.showRailing) {
      final floor = storey ?? const ArchitectStorey(id: 'preview', name: '');
      for (final path in ArchitectStairRailings.build(
        stair,
        storey: floor,
        project: project,
      )) {
        final base = ArchitectStairMesh.simplify(path.base);
        if (base.length < 2) continue;
        for (final offset in path.wallMounted ? [0.0] : [-.024, .024]) {
          final outline = ArchitectStairRailings.planOffset(base, offset);
          for (var i = 0; i < base.length - 1; i++) {
            final p = base[i], q = base[i + 1];
            final a = outline[i], b = outline[i + 1], v = b - a;
            if (v.distance < 1e-8) continue;
            void segment(Offset start, Offset end, bool above) {
              final line = Path()
                ..moveTo(start.dx, start.dy)
                ..lineTo(end.dx, end.dy);
              if (above) {
                overhead(line, thin);
              } else {
                canvas.drawPath(line, thin);
              }
            }

            final height = cutHeight ?? double.infinity;
            if ((p.z - height) * (q.z - height) < 0) {
              final middle = a + v * ((height - p.z) / (q.z - p.z));
              segment(a, middle, p.z > height);
              segment(middle, b, q.z > height);
            } else {
              segment(a, b, (p.z + q.z) / 2 > height + 1e-8);
            }
          }
        }
        if (!path.wallMounted && .036 * scale >= 2) {
          for (final member in ArchitectStairRailings.members(
            path,
          ).where((m) => m.post)) {
            final p = member.point;
            if (p.z > (cutHeight ?? double.infinity) + 1e-8) continue;
            canvas.drawCircle(Offset(p.x, p.y), .018, thin);
          }
        }
      }
    }
    if (cut.crossing != null) {
      final (a, b) = cut.crossing!;
      final index = (((cutHeight ?? 0) - d!.startOffset) / d.riser)
          .floor()
          .clamp(0, d.risers - 1);
      Offset direction;
      if (geometry.flights.isNotEmpty) {
        direction = geometry.flights
            .firstWhere(
              (f) => index >= f.firstRiser && index < f.firstRiser + f.count,
            )
            .axis;
      } else {
        final other =
            plan.nosings[index == d.risers - 1 ? index - 1 : index + 1];
        final delta = index == d.risers - 1
            ? a + b - other.$1 - other.$2
            : other.$1 + other.$2 - a - b;
        direction = delta / delta.distance;
      }
      for (final shift in [-.045, .045]) {
        final oblique = math.min(.28, stair.width * .22);
        final start = a + direction * (shift - oblique),
            end = b + direction * (shift + oblique);
        canvas.drawLine(
          start,
          end,
          Paint()
            ..color = background
            ..strokeWidth = 4 / scale,
        );
        canvas.drawLine(start, end, stroke..strokeWidth = 1.5 / scale);
      }
    }
    if (labels && d != null) {
      _landingLevels(
        canvas,
        stair,
        geometry,
        scale,
        color,
        storey,
        project,
        dimensionScale,
      );
    }
    paintLabel?.call();
  }

  static void _landingLevels(
    Canvas canvas,
    ArchitectStair stair,
    ArchitectStairGeometry geometry,
    double scale,
    Color color,
    ArchitectStorey? storey,
    ArchitectProject? project,
    ArchitectDimensionScale dimensionScale,
  ) {
    final scope = ArchitectTextScope.current;
    if (scope == null && dimensionScale.textHeight * scale < 5) return;
    final paper = ArchitectDrawingScale(
      scope?.denominator ?? dimensionScale.denominator,
    );
    final size = paper.paperToModel(.8);
    final paint = Paint()
      ..color = color
      ..strokeWidth = .8 / scale
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < geometry.landings.length; i++) {
      final landing = geometry.landings[i];
      final elevation =
          (storey?.elevation ?? 0) +
          stair.design!.startOffset +
          landing.elevation;
      final label =
          scope?.level(elevation) ??
          project?.formatLevel(elevation) ??
          formatArchitectLevel(elevation);
      final modelScale = scope == null ? 1 / scale : 1.0;
      final text = ArchitectTextPainter(
        elementId: stair.id,
        role: ArchitectAnnotationRole.dimension,
        modelScale: modelScale,
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: color,
            fontFamily: 'Roboto',
            fontSize: math.min(dimensionScale.textHeight * scale, 20.0),
          ),
        ),
      )..layout();
      final centre =
          landing.polygon.reduce((a, b) => a + b) /
          landing.polygon.length.toDouble();
      final flight = geometry.flights[i];
      var angle = math.atan2(flight.axis.dy, flight.axis.dx);
      if (angle > math.pi / 2) angle -= math.pi;
      if (angle < -math.pi / 2) angle += math.pi;
      // Fit the complete unmasked symbol inside the landing, including long
      // elevations in centimetres and larger publication text settings.
      final axis = Offset(math.cos(angle), math.sin(angle));
      final normal = Offset(-axis.dy, axis.dx);
      final local =
          (Path()..addPolygon([
                for (final p in landing.polygon)
                  Offset(
                    ArchitectStairGeometry.dot(p - centre, axis),
                    ArchitectStairGeometry.dot(p - centre, normal),
                  ),
              ], true))
              .getBounds();
      final textHeight = text.height * modelScale;
      final content = Rect.fromLTRB(
        -size * 1.4,
        -math.max(size * 1.4, textHeight / 2),
        size * 2 + text.width * modelScale,
        math.max(size * 1.4, textHeight / 2),
      );
      final margin = math.min(.08, math.min(local.width, local.height) * .1);
      final available = local.deflate(margin);
      final fit = math.min(
        1.0,
        math.min(
          available.width / content.width,
          available.height / content.height,
        ),
      );
      final up = math.min(
        size * 2,
        math.max(0.0, (available.height - content.height * fit) / 2),
      );
      canvas.save();
      canvas.translate(centre.dx, centre.dy);
      canvas.rotate(angle);
      canvas.translate(-content.center.dx * fit, -up);
      canvas.scale(fit);
      canvas.drawCircle(Offset.zero, size, paint);
      canvas.drawLine(Offset(-size * 1.4, 0), Offset(size * 1.4, 0), paint);
      canvas.drawLine(Offset(0, -size * 1.4), Offset(0, size * 1.4), paint);
      canvas.translate(size * 2, -textHeight / 2);
      canvas.scale(modelScale);
      text.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }
}
