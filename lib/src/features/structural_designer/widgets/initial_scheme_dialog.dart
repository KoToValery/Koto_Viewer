import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/structural_element.dart';
import '../models/wall_axis_models.dart';
import '../models/seismic_analysis_models.dart';
import '../analysis/initial_scheme_generator.dart';
import '../analysis/seismic_analysis_calculator.dart';
import '../analysis/wall_axis_detector.dart';
import 'seismic_analysis_sheet.dart';

class InitialSchemeDialog extends StatefulWidget {
  final StructuralProject project;
  final List<WallPairCandidate> pairs;
  final List<(Offset, Offset)> closureSegments;
  final double scale;
  final InitialSchemeOptions options;
  const InitialSchemeDialog({
    super.key,
    required this.project,
    required this.pairs,
    this.closureSegments = const [],
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
  late bool enforcePaired = widget.options.enforcePairedWalls;
  late bool generousDensity = widget.options.generousDensity;
  late final List<(Offset, Offset)> effectiveClosureSegments =
      widget.closureSegments.isNotEmpty
          ? widget.closureSegments
          : WallAxisDetector.computeClosureSegmentsForPairs(widget.pairs);
  List<InitialSchemeProposal> proposals = [];
  List<SeismicAnalysisReport> reports = [];
  int selected = 0;
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
      wallThicknessM: o.wallThicknessM,
      columnWidthM: o.columnWidthM,
      columnDepthM: o.columnDepthM,
      enforcePairedWalls: enforcePaired,
      generousDensity: generousDensity,
    );
    if (!options.valid) {
      setState(() => error = true);
      return;
    }
    proposals = [
      for (var v = 0; v < 2; v++)
        InitialSchemeGenerator.generate(
          project: widget.project,
          wallPairs: widget.pairs,
          scale: widget.scale,
          options: options,
          variant: v,
        ),
    ];
    reports = [
      for (final p in proposals)
        SeismicAnalysisCalculator.analyzeProject(
          widget.project.copyWith(
            storeys: [
              for (final f in widget.project.storeys)
                f.id == widget.project.activeStorey.id ? p.apply(f) : f,
            ],
          ),
          cadUnitsPerMeter: widget.scale,
        ),
    ];
    confirmed = false;
    error = false;
    dirty = false;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = proposals[selected];
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
              Text(l.schemeFresh),
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
                  TextButton(
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
              if (error)
                Text(
                  l.schemeInvalidOptions,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 8),
              Text(l.schemeComparison),
              for (var i = 0; i < proposals.length; i++)
                Builder(
                  builder: (context) {
                    final checks = reports[i].storeyChecks.where(
                      (c) => c.storeyId == widget.project.activeStorey.id,
                    );
                    final e = checks.isEmpty
                        ? null
                        : checks.first.eccentricityM;
                    return ListTile(
                      leading: Icon(
                        selected == i
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                      ),
                      onTap: () => setState(() {
                        selected = i;
                        confirmed = false;
                      }),
                      title: Text(
                        i == 0 ? l.schemeVariantCore : l.schemeVariantLong,
                      ),
                      subtitle: Text(
                        '${proposals[i].columns.length} C · ${proposals[i].walls.length} W · '
                        '${e == null ? '—' : '${e.dx.toStringAsFixed(3)} / ${e.dy.toStringAsFixed(3)}'} · '
                        '${reports[i].totalFloatingColumnsCount}',
                      ),
                    );
                  },
                ),
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
              Text('${l.schemeUnresolved}: ${p.unresolvedRegions}'),
              Text('${l.schemeRejected}: ${p.rejectedCandidates}'),
              Text(l.schemePreliminary),
              TextButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) =>
                      SeismicAnalysisSheet(report: reports[selected]),
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
  _SchemePainter(this.floor, this.proposal, this.pairs, this.closureSegments);

  @override
  void paint(Canvas canvas, Size size) {
    final points = <Offset>[
      ...floor.slabs.expand((s) => s.polygon),
      ...pairs.expand((p) => [
        p.segmentA.start,
        p.segmentA.end,
        p.segmentB.start,
        p.segmentB.end,
      ]),
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
        final pAStart = Offset(tStart * cosA - dA * sinA, tStart * sinA + dA * cosA);
        final pAEnd = Offset(tEnd * cosA - dA * sinA, tEnd * sinA + dA * cosA);
        final pBEnd = Offset(tEnd * cosA - dB * sinA, tEnd * sinA + dB * cosA);
        final pBStart = Offset(tStart * cosA - dB * sinA, tStart * sinA + dB * cosA);
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

    // 3. Draw Existing and Proposed Columns & Walls
    for (final c in floor.columns) {
      draw(c.polygonVertices, Colors.grey, fill: true);
    }
    for (final w in floor.shearWalls) {
      draw(w.polygonVertices, Colors.grey, fill: true);
    }
    for (final c in proposal.columns) {
      draw(c.polygonVertices, Colors.green, fill: true);
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
