import 'dart:ui';

/// Bounded spatial lookup in model metres, independent of native model types.
class BimPointIndex<T> {
  BimPointIndex({this.cellSize = .5}) : assert(cellSize > 0);
  final double cellSize;
  final Map<(int, int), List<T>> _cells = {};
  bool _sealed = false;
  void add(Offset point, T value) {
    if (_sealed) throw StateError('Scene index is sealed');
    if (!point.dx.isFinite || !point.dy.isFinite) return;
    (_cells[((point.dx / cellSize).floor(), (point.dy / cellSize).floor())] ??=
            [])
        .add(value);
  }

  void seal() => _sealed = true;
  Iterable<T> query(Offset raw, double radius) sync* {
    if (!raw.dx.isFinite ||
        !raw.dy.isFinite ||
        !radius.isFinite ||
        radius < 0) {
      return;
    }
    final minX = ((raw.dx - radius) / cellSize).floor(),
        maxX = ((raw.dx + radius) / cellSize).floor();
    final minY = ((raw.dy - radius) / cellSize).floor(),
        maxY = ((raw.dy + radius) / cellSize).floor();
    // Avoid walking millions of empty cells for an unusually large query.
    if ((maxX - minX + 1) * (maxY - minY + 1) > _cells.length * 4 + 64) {
      for (final entry in _cells.entries) {
        if (entry.key.$1 >= minX &&
            entry.key.$1 <= maxX &&
            entry.key.$2 >= minY &&
            entry.key.$2 <= maxY) {
          yield* entry.value;
        }
      }
      return;
    }
    for (var x = minX; x <= maxX; x++) {
      for (var y = minY; y <= maxY; y++) {
        yield* _cells[(x, y)] ?? <T>[];
      }
    }
  }
}
