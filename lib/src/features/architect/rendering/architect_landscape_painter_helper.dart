import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/architect_hatch_pattern.dart';
import '../models/architect_project.dart';
import 'architect_canvas_palette.dart';
import 'architect_hatch_geometry.dart';

/// Vector paths for a single vegetation item projected into 2D Section or Elevation view.
class ArchitectElevationPlantPaths {
  final Path canopyFill;
  final Path canopyOutline;
  final Path trunkAndBranches;

  const ArchitectElevationPlantPaths({
    required this.canopyFill,
    required this.canopyOutline,
    required this.trunkAndBranches,
  });
}

/// Clean, print-first 2D Plan & 2D Elevation/Section vector graphics for
/// Terrain, Pathways with Automatic Curbs, Site Fences/Gabions, and Vegetation.
class ArchitectLandscapePainterHelper {
  ArchitectLandscapePainterHelper._();

  // ===========================================================================
  // 1. TERRAIN SURFACE IN 2D PLAN (EXISTING & PROPOSED)
  // ===========================================================================

  static void drawTerrain({
    required Canvas canvas,
    required ArchitectProject project,
    required double zoomScale,
    required Set<String> selectedIds,
    ArchitectCanvasPalette palette = const ArchitectCanvasPalette.light(),
  }) {
    if (project.isLayerVisible(ArchitectLayer.terrainExistingLayerId) &&
        !project.existingTerrain.isEmpty) {
      _drawTerrainSurface(
        canvas: canvas,
        project: project,
        surface: project.existingTerrain,
        zoomScale: zoomScale,
        selectedIds: selectedIds,
        isProposed: false,
        palette: palette,
      );
    }

    if (project.isLayerVisible(ArchitectLayer.terrainProposedLayerId) &&
        !project.proposedTerrain.isEmpty) {
      _drawTerrainSurface(
        canvas: canvas,
        project: project,
        surface: project.proposedTerrain,
        zoomScale: zoomScale,
        selectedIds: selectedIds,
        isProposed: true,
        palette: palette,
      );
    }
  }

