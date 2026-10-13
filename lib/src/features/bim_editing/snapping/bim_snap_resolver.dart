import 'dart:ui';

enum BimSnapKind {
  endpoint(0),
  intersection(1),
  center(2),
  midpoint(2),
  perpendicular(3),
  edge(4),
  alignment(5);

  const BimSnapKind(this.priority);
  final int priority;
}

class BimSnapCandidate<T> {
  const BimSnapCandidate({
    required this.point,
    required this.kind,
    required this.source,
  });
  final Offset point;
  final BimSnapKind kind;
  final T source;
}

/// Same bounded, deterministic selection for all tools and providers.
/// Exact geometry is kept; only free input is quantized by the native host.
class BimSnapResolver<T> {
  BimSnapResolver({required this.raw, required this.radius, this.anchor});
  final Offset raw;
  final double radius;
  final Offset? anchor;
  BimSnapCandidate<T>? _best;
  double _distance = double.infinity;
  BimSnapCandidate<T>? get best => _best;
  void consider(BimSnapCandidate<T> candidate) {
    final point = candidate.point;
    if (!point.dx.isFinite ||
        !point.dy.isFinite ||
        !radius.isFinite ||
        radius < 0) {
      return;
    }
    if (anchor != null && (point - anchor!).distance < 1e-9) return;
    final distance = (point - raw).distance;
    if (distance > radius + 1e-9) return;
    final previous = _best;
    final tie = (distance - _distance).abs() < 1e-9;
    if (previous == null ||
        candidate.kind.priority < previous.kind.priority ||
        (candidate.kind.priority == previous.kind.priority &&
            (distance < _distance - 1e-9 ||
                (tie &&
                    (point.dx < previous.point.dx ||
                        (point.dx == previous.point.dx &&
                            point.dy < previous.point.dy)))))) {
      _best = candidate;
      _distance = distance;
    }
  }
}
