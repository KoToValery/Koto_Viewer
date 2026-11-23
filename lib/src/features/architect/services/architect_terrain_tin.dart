import 'dart:math' as math;
import 'dart:ui';

import '../../bim_editing/geometry/bim_polygon_geometry.dart';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../models/architect_landscape_models.dart';

/// A single triangle in a 2.5D Constrained Delaunay Triangulated Irregular
/// Network (TIN) for terrain elevation lookup, section slicing, and 3D meshing.
class ArchitectTinTriangle {
  final Offset a;
  final Offset b;
  final Offset c;
  final double za;
  final double zb;
  final double zc;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final double _denom;

  ArchitectTinTriangle({
    required this.a,
    required this.b,
    required this.c,
    required this.za,
    required this.zb,
    required this.zc,
  }) : minX = math.min(a.dx, math.min(b.dx, c.dx)),
       maxX = math.max(a.dx, math.max(b.dx, c.dx)),
       minY = math.min(a.dy, math.min(b.dy, c.dy)),
       maxY = math.max(a.dy, math.max(b.dy, c.dy)),
       _denom = (b.dy - c.dy) * (a.dx - c.dx) + (c.dx - b.dx) * (a.dy - c.dy);

  /// Barycentric interpolation of elevation inside this triangle, or `null` if
  /// [point] falls outside (with slight boundary tolerance for seam stability).
  double? evaluateAt(Offset point) {
    if (_denom.abs() < 1e-12) return null;
    if (point.dx < minX - 1e-4 ||
        point.dx > maxX + 1e-4 ||
        point.dy < minY - 1e-4 ||
        point.dy > maxY + 1e-4) {
      return null;
    }
    final inv = 1.0 / _denom;
    final w0 =
        ((b.dy - c.dy) * (point.dx - c.dx) +
            (c.dx - b.dx) * (point.dy - c.dy)) *
        inv;
    final w1 =
        ((c.dy - a.dy) * (point.dx - c.dx) +
            (a.dx - c.dx) * (point.dy - c.dy)) *
        inv;
    final w2 = 1.0 - w0 - w1;
    const eps = -1e-4;
    if (w0 >= eps && w1 >= eps && w2 >= eps) {
      return w0 * za + w1 * zb + w2 * zc;
    }
    return null;
  }
}

class _TinPoint {
  final double x;
  final double y;
  double z;
  _TinPoint(this.x, this.y, this.z);
  Offset get offset => Offset(x, y);
}

class _TriIndex {
  int a;
  int b;
  int c;
  _TriIndex(this.a, this.b, this.c);
}

class _EdgeKey {
  final int u;
  final int v;
  const _EdgeKey(int p, int q) : u = p < q ? p : q, v = p < q ? q : p;

  @override
  bool operator ==(Object other) =>
      other is _EdgeKey && other.u == u && other.v == v;

  @override
  int get hashCode => Object.hash(u, v);
}

class _CachedTinEntry {
  final int signature;
  final ArchitectTerrainTin? tin;
  const _CachedTinEntry(this.signature, this.tin);
}

/// Constrained Delaunay TIN builder and spatial index for [ArchitectTerrainSurface].
///
/// Preserves exact contour lines, boundary edges, flat grading pads, and
/// excavation cutouts as constrained triangulation edges so slopes never suffer
/// from IDW cratering or artificial pulling toward `0.00`.
class ArchitectTerrainTin {
  static final Expando<_CachedTinEntry> _cache = Expando<_CachedTinEntry>();
  static const int _gridSize = 16;

  final List<ArchitectTinTriangle> triangles;
  final List<List<Offset>> _holePolygons;
  final List<ArchitectTerrainBoundary> _flatPads;
  final List<_EdgeSegment> _uniqueEdges;
  final double _minX;
  final double _minY;
  final double _cellW;
  final double _cellH;
  final List<List<int>> _grid;

  ArchitectTerrainTin._({
    required this.triangles,
    required List<List<Offset>> holePolygons,
    required List<ArchitectTerrainBoundary> flatPads,
    required List<_EdgeSegment> uniqueEdges,
    required double minX,
    required double minY,
    required double cellW,
    required double cellH,
    required List<List<int>> grid,
  }) : _holePolygons = holePolygons,
       _flatPads = flatPads,
       _uniqueEdges = uniqueEdges,
       _minX = minX,
       _minY = minY,
       _cellW = cellW,
       _cellH = cellH,
       _grid = grid;