  static void _drawTerrainSurface({
    required Canvas canvas,
    required ArchitectProject project,
    required ArchitectTerrainSurface surface,
    required double zoomScale,
    required Set<String> selectedIds,
    required bool isProposed,
    required ArchitectCanvasPalette palette,
  }) {
    final primaryColor = isProposed
        ? const Color(0xFF2E6B3E)
        : const Color(0xFF7A5C3E);
    final fillTint = isProposed
        ? const Color(0x0D2E6B3E)
        : const Color(0x087A5C3E);

    // 1. Boundaries / Building Pads
    for (final boundary in surface.boundaries) {
      if (boundary.polygon.length < 3) continue;
      final isSelected = selectedIds.contains(boundary.id);
      final path = _polygonPath(boundary.polygon, closed: true);

      canvas.drawPath(
        path,
        Paint()
          ..color = isSelected
              ? const Color(0x222563EB)
              : (boundary.isHole
                  ? const Color(0x12D97706)
                  : (boundary.isCutoutPad ? const Color(0x14D97706) : fillTint))
          ..style = PaintingStyle.fill,
      );

      final borderPaint = Paint()
        ..color = isSelected
            ? const Color(0xFF2563EB)
            : (boundary.isHole
                ? const Color(0xFFD97706)
                : (boundary.isCutoutPad ? const Color(0xFFB45309) : primaryColor))
        ..strokeWidth = (isSelected ? 2.2 : (isProposed ? 1.6 : 1.2)) / zoomScale
        ..style = PaintingStyle.stroke;

      if (isProposed && !boundary.isCutoutPad && !boundary.isHole) {
        canvas.drawPath(path, borderPaint);
        _drawBoundaryGrassTicks(
          canvas,
          boundary.polygon,
          zoomScale,
          borderPaint.color.withValues(alpha: 0.65),
        );
      } else {
        _drawDashedPath(
          canvas,
          path,
          borderPaint,
          dashLength: boundary.isHole ? 0.60 : 0.45,
          gapLength: boundary.isHole ? 0.25 : 0.22,
        );
      }

      // Label elevation at first vertex
      final bndLabelZ = surface.datumElevation.abs() > 1e-4
          ? (boundary.elevation + surface.datumElevation).toStringAsFixed(2)
          : project.formatLevel(boundary.elevation);
      _drawSmallLabel(
        canvas: canvas,
        text: boundary.isHole
            ? 'ОТВОР $bndLabelZ'
            : '${isProposed ? "ПР." : "СЪЩ."} $bndLabelZ',
        worldPos: boundary.polygon.first + const Offset(0.18, -0.18),
        zoomScale: zoomScale,
        color: borderPaint.color,
      );
    }

    // 2. Contour Iso-lines
    for (final contour in surface.contours) {
      if (contour.points.length < 2) continue;
      final isSelected = selectedIds.contains(contour.id);
      final path = _smoothContourPath(contour.points, closed: contour.closed);
      final strokePaint = Paint()
        ..color = isSelected ? const Color(0xFF2563EB) : primaryColor
        ..strokeWidth = (isSelected ? 2.0 : (isProposed ? 1.25 : 1.0)) / zoomScale
        ..style = PaintingStyle.stroke;

      if (isProposed) {
        canvas.drawPath(path, strokePaint);
      } else {
        _drawDashedPath(
          canvas,
          path,
          strokePaint,
          dashLength: 0.35,
          gapLength: 0.18,
        );
      }

      final midIdx = contour.points.length ~/ 2;
      final cntLabelZ = surface.datumElevation.abs() > 1e-4
          ? (contour.elevation + surface.datumElevation).toStringAsFixed(2)
          : project.formatLevel(contour.elevation);
      _drawSmallLabel(
        canvas: canvas,
        text: contour.isMajor ? '$cntLabelZ [Г]' : cntLabelZ,
        worldPos: contour.points[midIdx],
        zoomScale: zoomScale,
        color: strokePaint.color,
      );
    }

    // 3. Spot Elevations
    final crossRadius = (4.5 / zoomScale).clamp(0.08, 0.28);
    for (final spot in surface.spots) {
      final isSelected = selectedIds.contains(spot.id);
      final color = isSelected ? const Color(0xFF2563EB) : primaryColor;
      final p = spot.position;
      final spotPaint = Paint()
        ..color = color
        ..strokeWidth = (isSelected ? 1.8 : 1.2) / zoomScale
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(p.dx - crossRadius, p.dy),
        Offset(p.dx + crossRadius, p.dy),
        spotPaint,
      );
      canvas.drawLine(
        Offset(p.dx, p.dy - crossRadius),
        Offset(p.dx, p.dy + crossRadius),
        spotPaint,
      );
      if (isProposed) {
        canvas.drawCircle(p, crossRadius * 0.72, spotPaint);
      }

      final spotLabelZ = surface.datumElevation.abs() > 1e-4
          ? (spot.elevation + surface.datumElevation).toStringAsFixed(2)
          : project.formatLevel(spot.elevation);
      _drawSmallLabel(
        canvas: canvas,
        text: spotLabelZ,
        worldPos: p + Offset(crossRadius * 1.2, -crossRadius * 0.9),
        zoomScale: zoomScale,
        color: color,
      );
    }
  }

  static void _drawBoundaryGrassTicks(
    Canvas canvas,
    List<Offset> polygon,
    double zoomScale,
    Color color,
  ) {
    final tickPaint = Paint()
      ..color = color
      ..strokeWidth = 0.9 / zoomScale
      ..style = PaintingStyle.stroke;
    const step = 1.6;
    const tickLen = 0.18;
    for (int i = 0; i < polygon.length; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % polygon.length];
      final d = b - a;
      final len = d.distance;
      if (len < 0.4) continue;
      final u = d / len;
      final n = Offset(-u.dy, u.dx);
      for (double s = step * 0.5; s < len - 0.2; s += step) {
        final base = a + u * s;
        canvas.drawLine(base, base + n * tickLen + u * (tickLen * 0.35), tickPaint);
        canvas.drawLine(
          base + u * 0.10,
          base + u * 0.10 + n * (tickLen * 0.75) - u * (tickLen * 0.25),
          tickPaint,
        );
      }
    }
  }

  // ===========================================================================
  // 2. PATHWAYS WITH AUTOMATIC CURBS IN 2D PLAN
  // ===========================================================================

  static void drawPathways({
    required Canvas canvas,
    required ArchitectProject project,
    required ArchitectStorey storey,
    required double zoomScale,
    required Set<String> selectedIds,
    ArchitectCanvasPalette palette = const ArchitectCanvasPalette.light(),
  }) {
    final visiblePathways = storey.pathways
        .where(
          (p) =>
              p.points.length >= 2 &&
              project.isElementVisible(p.id, ArchitectLayer.pathwayLayerId),
        )
        .toList();
    if (visiblePathways.isEmpty) return;

    // Build boolean union of all paving interiors so intersecting pathways
    // merge cleanly without curb lines cutting across intersections.
    Path mergedPaving = Path();
    final pathwayPolys = <String, Path>{};
    for (final pathway in visiblePathways) {
      final poly = pathway.pavingPolygon;
      if (poly.length < 3) continue;
      final path = _polygonPath(poly, closed: true);
      pathwayPolys[pathway.id] = path;
      mergedPaving = _safePathOp(PathOperation.union, mergedPaving, path);
    }

    // 1. Draw Paving Fill & Material Hatch
    final unitsPerMm = project.dimensionScale.paperToModel(1.0);
    for (final pathway in visiblePathways) {
      final polyPath = pathwayPolys[pathway.id];
      if (polyPath == null) continue;
      final isSelected = selectedIds.contains(pathway.id);

      canvas.drawPath(
        polyPath,
        Paint()
          ..color = isSelected
              ? const Color(0x242563EB)
              : _pavingFillTint(pathway.material)
          ..style = PaintingStyle.fill,
      );

      final hatchPattern = _pavingHatchPattern(pathway.material);
      if (hatchPattern != null && unitsPerMm > 0) {
        final hatchPath = ArchitectHatchGeometry.path(
          boundary: polyPath,
          pattern: hatchPattern,
          unitsPerMm: unitsPerMm,
          scale: pathway.material == ArchitectPavingMaterial.stoneSlabs
              ? 1.8
              : 1.1,
        );
        canvas.save();
        canvas.clipPath(polyPath);
        canvas.drawPath(
          hatchPath,
          Paint()
            ..color = const Color(0xFF475569).withValues(alpha: 0.42)
            ..strokeWidth = 0.75 / zoomScale
            ..style = PaintingStyle.stroke,
        );
        canvas.restore();
      }
    }

    // 2. Draw Automatic Left/Right Curbs (clipped against mergedPaving so T-junctions are clean)
    for (final pathway in visiblePathways) {
      final isSelected = selectedIds.contains(pathway.id);
      final curbFillPaint = Paint()
        ..color = isSelected
            ? const Color(0x382563EB)
            : const Color(0xFFD6D3D1).withValues(alpha: 0.65)
        ..style = PaintingStyle.fill;
      final curbStrokePaint = Paint()
        ..color = isSelected
            ? const Color(0xFF2563EB)
            : const Color(0xFF334155)
        ..strokeWidth = (isSelected ? 1.8 : 1.15) / zoomScale
        ..style = PaintingStyle.stroke;

      for (final curbPoly in [
        pathway.leftCurbPolygon,
        pathway.rightCurbPolygon,
      ]) {
        if (curbPoly.length < 3) continue;
        final rawCurb = _polygonPath(curbPoly, closed: true);
        final clippedCurb = _safePathOp(
          PathOperation.difference,
          rawCurb,
          mergedPaving,
        );
        canvas.drawPath(clippedCurb, curbFillPaint);
        canvas.drawPath(clippedCurb, curbStrokePaint);

        // Draw perpendicular curb stone joints every 1.0 m
        final halfLen = curbPoly.length ~/ 2;
        if (halfLen >= 2) {
          canvas.save();
          canvas.clipPath(clippedCurb);
          _drawCurbJointTicks(
            canvas: canvas,
            innerEdge: curbPoly.sublist(0, halfLen),
            outerEdge: curbPoly.sublist(halfLen).reversed.toList(),
            zoomScale: zoomScale,
            color: curbStrokePaint.color.withValues(alpha: 0.65),
          );
          canvas.restore();
        }
      }
    }

    // 3. Draw Merged Paving Seam Outline
    canvas.drawPath(
      mergedPaving,
      Paint()
        ..color = const Color(0xFF334155)
        ..strokeWidth = 1.1 / zoomScale
        ..style = PaintingStyle.stroke,
    );
  }

  static void _drawCurbJointTicks({
    required Canvas canvas,
    required List<Offset> innerEdge,
    required List<Offset> outerEdge,
    required double zoomScale,
    required Color color,
  }) {
    final count = math.min(innerEdge.length, outerEdge.length);
    if (count < 2) return;
    final jointPaint = Paint()
      ..color = color
      ..strokeWidth = 0.75 / zoomScale
      ..style = PaintingStyle.stroke;
    const jointSpacing = 1.0;
    for (int i = 0; i < count - 1; i++) {
      final aIn = innerEdge[i];
      final bIn = innerEdge[i + 1];
      final aOut = outerEdge[i];
      final bOut = outerEdge[i + 1];
      final segLen = (bIn - aIn).distance;
      if (segLen < 0.25) continue;
      for (double d = jointSpacing; d < segLen - 0.15; d += jointSpacing) {
        final t = d / segLen;
        final p1 = Offset.lerp(aIn, bIn, t)!;
        final p2 = Offset.lerp(aOut, bOut, t)!;
        canvas.drawLine(p1, p2, jointPaint);
      }
    }
  }

  static Color _pavingFillTint(ArchitectPavingMaterial material) =>
      switch (material) {
        ArchitectPavingMaterial.stoneSlabs => const Color(0x1494A3B8),
        ArchitectPavingMaterial.cobblePavers => const Color(0x1478716C),
        ArchitectPavingMaterial.timberDecking => const Color(0x16B45309),
        ArchitectPavingMaterial.gravel => const Color(0x12A8A29E),
        ArchitectPavingMaterial.asphalt => const Color(0x18475569),
        ArchitectPavingMaterial.grassGrid => const Color(0x1415803D),
      };

  static ArchitectHatchPattern? _pavingHatchPattern(
    ArchitectPavingMaterial material,
  ) => switch (material) {
    ArchitectPavingMaterial.stoneSlabs =>
      ArchitectHatchPattern.presets.firstWhere((p) => p.id == 'cross'),
    ArchitectPavingMaterial.cobblePavers =>
      ArchitectHatchPattern.presets.firstWhere((p) => p.id == 'brick'),
    ArchitectPavingMaterial.timberDecking =>
      ArchitectHatchPattern.presets.firstWhere((p) => p.id == 'wood'),
    ArchitectPavingMaterial.gravel || ArchitectPavingMaterial.asphalt =>
      ArchitectHatchPattern.presets.firstWhere((p) => p.id == 'dots'),
    ArchitectPavingMaterial.grassGrid =>
      ArchitectHatchPattern.presets.firstWhere((p) => p.id == 'diagonalCross'),
  };

  // ===========================================================================
  // 3. SITE FENCES, GABIONS & RETAINING WALLS IN 2D PLAN
  // ===========================================================================

  static void drawSiteFences({
    required Canvas canvas,
    required ArchitectProject project,
    required ArchitectStorey storey,
    required double zoomScale,
    required Set<String> selectedIds,
    ArchitectCanvasPalette palette = const ArchitectCanvasPalette.light(),
  }) {
    for (final fence in storey.siteFences) {
      if (fence.points.length < 2) continue;
      if (!project.isElementVisible(fence.id, ArchitectLayer.pathwayLayerId)) {
        continue;
      }
      _drawSingleSiteFence(
        canvas: canvas,
        fence: fence,
        zoomScale: zoomScale,
        isSelected: selectedIds.contains(fence.id),
      );
    }
  }

  static void _drawSingleSiteFence({
    required Canvas canvas,
    required ArchitectSiteFence fence,
    required double zoomScale,
    required bool isSelected,
  }) {
    final halfT = fence.thickness * 0.5;
    final leftChain = ArchitectPathway.offsetChain(
      fence.points,
      halfT,
      closed: fence.closed,
    );
    final rightChain = ArchitectPathway.offsetChain(
      fence.points,
      -halfT,
      closed: fence.closed,
    );
    final bodyPoly = <Offset>[...leftChain, ...rightChain.reversed];
    if (bodyPoly.length < 3) return;
    final bodyPath = _polygonPath(bodyPoly, closed: true);

    final strokeColor = isSelected
        ? const Color(0xFF2563EB)
        : const Color(0xFF1E293B);
    final fillPaint = Paint()
      ..color = isSelected
          ? const Color(0x282563EB)
          : switch (fence.preset) {
              ArchitectSiteFencePreset.gabionFence ||
              ArchitectSiteFencePreset.gabionRetaining =>
                const Color(0x2278716C),
              ArchitectSiteFencePreset.rcRetaining => const Color(0x2464748B),
              ArchitectSiteFencePreset.piersAndSlats => const Color(0x1CB45309),
              _ => const Color(0x1864748B),
            }
      ..style = PaintingStyle.fill;

    canvas.drawPath(bodyPath, fillPaint);
    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = strokeColor
        ..strokeWidth = (isSelected ? 2.0 : 1.35) / zoomScale
        ..style = PaintingStyle.stroke,
    );

    // Preset-specific internal detail in 2D plan
    final detailPaint = Paint()
      ..color = strokeColor.withValues(alpha: 0.72)
      ..strokeWidth = 0.85 / zoomScale
      ..style = PaintingStyle.stroke;

    switch (fence.preset) {
      case ArchitectSiteFencePreset.gabionFence:
      case ArchitectSiteFencePreset.gabionRetaining:
        // Draw gabion basket compartments & stone cells
        canvas.save();
        canvas.clipPath(bodyPath);
        for (int i = 0; i < fence.points.length - 1; i++) {
          final a = fence.points[i];
          final b = fence.points[i + 1];
          final d = b - a;
          final len = d.distance;
          if (len < 0.1) continue;
          final u = d / len;
          final n = Offset(-u.dy, u.dx);
          for (double s = 0.20; s < len - 0.12; s += 0.28) {
            final center = a + u * s;
            canvas.drawCircle(
              center + n * (halfT * 0.35),
              halfT * 0.32,
              detailPaint,
            );
            canvas.drawCircle(
              center - n * (halfT * 0.35),
              halfT * 0.30,
              detailPaint,
            );
          }
          for (double s = 1.0; s < len - 0.15; s += 1.0) {
            final p = a + u * s;
            canvas.drawLine(p - n * halfT, p + n * halfT, detailPaint);
          }
        }
        canvas.restore();

      case ArchitectSiteFencePreset.rcRetaining:
        // Dashed footing heel line on one side + concrete diagonal ticks
        final heelOffset = ArchitectPathway.offsetChain(
          fence.points,
          halfT + 0.35,
          closed: fence.closed,
        );
        final heelPath = _polygonPath(heelOffset, closed: fence.closed);
        _drawDashedPath(
          canvas,
          heelPath,
          detailPaint,
          dashLength: 0.25,
          gapLength: 0.15,
        );

      case ArchitectSiteFencePreset.modernLouvers:
        // Angled 45-degree louver blades along centerline
        for (int i = 0; i < fence.points.length - 1; i++) {
          final a = fence.points[i];
          final b = fence.points[i + 1];
          final d = b - a;
          final len = d.distance;
          if (len < 0.15) continue;
          final u = d / len;
          final n = Offset(-u.dy, u.dx);
          for (double s = 0.20; s < len - 0.15; s += 0.25) {
            final c = a + u * s;
            canvas.drawLine(
              c - u * 0.06 - n * (halfT * 0.7),
              c + u * 0.06 + n * (halfT * 0.7),
              detailPaint,
            );
          }
        }

      case ArchitectSiteFencePreset.piersAndSlats:
      case ArchitectSiteFencePreset.classicIron:
        // Centerline slat/rail stroke
        final centerPath = _polygonPath(fence.points, closed: fence.closed);
        canvas.drawPath(centerPath, detailPaint);
    }

    // Draw piers / posts for post-based fences
    if (fence.preset != ArchitectSiteFencePreset.rcRetaining &&
        fence.preset != ArchitectSiteFencePreset.gabionRetaining) {
      final pierHalf = switch (fence.preset) {
        ArchitectSiteFencePreset.piersAndSlats => math.max(halfT * 1.3, 0.19),
        ArchitectSiteFencePreset.classicIron => math.max(halfT * 1.25, 0.18),
        ArchitectSiteFencePreset.modernLouvers => math.max(halfT * 1.1, 0.08),
        _ => halfT * 1.05,
      };
      final pierFill = Paint()
        ..color = isSelected
            ? const Color(0xFF93C5FD)
            : const Color(0xFFE2E8F0)
        ..style = PaintingStyle.fill;
      final pierStroke = Paint()
        ..color = strokeColor
        ..strokeWidth = (isSelected ? 1.8 : 1.3) / zoomScale
        ..style = PaintingStyle.stroke;

      for (final (pierCenter, _) in fence.pierPositions) {
        final rect = Rect.fromCenter(
          center: pierCenter,
          width: pierHalf * 2,
          height: pierHalf * 2,
        );
        canvas.drawRect(rect, pierFill);
        canvas.drawRect(rect, pierStroke);
      }
    }
  }

  // ===========================================================================
  // 4. VEGETATION IN 2D PLAN & 2D ELEVATION / SECTION
  // ===========================================================================

  static void drawVegetation({
    required Canvas canvas,
    required ArchitectProject project,
    required ArchitectStorey storey,
    required double zoomScale,
    required Set<String> selectedIds,
    ArchitectCanvasPalette palette = const ArchitectCanvasPalette.light(),
  }) {
    for (final item in storey.vegetation) {
      if (!project.isElementVisible(
        item.id,
        ArchitectLayer.vegetationLayerId,
      )) {
        continue;
      }
      drawPlanVegetationItem(
        canvas: canvas,
        item: item,
        zoomScale: zoomScale,
        isSelected: selectedIds.contains(item.id),
      );
    }
  }

  static void drawPlanVegetationItem({
    required Canvas canvas,
    required ArchitectVegetationItem item,
    required double zoomScale,
    required bool isSelected,
  }) {
    final strokeColor = isSelected
        ? const Color(0xFF2563EB)
        : const Color(0xFF1E3A2F);
    final innerColor = isSelected
        ? const Color(0xFF3B82F6)
        : const Color(0xFF3B5E4C);
    final fillColor = isSelected
        ? const Color(0x222563EB)
        : const Color(0x102E6B3E);

    if (item.species == ArchitectPlantSpecies.trimmedHedge &&
        item.points.length >= 2) {
      _drawPlanHedge(
        canvas: canvas,
        item: item,
        zoomScale: zoomScale,
        strokeColor: strokeColor,
        innerColor: innerColor,
        fillColor: fillColor,
      );
      return;
    }

    final center = item.position;
    final r = (item.crownDiameter * 0.5).clamp(0.25, 12.0);

    // Subtle ground drop-shadow arc (south-east offset, print-safe thin stroke)
    final shadowPaint = Paint()
      ..color = const Color(0x180F172A)
      ..strokeWidth = (r * 0.08).clamp(1.2 / zoomScale, 4.0 / zoomScale)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center + Offset(r * 0.08, r * 0.08), radius: r),
      -math.pi * 0.15,
      math.pi * 0.85,
      false,
      shadowPaint,
    );

    final outlinePaint = Paint()
      ..color = strokeColor
      ..strokeWidth = (isSelected ? 2.0 : 1.35) / zoomScale
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final detailPaint = Paint()
      ..color = innerColor.withValues(alpha: 0.72)
      ..strokeWidth = 0.85 / zoomScale
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(item.rotationRad);

    switch (item.species) {
      case ArchitectPlantSpecies.deciduousCanopy:
        final crown = _scallopedCirclePath(
          radius: r,
          lobes: 12,
          lobeDepth: r * 0.085,
        );
        canvas.drawPath(crown, fillPaint);
        canvas.drawPath(crown, outlinePaint);
        // Delicate architectural branching Y-twigs
        for (int i = 0; i < 6; i++) {
          final a = i * math.pi / 3 + 0.2;
          final mainEnd = Offset(math.cos(a) * r * 0.68, math.sin(a) * r * 0.68);
          final forkBase = Offset(
            math.cos(a) * r * 0.36,
            math.sin(a) * r * 0.36,
          );
          final fork1 = Offset(
            math.cos(a + 0.35) * r * 0.58,
            math.sin(a + 0.35) * r * 0.58,
          );
          final fork2 = Offset(
            math.cos(a - 0.32) * r * 0.52,
            math.sin(a - 0.32) * r * 0.52,
          );
          canvas.drawLine(Offset.zero, mainEnd, detailPaint);
          canvas.drawLine(forkBase, fork1, detailPaint);
          canvas.drawLine(forkBase, fork2, detailPaint);
        }
        canvas.drawCircle(
          Offset.zero,
          (r * 0.06).clamp(0.04, 0.16),
          outlinePaint,
        );

      case ArchitectPlantSpecies.deciduousMinimal:
        final outer = Path()
          ..addOval(Rect.fromCircle(center: Offset.zero, radius: r));
        canvas.drawPath(outer, fillPaint);
        canvas.drawPath(outer, outlinePaint);
        // Fine perimeter foliage ticks + inner dashed ring + center cross
        for (int i = 0; i < 24; i++) {
          final a = i * (2 * math.pi / 24);
          final rIn = r * (i.isEven ? 0.86 : 0.91);
          canvas.drawLine(
            Offset(math.cos(a) * rIn, math.sin(a) * rIn),
            Offset(math.cos(a) * r, math.sin(a) * r),
            detailPaint,
          );
        }
        final cross = r * 0.14;
        canvas.drawLine(Offset(-cross, 0), Offset(cross, 0), detailPaint);
        canvas.drawLine(Offset(0, -cross), Offset(0, cross), detailPaint);

      case ArchitectPlantSpecies.coniferPine:
        final outerStar = _starburstPath(
          outerRadius: r,
          innerRadius: r * 0.74,
          points: 18,
        );
        final innerStar = _starburstPath(
          outerRadius: r * 0.56,
          innerRadius: r * 0.38,
          points: 12,
          phaseRad: 0.18,
        );
        canvas.drawPath(outerStar, fillPaint);
        canvas.drawPath(outerStar, outlinePaint);
        canvas.drawPath(innerStar, detailPaint);
        canvas.drawCircle(Offset.zero, r * 0.08, detailPaint);

      case ArchitectPlantSpecies.columnarCypress:
        final outer = _scallopedCirclePath(
          radius: r,
          lobes: 16,
          lobeDepth: r * 0.06,
        );
        final inner = _scallopedCirclePath(
          radius: r * 0.58,
          lobes: 12,
          lobeDepth: r * 0.05,
        );
        canvas.drawPath(outer, fillPaint);
        canvas.drawPath(outer, outlinePaint);
        canvas.drawPath(inner, detailPaint);
        for (int i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          canvas.drawLine(
            Offset(math.cos(a) * r * 0.18, math.sin(a) * r * 0.18),
            Offset(math.cos(a) * r * 0.55, math.sin(a) * r * 0.55),
            detailPaint,
          );
        }

      case ArchitectPlantSpecies.ornamentalPalm:
        final fronds = Path();
        const frondCount = 7;
        for (int i = 0; i < frondCount; i++) {
          final a = i * (2 * math.pi / frondCount);
          final tip = Offset(math.cos(a) * r, math.sin(a) * r);
          final leftCtrl = Offset(
            math.cos(a - 0.26) * r * 0.62,
            math.sin(a - 0.26) * r * 0.62,
          );
          final rightCtrl = Offset(
            math.cos(a + 0.26) * r * 0.62,
            math.sin(a + 0.26) * r * 0.62,
          );
          fronds.moveTo(0, 0);
          fronds.quadraticBezierTo(leftCtrl.dx, leftCtrl.dy, tip.dx, tip.dy);
          fronds.quadraticBezierTo(rightCtrl.dx, rightCtrl.dy, 0, 0);
          canvas.drawLine(Offset.zero, tip * 0.92, detailPaint);
        }
        canvas.drawPath(fronds, fillPaint);
        canvas.drawPath(fronds, outlinePaint);
        canvas.drawCircle(Offset.zero, r * 0.11, outlinePaint);

      case ArchitectPlantSpecies.shrubCluster:
        final subCenters = [
          Offset(-r * 0.26, -r * 0.16),
          Offset(r * 0.28, -r * 0.12),
          Offset(0, r * 0.26),
        ];
        final radii = [r * 0.64, r * 0.58, r * 0.62];
        Path combined = Path();
        for (int i = 0; i < subCenters.length; i++) {
          final bush = _scallopedCirclePath(
            radius: radii[i],
            lobes: 10,
            lobeDepth: radii[i] * 0.09,
          ).shift(subCenters[i]);
          combined = _safePathOp(PathOperation.union, combined, bush);
        }
        canvas.drawPath(combined, fillPaint);
        canvas.drawPath(combined, outlinePaint);
        for (final c in subCenters) {
          for (int k = 0; k < 5; k++) {
            final a = k * (2 * math.pi / 5);
            canvas.drawLine(
              c,
              c + Offset(math.cos(a) * r * 0.25, math.sin(a) * r * 0.25),
              detailPaint,
            );
          }
        }

      case ArchitectPlantSpecies.trimmedHedge:
        final crown = _scallopedCirclePath(
          radius: r,
          lobes: 12,
          lobeDepth: r * 0.08,
        );
        canvas.drawPath(crown, fillPaint);
        canvas.drawPath(crown, outlinePaint);

      case ArchitectPlantSpecies.artisticLowPoly:
        // Stylized 7-sided faceted polygon crown with internal faceted triangulation
        final polyPath = Path();
        const facetSides = 7;
        final outerPts = <Offset>[];
        for (int i = 0; i < facetSides; i++) {
          final a = i * (2 * math.pi / facetSides) - math.pi / 2;
          final facetR = r * (i.isEven ? 1.0 : 0.88);
          outerPts.add(Offset(math.cos(a) * facetR, math.sin(a) * facetR));
        }
        polyPath.addPolygon(outerPts, true);
        canvas.drawPath(polyPath, fillPaint);
        canvas.drawPath(polyPath, outlinePaint);
        for (final p in outerPts) {
          canvas.drawLine(Offset.zero, p, detailPaint);
        }
        canvas.drawCircle(Offset.zero, (r * 0.12).clamp(0.06, 0.22), outlinePaint);
    }

    canvas.restore();
  }

  static void _drawPlanHedge({
    required Canvas canvas,
    required ArchitectVegetationItem item,
    required double zoomScale,
    required Color strokeColor,
    required Color innerColor,
    required Color fillColor,
  }) {
    final halfW = (item.hedgeWidth * 0.5).clamp(0.15, 2.0);
    final left = ArchitectPathway.offsetChain(item.points, halfW);
    final right = ArchitectPathway.offsetChain(item.points, -halfW);
    final poly = <Offset>[...left, ...right.reversed];
    if (poly.length < 3) return;
    final path = _polygonPath(poly, closed: true);

    canvas.drawPath(
      path,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = strokeColor
        ..strokeWidth = 1.35 / zoomScale
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );

    // Center woody stem + diagonal foliage texture ticks inside hedge
    final detailPaint = Paint()
      ..color = innerColor.withValues(alpha: 0.65)
      ..strokeWidth = 0.85 / zoomScale
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < item.points.length - 1; i++) {
      final a = item.points[i];
      final b = item.points[i + 1];
      final d = b - a;
      final len = d.distance;
      if (len < 0.1) continue;
      final u = d / len;
      final n = Offset(-u.dy, u.dx);
      canvas.drawLine(a, b, detailPaint);
      for (double s = 0.25; s < len - 0.15; s += 0.35) {
        final base = a + u * s;
        canvas.drawLine(
          base,
          base + u * (halfW * 0.45) + n * (halfW * 0.72),
          detailPaint,
        );
        canvas.drawLine(
          base + u * 0.12,
          base + u * (0.12 + halfW * 0.45) - n * (halfW * 0.72),
          detailPaint,
        );
      }
    }
  }

  /// Generates clean, architectural 2D vector elevation/section paths for a plant
  /// centered at `(stationX, groundZ)` in section/elevation view space `(x, z)`.
  static ArchitectElevationPlantPaths buildElevationPlantPaths({
    required ArchitectVegetationItem item,
    required double stationX,
    required double groundZ,
    double? projectedSpanWidth,
  }) {
    final canopyFill = Path();
    final canopyOutline = Path();
    final trunkAndBranches = Path();

    final h = item.height.clamp(0.4, 25.0);
    final w = (projectedSpanWidth ?? item.crownDiameter).clamp(0.4, 20.0);
    final halfW = w * 0.5;

    switch (item.species) {
      case ArchitectPlantSpecies.deciduousCanopy:
      case ArchitectPlantSpecies.deciduousMinimal:
        final trunkTopZ = groundZ + h * 0.38;
        final crownCenterZ = groundZ + h * 0.62;
        final rx = halfW;
        final ry = h * 0.38;
        final trunkHalfW = (w * 0.045).clamp(0.04, 0.18);

        // Trunk + Y-branches
        trunkAndBranches.moveTo(stationX - trunkHalfW, groundZ);
        trunkAndBranches.lineTo(stationX - trunkHalfW * 0.7, trunkTopZ);
        trunkAndBranches.lineTo(stationX + trunkHalfW * 0.7, trunkTopZ);
        trunkAndBranches.lineTo(stationX + trunkHalfW, groundZ);

        trunkAndBranches.moveTo(stationX, groundZ + h * 0.26);
        trunkAndBranches.lineTo(stationX - rx * 0.42, crownCenterZ + ry * 0.15);
        trunkAndBranches.moveTo(stationX, groundZ + h * 0.30);
        trunkAndBranches.lineTo(stationX + rx * 0.40, crownCenterZ + ry * 0.20);
        trunkAndBranches.moveTo(stationX, trunkTopZ);
        trunkAndBranches.lineTo(stationX, crownCenterZ + ry * 0.48);

        if (item.species == ArchitectPlantSpecies.deciduousMinimal) {
          final oval = Rect.fromCenter(
            center: Offset(stationX, crownCenterZ),
            width: rx * 2,
            height: ry * 2,
          );
          canopyFill.addOval(oval);
          canopyOutline.addOval(oval);
        } else {
          final cloud = _elevationScallopedCrown(
            centerX: stationX,
            centerZ: crownCenterZ,
            rx: rx,
            ry: ry,
            lobes: 12,
          );
          canopyFill.addPath(cloud, Offset.zero);
          canopyOutline.addPath(cloud, Offset.zero);
        }

      case ArchitectPlantSpecies.coniferPine:
        final trunkTopZ = groundZ + h * 0.22;
        final trunkHalfW = (w * 0.04).clamp(0.04, 0.15);
        trunkAndBranches.addRect(
          Rect.fromLTRB(
            stationX - trunkHalfW,
            groundZ,
            stationX + trunkHalfW,
            trunkTopZ,
          ),
        );
        // 4 tiered conifer boughs
        const tiers = 4;
        for (int t = 0; t < tiers; t++) {
          final frac = t / tiers;
          final tierBottomZ = groundZ + h * (0.16 + frac * 0.56);
          final tierTopZ = groundZ + h * (0.45 + frac * 0.55);
          final tierHalfW = halfW * (1.0 - frac * 0.58);
          final tierPath = Path()
            ..moveTo(stationX, tierTopZ)
            ..lineTo(stationX - tierHalfW, tierBottomZ)
            ..quadraticBezierTo(
              stationX,
              tierBottomZ - h * 0.04,
              stationX + tierHalfW,
              tierBottomZ,
            )
            ..close();
          canopyFill.addPath(tierPath, Offset.zero);
          canopyOutline.addPath(tierPath, Offset.zero);
        }

      case ArchitectPlantSpecies.columnarCypress:
        final baseZ = groundZ + h * 0.06;
        final trunkHalfW = (w * 0.05).clamp(0.03, 0.10);
        trunkAndBranches.addRect(
          Rect.fromLTRB(
            stationX - trunkHalfW,
            groundZ,
            stationX + trunkHalfW,
            baseZ,
          ),
        );
        final flame = Path()
          ..moveTo(stationX, groundZ + h)
          ..cubicTo(
            stationX - halfW * 0.85,
            groundZ + h * 0.72,
            stationX - halfW * 1.05,
            groundZ + h * 0.25,
            stationX - halfW * 0.45,
            baseZ,
          )
          ..lineTo(stationX + halfW * 0.45, baseZ)
          ..cubicTo(
            stationX + halfW * 1.05,
            groundZ + h * 0.25,
            stationX + halfW * 0.85,
            groundZ + h * 0.72,
            stationX,
            groundZ + h,
          )
          ..close();
        canopyFill.addPath(flame, Offset.zero);
        canopyOutline.addPath(flame, Offset.zero);

      case ArchitectPlantSpecies.ornamentalPalm:
        final crownZ = groundZ + h * 0.76;
        final trunkW = (w * 0.055).clamp(0.05, 0.18);
        trunkAndBranches.moveTo(stationX - trunkW, groundZ);
        trunkAndBranches.quadraticBezierTo(
          stationX + trunkW * 0.5,
          groundZ + h * 0.38,
          stationX - trunkW * 0.4,
          crownZ,
        );
        trunkAndBranches.lineTo(stationX + trunkW * 0.4, crownZ);
        trunkAndBranches.quadraticBezierTo(
          stationX + trunkW * 1.3,
          groundZ + h * 0.38,
          stationX + trunkW,
          groundZ,
        );
        trunkAndBranches.close();

        for (final angle in [-1.15, -0.65, -0.20, 0.20, 0.65, 1.15]) {
          final tipX = stationX + math.sin(angle) * halfW;
          final tipZ = crownZ + math.cos(angle * 0.8) * (h * 0.22) -
              angle.abs() * (h * 0.10);
          final ctrlX = stationX + math.sin(angle) * halfW * 0.55;
          final ctrlZ = crownZ + h * 0.24;
          final frond = Path()
            ..moveTo(stationX, crownZ)
            ..quadraticBezierTo(ctrlX, ctrlZ, tipX, tipZ)
            ..quadraticBezierTo(
              ctrlX,
              ctrlZ - h * 0.06,
              stationX,
              crownZ - h * 0.02,
            )
            ..close();
          canopyFill.addPath(frond, Offset.zero);
          canopyOutline.addPath(frond, Offset.zero);
        }

      case ArchitectPlantSpecies.artisticLowPoly:
        final trunkTopZ = groundZ + h * 0.42;
        final crownBaseZ = groundZ + h * 0.35;
        final crownTopZ = groundZ + h;
        final trunkW = (w * 0.05).clamp(0.05, 0.16);

        // Low-poly faceted tapered trunk with root flare buttresses
        trunkAndBranches.moveTo(stationX - trunkW * 1.8, groundZ);
        trunkAndBranches.lineTo(stationX - trunkW * 0.6, trunkTopZ);
        trunkAndBranches.lineTo(stationX + trunkW * 0.6, trunkTopZ);
        trunkAndBranches.lineTo(stationX + trunkW * 1.8, groundZ);
        trunkAndBranches.close();

        // Faceted low-poly crown contour
        final crownPoly = Path()
          ..moveTo(stationX, crownTopZ)
          ..lineTo(stationX + halfW * 0.82, groundZ + h * 0.80)
          ..lineTo(stationX + halfW, groundZ + h * 0.55)
          ..lineTo(stationX + halfW * 0.45, crownBaseZ)
          ..lineTo(stationX - halfW * 0.45, crownBaseZ)
          ..lineTo(stationX - halfW, groundZ + h * 0.52)
          ..lineTo(stationX - halfW * 0.85, groundZ + h * 0.78)
          ..close();
        canopyFill.addPath(crownPoly, Offset.zero);
        canopyOutline.addPath(crownPoly, Offset.zero);

      case ArchitectPlantSpecies.shrubCluster:
      case ArchitectPlantSpecies.trimmedHedge:
        final rRect = RRect.fromRectAndCorners(
          Rect.fromLTRB(
            stationX - halfW,
            groundZ,
            stationX + halfW,
            groundZ + h,
          ),
          topLeft: Radius.circular(
            item.species == ArchitectPlantSpecies.trimmedHedge
                ? h * 0.18
                : h * 0.55,
          ),
          topRight: Radius.circular(
            item.species == ArchitectPlantSpecies.trimmedHedge
                ? h * 0.18
                : h * 0.55,
          ),
        );
        canopyFill.addRRect(rRect);
        canopyOutline.addRRect(rRect);
    }

    return ArchitectElevationPlantPaths(
      canopyFill: canopyFill,
      canopyOutline: canopyOutline,
      trunkAndBranches: trunkAndBranches,
    );
  }

  // ===========================================================================
  // 5. ACTIVE DRAFTING PREVIEW IN 2D PLAN
  // ===========================================================================

  static void drawActiveLandscapeDraft({
    required Canvas canvas,
    required List<Offset> draftPoints,
    required Offset? cursorWorld,
    required double zoomScale,
    required Color accentColor,
    double previewWidth = 0.0,
    bool showCurbs = false,
    double curbWidth = 0.15,
    double? previewRadius,
  }) {
    final pts = <Offset>[
      ...draftPoints,
      if (cursorWorld != null &&
          (draftPoints.isEmpty ||
              (draftPoints.last - cursorWorld).distance > 1e-4))
        cursorWorld,
    ];

    final strokePaint = Paint()
      ..color = accentColor
      ..strokeWidth = 1.8 / zoomScale
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    if (previewRadius != null && cursorWorld != null && draftPoints.isEmpty) {
      canvas.drawCircle(cursorWorld, previewRadius, fillPaint);
      canvas.drawCircle(cursorWorld, previewRadius, strokePaint);
      return;
    }

    if (pts.isEmpty) return;

    if (pts.length >= 2 && previewWidth > 0.05) {
      final halfW = previewWidth * 0.5;
      final left = ArchitectPathway.offsetChain(pts, halfW);
      final right = ArchitectPathway.offsetChain(pts, -halfW);
      final poly = <Offset>[...left, ...right.reversed];
      final path = _polygonPath(poly, closed: true);
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, strokePaint);

      if (showCurbs && curbWidth > 0.01) {
        final leftOuter = ArchitectPathway.offsetChain(pts, halfW + curbWidth);
        final rightOuter = ArchitectPathway.offsetChain(
          pts,
          -(halfW + curbWidth),
        );
        final curbPaint = Paint()
          ..color = accentColor.withValues(alpha: 0.65)
          ..strokeWidth = 1.1 / zoomScale
          ..style = PaintingStyle.stroke;
        canvas.drawPath(_polygonPath(leftOuter, closed: false), curbPaint);
        canvas.drawPath(_polygonPath(rightOuter, closed: false), curbPaint);
      }
    } else if (pts.length >= 2) {
      final path = _polygonPath(pts, closed: false);
      _drawDashedPath(
        canvas,
        path,
        strokePaint,
        dashLength: 0.30,
        gapLength: 0.15,
      );
    }

    final handleRadius = 4.0 / zoomScale;
    final dotPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;
    for (final p in pts) {
      canvas.drawCircle(p, handleRadius, dotPaint);
    }
  }

  // ===========================================================================
  // INTERNAL GEOMETRY & VECTOR HELPERS
  // ===========================================================================

  static Path _polygonPath(List<Offset> pts, {required bool closed}) {
    final path = Path();
    if (pts.isEmpty) return path;
    path.moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    if (closed && pts.length >= 3) path.close();
    return path;
  }

  static Path _smoothContourPath(List<Offset> pts, {required bool closed}) {
    if (pts.length < 3) return _polygonPath(pts, closed: closed);
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 0; i < pts.length - 1; i++) {
      final p0 = pts[i];
      final p1 = pts[i + 1];
      final mid = Offset((p0.dx + p1.dx) * 0.5, (p0.dy + p1.dy) * 0.5);
      if (i == 0) {
        path.lineTo(mid.dx, mid.dy);
      } else {
        path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
      }
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    if (closed) path.close();
    return path;
  }

  static Path _scallopedCirclePath({
    required double radius,
    required int lobes,
    required double lobeDepth,
  }) {
    final path = Path();
    final step = (2 * math.pi) / lobes;
    final rVal = radius - lobeDepth;
    final start = Offset(rVal, 0);
    path.moveTo(start.dx, start.dy);
    for (int i = 0; i < lobes; i++) {
      final aMid = (i + 0.5) * step;
      final aEnd = (i + 1) * step;
      final ctrl = Offset(
        math.cos(aMid) * (radius + lobeDepth * 0.8),
        math.sin(aMid) * (radius + lobeDepth * 0.8),
      );
      final end = Offset(math.cos(aEnd) * rVal, math.sin(aEnd) * rVal);
      path.quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);
    }
    path.close();
    return path;
  }

  static Path _elevationScallopedCrown({
    required double centerX,
    required double centerZ,
    required double rx,
    required double ry,
    required int lobes,
  }) {
    final path = Path();
    final step = (2 * math.pi) / lobes;
    path.moveTo(centerX + rx * 0.92, centerZ);
    for (int i = 0; i < lobes; i++) {
      final aMid = (i + 0.5) * step;
      final aEnd = (i + 1) * step;
      final ctrl = Offset(
        centerX + math.cos(aMid) * rx * 1.08,
        centerZ + math.sin(aMid) * ry * 1.08,
      );
      final end = Offset(
        centerX + math.cos(aEnd) * rx * 0.92,
        centerZ + math.sin(aEnd) * ry * 0.92,
      );
      path.quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);
    }
    path.close();
    return path;
  }

  static Path _starburstPath({
    required double outerRadius,
    required double innerRadius,
    required int points,
    double phaseRad = 0.0,
  }) {
    final path = Path();
    final step = math.pi / points;
    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? outerRadius : innerRadius;
      final a = phaseRad + i * step;
      final p = Offset(math.cos(a) * r, math.sin(a) * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  static void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dashLength,
    required double gapLength,
  }) {
    final dashed = Path();
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dashLength, metric.length);
        dashed.addPath(metric.extractPath(distance, next), Offset.zero);
        distance = next + gapLength;
      }
    }
    canvas.drawPath(dashed, paint);
  }

  static void _drawSmallLabel({
    required Canvas canvas,
    required String text,
    required Offset worldPos,
    required double zoomScale,
    required Color color,
  }) {
    final fontSize = (10.5 / zoomScale).clamp(0.12, 0.42);
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, worldPos);
  }

  static Path _safePathOp(PathOperation op, Path a, Path b) {
    try {
      return Path.combine(op, a, b);
    } catch (_) {
      return a;
    }
  }
}
