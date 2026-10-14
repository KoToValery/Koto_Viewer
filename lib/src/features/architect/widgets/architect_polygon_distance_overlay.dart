import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../rendering/architect_dimension_layout.dart';
import '../services/architect_polygon_dimensions.dart';

/// Touch targets and their dimension lines share the viewport transform.
class ArchitectPolygonDistanceOverlay extends StatelessWidget {
  final List<Offset> polygon;
  final int edge;
  final List<ArchitectPolygonDistance> dimensions;
  final ArchitectUnit unit;
  final double scale;
  final Offset Function(Offset) toScreen;
  final Path obstacles;
  final ValueChanged<ArchitectPolygonDistance> onEdit;
  const ArchitectPolygonDistanceOverlay({
    super.key,
    required this.polygon,
    required this.edge,
    required this.dimensions,
    required this.unit,
    required this.scale,
    required this.toScreen,
    required this.obstacles,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => ClipRect(
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _DistancePainter(polygon, edge, dimensions, toScreen),
              ),
            ),
          ),
          for (final dimension in dimensions)
            Builder(
              builder: (context) {
                final normal = dimension.normal;
                final tangent = Offset(-normal.dy, normal.dx);
                final midpoint = (dimension.start + dimension.end) / 2;
                final center = toScreen(
                  ArchitectDimensionLayout.clearTextPosition(
                    midpoint + tangent * (24 / scale),
                    const Size(96, 44),
                    scale,
                    tangent,
                    obstacles,
                  ),
                );
                if (center.dx < 48 ||
                    center.dx > constraints.maxWidth - 48 ||
                    center.dy < 22 ||
                    center.dy > constraints.maxHeight - 22) {
                  return const SizedBox.shrink();
                }
                return Positioned(
                  left: center.dx - 48,
                  top: center.dy - 22,
                  width: 96,
                  height: 44,
                  child: Tooltip(
                    message: context.l10n.architectEdgeDistanceHint,
                    child: Material(
                      color: const Color(0xEE1E242C),
                      elevation: 3,
                      shadowColor: Colors.black54,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: const BorderSide(color: Colors.white24),
                      ),
                      child: InkWell(
                        key: ValueKey('polygon-distance-${dimension.key}'),
                        onTap: () => onEdit(dimension),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Text(
                                '${unit.toUnit(dimension.distance).toStringAsFixed(2)} ${unit.symbol}',
                                style: const TextStyle(
                                  color: Colors.cyanAccent,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    ),
  );
}

class _DistancePainter extends CustomPainter {
  final List<Offset> polygon;
  final int edge;
  final List<ArchitectPolygonDistance> dimensions;
  final Offset Function(Offset) toScreen;
  _DistancePainter(this.polygon, this.edge, this.dimensions, this.toScreen);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      toScreen(polygon[edge]),
      toScreen(polygon[(edge + 1) % polygon.length]),
      Paint()
        ..color = Colors.orangeAccent
        ..strokeWidth = 3,
    );
    final paint = Paint()
      ..color = const Color(0xFF00838F)
      ..strokeWidth = 1;
    for (final dimension in dimensions) {
      final a = toScreen(dimension.start), b = toScreen(dimension.end);
      final delta = b - a;
      if (delta.distance < 1) continue;
      final u = delta / delta.distance;
      for (var d = 0.0; d < delta.distance; d += 9) {
        canvas.drawLine(
          a + u * d,
          a + u * (d + 5).clamp(0, delta.distance),
          paint,
        );
      }
      final tick = Offset(-u.dy, u.dx) * 6;
      canvas.drawLine(a - tick, a + tick, paint);
      canvas.drawLine(b - tick, b + tick, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DistancePainter oldDelegate) => true;
}
