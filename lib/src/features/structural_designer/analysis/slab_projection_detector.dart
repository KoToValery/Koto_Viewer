import 'dart:math' as math;
import 'drawing_frame_detector.dart';
import 'dart:ui';
import '../../dxf_viewer/models/dxf_models.dart';
import 'slab_envelope_detector.dart';
import 'structural_underlay_filter.dart';
import 'slab_parapet_chains.dart';

/// External areas bounded by existing straight CAD chains and the envelope.
/// Classifies geometric proposals into balconies (with parapet), cornices,
/// eaves, terraces, and loggias.
class SlabProjectionCandidate {
  final List<Offset> contour;
  final String sourceLayer;
  final double area;
  final String kind;
  final bool hasParapet;
  final double cantileverDepth;

  const SlabProjectionCandidate(
    this.contour,
    this.sourceLayer,
    this.area, {
    this.kind = 'externalArea',
    this.hasParapet = false,
    this.cantileverDepth = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'coordinateSpace': 'sourceCad',
    'status': 'needsReview',
    'sourceLayer': sourceLayer,
    'areaCadSquared': area,
    'hasParapet': hasParapet,
    'cantileverDepthCad': cantileverDepth,
    'contour': contour.map((p) => [p.dx, p.dy]).toList(),
    'levelVerified': false,
    'materialVerified': false,
  };
}

class SlabProjectionDetector {
  static double _area(List<Offset> ring) {
    var sum = 0.0;
    final origin = ring.first;
    for (var i = 0; i < ring.length; i++) {
      final a = ring[i] - origin, b = ring[(i + 1) % ring.length] - origin;
      sum += a.dx * b.dy - a.dy * b.dx;
    }
    return sum.abs() / 2;
  }

  static bool _inside(Offset p, List<Offset> ring) {
    var inside = false;
    for (var i = 0; i < ring.length; i++) {
      final a = ring[i], b = ring[(i + 1) % ring.length];
      if ((a.dy > p.dy) != (b.dy > p.dy) &&
          p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        inside = !inside;
      }
    }
    return inside;
  }

  static ({Offset point, int edge, double distance}) _nearest(
    Offset p,
    List<Offset> ring, {
    Offset? transverseTo,
  }) {
    var best = double.infinity, index = 0, point = Offset.zero;
    for (var i = 0; i < ring.length; i++) {
      final a = ring[i], d = ring[(i + 1) % ring.length] - a;
      if (transverseTo != null &&
          (d.distance == 0 ||
              (d.dx * transverseTo.dx + d.dy * transverseTo.dy).abs() /
                      (d.distance * transverseTo.distance) >
                  0.2)) {
        continue;
      }
      final t = d.distanceSquared == 0
          ? 0.0
          : (((p - a).dx * d.dx + (p - a).dy * d.dy) / d.distanceSquared).clamp(
              0.0,
              1.0,
            );
      final q = a + d * t, distance = (p - q).distance;
      if (distance < best) {
        best = distance;
        index = i;
        point = q;
      }
    }
    return (point: point, edge: index, distance: best);
  }

  static bool _simple(List<Offset> ring, double tolerance) {
    double cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;
    for (var i = 0; i < ring.length; i++) {
      final a = ring[i], b = ring[(i + 1) % ring.length], u = b - a;
      for (var j = i + 2; j < ring.length; j++) {
        if (i == 0 && j == ring.length - 1) continue;
        final c = ring[j], d = ring[(j + 1) % ring.length], v = d - c;
        final denominator = cross(u, v);
        if (denominator.abs() < tolerance * tolerance) continue;
        final t = cross(c - a, v) / denominator,
            s = cross(c - a, u) / denominator;
        if (t > 1e-7 && t < 1 - 1e-7 && s > 1e-7 && s < 1 - 1e-7) return false;
      }
    }
    return true;
  }

