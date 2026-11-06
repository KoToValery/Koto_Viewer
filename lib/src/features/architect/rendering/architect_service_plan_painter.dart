import 'dart:ui';
import '../models/architect_contour.dart';
import '../models/architect_project.dart';
import '../services/architect_service_geometry.dart';
import 'architect_canvas_palette.dart';
import 'architect_line_presentation.dart';
import 'architect_vector_scene.dart';

/// Roof openings remain visible even when their source belongs to a lower floor.
class ArchitectServicePlanPainter {
  static void roofOpenings({
    required Canvas canvas,
    required ArchitectProject project,
    required ArchitectStorey storey,
    required double scale,
    required ArchitectCanvasPalette palette,
  }) {
    final openings = <String, Path>{}, flashings = <String, Path>{};
    for (final floor in project.storeys) {
      if (!storey.isRoof && floor.id != storey.id) continue;
      for (final roof in floor.roofs) {
        final roofPath = ArchitectContour.path(roof.points, roof.holes);
        for (final p in ArchitectServiceGeometry.penetrations(
          project,
          floor,
          roof,
        )) {
          final id = p.component.id;
          openings[id] = Path.combine(
            PathOperation.union,
            openings[id] ?? Path(),
            p.opening,
          );
          if (ArchitectServiceGeometry.hasRoofOutlet(p.component)) {
            final params = ArchitectServiceGeometry.parameters(
              project,
              p.owner,
              p.component,
            );
            final clearance =
                (params['roofClearance'] as num?)?.toDouble() ?? .02;
            final apron = Path.combine(
              PathOperation.intersect,
              roofPath,
              ArchitectServiceGeometry.footprint(
                p.profile,
                clearance: clearance + .10,
              ),
            );
            flashings[id] = Path.combine(
              PathOperation.union,
              flashings[id] ?? Path(),
              apron,
            );
          }
        }
      }
    }
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..color = palette.foreground(ArchitectPaperStyle.ink)
      ..strokeWidth = ArchitectLinePresentation.stroke(
        scale,
        .20,
        canvas: canvas,
      );
    final apronPen = Paint()
      ..style = PaintingStyle.stroke
      ..color = palette.foreground(ArchitectPaperStyle.rule)
      ..strokeWidth = ArchitectLinePresentation.stroke(
        scale,
        .13,
        pixels: .7,
        canvas: canvas,
      );
    final mask = Paint()
      ..color = ArchitectLinePresentation.paper(canvas)
          ? ArchitectPaperStyle.paper
          : palette.background;
    for (final entry in openings.entries) {
      architectDrawingSources(canvas, {entry.key}, 'serviceRoofOpenings');
      canvas.drawPath(entry.value, mask);
      if (flashings[entry.key] case final Path apron) {
        canvas.drawPath(apron, apronPen);
      }
      canvas.drawPath(entry.value, outline);
    }
  }
}
