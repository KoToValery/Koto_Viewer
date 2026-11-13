import 'dart:math' as math;
import 'dart:ui';
import '../models/architect_elements.dart';
import 'architect_polygon_geometry.dart';
import 'architect_stair_geometry.dart';
import '../rendering/architect_path_solid.dart';
import 'architect_stair_landing_path.dart';

enum StairLayoutProblem {
  polygon,
  connection,
  cell,
  length,
  total,
  collision,
  clearance,
}

class StairLayoutIssue {
  final StairLayoutProblem problem;
  final String partId;
  final double? suggestedRun;
  const StairLayoutIssue(this.problem, this.partId, {this.suggestedRun});
}

/// Pure constraints: a failed fit never changes a dimension or a contour.
class ArchitectStairLayoutResolver {
  static List<StairLayoutIssue> check(ArchitectStairDesign d) {
    final l = d.layout;
    if (l == null) return [];
    final issues = <StairLayoutIssue>[];
    if (d.manualRisers != null && d.manualRisers != l.risers) {
      issues.add(const StairLayoutIssue(StairLayoutProblem.total, ''));
    }
    final polygons = <List<Offset>>[];
    for (final f in l.flights) {
      if (f.fixedRun != null && (f.fixedRun! - f.run(d.going)).abs() > 1e-6) {
        issues.add(
          StairLayoutIssue(
            StairLayoutProblem.length,
            f.id,
            suggestedRun: f.run(d.going),
          ),
        );
      }
      polygons.add(f.footprint(d.going));
    }
    for (var i = 0; i < l.landings.length; i++) {
      final p = l.landings[i].polygon;
      if (!ArchitectPolygonGeometry.valid(p)) {
        issues.add(
          StairLayoutIssue(StairLayoutProblem.polygon, l.landings[i].id),
        );
        continue;
      }
      final a = l.flights[i], b = l.flights[i + 1];
      if (ArchitectStairLandingPath.route(
        p,
        a.end(d.going),
        b.origin,
        width: math.min(a.width, b.width),
        incoming: a.axis,
        outgoing: b.axis,
      ).isEmpty) {
        issues.add(
          StairLayoutIssue(StairLayoutProblem.clearance, l.landings[i].id),
        );
      }
      if (!port(p, a.end(d.going), a.normal, a.width) ||
          !port(p, b.origin, b.normal, b.width)) {
        issues.add(
          StairLayoutIssue(StairLayoutProblem.connection, l.landings[i].id),
        );
      }
      // Flight interiors must be on the opposite side of their landing edge.
      if (ArchitectPolygonGeometry.contains(
            p,
            a.end(d.going) - a.axis * 1e-4,
          ) ||
          ArchitectPolygonGeometry.contains(p, b.origin + b.axis * 1e-4)) {
        issues.add(
          StairLayoutIssue(StairLayoutProblem.connection, l.landings[i].id),
        );
      }
      polygons.add(p);
    }
    if (l.cell.isNotEmpty) {
      if (!ArchitectPolygonGeometry.valid(l.cell)) {
        issues.add(const StairLayoutIssue(StairLayoutProblem.polygon, 'cell'));
      } else {
        final cell = Path()..addPolygon(l.cell, true);
        for (var i = 0; i < polygons.length; i++) {
          final outside = Path.combine(
            PathOperation.difference,
            Path()..addPolygon(polygons[i], true),
            cell,
          );
          if (hasArea(outside))
            issues.add(
              StairLayoutIssue(
                StairLayoutProblem.cell,
                i < l.flights.length
                    ? l.flights[i].id
                    : l.landings[i - l.flights.length].id,
              ),
            );
        }
      }
    }
    // Same-level landings may touch but must not cover an adjoining flight.
    for (var i = 0; i < l.landings.length; i++) {
      final p = Path()..addPolygon(l.landings[i].polygon, true);
      for (final f in [l.flights[i], l.flights[i + 1]]) {
        if (hasArea(
          Path.combine(
            PathOperation.intersect,
            p,
            Path()..addPolygon(f.footprint(d.going), true),
          ),
        )) {
          issues.add(StairLayoutIssue(StairLayoutProblem.collision, f.id));
        }
      }
    }
    return issues;
  }

  static bool hasArea(Path p) {
    final bounds = p.getBounds();
    if (bounds.width < 1e-8 || bounds.height < 1e-8) return false;
    for (final points in ArchitectPathSolid.contours(p, tolerance: 1e-7)) {
      if (ArchitectPolygonGeometry.signedArea(points).abs() > 1e-7) return true;
    }
    return false;
  }

