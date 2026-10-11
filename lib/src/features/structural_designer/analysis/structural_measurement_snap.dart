import 'dart:ui';
import '../../dxf_viewer/models/dxf_models.dart';
import '../../dxf_viewer/rendering/dxf_segment_snap.dart';
import '../../dxf_viewer/rendering/dxf_snap_helper.dart';
import 'slab_vertex_snap.dart';

/// Uses the viewer's object snaps for BIM edges and CAD underlays alike.
class StructuralMeasurementSnap {
  static ({DxfSnapResult? snap, List<(Offset, Offset)> guides}) find({
    required DxfDocument document,
    required Offset raw,
    required double tolerance,
    required List<(Offset, Offset)> edges,
    Offset? start,
  }) {
    final localEdges = edges
        .where(
          (edge) =>
              (DxfSnapHelper.closestPointOnSegment(raw, edge.$1, edge.$2) - raw)
                  .distance <=
              tolerance * 3,
        )
        .toList();
    final structuralDocument = DxfDocument(
      layers: const {},
      blocks: const {},
      headerVars: const {},
      bounds: Rect.zero,
      entityStats: const {},
      entities: [for (final (a, b) in localEdges) DxfLine(p1: a, p2: b)],
    );
    final candidates = <DxfSnapResult>[
      for (final source in [document, structuralDocument])
        ?DxfSnapHelper.findSnapPoint(
          document: source,
          cadPoint: raw,
          toleranceCad: tolerance,
          basePoint: start,
          includeIntersections: true,
        ),
    ];
    final cadEdges = DxfSegmentSnap.nearby(
      document: document,
      point: raw,
      radius: tolerance * 3,
    );
    // Also capture crossings between the underlay and BIM geometry.
    for (final cad in cadEdges) {
      for (final bim in localEdges) {
        final point = DxfSegmentSnap.intersection(cad, bim);
        if (point != null && (point - raw).distance <= tolerance) {
          candidates.add(
            DxfSnapResult(
              point: point,
              type: DxfSnapType.intersection,
              distance: (point - raw).distance,
            ),
          );
        }
      }
    }
    candidates.sort((a, b) => a.distance.compareTo(b.distance));
    final exact = candidates.where(
      (c) =>
          c.type == DxfSnapType.endpoint || c.type == DxfSnapType.intersection,
    );
    if (exact.isNotEmpty) {
      final snap = exact.first;
      return (snap: snap, guides: start == null ? [] : [(start, snap.point)]);
    }
    if (start != null) {
      final alignment = SlabVertexSnap.align(
        raw: raw,
        previous: start,
        tolerance: tolerance,
        edges: [
          ...localEdges,
          ...cadEdges,
          ...edges.where(
            (edge) =>
                (DxfSnapHelper.closestPointOnSegment(start, edge.$1, edge.$2) -
                        start)
                    .distance <=
                tolerance * 3,
          ),
          ...DxfSegmentSnap.nearby(
            document: document,
            point: start,
            radius: tolerance * 3,
          ),
        ],
      );
      if (alignment.snap != null) return alignment;
    }
    final snap = candidates.firstOrNull;
    return (
      snap: snap,
      guides: start == null || snap == null ? [] : [(start, snap.point)],
    );
  }
}
