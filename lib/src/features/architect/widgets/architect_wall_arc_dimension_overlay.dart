import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extensions.dart';
import '../../bim_editing/geometry/bim_line_geometry.dart';
import '../models/architect_wall_arc.dart';
import '../rendering/architect_clearance_badge_layout.dart';

/// A temporary, screen-space dimension. It never becomes a drawing annotation.
class ArchitectWallArcDimensionOverlay extends StatelessWidget {
  final ArchitectWallArc arc;
  final ArchitectArcDimension dimension;
  final Offset Function(Offset) toScreen;
  final Offset Function(Offset) toModel;
  final String Function(double) format;
  final Path obstacles;
  final VoidCallback onEdit;

  const ArchitectWallArcDimensionOverlay({
    super.key,
    required this.arc,
    required this.dimension,
    required this.toScreen,
    required this.toModel,
    required this.format,
    required this.obstacles,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 140 || constraints.maxHeight < 200) {
        return const SizedBox.shrink();
      }
      final radius = dimension == ArchitectArcDimension.radius;
      final value = radius ? arc.radius : arc.sagitta;
      final text =
          '${radius ? 'R' : 'h'}=${value.isFinite ? format(value) : '—'}';
      final start = radius && arc.bulge.abs() > 1e-8
          ? arc.center
          : arc.chordMidpoint;
      final a = toScreen(start), b = toScreen(arc.midpoint);
      final preferred = radius
          ? b + const Offset(24, -28)
          : (a + b) / 2 + const Offset(42, 0);
      final available = Rect.fromLTRB(
        8,
        104,
        constraints.maxWidth - 8,
        constraints.maxHeight - 64,
      );
      final rect = ArchitectClearanceBadgeLayout.place(
        preferred: preferred,
        available: available,
        excluded: const [],
        size: const Size(112, 40),
        intersectsWall: (rect) => Path.combine(
          PathOperation.intersect,
          obstacles,
          Path()..addPolygon([
            toModel(rect.topLeft),
            toModel(rect.topRight),
            toModel(rect.bottomRight),
            toModel(rect.bottomLeft),
          ], true),
        ).computeMetrics().isNotEmpty,
      );
      return ClipRect(
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ArcDimensionPainter(
                    toScreen(arc.start),
                    toScreen(arc.end),
                    a,
                    b,
                    rect,
                  ),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: rect,
              child: Tooltip(
                message: context.l10n.wallArcDimensionHelp,
                child: Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                    side: const BorderSide(color: Color(0xff777777), width: .7),
                  ),
                  child: InkWell(
                    key: const ValueKey('wall-arc-dimension-badge'),
                    borderRadius: BorderRadius.circular(5),
                    onTap: onEdit,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            text,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _ArcDimensionPainter extends CustomPainter {
  final Offset chordStart, chordEnd, start, end;
  final Rect badge;
  _ArcDimensionPainter(
    this.chordStart,
    this.chordEnd,
    this.start,
    this.end,
    this.badge,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final paint = Paint()
      ..color = const Color(0xff656565)
      ..strokeWidth = .8;
    final chord = BimLineGeometry.visibleSegment(chordStart, chordEnd, bounds);
    if (chord != null) {
      final delta = chord.$2 - chord.$1;
      if (delta.distance > 1e-6) {
        final u = delta / delta.distance;
        for (var d = 0.0; d < delta.distance; d += 9) {
          canvas.drawLine(
            chord.$1 + u * d,
            chord.$1 + u * math.min(d + 5, delta.distance),
            paint,
          );
        }
      }
    }
    if (start.dx.isFinite &&
        start.dy.isFinite &&
        end.dx.isFinite &&
        end.dy.isFinite) {
      final visible = BimLineGeometry.visibleSegment(start, end, bounds);
      if (visible != null) canvas.drawLine(visible.$1, visible.$2, paint);
      final delta = end - start;
      if (delta.distance > 1e-6) {
        final tick = Offset(-delta.dy, delta.dx) / delta.distance * 5;
        for (final p in [start, end]) {
          if (bounds.inflate(8).contains(p)) {
            canvas.drawLine(p - tick, p + tick, paint);
          }
        }
      }
      // Connect a displaced label to its measured line without covering text.
      final closest = BimLineGeometry.closest(badge.center, start, end);
      if (!badge.inflate(4).contains(closest)) {
        canvas.drawLine(closest, badge.center, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ArcDimensionPainter oldDelegate) => true;
}
