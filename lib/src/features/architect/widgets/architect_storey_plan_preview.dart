import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../rendering/architect_2d_painter.dart';
import '../rendering/architect_scene_geometry.dart';

/// The production plan renderer keeps opening cuts, curves and lineweights
/// consistent with the drawing workspace, on a white paper preview.
class ArchitectStoreyPlanPreview extends StatelessWidget {
  final ArchitectProject project;
  final ArchitectStorey storey;
  final double height;
  const ArchitectStoreyPlanPreview({
    super.key,
    required this.project,
    required this.storey,
    this.height = 300,
  });

  @override
  Widget build(BuildContext context) {
    final isolated = project.copyWith(
      activeStoreyId: storey.id,
      storeys: [storey],
      gridAxes: [],
      sections: [],
      elevations: [],
      clearNorthSymbol: true,
    );
    final bounds = ArchitectSceneGeometry.projectBounds(isolated);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xffd0d4d9)),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: storey.groupableIds.isEmpty && storey.zones.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  context.l10n.architectNoDrawnElements,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xff586270)),
                ),
              ),
            )
          : ExcludeSemantics(
              child: CustomPaint(
                painter: _StoreyPlanPainter(isolated, bounds, context.l10n),
              ),
            ),
    );
  }
}

class _StoreyPlanPainter extends CustomPainter {
  final ArchitectProject project;
  final Rect bounds;
  final AppLocalizations l10n;
  _StoreyPlanPainter(this.project, this.bounds, this.l10n);

  @override
  void paint(Canvas canvas, Size size) {
    final padded = bounds.inflate(
      math.max(.5, math.max(bounds.width, bounds.height) * .08),
    );
    final scale = math.min(
      (size.width - 24) / padded.width,
      (size.height - 24) / padded.height,
    );
    if (!scale.isFinite || scale <= 0) return;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    canvas.translate(-padded.center.dx, -padded.center.dy);
    Architect2dPainter(
      project: project,
      l10n: l10n,
      activeTool: ArchitectTool.pan,
      paintGrid: false,
      showUpperOverhangs: false,
      layer: ArchitectPaintLayer.model,
      zoomScale: scale,
    ).paint(canvas, size);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StoreyPlanPainter old) =>
      old.project != project || old.bounds != bounds || old.l10n != l10n;
}