  static bool _isNonProjectionLayer(String layerName) {
    final name = layerName.toLowerCase();
    if (name.contains('railing') ||
        name.contains('парапет') ||
        name.contains('balustrade') ||
        name.contains('handrail') ||
        name.contains('балюстрад') ||
        name.contains('корниз') ||
        name.contains('cornice') ||
        name.contains('стрех') ||
        name.contains('eave') ||
        name.contains('overhang') ||
        name.contains('балкон') ||
        name.contains('balcony') ||
        name.contains('терас') ||
        name.contains('terrace')) {
      return false;
    }
    return StructuralUnderlayFilter.isNegativeKeyword(layerName);
  }

  /// Snaps segments of [polygon] that are within < 2 cm (0.02 m / 20 mm * scale)
  /// of the main slab [envelopeContours] flush to the envelope edge.
  static List<Offset> _snapToEnvelope(
    List<Offset> polygon,
    List<List<Offset>> envelopeContours,
    double scale,
  ) {
    final tolerance = 20.0 * scale; // 2 cm (20 mm)
    final epsilon = 0.001 * scale;
    if (polygon.length < 3) return polygon;

    final envelopeEdges = <(Offset, Offset)>[];
    for (final ring in envelopeContours) {
      for (var i = 0; i < ring.length; i++) {
        envelopeEdges.add((ring[i], ring[(i + 1) % ring.length]));
      }
    }
    if (envelopeEdges.isEmpty) return polygon;

    final p = List<Offset>.from(polygon);
    final lines = <(Offset, Offset)>[];
    for (var i = 0; i < p.length; i++) {
      lines.add((p[i], p[(i + 1) % p.length]));
    }

    bool anySnapped = false;
    for (var i = 0; i < lines.length; i++) {
      final (a, b) = lines[i];
      final len = (b - a).distance;
      if (len <= epsilon) continue;
      final direction = (b - a) / len;

      var bestDist = tolerance;
      (Offset, Offset)? bestTarget;

      for (final (c, d) in envelopeEdges) {
        final targetLen = (d - c).distance;
        if (targetLen <= epsilon) continue;
        final axis = (d - c) / targetLen;

        // Nearly parallel (within 5 degrees)
        final cross = (direction.dx * axis.dy - direction.dy * axis.dx).abs();
        if (cross > math.sin(5.0 * math.pi / 180.0)) continue;

        // Perpendicular distance of both endpoints to supporting line of (c, d)
        final distA = ((a - c).dx * axis.dy - (a - c).dy * axis.dx).abs();
        final distB = ((b - c).dx * axis.dy - (b - c).dy * axis.dx).abs();
        final maxDist = math.max(distA, distB);

        // Strict threshold: strictly < 2 cm (20 mm * scale)
        if (maxDist >= tolerance) continue;

        // Longitudinal overlap
        final dotA = (a - c).dx * axis.dx + (a - c).dy * axis.dy;
        final dotB = (b - c).dx * axis.dx + (b - c).dy * axis.dy;
        final tMin = math.min(dotA, dotB);
        final tMax = math.max(dotA, dotB);
        final overlap = math.min(tMax, targetLen) - math.max(tMin, 0.0);

        if (overlap > epsilon && maxDist < bestDist) {
          bestDist = maxDist;
          bestTarget = (c, d);
        }
      }

      if (bestTarget != null) {
        lines[i] = bestTarget;
        anySnapped = true;
      }
    }

    if (!anySnapped) return polygon;

    // Recompute corner intersections
    final snapped = <Offset>[];
    for (var i = 0; i < p.length; i++) {
      final (a, b) = lines[(i + p.length - 1) % p.length];
      final (c, d) = lines[i];
      final u = b - a, v = d - c;
      final denominator = u.dx * v.dy - u.dy * v.dx;
      if (denominator.abs() < 1e-8 * u.distance * v.distance) {
        snapped.add(p[i]);
        continue;
      }
      final corner =
          a + u * (((c - a).dx * v.dy - (c - a).dy * v.dx) / denominator);
      if ((corner - p[i]).distance > math.sqrt(2) * tolerance + epsilon) {
        snapped.add(p[i]);
      } else {
        snapped.add(corner);
      }
    }

    return _simple(snapped, epsilon) && _area(snapped) > 0 ? snapped : polygon;
  }

