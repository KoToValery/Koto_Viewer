import 'dart:math' as math;
import 'dart:ui';
import '../models/architect_elements.dart';
import 'architect_polygon_geometry.dart';
import 'architect_stair_draft_controller.dart';

enum StairPerimeterPart { flight, landing }

class StairPerimeterSegment {
  final StairPerimeterPart part;
  final Offset start, end;
  final double width;
  const StairPerimeterSegment(this.part, this.start, this.end, this.width);
  Offset get axis => (end - start) / (end - start).distance;
}

/// The user traces one continuous outside edge. Only Apply publishes the stair.
class ArchitectStairPerimeterDraft extends ArchitectStairDraftController {
  final ArchitectStair seed;
  final segments = <StairPerimeterSegment>[];
  final _future = <StairPerimeterSegment>[];
  (Offset?, bool)? _pointerBefore;
  Object? _previewKey;
  ArchitectStair? _previewValue;
  Object? _snapKey;
  ArchitectStair? _snapValue;
  (ArchitectStairDesign, double)? _designKey;
  ArchitectStairDesign? _designValue;
  StairPerimeterPart part = StairPerimeterPart.flight;
  Offset? anchor, target;
  bool reviewing = false, sideLocked = false;
  double side = 1, width;
  double _baseGoing, _going;
  final int? targetRisers;
  ArchitectStairPerimeterDraft(this.seed)
    : width = seed.width,
      _baseGoing = ArchitectStairDesign.roundGoing(seed.design!.going),
      _going = ArchitectStairDesign.roundGoing(seed.design!.going),
      targetRisers = seed.design!.manualRisers,
      super(
        seed.copyWith(
          design: seed.design!.copyWith(
            clearLayout: true,
            autoRisers: true,
          ),
        ),
        create: true,
      );
  void setWidth(double value) {
    if (value > .01 && value.isFinite) {
      width = value;
      _going = _effectiveGoing(visibleSegments);
      notifyListeners();
    }
  }

  double get length =>
      anchor == null || target == null ? 0 : (target! - anchor!).distance;
  bool snapExact = false;
  void beginPointer() {
    _pointerBefore = (target, reviewing);
  }

  void endPointer() {
    _pointerBefore = null;
  }

  void cancelPointer() {
    final old = _pointerBefore;
    if (old != null) {
      target = old.$1;
      reviewing = old.$2;
    }
    _pointerBefore = null;
    _going = _effectiveGoing(visibleSegments);
    notifyListeners();
  }

  void choose(StairPerimeterPart next) {
    part = next;
    _going = _effectiveGoing(visibleSegments);
    notifyListeners();
  }

  void flip() {
    side = -side;
    sideLocked = true;
    _going = _effectiveGoing(visibleSegments);
    notifyListeners();
  }

  double _goingForRun(double run, {bool mustNotExceed = false}) {
    if (run <= .001) return _baseGoing;
    final treads = math.max(1, (run / _baseGoing).round());
    final raw = run / treads;
    var rounded = ArchitectStairDesign.roundGoing(raw).clamp(.10, 2.0);
    if (mustNotExceed && treads * rounded > run + 1e-6) {
      rounded = ((raw * 1000 + 1e-9).floorToDouble() / 1000.0).clamp(.10, 2.0);
    }
    return rounded;
  }

  double _effectiveGoing(List<StairPerimeterSegment> source) =>
      _buildGeometry(source).going;

  Offset _flightEndAnchor(ArchitectStairFlightSpec flight, double sideSign) =>
      flight.end(_going) - flight.normal * (sideSign * flight.width / 2);

