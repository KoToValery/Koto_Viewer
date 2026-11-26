import 'dart:ui';

import '../../bim_editing/geometry/bim_coordinate_frame.dart';
import '../../bim_editing/geometry/bim_line_geometry.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../../dxf_viewer/rendering/dxf_segment_snap.dart';
import '../models/architect_site_parcel.dart';
import 'architect_underlay_clip.dart';

abstract final class ArchitectSiteUnderlayPick {
  /// Query actual visible segments. Finite edges and their visible endpoints
  /// are the entire candidate set, even when drawing guides are active.
  static List<ArchitectSiteSegment> nearby({
    required DxfDocument document,
    required BimCoordinateFrame frame,
    required Offset point,
    required double tolerance,
    required Map<String, bool> visibility,
    List<Offset>? mask,
  }) {
    document.orBuildSpatialIndex;
    final candidates = <(double, ArchitectSiteSegment)>[];
    final seen = <ArchitectSiteSegment>{};
    final lines = DxfSegmentSnap.nearby(
      document: document,
      point: frame.toCad(point),
      radius: tolerance * frame.unitsPerMeter,
      layerVisibility: visibility,
    );
    for (final (a, b) in ArchitectUnderlayClip.segments(
      lines.map((line) => (frame.toModel(line.$1), frame.toModel(line.$2))),
      mask,
    )) {
      if ((b - a).distanceSquared < 1e-12) continue;
      final ordered = a.dx < b.dx || (a.dx == b.dx && a.dy < b.dy)
          ? (a, b)
          : (b, a);
      final distance = (BimLineGeometry.closest(point, a, b) - point).distance;
      if (distance <= tolerance && seen.add(ordered)) {
        candidates.add((distance, ordered));
      }
    }
    candidates.sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final (_, line) in candidates) line];
  }
}