  static double landingDepth(ArchitectStairDesign d, {int? landingIndex}) {
    final l = d.layout!;
    var depth = double.infinity;
    for (var i = 0; i < l.landings.length; i++) {
      if (landingIndex != null && i != landingIndex) continue;
      final p = Path()..addPolygon(l.landings[i].polygon, true);
      for (final entry in [
        (
          l.flights[i].end(d.going),
          l.flights[i].axis,
          l.flights[i].normal,
          l.flights[i].width,
        ),
        (
          l.flights[i + 1].origin,
          -l.flights[i + 1].axis,
          l.flights[i + 1].normal,
          l.flights[i + 1].width,
        ),
      ]) {
        var low = 0.0, high = p.getBounds().size.longestSide * 2;
        for (var n = 0; n < 20; n++) {
          final t = (low + high) / 2,
              a = entry.$1 - entry.$3 * entry.$4 / 2,
              b = entry.$1 + entry.$3 * entry.$4 / 2;
          final rectangle = Path()
            ..addPolygon([a, b, b + entry.$2 * t, a + entry.$2 * t], true);
          if (hasArea(Path.combine(PathOperation.difference, rectangle, p))) {
            high = t;
          } else {
            low = t;
          }
        }
        depth = math.min(depth, low);
      }
    }
    return depth;
  }

  static bool port(
    List<Offset> polygon,
    Offset center,
    Offset normal,
    double width,
  ) {
    // All endpoints must lie on one collinear chain of boundary edges. Checking
    // endpoints alone would accept a port crossing a concave notch.
    final a = center - normal * width / 2, b = center + normal * width / 2;
    final intervals = <(double, double)>[];
    for (var i = 0; i < polygon.length; i++) {
      final p = polygon[i], q = polygon[(i + 1) % polygon.length];
      if (ArchitectStairGeometry.cross(p - a, normal).abs() > 1e-6 ||
          ArchitectStairGeometry.cross(q - a, normal).abs() > 1e-6)
        continue;
      final x = ArchitectStairGeometry.dot(p - a, normal);
      final y = ArchitectStairGeometry.dot(q - a, normal);
      intervals.add((math.min(x, y), math.max(x, y)));
    }
    intervals.sort((a, b) => a.$1.compareTo(b.$1));
    var covered = 0.0;
    for (final r in intervals) {
      if (r.$1 > covered + 1e-6) break;
      covered = math.max(covered, r.$2);
    }
    return covered >= (b - a).distance - 1e-6;
  }

  /// Exact locked lengths determine a shared going. Unlocked counts use the
  /// nearest integer; proposals are returned for review, not applied in-place.
  static ArchitectStairDesign? fit(
    ArchitectStairDesign d, {
    bool Function(ArchitectStairDesign)? accepts,
  }) {
    final l = d.layout;
    if (l == null) return null;
    final candidates = <double>{d.going};
    if (!l.goingLocked) {
      candidates.add((.63 - 2 * d.riser).clamp(.28, .35));
      for (final f in l.flights.where((f) => f.fixedRun != null)) {
        for (var n = 2; n <= 500; n++) {
          if (f.countLocked && n != f.risers) continue;
          final g = f.fixedRun! / (n - 1);
          if (g >= .1 && g <= .6) candidates.add(g);
        }
      }
    }
    final sorted = candidates.toList()
      ..sort((a, b) => (a - d.going).abs().compareTo((b - d.going).abs()));
    for (final g in sorted) {
      final initial = [
        for (final f in l.flights)
          f.fixedRun == null || f.countLocked
              ? f
              : f.copyWith(risers: math.max(2, (f.fixedRun! / g).round() + 1)),
      ];
      final totals = d.manualRisers == null
          ? <int>{
              l.risers,
              math.max(
                2 * initial.length,
                (d.rise / d.preferredMaxRiser).ceil(),
              ),
            }
          : <int>{d.manualRisers!};
      for (final total in totals) {
        if (total > 500 || total < 2 * initial.length) continue;
        final flights = List<ArchitectStairFlightSpec>.of(initial);
        var difference = total - flights.fold<int>(0, (n, f) => n + f.risers);
        while (difference != 0) {
          int? best;
          var cost = double.infinity;
          final step = difference.sign;
          for (var i = 0; i < flights.length; i++) {
            final f = flights[i];
            if (f.countLocked || f.fixedRun != null || f.risers + step < 2)
              continue;
            final target = l.flights[i].run(d.going);
            final delta =
                ((f.risers + step - 1) * g - target).abs() -
                (f.run(g) - target).abs();
            if (delta < cost) {
              cost = delta;
              best = i;
            }
          }
          if (best == null) break;
          flights[best] = flights[best].copyWith(
            risers: flights[best].risers + step,
          );
          difference -= step;
        }
        if (difference != 0) continue;
        final layout = reconnect(l, l.copyWith(flights: flights), d.going, g);
        final next = d.copyWith(layout: layout, manualGoing: g);
        try {
          next.validate();
        } on ArgumentError {
          continue;
        }
        if (check(next).isEmpty && (accepts?.call(next) ?? true)) return next;
      }
    }
    return null;
  }

