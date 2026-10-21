import 'dart:math' as math;
import 'dart:ui';
import '../../bim_editing/geometry/bim_line_geometry.dart';
import '../models/architect_project.dart';
import 'architect_snap_geometry.dart';

class ArchitectMidpointReference {
  final ArchitectSnapEdge edge;
  const ArchitectMidpointReference(this.edge);
  Offset get point => (edge.a + edge.b) / 2;
  String get owner => edge.owner.startsWith('@wall-axis:')
      ? edge.owner.substring(11)
      : edge.owner;
  Iterable<Offset> get directions sync* {
    yield const Offset(1, 0);
    yield const Offset(0, 1);
    final u = (edge.b - edge.a) / (edge.b - edge.a).distance;
    if (u.dx.abs() > 1e-8 && u.dy.abs() > 1e-8) {
      yield u;
      yield Offset(-u.dy, u.dx);
    }
  }
}

/// Transient drafting references. They never modify the project or Undo stack.
/// Hovering an edge reveals its middle; visiting that middle acquires a guide.
class ArchitectMidpointTracking {
  Object? _context;
  ArchitectSnapGeometry? _geometry;
  final List<ArchitectMidpointReference> _references = [];
  ArchitectMidpointReference? _hovered;
  List<ArchitectMidpointReference> get references =>
      List.unmodifiable(_references);
  List<Offset> get hints => {
    for (final reference in _references) reference.point,
    if (_hovered != null) _hovered!.point,
  }.toList();

  void clear() {
    _context = null;
    _geometry = null;
    _hovered = null;
    _references.clear();
  }

  void update({
    required ArchitectProject project,
    required Offset raw,
    required double scale,
    required Object context,
    bool enabled = true,
    double hoverPixels = 12,
    double capturePixels = 8,
    Set<String> excludedIds = const {},
  }) {
    if (!enabled || !scale.isFinite || scale <= 0) {
      clear();
      return;
    }
    final key = (project.id, project.activeStoreyId, context);
    if (_context != key) clear();
    _context = key;
    final geometry = ArchitectSnapGeometry.of(project);
    if (!identical(_geometry, geometry)) {
      _references.removeWhere((r) => !geometry.midpointEdges.contains(r.edge));
      _geometry = geometry;
    }
    _references.removeWhere((r) => excludedIds.contains(r.owner));
    _hovered = null;
    final radius = math.min(hoverPixels / scale, .6);
    var distance = radius + 1e-9;
    var middleDistance = double.infinity;
    for (final edge in geometry.nearbyEdges(raw, radius)) {
      if (!geometry.midpointEdges.contains(edge) ||
          (edge.b - edge.a).distance * scale < 28) {
        continue;
      }
      final reference = ArchitectMidpointReference(edge);
      if (excludedIds.contains(reference.owner)) continue;
      final d = (BimLineGeometry.closest(raw, edge.a, edge.b) - raw).distance;
      final m = (reference.point - raw).distance;
      if (d < distance - 1e-9 ||
          ((d - distance).abs() < 1e-9 && m < middleDistance)) {
        distance = d;
        middleDistance = m;
        _hovered = reference;
      }
    }
    final hovered = _hovered;
    if (hovered != null &&
        (hovered.point - raw).distance <= math.min(capturePixels / scale, .6)) {
      _references.removeWhere((r) => (r.point - hovered.point).distance < 1e-8);
      _references.add(hovered);
      if (_references.length > 2) _references.removeAt(0);
    }
  }

  static ({Offset point, List<(Offset, Offset)> guides})? align({
    required Offset raw,
    required double radius,
    required List<ArchitectMidpointReference> references,
    Offset? anchor,
  }) {
    final lines =
        <
          ({
            ArchitectMidpointReference ref,
            Offset direction,
            Offset projection,
          })
        >[];
    for (final ref in references) {
      for (final direction in ref.directions) {
        final delta = raw - ref.point;
        final projection =
            ref.point +
            direction * (delta.dx * direction.dx + delta.dy * direction.dy);
        if ((projection - raw).distance <= radius + 1e-9 &&
            (projection - ref.point).distance > radius &&
            (anchor == null || (projection - anchor).distance > 1e-9)) {
          lines.add((ref: ref, direction: direction, projection: projection));
        }
      }
    }
    // Crossing two acquired guides gives a single precise reference point.
    ({Offset point, List<(Offset, Offset)> guides})? crossing;
    var crossingDistance = double.infinity;
    for (var i = 0; i < lines.length; i++) {
      final a = lines[i];
      for (final b in lines.skip(i + 1)) {
        if (identical(a.ref, b.ref)) continue;
        final p = BimLineGeometry.intersection(
          a.ref.point,
          a.ref.point + a.direction,
          b.ref.point,
          b.ref.point + b.direction,
          firstFinite: false,
          secondFinite: false,
        );
        if (p == null || (anchor != null && (p - anchor).distance < 1e-9)) {
          continue;
        }
        final d = (p - raw).distance;
        if (d <= radius + 1e-9 && d < crossingDistance) {
          crossingDistance = d;
          crossing = (point: p, guides: [(a.ref.point, p), (b.ref.point, p)]);
        }
      }
    }
    if (crossing != null) return crossing;
    if (lines.isEmpty) return null;
    lines.sort(
      (a, b) => (a.projection - raw).distanceSquared.compareTo(
        (b.projection - raw).distanceSquared,
      ),
    );
    final best = lines.first;
    return (
      point: best.projection,
      guides: [(best.ref.point, best.projection)],
    );
  }
}
