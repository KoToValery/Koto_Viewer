import 'dart:math' as math;
import 'dart:ui';

import '../models/architect_wall.dart';
import 'architect_wall_connection_policy.dart';

/// Shared calculation geometry. Saved placement references are never changed.
class ArchitectWallOperationAxis {
  static double coreOffset(ArchitectWall wall) =>
      wall.centerLineOffset - wall.exteriorSign * wall.coreAsymmetry / 2;

  /// Parallel arcs retain their sweep/bulge, but have a different radius.
  static ArchitectWall core(ArchitectWall wall) => ArchitectWall(
    id: wall.id,
    startPoint: wall.coreCenterStart,
    endPoint: wall.coreCenterEnd,
    arcBulge: wall.arcBulge,
    thickness: .001,
    connectStart: wall.connectStart,
    connectEnd: wall.connectEnd,
  );

  static ArchitectWall restore(
    ArchitectWall source,
    ArchitectWall axis, {
    bool keepOpeningPositions = false,
  }) {
    final offset = -coreOffset(source);
    final start = axis.isCurved
        ? axis.arc!.pointAt(0, leftOffset: offset)
        : axis.startPoint + axis.normalVector * offset;
    final end = axis.isCurved
        ? axis.arc!.pointAt(1, leftOffset: offset)
        : axis.endPoint + axis.normalVector * offset;
    if (axis.isCurved &&
        axis.arc!.radius - axis.arcBulge.sign * offset <= .001) {
      throw ArgumentError('Wall reference arc collapsed');
    }
    var next = source.copyWith(
      startPoint: start,
      endPoint: end,
      arcBulge: axis.arcBulge,
    );
    if (keepOpeningPositions) {
      double ratio(double oldRatio, double width) {
        final point = source.referencePointAt(oldRatio);
        final r = next.projectPoint(point).$1;
        final half = next.openingArcSpan(width) / 2;
        if (!r.isFinite ||
            r * next.length < half - 1e-8 ||
            (1 - r) * next.length < half - 1e-8) {
          throw ArgumentError('Opening would leave its host');
        }
        return r;
      }

      next = next.copyWith(
        doors: [
          for (final d in source.doors)
            d.copyWith(offsetRatio: ratio(d.offsetRatio, d.width)),
        ],
        windows: [
          for (final w in source.windows)
            w.copyWith(offsetRatio: ratio(w.offsetRatio, w.width)),
        ],
      );
    }
    next.validateGeometry();
    return next;
  }

  /// A physically joined L corner can have different saved reference endpoints.
  /// Normalize only the calculation endpoints to its existing core junction.
  static List<ArchitectWall> joinedCores(List<ArchitectWall> walls) {
    final axes = walls.map(core).toList();
    final starts = <int, Offset>{}, ends = <int, Offset>{};
    void assign(Map<int, Offset> points, int i, Offset p) {
      final previous = points[i];
      if (previous != null && (previous - p).distance > 1e-7) {
        throw ArgumentError('Offset junction has multiple branches');
      }
      points[i] = p;
    }

    for (var i = 0; i < walls.length; i++) {
      for (var j = i + 1; j < walls.length; j++) {
        final a = walls[i], b = walls[j];
        if (a.isDetached || b.isDetached) continue;
        final aa = axes[i], bb = axes[j];
        final curved = a.isCurved || b.isCurved;
        final nodes = curved
            ? aa.intersections(bb, finite: false)
            : [?ArchitectWallConnectionPolicy.coreJunction(a, b)];
        // Tangent arcs can have a tiny negative quadratic discriminant. Their
        // shared endpoints still define an exact connection.
        if (curved) {
          for (final p in [aa.startPoint, aa.endPoint]) {
            for (final q in [bb.startPoint, bb.endPoint]) {
              if ((p - q).distance < 1e-7) nodes.add((p + q) / 2);
            }
          }
        }
        for (final node in nodes) {
          final aStart =
              (node - aa.startPoint).distance < (node - aa.endPoint).distance;
          final bStart =
              (node - bb.startPoint).distance < (node - bb.endPoint).distance;
          final aTip = aStart ? aa.startPoint : aa.endPoint;
          final bTip = bStart ? bb.startPoint : bb.endPoint;
          final reachA = curved
              ? math.max(a.thickness, b.thickness) * 3
              : ArchitectWallConnectionPolicy.coreJunctionReach(b) + .0001;
          final reachB = curved
              ? math.max(a.thickness, b.thickness) * 3
              : ArchitectWallConnectionPolicy.coreJunctionReach(a) + .0001;
          bool finite(ArchitectWall axis) {
            final d = node - axis.startPoint;
            final r = axis.isCurved
                ? axis.arc!.parameter(node)
                : (d.dx * axis.unitVector.dx + d.dy * axis.unitVector.dy) /
                      axis.length;
            return r >= 0 && r <= 1;
          }

          final nearA = (node - aTip).distance <= reachA;
          final nearB = (node - bTip).distance <= reachB;
          if ((!nearA && !finite(aa)) || (!nearB && !finite(bb))) continue;
          if (!nearA || !nearB) {
            throw ArgumentError('Offset requires unbranched wall chains');
          }
          if (!(aStart ? a.connectStart : a.connectEnd) ||
              !(bStart ? b.connectStart : b.connectEnd)) {
            continue;
          }
          assign(aStart ? starts : ends, i, node);
          assign(bStart ? starts : ends, j, node);
        }
      }
    }
    return [
      for (var i = 0; i < axes.length; i++)
        axes[i].withExtendedEnds(start: starts[i], end: ends[i]),
    ];
  }
}