  @override
  void aim(Offset world) {
    if (reviewing) return;
    var p = world;
    if (anchor != null && part == StairPerimeterPart.flight) {
      final v = p - anchor!;
      if (!snapExact && v.distance > .001) {
        final axis = v / v.distance;
        final provisionalSide = _sideFor([
          ...segments,
          StairPerimeterSegment(part, anchor!, p, width),
        ]);
        final committed = _buildGeometry(
          segments,
          overrideSide: provisionalSide,
        );
        var advance = 0.0;
        if (committed.pendingHull.length >= 3) {
          final normal = Offset(-axis.dy, axis.dx) * provisionalSide;
          advance = _corridorAdvance(
            anchor! + normal * (width / 2),
            axis,
            normal,
            width,
            committed.pendingHull,
          );
        }
        final step = segments.any((s) => s.part == StairPerimeterPart.flight)
            ? committed.going
            : _baseGoing;
        final flightDist = v.distance - advance;
        if (flightDist > .001) {
          final snappedFlight = math.max(
            step,
            (flightDist / step).round() * step,
          );
          p = anchor! + axis * (advance + snappedFlight);
        }
      }
    }
    target = p;
    _going = _effectiveGoing(visibleSegments);
    notifyListeners();
  }

  @override
  void pick(Offset world, {double tolerance = .15}) {
    if (anchor == null) {
      anchor = world;
      target = world;
    } else {
      reviewing = false;
      aim(world);
      reviewing = length > .001;
    }
    _going = _effectiveGoing(visibleSegments);
    notifyListeners();
  }

  void unlock() {
    reviewing = false;
    notifyListeners();
  }

  void setLength(double value) {
    if (!value.isFinite || value <= .001 || anchor == null) return;
    final v = (target ?? anchor! + const Offset(1, 0)) - anchor!;
    final axis = v.distance > .001 ? v / v.distance : const Offset(1, 0);
    target = anchor! + axis * value;
    reviewing = true;
    _going = _effectiveGoing(visibleSegments);
    notifyListeners();
  }

  bool acceptPart() {
    if (anchor == null || target == null || length < .001) return false;
    if (segments.isEmpty && part != StairPerimeterPart.flight) return false;
    if (segments.isNotEmpty &&
        part == StairPerimeterPart.flight &&
        segments.last.part == part) {
      return false;
    }
    final segment = StairPerimeterSegment(part, anchor!, target!, width);
    final nextSegments = [...segments, segment];
    final expectedFlights = nextSegments
        .where((s) => s.part == StairPerimeterPart.flight)
        .length;
    final geom = _buildGeometry(nextSegments);
    if (geom.layout.flights.length != expectedFlights) return false;
    if (!sideLocked && segments.isNotEmpty) {
      side = geom.side;
    }
    segments.add(segment);
    _future.clear();
    _going = geom.going;
    if (segment.part == StairPerimeterPart.flight) {
      anchor = _flightEndAnchor(geom.layout.flights.last, geom.side);
    } else {
      anchor = target;
    }
    reviewing = false;
    part = segment.part == StairPerimeterPart.flight
        ? StairPerimeterPart.landing
        : StairPerimeterPart.flight;
    notifyListeners();
    return true;
  }

  List<StairPerimeterSegment> get visibleSegments => [
    ...segments,
    if (anchor != null &&
        target != null &&
        length > .001 &&
        (segments.isNotEmpty || part == StairPerimeterPart.flight))
      StairPerimeterSegment(part, anchor!, target!, width),
  ];

  static double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

  static List<Offset> _clipToCorridorStrip(
    List<Offset> polygon,
    Offset origin,
    Offset axis,
    Offset normal,
    double half,
  ) {
    var pts = [
      for (final p in polygon)
        Offset(_dot(p - origin, axis), _dot(p - origin, normal)),
    ];
    List<Offset> clipHalfPlane(List<Offset> input, bool lower) {
      if (input.isEmpty) return const [];
      final bound = lower ? -half : half;
      bool inside(Offset v) => lower ? v.dy >= -half : v.dy <= half;
      Offset intersect(Offset a, Offset b) {
        final den = b.dy - a.dy;
        if (den.abs() < 1e-12) return a;
        final t = ((bound - a.dy) / den).clamp(0.0, 1.0);
        return Offset(a.dx + (b.dx - a.dx) * t, bound);
      }

      final out = <Offset>[];
      for (var i = 0; i < input.length; i++) {
        final cur = input[i];
        final prev = input[(i - 1 + input.length) % input.length];
        final curIn = inside(cur);
        final prevIn = inside(prev);
        if (curIn) {
          if (!prevIn) out.add(intersect(prev, cur));
          out.add(cur);
        } else if (prevIn) {
          out.add(intersect(prev, cur));
        }
      }
      return out;
    }

    pts = clipHalfPlane(pts, true);
    pts = clipHalfPlane(pts, false);
    return pts;
  }