  /// Move only vertices on the changed connection edges. Other landing
  /// vertices, flight axes and the cell remain fixed in a fit proposal.
  static ArchitectStairLayout reconnect(
    ArchitectStairLayout old,
    ArchitectStairLayout next,
    double oldGoing,
    double newGoing,
  ) {
    final landings = List<ArchitectStairLandingSpec>.of(next.landings);
    for (var i = 0; i < landings.length; i++) {
      var points = List<Offset>.of(landings[i].polygon);
      for (final side in [i, i + 1]) {
        if (side >= next.flights.length) continue;
        final before = old.flights[side], after = next.flights[side];
        final a = side == i ? before.end(oldGoing) : before.origin;
        final b = side == i ? after.end(newGoing) : after.origin;
        points = [
          for (final p in points)
            ArchitectStairGeometry.cross(p - a, before.normal).abs() < 1e-6
                ? b +
                      after.normal *
                          (ArchitectStairGeometry.dot(p - a, before.normal) *
                              after.width /
                              before.width)
                : p,
        ];
      }
      landings[i] = landings[i].copyWith(polygon: points);
    }
    return next.copyWith(landings: landings);
  }

  static ArchitectStair normalizePlacement(ArchitectStair stair) {
    final d = stair.design!, layout = d.layout;
    if (layout == null) return stair;
    final first = layout.flights.first;
    final u = stair.unitVector, v = stair.normalVector * (d.turnLeft ? -1 : 1);
    final start = stair.startPoint + u * first.origin.dx + v * first.origin.dy;
    final axis = u * first.axis.dx + v * first.axis.dy;
    Offset point(Offset p) => Offset(
      ArchitectStairGeometry.dot(p - first.origin, first.axis),
      ArchitectStairGeometry.dot(p - first.origin, first.normal),
    );
    Offset direction(Offset p) => Offset(
      ArchitectStairGeometry.dot(p, first.axis),
      ArchitectStairGeometry.dot(p, first.normal),
    );
    return stair.copyWith(
      startPoint: start,
      endPoint: start + axis,
      width: first.width,
      design: d.copyWith(
        layout: layout.copyWith(
          flights: [
            for (final f in layout.flights)
              f.copyWith(origin: point(f.origin), axis: direction(f.axis)),
          ],
          landings: [
            for (final l in layout.landings)
              l.copyWith(polygon: l.polygon.map(point).toList()),
          ],
          cell: layout.cell.map(point).toList(),
        ),
      ),
    );
  }

  static ArchitectStairLayout fromStair(ArchitectStair stair) {
    final d = stair.design;
    if (d == null || d.isSpiral || d.hasWinders) {
      throw ArgumentError('Only straight-flight presets can be converted');
    }
    if (d.layout != null) return d.layout!;
    final geometry = ArchitectStairGeometry.of(stair);
    final u = stair.unitVector, v = stair.normalVector * (d.turnLeft ? -1 : 1);
    Offset local(Offset p) => Offset(
      ArchitectStairGeometry.dot(p - stair.startPoint, u),
      ArchitectStairGeometry.dot(p - stair.startPoint, v),
    );
    Offset axis(Offset p) => Offset(
      ArchitectStairGeometry.dot(p, u),
      ArchitectStairGeometry.dot(p, v),
    );
    return ArchitectStairLayout(
      flights: [
        for (var i = 0; i < geometry.flights.length; i++)
          ArchitectStairFlightSpec(
            id: 'flight_$i',
            origin: local(geometry.flights[i].origin),
            axis: axis(geometry.flights[i].axis),
            width: geometry.flights[i].width,
            risers: geometry.flights[i].count,
          ),
      ],
      landings: [
        for (var i = 0; i < geometry.landings.length; i++)
          ArchitectStairLandingSpec(
            id: 'landing_$i',
            polygon: geometry.landings[i].polygon.map(local).toList(),
          ),
      ],
    );
  }
}
