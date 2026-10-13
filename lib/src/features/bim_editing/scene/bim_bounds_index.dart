import 'dart:ui';

/// Spatial lookup for finite edges and analytic circles. Very large bounds
/// use an overflow bucket instead of allocating unbounded grid cells.
class BimBoundsIndex<T> {
  BimBoundsIndex({this.cellSize = 2, this.maxCellsPerItem = 256});
  final double cellSize;
  final int maxCellsPerItem;
  final Map<(int, int), List<({Rect bounds, T value})>> _cells = {};
  final List<({Rect bounds, T value})> _overflow = [];
  void add(Rect bounds, T value) {
    if (!bounds.isFinite) return;
    final minX = (bounds.left / cellSize).floor(),
        maxX = (bounds.right / cellSize).floor();
    final minY = (bounds.top / cellSize).floor(),
        maxY = (bounds.bottom / cellSize).floor();
    final item = (bounds: bounds, value: value);
    if ((maxX - minX + 1) * (maxY - minY + 1) > maxCellsPerItem) {
      _overflow.add(item);
      return;
    }
    for (var x = minX; x <= maxX; x++) {
      for (var y = minY; y <= maxY; y++) {
        (_cells[(x, y)] ??= []).add(item);
      }
    }
  }

  Iterable<T> query(Rect area) sync* {
    if (!area.isFinite) return;
    final minX = (area.left / cellSize).floor(),
        maxX = (area.right / cellSize).floor();
    final minY = (area.top / cellSize).floor(),
        maxY = (area.bottom / cellSize).floor();
    final seen = <T>{};
    bool matches(Rect bounds) =>
        bounds.right >= area.left &&
        bounds.left <= area.right &&
        bounds.bottom >= area.top &&
        bounds.top <= area.bottom;
    final Iterable<({Rect bounds, T value})> candidates;
    if ((maxX - minX + 1) * (maxY - minY + 1) > _cells.length * 4 + 64) {
      candidates = _cells.values.expand((items) => items);
    } else {
      candidates = [
        for (var x = minX; x <= maxX; x++)
          for (var y = minY; y <= maxY; y++) ...?_cells[(x, y)],
      ];
    }
    for (final item in [...candidates, ..._overflow]) {
      if (matches(item.bounds) && seen.add(item.value)) yield item.value;
    }
  }
}
