import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../rendering/architect_elevation_markers.dart';
import '../rendering/architect_stair_plan_painter.dart';
import '../services/architect_view_placement.dart';
import '../services/architect_roof_junctions.dart';

/// Stable plan framing throughout a draft. Mouse hover and touch dragging share
/// the same snapping and live guides; no model/history is changed by a preview.
class ArchitectViewPlan extends StatefulWidget {
  final ArchitectProject project;
  final Offset? first, second;
  final bool placing, north;
  final String? selectedSection, selectedElevation;
  final ValueChanged<Offset> onPoint;
  final TransformationController? transform;
  final String surfaceKey;
  const ArchitectViewPlan({
    super.key,
    required this.project,
    required this.onPoint,
    required this.surfaceKey,
    this.first,
    this.second,
    this.placing = false,
    this.north = false,
    this.selectedSection,
    this.selectedElevation,
    this.transform,
  });
  @override
  State<ArchitectViewPlan> createState() => _ViewPlanState();

  static Rect bounds(ArchitectProject project) {
    final points = <Offset>[
      for (final a in project.gridAxes) ...[a.start, a.end],
      for (final s in project.storeys) ...[
        for (final w in s.walls) ...w.polygonCorners,
        for (final slab in s.slabs) ...slab.polygon,
        for (final roof in s.roofs) ...roof.points,
        for (final c in s.columns) ...[
          c.position - Offset(c.width, c.depth),
          c.position + Offset(c.width, c.depth),
        ],
        for (final beam in s.beams) ...beam.polygonCorners,
        for (final stair in s.stairs) ...[
          stair.displayBounds.topLeft,
          stair.displayBounds.bottomRight,
        ],
      ],
      for (final e in project.elevations) ...[e.start, e.end],
      for (final s in project.sections) ...[s.start, s.end],
      if (project.northSymbol != null) project.northSymbol!.position,
    ];
    if (points.isEmpty) return const Rect.fromLTWH(-5, -5, 10, 10);
    var bounds = Rect.fromPoints(points.first, points.first);
    for (final p in points.skip(1)) {
      bounds = bounds.expandToInclude(Rect.fromPoints(p, p));
    }
    return bounds.inflate(3);
  }
}

class _ViewPlanState extends State<ArchitectViewPlan> {
  Offset? pointer;
  @override
  void didUpdateWidget(covariant ArchitectViewPlan oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.first != oldWidget.first ||
        widget.second != oldWidget.second ||
        widget.placing != oldWidget.placing ||
        widget.north != oldWidget.north) {
      pointer = null;
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, constraints) {
      final size = constraints.biggest,
          bounds = ArchitectViewPlan.bounds(widget.project);
      final scale =
          math.min(size.width / bounds.width, size.height / bounds.height) *
          .85;
      Offset point(Offset screen) =>
          bounds.center + (screen - size.center(Offset.zero)) / scale;
      void move(Offset local) => setState(() => pointer = point(local));
      void accept(Offset local) {
        var p = point(local);
        if (widget.placing && !widget.north) {
          if (widget.first == null) {
            p = ArchitectViewPlacement.snapStart(widget.project, p, 10 / scale);
          } else if (widget.second == null) {
            p = ArchitectViewPlacement.snapEnd(
              widget.project,
              widget.first!,
              p,
            );
          }
        }
        widget.onPoint(p);
      }

      return InteractiveViewer(
        transformationController: widget.transform,
        minScale: .25,
        maxScale: 20,
        panEnabled: !widget.placing,
        scaleEnabled: !widget.placing,
        child: MouseRegion(
          onHover: widget.placing ? (e) => move(e.localPosition) : null,
          child: GestureDetector(
            key: ValueKey(widget.surfaceKey),
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => accept(d.localPosition),
            onPanStart: widget.placing ? (d) => move(d.localPosition) : null,
            onPanUpdate: widget.placing ? (d) => move(d.localPosition) : null,
            onPanEnd: widget.placing
                ? (_) {
                    if (pointer != null) {
                      accept(
                        size.center(Offset.zero) +
                            (pointer! - bounds.center) * scale,
                      );
                    }
                  }
                : null,
            onPanCancel: widget.placing
                ? () => setState(() => pointer = null)
                : null,
            child: CustomPaint(
              size: size,
              painter: ArchitectViewPlanPainter(
                widget.project,
                bounds,
                scale,
                Theme.of(context).colorScheme,
                context.l10n,
                first: widget.first,
                second: widget.second,
                pointer: pointer,
                placing: widget.placing,
                north: widget.north,
                selectedSection: widget.selectedSection,
                selectedElevation: widget.selectedElevation,
                fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
              ),
            ),
          ),
        ),
      );
    },
  );
}

