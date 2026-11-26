import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../../core/l10n/l10n_extensions.dart';
import '../../bim_editing/geometry/bim_line_geometry.dart';
import '../../bim_editing/geometry/bim_polygon_geometry.dart';
import '../../bim_editing/geometry/bim_transform_2d.dart';
import '../models/architect_project.dart';
import '../models/architect_site_parcel.dart';
import 'architect_canvas_palette.dart';
import 'architect_vector_scene.dart';

abstract final class ArchitectSiteParcelPainter {
  static void paint({
    required Canvas canvas,
    required ArchitectProject project,
    required List<List<Offset>> building,
    required AppLocalizations? l10n,
    required double scale,
    required ArchitectCanvasPalette palette,
    required Rect? visibleBounds,
  }) {
    final parcel = project.activeStorey.siteParcel;
    if (parcel == null) return;
    final scope = ArchitectTextScope.current!;
    final paperFactor = scope.denominator / 1000;
    double pen(double millimetres, double pixels) =>
        scope.publication ? millimetres * paperFactor : pixels / scale;
    final ink = palette.foreground(ArchitectPaperStyle.ink);

    architectDrawingSources(canvas, const [], 'siteParcelBoundary');
    canvas.drawPath(
      Path()..addPolygon(parcel.vertices, true),
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = pen(.50, 2.8),
    );

    architectDrawingSources(canvas, const [], 'siteSetback');
    final red = Paint()
      ..color = palette.foreground(const Color(0xFFC62828))
      ..strokeWidth = pen(.25, 1.5);
    final dash = pen(3, 9), gap = pen(1.5, 4);
    for (final entry in parcel.setbacks.entries) {
      for (final (a, b) in parcel.setbackSegments(entry.key, entry.value)) {
        final length = (b - a).distance;
        final direction = (b - a) / length;
        final clipped = visibleBounds == null
            ? (a, b)
            : BimLineGeometry.visibleSegment(a, b, visibleBounds.inflate(dash));
        if (clipped == null) continue;
        final first =
            ((clipped.$1 - a).distance / (dash + gap)).floor() * (dash + gap);
        final last = (clipped.$2 - a).distance;
        for (var d = first; d < last; d += dash + gap) {
          canvas.drawLine(
            a + direction * d,
            a + direction * math.min(d + dash, length),
            red,
          );
        }
      }
    }

    final labels = <Rect>[];
    final rotate = scope.viewRotationRad;
    Offset rotation(Offset p) => BimTransform2D.rotate(p, Offset.zero, rotate);
    Offset unrotate(Offset p) => BimTransform2D.rotate(p, Offset.zero, -rotate);
    final tick = pen(.9, 4);
    final dimension = Paint()
      ..color = palette.foreground(ArchitectPaperStyle.rule)
      ..strokeWidth = pen(.18, 1);

    void label(
      String value,
      Offset anchor,
      String role, {
      bool strong = false,
    }) {
      final text = ArchitectTextPainter(
        elementId: role,
        modelScale: 1,
        role: ArchitectAnnotationRole.ordinary,
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: value,
          style: TextStyle(
            color: ink,
            fontSize: 12 / scale,
            fontWeight: strong ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      )..layout();
      final target = rotation(anchor);
      final size = text.size;
      final pad = tick / 3;
      var center = target;
      Rect bounds() => Rect.fromCenter(
        center: center,
        width: size.width,
        height: size.height,
      ).inflate(pad);
      var rect = bounds();
      while (labels.any(rect.overlaps)) {
        center -= Offset(0, size.height + pad * 2);
        rect = bounds();
      }
      labels.add(rect);
      architectDrawingSources(canvas, const [], role);
      if (center != target) {
        canvas.drawLine(anchor, unrotate(rect.bottomCenter), dimension);
      }
      canvas.save();
      canvas.translate(unrotate(center).dx, unrotate(center).dy);
      canvas.rotate(-rotate);
      architectDrawKnockout(
        canvas,
        Path()..addRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: size.width + pad,
            height: size.height + pad,
          ),
        ),
        scope.publication ? ArchitectPaperStyle.paper : palette.background,
      );
      text.paint(canvas, Offset(-size.width / 2, -size.height / 2));
      canvas.restore();
    }

    final areaPosition = _areaAnchor(parcel);
    if (l10n != null) {
      label(
        l10n.architectSiteParcelArea(
          NumberFormat.decimalPatternDigits(
            locale: l10n.localeName,
            decimalDigits: 2,
          ).format(parcel.area),
        ),
        areaPosition,
        'siteParcelArea',
        strong: true,
      );
    }
    for (final (a, b) in parcel.clearances(building)) {
      if (visibleBounds != null &&
          BimLineGeometry.visibleSegment(
                a,
                b,
                visibleBounds.inflate(50 / scale),
              ) ==
              null &&
          !visibleBounds.contains(a)) {
        continue;
      }
      final length = (b - a).distance;
      final perpendicular = length < 1e-8
          ? unrotate(const Offset(0, -1))
          : Offset(a.dy - b.dy, b.dx - a.dx) / length;
      architectDrawingSources(canvas, const [], 'siteClearance');
      if (length < 1e-8) {
        canvas.drawCircle(a, tick / 2, dimension);
      } else {
        canvas.drawLine(a, b, dimension);
        for (final p in [a, b]) {
          canvas.drawLine(
            p - perpendicular * tick,
            p + perpendicular * tick,
            dimension,
          );
        }
      }
      label(
        scope.length(length),
        (a + b) / 2 + perpendicular * (tick * 3),
        'siteClearance',
      );
    }
    if (l10n != null && parcel.buildingOutside(building)) {
      label(
        l10n.architectSiteBuildingOutside,
        areaPosition + unrotate(Offset(0, tick * 5)),
        'siteClearance',
        strong: true,
      );
    }
  }

  static Offset _areaAnchor(ArchitectSiteParcel parcel) {
    final center = (Path()..addPolygon(parcel.vertices, true))
        .getBounds()
        .center;
    if (parcel.contains(center)) return center;
    // An inward probe at an edge midpoint gives a label anchor even for an
    // L-shaped parcel whose bounding-box centre falls outside.
    for (var i = 0; i < parcel.vertices.length; i++) {
      final (a, b) = parcel.side(i);
      final normal = -BimPolygonGeometry.normal(parcel.vertices, i);
      final anchor = (a + b) / 2 + normal * math.min(.2, (b - a).distance / 20);
      if (parcel.contains(anchor)) return anchor;
    }
    return parcel.vertices.first;
  }
}
