import '../services/architect_ellipse_geometry.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../bim_projects/controllers/bim_viewport_controller.dart';
import '../models/architect_project.dart';
import '../models/architect_elements.dart';
import '../models/architect_column.dart';
import 'architect_canvas_palette.dart';
import 'architect_scene_geometry.dart';
import 'architect_wall_network.dart';
import 'architect_wall_geometry.dart';
import '../services/architect_spline_geometry.dart';

/// View-only silhouettes of the nearest floors. They do not enter hit testing,
/// snapping, project geometry, or the model's Undo history.
class ArchitectGhostStoreyPainter extends CustomPainter {
  final ArchitectProject project;
  final BimViewportController viewport;
  final ArchitectCanvasPalette palette;
  ArchitectGhostStoreyPainter({
    required this.project,
    required this.viewport,
    required this.palette,
  }) : super(repaint: viewport);

  static List<ArchitectStorey> neighbors(ArchitectProject project) {
    if (project.activeStorey.isSite) return const [];
    final floors = [
      for (final floor in project.storeys)
        if (!floor.isSite) floor,
    ]..sort(
        (a, b) => a.elevation == b.elevation
            ? a.id.compareTo(b.id)
            : a.elevation.compareTo(b.elevation),
      );
    final index = floors.indexWhere(
      (floor) => floor.id == project.activeStorey.id,
    );
    return [
      if (index > 0) floors[index - 1],
      if (index >= 0 && index < floors.length - 1) floors[index + 1],
    ];
  }

  static void _drawCadPrimitives(
    Canvas canvas,
    List<ArchitectCadPrimitive> primitives,
    Paint stroke,
    void Function(List<Offset>) polygon,
  ) {
    for (final primitive in primitives) {
      switch (primitive.type) {
        case CadPrimitiveType.line:
          canvas.drawLine(primitive.startPoint, primitive.endPoint, stroke);
        case CadPrimitiveType.polyline:
          canvas.drawPath(
            Path()..addPolygon(primitive.linePoints, false),
            stroke,
          );
        case CadPrimitiveType.rect:
        case CadPrimitiveType.hatch:
          polygon(primitive.polygonCorners);
        case CadPrimitiveType.circle:
          canvas.drawCircle(
            primitive.startPoint,
            (primitive.endPoint - primitive.startPoint).distance,
            stroke,
          );
        case CadPrimitiveType.arc:
          final arc = primitive.arc;
          if (arc != null) {
            canvas.drawPath(arc.toPath(), stroke);
          } else {
            canvas.drawLine(primitive.startPoint, primitive.endPoint, stroke);
          }
        case CadPrimitiveType.mask:
          polygon(primitive.polygonCorners);
        case CadPrimitiveType.spline:
          canvas.drawPath(
            ArchitectSplineGeometry.generatePath(
              primitive.linePoints,
              closed: primitive.closed == true,
            ),
            stroke,
          );
        case CadPrimitiveType.ellipse:
          canvas.drawPath(
            ArchitectEllipseGeometry.fromPrimitive(primitive).path,
            stroke,
          );
      }
    }
  }

  static void _drawPolyline(
    Canvas canvas,
    List<Offset> points,
    Paint stroke, {
    bool closed = false,
  }) {
    if (points.length < 2) return;
    canvas.drawPath(Path()..addPolygon(points, closed), stroke);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    viewport.applyToCanvas(canvas);
    for (final floor in neighbors(project)) {
      final scene = ArchitectSceneGeometry.visible(
        project.copyWith(activeStoreyId: floor.id, gridAxes: []),
        viewport.visibleRect,
        viewport.scale,
      );
      final storey = scene.activeStorey;
      final below = floor.elevation <= project.activeStorey.elevation;
      final color = below
          ? (palette.isDark ? const Color(0xFF80CBC4) : const Color(0xFF00695C))
          : (palette.isDark
                ? const Color(0xFFFFCC80)
                : const Color(0xFFBF360C));
      final stroke = Paint()
        ..color = color.withValues(alpha: .3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1 / viewport.scale;
      final fill = Paint()..color = color.withValues(alpha: .04);
      void polygon(List<Offset> points) {
        if (points.length < 3) return;
        final path = Path()..addPolygon(points, true);
        canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
      }

      final walls = ArchitectWallNetwork.body(
        ArchitectWallGeometry.planWalls(storey.walls),
      );
      canvas.drawPath(walls, fill);
      canvas.drawPath(walls, stroke);
      for (final slab in storey.slabs) {
        polygon(slab.polygon);
      }
      for (final zone in storey.zones) {
        polygon(zone.polygon);
      }
      for (final opening in storey.openings) {
        polygon(opening.boundary);
      }
      for (final beam in storey.beams) {
        polygon(beam.polygonCorners);
      }
      for (final stair in storey.stairs) {
        canvas.drawPath(stair.plan.path, stroke);
      }
      for (final column in storey.columns) {
        canvas.save();
        canvas.translate(column.position.dx, column.position.dy);
        canvas.rotate(column.rotationDeg * math.pi / 180);
        if (column.shape == ColumnShape.circular) {
          canvas.drawCircle(Offset.zero, column.width / 2, stroke);
        } else {
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: column.width,
              height: column.depth,
            ),
            stroke,
          );
        }
        canvas.restore();
      }
      _drawCadPrimitives(canvas, storey.cadPrimitives, stroke, polygon);
    }

    if (!project.activeStorey.isSite && project.siteStorey != null) {
      final site = project.siteStorey!;
      final siteColor = palette.isDark
          ? const Color(0xFFA5D6A7)
          : const Color(0xFF33691E);
      final siteStroke = Paint()
        ..color = siteColor.withValues(alpha: .35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 / viewport.scale;
      final siteFill = Paint()..color = siteColor.withValues(alpha: .03);
      void sitePolygon(List<Offset> points) {
        if (points.length < 3) return;
        final path = Path()..addPolygon(points, true);
        canvas.drawPath(path, siteFill);
        canvas.drawPath(path, siteStroke);
      }

      for (final surface in [project.existingTerrain, project.proposedTerrain]) {
        for (final boundary in surface.boundaries) {
          sitePolygon(boundary.polygon);
        }
        for (final contour in surface.contours) {
          _drawPolyline(
            canvas,
            contour.resolvedPolyline(),
            siteStroke,
            closed: contour.closed,
          );
        }
      }
      for (final pathway in site.pathways) {
        _drawPolyline(canvas, pathway.points, siteStroke, closed: pathway.closed);
      }
      for (final street in site.streets) {
        _drawPolyline(canvas, street.points, siteStroke, closed: street.closed);
      }
      for (final fence in site.siteFences) {
        _drawPolyline(canvas, fence.points, siteStroke, closed: fence.closed);
      }
      for (final slab in site.slabs) {
        sitePolygon(slab.polygon);
      }
      for (final zone in site.zones) {
        sitePolygon(zone.polygon);
      }
      _drawCadPrimitives(canvas, site.cadPrimitives, siteStroke, sitePolygon);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ArchitectGhostStoreyPainter oldDelegate) =>
      project != oldDelegate.project ||
      viewport != oldDelegate.viewport ||
      palette.isDark != oldDelegate.palette.isDark;
}
