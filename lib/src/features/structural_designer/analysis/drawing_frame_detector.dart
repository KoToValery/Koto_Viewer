import 'dart:math' as math;
import 'dart:ui';
import '../../dxf_viewer/models/dxf_models.dart';

/// Sheet borders must enclose separate geometry with clear margins on all sides.
/// A rectangular building outline touching its wall faces remains a candidate.
class DrawingFrameDetector {
  static Set<DxfEntity> find(
    Iterable<DxfEntity> source,
    Map<String, DxfBlock> blocks,
  ) {
    final entities = source.where((e) => !e.isPaperSpace).toList();
    final candidates = <({List<Offset> ring, Set<DxfEntity> owners})>[];
    final lines = <String, List<DxfLine>>{};
    for (final e in entities) {
      List<DxfPolylineVertex>? vertices;
      if (e is DxfLwPolyline && e.isClosed) vertices = e.vertices;
      if (e is DxfPolyline && e.isClosed) vertices = e.vertices;
      if (vertices != null && vertices.every((v) => v.bulge == 0)) {
        final ring = vertices.map((v) => v.offset).toList();
        if (ring.length == 5 && (ring.first - ring.last).distance < 1e-8) {
          ring.removeLast();
        }
        if (ring.length == 4) candidates.add((ring: ring, owners: {e}));
      }
      if (e is DxfLine) lines.putIfAbsent(e.layer, () => []).add(e);
    }
    // Four LINE borders, including anonymous layers. Endpoint lookup avoids O(N^4).
    for (final group in lines.values) {
      String key(Offset p) =>
          '${p.dx.toStringAsFixed(6)},${p.dy.toStringAsFixed(6)}';
      final byPoint = <String, List<DxfLine>>{};
      for (final l in group) {
        byPoint.putIfAbsent(key(l.p1), () => []).add(l);
        byPoint.putIfAbsent(key(l.p2), () => []).add(l);
      }
      final seen = <DxfLine>{};
      for (final first in group) {
        if (seen.contains(first)) continue;
        final chain = <DxfLine>[first];
        final ring = <Offset>[first.p1, first.p2];
        while (chain.length < 4) {
          final adjacent = (byPoint[key(ring.last)] ?? [])
              .where((l) => !chain.contains(l))
              .toList();
          if (adjacent.length != 1) break;
          final l = adjacent.single;
          chain.add(l);
          ring.add(key(l.p1) == key(ring.last) ? l.p2 : l.p1);
        }
        if (chain.length == 4 && key(ring.last) == key(ring.first)) {
          candidates.add((ring: ring.take(4).toList(), owners: chain.toSet()));
          seen.addAll(chain);
        }
      }
    }
    final candidateByOwner = {
      for (final candidate in candidates)
        for (final owner in candidate.owners) owner: candidate,
    };
    final boxes = {for (final e in entities) e: e.getBoundingBox(blocks)};
    final frames = <DxfEntity>{};
    for (final c in candidates) {
      final ring = c.ring;
      final u0 = ring[1] - ring[0], v0 = ring[3] - ring[0];
      if (u0.distance <= 1e-8 || v0.distance <= 1e-8) continue;
      final u = u0 / u0.distance, v = v0 / v0.distance;
      if ((u.dx * v.dx + u.dy * v.dy).abs() > 1e-5 ||
          (ring[2] - ring[1] - v0).distance > v0.distance * 1e-5) {
        continue;
      }
      Offset local(Offset p) {
        final d = p - ring[0];
        return Offset(d.dx * u.dx + d.dy * u.dy, d.dx * v.dx + d.dy * v.dy);
      }

      final margin = math.min(u0.distance, v0.distance) * .02;
      final interior = Rect.fromLTWH(
        margin,
        margin,
        u0.distance - 2 * margin,
        v0.distance - 2 * margin,
      );
      Rect? content;
      var count = 0;
      var crossesBorder = false;
      for (final e in entities) {
        if (c.owners.contains(e)) continue;
        // Other candidate borders are not building evidence.
        final candidate = candidateByOwner[e];
        if (candidate != null) {
          final points = candidate.ring.map(local).toList();
          final w =
              points.map((p) => p.dx).reduce(math.max) -
              points.map((p) => p.dx).reduce(math.min);
          final h =
              points.map((p) => p.dy).reduce(math.max) -
              points.map((p) => p.dy).reduce(math.min);
          if (w >= u0.distance * .9 && h >= v0.distance * .9) continue;
        }
        final box = boxes[e];
        if (box == null) continue;
        // Use actual vertices for rotated geometry; an AABB would create
        // false crossings when transformed back into the border axes.
        final worldPoints = e is DxfLine
            ? [e.p1, e.p2]
            : e is DxfLwPolyline && e.vertices.every((v) => v.bulge == 0)
            ? e.vertices.map((v) => v.offset).toList()
            : e is DxfPolyline && e.vertices.every((v) => v.bulge == 0)
            ? e.vertices.map((v) => v.offset).toList()
            : [box.topLeft, box.topRight, box.bottomLeft, box.bottomRight];
        final points = worldPoints.map(local);
        if (!points.every(interior.contains)) {
          crossesBorder = true;
          break;
        }
        for (final p in points) {
          content = content == null
              ? Rect.fromPoints(p, p)
              : content.expandToInclude(Rect.fromPoints(p, p));
        }
        count += e is DxfLwPolyline
            ? e.vertices.length
            : e is DxfPolyline
            ? e.vertices.length
            : 1;
      }
      if (!crossesBorder &&
          count >= 4 &&
          content != null &&
          content.width * content.height < u0.distance * v0.distance * .8) {
        frames.addAll(c.owners);
      }
    }
    return frames;
  }

  static DxfDocument withoutFrames(DxfDocument doc) {
    final frames = documentFrames(doc);
    if (frames.isEmpty) return doc;
    return DxfDocument(
      layers: doc.layers,
      headerVars: doc.headerVars,
      bounds: doc.bounds,
      entityStats: doc.entityStats,
      textStyles: doc.textStyles,
      lineTypes: doc.lineTypes,
      dimStyles: doc.dimStyles,
      entities: doc.entities.where((e) => !frames.contains(e)).toList(),
      blocks: {
        for (final b in doc.blocks.values)
          b.name: DxfBlock(
            name: b.name,
            basePoint: b.basePoint,
            entities: b.entities.where((e) => !frames.contains(e)).toList(),
          ),
      },
    );
  }

  static Set<DxfEntity> documentFrames(DxfDocument doc) => {
    ...find(doc.entities, doc.blocks),
    for (final b in doc.blocks.values) ...find(b.entities, doc.blocks),
  };
}
