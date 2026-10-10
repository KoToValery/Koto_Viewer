import 'dart:math' as math;
import 'dart:ui';
import '../../dxf_viewer/models/dxf_models.dart';
import 'slab_envelope_detector.dart';
import 'slab_opening_evidence.dart';
import 'structural_underlay_filter.dart';

/// Double railing faces are collapsed before tracing: caps, posts and panel
/// joints otherwise give the raw CAD graph ambiguous branches and closed strips.
class SlabParapetChain {
  final List<Offset> points;
  final String layer;
  const SlabParapetChain(this.points, this.layer);
}

class SlabParapetChains {
  static List<SlabParapetChain> detect(
    DxfDocument doc,
    SlabEnvelopeResult envelope,
    double scale,
  ) {
    bool inside(Offset p, List<Offset> ring) {
      var value = false;
      for (var i = 0; i < ring.length; i++) {
        final a = ring[i], b = ring[(i + 1) % ring.length];
        if ((a.dy > p.dy) != (b.dy > p.dy) &&
            p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
          value = !value;
        }
      }
      return value;
    }

    double distance(Offset p) {
      var best = double.infinity;
      for (final ring in envelope.contours) {
        for (var i = 0; i < ring.length; i++) {
          final a = ring[i], d = ring[(i + 1) % ring.length] - a;
          final t = d.distanceSquared == 0
              ? 0.0
              : dot(p - a, d) / d.distanceSquared;
          best = math.min(best, (p - a - d * t.clamp(0.0, 1.0)).distance);
        }
      }
      return best;
    }

    Offset interiorWitness(Offset p) {
      var best = double.infinity, witness = envelope.contours.first.first;
      for (final ring in envelope.contours) {
        var signedArea = 0.0;
        for (var i = 0; i < ring.length; i++) {
          signedArea += cross(
            ring[i] - ring.first,
            ring[(i + 1) % ring.length] - ring.first,
          );
        }
        for (var i = 0; i < ring.length; i++) {
          final a = ring[i], d = ring[(i + 1) % ring.length] - a;
          if (d.distance == 0) continue;
          final t = (dot(p - a, d) / d.distanceSquared).clamp(.0001, .9999);
          final inward =
              Offset(-d.dy, d.dx) / d.distance * (signedArea >= 0 ? 1 : -1);
          final point =
              a + d * t + inward * math.min(50 * scale, d.distance * .1);
          if (!inside(point, ring)) continue;
          if ((point - p).distance < best) {
            best = (point - p).distance;
            witness = point;
          }
        }
      }
      return witness;
    }

    final strokes = SlabOpeningEvidence.collect(doc)
        .where((s) {
          final layer = s.$3.toLowerCase();
          final parapet =
              layer.contains('парапет') ||
              layer.contains('railing') ||
              layer.contains('handrail');
          final mid = (s.$1 + s.$2) / 2;
          if (!parapet &&
              [
                'roof',
                'покрив',
                'eave',
                'стрех',
                'cornice',
                'корниз',
              ].any(layer.contains)) {
            return false;
          }
          return (parapet ||
                  !StructuralUnderlayFilter.isNegativeKeyword(layer)) &&
              (s.$2 - s.$1).distance >= 100 * scale &&
              !envelope.contours.any((r) => inside(mid, r)) &&
              distance(mid) < 6000 * scale;
        })
        .take(2500)
        .toList();
    final rails = <_Rail>[];
    var comparisons = 0;
    for (var i = 0; i < strokes.length; i++) {
      final a = strokes[i], delta = a.$2 - a.$1, u = delta / delta.distance;
      for (var j = i + 1; j < strokes.length; j++) {
        if (++comparisons > 2000000) break;
        final b = strokes[j], v = b.$2 - b.$1;
        if (a.$3 != b.$3 || cross(u, v / v.distance).abs() > .025) continue;
        final separation = cross(b.$1 - a.$1, u).abs() / scale;
        // Thin metal profiles, masonry parapets, and insulated facade returns.
        if (!((separation >= 8 && separation <= 60) ||
            (separation >= 80 && separation <= 145) ||
            (separation >= 195 && separation <= 245))) {
          continue;
        }
        if ((cross(b.$2 - a.$1, u).abs() - separation * scale).abs() >
            10 * scale) {
          continue;
        }
        final lo = math.max(
          0.0,
          math.min(dot(b.$1 - a.$1, u), dot(b.$2 - a.$1, u)),
        );
        final hi = math.min(
          delta.distance,
          math.max(dot(b.$1 - a.$1, u), dot(b.$2 - a.$1, u)),
        );
        if (hi - lo < 300 * scale ||
            hi - lo < math.min(delta.distance, v.distance) * .4) {
          continue;
        }
        // Use the observed outside face, rather than a fictitious centerline.
        final probe = (a.$1 + a.$2 + b.$1 + b.$2) / 4;
        final onA = a.$1 + u * dot(probe - a.$1, u), bDir = v / v.distance;
        final onB = b.$1 + bDir * dot(probe - b.$1, bDir);
        final witness = interiorWitness(probe);
        final outer =
            cross(onA - witness, u).abs() >= cross(onB - witness, u).abs()
            ? a
            : b;
        final rail = _Rail(outer.$1, outer.$2, outer.$3, separation * scale)
          ..faces.addAll([(a.$1, a.$2), (b.$1, b.$2)]);
        final existing = rails
            .where(
              (r) =>
                  r.layer == rail.layer &&
                  cross(r.direction, rail.direction).abs() < .025 &&
                  cross(rail.start - r.start, r.direction).abs() <=
                      math.max(
                        80 * scale,
                        math.max(r.thickness, rail.thickness),
                      ) &&
                  r.overlaps(rail, 150 * scale),
            )
            .firstOrNull;
        if (existing == null) {
          rails.add(rail);
        } else {
          final probe =
              (rail.start + rail.end + existing.start + existing.end) / 4;
          final onRail =
              rail.start +
              rail.direction * dot(probe - rail.start, rail.direction);
          final onExisting =
              existing.start +
              existing.direction *
                  dot(probe - existing.start, existing.direction);
          final witness = interiorWitness(probe);
          final outward =
              cross(onRail - witness, existing.direction).abs() >
              cross(onExisting - witness, existing.direction).abs() +
                  .001 * scale;
          final axis = outward ? rail : existing;
          final positions = [
            existing.start,
            existing.end,
            rail.start,
            rail.end,
          ].map((p) => dot(p - axis.start, axis.direction)).toList();
          final start =
              axis.start + axis.direction * positions.reduce(math.min);
          final end = axis.start + axis.direction * positions.reduce(math.max);
          existing.start = start;
          existing.end = end;
          existing.thickness = math.max(existing.thickness, rail.thickness);
          existing.faces.addAll(rail.faces);
        }
      }
      if (comparisons > 2000000) break;
    }
    // Join actual turns, including mitres whose face endpoints do not coincide.
    final joins = <int, List<(int, Offset)>>{};
    for (var i = 0; i < rails.length; i++) {
      for (var j = i + 1; j < rails.length; j++) {
        final a = rails[i], b = rails[j], den = cross(a.direction, b.direction);
        if (a.layer != b.layer || den.abs() < .5) continue;
        final point =
            a.start +
            a.direction * (cross(b.start - a.start, b.direction) / den);
        final reach = math.max(150 * scale, math.max(a.thickness, b.thickness));
        if ([a.start, a.end].map((p) => (p - point).distance).reduce(math.min) >
                reach ||
            [b.start, b.end].map((p) => (p - point).distance).reduce(math.min) >
                reach) {
          continue;
        }
        joins.putIfAbsent(i, () => []).add((j, point));
        joins.putIfAbsent(j, () => []).add((i, point));
      }
    }
    final result = <SlabParapetChain>[], visited = <int>{};
    for (var i = 0; i < rails.length; i++) {
      if (visited.contains(i) || (joins[i]?.length ?? 0) != 1) continue;
      final first = rails[i], junction = joins[i]!.single.$2;
      final start =
          (first.start - junction).distance > (first.end - junction).distance
          ? first.start
          : first.end;
      final chain = <Offset>[start];
      var current = i, previous = -1, ambiguous = false;
      final ordered = <_Rail>[];
      while (true) {
        ordered.add(rails[current]);
        visited.add(current);
        final next = (joins[current] ?? [])
            .where((p) => p.$1 != previous)
            .toList();
        if (next.isEmpty) {
          final rail = rails[current], near = chain.last;
          chain.add(
            (rail.start - near).distance > (rail.end - near).distance
                ? rail.start
                : rail.end,
          );
          break;
        }
        if (next.length != 1 || visited.contains(next.single.$1)) {
          ambiguous = true;
          break;
        }
        chain.add(next.single.$2);
        previous = current;
        current = next.single.$1;
      }
      if (!ambiguous && chain.length >= 3 && ordered.length <= 8) {
        final choices = <List<(Offset, Offset)>>[];
        for (final rail in ordered) {
          final faces = [...rail.faces]
            ..sort(
              (a, b) => cross(
                a.$1 - rail.start,
                rail.direction,
              ).compareTo(cross(b.$1 - rail.start, rail.direction)),
            );
          choices.add([faces.first, faces.last]);
        }
        for (var mask = 0; mask < (1 << ordered.length); mask++) {
          final lines = [
            for (var k = 0; k < ordered.length; k++)
              choices[k][(mask >> k) & 1],
          ];
          Offset project(Offset p, (Offset, Offset) line) {
            final u = (line.$2 - line.$1) / (line.$2 - line.$1).distance;
            return line.$1 + u * dot(p - line.$1, u);
          }

          final variant = <Offset>[project(chain.first, lines.first)];
          for (var k = 1; k < lines.length; k++) {
            final a = lines[k - 1],
                b = lines[k],
                u = a.$2 - a.$1,
                v = b.$2 - b.$1;
            variant.add(a.$1 + u * (cross(b.$1 - a.$1, v) / cross(u, v)));
          }
          variant.add(project(chain.last, lines.last));
          result.add(SlabParapetChain(variant, first.layer));
        }
      }
    }
    return result;
  }

  static double cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;
  static double dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
}

class _Rail {
  Offset start, end;
  final String layer;
  double thickness;
  final List<(Offset, Offset)> faces = [];
  _Rail(this.start, this.end, this.layer, this.thickness);
  Offset get direction => (end - start) / (end - start).distance;
  bool overlaps(_Rail other, double tolerance) {
    final a = SlabParapetChains.dot(other.start - start, direction),
        b = SlabParapetChains.dot(other.end - start, direction);
    return math.min(a, b) < (end - start).distance + tolerance &&
        math.max(a, b) > -tolerance;
  }
}
