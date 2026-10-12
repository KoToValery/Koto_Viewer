import 'dart:math' as math;
import 'dart:ui';
import '../../bim_projects/models/bim_coordinate_frame.dart';
import '../models/architect_project.dart';

class ArchitectSnapResult {
  final Offset point;
  final bool isSnapped;
  final String? snapLabel;
  final double? angleDeg;
  final List<(Offset, Offset)> magneticGuides;
  const ArchitectSnapResult({
    required this.point,
    this.isSnapped = false,
    this.snapLabel,
    this.angleDeg,
    this.magneticGuides = const [],
  });
}

/// Bounded nearest-candidate snapping, independent of list order.
class ArchitectSnapHelper {
  static final _indexes = Expando<_SnapIndex>();
  static BimPrecisionPolicy precision(ArchitectProject project) =>
      project.units.isImperial
      ? BimPrecisionPolicy.imperial
      : BimPrecisionPolicy.metric;

  static ArchitectSnapResult snapWithAnchor({
    required Offset anchor,
    required Offset rawPoint,
    required ArchitectProject project,
    double tolerance = .20,
  }) {
    final radius = tolerance.clamp(0.0, .20);
    final explicit = _nearest(rawPoint, project, radius, anchor: anchor);
    if (explicit != null) return explicit;
    final delta = rawPoint - anchor;
    if (delta.distance < 1e-9) return ArchitectSnapResult(point: anchor);
    final angle = math.atan2(delta.dy, delta.dx);
    final target = (angle / (math.pi / 4)).round() * math.pi / 4;
    if ((target - angle).abs() <= math.pi / 30) {
      final u = Offset(math.cos(target), math.sin(target));
      final projection = anchor + u * (delta.dx * u.dx + delta.dy * u.dy);
      if ((projection - rawPoint).distance <= radius + 1e-9) {
        final degrees = (target * 180 / math.pi + 360) % 360;
        return ArchitectSnapResult(
          point: projection,
          isSnapped: true,
          snapLabel: '${degrees.round()}°',
          angleDeg: degrees,
        );
      }
    }
    return ArchitectSnapResult(
      point: precision(project).inputPoint(rawPoint),
      angleDeg: (angle * 180 / math.pi + 360) % 360,
    );
  }

  static ArchitectSnapResult snapFree({
    required Offset rawPoint,
    required ArchitectProject project,
    double tolerance = .20,
  }) =>
      _nearest(rawPoint, project, tolerance.clamp(0.0, .20)) ??
      ArchitectSnapResult(point: precision(project).inputPoint(rawPoint));

  static ArchitectSnapResult? _nearest(
    Offset raw,
    ArchitectProject project,
    double radius, {
    Offset? anchor,
  }) {
    final index = _indexes[project] ??= _SnapIndex(project);
    _Candidate? best;
    double bestDistance = radius + 1e-9;
    void consider(_Candidate candidate) {
      if (anchor != null && (candidate.point - anchor).distance < 1e-9) return;
      final distance = (candidate.point - raw).distance;
      if (distance > radius + 1e-9) return;
      final tie = (distance - bestDistance).abs() <= 1e-9;
      if (distance < bestDistance - 1e-9 ||
          best == null ||
          (tie && candidate.compareTo(best!) < 0)) {
        best = candidate;
        bestDistance = distance;
      }
    }

    for (final candidate in index.query(raw, radius)) {
      consider(candidate);
    }
    for (final axis in project.gridAxes) {
      consider(_Candidate(axis.projectPoint(raw), 'Axis ${axis.name}', 3));
    }
    return best == null
        ? null
        : ArchitectSnapResult(
            point: best!.point,
            isSnapped: true,
            snapLabel: best!.label,
          );
  }
}

class _Candidate {
  final Offset point;
  final String label;
  final int priority;
  const _Candidate(this.point, this.label, this.priority);
  int compareTo(_Candidate other) {
    final rank = priority.compareTo(other.priority);
    if (rank != 0) return rank;
    final x = point.dx.compareTo(other.point.dx);
    if (x != 0) return x;
    final y = point.dy.compareTo(other.point.dy);
    return y != 0 ? y : label.compareTo(other.label);
  }
}

/// Cached on immutable project revision; capture queries visit nearby buckets.
class _SnapIndex {
  static const cellSize = .5;
  final Map<(int, int), List<_Candidate>> _cells = {};
  _SnapIndex(ArchitectProject project) {
    void add(Offset point, String label, int priority) {
      if (!point.dx.isFinite || !point.dy.isFinite) return;
      final key = (
        (point.dx / cellSize).floor(),
        (point.dy / cellSize).floor(),
      );
      (_cells[key] ??= []).add(_Candidate(point, label, priority));
    }

    for (final wall in project.activeStorey.walls) {
      add(wall.startPoint, 'Endpoint', 0);
      add(wall.endPoint, 'Endpoint', 0);
      add((wall.startPoint + wall.endPoint) / 2, 'Midpoint', 2);
    }
    for (final zone in project.activeStorey.zones) {
      for (final point in zone.polygon) {
        add(point, 'Vertex', 0);
      }
    }
    for (final slab in project.activeStorey.slabs) {
      for (final point in slab.polygon) {
        add(point, 'Vertex', 0);
      }
    }
    for (final column in project.activeStorey.columns) {
      add(column.position, 'Center', 1);
    }
    final axes = project.gridAxes;
    for (var i = 0; i < axes.length; i++) {
      add(axes[i].start, 'Axis endpoint', 0);
      add(axes[i].end, 'Axis endpoint', 0);
      final u = axes[i].end - axes[i].start;
      for (var j = i + 1; j < axes.length; j++) {
        final v = axes[j].end - axes[j].start;
        final cross = u.dx * v.dy - u.dy * v.dx;
        if (cross.abs() <= 1e-12 * u.distance * v.distance) continue;
        final d = axes[j].start - axes[i].start;
        final t = (d.dx * v.dy - d.dy * v.dx) / cross;
        add(axes[i].start + u * t, 'Axis intersection', 1);
      }
    }
  }
  Iterable<_Candidate> query(Offset raw, double radius) sync* {
    for (
      var x = ((raw.dx - radius) / cellSize).floor();
      x <= ((raw.dx + radius) / cellSize).floor();
      x++
    ) {
      for (
        var y = ((raw.dy - radius) / cellSize).floor();
        y <= ((raw.dy + radius) / cellSize).floor();
        y++
      ) {
        yield* _cells[(x, y)] ?? const <_Candidate>[];
      }
    }
  }
}
