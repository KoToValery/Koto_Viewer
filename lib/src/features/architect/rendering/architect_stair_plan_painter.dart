import 'architect_hatch_geometry.dart';
import '../models/architect_hatch_pattern.dart';
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
    final points=plan.walkingLine;
    Path? labelMask;
    VoidCallback? paintLabel;
    if (d != null &&
        d.showLabel &&
        labels &&
        l10n != null &&
        (ArchitectTextScope.current != null || dimensionScale.textHeight * scale >= 5)) {
      final scope = ArchitectTextScope.current;
      final labelScale = scope == null ? 1 / scale : 1.0;
      final text = ArchitectTextPainter(elementId: stair.id, modelScale: labelScale,
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
        if (length > longest) { longest = length; a = points[i - 1]; b = points[i]; }
      }
      var angle = math.atan2((b - a).dy, (b - a).dx);
      if (angle > math.pi / 2) angle -= math.pi;
      if (angle < -math.pi / 2) angle += math.pi;
      final at = (a + b) / 2;
      final fit=longest>0?math.min(1.0,longest*.85/math.max(.001,text.width*labelScale)):1.0;

      final gap = scope == null ? 3.0 : ArchitectDrawingScale(scope.denominator).paperToModel(.5) / labelScale;
      final offset=Offset(-text.width/2,-text.height-gap);
      final matrix=Matrix4.identity()..translateByDouble(at.dx,at.dy,0,1)
        ..rotateZ(angle)..scaleByDouble(labelScale*fit,labelScale*fit,1,1);
      labelMask=(Path()..addRect(Rect.fromLTWH(offset.dx-gap/2,offset.dy-gap/2,
        text.width+gap,text.height+gap))).transform(matrix.storage);
      paintLabel=() {
        canvas.save();canvas.translate(at.dx,at.dy);canvas.rotate(angle);
        canvas.scale(labelScale*fit);text.paint(canvas,offset);canvas.restore();
      };
    }
    final labelOutside=labelMask==null?null:Path.combine(PathOperation.difference,
      Path()..addRect(plan.bounds.inflate(5)),labelMask);
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
      final pattern=ArchitectHatchPattern.presets.firstWhere((p)=>p.id==switch(d?.construction) {
        StairConstruction.steel=>'metal',StairConstruction.timber=>'wood',_=>'concrete'});
      canvas.save(); canvas.clipPath(cut.below);
      if(labelOutside!=null) canvas.clipPath(labelOutside);
      canvas.drawPath(ArchitectHatchGeometry.path(boundary:cut.below,pattern:pattern,
        unitsPerMm:ArchitectTextScope.current==null ? 3/scale :
          ArchitectTextScope.current!.denominator/1000),
        Paint()..color=color.withValues(alpha:.6)..strokeWidth=.6/scale..style=PaintingStyle.stroke);
      canvas.restore();
      canvas.drawPath(cut.below, stroke);
    }
    overhead(cut.above, thin);
    canvas.save();
    if(labelOutside!=null) canvas.clipPath(labelOutside);
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
    canvas.restore();
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
        for (var i = 0; i < base.length - 1; i++) {
          final p = base[i], q = base[i + 1];
          final a = Offset(p.x, p.y), b = Offset(q.x, q.y), v = b - a;
          if (v.distance < 1e-8) continue;
          final offsets = path.wallMounted
              ? [Offset.zero]
              : [Offset.zero, Offset(-v.dy, v.dx) / v.distance * .025];
          for (final offset in offsets) {
            void segment(Offset start, Offset end, bool above) {
              final line = Path()
                ..moveTo(start.dx + offset.dx, start.dy + offset.dy)
                ..lineTo(end.dx + offset.dx, end.dy + offset.dy);
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
    paintLabel?.call();
  }
}