  static double _corridorTrimEnd(
    Offset origin,
    Offset axis,
    Offset normal,
    double width,
    double rawEnd,
    List<Offset> obstacle,
  ) {
    final half = width / 2 - 1e-4;
    if (half <= 0 || obstacle.length < 3) return rawEnd;
    final clipped = _clipToCorridorStrip(obstacle, origin, axis, normal, half);
    if (clipped.length < 3) return rawEnd;
    var minT = double.infinity;
    var maxT = double.negativeInfinity;
    for (final pt in clipped) {
      if (pt.dx < minT) minT = pt.dx;
      if (pt.dx > maxT) maxT = pt.dx;
    }
    if (maxT <= 1e-4 || minT >= rawEnd - 1e-4) return rawEnd;
    return math.max(0.0, math.min(rawEnd, minT));
  }

  static double _corridorAdvance(
    Offset rawOrigin,
    Offset axis,
    Offset normal,
    double width,
    List<Offset> obstacle,
  ) {
    final half = width / 2 - 1e-4;
    if (half <= 0 || obstacle.length < 3) return 0;
    final clipped = _clipToCorridorStrip(
      obstacle,
      rawOrigin,
      axis,
      normal,
      half,
    );
    var advance = 0.0;
    for (final pt in clipped) {
      if (pt.dx > advance) advance = pt.dx;
    }
    return advance;
  }