class ArchitectViewPlanPainter extends CustomPainter {
  final ArchitectProject project;
  final Rect bounds;
  final double scale;
  final ColorScheme colors;
  final AppLocalizations l;
  final Offset? first, second, pointer;
  final bool placing, north;
  final String? selectedSection, selectedElevation, fontFamily;
  ArchitectViewPlanPainter(
    this.project,
    this.bounds,
    this.scale,
    this.colors,
    this.l, {
    this.first,
    this.second,
    this.pointer,
    this.placing = false,
    this.north = false,
    this.selectedSection,
    this.selectedElevation,
    this.fontFamily,
  });

  ArchitectViewPlacement? get draft => !placing || north || first == null
      ? null
      : ArchitectViewPlacement.preview(
          project,
          bounds,
          first!,
          second,
          pointer,
        );

  void dashed(Canvas canvas, Offset a, Offset b, Color color) {
    ArchitectStairPlanPainter.dashed(
      canvas,
      Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 / scale,
      scale,
    );
  }

  void arrow(Canvas canvas, Offset a, Offset direction, Color color) {
    final end = a + direction * (23 / scale),
        side = Offset(-direction.dy, direction.dx);
    canvas.drawLine(
      a,
      end,
      Paint()
        ..color = color
        ..strokeWidth = 2 / scale,
    );
    canvas.drawPath(
      Path()
        ..moveTo(end.dx, end.dy)
        ..lineTo(
          (end - direction * (7 / scale) + side * (4 / scale)).dx,
          (end - direction * (7 / scale) + side * (4 / scale)).dy,
        )
        ..lineTo(
          (end - direction * (7 / scale) - side * (4 / scale)).dx,
          (end - direction * (7 / scale) - side * (4 / scale)).dy,
        )
        ..close(),
      Paint()..color = color,
    );
  }

