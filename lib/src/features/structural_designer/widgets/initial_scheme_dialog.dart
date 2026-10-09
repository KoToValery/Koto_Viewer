import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/structural_element.dart';
import '../models/wall_axis_models.dart';
import '../models/seismic_analysis_models.dart';
import '../analysis/initial_scheme_generator.dart';
import '../analysis/seismic_analysis_calculator.dart';
import '../analysis/wall_axis_detector.dart';
import '../analysis/geometric_window_detector.dart';
import 'seismic_analysis_sheet.dart';

class InitialSchemeDialog extends StatefulWidget {
  final StructuralProject project;
  final List<WallPairCandidate> pairs;
  final List<(Offset, Offset)> closureSegments;
  final List<GeometricWindowOpening> wallOpenings;
  final double scale;
  final InitialSchemeOptions options;
  const InitialSchemeDialog({
    super.key,
    required this.project,
    required this.pairs,
    this.closureSegments = const [],
    this.wallOpenings = const [],
    required this.scale,
    required this.options,
  });
  @override
  State<InitialSchemeDialog> createState() => _InitialSchemeDialogState();
}

class _InitialSchemeDialogState extends State<InitialSchemeDialog> {
  late final min = TextEditingController(
    text: widget.options.minSpacingM.toString(),
  );
  late final target = TextEditingController(
    text: widget.options.targetSpacingM.toString(),
  );
  late final maxWallLength = TextEditingController(
    text: widget.options.effectiveMaxWallLengthM.toString(),
  );
  late bool enforcePaired = widget.options.enforcePairedWalls;
  late bool generousDensity = widget.options.generousDensity;
  late bool adaptiveSizes = widget.options.adaptiveSizes;
  late final List<(Offset, Offset)> effectiveClosureSegments =
      widget.closureSegments.isNotEmpty
      ? widget.closureSegments
      : WallAxisDetector.computeClosureSegmentsForPairs(widget.pairs);
  InitialSchemeProposal proposal = const InitialSchemeProposal();
  SeismicAnalysisReport report = SeismicAnalysisReport.empty;
  final seenLayouts = <String>{};
  int nextVariant = 0, displayedVariant = 0;
  bool noAlternative = false;
  bool confirmed = false, error = false, dirty = false;
  @override
  void initState() {
    super.initState();
    rebuild();
  }

  @override
  void dispose() {
    min.dispose();
    target.dispose();
    maxWallLength.dispose();
    super.dispose();
  }