  ({
    ArchitectStairLayout layout,
    List<List<Offset>> pendingQuads,
    List<Offset> pendingHull,
    double going,
    double side,
  }) _buildGeometry(List<StairPerimeterSegment> source, {double? overrideSide}) {
    final sSide = overrideSide ?? _sideFor(source);
    // Pass 1: derive each flight's clear corridor after inward turning landings
    // trim the preceding flight end and advance the following flight start.
    final drafts = <({
      Offset origin,
      Offset axis,
      Offset normal,
      double width,
      double run,
      bool trimmedByTurn,
      List<List<Offset>> precedingPending,
    })>[];
    final pending = <List<Offset>>[];
    var truncated = false;
    for (final s in source) {
      if (s.part == StairPerimeterPart.landing) {
        final n = Offset(-s.axis.dy, s.axis.dx) * sSide * s.width;
        final corners = <Offset>[s.start, s.end, s.end + n, s.start + n];
        if (drafts.isNotEmpty) {
          final last = drafts.last;
          final trimmed = _corridorTrimEnd(
            last.origin,
            last.axis,
            last.normal,
            last.width,
            last.run,
            corners,
          );
          if (trimmed <= 1e-4) {
            truncated = true;
          }
          drafts[drafts.length - 1] = (
            origin: last.origin,
            axis: last.axis,
            normal: last.normal,
            width: last.width,
            run: trimmed,
            trimmedByTurn: last.trimmedByTurn || trimmed < last.run - 1e-6,
            precedingPending: last.precedingPending,
          );
        }
        pending.add(corners);
        continue;
      }
      if (truncated) break;
      final normal = Offset(-s.axis.dy, s.axis.dx) * sSide;
      var origin = s.start + normal * s.width / 2;
      var run = (s.end - s.start).distance;
      if (drafts.isNotEmpty && pending.isNotEmpty) {
        final prev = drafts.last;
        final prevEnd = prev.origin + prev.axis * prev.run;
        final pendingHull = _hull([
          for (final quad in pending) ...quad,
          prevEnd - prev.normal * prev.width / 2,
          prevEnd + prev.normal * prev.width / 2,
        ]);
        final advance = _corridorAdvance(
          origin,
          s.axis,
          normal,
          s.width,
          pendingHull,
        );
        if (advance > 1e-4) {
          origin = origin + s.axis * advance;
          run = math.max(0.0, run - advance);
        }
      }
      if (run <= 1e-4) {
        break;
      }
      drafts.add((
        origin: origin,
        axis: s.axis,
        normal: normal,
        width: s.width,
        run: run,
        trimmedByTurn: false,
        precedingPending: List<List<Offset>>.unmodifiable(pending),
      ));
      pending.clear();
    }

    if (truncated || drafts.isEmpty) {
      return (
        layout: ArchitectStairLayout(flights: const []),
        pendingQuads: pending,
        pendingHull: const <Offset>[],
        going: _baseGoing,
        side: sSide,
      );
    }

    // Pass 2: fit whole steps to the trimmed clear corridors.
    final g = _goingForRun(
      drafts.first.run,
      mustNotExceed: drafts.first.trimmedByTurn,
    );
    final flights = <ArchitectStairFlightSpec>[];
    final landings = <ArchitectStairLandingSpec>[];
    for (var i = 0; i < drafts.length; i++) {
      final d = drafts[i];
      final treads = math.max(1, (d.run / g).round());
      final isFirst = i == 0;
      final fittedRun = treads * g;
      final f = ArchitectStairFlightSpec(
        id: 'flight_$i',
        origin: d.origin,
        axis: d.axis,
        width: d.width,
        risers: treads + 1,
        fixedRun: isFirst || (d.run - fittedRun).abs() <= 1e-6 ? fittedRun : null,
      );
      if (i > 0 && d.precedingPending.isNotEmpty) {
        final previous = flights.last;
        landings.add(
          ArchitectStairLandingSpec(
            id: 'landing_${landings.length}',
            polygon: _landingPolygon(d.precedingPending, previous, f, g),
          ),
        );
      }
      flights.add(f);
    }
    final pendingHull = pending.isNotEmpty && flights.isNotEmpty
        ? _hull([
            for (final quad in pending) ...quad,
            flights.last.end(g) -
                flights.last.normal * flights.last.width / 2,
            flights.last.end(g) +
                flights.last.normal * flights.last.width / 2,
          ])
        : const <Offset>[];
    return (
      layout: ArchitectStairLayout(flights: flights, landings: landings),
      pendingQuads: pending,
      pendingHull: pendingHull,
      going: g,
      side: sSide,
    );
  }

  ArchitectStairLayout _build(List<StairPerimeterSegment> source) =>
      _buildGeometry(source).layout;

  List<List<Offset>> get pendingLandingQuads =>
      _buildGeometry(visibleSegments).pendingQuads;

  static List<Offset> _landingPolygon(
    List<List<Offset>> quads,
    ArchitectStairFlightSpec previous,
    ArchitectStairFlightSpec next,
    double going,
  ) {
    final a = previous.end(going);
    final b = next.origin;
    if (_dot(previous.axis, next.axis) < 1 - 1e-6) {
      final base = _hull([for (final q in quads) ...q]);
      final spliced = _spliceFlightThroat(
        base,
        a,
        previous.axis,
        previous.width,
      );
      if (spliced != null && ArchitectPolygonGeometry.valid(spliced)) {
        return spliced;
      }
    }
    return _hull([
      for (final quad in quads) ...quad,
      a - previous.normal * previous.width / 2,
      a + previous.normal * previous.width / 2,
      b - next.normal * next.width / 2,
      b + next.normal * next.width / 2,
    ]);
  }