  /// Checks whether an outer boundary contour has a physical parapet / railing.
  static bool _detectParapet(
    List<Offset> polygon,
    DxfDocument doc,
    double scale,
    String sourceLayer,
  ) {
    final lowerLayer = sourceLayer.toLowerCase();
    if (lowerLayer.contains('парапет') ||
        lowerLayer.contains('railing') ||
        lowerLayer.contains('balustrade') ||
        lowerLayer.contains('handrail') ||
        lowerLayer.contains('балюстрад')) {
      return true;
    }

    final minParapetThick = 70.0 * scale; // 7-8 cm
    final maxParapetThick = 260.0 * scale; // 25-26 cm

    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i], b = polygon[(i + 1) % polygon.length];
      final edgeLen = (b - a).distance;
      if (edgeLen < 300.0 * scale) continue;
      final edgeDir = (b - a) / edgeLen;
      final edgeMid = (a + b) / 2.0;

      for (final e in doc.entities) {
        if (e is DxfLine && !e.isPaperSpace) {
          // Exclude lines that are part of the polygon's own boundary
          bool isPolygonEdge = false;
          for (var k = 0; k < polygon.length; k++) {
            final p1 = polygon[k], p2 = polygon[(k + 1) % polygon.length];
            if (((e.p1 - p1).distance < 2.0 * scale &&
                    (e.p2 - p2).distance < 2.0 * scale) ||
                ((e.p1 - p2).distance < 2.0 * scale &&
                    (e.p2 - p1).distance < 2.0 * scale)) {
              isPolygonEdge = true;
              break;
            }
          }
          if (isPolygonEdge) continue;

          final pDir = (e.p2 - e.p1);
          final pLen = pDir.distance;
          if (pLen < 200.0 * scale) continue;
          final pUnit = pDir / pLen;
          final cos = (edgeDir.dx * pUnit.dx + edgeDir.dy * pUnit.dy).abs();
          if (cos > 0.96) {
            final distMid =
                ((e.p1 - edgeMid).dx * edgeDir.dy -
                        (e.p1 - edgeMid).dy * edgeDir.dx)
                    .abs();
            if (distMid >= minParapetThick && distMid <= maxParapetThick) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  /// Classifies an external slab projection into balcony, cornice, eave, terrace,
  /// loggia, or general external area based on geometry.
  static String _classifyProjection({
    required bool isLoggia,
    required bool hasParapet,
    required double areaM2,
    required double cantileverDepthM,
    required double aspectRatio,
    required String sourceLayer,
  }) {
    if (isLoggia) return 'loggiaCandidate';

    final lowerLayer = sourceLayer.toLowerCase();
    if (lowerLayer.contains('корниз') || lowerLayer.contains('cornice')) {
      return 'cornice';
    }
    if (lowerLayer.contains('покрив') ||
        lowerLayer.contains('roof') ||
        lowerLayer.contains('стрех') ||
        lowerLayer.contains('eave') ||
        lowerLayer.contains('overhang')) {
      return 'eave';
    }
    if (lowerLayer.contains('терас') || lowerLayer.contains('terrace')) {
      return 'terrace';
    }
    if (lowerLayer.contains('балкон') || lowerLayer.contains('balcony')) {
      return 'balcony';
    }

    // 1. Cornice (корниз): narrow cantilevered strip along facade, no parapet, depth 10 - 60 cm, aspect ratio >= 2.2
    if (!hasParapet &&
        cantileverDepthM >= 0.10 &&
        cantileverDepthM <= 0.60 &&
        aspectRatio >= 2.2) {
      return 'cornice';
    }

    // 2. Eave (стреха): roof/facade overhang, no parapet, depth 0.35 - 1.80 m
    if (!hasParapet &&
        (lowerLayer.contains('покрив') ||
            lowerLayer.contains('roof') ||
            (cantileverDepthM >= 0.35 &&
                cantileverDepthM <= 1.50 &&
                aspectRatio >= 3.0))) {
      return 'eave';
    }

    // 3. Balcony with parapet (балкон с парапет)
    if (hasParapet &&
        cantileverDepthM >= 0.50 &&
        cantileverDepthM <= 2.60 &&
        areaM2 <= 20.0) {
      return 'balcony';
    }

    // 4. Terrace (тераса): larger area >= 6 m² or deep cantilever >= 2.0 m
    if (areaM2 >= 6.0 && cantileverDepthM >= 1.80) {
      return 'terrace';
    }

    // 5. If has parapet -> balcony
    if (hasParapet) {
      return 'balcony';
    }

    return 'externalArea';
  }

  static List<SlabProjectionCandidate> detect(
    DxfDocument doc,
    SlabEnvelopeResult envelope,
    double scale, {
    Set<String> wallLayers = const {},
    bool includeParapetGraph = true,
  }) {
    if (envelope.contours.isEmpty || scale <= 0 || !scale.isFinite) return [];
    doc = DrawingFrameDetector.withoutFrames(doc);
    final byLayer = <String, List<(Offset, Offset)>>{};
    bool outside(Offset p) => !envelope.contours.any((r) => _inside(p, r));
    double distance(Offset p) =>
        envelope.contours.map((r) => _nearest(p, r).distance).reduce(math.min);
    var count = 0;
    void add(Offset a, Offset b, String layer) {
      if ((a - b).distance < 50 * scale || count >= 4000) return;
      final mid = (a + b) / 2;
      if (!outside(mid) || distance(mid) > 6000 * scale) return;
      if ([a, b].any((p) => distance(p) > 6000 * scale)) return;
      byLayer.putIfAbsent(layer, () => []).add((a, b));
      count++;
    }

    final closedPolygonsByLayer = <String, List<List<Offset>>>{};

    for (final e in doc.entities) {
      if (e.isPaperSpace ||
          wallLayers.contains(e.layer) ||
          _isNonProjectionLayer(e.layer)) {
        continue;
      }
      var lt = e.lineType?.toUpperCase() ?? 'BYLAYER';
      if (lt == 'BYLAYER') {
        lt = doc.layers[e.layer]?.lineType?.toUpperCase() ?? 'CONTINUOUS';
      }
      if (!{'CONTINUOUS', 'BYBLOCK', 'BYLAYER'}.contains(lt)) continue;
      if (e is DxfLine) add(e.p1, e.p2, e.layer);
      if (e is DxfLwPolyline) {
        if (e.isClosed && e.vertices.length >= 3) {
          final pts = e.vertices.map((v) => Offset(v.x, v.y)).toList();
          closedPolygonsByLayer.putIfAbsent(e.layer, () => []).add(pts);
        }
        for (var i = 0; i < e.vertices.length - (e.isClosed ? 0 : 1); i++) {
          final a = e.vertices[i], b = e.vertices[(i + 1) % e.vertices.length];
          if (a.bulge.abs() < 1e-10) {
            add(Offset(a.x, a.y), Offset(b.x, b.y), e.layer);
          }
        }
      }
      if (e is DxfPolyline) {
        if (e.isClosed && e.vertices.length >= 3) {
          final pts = e.vertices.map((v) => Offset(v.x, v.y)).toList();
          closedPolygonsByLayer.putIfAbsent(e.layer, () => []).add(pts);
        }
        for (var i = 0; i < e.vertices.length - (e.isClosed ? 0 : 1); i++) {
          final a = e.vertices[i], b = e.vertices[(i + 1) % e.vertices.length];
          add(Offset(a.x, a.y), Offset(b.x, b.y), e.layer);
        }
      }
    }
    final candidates = <SlabProjectionCandidate>[];
    final attachment = 200 * scale;

    // Process closed polylines (e.g. balconies/cornices drawn as closed polylines)
    for (final entry in closedPolygonsByLayer.entries) {
      for (final rawPoly in entry.value) {
        final area = _area(rawPoly);
        if (area < 200000 * scale * scale || area > 100000000 * scale * scale) {
          continue;
        }
        if (rawPoly.length > 2000 || !_simple(rawPoly, scale * 0.1)) {
          continue;
        }
        final left = rawPoly.map((p) => p.dx).reduce(math.min),
            right = rawPoly.map((p) => p.dx).reduce(math.max);
        final top = rawPoly.map((p) => p.dy).reduce(math.min),
            bottom = rawPoly.map((p) => p.dy).reduce(math.max);
        var samples = 0, external = 0;
        for (var y = 0; y < 11; y++) {
          for (var x = 0; x < 11; x++) {
            final p = Offset(
              left + (x + 0.5) * (right - left) / 11,
              top + (y + 0.5) * (bottom - top) / 11,
            );
            if (_inside(p, rawPoly)) {
              samples++;
              if (outside(p)) external++;
            }
          }
        }
        if (samples < 5 || external / samples < 0.85) continue;
        final minEnvelopeDist = rawPoly
            .map((p) => distance(p))
            .reduce(math.min);
        if (minEnvelopeDist > attachment) continue;

        // Snap edge to main slab envelope if distance < 2 cm (20 mm * scale)
        final snappedPoly = _snapToEnvelope(rawPoly, envelope.contours, scale);
        final snappedArea = _area(snappedPoly);

        final unitsToM = 1.0 / (scale * 1000.0);
        final areaM2 = snappedArea * unitsToM * unitsToM;
        final maxCantileverDist = snappedPoly
            .map((p) => distance(p))
            .reduce(math.max);
        final cantileverDepthM = maxCantileverDist * unitsToM;
        final facadeLength = snappedPoly.fold<double>(
          0.0,
          (sum, p) => sum + (distance(p) <= 20 * scale ? 100 * scale : 0.0),
        );
        final aspectRatio = cantileverDepthM > 0.05
            ? ((facadeLength * unitsToM) / cantileverDepthM)
            : 10.0;
        final hasParapet = _detectParapet(snappedPoly, doc, scale, entry.key);

        final kind = _classifyProjection(
          isLoggia: false,
          hasParapet: hasParapet,
          areaM2: areaM2,
          cantileverDepthM: cantileverDepthM,
          aspectRatio: aspectRatio,
          sourceLayer: entry.key,
        );

        candidates.add(
          SlabProjectionCandidate(
            snappedPoly,
            entry.key,
            snappedArea,
            kind: kind,
            hasParapet: hasParapet,
            cantileverDepth: maxCantileverDist,
          ),
        );
      }
    }

    for (final entry in byLayer.entries) {
      final points = <Offset>[],
          edges = <(int, int)>[],
          adjacency = <int, List<int>>{};
      int node(Offset p) {
        for (var i = 0; i < points.length; i++) {
          if ((points[i] - p).distance <= 5 * scale) return i;
        }
        points.add(p);
        return points.length - 1;
      }

      for (final segment in entry.value) {
        final a = node(segment.$1), b = node(segment.$2);
        if (a == b ||
            edges.any(
              (e) => (e.$1 == a && e.$2 == b) || (e.$1 == b && e.$2 == a),
            )) {
          continue;
        }
        final i = edges.length;
        edges.add((a, b));
        adjacency.putIfAbsent(a, () => []).add(i);
        adjacency.putIfAbsent(b, () => []).add(i);
      }
      final visited = <int>{};
      for (final start in adjacency.keys.where(
        (n) => adjacency[n]!.length == 1,
      )) {
        if (visited.contains(adjacency[start]!.single)) continue;
        final chain = <Offset>[points[start]];
        var current = start, ambiguous = false;
        while (true) {
          final next = adjacency[current]!
              .where((e) => !visited.contains(e))
              .toList();
          if (next.isEmpty) break;
          if (next.length != 1 || adjacency[current]!.length > 2) {
            ambiguous = true;
            break;
          }
          final edge = next.single;
          visited.add(edge);
          current = edges[edge].$1 == current ? edges[edge].$2 : edges[edge].$1;
          chain.add(points[current]);
        }
        if (ambiguous || chain.length < 2) continue;
        for (final ring in envelope.contours) {
          final mouthDirection = chain.length == 2
              ? chain.last - chain.first
              : null;
          final first = _nearest(
                chain.first,
                ring,
                transverseTo: mouthDirection,
              ),
              last = _nearest(chain.last, ring, transverseTo: mouthDirection);
          if (first.distance > attachment || last.distance > attachment) {
            continue;
          }
          final isLoggia = chain.length == 2;
          if (isLoggia) {
            // A single railing across a recess needs two opposing side walls.
            final mouth = chain.last - chain.first;
            final sideA =
                ring[(first.edge + 1) % ring.length] - ring[first.edge];
            final sideB = ring[(last.edge + 1) % ring.length] - ring[last.edge];
            double cosine(Offset a, Offset b) =>
                (a.dx * b.dx + a.dy * b.dy) / (a.distance * b.distance);
            if (first.edge == last.edge ||
                mouth.distance > 6000 * scale ||
                cosine(mouth, sideA).abs() > 0.2 ||
                cosine(mouth, sideB).abs() > 0.2) {
              continue;
            }
          }
          final routes = <List<Offset>>[];
          if (first.edge == last.edge) {
            routes.add([first.point, ...chain, last.point]);
          }
          for (final forward in [true, false]) {
            final polygon = [first.point, ...chain, last.point];
            var i = forward ? (last.edge + 1) % ring.length : last.edge;
            final stop = forward ? (first.edge + 1) % ring.length : first.edge;
            for (var k = 0; i != stop && k <= ring.length; k++) {
              polygon.add(ring[i]);
              i = (i + (forward ? 1 : ring.length - 1)) % ring.length;
            }
            routes.add(polygon);
          }
          routes.sort((a, b) => _area(a).compareTo(_area(b)));
          for (final rawPolygon in routes) {
            // A long detour into an unclosed building is not a balcony.
            final chainLength = List.generate(
              chain.length - 1,
              (i) => (chain[i + 1] - chain[i]).distance,
            ).fold<double>(0, (a, b) => a + b);
            final perimeter = List.generate(
              rawPolygon.length,
              (i) => (rawPolygon[(i + 1) % rawPolygon.length] - rawPolygon[i])
                  .distance,
            ).fold<double>(0, (a, b) => a + b);
            if (perimeter > chainLength * 4 + 2 * attachment) continue;
            final rawArea = _area(rawPolygon);
            if (rawArea < 500000 * scale * scale ||
                rawArea > 100000000 * scale * scale) {
              continue;
            }
            if (rawPolygon.length > 2000 || !_simple(rawPolygon, scale * 0.1)) {
              continue;
            }
            final left = rawPolygon.map((p) => p.dx).reduce(math.min),
                right = rawPolygon.map((p) => p.dx).reduce(math.max);
            final top = rawPolygon.map((p) => p.dy).reduce(math.min),
                bottom = rawPolygon.map((p) => p.dy).reduce(math.max);
            var samples = 0, external = 0;
            for (var y = 0; y < 11; y++) {
              for (var x = 0; x < 11; x++) {
                final p = Offset(
                  left + (x + 0.5) * (right - left) / 11,
                  top + (y + 0.5) * (bottom - top) / 11,
                );
                if (_inside(p, rawPolygon)) {
                  samples++;
                  if (outside(p)) external++;
                }
              }
            }
            if (samples < 5 || external / samples < 0.95) continue;

            // Pull/snap boundary segments to the main slab envelope if distance < 2 cm (20 mm * scale)
            final polygon = _snapToEnvelope(
              rawPolygon,
              envelope.contours,
              scale,
            );
            final area = _area(polygon);

            final unitsToM = 1.0 / (scale * 1000.0);
            final areaM2 = area * unitsToM * unitsToM;
            final maxCantileverDist = polygon
                .map((p) => distance(p))
                .reduce(math.max);
            final cantileverDepthM = maxCantileverDist * unitsToM;
            final facadeDist =
                List.generate(
                  polygon.length,
                  (i) =>
                      (polygon[(i + 1) % polygon.length] - polygon[i]).distance,
                ).fold<double>(0, (sum, len) => sum + len) -
                chainLength;
            final aspectRatio = cantileverDepthM > 0.05
                ? ((facadeDist * unitsToM) / cantileverDepthM)
                : 10.0;
            final hasParapet = _detectParapet(polygon, doc, scale, entry.key);

            final kind = _classifyProjection(
              isLoggia: isLoggia,
              hasParapet: hasParapet,
              areaM2: areaM2,
              cantileverDepthM: cantileverDepthM,
              aspectRatio: aspectRatio,
              sourceLayer: entry.key,
            );

            candidates.add(
              SlabProjectionCandidate(
                polygon,
                entry.key,
                area,
                kind: kind,
                hasParapet: hasParapet,
                cantileverDepth: maxCantileverDist,
              ),
            );
            break;
          }
        }
      }
    }

    if (includeParapetGraph) {
      final chains = SlabParapetChains.detect(doc, envelope, scale);
      for (final chain in chains) {
        final normalized = DxfDocument(
          entities: [
            DxfLwPolyline(
              vertices: chain.points
                  .map((p) => DxfPolylineVertex(x: p.dx, y: p.dy))
                  .toList(),
              layer: chain.layer,
            ),
          ],
          layers: {chain.layer: DxfLayer(name: chain.layer)},
          blocks: {},
          headerVars: {},
          bounds: doc.bounds,
          entityStats: {},
        );
        for (final proposed in detect(
          normalized,
          envelope,
          scale,
          includeParapetGraph: false,
        )) {
          if (proposed.cantileverDepth < 350 * scale) continue;
          final units = 1 / (scale * 1000);
          candidates.add(
            SlabProjectionCandidate(
              proposed.contour,
              chain.layer,
              proposed.area,
              hasParapet: true,
              cantileverDepth: proposed.cantileverDepth,
              kind: _classifyProjection(
                isLoggia: proposed.kind == 'loggia',
                hasParapet: true,
                areaM2: proposed.area * units * units,
                cantileverDepthM: proposed.cantileverDepth * units,
                aspectRatio: 2,
                sourceLayer: chain.layer,
              ),
            ),
          );
        }
      }
    }

    // Double railing outlines describe one external area with a parapet.
    // When a smaller outline is contained inside an enclosing outline,
    // mark the enclosing outline as having a parapet!
    candidates.sort((a, b) => b.area.compareTo(a.area));
    final result = <SlabProjectionCandidate>[];
    for (final candidate in candidates) {
      final outerIndex = result.indexWhere(
        (r) =>
            candidate.area / r.area > 0.55 &&
            candidate.contour.every(
              (p) =>
                  _inside(p, r.contour) ||
                  _nearest(p, r.contour).distance <= attachment,
            ),
      );
      if (outerIndex >= 0) {
        // Enclosing candidate possesses a parapet!
        final outer = result[outerIndex];
        result[outerIndex] = SlabProjectionCandidate(
          outer.contour,
          outer.sourceLayer,
          outer.area,
          kind: (outer.kind == 'externalArea' || outer.kind == 'eave')
              ? 'balcony'
              : outer.kind,
          hasParapet: true,
          cantileverDepth: outer.cantileverDepth,
        );
        continue;
      }
      result.add(candidate);
    }
    return result;
  }
}
