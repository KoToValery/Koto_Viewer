import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../services/architect_building_elevation.dart';

class ArchitectTerrainEditor extends StatefulWidget {
  final List<Offset> initial;
  final Offset Function(Offset) toView, toScreen;
  final ValueChanged<List<Offset>> onApply;
  final VoidCallback onCancel;
  const ArchitectTerrainEditor({
    super.key,
    required this.initial,
    required this.toView,
    required this.toScreen,
    required this.onApply,
    required this.onCancel,
  });
  @override
  State<ArchitectTerrainEditor> createState() => _TerrainState();
}

class _TerrainState extends State<ArchitectTerrainEditor> {
  late List<Offset> points = List.of(widget.initial);
  int? dragging;
  Offset? pointerDown;
  @override
  void didUpdateWidget(covariant ArchitectTerrainEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initial != widget.initial) {
      points = List.of(widget.initial);
      dragging = null;
      pointerDown = null;
    }
  }

  bool get valid {
    try {
      ArchitectBuildingElevation.validateTerrain(points);
      return points.length >= 2;
    } on ArgumentError {
      return false;
    }
  }

  int? hit(Offset screen) {
    for (var i = 0; i < points.length; i++) {
      if ((widget.toScreen(points[i]) - screen).distance <= 22) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: (d) => pointerDown = d.localPosition,
            onTapUp: (d) => setState(() {
              final p = widget.toView(d.localPosition);
              if (points.any((q) => (q.dx - p.dx).abs() < .001)) return;
              points.add(p);
              points.sort((a, b) => a.dx.compareTo(b.dx));
            }),
            onPanStart: (d) => dragging = hit(pointerDown ?? d.localPosition),
            onPanUpdate: (d) {
              final i = dragging;
              if (i == null) return;
              final p = widget.toView(d.localPosition);
              if ((i > 0 && p.dx <= points[i - 1].dx + .001) ||
                  (i + 1 < points.length && p.dx >= points[i + 1].dx - .001)) {
                return;
              }
              setState(() => points[i] = p);
            },
            onPanEnd: (_) => dragging = null,
            child: CustomPaint(
              painter: _TerrainDraftPainter(List.of(points), widget.toScreen),
            ),
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: Tooltip(
                      message: l.architectTerrainHint,
                      child: Text(l.architectTerrain),
                    ),
                  ),
                  IconButton(
                    tooltip: l.undoAction,
                    onPressed: points.isEmpty
                        ? null
                        : () => setState(() => points.removeLast()),
                    icon: const Icon(Icons.undo),
                  ),
                  IconButton(
                    tooltip: l.delete,
                    onPressed: () => setState(() => points.clear()),
                    icon: const Icon(Icons.delete_outline),
                  ),
                  IconButton(
                    tooltip: l.cancel,
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.close),
                  ),
                  IconButton(
                    key: const ValueKey('terrain-confirm'),
                    tooltip: l.save,
                    onPressed: valid || points.isEmpty
                        ? () => widget.onApply(List.unmodifiable(points))
                        : null,
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TerrainDraftPainter extends CustomPainter {
  final List<Offset> points;
  final Offset Function(Offset) toScreen;
  _TerrainDraftPainter(this.points, this.toScreen);
  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final screen = points.map(toScreen).toList();
    canvas.drawPath(
      Path()..addPolygon(screen, false),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF36794A),
    );
    for (final p in screen) {
      canvas.drawCircle(p, 5, Paint()..color = const Color(0xFF36794A));
    }
  }

  @override
  bool shouldRepaint(covariant _TerrainDraftPainter old) => true;
}
