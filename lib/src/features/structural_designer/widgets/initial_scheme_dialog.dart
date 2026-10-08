import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/structural_element.dart';
import '../models/wall_axis_models.dart';
import '../models/seismic_analysis_models.dart';
import '../analysis/initial_scheme_generator.dart';
import '../analysis/seismic_analysis_calculator.dart';
import 'seismic_analysis_sheet.dart';

class InitialSchemeDialog extends StatefulWidget {
  final StructuralProject project;
  final List<WallPairCandidate> pairs;
  final double scale;
  final InitialSchemeOptions options;
  const InitialSchemeDialog({
    super.key,
    required this.project,
    required this.pairs,
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
  _SchemePainter(this.floor, this.proposal, this.pairs);
  @override
  void paint(Canvas canvas, Size size) {
    final points = floor.slabs.expand((s) => s.polygon).toList();
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

    final wallPaint = Paint()
      ..color = Colors.grey.withValues(alpha: .45)
      ..strokeWidth = 1;
    for (final pair in pairs) {
      canvas.drawLine(
        screen(pair.segmentA.start),
        screen(pair.segmentA.end),
        wallPaint,
      );
      canvas.drawLine(
        screen(pair.segmentB.start),
        screen(pair.segmentB.end),
        wallPaint,
      );
    }
    for (final s in floor.slabs) {
      draw(s.polygon, Colors.blue);
      for (final hole in s.openings) {
        draw(hole, Colors.red);
      }
    }
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
      old.proposal != proposal || old.floor != floor;
}
