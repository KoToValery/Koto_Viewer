import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../models/wall_axis_models.dart';
import 'slab_wall_regions.dart';

/// Conservative preview only: enclosed free space is not proof of a slab.
/// Coordinates remain in source CAD units, before project alignment.
class SlabEnvelopeResult {
  final List<List<Offset>> contours;
  final List<String> diagnostics;
  final double cellSize;
  final int enclosedRegionCount;
  final List<SlabGapHypothesis> assumedGaps;
  final List<Map<String, dynamic>> regionReports;
  final int skippedRegions;
  const SlabEnvelopeResult(
    this.contours,
    this.diagnostics,
    this.cellSize,
    this.enclosedRegionCount, {
    this.assumedGaps = const [],
    this.regionReports = const [],
    this.skippedRegions = 0,
  });

  Map<String, dynamic> toJson() => {
    'version': 2,
    'status': contours.isEmpty ? 'unresolved' : 'needsReview',
    'coordinateSpace': 'sourceCad',
    'cellSize': cellSize,
    'enclosedRegionCount': enclosedRegionCount,
    'diagnostics': diagnostics,
    'assumedGaps': assumedGaps.map((g) => g.toJson()).toList(),
    'regions': regionReports,
    'skippedRegions': skippedRegions,
    'contours': contours
        .map((c) => c.map((p) => [p.dx, p.dy]).toList())
        .toList(),
  };
}

class SlabEnvelopeDetector {
  /// Geometric gap hypotheses remain visible and require review. No semantic
  /// door/window classification is implied by matching collinear wall faces.
  static SlabEnvelopeResult detect(WallAxisDetectionResult walls) {
    final scale = walls.detectedScale;
    final pairs = walls.selectedWallPairs;
    SlabEnvelopeResult empty(String reason) =>
        SlabEnvelopeResult(const [], [reason], 0, 0);
    if (!scale.isFinite || scale <= 0) return empty('invalidScale');
    if (pairs.isEmpty) return empty('noWallPairs');
    if (pairs.any(
      (p) =>
          !p.centerlineStart.dx.isFinite ||
          !p.centerlineStart.dy.isFinite ||
          !p.centerlineEnd.dx.isFinite ||
          !p.centerlineEnd.dy.isFinite ||
          !p.perpendicularDistance.isFinite ||
          p.perpendicularDistance <= 0,
    )) {
      return empty('invalidWallGeometry');
    }
    final partition = SlabWallRegions.build(pairs, scale);
    if (partition.tooComplex) return empty('analysisComplexityLimit');
    final contours = <List<Offset>>[];
    final gaps = <SlabGapHypothesis>[];
    final reports = <Map<String, dynamic>>[];
    final diagnostics = <String>{};
    var cell = 0.0, enclosed = 0;
    for (var i = 0; i < partition.regions.length; i++) {
      // Bound total raster work as well as individual grid size.
      if (i >= 64) {
        diagnostics.add('regionLimitReached');
        break;
      }
      final region = partition.regions[i];
      final baseline = _raster(region, scale);
      final hypotheses = partition.gaps[i];
      final augmented = [...region];
      for (final gap in hypotheses) {
        final source = region[gap.wallA];
        augmented.add(
          WallPairCandidate(
            segmentA: source.segmentA,
            segmentB: source.segmentB,
            perpendicularDistance: gap.thickness,
            overlapLength: (gap.end - gap.start).distance,
            centerlineStart: gap.start,
            centerlineEnd: gap.end,
          ),
        );
      }
      final proposed = hypotheses.isEmpty
          ? baseline
          : _raster(augmented, scale);
      final chosen = proposed.contours.isNotEmpty ? proposed : baseline;
      contours.addAll(chosen.contours);
      gaps.addAll(hypotheses);
      cell = math.max(cell, chosen.cellSize);
      enclosed += chosen.enclosedRegionCount;
      diagnostics.addAll(chosen.diagnostics);
      reports.add({
        'index': i,
        'wallCount': region.length,
        'baselineContours': baseline.toJson()['contours'],
        'contourCount': chosen.contours.length,
        'cellSize': chosen.cellSize,
        'diagnostics': chosen.diagnostics,
        'hypothesisDiagnostics': proposed.diagnostics,
        'assumedGaps': hypotheses.map((g) => g.toJson()).toList(),
        'usesAssumedGaps':
            hypotheses.isNotEmpty && proposed.contours.isNotEmpty,
      });
    }
    if (gaps.isNotEmpty) diagnostics.add('unconfirmedOpeningHypotheses');
    if (reports.any((r) => r['contourCount'] == 0)) {
      diagnostics.add('unresolvedRegions');
    }
    return SlabEnvelopeResult(
      contours,
      diagnostics.toList(),
      cell,
      enclosed,
      assumedGaps: gaps,
      regionReports: reports,
      skippedRegions: partition.regions.length - reports.length,
    );
  }

