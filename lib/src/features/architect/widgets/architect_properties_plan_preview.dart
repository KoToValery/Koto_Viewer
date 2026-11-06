import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../rendering/architect_2d_painter.dart';
import '../services/architect_selection.dart';

/// Uses the production geometry/painter, so handing and swings match the plan.
class ArchitectPropertiesPlanPreview extends StatelessWidget {
  final ArchitectProject project;
  final String elementId;
  const ArchitectPropertiesPlanPreview({
    super.key,
    required this.project,
    required this.elementId,
  });
  @override
  Widget build(BuildContext context) {
    final host = project.activeStorey.walls
        .where(
          (w) =>
              w.id == elementId ||
              w.doors.any((d) => d.id == elementId) ||
              w.windows.any((w) => w.id == elementId),
        )
        .firstOrNull;
    if (host == null) return const SizedBox.shrink();
    final floor = project.activeStorey;
    final isolated = project.copyWith(
      storeys: [
        ArchitectStorey(
          id: floor.id,
          name: floor.name,
          height: floor.height,
          elevation: floor.elevation,
          walls: [host],
        ),
      ],
      gridAxes: [],
      sections: [],
      elevations: [],
      clearNorthSymbol: true,
    );
    final bounds = ArchitectSelection.bounds(project, elementId)!.inflate(
      math.max(
        .5,
        host.doors.where((d) => d.id == elementId).firstOrNull?.width ?? .5,
      ),
    );
    return Semantics(
      label: context.l10n.architectProperties,
      child: Container(
        height: 132,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xffd0d4d9)),
        ),
        child: ClipRect(
          child: CustomPaint(
            painter: _PlanPreview(isolated, bounds, context.l10n),
          ),
        ),
      ),
    );
  }
}

class _PlanPreview extends CustomPainter {
  final ArchitectProject project;
  final Rect bounds;
  final AppLocalizations l;
  _PlanPreview(this.project, this.bounds, this.l);
  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(
      (size.width - 24) / bounds.width,
      (size.height - 16) / bounds.height,
    );
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    canvas.translate(-bounds.center.dx, -bounds.center.dy);
    Architect2dPainter(
      project: project,
      l10n: l,
      activeTool: ArchitectTool.pan,
      paintGrid: false,
      layer: ArchitectPaintLayer.model,
      zoomScale: scale,
    ).paint(canvas, size);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PlanPreview old) =>
      old.project != project || old.bounds != bounds || old.l != l;
}