  /// Returns a cached constrained TIN for [surface], or `null` if the surface
  /// lacks enough non-collinear vertices to triangulate.
  static ArchitectTerrainTin? of(ArchitectTerrainSurface surface) {
    final sig = _surfaceSignature(surface);
    final cached = _cache[surface];
    if (cached != null && cached.signature == sig) {
      return cached.tin;
    }
    final tin = build(surface);
    _cache[surface] = _CachedTinEntry(sig, tin);
    return tin;
  }

  static int _surfaceSignature(ArchitectTerrainSurface surface) {
    return Object.hash(
      surface.datumElevation,
      surface.boundaries.length,
      surface.contours.length,
      surface.spots.length,
      Object.hashAll(surface.boundaries),
      Object.hashAll(surface.contours),
      Object.hashAll(surface.spots),
    );
  }

  /// Builds a TIN from [surface], optionally subtracting [extraCutouts]
  /// (such as ground-floor building slabs) when generating the 3D terrain solid.
  static ArchitectTerrainTin? build(
    ArchitectTerrainSurface surface, {
    List<List<Offset>> extraCutouts = const [],
  }) {
    if (surface.isEmpty) return null;

    final holePolygons = <List<Offset>>[
      for (final b in surface.boundaries)
        if (b.isHole && b.polygon.length >= 3) b.polygon,
      for (final cutout in extraCutouts)
        if (cutout.length >= 3) cutout,
    ];
    final flatPads = <ArchitectTerrainBoundary>[
      for (final b in surface.boundaries)
        if (b.isFlatPad && !b.isHole && b.polygon.length >= 3) b,
    ];
    final outerBoundaries = <ArchitectTerrainBoundary>[
      for (final b in surface.boundaries)
        if (!b.isHole && !b.isFlatPad && b.polygon.length >= 3) b,
    ];

    // 1. Collect topographic samples for boundary auto-interpolation.
    final contourPolylines = <({List<Offset> pts, double z})>[];
    final topoSamples = <({Offset p, double z})>[];
    for (final c in surface.contours) {
      final pts = c.resolvedPolyline(samplesPerSpan: 6);
      if (pts.isEmpty) continue;
      final z = c.effectiveRelative(surface.datumElevation);
      contourPolylines.add((pts: pts, z: z));
      for (final p in pts) {
        topoSamples.add((p: p, z: z));
      }
    }
    for (final s in surface.spots) {
      topoSamples.add((p: s.position, z: s.effectiveRelative(surface.datumElevation)));
    }

    final points = <_TinPoint>[];
    final constraints = <({int a, int b})>[];

    int addOrReusePoint(
      Offset p,
      double z, {
      double mergeTol = 0.02,
      bool overwriteZ = true,
    }) {
      final tolSq = mergeTol * mergeTol;
      for (var i = 0; i < points.length; i++) {
        final existing = points[i];
        final dx = existing.x - p.dx;
        final dy = existing.y - p.dy;
        if (dx * dx + dy * dy <= tolSq) {
          if (overwriteZ) existing.z = z;
          return i;
        }
      }
      points.add(_TinPoint(p.dx, p.dy, z));
      return points.length - 1;
    }

    // 2. Determine outer boundary polygons + corner Z.
    final outerPolysWithZ = <List<({Offset p, double z})>>[];
    if (outerBoundaries.isNotEmpty) {
      for (final bnd in outerBoundaries) {
        final poly = bnd.polygon;
        final useAuto = bnd.autoInterpolateElevation && topoSamples.isNotEmpty;
        final withZ = <({Offset p, double z})>[];
        for (var i = 0; i < poly.length; i++) {
          final v = poly[i];
          final z = useAuto
              ? _nearestTopoElevation(v, topoSamples)
              : bnd.vertexElevationAt(i);
          withZ.add((p: v, z: z));
        }
        outerPolysWithZ.add(withZ);
      }
    } else {
      final b = surface.bounds;
      if (b != null) {
        final rect = b.inflate(3.5);
        final corners = [
          rect.topLeft,
          rect.topRight,
          rect.bottomRight,
          rect.bottomLeft,
        ];
        outerPolysWithZ.add([
          for (final c in corners)
            (
              p: c,
              z: topoSamples.isNotEmpty
                  ? _nearestTopoElevation(c, topoSamples)
                  : 0.0,
            ),
        ]);
      }
    }

    // 3. Collect boundary, flat-pad, and hole perimeter segments so every
    //    contour crossing creates shared exact PSLG junction vertices.
    final boundarySegments =
        <({Offset a, Offset b, double za, double zb})>[];
    for (final poly in outerPolysWithZ) {
      for (var i = 0; i < poly.length; i++) {
        final curr = poly[i];
        final next = poly[(i + 1) % poly.length];
        boundarySegments.add((a: curr.p, b: next.p, za: curr.z, zb: next.z));
      }
    }
    final padSegments = <({Offset a, Offset b, double z})>[];
    for (final pad in flatPads) {
      for (var i = 0; i < pad.polygon.length; i++) {
        padSegments.add((
          a: pad.polygon[i],
          b: pad.polygon[(i + 1) % pad.polygon.length],
          z: pad.elevation,
        ));
      }
    }
    final holeSegments = <({Offset a, Offset b})>[];
    for (final hole in holePolygons) {
      for (var i = 0; i < hole.length; i++) {
        holeSegments.add((
          a: hole[i],
          b: hole[(i + 1) % hole.length],
        ));
      }
    }

    for (final c in contourPolylines) {
      for (var i = 0; i + 1 < c.pts.length; i++) {
        final p0 = c.pts[i];
        final p1 = c.pts[i + 1];
        if ((p1 - p0).distanceSquared < 1e-8) continue;

        final splits = <({double t, Offset p, double z})>[
          (t: 0.0, p: p0, z: c.z),
          (t: 1.0, p: p1, z: c.z),
        ];
        for (final edge in boundarySegments) {
          final hit = _properSegmentIntersection(p0, p1, edge.a, edge.b);
          if (hit != null && hit.t > 1e-4 && hit.t < 1.0 - 1e-4) {
            splits.add((t: hit.t, p: hit.point, z: c.z));
          }
        }
        for (final edge in padSegments) {
          final hit = _properSegmentIntersection(p0, p1, edge.a, edge.b);
          if (hit != null && hit.t > 1e-4 && hit.t < 1.0 - 1e-4) {
            splits.add((t: hit.t, p: hit.point, z: edge.z));
          }
        }
        for (final edge in holeSegments) {
          final hit = _properSegmentIntersection(p0, p1, edge.a, edge.b);
          if (hit != null && hit.t > 1e-4 && hit.t < 1.0 - 1e-4) {
            splits.add((t: hit.t, p: hit.point, z: c.z));
          }
        }
        splits.sort((u, v) => u.t.compareTo(v.t));

        int? prevIdx;
        for (final s in splits) {
          final idx = addOrReusePoint(s.p, s.z);
          if (prevIdx != null && prevIdx != idx) {
            constraints.add((a: prevIdx, b: idx));
          }
          prevIdx = idx;
        }
      }
      if (c.pts.length == 1) {
        addOrReusePoint(c.pts.first, c.z);
      }
    }

    // 4. Insert explicit spots (exact Z relative to datum).
    for (final s in surface.spots) {
      addOrReusePoint(
        s.position,
        s.effectiveRelative(surface.datumElevation),
      );
    }

    void insertPolygonEdgeWithContourSplits({
      required Offset a,
      required double za,
      required Offset b,
      required double zb,
      required bool overwriteEnds,
      double? forcedZ,
      List<({Offset a, Offset b})> crossSegments = const [],
    }) {
      final splits = <({double t, Offset p, double z, bool overwrite})>[
        (t: 0.0, p: a, z: forcedZ ?? za, overwrite: overwriteEnds),
        (t: 1.0, p: b, z: forcedZ ?? zb, overwrite: overwriteEnds),
      ];
      for (final c in contourPolylines) {
        final splitZ = forcedZ ?? c.z;
        for (var j = 0; j + 1 < c.pts.length; j++) {
          final hit =
              _properSegmentIntersection(a, b, c.pts[j], c.pts[j + 1]);
          if (hit != null && hit.t > 1e-4 && hit.t < 1.0 - 1e-4) {
            splits.add((t: hit.t, p: hit.point, z: splitZ, overwrite: true));
          }
        }
      }
      for (final seg in crossSegments) {
        final hit = _properSegmentIntersection(a, b, seg.a, seg.b);
        if (hit != null && hit.t > 1e-4 && hit.t < 1.0 - 1e-4) {
          final interpZ = forcedZ ?? (za + (zb - za) * hit.t);
          splits.add((
            t: hit.t,
            p: hit.point,
            z: interpZ,
            overwrite: forcedZ != null,
          ));
        }
      }
      splits.sort((u, v) => u.t.compareTo(v.t));
      int? prevIdx;
      for (final s in splits) {
        final idx = addOrReusePoint(s.p, s.z, overwriteZ: s.overwrite);
        if (prevIdx != null && prevIdx != idx) {
          constraints.add((a: prevIdx, b: idx));
        }
        prevIdx = idx;
      }
    }

    // 5. Insert outer boundary edges, splitting along contour & hole crossings.
    for (final edge in boundarySegments) {
      // Never overwrite an exact contour/spot vertex with an interpolated boundary corner.
      insertPolygonEdgeWithContourSplits(
        a: edge.a,
        za: edge.za,
        b: edge.b,
        zb: edge.zb,
        overwriteEnds: false,
        crossSegments: holeSegments,
      );
    }

    // 6. Apply flat grading pads: override interior points to pad.elevation
    //    and insert pad perimeter edges (split at contour crossings) as constraints.
    for (final pad in flatPads) {
      for (final pt in points) {
        if (BimPolygonGeometry.contains(pad.polygon, pt.offset)) {
          pt.z = pad.elevation;
        }
      }
      for (var i = 0; i < pad.polygon.length; i++) {
        insertPolygonEdgeWithContourSplits(
          a: pad.polygon[i],
          za: pad.elevation,
          b: pad.polygon[(i + 1) % pad.polygon.length],
          zb: pad.elevation,
          overwriteEnds: true,
          forcedZ: pad.elevation,
        );
      }
    }

    // 7. Insert hole & cutout perimeters (split at contour & boundary crossings).
    double? existingPointZ(Offset p) {
      for (final pt in points) {
        final dx = pt.x - p.dx;
        final dy = pt.y - p.dy;
        if (dx * dx + dy * dy <= 0.02 * 0.02) return pt.z;
      }
      return null;
    }

    final boundarySegOffsets = [
      for (final edge in boundarySegments) (a: edge.a, b: edge.b),
    ];
    for (final hole in holePolygons) {
      for (var i = 0; i < hole.length; i++) {
        final a = hole[i];
        final b = hole[(i + 1) % hole.length];
        insertPolygonEdgeWithContourSplits(
          a: a,
          za: existingPointZ(a) ??
              (topoSamples.isNotEmpty
                  ? _nearestTopoElevation(a, topoSamples)
                  : 0.0),
          b: b,
          zb: existingPointZ(b) ??
              (topoSamples.isNotEmpty
                  ? _nearestTopoElevation(b, topoSamples)
                  : 0.0),
          overwriteEnds: false,
          crossSegments: boundarySegOffsets,
        );
      }
    }

    if (points.length < 3) return null;

    // 8. Compute bounds and run shifted Bowyer-Watson Delaunay triangulation.
    var minX = points.first.x;
    var maxX = points.first.x;
    var minY = points.first.y;
    var maxY = points.first.y;
    for (final p in points) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }
    final spanX = maxX - minX;
    final spanY = maxY - minY;
    final span = math.max(spanX, spanY);
    if (span < 1e-5) return null;