  static List<Offset>? _spliceFlightThroat(
    List<Offset> poly,
    Offset center,
    Offset intoLandingAxis,
    double width,
  ) {
    if (poly.length < 3) return null;
    final across = Offset(-intoLandingAxis.dy, intoLandingAxis.dx);
    final e1 = center - across * (width / 2);
    final e2 = center + across * (width / 2);
    for (var i = 0; i < poly.length; i++) {
      final p0 = poly[i];
      final p1 = poly[(i + 1) % poly.length];
      final edge = p1 - p0;
      final len = edge.distance;
      if (len < 1e-8) continue;
      final dir = edge / len;
      if (_dot(dir, intoLandingAxis).abs() > 1e-4) continue;
      final gap = _dot(p0 - center, intoLandingAxis);
      if (gap < -1e-6 || gap > math.max(0.3, width * 0.4)) continue;
      final t1 = _dot(e1 - p0, dir) / len;
      final t2 = _dot(e2 - p0, dir) / len;
      final tMin = math.min(t1, t2);
      final tMax = math.max(t1, t2);
      if (tMin < -1e-4 || tMax > 1 + 1e-4) continue;
      if (gap <= 1e-6) return poly;
      final firstPt = t1 <= t2 ? e1 : e2;
      final secondPt = t1 <= t2 ? e2 : e1;
      final qStart = p0 + edge * tMin.clamp(0.0, 1.0);
      final qEnd = p0 + edge * tMax.clamp(0.0, 1.0);
      final out = <Offset>[];
      for (var k = 0; k < poly.length; k++) {
        final v = poly[k];
        if (out.isEmpty || (out.last - v).distance > 1e-7) out.add(v);
        if (k != i) continue;
        for (final pt in [qStart, firstPt, secondPt, qEnd]) {
          if ((out.last - pt).distance > 1e-7) out.add(pt);
        }
      }
      if (out.length > 2 && (out.last - out.first).distance <= 1e-7) {
        out.removeLast();
      }
      return out;
    }
    return null;
  }

  static List<Offset> _hull(List<Offset> input) {
    final p = <Offset>[];
    for (final v in input) {
      if (!p.any((existing) => (existing - v).distanceSquared < 1e-14)) {
        p.add(v);
      }
    }
    p.sort(
      (a, b) => a.dx == b.dx ? a.dy.compareTo(b.dy) : a.dx.compareTo(b.dx),
    );
    final hull = <Offset>[];
    for (final list in [p, p.reversed.toList()]) {
      final half = <Offset>[];
      for (final v in list) {
        // Use cross <= 0 during the chain so 1e-16 jitter along collinear
        // edges cannot pop orthogonal corners; prune near-collinear middle
        // vertices afterward using perpendicular distance.
        while (half.length > 1 &&
            ArchitectPolygonGeometry.cross(
                  half.last - half[half.length - 2],
                  v - half.last,
                ) <=
                0) {
          half.removeLast();
        }
        half.add(v);
      }
      hull.addAll(half.take(math.max(0, half.length - 1)));
    }
    var pruned = true;
    while (pruned && hull.length > 3) {
      pruned = false;
      for (var i = 0; i < hull.length; i++) {
        final prev = hull[(i - 1 + hull.length) % hull.length];
        final cur = hull[i];
        final next = hull[(i + 1) % hull.length];
        final span = next - prev;
        final lenSq = span.distanceSquared;
        if (lenSq < 1e-16) {
          hull.removeAt(i);
          pruned = true;
          break;
        }
        final t = _dot(cur - prev, span) / lenSq;
        final dist =
            ArchitectPolygonGeometry.cross(span, cur - prev).abs() /
            math.sqrt(lenSq);
        if (t >= -1e-9 && t <= 1 + 1e-9 && dist < 1e-7) {
          hull.removeAt(i);
          pruned = true;
          break;
        }
      }
    }
    return hull;
  }

