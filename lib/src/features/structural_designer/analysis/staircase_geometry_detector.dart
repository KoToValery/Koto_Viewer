import 'dart:math' as math;
import 'dart:ui';
import '../../dxf_viewer/models/dxf_models.dart';
import '../models/structural_element.dart' show compute2DConvexHull;
import 'structural_polygon_distance.dart';

class StairFlightCandidate {
  final List<Offset> polygon;
  final List<(Offset, Offset)> treads;
  final int boundarySides;
  final double spacingM;
  final bool isWinder;
  const StairFlightCandidate({
    required this.polygon,
    required this.treads,
    required this.boundarySides,
    required this.spacingM,
    this.isWinder = false,
  });
}

class StairGeometryResult {
  final List<StairFlightCandidate> flights;
  final List<(Offset, Offset)> strokes;
  final bool limited;
  final List<(Offset, Offset)>? boundaryStrokes;
  const StairGeometryResult(
    this.flights,
    this.strokes, {
    this.limited = false,
    this.boundaryStrokes,
  });
}

/// Geometry proposals only. A tread envelope is never an automatic slab cut.
/// Includes dashed projected flights; text, symbols and layer names are unused.
class StaircaseGeometryDetector {
  static StairGeometryResult detect(
    DxfDocument document,
    double scale, {
    List<Offset>? region,
  }) {
    if (!scale.isFinite || scale <= 0) return const StairGeometryResult([], []);
    final strokes = <(Offset, Offset)>[];
    final boundaries = <(Offset, Offset)>[];
    var visited = 0, limited = false;
    void add(Offset a, Offset b, {required bool continuous}) {
      if (strokes.length >= 12000) {
        limited = true;
        return;
      }
      if (![a.dx, a.dy, b.dx, b.dy].every((n) => n.isFinite) ||
          (b - a).distance < .01 * scale) {
        return;
      }
      strokes.add((a, b));
      if (continuous) boundaries.add((a, b));
    }

    void visit(
      DxfEntity e,
      Offset Function(Offset) tr,
      String inherited,
      String inheritedType,
      int depth,
    ) {
      if (++visited > 40000 || depth > 8) {
        limited = true;
        return;
      }
      if (e.isPaperSpace) return;
      final layer = e.layer == '0' ? inherited : e.layer;
      if (document.layers[layer]?.isVisible == false) return;
      var type = (e.lineType ?? 'BYLAYER').toUpperCase();
      if (type == 'BYBLOCK') type = inheritedType;
      if (type == 'BYLAYER') {
        type = (document.layers[layer]?.lineType ?? 'CONTINUOUS').toUpperCase();
      }
      final continuous = type.isEmpty || type == 'CONTINUOUS';
      if (e is DxfInsert) {
        final block = document.blocks[e.blockName];
        if (block == null) return;
        final angle = e.rotationDeg * math.pi / 180;
        Offset child(Offset p) {
          final v = p - block.basePoint;
          final x = v.dx * e.scaleX, y = v.dy * e.scaleY;
          return tr(
            e.insertPoint +
                Offset(
                  x * math.cos(angle) - y * math.sin(angle),
                  x * math.sin(angle) + y * math.cos(angle),
                ),
          );
        }

        for (final item in block.entities) {
          if (limited) break;
          visit(item, child, layer, type, depth + 1);
        }
      } else if (e is DxfLine) {
        add(tr(e.p1), tr(e.p2), continuous: continuous);
      } else if (e is DxfLwPolyline || e is DxfPolyline) {
        final (vertices, closed) = e is DxfLwPolyline
            ? (e.vertices, e.isClosed)
            : ((e as DxfPolyline).vertices, e.isClosed);
        final count = vertices.length - (closed ? 0 : 1);
        for (var i = 0; i < count; i++) {
          final a = vertices[i], b = vertices[(i + 1) % vertices.length];
          if (a.bulge.abs() < 1e-10) {
            add(tr(a.offset), tr(b.offset), continuous: continuous);
          }
        }
      }
    }

    for (final e in document.layoutEntities['Model'] ?? document.entities) {
      if (limited) break;
      visit(e, (p) => p, '0', 'CONTINUOUS', 0);
    }
    Rect? roi;
    if (region != null && region.isNotEmpty) {
      roi = Rect.fromLTRB(
        region.map((p) => p.dx).reduce(math.min),
        region.map((p) => p.dy).reduce(math.min),
        region.map((p) => p.dx).reduce(math.max),
        region.map((p) => p.dy).reduce(math.max),
      ).inflate(.5 * scale);
    }
    final candidateKeys = <String>{};
    String pointKey(Offset p) =>
        '${(p.dx / scale * 2000).round()},${(p.dy / scale * 2000).round()}';
    final candidates = strokes.where((s) {
      final a = pointKey(s.$1), b = pointKey(s.$2);
      final key = a.compareTo(b) < 0 ? '$a/$b' : '$b/$a';
      if (!candidateKeys.add(key)) return false;
      final len = (s.$2 - s.$1).distance / scale;
      return len >= .55 &&
          len <= 2.2 &&
          (roi == null || roi.contains((s.$1 + s.$2) / 2));
    }).toList();
    if (candidates.length > 2000) {
      return StairGeometryResult(
        [],
        strokes,
        limited: true,
        boundaryStrokes: boundaries,
      );
    }
    double dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
    final flights = <StairFlightCandidate>[];
    final seen = <String>{};
    for (final seed in candidates) {
      var u = (seed.$2 - seed.$1) / (seed.$2 - seed.$1).distance;
      if (u.dx < -.00001 || (u.dx.abs() < .00001 && u.dy < 0)) {
        u = -u;
      }
      final v = Offset(-u.dy, u.dx);
      final width = (seed.$2 - seed.$1).distance;
      final center = (seed.$1 + seed.$2) / 2;
      final rows = <(double, (Offset, Offset))>[];
      for (final s in candidates) {
        final d = s.$2 - s.$1, len = d.distance;
        if (dot(d / len, u).abs() < .9994 ||
            (len - width).abs() > .15 * width ||
            dot((s.$1 + s.$2) / 2 - center, u).abs() > .08 * scale) {
          continue;
        }
        rows.add((dot((s.$1 + s.$2) / 2 - center, v), s));
      }
      rows.sort((a, b) => a.$1.compareTo(b.$1));
      final unique = <(double, (Offset, Offset))>[];
      for (final row in rows) {
        if (unique.isEmpty || row.$1 - unique.last.$1 > .015 * scale) {
          unique.add(row);
        }
      }
      for (var start = 0; start < unique.length - 3; start++) {
        final run = [unique[start]];
        double? spacing;
        for (var j = start + 1; j < unique.length; j++) {
          final gap = (unique[j].$1 - run.last.$1) / scale;
          if (gap < .16 ||
              gap > .38 ||
              (spacing != null && (gap - spacing).abs() > .15 * spacing)) {
            break;
          }
          spacing ??= gap;
          run.add(unique[j]);
        }
        if (run.length < 4) continue;
        final first = run.first.$1 - (spacing! * scale / 2),
            last = run.last.$1 + spacing * scale / 2;
        final polygon = [
          center - u * (width / 2) + v * first,
          center + u * (width / 2) + v * first,
          center + u * (width / 2) + v * last,
          center - u * (width / 2) + v * last,
        ];
        final key = run
            .map(
              (r) =>
                  '${((r.$2.$1.dx + r.$2.$2.dx) / 2 / scale * 100).round()},'
                  '${((r.$2.$1.dy + r.$2.$2.dy) / 2 / scale * 100).round()}',
            )
            .join(';');
        if (!seen.add(key)) continue;
        if (flights.any((f) => run.every((r) => f.treads.contains(r.$2)))) {
          continue;
        }
        var sides = 0;
        for (final edge in [-width / 2, width / 2]) {
          if (strokes.any((s) {
            final d = s.$2 - s.$1;
            if (d.distance < (last - first) * .4 ||
                dot(d / d.distance, v).abs() < .995) {
              return false;
            }
            final a = dot(s.$1 - center, v), b = dot(s.$2 - center, v);
            return (dot((s.$1 + s.$2) / 2 - center, u) - edge).abs() <
                    .08 * scale &&
                math.min(math.max(a, b), last) -
                        math.max(math.min(a, b), first) >
                    (last - first) * .4;
          })) {
            sides++;
          }
        }
        flights.add(
          StairFlightCandidate(
            polygon: polygon,
            treads: run.map((r) => r.$2).toList(),
            boundarySides: sides,
            spacingM: spacing,
          ),
        );
        start += run.length - 2;
        if (flights.length >= 64) {
          return StairGeometryResult(
            flights,
            strokes,
            limited: true,
            boundaryStrokes: boundaries,
          );
        }
      }
    }
    // Winder risers share a local corner rather than a parallel direction.
    // Full radial decorations and densely spaced railing profiles are excluded.
    final fanCenters = <Offset>[];
    final poles = [
      for (final seed in candidates) ...[seed.$1, seed.$2],
    ];
    final neighbours = candidates
        .where(
          (s) => flights.any(
            (f) =>
                StructuralPolygonDistance.pointToSegment(
                      (s.$1 + s.$2) / 2,
                      f.polygon[0],
                      f.polygon[1],
                    ) <
                    1.5 * scale ||
                f.polygon.any(
                  (p) =>
                      (p - s.$1).distance < .6 * scale ||
                      (p - s.$2).distance < .6 * scale,
                ),
          ),
        )
        .take(200)
        .toList();
    double cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;
    for (var i = 0; i < neighbours.length; i++) {
      for (var j = i + 1; j < neighbours.length; j++) {
        final a = neighbours[i],
            b = neighbours[j],
            u = a.$2 - a.$1,
            v = b.$2 - b.$1;
        final den = cross(u, v);
        if (den.abs() < .15 * u.distance * v.distance) continue;
        final pole = a.$1 + u * (cross(b.$1 - a.$1, v) / den);
        if (math.min((pole - a.$1).distance, (pole - a.$2).distance) >
                .32 * scale ||
            math.min((pole - b.$1).distance, (pole - b.$2).distance) >
                .32 * scale) {
          continue;
        }
        poles.add(pole);
      }
    }
    for (final pole in poles) {
      if (fanCenters.any((p) => (p - pole).distance < .04 * scale)) continue;
      fanCenters.add(pole);
      final rays = <(double, (Offset, Offset), Offset)>[];
      for (final segment in candidates) {
        final a = (segment.$1 - pole).distance,
            b = (segment.$2 - pole).distance;
        if (math.min(a, b) > .32 * scale) continue;
        if (StructuralPolygonDistance.pointToSegment(
              pole,
              segment.$1,
              segment.$2,
            ) >
            .32 * scale) {
          continue;
        }
        final direction = segment.$2 - segment.$1;
        if (cross(segment.$1 - pole, direction).abs() / direction.distance >
            .02 * scale) {
          continue;
        }
        final end = a < b ? segment.$2 : segment.$1;
        final delta = end - pole;
        rays.add((math.atan2(delta.dy, delta.dx), segment, end));
      }
      rays.sort((a, b) => a.$1.compareTo(b.$1));
      final uniqueRays = <(double, (Offset, Offset), Offset)>[];
      for (final ray in rays) {
        if (uniqueRays.isNotEmpty &&
            (ray.$1 - uniqueRays.last.$1).abs() < .04) {
          if ((ray.$3 - pole).distance > (uniqueRays.last.$3 - pole).distance) {
            uniqueRays[uniqueRays.length - 1] = ray;
          }
        } else {
          uniqueRays.add(ray);
        }
      }
      rays
        ..clear()
        ..addAll(uniqueRays);
      final attachedToFlight = flights.any(
        (f) =>
            !f.isWinder &&
            List.generate(
              f.polygon.length,
              (i) => StructuralPolygonDistance.pointToSegment(
                pole,
                f.polygon[i],
                f.polygon[(i + 1) % f.polygon.length],
              ),
            ).any((d) => d <= .65 * scale),
      );
      if (rays.length < (attachedToFlight ? 3 : 4) || rays.length > 12) {
        continue;
      }
      var largestGap = -1.0, breakAt = 0;
      for (var i = 0; i < rays.length; i++) {
        final next = (i + 1) % rays.length;
        final gap = rays[next].$1 - rays[i].$1 + (next == 0 ? 2 * math.pi : 0);
        if (gap > largestGap) {
          largestGap = gap;
          breakAt = next;
        }
      }
      final span = 2 * math.pi - largestGap;
      if (span < .5 || span > 1.85) continue;
      final ordered = [...rays.skip(breakAt), ...rays.take(breakAt)];
      final angles = <double>[];
      for (var i = 1; i < ordered.length; i++) {
        var gap = ordered[i].$1 - ordered[i - 1].$1;
        if (gap < 0) gap += 2 * math.pi;
        angles.add(gap);
      }
      final mean = span / angles.length;
      if (angles.any(
        (g) => g < .12 || g > .6 || (g - mean).abs() > mean * .3,
      )) {
        continue;
      }
      final reach = ordered.map((r) => (r.$3 - pole).distance).reduce(math.max);
      if (reach * mean / scale < .16 || reach * mean / scale > .8) continue;
      final polygon = compute2DConvexHull([pole, ...ordered.map((r) => r.$3)]);
      if (polygon.length < 3) continue;
      flights.add(
        StairFlightCandidate(
          polygon: polygon,
          treads: ordered.map((r) => r.$2).toList(),
          boundarySides: 0,
          spacingM: reach * mean / scale,
          isWinder: true,
        ),
      );
      if (flights.length >= 64) {
        return StairGeometryResult(
          flights,
          strokes,
          limited: true,
          boundaryStrokes: boundaries,
        );
      }
    }
    // Stable spatial order, independent of source entity insertion order.
    flights.sort((a, b) {
      final x = a.polygon.first.dx.compareTo(b.polygon.first.dx);
      return x != 0 ? x : a.polygon.first.dy.compareTo(b.polygon.first.dy);
    });
    return StairGeometryResult(
      flights,
      strokes,
      limited: limited,
      boundaryStrokes: boundaries,
    );
  }
}