    final cx = (minX + maxX) * 0.5;
    final cy = (minY + maxY) * 0.5;
    final sx = [for (final p in points) p.x - cx];
    final sy = [for (final p in points) p.y - cy];

    final triIndices = _triangulateConstrained(
      sx: sx,
      sy: sy,
      span: span,
      constraints: constraints,
    );
    if (triIndices.isEmpty) return null;

    // 9. Keep triangles inside outer polygons and outside holes/cutouts.
    final outerPolys = [for (final p in outerPolysWithZ) [for (final v in p) v.p]];
    final keptTriangles = <ArchitectTinTriangle>[];
    final uniqueEdgeKeys = <_EdgeKey>{};
    final uniqueEdges = <_EdgeSegment>[];

    for (final t in triIndices) {
      final pa = points[t.a];
      final pb = points[t.b];
      final pc = points[t.c];
      final area2 =
          (pb.x - pa.x) * (pc.y - pa.y) - (pb.y - pa.y) * (pc.x - pa.x);
      if (area2.abs() < 1e-10) continue;

      final gx = (pa.x + pb.x + pc.x) / 3.0;
      final gy = (pa.y + pb.y + pc.y) / 3.0;
      final centroid = Offset(gx, gy);

      if (outerPolys.isNotEmpty &&
          !outerPolys.any((poly) => BimPolygonGeometry.contains(poly, centroid))) {
        continue;
      }
      if (holePolygons.any((hole) => BimPolygonGeometry.contains(hole, centroid))) {
        continue;
      }

      // Ensure CCW order in world XY coordinates so 3D normals point upward (+Z).
      final tri = area2 >= 0
          ? ArchitectTinTriangle(
              a: pa.offset,
              b: pb.offset,
              c: pc.offset,
              za: pa.z,
              zb: pb.z,
              zc: pc.z,
            )
          : ArchitectTinTriangle(
              a: pa.offset,
              b: pc.offset,
              c: pb.offset,
              za: pa.z,
              zb: pc.z,
              zc: pb.z,
            );
      keptTriangles.add(tri);

      for (final edge in [
        (_EdgeKey(t.a, t.b), pa.offset, pb.offset),
        (_EdgeKey(t.b, t.c), pb.offset, pc.offset),
        (_EdgeKey(t.c, t.a), pc.offset, pa.offset),
      ]) {
        if (uniqueEdgeKeys.add(edge.$1)) {
          uniqueEdges.add(_EdgeSegment(edge.$2, edge.$3));
        }
      }
    }

