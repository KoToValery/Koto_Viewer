import 'dart:math' as math;
import 'dart:ui';
import '../models/architect_elements.dart';
import 'architect_stair_geometry.dart';
import 'architect_stair_layout_resolver.dart';

/// Leader-line endpoint handle on a stair flight (start/end) for direct
/// on-plan editing with model snapping.
class StairEndpointHandle {
  final int flightIndex;
  final bool atStart;
  final int? landingIndex;
  final Offset anchor;
  final Offset handle;
  final Offset opposite;
  final bool isOffset;

  const StairEndpointHandle({
    required this.flightIndex,
    required this.atStart,
    this.landingIndex,
    required this.anchor,
    required this.handle,
    required this.opposite,
    this.isOffset = true,
  });

  StairEndpointHandle withOffset(bool offset) => StairEndpointHandle(
    flightIndex: flightIndex,
    atStart: atStart,
    landingIndex: landingIndex,
    anchor: anchor,
    handle: handle,
    opposite: opposite,
    isOffset: offset,
  );
}

/// Computes, hit-tests, and applies drag edits for stair flight leader handles.
class ArchitectStairHandles {
  static List<StairEndpointHandle> handles(
    ArchitectStair stair,
    double clearance,
  ) {
    final d = stair.design;
    if (d == null) {
      final u = stair.unitVector;
      return [
        StairEndpointHandle(
          flightIndex: 0,
          atStart: true,
          anchor: stair.startPoint,
          handle: stair.startPoint - u * clearance,
          opposite: stair.endPoint,
        ),
        StairEndpointHandle(
          flightIndex: 0,
          atStart: false,
          anchor: stair.endPoint,
          handle: stair.endPoint + u * clearance,
          opposite: stair.startPoint,
        ),
      ];
    }
    if (d.isSpiral || d.hasWinders) {
      final first = stair.plan.nosings.first;
      final last = stair.plan.nosings.last;
      final startMid = (first.$1 + first.$2) / 2;
      final endMid = (last.$1 + last.$2) / 2;
      final u = stair.unitVector;
      final v = stair.normalVector * (d.turnLeft ? -1 : 1);
      final sweep = d.isSpiral
          ? d.sweepDegrees * math.pi / 180
          : d.turnQuarters * math.pi / 2;
      final exitAxis = u * math.cos(sweep) + v * math.sin(sweep);
      return [
        StairEndpointHandle(
          flightIndex: 0,
          atStart: true,
          anchor: startMid,
          handle: startMid - u * clearance,
          opposite: endMid,
        ),
        StairEndpointHandle(
          flightIndex: 0,
          atStart: false,
          anchor: endMid,
          handle: endMid + exitAxis * clearance,
          opposite: startMid,
        ),
      ];
    }
    final geom = ArchitectStairGeometry.of(stair);
    final flights = geom.flights;
    final landings = geom.landings;
    return [
      for (var i = 0; i < flights.length; i++) ...[
        () {
          final f = flights[i];
          final start = f.origin;
          final end = f.origin + f.axis * f.run;
          return StairEndpointHandle(
            flightIndex: i,
            atStart: true,
            anchor: start,
            handle: start - f.axis * clearance,
            opposite: end,
          );
        }(),
        () {
          final f = flights[i];
          final start = f.origin;
          final end = f.origin + f.axis * f.run;
          return StairEndpointHandle(
            flightIndex: i,
            atStart: false,
            anchor: end,
            handle: end + f.axis * clearance,
            opposite: start,
          );
        }(),
      ],
      for (var i = 0; i < landings.length && i < flights.length; i++)
        if (_landingBackHandle(
          landings[i],
          flights[i],
          i,
          clearance,
        )
            case final landingHandle?)
          landingHandle,
    ];
  }