  void viewExtent(
    Canvas canvas,
    Offset start,
    Offset end,
    Offset direction,
    double? depth,
    Color color, {
    bool label = false,
  }) {
    if (depth == null) return;
    final offset = direction * depth;
    dashed(canvas, start, start + offset, color);
    dashed(canvas, end, end + offset, color);
    dashed(canvas, start + offset, end + offset, color);
    if (label) {
      final text = TextPainter(
        text: TextSpan(
          text: project.units.format(depth, decimals: project.distanceDecimals),
          style: TextStyle(
            color: color,
            fontSize: 11 / scale,
            fontFamily: fontFamily,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        (start + end) / 2 +
            offset -
            Offset(text.width / 2, text.height + 5 / scale),
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(
      size.width / 2 - bounds.center.dx * scale,
      size.height / 2 - bounds.center.dy * scale,
    );
    canvas.scale(scale);
    for (final axis in project.gridAxes) {
      dashed(
        canvas,
        axis.start,
        axis.end,
        colors.onSurface.withValues(alpha: .18),
      );
    }
    for (final floor in project.storeys) {
      for (final slab in floor.slabs) {
        final path = Path()..addPolygon(slab.polygon, true);
        canvas.drawPath(
          path,
          Paint()..color = colors.primary.withValues(alpha: .06),
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = colors.onSurface.withValues(alpha: .25)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1 / scale,
        );
      }
      for (final roof in floor.roofs) {
        canvas.drawPath(
          ArchitectRoofJunctions.of(floor, project: project).footprint(roof),
          Paint()..color = const Color(0xffc85a32).withValues(alpha: .08),
        );
      }
      for (final polygon in [
        for (final w in floor.walls) w.polygonCorners,
        for (final b in floor.beams) b.polygonCorners,
      ]) {
        canvas.drawPath(
          Path()..addPolygon(polygon, true),
          Paint()..color = colors.onSurface.withValues(alpha: .23),
        );
      }
    }
    // Stairs are drawn last, above slab/roof fills, using real treads and ascent
    // arrows. The active storey's stair remains strongest when floors overlap.
    final floors = [...project.storeys]
      ..sort(
        (a, b) => (a.id == project.activeStoreyId ? 1 : 0).compareTo(
          b.id == project.activeStoreyId ? 1 : 0,
        ),
      );
    for (final floor in floors) {
      for (final column in floor.columns) {
        column.paint2D(
          canvas: canvas,
          zoomScale: scale,
          defaultStoreyHeight: floor.height,
        );
      }
      for (final stair in floor.stairs) {
        ArchitectStairPlanPainter.draw(
          canvas: canvas,
          stair: stair,
          scale: scale,
          color: colors.onSurface.withValues(
            alpha: floor.id == project.activeStoreyId ? .9 : .3,
          ),
          background: colors.surface,
          storey: floor,
          project: project,
          l10n: l,
          labels: false,
        );
      }
    }
    drawArchitectElevationMarkers(
      canvas,
      project,
      scale,
      colors.onSurface,
      l,
      selected: selectedElevation,
      fontFamily: fontFamily,
    );
    for (final view in project.elevations.where(
      (e) => e.id == selectedElevation,
    )) {
      viewExtent(
        canvas,
        view.start,
        view.end,
        view.viewDirection,
        view.viewDepth,
        colors.primary.withValues(alpha: .6),
      );
    }
    for (final section in project.sections) {
      final color = section.id == selectedSection
          ? colors.primary
          : colors.onSurface.withValues(alpha: .4);
      canvas.drawLine(
        section.start,
        section.end,
        Paint()
          ..color = color
          ..strokeWidth = 2 / scale,
      );
      for (final p in [section.start, section.end]) {
        canvas.drawCircle(p, 3 / scale, Paint()..color = color);
        arrow(canvas, p, section.viewDirection, color);
      }
      if (section.id == selectedSection) {
        viewExtent(
          canvas,
          section.start,
          section.end,
          section.viewDirection,
          section.viewDepth,
          color.withValues(alpha: .6),
        );
      }
    }
    final draft = this.draft;
    if (draft != null && (pointer != null || second != null)) {
      final axis = draft.axis, centre = draft.centre;
      final extent = math.max(bounds.width, bounds.height) * 3;
      dashed(
        canvas,
        draft.start - axis * extent,
        draft.start + axis * extent,
        colors.primary.withValues(alpha: .55),
      );
      // The perpendicular guide refers to the marker, never to an inferred
      // target wall. After the second click it becomes the depth direction.
      final guideOrigin = second == null ? draft.end : centre;
      dashed(
        canvas,
        guideOrigin - draft.direction * extent,
        guideOrigin + draft.direction * extent,
        colors.primary.withValues(alpha: .35),
      );
      if (second == null) {
        dashed(
          canvas,
          Offset(bounds.left, draft.start.dy),
          Offset(bounds.right, draft.start.dy),
          colors.primary.withValues(alpha: .3),
        );
        dashed(
          canvas,
          Offset(draft.start.dx, bounds.top),
          Offset(draft.start.dx, bounds.bottom),
          colors.primary.withValues(alpha: .3),
        );
      }
      if (draft.aligned && pointer != null) {
        dashed(canvas, pointer!, draft.end, colors.tertiary);
      }
      final r = 9 / scale;
      canvas.drawPath(
        Path()
          ..moveTo((centre + axis * r).dx, (centre + axis * r).dy)
          ..lineTo(
            (centre + axis * r + draft.direction * r).dx,
            (centre + axis * r + draft.direction * r).dy,
          )
          ..lineTo(
            (centre + draft.direction * r).dx,
            (centre + draft.direction * r).dy,
          ),
        Paint()
          ..color = colors.tertiary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 / scale,
      );
      canvas.drawLine(
        draft.start,
        draft.end,
        Paint()
          ..color = colors.primary
          ..strokeWidth = 2.5 / scale,
      );
      for (final p in [draft.start, draft.end]) {
        canvas.drawCircle(p, 5 / scale, Paint()..color = colors.surface);
        canvas.drawCircle(
          p,
          5 / scale,
          Paint()
            ..color = colors.primary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2 / scale,
        );
      }
      if (second != null) {
        viewExtent(
          canvas,
          draft.start,
          draft.end,
          draft.direction,
          draft.viewDepth,
          colors.primary,
          label: true,
        );
        arrow(canvas, centre, draft.direction, colors.primary);
        arrow(canvas, draft.start, draft.direction, colors.primary);
        arrow(canvas, draft.end, draft.direction, colors.primary);
      }
    } else if (first != null) {
      if (!north) {
        dashed(
          canvas,
          Offset(bounds.left, first!.dy),
          Offset(bounds.right, first!.dy),
          colors.primary.withValues(alpha: .4),
        );
        dashed(
          canvas,
          Offset(first!.dx, bounds.top),
          Offset(first!.dx, bounds.bottom),
          colors.primary.withValues(alpha: .4),
        );
      }
      canvas.drawCircle(first!, 5 / scale, Paint()..color = colors.primary);
      if (north && pointer != null && (pointer! - first!).distance > .01) {
        arrow(
          canvas,
          first!,
          (pointer! - first!) / (pointer! - first!).distance,
          colors.primary,
        );
      }
    } else if (placing && pointer != null) {
      final p = north
          ? pointer!
          : ArchitectViewPlacement.snapStart(project, pointer!, 10 / scale);
      dashed(
        canvas,
        Offset(bounds.left, p.dy),
        Offset(bounds.right, p.dy),
        colors.primary.withValues(alpha: .35),
      );
      dashed(
        canvas,
        Offset(p.dx, bounds.top),
        Offset(p.dx, bounds.bottom),
        colors.primary.withValues(alpha: .35),
      );
      canvas.drawCircle(
        p,
        5 / scale,
        Paint()
          ..color = colors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 / scale,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ArchitectViewPlanPainter oldDelegate) => true;
}
