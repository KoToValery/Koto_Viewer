import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../analysis/staircase_geometry_detector.dart';
import '../analysis/staircase_opening_contours.dart';
import '../analysis/staircase_assemblies.dart';

class StaircaseGeometrySelection {
  final List<Offset> polygon;
  final bool isOpening;
  const StaircaseGeometrySelection(this.polygon, {this.isOpening = false});
}

/// Proposals load a draft for point editing; only closing the draft saves it.
class StaircaseGeometryDialog extends StatefulWidget {
  final StairGeometryResult result;
  final String? referenceLevel;
  final double scale;
  final bool allowOpening;
  const StaircaseGeometryDialog({
    super.key,
    required this.result,
    this.referenceLevel,
    this.scale = 1,
    this.allowOpening = false,
  });
  @override
  State<StaircaseGeometryDialog> createState() =>
      _StaircaseGeometryDialogState();
}

class _StaircaseGeometryDialogState extends State<StaircaseGeometryDialog> {
  int selected = 0;
  int selectedContour = 0;
  final Map<int, List<List<Offset>>> contoursByFlight = {};
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final assemblies = StaircaseAssembly.group(
      widget.result.flights,
      widget.scale,
    );
    final flights = [
      for (final a in assemblies)
        StairFlightCandidate(
          polygon: a.circulation,
          treads: a.flights.expand((f) => f.treads).toList(),
          boundarySides: 0,
          spacingM: 0,
        ),
    ];
    final contours = widget.allowOpening && flights.isNotEmpty
        ? contoursByFlight.putIfAbsent(
            selected,
            () => StaircaseOpeningContours.findAssembly(
              widget.result,
              assemblies[selected].flights,
              widget.scale,
            ),
          )
        : <List<Offset>>[];
    return AlertDialog(
      title: Text(l.staircaseDetectionTitle),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.staircaseDetectionHint),
              if (widget.referenceLevel != null)
                Text(l.staircaseEvidenceFromLevel(widget.referenceLevel!)),
              if (widget.result.limited)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(l.staircaseLimit),
                ),
              if (flights.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(l.staircaseDetectionEmpty),
                ),
              if (flights.isNotEmpty) ...[
                DropdownButton<int>(
                  value: selected,
                  isExpanded: true,
                  items: [
                    for (var i = 0; i < flights.length; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(
                          '${i + 1} · ${l.staircaseArms(assemblies[i].flights.where((f) => !f.isWinder).length)}'
                          '${assemblies[i].flights.any((f) => f.isWinder) ? ' · ${l.staircaseWinder}' : ''}',
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() {
                    selected = v ?? 0;
                    selectedContour = 0;
                  }),
                ),
                SizedBox(
                  height: 240,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _Preview(
                      widget.result.strokes,
                      flights[selected],
                      opening: contours.isEmpty
                          ? null
                          : contours[selectedContour],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(l.staircaseDetectionPartial),
                if (contours.length > 1)
                  DropdownButton<int>(
                    value: selectedContour,
                    isExpanded: true,
                    items: [
                      for (var i = 0; i < contours.length; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text('${l.staircaseUseOpening} ${i + 1}'),
                        ),
                    ],
                    onChanged: (v) => setState(() => selectedContour = v ?? 0),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (contours.isNotEmpty && !widget.result.limited)
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              StaircaseGeometrySelection(
                contours[selectedContour],
                isOpening: true,
              ),
            ),
            child: Text(l.staircaseUseOpening),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        if (flights.isNotEmpty && !widget.result.limited)
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              StaircaseGeometrySelection(flights[selected].polygon),
            ),
            child: Text(l.staircaseUseZone),
          ),
      ],
    );
  }
}

class _Preview extends CustomPainter {
  final List<(Offset, Offset)> strokes;
  final StairFlightCandidate flight;
  final List<Offset>? opening;
  _Preview(this.strokes, this.flight, {this.opening});
  @override
  void paint(Canvas canvas, Size size) {
    final poly = flight.polygon;
    final viewPoints = [...poly, ...?opening];
    final bounds = Rect.fromLTRB(
      viewPoints.map((p) => p.dx).reduce(math.min),
      viewPoints.map((p) => p.dy).reduce(math.min),
      viewPoints.map((p) => p.dx).reduce(math.max),
      viewPoints.map((p) => p.dy).reduce(math.max),
    );
    final roi = bounds.inflate(math.max(bounds.width, bounds.height) * .35);
    final zoom = math.min(size.width / roi.width, size.height / roi.height);
    Offset point(Offset p) => Offset(
      (p.dx - roi.center.dx) * zoom + size.width / 2,
      -(p.dy - roi.center.dy) * zoom + size.height / 2,
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF15191B),
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final pen = Paint()
      ..color = Colors.white54
      ..strokeWidth = 1;
    for (final s in strokes) {
      if (Rect.fromPoints(s.$1, s.$2).inflate(.001).overlaps(roi)) {
        canvas.drawLine(point(s.$1), point(s.$2), pen);
      }
    }
    final path = Path()..moveTo(point(poly.first).dx, point(poly.first).dy);
    for (final p in poly.skip(1)) {
      final q = point(p);
      path.lineTo(q.dx, q.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = Colors.cyan.withValues(alpha: .16));
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.cyan
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    pen
      ..color = Colors.orange
      ..strokeWidth = 2;
    for (final s in flight.treads) {
      canvas.drawLine(point(s.$1), point(s.$2), pen);
    }
    if (opening != null && opening!.length >= 3) {
      final hole = Path();
      for (var i = 0; i < opening!.length; i++) {
        final p = point(opening![i]);
        if (i == 0) {
          hole.moveTo(p.dx, p.dy);
        } else {
          hole.lineTo(p.dx, p.dy);
        }
      }
      hole.close();
      canvas.drawPath(
        hole,
        Paint()
          ..color = Colors.purpleAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _Preview old) =>
      old.flight != flight || old.opening != opening || old.strokes != strokes;
}