  static StairEndpointHandle? _landingBackHandle(
    StairLandingGeometry landing,
    StairFlightGeometry incoming,
    int landingIndex,
    double clearance,
  ) {
    final poly = landing.polygon;
    if (poly.length < 3) return null;
    Offset? bestMid;
    var bestProj = double.negativeInfinity;
    for (var k = 0; k < poly.length; k++) {
      final p0 = poly[k], p1 = poly[(k + 1) % poly.length];
      final seg = p1 - p0;
      if (seg.distance < 1e-4) continue;
      final dir = seg / seg.distance;
      if (ArchitectStairGeometry.dot(dir, incoming.axis).abs() > 0.35) continue;
      final mid = (p0 + p1) / 2;
      final proj = ArchitectStairGeometry.dot(mid, incoming.axis);
      if (proj > bestProj) {
        bestProj = proj;
        bestMid = mid;
      }
    }
    if (bestMid == null) return null;
    final incomingEnd = incoming.origin + incoming.axis * incoming.run;
    return StairEndpointHandle(
      flightIndex: landingIndex,
      atStart: false,
      landingIndex: landingIndex,
      anchor: bestMid,
      handle: bestMid + incoming.axis * clearance,
      opposite: incomingEnd,
    );
  }

  static StairEndpointHandle? hitTest(
    ArchitectStair stair,
    Offset rawModel,
    double scale,
    double handleOffsetPx,
  ) {
    final clearance = handleOffsetPx / scale;
    final items = handles(stair, clearance);
    if (items.isEmpty) return null;
    if (handleOffsetPx > 0) {
      final offsetTol = math.max(28.0 / scale, 0.35);
      StairEndpointHandle? best;
      var bestDist = offsetTol;
      for (final h in items) {
        final d = (rawModel - h.handle).distance;
        if (d <= bestDist) {
          bestDist = d;
          best = h;
        }
      }
      if (best != null) return best.withOffset(true);
    }
    final directTol = math.max(14.0 / scale, 0.25);
    StairEndpointHandle? bestDirect;
    var bestDirectDist = directTol;
    for (final h in items) {
      final d = (rawModel - h.anchor).distance;
      if (d <= bestDirectDist) {
        bestDirectDist = d;
        bestDirect = h;
      }
    }
    return bestDirect?.withOffset(false);
  }

  static Offset anchorFor(
    ArchitectStair stair,
    StairEndpointHandle hit,
  ) {
    final items = handles(stair, 0);
    for (final h in items) {
      if (h.landingIndex == hit.landingIndex &&
          h.flightIndex == hit.flightIndex &&
          h.atStart == hit.atStart) {
        return h.anchor;
      }
    }
    return hit.anchor;
  }

