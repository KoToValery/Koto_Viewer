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
  @override
  String toString() => 'StairLayoutIssue($problem, $partId)';
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
      candidates.add(ArchitectStairDesign.roundGoing((.63 - 2 * d.riser).clamp(.28, .35)));
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

  /// Updates one flight and shifts/steps its adjoining landing port edges cleanly,
  /// preserving orthogonal corners and minimum landing clear depth.
  static ArchitectStairLayout updateFlightWithPorts(
    ArchitectStairLayout layout,
    double going,
    ArchitectStairFlightSpec oldFlight,
    ArchitectStairFlightSpec nextFlight,
  ) {
    final index = layout.flights.indexWhere((f) => f.id == oldFlight.id);
    if (index < 0) return layout;

    List<Offset> shiftPortOnPolygon(
      List<Offset> polygon, {
      required Offset a,
      required Offset b,
      required Offset c,
      required Offset e,
      required Offset intoLanding,
      required double minClearDepth,
      required bool allowPushBackWall,
      (Offset, Offset)? otherPort,
    }) {
      if ((a - c).distance < 1e-7 && (b - e).distance < 1e-7) return polygon;
      final split = <Offset>[];
      for (var k = 0; k < polygon.length; k++) {
        final p0 = polygon[k], p1 = polygon[(k + 1) % polygon.length];
        split.add(p0);
        final seg = p1 - p0;
        final segLen = seg.distance;
        if (segLen < 1e-7) continue;
        final inserts = <(double t, Offset pt)>[];
        for (final target in [a, b]) {
          if (ArchitectStairGeometry.pointSegmentDistance(target, p0, p1) <
                  1e-5 &&
              (target - p0).distance > 1e-5 &&
              (target - p1).distance > 1e-5) {
            final t = ArchitectStairGeometry.dot(target - p0, seg) /
                seg.distanceSquared;
            inserts.add((t, target));
          }
        }
        inserts.sort((x, y) => x.$1.compareTo(y.$1));
        for (final item in inserts) {
          if ((item.$2 - split.last).distance > 1e-5) {
            split.add(item.$2);
          }
        }
      }
      final pts = <Offset>[];
      for (final p in split) {
        if (pts.isEmpty || (p - pts.last).distance > 1e-5) pts.add(p);
      }
      if (pts.length > 1 && (pts.first - pts.last).distance <= 1e-5) {
        pts.removeLast();
      }
      if (pts.length < 3) return polygon;

      final n = pts.length;
      final idxA = pts.indexWhere((p) => (p - a).distance < 1e-4);
      final idxB = pts.indexWhere((p) => (p - b).distance < 1e-4);
      if (idxA < 0 || idxB < 0 || idxA == idxB) {
        return [
          for (final p in pts)
            ArchitectStairGeometry.pointSegmentDistance(p, a, b) < 1e-5
                ? c +
                    (e - c) *
                        (ArchitectStairGeometry.dot(p - a, b - a) /
                            (b - a).distanceSquared)
                : p,
        ];
      }

      bool allOnPort(int start, int end, int step) {
        var cur = start;
        while (true) {
          if (ArchitectStairGeometry.pointSegmentDistance(pts[cur], a, b) >
              1e-4) {
            return false;
          }
          if (cur == end) return true;
          cur = (cur + step + n) % n;
        }
      }

      int startIdx = idxA, endIdx = idxB;
      Offset oldStart = a, oldEnd = b, newStart = c, newEnd = e;
      if (!allOnPort(idxA, idxB, 1)) {
        if (allOnPort(idxB, idxA, 1)) {
          startIdx = idxB;
          endIdx = idxA;
          oldStart = b;
          oldEnd = a;
          newStart = e;
          newEnd = c;
        } else {
          return polygon;
        }
      }

      bool isParallelMove(Offset from, Offset to, Offset neighbor) {
        final move = to - from;
        final edge = from - neighbor;
        if (move.distance < 1e-6 || edge.distance < 1e-6) return true;
        return ArchitectStairGeometry.cross(edge, move).abs() <
            1e-4 * edge.distance * move.distance;
      }

      final prevIdx = (startIdx - 1 + n) % n;
      final nextIdx = (endIdx + 1) % n;
      final keepOldStart = !isParallelMove(oldStart, newStart, pts[prevIdx]);
      final keepOldEnd = !isParallelMove(oldEnd, newEnd, pts[nextIdx]);

      // When a port corner moves laterally (e.g. flight width edit) along a
      // landing edge that runs along the flight axis, translate that outer/inner
      // side corner so the edge remains perpendicular to the port.
      final latStart = newStart - oldStart;
      final latEnd = newEnd - oldEnd;
      final portSpan = oldEnd - oldStart;
      final portDir = portSpan.distance > 1e-8
          ? portSpan / portSpan.distance
          : Offset.zero;
      bool isAxisAlignedEdge(Offset edge, Offset move) {
        if (edge.distance < 1e-6 ||
            move.distance < 1e-6 ||
            portDir.distance < 1e-6) {
          return false;
        }
        return ArchitectStairGeometry.dot(edge, portDir).abs() <
                1e-4 * edge.distance &&
            ArchitectStairGeometry.dot(edge, move).abs() <
                1e-4 * edge.distance * move.distance;
      }
      bool touchesOther(Offset p) =>
          otherPort != null &&
          ArchitectStairGeometry.pointSegmentDistance(
                p,
                otherPort.$1,
                otherPort.$2,
              ) <=
              1e-4;

      final shiftPrevSide =
          keepOldStart &&
          isAxisAlignedEdge(oldStart - pts[prevIdx], latStart) &&
          !touchesOther(pts[prevIdx]);
      final shiftNextSide =
          keepOldEnd &&
          isAxisAlignedEdge(pts[nextIdx] - oldEnd, latEnd) &&
          !touchesOther(pts[nextIdx]);

      final rebuilt = <Offset>[];
      var i = (endIdx + 1) % n;
      while (i != startIdx) {
        var p = pts[i];
        if (i == nextIdx && shiftNextSide) p = p + latEnd;
        if (i == prevIdx && shiftPrevSide) p = p + latStart;
        rebuilt.add(p);
        i = (i + 1) % n;
      }
      if (keepOldStart && !shiftPrevSide) rebuilt.add(oldStart);
      rebuilt.add(newStart);
      rebuilt.add(newEnd);
      if (keepOldEnd && !shiftNextSide) rebuilt.add(oldEnd);

      var cleaned = <Offset>[];
      for (final p in rebuilt) {
        if (cleaned.isEmpty || (p - cleaned.last).distance > 1e-5) {
          cleaned.add(p);
        }
      }
      if (cleaned.length > 1 && (cleaned.first - cleaned.last).distance <= 1e-5) {
        cleaned.removeLast();
      }
      var removedColinear = true;
      while (removedColinear && cleaned.length > 3) {
        removedColinear = false;
        for (var idx = 0; idx < cleaned.length; idx++) {
          final prev = cleaned[(idx - 1 + cleaned.length) % cleaned.length];
          final curr = cleaned[idx];
          final next = cleaned[(idx + 1) % cleaned.length];
          final v1 = curr - prev, v2 = next - curr;
          final len = v1.distance * v2.distance;
          if (len > 1e-12 &&
              ArchitectStairGeometry.cross(v1, v2).abs() <= 1e-6 * len &&
              ArchitectStairGeometry.dot(v1, v2) >= 0) {
            cleaned.removeAt(idx);
            removedColinear = true;
            break;
          }
        }
      }

      final shift = newStart - oldStart;
      if (allowPushBackWall &&
          intoLanding.distance > 1e-6 &&
          ArchitectStairGeometry.dot(shift, intoLanding) > 1e-6) {
        var maxProj = double.negativeInfinity;
        for (final p in cleaned) {
          maxProj = math.max(maxProj, ArchitectStairGeometry.dot(p, intoLanding));
        }
        final reqProj =
            ArchitectStairGeometry.dot(c, intoLanding) + minClearDepth;
        if (maxProj < reqProj - 1e-5) {
          final push = reqProj - maxProj;
          bool isBack(Offset p) =>
              (ArchitectStairGeometry.dot(p, intoLanding) - maxProj).abs() <
              1e-4;
          bool pinned(Offset p) =>
              otherPort != null &&
              ArchitectStairGeometry.pointSegmentDistance(
                    p,
                    otherPort.$1,
                    otherPort.$2,
                  ) <=
                  1e-4;
          final pushed = <Offset>[];
          for (var k = 0; k < cleaned.length; k++) {
            final p = cleaned[k];
            if (!isBack(p)) {
              pushed.add(p);
              continue;
            }
            if (!pinned(p)) {
              pushed.add(p + intoLanding * push);
              continue;
            }
            final prev = cleaned[(k - 1 + cleaned.length) % cleaned.length];
            final next = cleaned[(k + 1) % cleaned.length];
            final prevShifted = isBack(prev) && !pinned(prev);
            final nextShifted = isBack(next) && !pinned(next);
            if (prevShifted) pushed.add(p + intoLanding * push);
            pushed.add(p);
            if (nextShifted) pushed.add(p + intoLanding * push);
          }
          cleaned = pushed;
        }
      }
      return cleaned;
    }

    final landings = List<ArchitectStairLandingSpec>.of(layout.landings);
    for (final entry in [
      (
        landingIdx: index - 1,
        oldCenter: oldFlight.origin,
        newCenter: nextFlight.origin,
        intoLanding: -oldFlight.axis,
      ),
      (
        landingIdx: index,
        oldCenter: oldFlight.end(going),
        newCenter: nextFlight.end(going),
        intoLanding: oldFlight.axis,
      ),
    ]) {
      if (entry.landingIdx < 0 || entry.landingIdx >= landings.length) {
        continue;
      }
      final l = landings[entry.landingIdx];
      final oldDepth = ArchitectStairLayoutResolver.landingDepth(
        ArchitectStairDesign(
          shape: StairShape.straight,
          manualGoing: going,
          layout: layout,
        ),
        landingIndex: entry.landingIdx,
      );
      final incoming = layout.flights[entry.landingIdx];
      final outgoing = layout.flights[entry.landingIdx + 1];
      final otherFlight = entry.landingIdx == index - 1 ? incoming : outgoing;
      final otherCenter = entry.landingIdx == index - 1
          ? incoming.end(going)
          : outgoing.origin;
      final otherPort = (
        otherCenter - otherFlight.normal * otherFlight.width / 2,
        otherCenter + otherFlight.normal * otherFlight.width / 2,
      );
      final minClear = math.max(
        oldDepth.isFinite ? oldDepth : 0.0,
        math.max(incoming.width, outgoing.width),
      );
      landings[entry.landingIdx] = l.copyWith(
        polygon: shiftPortOnPolygon(
          l.polygon,
          a: entry.oldCenter - oldFlight.normal * oldFlight.width / 2,
          b: entry.oldCenter + oldFlight.normal * oldFlight.width / 2,
          c: entry.newCenter - nextFlight.normal * nextFlight.width / 2,
          e: entry.newCenter + nextFlight.normal * nextFlight.width / 2,
          intoLanding: entry.intoLanding,
          minClearDepth: minClear,
          allowPushBackWall: layout.cell.isEmpty,
          otherPort: otherPort,
        ),
      );
    }
    return layout.copyWith(
      flights: [
        for (final f in layout.flights) f.id == nextFlight.id ? nextFlight : f,
      ],
      landings: landings,
    );
  }

  /// Slides a flight as a unit while rebuilding its landing connections.
  static ArchitectStair translateFlight(
    ArchitectStair stair,
    int flightIndex,
    Offset localShift,
  ) {
    if (localShift.distance < 1e-6) return stair;
    final design = stair.design!;
    final layout = design.layout ?? fromStair(stair);
    final flight = layout.flights[flightIndex];
    final updated = updateFlightWithPorts(
      layout,
      design.going,
      flight,
      flight.copyWith(origin: flight.origin + localShift),
    );
    final next = design.copyWith(layout: updated, manualGoing: design.going);
    if (check(next).isNotEmpty) {
      throw ArgumentError('Flight shift violates stair layout constraints');
    }
    return normalizePlacement(stair.copyWith(design: next));
  }

  /// Signed gap along a return stair's incoming axis between its two ports.
  static double? returnStagger(ArchitectStairDesign design, int landingIndex) {
    final layout = design.layout!;
    final incoming = layout.flights[landingIndex];
    final outgoing = layout.flights[landingIndex + 1];
    if ((incoming.axis + outgoing.axis).distance > 1e-6) return null;
    return ArchitectStairGeometry.dot(
      incoming.end(design.going) - outgoing.origin,
      incoming.axis,
    );
  }

  static ArchitectStair setReturnStagger(
    ArchitectStair stair,
    int landingIndex,
    double distance,
  ) {
    final design = stair.design!;
    final oldDistance = returnStagger(design, landingIndex);
    if (oldDistance == null || !distance.isFinite) {
      throw ArgumentError('Invalid return stair stagger');
    }
    final outgoing = design.layout!.flights[landingIndex + 1];
    return translateFlight(
      stair,
      landingIndex + 1,
      outgoing.axis * (distance - oldDistance),
    );
  }

  /// Updates all flight widths in [layout] uniformly and keeps landing ports &
  /// side edges orthogonal.
  static ArchitectStairLayout resizeFlightWidths(
    ArchitectStairLayout layout,
    double going,
    double newWidth,
  ) {
    var current = layout;
    for (var i = 0; i < current.flights.length; i++) {
      final f = current.flights[i];
      if ((f.width - newWidth).abs() < 1e-7) continue;
      current = updateFlightWithPorts(
        current,
        going,
        f,
        f.copyWith(width: newWidth),
      );
    }
    return current;
  }

  /// Shifts the outer back edge of landing [landingIndex] along [axis] to set
  /// its clear projection depth relative to the incoming flight port.
  static ArchitectStairLayout updateLandingDepth(
    ArchitectStairLayout layout,
    double going,
    int landingIndex,
    Offset axis,
    double targetProj,
  ) {
    if (landingIndex < 0 || landingIndex >= layout.landings.length) {
      return layout;
    }
    final l = layout.landings[landingIndex];
    final poly = l.polygon;
    if (poly.length < 3) return layout;
    final incoming = layout.flights[landingIndex];
    final outgoing = layout.flights[landingIndex + 1];
    final inPort = (
      incoming.end(going) - incoming.normal * incoming.width / 2,
      incoming.end(going) + incoming.normal * incoming.width / 2,
    );
    final outPort = (
      outgoing.origin - outgoing.normal * outgoing.width / 2,
      outgoing.origin + outgoing.normal * outgoing.width / 2,
    );

    var maxProj = double.negativeInfinity;
    for (final p in poly) {
      maxProj = math.max(maxProj, ArchitectStairGeometry.dot(p, axis));
    }
    final delta = targetProj - maxProj;
    if (delta.abs() < 1e-6) return layout;

    bool isBack(Offset p) =>
        (ArchitectStairGeometry.dot(p, axis) - maxProj).abs() < 1e-4;
    bool pinned(Offset p) =>
        ArchitectStairGeometry.pointSegmentDistance(p, inPort.$1, inPort.$2) <=
            1e-4 ||
        ArchitectStairGeometry.pointSegmentDistance(
              p,
              outPort.$1,
              outPort.$2,
            ) <=
            1e-4;

    final nextPoly = <Offset>[];
    for (var k = 0; k < poly.length; k++) {
      final p = poly[k];
      if (!isBack(p)) {
        nextPoly.add(p);
        continue;
      }
      if (!pinned(p)) {
        nextPoly.add(p + axis * delta);
        continue;
      }
      final prev = poly[(k - 1 + poly.length) % poly.length];
      final next = poly[(k + 1) % poly.length];
      if (isBack(prev) && !pinned(prev)) nextPoly.add(p + axis * delta);
      nextPoly.add(p);
      if (isBack(next) && !pinned(next)) nextPoly.add(p + axis * delta);
    }

    final landings = List<ArchitectStairLandingSpec>.of(layout.landings);
    landings[landingIndex] = l.copyWith(polygon: nextPoly);
    return layout.copyWith(landings: landings);
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