    if (keptTriangles.isEmpty) return null;

    // 10. Build 16x16 spatial lookup grid over kept triangles.
    var kMinX = keptTriangles.first.minX;
    var kMaxX = keptTriangles.first.maxX;
    var kMinY = keptTriangles.first.minY;
    var kMaxY = keptTriangles.first.maxY;
    for (final tri in keptTriangles) {
      if (tri.minX < kMinX) kMinX = tri.minX;
      if (tri.maxX > kMaxX) kMaxX = tri.maxX;
      if (tri.minY < kMinY) kMinY = tri.minY;
      if (tri.maxY > kMaxY) kMaxY = tri.maxY;
    }

    final cellW = math.max(1e-4, (kMaxX - kMinX + 2e-4) / _gridSize);
    final cellH = math.max(1e-4, (kMaxY - kMinY + 2e-4) / _gridSize);
    final grid = List<List<int>>.generate(_gridSize * _gridSize, (_) => <int>[]);

    for (var i = 0; i < keptTriangles.length; i++) {
      final tri = keptTriangles[i];
      final gx0 = ((tri.minX - kMinX) / cellW).floor().clamp(0, _gridSize - 1);
      final gx1 = ((tri.maxX - kMinX) / cellW).floor().clamp(0, _gridSize - 1);
      final gy0 = ((tri.minY - kMinY) / cellH).floor().clamp(0, _gridSize - 1);
      final gy1 = ((tri.maxY - kMinY) / cellH).floor().clamp(0, _gridSize - 1);
      for (var gy = gy0; gy <= gy1; gy++) {
        for (var gx = gx0; gx <= gx1; gx++) {
          grid[gy * _gridSize + gx].add(i);
        }
      }
    }

