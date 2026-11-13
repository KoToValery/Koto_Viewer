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
  StairPerimeterPart part = StairPerimeterPart.flight;
  Offset? anchor, target;
  bool reviewing = false, sideLocked = false;
  double side = 1, width;
  double _going;
  ArchitectStairPerimeterDraft(this.seed)
    : width = seed.width,
      _going = seed.design!.going,
      super(
        seed.copyWith(design: seed.design!.copyWith(clearLayout: true)),
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
    notifyListeners();
  }

  void flip() {
    side = -side;
    sideLocked = true;
    notifyListeners();
  }

  @override
  void aim(Offset p) {
    if (reviewing) return;
    if (anchor != null && part == StairPerimeterPart.flight) {
      final v = p - anchor!;
      if (snapExact && v.distance > .001 && segments.isEmpty) {
        _going =
            v.distance / math.max(1, (v.distance / seed.design!.going).round());
      }
      if (!snapExact && v.distance > .001)
        p =
            anchor! +
            v /
                v.distance *
                math.max(_going, (v.distance / _going).round() * _going);
    }
    target = p;
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
    if (part == StairPerimeterPart.flight &&
        segments.where((s) => s.part == StairPerimeterPart.flight).isEmpty) {
      _going = value / math.max(1, (value / _going).round());
    }
    target = anchor! + axis * value;
    reviewing = true;
    notifyListeners();
  }

  bool acceptPart() {
    if (anchor == null || target == null || length < .001) return false;
    if (segments.isEmpty && part != StairPerimeterPart.flight) return false;
    if (segments.isNotEmpty &&
        part == StairPerimeterPart.flight &&
        segments.last.part == part)
      return false;
    final segment = StairPerimeterSegment(part, anchor!, target!, width);
    if (!sideLocked &&
        part == StairPerimeterPart.flight &&
        segments.isNotEmpty) {
      final first = segments.first;
      final cross = ArchitectPolygonGeometry.cross(first.axis, segment.axis);
      if (cross.abs() > 1e-6) side = cross > 0 ? -1 : 1;
    }
    segments.add(segment);
    _future.clear();
    anchor = target;
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

  ArchitectStairLayout _build(List<StairPerimeterSegment> source) {
    final side = _sideFor(source);
    final flights = <ArchitectStairFlightSpec>[],
        landings = <ArchitectStairLandingSpec>[];
    final pending = <StairPerimeterSegment>[];
    for (final s in source) {
      if (s.part == StairPerimeterPart.landing) {
        pending.add(s);
        continue;
      }
      final normal = Offset(-s.axis.dy, s.axis.dx) * side;
      final f = ArchitectStairFlightSpec(
        id: 'flight_${flights.length}',
        origin: s.start + normal * s.width / 2,
        axis: s.axis,
        width: s.width,
        risers: math.max(2, ((s.end - s.start).distance / _going).round() + 1),
        fixedRun: (s.end - s.start).distance,
      );
      if (flights.isNotEmpty && pending.isNotEmpty) {
        final previous = flights.last;
        final a = previous.end(_going), b = f.origin;
        final cloud = <Offset>[];
        for (final p in pending) {
          final n = Offset(-p.axis.dy, p.axis.dx) * side * p.width;
          cloud.addAll([p.start, p.end, p.start + n, p.end + n]);
        }
        cloud.addAll([
          a - previous.normal * previous.width / 2,
          a + previous.normal * previous.width / 2,
          b - f.normal * f.width / 2,
          b + f.normal * f.width / 2,
          b - f.normal * f.width / 2 - f.axis * f.width,
          b + f.normal * f.width / 2 - f.axis * f.width,
        ]);
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
    return ArchitectStairLayout(flights: flights, landings: landings);
  }

  static List<Offset> _hull(List<Offset> input) {
    final p = input.toSet().toList()
      ..sort(
        (a, b) => a.dx == b.dx ? a.dy.compareTo(b.dy) : a.dx.compareTo(b.dx),
      );
    final hull = <Offset>[];
    for (final list in [p, p.reversed.toList()]) {
      final half = <Offset>[];
      for (final v in list) {
        while (half.length > 1 &&
            ArchitectPolygonGeometry.cross(
                  half.last - half[half.length - 2],
                  v - half.last,
                ) <=
                1e-9) {
          half.removeLast();
        }
        half.add(v);
      }
      hull.addAll(half.take(math.max(0, half.length - 1)));
    }
    return hull;
  }

  double _sideFor(List<StairPerimeterSegment> source) {
    if (sideLocked) return side;
    final flights = source
        .where((s) => s.part == StairPerimeterPart.flight)
        .toList();
    for (final f in flights.skip(1)) {
      final cross = ArchitectPolygonGeometry.cross(flights.first.axis, f.axis);
      if (cross.abs() > 1e-6) return cross > 0 ? -1 : 1;
    }
    return side;
  }

  double get drawingSide => _sideFor(visibleSegments);
  @override
  void replaceDesign(ArchitectStairDesign next) {
    _going = next.going;
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
        manualGoing: _going,
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
    final key = (
      design,
      segments.length,
      segments.last,
      side,
      sideLocked,
      _going,
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
        manualGoing: _going,
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
    notifyListeners();
  }

  @override
  void redo() {
    if (_future.isEmpty) return;
    final next = _future.removeLast();
    segments.add(next);
    anchor = next.end;
    target = anchor;
    reviewing = false;
    part = next.part == StairPerimeterPart.flight
        ? StairPerimeterPart.landing
        : StairPerimeterPart.flight;
    notifyListeners();
  }
}