  void rebuild() {
    final o = widget.options;
    final options = InitialSchemeOptions(
      minSpacingM: double.tryParse(min.text.replaceAll(',', '.')) ?? 0,
      targetSpacingM: double.tryParse(target.text.replaceAll(',', '.')) ?? 0,
      columnShape: o.columnShape,
      columnThicknessM: o.columnThicknessM,
      wallLengthM: o.wallLengthM,
      maxWallLengthM:
          double.tryParse(maxWallLength.text.replaceAll(',', '.')) ?? 0,
      wallThicknessM: o.wallThicknessM,
      columnWidthM: o.columnWidthM,
      columnDepthM: o.columnDepthM,
      enforcePairedWalls: enforcePaired,
      generousDensity: generousDensity,
      adaptiveSizes: adaptiveSizes,
    );
    if (!options.valid) {
      error = true;
      return;
    }
    if (dirty) {
      seenLayouts.clear();
      nextVariant = 0;
      displayedVariant = 0;
    }
    noAlternative = true;
    // Do not label identical layouts as a new alternative. The search is bounded.
    for (var attempt = 0; attempt < 12; attempt++) {
      final candidate = InitialSchemeGenerator.generate(
        project: widget.project,
        wallPairs: widget.pairs,
        wallOpenings: widget.wallOpenings,
        scale: widget.scale,
        options: options,
        variant: nextVariant++,
      );
      // Ignore changes below 5 cm when identifying a different layout.
      String position(Offset p) =>
          '${(p.dx / widget.scale / .05).round()},${(p.dy / widget.scale / .05).round()}';
      final ids = [
        ...candidate.columns.map(
          (c) =>
              'c:${position(c.center)}:${(c.width / widget.scale / .05).round()}:${(c.height / widget.scale / .05).round()}',
        ),
        ...candidate.walls.map(
          (w) =>
              'w:${position(w.start)}:${position(w.end)}:${(w.thickness / widget.scale / .05).round()}',
        ),
      ]..sort();
      if (!seenLayouts.add(ids.join('|'))) continue;
      proposal = candidate;
      displayedVariant++;
      noAlternative = false;
      report = SeismicAnalysisCalculator.analyzeProject(
        widget.project.copyWith(
          storeys: [
            for (final f in widget.project.storeys)
              f.id == widget.project.activeStorey.id ? proposal.apply(f) : f,
          ],
        ),
        cadUnitsPerMeter: widget.scale,
      );
      break;
    }
    confirmed = false;
    error = false;
    dirty = false;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = proposal;
    final sectionCounts = <String, int>{};
    for (final c in p.columns) {
      final section =
          '${(c.width / widget.scale * 100).round()}×${(c.height / widget.scale * 100).round()} cm';
      sectionCounts.update(section, (n) => n + 1, ifAbsent: () => 1);
    }
    final wallSections = <String, int>{};
    for (final w in p.walls) {
      final section =
          '${(w.thickness / widget.scale * 100).round()} cm × ${(w.length / widget.scale).toStringAsFixed(2)} m';
      wallSections.update(section, (n) => n + 1, ifAbsent: () => 1);
    }
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.schemePreview,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                p.continuationSource == null
                    ? l.schemeFresh
                    : l.schemeContinueLower(p.continuationSource!),
              ),
              if ((p.rejectionReasons['continuity'] ?? 0) > 0)
                Text(
                  l.schemeContinuityReview,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (p.continuationSource == null) ...[
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: 180,
                      child: TextField(
                        controller: min,
                        onChanged: (_) => setState(() {
                          dirty = true;
                          confirmed = false;
                        }),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: l.schemeMinSpacing,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: TextField(
                        controller: target,
                        onChanged: (_) => setState(() {
                          dirty = true;
                          confirmed = false;
                        }),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: l.schemeTargetSpacing,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: TextField(
                        key: const ValueKey('scheme-max-wall-length'),
                        controller: maxWallLength,
                        onChanged: (_) => setState(() {
                          dirty = true;
                          confirmed = false;
                        }),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: l.schemeMaxWallLength,
                        ),
                      ),
                    ),
                    TextButton(
                      key: const ValueKey('next-scheme'),
                      onPressed: () => setState(rebuild),
                      child: Text(l.schemeRebuild),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: enforcePaired,
                  onChanged: (v) => setState(() {
                    enforcePaired = v;
                    dirty = true;
                    confirmed = false;
                    rebuild();
                  }),
                  title: Text(l.schemePairedWalls),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: generousDensity,
                  onChanged: (v) => setState(() {
                    generousDensity = v;
                    dirty = true;
                    confirmed = false;
                    rebuild();
                  }),
                  title: Text(l.schemeGenerousDensity),
                ),
                SwitchListTile(
                  key: const ValueKey('adaptive-scheme-sizes'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: adaptiveSizes,
                  onChanged: (v) => setState(() {
                    adaptiveSizes = v;
                    dirty = true;
                    confirmed = false;
                    rebuild();
                  }),
                  title: Text(l.schemeAdaptiveSizes),
                ),
              ],
              if (error)
                Text(
                  l.schemeInvalidOptions,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 8),
              if (p.continuationSource == null)
                Text('${l.schemeVariant}: $displayedVariant'),
              Text('${p.columns.length} C · ${p.walls.length} W'),
              if (sectionCounts.isNotEmpty)
                Text(
                  '${l.columns}: ${sectionCounts.entries.map((e) => "${e.key} (${e.value})").join(" · ")}',
                ),
              if (wallSections.isNotEmpty)
                Text(
                  '${l.schemeWallSections}: ${wallSections.entries.map((e) => "${e.key} (${e.value})").join(" · ")}',
                ),
              if (noAlternative) Text(l.schemeNoAlternative),
              SizedBox(
                height: 320,
                width: double.infinity,
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 8,
                  child: CustomPaint(
                    painter: _SchemePainter(
                      widget.project.activeStorey,
                      p,
                      widget.pairs,
                      widget.project.effectiveGridAxes,
                      effectiveClosureSegments,
                    ),
                  ),
                ),
              ),
              Text(
                l.schemeLegend,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (widget.pairs.isEmpty) Text(l.schemeNoWalls),
              if (p.isEmpty) Text(l.schemeNoCandidates),
              if (p.limited) Text(l.schemeLimits),
              if (p.continuationSource != null && p.uncoveredSamples > 0)
                Text(
                  l.schemeBlockedContinuations(p.uncoveredSamples),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              Text('${l.schemeUnresolved}: ${p.unresolvedRegions}'),
              Text('${l.schemeRejected}: ${p.rejectedCandidates}'),
              if (p.continuationSource == null)
                Text(
                  '${l.schemeCoverage}: ${p.uncoveredSamples} · '
                  '${p.maxSupportDistanceM.isFinite ? p.maxSupportDistanceM.toStringAsFixed(2) : '—'} m',
                ),
              Text(l.schemeEurocodeScope),
              Text(
                p.maxSupportSpanM == null
                    ? l.schemeSpanUnknown
                    : '${l.schemeSupportSpan}: ${p.maxSupportSpanM!.toStringAsFixed(2)} m',
                style: TextStyle(
                  color: p.spanCheck?.isDeflectionSafe == true
                      ? Colors.green.shade700
                      : Theme.of(context).colorScheme.error,
                ),
              ),
              if (p.openingColumnIds.isNotEmpty)
                Text(
                  '${l.schemeOpeningFallback}: ${p.openingColumnIds.length}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              Text(
                '${l.schemeWallDensity}: X ${p.wallRatioX.toStringAsFixed(2)}% · Y ${p.wallRatioY.toStringAsFixed(2)}%',
              ),
              if (p.wallDeficitXM2 > 1e-6 || p.wallDeficitYM2 > 1e-6)
                Text(
                  '${l.schemeWallDeficit}: X ${p.wallDeficitXM2.toStringAsFixed(2)} m² · Y ${p.wallDeficitYM2.toStringAsFixed(2)} m²',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (p.resizedColumnIds.isNotEmpty)
                Text('${l.schemeResizedColumns}: ${p.resizedColumnIds.length}'),
              if (p.columnSizingReviewIds.isNotEmpty)
                Text(
                  '${l.schemeSizingReview}: ${p.columnSizingReviewIds.length}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (p.rejectionReasons.isNotEmpty)
                Text(
                  '${l.schemePlacementReasons}: ${l.schemeWallConstraint} ${p.rejectionReasons['wall'] ?? 0} · '
                  '${l.schemeSlabConstraint} ${p.rejectionReasons['slab'] ?? 0} · '
                  '${l.schemeSpacingConstraint} ${(p.rejectionReasons['spacing'] ?? 0) + (p.rejectionReasons['collision'] ?? 0)}',
                ),
              Text(l.schemePreliminary),
              TextButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => SeismicAnalysisSheet(report: report),
                ),
                child: Text(l.schemeReport),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: confirmed,
                onChanged: dirty || error
                    ? null
                    : (v) => setState(() => confirmed = v ?? false),
                title: Text(l.schemeConfirm),
              ),
              Wrap(
                spacing: 12,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l.cancel),
                  ),
                  FilledButton(
                    key: const ValueKey('accept-scheme'),
                    onPressed: confirmed && !dirty && !error && !p.isEmpty
                        ? () => Navigator.pop(context, p)
                        : null,
                    child: Text(l.schemeAccept),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SchemePainter extends CustomPainter {
  final StoreyLevel floor;
  final InitialSchemeProposal proposal;
  final List<WallPairCandidate> pairs;
  final List<(Offset, Offset)> closureSegments;
  final List<StructuralGridAxis> axes;
  _SchemePainter(
    this.floor,
    this.proposal,
    this.pairs,
    this.axes,
    this.closureSegments,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final points = <Offset>[
      ...floor.slabs.expand((s) => s.polygon),
      ...pairs.expand(
        (p) => [
          p.segmentA.start,
          p.segmentA.end,
          p.segmentB.start,
          p.segmentB.end,
        ],
      ),
    ];
    if (points.isEmpty) return;
    final minX = points.map((p) => p.dx).reduce(math.min),
        maxX = points.map((p) => p.dx).reduce(math.max);
    final minY = points.map((p) => p.dy).reduce(math.min),
        maxY = points.map((p) => p.dy).reduce(math.max);
    final scale = math.min(
      (size.width - 24) / math.max(1e-6, maxX - minX),
      (size.height - 24) / math.max(1e-6, maxY - minY),
    );
    Offset screen(Offset p) => Offset(
      12 + (p.dx - minX) * scale,
      size.height - 12 - (p.dy - minY) * scale,
    );
    void draw(List<Offset> poly, Color color, {bool fill = false}) {
      if (poly.isEmpty) return;
      final path = Path()..addPolygon(poly.map(screen).toList(), true);
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 1.5
          ..style = fill ? PaintingStyle.fill : PaintingStyle.stroke,
      );
    }

    final axisPaint = Paint()
      ..color = Colors.blueGrey.withValues(alpha: .3)
      ..strokeWidth = .75;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final axis in axes) {
      canvas.drawLine(screen(axis.start), screen(axis.end), axisPaint);
    }
    canvas.restore();
    // 1. Draw Architectural Walls:
    // Light solid background fill + light diagonal architectural hatch pattern + boundary stroke
    final wallFillPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;
    final wallHatchPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.38)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    final wallLinePaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.70)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    for (final pair in pairs) {
      final sA = pair.segmentA;
      final sB = pair.segmentB;
      final cosA = math.cos(sA.angleRad);
      final sinA = math.sin(sA.angleRad);
      final midA = (sA.start + sA.end) / 2.0;
      final midB = (sB.start + sB.end) / 2.0;
      final dA = -midA.dx * sinA + midA.dy * cosA;
      final dB = -midB.dx * sinA + midB.dy * cosA;
      final t1A = sA.start.dx * cosA + sA.start.dy * sinA;
      final t2A = sA.end.dx * cosA + sA.end.dy * sinA;
      final tMinA = math.min(t1A, t2A);
      final tMaxA = math.max(t1A, t2A);
      final t1B = sB.start.dx * cosA + sB.start.dy * sinA;
      final t2B = sB.end.dx * cosA + sB.end.dy * sinA;
      final tMinB = math.min(t1B, t2B);
      final tMaxB = math.max(t1B, t2B);
      final tStart = math.max(tMinA, tMinB);
      final tEnd = math.min(tMaxA, tMaxB);

      final List<Offset> polyPts;
      if (tEnd > tStart) {
        final pAStart = Offset(
          tStart * cosA - dA * sinA,
          tStart * sinA + dA * cosA,
        );
        final pAEnd = Offset(tEnd * cosA - dA * sinA, tEnd * sinA + dA * cosA);
        final pBEnd = Offset(tEnd * cosA - dB * sinA, tEnd * sinA + dB * cosA);
        final pBStart = Offset(
          tStart * cosA - dB * sinA,
          tStart * sinA + dB * cosA,
        );
        polyPts = [pAStart, pAEnd, pBEnd, pBStart];
      } else {
        polyPts = [sA.start, sA.end, sB.end, sB.start];
      }

      final screenPts = polyPts.map(screen).toList();
      final polyPath = Path()..addPolygon(screenPts, true);

      // Light solid shading
      canvas.drawPath(polyPath, wallFillPaint);

      // Light diagonal architectural hatch (лека щриховка под 45 градуса)
      final bounds = polyPath.getBounds();
      if (bounds.width > 0.5 && bounds.height > 0.5) {
        canvas.save();
        canvas.clipPath(polyPath);
        const double step = 6.0;
        final double startX = bounds.left - bounds.height;
        for (double x = startX; x <= bounds.right; x += step) {
          canvas.drawLine(
            Offset(x, bounds.bottom),
            Offset(x + bounds.height, bounds.top),
            wallHatchPaint,
          );
        }
        canvas.restore();
      }

      // Longitudinal wall face outlines
      canvas.drawLine(screen(sA.start), screen(sA.end), wallLinePaint);
      canvas.drawLine(screen(sB.start), screen(sB.end), wallLinePaint);
    }

    // Perpendicular closing jamb lines at wall openings & free ends
    for (final cap in closureSegments) {
      canvas.drawLine(screen(cap.$1), screen(cap.$2), wallLinePaint);
    }

    // 2. Draw Floor Slabs & Openings
    for (final s in floor.slabs) {
      draw(s.polygon, Colors.blue);
      for (final hole in s.openings) {
        draw(hole, Colors.red);
      }
    }

    final gapPaint = Paint()..color = Colors.red.withValues(alpha: .65);
    for (final p in proposal.uncoveredPoints) {
      canvas.drawCircle(screen(p), 2, gapPaint);
    }
    // 3. Draw Existing and Proposed Columns & Walls
    final span = proposal.criticalSupportSpan;
    if (span != null) {
      canvas.drawLine(
        screen(span.$1),
        screen(span.$2),
        Paint()
          ..color = proposal.spanCheck?.isDeflectionSafe == true
              ? Colors.green
              : Colors.red
          ..strokeWidth = 2,
      );
      final label = TextPainter(
        text: TextSpan(
          text: 'L = ${proposal.maxSupportSpanM!.toStringAsFixed(2)} m',
          style: const TextStyle(color: Colors.deepPurple, fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, screen((span.$1 + span.$2) / 2));
    }
    for (final c in floor.columns.where(
      (c) =>
          !proposal.replacesGeneratedSupports ||
          !(c.generatedBy?.startsWith('initial-scheme') ?? false),
    )) {
      draw(c.polygonVertices, Colors.grey, fill: true);
    }
    for (final w in floor.shearWalls.where(
      (w) =>
          !proposal.replacesGeneratedSupports ||
          !(w.generatedBy?.startsWith('initial-scheme') ?? false),
    )) {
      draw(w.polygonVertices, Colors.grey, fill: true);
    }
    for (final c in proposal.columns) {
      draw(
        c.polygonVertices,
        proposal.openingColumnIds.contains(c.id) ? Colors.purple : Colors.green,
        fill: true,
      );
    }
    for (final w in proposal.walls) {
      draw(w.polygonVertices, Colors.orange, fill: true);
    }
  }

  @override
  bool shouldRepaint(covariant _SchemePainter old) =>
      old.proposal != proposal ||
      old.floor != floor ||
      old.closureSegments != closureSegments;
}
