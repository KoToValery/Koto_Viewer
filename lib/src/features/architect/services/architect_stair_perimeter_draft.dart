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
  ArchitectStairPerimeterDraft(this.seed)
    : width = seed.width,
      _baseGoing = seed.design!.going,
      _going = seed.design!.going,
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
    notifyListeners();
  }

  double _effectiveGoing(List<StairPerimeterSegment> source) {
    final firstFlight = source
        .where((s) => s.part == StairPerimeterPart.flight)
        .firstOrNull;
    if (firstFlight == null) return _baseGoing;
    final run = (firstFlight.end - firstFlight.start).distance;
    if (run <= .001) return _baseGoing;
    final treads = math.max(1, (run / _baseGoing).round());
    return run / treads;
  }

  @override
  void aim(Offset p) {
    if (reviewing) return;
    if (anchor != null && part == StairPerimeterPart.flight) {
      final v = p - anchor!;
      final hasFirstFlight = segments.any(
        (s) => s.part == StairPerimeterPart.flight,
      );
      final step = hasFirstFlight ? _effectiveGoing(segments) : _baseGoing;
      if (!snapExact && v.distance > .001) {
        p =
            anchor! +
            v /
                v.distance *
                math.max(step, (v.distance / step).round() * step);
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
    if (!sideLocked && segments.isNotEmpty) {
      side = _sideFor(nextSegments);
    }
    segments.add(segment);
    _future.clear();
    _going = _effectiveGoing(segments);
    if (segment.part == StairPerimeterPart.flight) {
      final built = _buildGeometry(segments).layout.flights.last;
      anchor = built.end(_going) - built.normal * (built.width / 2);
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

  static double _corridorAdvance(
    Offset rawOrigin,
    Offset axis,
    Offset normal,
    double width,
    List<Offset> obstacle,
  ) {
    if (obstacle.length < 3) return 0;
    final half = width / 2 - 1e-4;
    if (half <= 0) return 0;
    var advance = 0.0;
    for (final v in obstacle) {
      final tSide = _dot(v - rawOrigin, normal);
      if (tSide.abs() <= half) {
        final tAlong = _dot(v - rawOrigin, axis);
        if (tAlong > advance) advance = tAlong;
      }
    }
    for (var i = 0; i < obstacle.length; i++) {
      final e0 = obstacle[i];
      final e1 = obstacle[(i + 1) % obstacle.length];
      final s0 = _dot(e0 - rawOrigin, normal);
      final s1 = _dot(e1 - rawOrigin, normal);
      if ((s1 - s0).abs() <= 1e-9) continue;
      for (final bound in [-half, half]) {
        if ((s0 - bound) * (s1 - bound) <= 0) {
          final u = (bound - s0) / (s1 - s0);
          final hit = e0 + (e1 - e0) * u;
          final tAlong = _dot(hit - rawOrigin, axis);
          if (tAlong > advance) advance = tAlong;
        }
      }
    }
    return advance;
  }

  ({
    ArchitectStairLayout layout,
    List<List<Offset>> pendingQuads,
  }) _buildGeometry(List<StairPerimeterSegment> source) {
    final g = _effectiveGoing(source);
    final sSide = _sideFor(source);
    final flights = <ArchitectStairFlightSpec>[];
    final landings = <ArchitectStairLandingSpec>[];
    final pending = <List<Offset>>[];
    for (final s in source) {
      if (s.part == StairPerimeterPart.landing) {
        final n = Offset(-s.axis.dy, s.axis.dx) * sSide * s.width;
        var corners = <Offset>[s.start, s.end, s.end + n, s.start + n];
        if (flights.isNotEmpty) {
          final prev = flights.last;
          final prevEnd = prev.end(g);
          var maxBack = 0.0;
          for (final c in corners) {
            final back = _dot(prevEnd - c, prev.axis);
            if (back > maxBack) maxBack = back;
          }
          final startsAtOrAhead =
              _dot(s.start - prevEnd, prev.axis) >= -1e-4 &&
              _dot(s.end - prevEnd, prev.axis) >= -1e-4;
          if (maxBack > 1e-4 &&
              _dot(n, prev.axis) < -1e-4 &&
              (pending.isEmpty || startsAtOrAhead)) {
            final shift = prev.axis * maxBack;
            corners = [for (final c in corners) c + shift];
          }
        }
        pending.add(corners);
        continue;
      }
      final normal = Offset(-s.axis.dy, s.axis.dx) * sSide;
      var origin = s.start + normal * s.width / 2;
      if (flights.isNotEmpty && pending.isNotEmpty) {
        final previous = flights.last;
        final a = previous.end(g);
        final pendingHull = _hull([
          for (final quad in pending) ...quad,
          a - previous.normal * previous.width / 2,
          a + previous.normal * previous.width / 2,
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
        }
      }
      final rawRun = (s.end - s.start).distance;
      final treads = math.max(1, (rawRun / g).round());
      final isFirst = flights.isEmpty;
      final f = ArchitectStairFlightSpec(
        id: 'flight_${flights.length}',
        origin: origin,
        axis: s.axis,
        width: s.width,
        risers: treads + 1,
        fixedRun: isFirst || (rawRun - treads * g).abs() <= 1e-6
            ? rawRun
            : null,
      );
      if (flights.isNotEmpty && pending.isNotEmpty) {
        final previous = flights.last;
        final a = previous.end(g);
        final b = f.origin;
        final cloud = <Offset>[
          for (final quad in pending) ...quad,
          a - previous.normal * previous.width / 2,
          a + previous.normal * previous.width / 2,
          b - f.normal * f.width / 2,
          b + f.normal * f.width / 2,
        ];
        landings.add(
          ArchitectStairLandingSpec(
            id: 'landing_${landings.length}',
            polygon: _hull(cloud),
          ),
        );
      }
      flights.add(f);
      pending.clear();
    }
    return (
      layout: ArchitectStairLayout(flights: flights, landings: landings),
      pendingQuads: pending,
    );
  }

  ArchitectStairLayout _build(List<StairPerimeterSegment> source) =>
      _buildGeometry(source).layout;

  List<List<Offset>> get pendingLandingQuads =>
      _buildGeometry(visibleSegments).pendingQuads;

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
    _baseGoing = next.going;
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
    final g = _effectiveGoing(visibleSegments);
    final l = _build(visibleSegments);
    if (l.flights.isEmpty ||
        l.landings.length != l.flights.length - 1 ||
        l.risers > 500)
      return _previewValue = null;
    return _previewValue = seed.copyWith(
      startPoint: Offset.zero,
      endPoint: const Offset(1, 0),
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
    final g = _effectiveGoing(segments);
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
    final l = _build(segments);
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
    _going = _effectiveGoing(segments);
    if (next.part == StairPerimeterPart.flight) {
      final built = _buildGeometry(segments).layout.flights.last;
      anchor = built.end(_going) - built.normal * (built.width / 2);
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
