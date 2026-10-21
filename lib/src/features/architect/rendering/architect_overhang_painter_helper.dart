import 'architect_vector_scene.dart';
// === SECTION: ARCHITECTURAL UPPER OVERHANG PAINTER HELPER ===
import 'package:flutter/material.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../dxf_viewer/rendering/dxf_linetype_helper.dart';
import '../models/architect_overhang.dart';
import 'architect_canvas_palette.dart';

/// Canvas painter helper for rendering upper storey erkers (еркери) and balconies (балкони)
/// with thin dashed lines on the active storey floor plan.
class ArchitectOverhangPainterHelper {
  ArchitectOverhangPainterHelper._();

  /// Draws the dashed contour and subtle designation for all detected upper overhangs.
  static void drawOverhangs({
    required Canvas canvas,
    required ArchitectCanvasPalette palette,
    required List<ArchitectOverhang> overhangs,
    required double zoomScale,
    required AppLocalizations? l10n,
    String? selectedElementId,
  }) {
    if (overhangs.isEmpty) return;

    // Standard architectural lineweight for overhead projections (ISO 128)
    final strokeWidth = ArchitectLineWeights.overhead / zoomScale;

    // View-independent paper-space dashed line pattern: 6px dash, 3.5px gap
    final dashLength = 6.0 / zoomScale;
    final gapLength = 3.5 / zoomScale;

    final erkerColor = palette.isDark
        ? const Color(0xFF80DEEA) // Light Cyan
        : const Color(0xFF37474F); // Dark Slate Blue Grey

    final balconyColor = palette.isDark
        ? const Color(0xFFA5D6A7) // Light Mint Green
        : const Color(0xFF2E7D32); // Forest / Slate Green

    for (final overhang in overhangs) {
      architectDrawingSources(canvas, {overhang.id}, 'overhang');
      final isBalcony = overhang.kind == ArchitectOverhangKind.balcony;
      final baseColor = isBalcony ? balconyColor : erkerColor;

      final paint = Paint()
        ..color = baseColor.withValues(alpha: 0.85)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke;

      // Faint tint (4%) to subtly indicate the overhead boundary area
      final fillPaint = Paint()
        ..color = baseColor.withValues(alpha: 0.04)
        ..style = PaintingStyle.fill;

      final Path continuousPath;
      if (overhang.path != null) {
        continuousPath = overhang.path!;
      } else if (overhang.polygon.length >= 3) {
        continuousPath = Path()..addPolygon(overhang.polygon, true);
      } else {
        continue;
      }

      // 1. Draw subtle background tint
      canvas.drawPath(continuousPath, fillPaint);

      // 2. Draw thin dashed line
      final dashedPath = DxfLinetypeHelper.createDashedPath(
        continuousPath,
        [dashLength, gapLength],
      );
      canvas.drawPath(dashedPath, paint);

      // 3. Compact architectural label when zoomed in sufficiently
      if (zoomScale > 14.0 && l10n != null) {
        final labelText = overhang.displayLabel(l10n);
        final depthStr = overhang.overhangDepth > 0.12
            ? ' (${ArchitectTextScope.current?.length(overhang.overhangDepth) ?? '${overhang.overhangDepth.toStringAsFixed(2)}m'})'
            : '';
        final text = '$labelText$depthStr';

        final tp = ArchitectTextPainter(elementId: overhang.id, modelScale: ArchitectPaperStyle.annotationScale,
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: baseColor.withValues(alpha: 0.90),
              fontSize: 10.0,
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final center = overhang.centroid;
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.scale(ArchitectPaperStyle.annotationScale);
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();
      }
    }
  }
}
