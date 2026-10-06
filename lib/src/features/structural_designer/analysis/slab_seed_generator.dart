import 'dart:math' as math;
import 'dart:ui';

import '../../dxf_viewer/models/dxf_models.dart';
import '../models/structural_element.dart';

/// Explicit, one-shot generation. Existing generated slabs are never replaced.
class SlabSeedGenerator {
  static String prefix(String storeyId) => 'bim_slab_${storeyId}_';

  static List<StructuralSlab> generate({
    required Map<String, dynamic> metadata,
    required DxfDocument document,
    required String storeyId,
    required List<StructuralSlab> existing,
    required double unitsPerMeter,
    required double thickness,
    List<(Offset, Offset)>? wallReferences,
  }) {
    final idPrefix = prefix(storeyId);
    if (existing.any((s) => s.id.startsWith(idPrefix)) ||
        !unitsPerMeter.isFinite ||
        unitsPerMeter <= 0) {
      return [];
    }
    final transform = metadata['sourceToProject'] as Map?;
    final scale = (transform?['scale'] as num?)?.toDouble() ?? 1;
    final translation = transform?['translation'] as List? ?? [0, 0];
    final shift = Offset(
      (translation[0] as num).toDouble(),
      (translation[1] as num).toDouble(),
    );
    List<Offset> read(dynamic value) => (value as List? ?? [])
        .map(
          (p) =>
              Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()) *
                  scale +
              shift,
        )
        .toList();
    final ownedLayers = (metadata['layers'] as List? ?? []).cast<String>();
    final wallLayer =
        metadata['wallLayer'] as String? ??
        ownedLayers.where((s) => s.startsWith('BIM_Walls')).firstOrNull;
    final walls =
        wallReferences ??
        document.entities
            .whereType<DxfLine>()
            .where((e) => e.layer == wallLayer && !e.isPaperSpace)
            .map((e) => (e.p1, e.p2))
            .toList();
    final tolerance = 0.02 * unitsPerMeter;
    final epsilon = 0.00001 * unitsPerMeter;
    final result = <StructuralSlab>[];
    final envelope = metadata['slabEnvelope'] as Map?;
    final contours = envelope?['contours'] as List? ?? [];
    for (var i = 0; i < contours.length; i++) {
      final polygon = snap(read(contours[i]), walls, tolerance, epsilon);
      if (polygon != null) {
        result.add(
          StructuralSlab(
            id: '${idPrefix}main_$i',
            polygon: polygon,
            thickness: thickness,
          ),
        );
      }
    }
    if (result.isEmpty) return [];
    final mainEdges = result.expand((s) => edges(s.polygon)).toList();
    final projections = metadata['slabProjections'] as List? ?? [];
    for (var i = 0; i < projections.length; i++) {
      final polygon = snap(
        read(projections[i]['contour']),
        mainEdges,
        tolerance,
        epsilon,
      );
      if (polygon != null) {
        result.add(
          StructuralSlab(
            id: '${idPrefix}projection_$i',
            polygon: polygon,
            thickness: thickness,
          ),
        );
      }
    }
    return result;
  }

  static Iterable<(Offset, Offset)> edges(List<Offset> p) sync* {
    for (var i = 0; i < p.length; i++) {
      yield (p[i], p[(i + 1) % p.length]);
    }
  }

  static double _cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;
  static double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

  /// Align supporting lines, then recompute corners. Never snap vertices
  /// independently: that introduces the inward corner steps seen in raster rings.
  static List<Offset>? snap(
    List<Offset> input,
    List<(Offset, Offset)> references,
    double tolerance,
    double epsilon,
  ) {
    final p = <Offset>[];
    for (final v in input) {
      if (!v.dx.isFinite || !v.dy.isFinite) return null;
      if (p.isEmpty || (p.last - v).distance > epsilon) p.add(v);
    }
    if (p.length > 1 && (p.first - p.last).distance <= epsilon) p.removeLast();
    var changed = true;
    while (changed && p.length >= 3) {
      changed = false;
      for (var i = 0; i < p.length; i++) {
        final a = p[(i + p.length - 1) % p.length];
        final b = p[i], c = p[(i + 1) % p.length];
        if (_cross(b - a, c - a).abs() <= epsilon * (c - a).distance &&
            _dot(b - a, b - c) <= 0) {
          p.removeAt(i);
          changed = true;
          break;
        }
      }
    }
    if (!_valid(p, epsilon)) return null;
    if (p.length * references.length > 8000000) return p;
    final lines = edges(p).toList();
    for (var i = 0; i < lines.length; i++) {
      final (a, b) = lines[i];
      final direction = (b - a) / (b - a).distance;
      var best = tolerance;
      (Offset, Offset)? target;
      for (final (c, d) in references) {
        final length = (d - c).distance;
        if (length <= epsilon) continue;
        final axis = (d - c) / length;
        // At most one degree, and both endpoints within the strict 20 mm band.
        if (_cross(direction, axis).abs() > math.sin(math.pi / 180)) continue;
        final distance = math.max(
          _cross(a - c, axis).abs(),
          _cross(b - c, axis).abs(),
        );
        final t0 = _dot(a - c, axis), t1 = _dot(b - c, axis);
        final overlap =
            math.min(math.max(t0, t1), length) - math.max(math.min(t0, t1), 0);
        if (overlap <= epsilon || distance >= best) continue;
        best = distance;
        target = (c, d);
      }
      if (target != null) lines[i] = target;
    }
    final snapped = <Offset>[];
    for (var i = 0; i < p.length; i++) {
      final (a, b) = lines[(i + p.length - 1) % p.length];
      final (c, d) = lines[i];
      final u = b - a, v = d - c;
      final denominator = _cross(u, v);
      if (denominator.abs() < 1e-8 * u.distance * v.distance) return p;
      final corner = a + u * (_cross(c - a, v) / denominator);
      if ((corner - p[i]).distance > math.sqrt(2) * tolerance + epsilon) {
        return p;
      }
      snapped.add(corner);
    }
    return _valid(snapped, epsilon) && _area(p) * _area(snapped) > 0
        ? snapped
        : p;
  }

  static double _area(List<Offset> p) => edges(
    p,
  ).fold(0.0, (sum, e) => sum + _cross(e.$1 - p.first, e.$2 - p.first));

  static bool _valid(List<Offset> p, double epsilon) {
    if (p.length < 3 ||
        p.length > 2000 ||
        _area(p).abs() <= epsilon * epsilon) {
      return false;
    }
    final segments = edges(p).toList();
    for (var i = 0; i < segments.length; i++) {
      final (a, b) = segments[i];
      if ((b - a).distance <= epsilon) return false;
      for (var j = i + 2; j < segments.length; j++) {
        if (i == 0 && j == segments.length - 1) continue;
        final (c, d) = segments[j];
        if (math.max(a.dx, b.dx) + epsilon < math.min(c.dx, d.dx) ||
            math.max(c.dx, d.dx) + epsilon < math.min(a.dx, b.dx) ||
            math.max(a.dy, b.dy) + epsilon < math.min(c.dy, d.dy) ||
            math.max(c.dy, d.dy) + epsilon < math.min(a.dy, b.dy)) {
          continue;
        }
        if (_cross(b - a, c - a) * _cross(b - a, d - a) <= 0 &&
            _cross(d - c, a - c) * _cross(d - c, b - c) <= 0) {
          return false;
        }
      }
    }
    return true;
  }
}