  static ArchitectStair applyDrag(
    ArchitectStair original,
    StairEndpointHandle hit,
    Offset snappedPoint,
  ) {
    final d = original.design;
    if (d == null) {
      final start = hit.atStart ? snappedPoint : original.startPoint;
      final end = hit.atStart ? original.endPoint : snappedPoint;
      if ((end - start).distance < 0.1) return original;
      return original.copyWith(startPoint: start, endPoint: end);
    }
    if (d.layout == null &&
        d.shape == StairShape.straight &&
        d.flightCount == 1) {
      final fixed = hit.opposite;
      final delta = hit.atStart ? fixed - snappedPoint : snappedPoint - fixed;
      if (delta.distance < 0.05) return original;
      final axis = delta / delta.distance;
      final going = ArchitectStairDesign.roundGoing(d.going);
      final treads = math.max(1, (delta.distance / going).round());
      final nextRisers = (treads + 1).clamp(2, 500);
      final run = treads * going;
      final nextStart = hit.atStart ? fixed - axis * run : fixed;
      final nextEnd = hit.atStart ? fixed : fixed + axis * run;
      return original.copyWith(
        startPoint: nextStart,
        endPoint: nextEnd,
        design: d.copyWith(manualGoing: going, manualRisers: nextRisers),
      );
    }
    if (d.isSpiral) {
      final u = original.unitVector;
      final v = original.normalVector * (d.turnLeft ? -1 : 1);
      final centre =
          original.startPoint + v * (d.innerRadius + original.width / 2);
      final fromCentre = snappedPoint - centre;
      if (fromCentre.distance < 0.05) return original;
      if (hit.atStart) {
        final targetRadial = fromCentre / fromCentre.distance;
        final nextU = d.turnLeft
            ? Offset(-targetRadial.dy, targetRadial.dx)
            : Offset(targetRadial.dy, -targetRadial.dx);
        final nextStart = centre + targetRadial * (d.innerRadius + original.width / 2);
        return original.copyWith(
          startPoint: nextStart,
          endPoint: nextStart + nextU * math.max(1.0, original.length),
        );
      } else {
        final angle = math.atan2(
          ArchitectStairGeometry.dot(fromCentre, u),
          -ArchitectStairGeometry.dot(fromCentre, v),
        );
        var deg = (angle * 180 / math.pi).roundToDouble();
        if (deg <= 0) deg += 360;
        if (d.shape == StairShape.spiralOverlap) {
          final turns = (d.sweepDegrees / 360).floor();
          deg = (turns * 360 + deg).clamp(360.001, 1080.0);
        } else {
          deg = deg.clamp(30.0, 360.0);
        }
        final minRisers = (deg / 180.0).floor() + 2;
        return original.copyWith(
          design: d.copyWith(
            sweepDegrees: deg,
            manualRisers: math.max(d.risers, minRisers),
          ),
        );
      }
    }
    if (d.hasWinders) {
      final u = original.unitVector;
      final v = original.normalVector * (d.turnLeft ? -1 : 1);
      final sweep = d.turnQuarters * math.pi / 2;
      final exitAxis = u * math.cos(sweep) + v * math.sin(sweep);
      final outward = hit.atStart ? -u : exitAxis;
      final going = ArchitectStairDesign.roundGoing(d.going);
      final extra = ArchitectStairGeometry.dot(
        snappedPoint - hit.anchor,
        outward,
      );
      final deltaTreads = (extra / going).round();
      final turnCount =
          d.winderLayout(original.width).perQuarter * d.turnQuarters;
      final minRisers = turnCount + 3;
      final nextRisers = (d.risers + deltaTreads).clamp(minRisers, 500);
      if (hit.atStart) {
        final oldLead = (d.risers - 1 - turnCount) ~/ 2;
        final newLead = (nextRisers - 1 - turnCount) ~/ 2;
        final shift = -u * ((newLead - oldLead) * going);
        return original.copyWith(
          startPoint: original.startPoint + shift,
          endPoint: original.endPoint + shift,
          design: d.copyWith(manualGoing: going, manualRisers: nextRisers),
        );
      }
      return original.copyWith(
        design: d.copyWith(manualGoing: going, manualRisers: nextRisers),
      );
    }

    // Multi-flight straight/turn presets or custom layouts:
    if (hit.landingIndex != null) {
      final li = hit.landingIndex!;
      if (d.layout == null) {
        final flights = ArchitectStairGeometry.of(original).flights;
        if (li < 0 || li >= flights.length) return original;
        final incoming = flights[li];
        final rawDepth = ArchitectStairGeometry.dot(
          snappedPoint - hit.opposite,
          incoming.axis,
        );
        final nextDepth =
            (rawDepth.clamp(original.width, 10.0) * 100.0).round() / 100.0;
        return original.copyWith(design: d.copyWith(landingDepth: nextDepth));
      }
      final baseLayout = d.layout!;
      if (li < 0 || li >= baseLayout.landings.length) return original;
      final u = original.unitVector;
      final v = original.normalVector * (d.turnLeft ? -1 : 1);
      final q = snappedPoint - original.startPoint;
      final localTarget = Offset(
        ArchitectStairGeometry.dot(q, u),
        ArchitectStairGeometry.dot(q, v),
      );
      final going = ArchitectStairDesign.roundGoing(d.going);
      final incoming = baseLayout.flights[li];
      final incomingEndProj = ArchitectStairGeometry.dot(
        incoming.end(going),
        incoming.axis,
      );
      final minProj = incomingEndProj + incoming.width;
      final targetProj = math.max(
        minProj,
        (ArchitectStairGeometry.dot(localTarget, incoming.axis) * 100.0)
                .round() /
            100.0,
      );
      final nextLayout = ArchitectStairLayoutResolver.updateLandingDepth(
        baseLayout,
        going,
        li,
        incoming.axis,
        targetProj,
      );
      final nextDesign = d.copyWith(
        shape: StairShape.straight,
        winderSteps: false,
        manualGoing: going,
        manualRisers: d.manualRisers == null ? null : nextLayout.risers,
        autoRisers: d.manualRisers == null,
        layout: nextLayout,
      );
      if (ArchitectStairLayoutResolver.check(nextDesign).isNotEmpty) {
        throw ArgumentError('Invalid landing handle drag');
      }
      return ArchitectStairLayoutResolver.normalizePlacement(
        original.copyWith(design: nextDesign),
      );
    }

    // Edit the targeted flight along its axis and reconnect its landing port cleanly.
    final baseLayout =
        d.layout ?? ArchitectStairLayoutResolver.fromStair(original);
    if (hit.flightIndex < 0 || hit.flightIndex >= baseLayout.flights.length) {
      return original;
    }
    final u = original.unitVector;
    final v = original.normalVector * (d.turnLeft ? -1 : 1);
    Offset toLocal(Offset p) {
      final q = p - original.startPoint;
      return Offset(
        ArchitectStairGeometry.dot(q, u),
        ArchitectStairGeometry.dot(q, v),
      );
    }

    final going = ArchitectStairDesign.roundGoing(d.going);
    final f = baseLayout.flights[hit.flightIndex];
    final localTarget = toLocal(snappedPoint);
    late final ArchitectStairFlightSpec nextFlight;
    if (hit.atStart) {
      final fixedEnd = f.end(going);
      final along = ArchitectStairGeometry.dot(fixedEnd - localTarget, f.axis);
      if (along < 0.05) throw ArgumentError('Flight too short');
      final treads = math.max(1, (along / going).round());
      final nextRun = treads * going;
      nextFlight = f.copyWith(
        origin: fixedEnd - f.axis * nextRun,
        risers: treads + 1,
        clearFixedRun: f.fixedRun == null,
        fixedRun: f.fixedRun != null ? nextRun : null,
      );
    } else {
      final fixedOrigin = f.origin;
      final along = ArchitectStairGeometry.dot(
        localTarget - fixedOrigin,
        f.axis,
      );
      if (along < 0.05) throw ArgumentError('Flight too short');
      final treads = math.max(1, (along / going).round());
      final nextRun = treads * going;
      nextFlight = f.copyWith(
        risers: treads + 1,
        clearFixedRun: f.fixedRun == null,
        fixedRun: f.fixedRun != null ? nextRun : null,
      );
    }
    final nextLayout = ArchitectStairLayoutResolver.updateFlightWithPorts(
      baseLayout,
      going,
      f,
      nextFlight,
    );
    final nextDesign = d.copyWith(
      shape: StairShape.straight,
      winderSteps: false,
      manualGoing: going,
      manualRisers: d.manualRisers == null ? null : nextLayout.risers,
      autoRisers: d.manualRisers == null,
      layout: nextLayout,
    );
    if (ArchitectStairLayoutResolver.check(nextDesign).isNotEmpty) {
      throw ArgumentError('Invalid stair handle drag');
    }
    return ArchitectStairLayoutResolver.normalizePlacement(
      original.copyWith(design: nextDesign),
    );
  }
}
