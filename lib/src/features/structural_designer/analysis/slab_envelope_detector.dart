import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../models/wall_axis_models.dart';
import 'slab_wall_regions.dart';
import 'slab_boundary_refiner.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import 'slab_opening_evidence.dart';
import 'structural_column_detector.dart';

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
    'version': 4,
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
  static SlabEnvelopeResult detect(
    WallAxisDetectionResult walls, {
    DxfDocument? document,
  }) {
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
    final partition = SlabWallRegions.build(
      pairs,
      scale,
      openingEvidence: document == null
          ? const []
          : SlabOpeningEvidence.collect(document),
    );
    if (partition.tooComplex) return empty('analysisComplexityLimit');
    final columns = walls.detectedColumns.isNotEmpty
        ? walls.detectedColumns
        : (document != null
            ? StructuralColumnDetector.detect(document, wallPairs: pairs, scale: scale)
            : const <DetectedStructuralColumn>[]);
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
      var rMinX = double.infinity, rMaxX = -double.infinity;
      var rMinY = double.infinity, rMaxY = -double.infinity;
      for (final w in region) {
        rMinX = math.min(rMinX, math.min(w.centerlineStart.dx, w.centerlineEnd.dx));
        rMaxX = math.max(rMaxX, math.max(w.centerlineStart.dx, w.centerlineEnd.dx));
        rMinY = math.min(rMinY, math.min(w.centerlineStart.dy, w.centerlineEnd.dy));
        rMaxY = math.max(rMaxY, math.max(w.centerlineStart.dy, w.centerlineEnd.dy));
      }
      final regionBounds = Rect.fromLTRB(rMinX, rMinY, rMaxX, rMaxY).inflate(100.0 * scale);
      final regionColumns = columns
          .where((c) => regionBounds.overlaps(c.bounds))
          .map((c) => c.polygon)
          .toList();

      final baseline = _raster(region, scale, regionColumns);
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
          : _raster(augmented, scale, regionColumns);
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

  static double _distance(Offset p, Offset a, Offset b) {
    final d = b - a, l = d.distanceSquared;
    if (l == 0) return (p - a).distance;
    final t = (((p - a).dx * d.dx + (p - a).dy * d.dy) / l).clamp(0.0, 1.0);
    return (p - a - d * t).distance;
  }

  static List<Offset> _footprint(
    WallPairCandidate pair,
    List<WallPairCandidate> pairs,
    double scale,
  ) {
    final a = pair.centerlineStart, b = pair.centerlineEnd, d = b - a;
    if (d.distance == 0) return const [];
    final u = d / d.distance, n = Offset(-u.dy, u.dx);
    double along(Offset p) => (p - a).dx * u.dx + (p - a).dy * u.dy;
    double across(Offset p) => (p - a).dx * n.dx + (p - a).dy * n.dy;
    final half = pair.perpendicularDistance / 2;
    // A T-junction splits the inner face while the outer face stays continuous.
    // Join only pairs sharing that same observed face, never across two jambs.
    var startT = 0.0, endT = d.distance;
    bool sameFace(WallSegment x, WallSegment y) =>
        ((x.start - y.start).distance <= 5 * scale &&
            (x.end - y.end).distance <= 5 * scale) ||
        ((x.start - y.end).distance <= 5 * scale &&
            (x.end - y.start).distance <= 5 * scale);
    for (final other in pairs) {
      if (identical(pair, other) ||
          (other.perpendicularDistance - pair.perpendicularDistance).abs() >
              5 * scale) {
        continue;
      }
      if (![pair.segmentA, pair.segmentB].any(
        (f) => [other.segmentA, other.segmentB].any((g) => sameFace(f, g)),
      )) {
        continue;
      }
      if (across(other.centerlineStart).abs() > 5 * scale ||
          across(other.centerlineEnd).abs() > 5 * scale) {
        continue;
      }
      final lo = math.min(
        along(other.centerlineStart),
        along(other.centerlineEnd),
      );
      final hi = math.max(
        along(other.centerlineStart),
        along(other.centerlineEnd),
      );
      if (lo > d.distance &&
          lo - d.distance <= pair.perpendicularDistance * 1.5) {
        endT = math.max(endT, (lo + d.distance) / 2);
      }
      if (hi < 0 && -hi <= pair.perpendicularDistance * 1.5) {
        startT = math.min(startT, hi / 2);
      }
    }

    final ends = <List<Offset>>[];
    for (final face in [pair.segmentA, pair.segmentB]) {
      final lo = along(face.start) < along(face.end) ? face.start : face.end;
      final hi = identical(lo, face.start) ? face.end : face.start;
      final offset = (across(face.start) + across(face.end)) / 2;
      // Virtual gaps borrow source faces; those faces do not overlap the gap.
      if (along(hi) < -scale ||
          along(lo) > d.distance + scale ||
          (offset.abs() - half).abs() > 25 * scale) {
        return [a + n * half, b + n * half, b - n * half, a - n * half];
      }
      bool witnessed(Offset endpoint, double limit) {
        if (limit > pair.perpendicularDistance * 1.5 || limit <= 0) {
          return false;
        }
        for (final other in pairs) {
          if (identical(pair, other)) continue;
          final v = other.centerlineEnd - other.centerlineStart;
          if (v.distance == 0 ||
              (u.dx * v.dy - u.dy * v.dx).abs() / v.distance < 0.5) {
            continue;
          }
          for (final f in [other.segmentA, other.segmentB]) {
            if (_distance(endpoint, f.start, f.end) <= 5 * scale) return true;
          }
        }
        return false;
      }

      final start = witnessed(lo, -along(lo))
          ? lo
          : a + u * startT + n * offset;
      final end = witnessed(hi, along(hi) - d.distance)
          ? hi
          : a + u * endT + n * offset;
      ends.add([start, end]);
    }
    return [ends[0][0], ends[0][1], ends[1][1], ends[1][0]];
  }

  static SlabEnvelopeResult _raster(
    List<WallPairCandidate> pairs,
    double scale, [
    List<List<Offset>> extraPolygons = const [],
  ]) {
    SlabEnvelopeResult empty(String reason) =>
        SlabEnvelopeResult(const [], [reason], 0, 0);
    final footprints = [
      for (final p in pairs) _footprint(p, pairs, scale),
      for (final poly in extraPolygons) poly,
    ];
    var left = double.infinity, top = double.infinity;
    var right = double.negativeInfinity, bottom = double.negativeInfinity;
    var minThickness = double.infinity;
    for (var i = 0; i < pairs.length; i++) {
      minThickness = math.min(minThickness, pairs[i].perpendicularDistance);
    }
    for (final poly in footprints) {
      for (final v in poly) {
        left = math.min(left, v.dx);
        right = math.max(right, v.dx);
        top = math.min(top, v.dy);
        bottom = math.max(bottom, v.dy);
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
    // Rasterize witnessed face endpoints. An overlap-only rectangle removes
    // the outer quarter of every mitred corner.
    for (final polygon in footprints) {
      if (polygon.isEmpty) continue;
      final padding = cell * 0.707107;
      final x0 =
          ((polygon.map((p) => p.dx).reduce(math.min) - padding - left) / cell)
              .floor()
              .clamp(0, width - 1);
      final x1 =
          ((polygon.map((p) => p.dx).reduce(math.max) + padding - left) / cell)
              .ceil()
              .clamp(0, width - 1);
      final y0 =
          ((polygon.map((p) => p.dy).reduce(math.min) - padding - top) / cell)
              .floor()
              .clamp(0, height - 1);
      final y1 =
          ((polygon.map((p) => p.dy).reduce(math.max) + padding - top) / cell)
              .ceil()
              .clamp(0, height - 1);
      for (var y = y0; y <= y1; y++) {
        for (var x = x0; x <= x1; x++) {
          final p = Offset(left + (x + 0.5) * cell, top + (y + 0.5) * cell);
          var inside = false, near = false;
          for (var i = 0; i < polygon.length; i++) {
            final a = polygon[i], b = polygon[(i + 1) % polygon.length];
            if ((a.dy > p.dy) != (b.dy > p.dy) &&
                p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
              inside = !inside;
            }
            if (_distance(p, a, b) <= padding) near = true;
          }
          if (inside || near) mask[y * width + x] = 1;
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
    var refinementFailures = 0;
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
      if (simplified.length >= 3) {
        final refined = SlabBoundaryRefiner.refine(
          ring,
          footprints,
          cell,
          scale,
        );
        if (refined == null) {
          refinementFailures++;
        } else {
          contours.add(refined);
        }
      }
    }
    return SlabEnvelopeResult(
      contours,
      [
        'sourceAlignedBoundary',
        if (refinementFailures > 0) 'boundaryRefinementFailed',
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