  static SlabEnvelopeResult _raster(
    List<WallPairCandidate> pairs,
    double scale,
  ) {
    SlabEnvelopeResult empty(String reason) =>
        SlabEnvelopeResult(const [], [reason], 0, 0);
    var left = double.infinity, top = double.infinity;
    var right = double.negativeInfinity, bottom = double.negativeInfinity;
    var minThickness = double.infinity;
    for (final p in pairs) {
      final r = p.perpendicularDistance / 2;
      minThickness = math.min(minThickness, p.perpendicularDistance);
      for (final v in [p.centerlineStart, p.centerlineEnd]) {
        left = math.min(left, v.dx - r);
        right = math.max(right, v.dx + r);
        top = math.min(top, v.dy - r);
        bottom = math.max(bottom, v.dy + r);
      }
    }
    final cell = math.max(
      25 * scale,
      math.max(right - left, bottom - top) / 760,
    );
    if (!cell.isFinite || cell > minThickness / 3) {
      return empty('drawingTooLargeSelectSmallerRegion');
    }
    left -= 3 * cell;
    top -= 3 * cell;
    final width = ((right - left) / cell).ceil() + 3;
    final height = ((bottom - top) / cell).ceil() + 3;
    final mask = Uint8List(width * height);
    // Rasterize measured wall bands, not extended BIM axes. Conservative cell
    // coverage introduces a visible uncertainty of roughly two cell widths.
    for (final p in pairs) {
      final a = p.centerlineStart, b = p.centerlineEnd;
      final d = b - a;
      final length = d.distance;
      if (length == 0) continue;
      final u = d / length;
      final radius = p.perpendicularDistance / 2 + cell * 0.707107;
      final x0 = ((math.min(a.dx, b.dx) - radius - left) / cell).floor().clamp(
        0,
        width - 1,
      );
      final x1 = ((math.max(a.dx, b.dx) + radius - left) / cell).ceil().clamp(
        0,
        width - 1,
      );
      final y0 = ((math.min(a.dy, b.dy) - radius - top) / cell).floor().clamp(
        0,
        height - 1,
      );
      final y1 = ((math.max(a.dy, b.dy) + radius - top) / cell).ceil().clamp(
        0,
        height - 1,
      );
      for (var y = y0; y <= y1; y++) {
        for (var x = x0; x <= x1; x++) {
          final v = Offset(left + (x + 0.5) * cell, top + (y + 0.5) * cell) - a;
          final along = v.dx * u.dx + v.dy * u.dy;
          final across = (v.dx * u.dy - v.dy * u.dx).abs();
          if (along >= -cell * 0.707107 &&
              along <= length + cell * 0.707107 &&
              across <= radius) {
            mask[y * width + x] = 1;
          }
        }
      }
    }
    Iterable<int> neighbours(int i) sync* {
      if (i % width > 0) yield i - 1;
      if (i % width < width - 1) yield i + 1;
      if (i >= width) yield i - width;
      if (i < mask.length - width) yield i + width;
    }

    void flood(int start, int from, int to) {
      final queue = <int>[start];
      mask[start] = to;
      for (var k = 0; k < queue.length; k++) {
        for (final n in neighbours(queue[k])) {
          if (mask[n] == from) {
            mask[n] = to;
            queue.add(n);
          }
        }
      }
    }

    flood(0, 0, 2); // exterior; padded border is always free
    var regions = 0;
    for (var i = 0; i < mask.length; i++) {
      if (mask[i] == 0) {
        regions++;
        flood(i, 0, 3);
      }
    }
    if (regions == 0) {
      return SlabEnvelopeResult(
        const [],
        ['noEnclosedSpace', 'remainingGapsMayLeak'],
        cell,
        0,
      );
    }
    // Keep only connected wall/space components containing enclosed free space.
    final visited = Uint8List(mask.length);
    final kept = Uint8List(mask.length);
    for (var i = 0; i < mask.length; i++) {
      if (mask[i] == 2 || visited[i] != 0) continue;
      final queue = <int>[i];
      visited[i] = 1;
      var interior = 0;
      for (var k = 0; k < queue.length; k++) {
        final v = queue[k];
        if (mask[v] == 3) interior++;
        for (final n in neighbours(v)) {
          if (mask[n] != 2 && visited[n] == 0) {
            visited[n] = 1;
            queue.add(n);
          }
        }
      }
      if (interior * cell * cell >= 1000000 * scale * scale) {
        for (final v in queue) {
          kept[v] = 1;
        }
      }
    }
    final stride = width + 1;
    final edges = <int, List<int>>{};
    void edge(int a, int b) => edges.putIfAbsent(a, () => []).add(b);
    bool filled(int x, int y) =>
        x >= 0 && y >= 0 && x < width && y < height && kept[y * width + x] != 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (!filled(x, y)) continue;
        final a = y * stride + x, b = a + 1, d = a + stride, c = d + 1;
        if (!filled(x, y - 1)) edge(a, b);
        if (!filled(x + 1, y)) edge(b, c);
        if (!filled(x, y + 1)) edge(c, d);
        if (!filled(x - 1, y)) edge(d, a);
      }
    }
    // Diagonal point contacts have ambiguous topology: report, never guess.
    if (edges.values.any((v) => v.length != 1)) {
      return SlabEnvelopeResult(
        const [],
        ['ambiguousPointContact'],
        cell,
        regions,
      );
    }
    final contours = <List<Offset>>[];
    while (edges.isNotEmpty) {
      final start = edges.keys.first;
      var current = start;
      final ring = <Offset>[];
      do {
        ring.add(
          Offset(
            left + (current % stride) * cell,
            top + (current ~/ stride) * cell,
          ),
        );
        final next = edges.remove(current);
        if (next == null) {
          return SlabEnvelopeResult(const [], ['openBoundary'], cell, regions);
        }
        current = next.single;
      } while (current != start);
      final simplified = <Offset>[];
      for (var i = 0; i < ring.length; i++) {
        final a = ring[(i + ring.length - 1) % ring.length],
            b = ring[i],
            c = ring[(i + 1) % ring.length];
        if ((b.dx - a.dx) * (c.dy - b.dy) - (b.dy - a.dy) * (c.dx - b.dx) !=
            0) {
          simplified.add(b);
        }
      }
      if (simplified.length >= 3) contours.add(simplified);
    }
    return SlabEnvelopeResult(
      contours,
      [
        'approximateRasterBoundary',
        'courtyardsAndSlabOpeningsUnclassified',
        'remainingGapsMayLeak',
        'mayBePartialEnvelope',
        'levelAndConcreteEdgeUnverified',
        if (contours.isEmpty) 'noEnclosedAreaAboveMinimum',
      ],
      cell,
      regions,
    );
  }
}
