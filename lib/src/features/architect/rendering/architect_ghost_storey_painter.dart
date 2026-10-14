import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../bim_projects/controllers/bim_viewport_controller.dart';
import '../models/architect_project.dart';
import '../models/architect_elements.dart';
import '../models/architect_column.dart';
import 'architect_canvas_palette.dart';
import 'architect_scene_geometry.dart';
import 'architect_wall_network.dart';

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
    final floors = [...project.storeys]
      ..sort(
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

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(viewport.translation.dx, viewport.translation.dy);
    canvas.scale(viewport.scale);
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

      final walls = ArchitectWallNetwork.body(storey.walls);
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
        polygon(stair.polygonCorners);
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
      for (final primitive in storey.cadPrimitives) {
        switch (primitive.type) {
          case CadPrimitiveType.line:
            canvas.drawLine(primitive.startPoint, primitive.endPoint, stroke);
          case CadPrimitiveType.rect:
            polygon(primitive.polygonCorners);
          case CadPrimitiveType.circle:
            canvas.drawCircle(
              primitive.startPoint,
              (primitive.endPoint - primitive.startPoint).distance,
              stroke,
            );
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ArchitectGhostStoreyPainter oldDelegate) =>
      project != oldDelegate.project ||
      viewport != oldDelegate.viewport ||
      palette.isDark != oldDelegate.palette.isDark;
}