    return ArchitectTerrainTin._(
      triangles: keptTriangles,
      holePolygons: holePolygons,
      flatPads: flatPads,
      uniqueEdges: uniqueEdges,
      minX: kMinX,
      minY: kMinY,
      cellW: cellW,
      cellH: cellH,
      grid: grid,
    );
  }

  /// Evaluates terrain elevation at [point] via barycentric TIN lookup,
  /// honoring excavation holes (`null`) and flat grading pads.
  double? evaluateElevationAt(Offset point) {
    for (final hole in _holePolygons.reversed) {
      if (BimPolygonGeometry.contains(hole, point)) return null;
    }
    for (final pad in _flatPads.reversed) {
      if (pad.containsPoint(point)) return pad.elevation;
    }
    if (point.dx < _minX - 1e-4 || point.dy < _minY - 1e-4) return null;
    final gx = ((point.dx - _minX) / _cellW).floor();
    final gy = ((point.dy - _minY) / _cellH).floor();
    if (gx < 0 || gx >= _gridSize || gy < 0 || gy >= _gridSize) return null;

    final bucket = _grid[gy * _gridSize + gx];
    for (final idx in bucket) {
      final z = triangles[idx].evaluateAt(point);
      if (z != null) return z;
    }
    return null;
  }

  /// Returns exact intersection points between segment [start]->[end] and TIN
  /// triangle edges so terrain profiles cut exact piecewise-linear slopes.
  List<Offset> intersectionStations(Offset start, Offset end) {
    final sMinX = math.min(start.dx, end.dx) - 1e-5;
    final sMaxX = math.max(start.dx, end.dx) + 1e-5;
    final sMinY = math.min(start.dy, end.dy) - 1e-5;
    final sMaxY = math.max(start.dy, end.dy) + 1e-5;
    final hits = <({double t, Offset p})>[];

    for (final edge in _uniqueEdges) {
      if (edge.maxX < sMinX ||
          edge.minX > sMaxX ||
          edge.maxY < sMinY ||
          edge.minY > sMaxY) {
        continue;
      }
      final hit = _properSegmentIntersection(start, end, edge.a, edge.b);
      if (hit != null && hit.t > 1e-5 && hit.t < 1.0 - 1e-5) {
        hits.add((t: hit.t, p: hit.point));
      }
    }
    hits.sort((a, b) => a.t.compareTo(b.t));
    return [for (final h in hits) h.p];
  }

  /// Builds a watertight 3D mesh (sloped TIN top + boundary/cutout vertical
  /// earth skirts + flat bottom cap) for [surface], subtracting [buildingCutouts].
  static List<Triangle3D> buildMesh3D(
    ArchitectTerrainSurface surface, {
    required List<List<Offset>> buildingCutouts,
    required Color topColor,
    required Color sideColor,
    required Color bottomColor,
    double skirtDepth = 1.0,
  }) {
    final tin = buildingCutouts.isEmpty
        ? ArchitectTerrainTin.of(surface)
        : ArchitectTerrainTin.build(surface, extraCutouts: buildingCutouts);
    if (tin == null || tin.triangles.isEmpty) return const [];

    var minZ = tin.triangles.first.za;
    for (final t in tin.triangles) {
      if (t.za < minZ) minZ = t.za;
      if (t.zb < minZ) minZ = t.zb;
      if (t.zc < minZ) minZ = t.zc;
    }
    final bottomZ = minZ - skirtDepth;

    final out = <Triangle3D>[];
    final directedEdges = <String, ({Offset a, double za, Offset b, double zb})>{};

    String ptKey(Offset p) =>
        '${(p.dx * 1000).round()},${(p.dy * 1000).round()}';

    void trackEdge(Offset a, double za, Offset b, double zb) {
      final ka = ptKey(a);
      final kb = ptKey(b);
      final reverseKey = '$kb->$ka';
      if (directedEdges.remove(reverseKey) == null) {
        directedEdges['$ka->$kb'] = (a: a, za: za, b: b, zb: zb);
      }
    }

    for (final tri in tin.triangles) {
      final vaTop = Vector3(tri.a.dx, tri.a.dy, tri.za);
      final vbTop = Vector3(tri.b.dx, tri.b.dy, tri.zb);
      final vcTop = Vector3(tri.c.dx, tri.c.dy, tri.zc);
      out.add(Triangle3D(v0: vaTop, v1: vbTop, v2: vcTop, color: topColor));

      final vaBot = Vector3(tri.a.dx, tri.a.dy, bottomZ);
      final vbBot = Vector3(tri.b.dx, tri.b.dy, bottomZ);
      final vcBot = Vector3(tri.c.dx, tri.c.dy, bottomZ);
      out.add(Triangle3D(v0: vaBot, v1: vcBot, v2: vbBot, color: bottomColor));

      trackEdge(tri.a, tri.za, tri.b, tri.zb);
      trackEdge(tri.b, tri.zb, tri.c, tri.zc);
      trackEdge(tri.c, tri.zc, tri.a, tri.za);
    }

    for (final edge in directedEdges.values) {
      final aTop = Vector3(edge.a.dx, edge.a.dy, edge.za);
      final bTop = Vector3(edge.b.dx, edge.b.dy, edge.zb);
      final aBot = Vector3(edge.a.dx, edge.a.dy, bottomZ);
      final bBot = Vector3(edge.b.dx, edge.b.dy, bottomZ);
      out.add(Triangle3D(v0: aTop, v1: aBot, v2: bTop, color: sideColor));
      out.add(Triangle3D(v0: bTop, v1: aBot, v2: bBot, color: sideColor));
    }

    return out;
  }

  static double _nearestTopoElevation(
    Offset pt,
    List<({Offset p, double z})> samples,
  ) {
    final scored = <({double distSq, double z})>[];
    for (final s in samples) {
      final dx = s.p.dx - pt.dx;
      final dy = s.p.dy - pt.dy;
      final d2 = dx * dx + dy * dy;
      if (d2 < 1e-6) return s.z;
      scored.add((distSq: d2, z: s.z));
    }
    scored.sort((a, b) => a.distSq.compareTo(b.distSq));
    final count = math.min(4, scored.length);
    var wSum = 0.0;
    var wTot = 0.0;
    for (var i = 0; i < count; i++) {
      final w = 1.0 / scored[i].distSq;
      wSum += scored[i].z * w;
      wTot += w;
    }
    return wTot > 0 ? wSum / wTot : 0.0;
  }

  // ---------------------------------------------------------------------------
  // Constrained Delaunay Triangulation (Bowyer-Watson + Diagonal Edge-Flipping)
  // ---------------------------------------------------------------------------

  static List<_TriIndex> _triangulateConstrained({
    required List<double> sx,
    required List<double> sy,
    required double span,
    required List<({int a, int b})> constraints,
  }) {
    final n = sx.length;
    final r = span * 20.0 + 100.0;
    final allX = List<double>.from(sx)..addAll([0.0, -3.0 * r, 3.0 * r]);
    final allY = List<double>.from(sy)..addAll([3.0 * r, -3.0 * r, -3.0 * r]);

    final order = List<int>.generate(n, (i) => i)
      ..sort((i, j) {
        final dx = allX[i].compareTo(allX[j]);
        return dx != 0 ? dx : allY[i].compareTo(allY[j]);
      });

    final tris = <_TriIndex>[_TriIndex(n, n + 1, n + 2)];
    final circumEps = 1e-9 * span * span;

    for (final pi in order) {
      final px = allX[pi];
      final py = allY[pi];
      final bad = <_TriIndex>[];
      final good = <_TriIndex>[];

      for (final tri in tris) {
        if (_inCircumcircle(allX, allY, tri.a, tri.b, tri.c, px, py, circumEps)) {
          bad.add(tri);
        } else {
          good.add(tri);
        }
      }

      if (bad.isEmpty) continue;

      final edgeCounts = <({int u, int v}), int>{};
      final directed = <({int u, int v})>[];
      for (final tri in bad) {
        for (final e in [
          (u: tri.a, v: tri.b),
          (u: tri.b, v: tri.c),
          (u: tri.c, v: tri.a),
        ]) {
          final key = e.u < e.v ? (u: e.u, v: e.v) : (u: e.v, v: e.u);
          edgeCounts[key] = (edgeCounts[key] ?? 0) + 1;
          directed.add(e);
        }
      }

      tris
        ..clear()
        ..addAll(good);

      for (final e in directed) {
        final key = e.u < e.v ? (u: e.u, v: e.v) : (u: e.v, v: e.u);
        if (edgeCounts[key] == 1) {
          final t = _makeCcw(allX, allY, e.u, e.v, pi);
          if (t != null) tris.add(t);
        }
      }
    }

    // Drop super-triangle vertices.
    tris.removeWhere((t) => t.a >= n || t.b >= n || t.c >= n);

    // Recover constrained edges via convex quadrilateral diagonal flipping.
    for (final c in constraints) {
      if (c.a != c.b && c.a < n && c.b < n) {
        _enforceConstraint(allX, allY, tris, c.a, c.b);
      }
    }

    return tris;
  }

  static _TriIndex? _makeCcw(
    List<double> x,
    List<double> y,
    int a,
    int b,
    int c,
  ) {
    final area2 = (x[b] - x[a]) * (y[c] - y[a]) - (y[b] - y[a]) * (x[c] - x[a]);
    if (area2.abs() < 1e-12) return null;
    return area2 > 0 ? _TriIndex(a, b, c) : _TriIndex(a, c, b);
  }

  static double _orient(
    List<double> x,
    List<double> y,
    int a,
    int b,
    int c,
  ) =>
      (x[b] - x[a]) * (y[c] - y[a]) - (y[b] - y[a]) * (x[c] - x[a]);

  static bool _inCircumcircle(
    List<double> x,
    List<double> y,
    int ia,
    int ib,
    int ic,
    double px,
    double py,
    double eps,
  ) {
    final ax = x[ia] - px;
    final ay = y[ia] - py;
    final bx = x[ib] - px;
    final by = y[ib] - py;
    final cx = x[ic] - px;
    final cy = y[ic] - py;

    final a2 = ax * ax + ay * ay;
    final b2 = bx * bx + by * by;
    final c2 = cx * cx + cy * cy;

    final det =
        a2 * (bx * cy - by * cx) -
        b2 * (ax * cy - ay * cx) +
        c2 * (ax * by - ay * bx);

    final ccw =
        (x[ib] - x[ia]) * (y[ic] - y[ia]) - (y[ib] - y[ia]) * (x[ic] - x[ia]);
    return ccw >= 0 ? det > -eps : det < eps;
  }

  static void _enforceConstraint(
    List<double> x,
    List<double> y,
    List<_TriIndex> tris,
    int ca,
    int cb,
  ) {
    // Check whether (ca, cb) is already present.
    for (final t in tris) {
      if ((t.a == ca && (t.b == cb || t.c == cb)) ||
          (t.b == ca && (t.a == cb || t.c == cb)) ||
          (t.c == ca && (t.a == cb || t.b == cb))) {
        return;
      }
    }

    // Collect crossing edges in the triangulation.
    final seen = <_EdgeKey>{};
    final queue = <({int u, int v})>[];
    final segA = Offset(x[ca], y[ca]);
    final segB = Offset(x[cb], y[cb]);

    for (final t in tris) {
      for (final e in [
        (u: t.a, v: t.b),
        (u: t.b, v: t.c),
        (u: t.c, v: t.a),
      ]) {
        if (e.u == ca || e.u == cb || e.v == ca || e.v == cb) continue;
        final key = _EdgeKey(e.u, e.v);
        if (!seen.add(key)) continue;
        if (_properSegmentIntersection(
              segA,
              segB,
              Offset(x[e.u], y[e.u]),
              Offset(x[e.v], y[e.v]),
            ) !=
            null) {
          queue.add(e);
        }
      }
    }

    if (queue.isEmpty) return;

    var attempts = 0;
    final maxAttempts = queue.length * 8 + 32;
    while (queue.isNotEmpty && attempts < maxAttempts) {
      attempts++;
      final e = queue.removeAt(0);
      final adj = <int>[];
      for (var i = 0; i < tris.length; i++) {
        final t = tris[i];
        final hasU = t.a == e.u || t.b == e.u || t.c == e.u;
        final hasV = t.a == e.v || t.b == e.v || t.c == e.v;
        if (hasU && hasV) adj.add(i);
      }
      if (adj.length != 2) continue;

      final t0 = tris[adj[0]];
      final t1 = tris[adj[1]];
      final r = _thirdVertex(t0, e.u, e.v);
      final s = _thirdVertex(t1, e.u, e.v);
      if (r < 0 || s < 0 || r == s) continue;

      // Quadrilateral (e.u, r, e.v, s) is strictly convex iff diagonals cross.
      final o1 = _orient(x, y, e.u, e.v, r);
      final o2 = _orient(x, y, e.u, e.v, s);
      final o3 = _orient(x, y, r, s, e.u);
      final o4 = _orient(x, y, r, s, e.v);
      final isConvex = (o1 * o2 < -1e-12) && (o3 * o4 < -1e-12);
      if (!isConvex) {
        queue.add(e);
        continue;
      }

      // Flip diagonal (e.u, e.v) -> (r, s).
      final nt0 = _makeCcw(x, y, r, s, e.u);
      final nt1 = _makeCcw(x, y, r, s, e.v);
      if (nt0 == null || nt1 == null) {
        queue.add(e);
        continue;
      }
      tris[adj[0]] = nt0;
      tris[adj[1]] = nt1;

      if (r != ca && r != cb && s != ca && s != cb) {
        if (_properSegmentIntersection(
              segA,
              segB,
              Offset(x[r], y[r]),
              Offset(x[s], y[s]),
            ) !=
            null) {
          queue.add((u: r, v: s));
        }
      }
    }
  }

  static int _thirdVertex(_TriIndex t, int u, int v) {
    if (t.a != u && t.a != v) return t.a;
    if (t.b != u && t.b != v) return t.b;
    if (t.c != u && t.c != v) return t.c;
    return -1;
  }

  static ({double t, Offset point})? _properSegmentIntersection(
    Offset a,
    Offset b,
    Offset c,
    Offset d,
  ) {
    final abx = b.dx - a.dx;
    final aby = b.dy - a.dy;
    final cdx = d.dx - c.dx;
    final cdy = d.dy - c.dy;
    final denom = abx * cdy - aby * cdx;
    if (denom.abs() < 1e-11) return null;

    final acx = c.dx - a.dx;
    final acy = c.dy - a.dy;
    final t = (acx * cdy - acy * cdx) / denom;
    final u = (acx * aby - acy * abx) / denom;
    const eps = 1e-5;
    if (t > eps && t < 1.0 - eps && u > eps && u < 1.0 - eps) {
      return (t: t, point: Offset(a.dx + t * abx, a.dy + t * aby));
    }
    return null;
  }
}

class _EdgeSegment {
  final Offset a;
  final Offset b;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;

  _EdgeSegment(this.a, this.b)
    : minX = math.min(a.dx, b.dx),
      maxX = math.max(a.dx, b.dx),
      minY = math.min(a.dy, b.dy),
      maxY = math.max(a.dy, b.dy);
}