  double _sideFor(List<StairPerimeterSegment> source) {
    if (sideLocked) return side;
    if (source.length < 2) return side;
    final firstAxis = source.first.axis;
    for (final s in source.skip(1)) {
      final cross = ArchitectPolygonGeometry.cross(firstAxis, s.axis);
      if (cross.abs() > 1e-6) return cross > 0 ? 1 : -1;
    }
    return side;
  }

  double get drawingSide => _sideFor(visibleSegments);
  @override
  ArchitectStairDesign get design {
    final base = super.design;
    if (_designKey == (base, _going) && _designValue != null) {
      return _designValue!;
    }
    _designKey = (base, _going);
    return _designValue = base.copyWith(manualGoing: _going);
  }
  @override
  void replaceDesign(ArchitectStairDesign next) {
    _baseGoing = ArchitectStairDesign.roundGoing(next.going);
    _going = _effectiveGoing(visibleSegments);
    super.replaceDesign(next);
  }

  @override
  ArchitectStairLayout get layout => _build(segments);
  @override
  ArchitectStair? get preview {
    final key = (
      design,
      segments.length,
      segments.lastOrNull,
      anchor,
      target,
      part,
      side,
      sideLocked,
      width,
      _going,
    );
    if (_previewKey == key) return _previewValue;
    _previewKey = key;
    final geom = _buildGeometry(visibleSegments);
    final g = geom.going;
    final l = geom.layout;
    if (l.flights.isEmpty ||
        l.landings.length != l.flights.length - 1 ||
        l.risers > 500)
      return _previewValue = null;
    return _previewValue = seed.copyWith(
      startPoint: Offset.zero,
      endPoint: const Offset(1, 0),
      width: l.flights.first.width,
      design: design.copyWith(
        layout: l,
        manualGoing: g,
        autoRisers: true,
        turnLeft: false,
      ),
    );
  }

  ArchitectStair? get committedPreview {
    if (segments.isEmpty || segments.last.part != StairPerimeterPart.flight)
      return null;
    return snappingPreview;
  }

  ArchitectStair? get snappingPreview {
    if (segments.isEmpty) return null;
    final geom = _buildGeometry(segments);
    final g = geom.going;
    final key = (
      design,
      segments.length,
      segments.last,
      side,
      sideLocked,
      g,
    );
    if (_snapKey == key) return _snapValue;
    _snapKey = key;
    final l = geom.layout;
    if (l.flights.isEmpty) return _snapValue = null;
    return _snapValue = seed.copyWith(
      startPoint: Offset.zero,
      endPoint: const Offset(1, 0),
      width: l.flights.first.width,
      design: design.copyWith(
        layout: l,
        manualGoing: g,
        autoRisers: true,
        turnLeft: false,
      ),
    );
  }

  @override
  bool get complete => committedPreview != null && !reviewing;
  @override
  bool get canUndo => segments.isNotEmpty || anchor != null;
  @override
  void undo() {
    if (reviewing) {
      reviewing = false;
      target = anchor;
    } else if (segments.isNotEmpty) {
      final last = segments.removeLast();
      _future.add(last);
      anchor = last.start;
      target = anchor;
      part = last.part;
    } else {
      anchor = null;
      target = null;
    }
    _going = _effectiveGoing(visibleSegments);
    notifyListeners();
  }

  @override
  void redo() {
    if (_future.isEmpty) return;
    final next = _future.removeLast();
    segments.add(next);
    final geom = _buildGeometry(segments);
    _going = geom.going;
    if (!sideLocked && geom.side != side) {
      side = geom.side;
    }
    if (next.part == StairPerimeterPart.flight &&
        geom.layout.flights.isNotEmpty) {
      anchor = _flightEndAnchor(geom.layout.flights.last, geom.side);
    } else {
      anchor = next.end;
    }
    target = anchor;
    reviewing = false;
    part = next.part == StairPerimeterPart.flight
        ? StairPerimeterPart.landing
        : StairPerimeterPart.flight;
    notifyListeners();
  }
}
