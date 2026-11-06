import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_wall.dart';
import '../rendering/architect_clearance_badge_layout.dart';
import '../rendering/architect_clearance_obstacles.dart';
import '../rendering/architect_dynamic_dimension_layout.dart';
import '../services/architect_new_point_measure.dart';
import 'architect_dynamic_dimension_painter.dart';

/// Live wall distances are editing aids and never enter publication output.
class ArchitectNewPointOverlay extends StatelessWidget {
  final ArchitectWall wall;
  final Offset candidate, gripOffset;
  final String? snapLabel;
  final bool valid;
  final bool darkCanvas;
  final Offset Function(Offset) toScreen, toModel;
  final String Function(double) format;
  final ArchitectClearanceObstacles obstacles;
  final ValueChanged<int> onEdit;
  const ArchitectNewPointOverlay({
    super.key,
    required this.wall,
    required this.candidate,
    required this.gripOffset,
    required this.valid,
    this.darkCanvas = false,
    this.snapLabel,
    required this.toScreen,
    required this.toModel,
    required this.format,
    required this.obstacles,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      if (size.maxWidth < 140 || size.maxHeight < 180) {
        return const SizedBox.shrink();
      }
      final measure = ArchitectNewPointMeasure(wall, candidate);
      final bounds = (Offset.zero & Size(size.maxWidth, size.maxHeight))
          .deflate(8);
      final available = Rect.fromLTRB(
        8,
        64,
        size.maxWidth - 8,
        size.maxHeight - 72,
      );
      final tip = toScreen(candidate);
      final grip = tip + gripOffset;
      final excluded = <Rect>[
        Rect.fromCircle(center: tip, radius: 13),
        Rect.fromCircle(center: grip, radius: 20),
      ];
      bool intersects(Rect rect) => obstacles.intersects(
        Rect.fromPoints(toModel(rect.topLeft), toModel(rect.bottomRight)),
      );
      final dimensions = <ArchitectDynamicDimensionLayout>[];
      final arcs = <List<Offset>>[];
      final labels = <Rect>[];
      for (final endpoint in [1, 2]) {
        final start = toScreen(endpoint == 1 ? wall.startPoint : wall.endPoint);
        if (!wall.isCurved) {
          final dim = ArchitectDynamicDimensionLayout.place(
            start: start,
            end: tip,
            available: available,
            viewport: bounds,
            excluded: excluded,
            intersectsWall: intersects,
            endpoint: endpoint,
          );
          dimensions.add(dim);
          labels.add(dim.label);
        } else {
          final from = endpoint == 1 ? 0.0 : measure.ratio;
          final to = endpoint == 1 ? measure.ratio : 1.0;
          final count = math.max(
            2,
            ((to - from) * wall.arc!.sweep.abs() * 24).ceil(),
          );
          final points = <Offset>[];
          // A parallel screen-space arc shows that this is an arc-length measure.
          for (var i = 0; i <= count; i++) {
            final ratio = from + (to - from) * i / count;
            final tangent = wall.tangentAt(ratio);
            final normal = Offset(-tangent.dy, tangent.dx);
            points.add(
              toScreen(wall.referencePointAt(ratio)) +
                  normal * (-wall.arc!.bulge.sign * 24),
            );
          }
          arcs.add(points);
          labels.add(
            ArchitectClearanceBadgeLayout.place(
              preferred: points[points.length ~/ 2],
              available: available,
              excluded: excluded,
              intersectsWall: intersects,
            ),
          );
        }
        excluded.add(labels.last.inflate(4));
      }
      final label = valid ? snapLabel : null;
      final snapRect = label == null
          ? null
          : ArchitectClearanceBadgeLayout.place(
              preferred: grip + const Offset(0, -26),
              available: available,
              excluded: excluded,
              size: const Size(128, 28),
              intersectsWall: intersects,
            );
      return ClipRect(
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  key: const ValueKey('architect-new-point-dimensions'),
                  painter: wall.isCurved
                      ? _ArcDistancesPainter(arcs, labels, [
                          toScreen(wall.startPoint),
                          tip,
                          toScreen(wall.endPoint),
                        ], darkCanvas)
                      : ArchitectDynamicDimensionPainter(
                          dimensions,
                          darkCanvas: darkCanvas,
                        ),
                ),
              ),
            ),
            for (var i = 0; i < 2; i++)
              Positioned.fromRect(
                rect: labels[i],
                child: Tooltip(
                  message: context.l10n.architectNewPointDistanceHelp(i + 1),
                  child: Material(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: const BorderSide(
                        color: Color(0xff78818a),
                        width: .7,
                      ),
                    ),
                    child: InkWell(
                      key: ValueKey('architect-new-point-distance-${i + 1}'),
                      onTap: () => onEdit(i + 1),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              context.l10n.architectWallEndpointValue(
                                i + 1,
                                format(measure.distanceFrom(i + 1)),
                              ),
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (snapRect != null)
              Positioned.fromRect(
                rect: snapRect,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: valid
                            ? const Color(0xff006e91)
                            : const Color(0xffb3261e),
                        width: .7,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            label!,
                            style: TextStyle(
                              color: valid
                                  ? Colors.black87
                                  : const Color(0xffb3261e),
                              fontSize: 11,
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

class _ArcDistancesPainter extends CustomPainter {
  final List<List<Offset>> arcs;
  final List<Rect> labels;
  final List<Offset> anchors;
  final bool darkCanvas;
  _ArcDistancesPainter(this.arcs, this.labels, this.anchors, this.darkCanvas);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final paint = Paint()
      ..color = darkCanvas ? const Color(0xffbcc3ca) : const Color(0xff545b62)
      ..strokeWidth = .85
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < arcs.length; i++) {
      final points = arcs[i];
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
      for (final (point, anchor) in [
        (points.first, anchors[i]),
        (points.last, anchors[i + 1]),
      ]) {
        canvas.drawLine(anchor, point, paint);
        final delta = point - anchor;
        if (delta.distance > 1e-6) {
          final tick = delta / delta.distance * 4;
          canvas.drawLine(point - tick, point + tick, paint);
        }
      }
      final mid = points[points.length ~/ 2];
      if (!labels[i].inflate(4).contains(mid)) {
        canvas.drawLine(mid, labels[i].center, paint);
      }
      final endpoint = anchors[i == 0 ? 0 : 2];
      canvas.drawCircle(endpoint, 7, Paint()..color = Colors.white);
      canvas.drawCircle(endpoint, 7, paint);
      final text = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(
            color: Colors.black87,
            fontFamily: 'Roboto',
            fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, endpoint - Offset(text.width / 2, text.height / 2));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ArcDistancesPainter oldDelegate) => true;
}
