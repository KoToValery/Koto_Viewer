import 'dart:math' as math;
import 'dart:ui';
import '../models/architect_project.dart';
import 'architect_snap_helper.dart';
import '../../bim_projects/models/bim_coordinate_frame.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../models/architect_zone.dart';

enum ArchitectZoneSnapType {
  none,
  gridAxis,
  zoneVertex,
  zoneEdge,
  zoneWallGap,
  element,
}

class ArchitectZoneSnapResult {
  final Offset point;
  final bool isSnapped;
  final ArchitectZoneSnapType snapType;
  final String? snapLabel;
  final List<(Offset, Offset)> magneticGuides;
  final int? mergeCandidateIndex;

  const ArchitectZoneSnapResult({
    required this.point,
    this.isSnapped = false,
    this.snapType = ArchitectZoneSnapType.none,
    this.snapLabel,
    this.magneticGuides = const [],
    this.mergeCandidateIndex,
  });
}

/// Snapping engine for architectural functional zones:
/// snaps to structural grid axes and adjacent zone vertices/edges with magnetic guide lines.
class ArchitectZoneSnap {
  /// Snaps a candidate point [raw] against project grid axes and existing zones.
  static ArchitectZoneSnapResult snap({
    required Offset raw,
    required ArchitectProject project,
    bool magnetic = true,
    DxfDocument? underlay,
    BimCoordinateFrame frame = const BimCoordinateFrame(),
    Map<String, bool> visibility = const {},
    String? excludedZoneId,
    int? movingVertexIndex,
    double tolerance = 0.25, // in meters
    List<double> wallGaps = const [
      0.0,
      0.12,
      0.25,
    ], // standard wall thicknesses
  }) {
    tolerance = tolerance.clamp(0.0, .60);
    if (!magnetic) {
      return ArchitectZoneSnapResult(
        point: ArchitectSnapHelper.precision(project).inputPoint(raw),
      );
    }
    final activeStorey = project.activeStorey;
    final otherZones = activeStorey.zones
        .where((z) => z.id != excludedZoneId)
        .toList();

    Offset bestPoint = raw;
    double bestDistance = tolerance;
    ArchitectZoneSnapType bestType = ArchitectZoneSnapType.none;
    String? bestLabel;
    List<(Offset, Offset)> guides = [];

    // -------------------------------------------------------------------------
    // 1. VERTEX MERGE CHECK (If moving a vertex of an existing zone)
    // -------------------------------------------------------------------------
    int? mergeCandidate;
    if (excludedZoneId != null && movingVertexIndex != null) {
      final matches = activeStorey.zones.where((z) => z.id == excludedZoneId);
      if (matches.isNotEmpty && matches.first.polygon.length > 3) {
        final ArchitectZone currentZone = matches.first;
        final poly = currentZone.polygon;
        final n = poly.length;
        // Check immediate neighbors
        final prevIdx = (movingVertexIndex - 1 + n) % n;
        final nextIdx = (movingVertexIndex + 1) % n;

        if ((raw - poly[prevIdx]).distance <= tolerance) {
          return ArchitectZoneSnapResult(
            point: poly[prevIdx],
            isSnapped: true,
            snapType: ArchitectZoneSnapType.zoneVertex,
            snapLabel: 'Merge',
            mergeCandidateIndex: prevIdx,
          );
        }
        if ((raw - poly[nextIdx]).distance <= tolerance) {
          return ArchitectZoneSnapResult(
            point: poly[nextIdx],
            isSnapped: true,
            snapType: ArchitectZoneSnapType.zoneVertex,
            snapLabel: 'Merge',
            mergeCandidateIndex: nextIdx,
          );
        }

      }
    }

    // -------------------------------------------------------------------------
    // 2. SNAP TO OTHER ZONES' VERTICES (Highest geometric priority)
    // -------------------------------------------------------------------------
    for (final zone in otherZones) {
      for (int i = 0; i < zone.polygon.length; i++) {
        final v = zone.polygon[i];
        final dist = (raw - v).distance;
        if (dist <= bestDistance) {
          bestDistance = dist;
          bestPoint = v;
          bestType = ArchitectZoneSnapType.zoneVertex;
          bestLabel = '${zone.name} (Corner)';
          guides = [
            (v - const Offset(2.0, 0), v + const Offset(2.0, 0)),
            (v - const Offset(0, 2.0), v + const Offset(0, 2.0)),
          ];
        }
      }
    }

    // If snapped directly to a zone corner, return immediately
    if (bestType == ArchitectZoneSnapType.zoneVertex) {
      return ArchitectZoneSnapResult(
        point: bestPoint,
        isSnapped: true,
        snapType: bestType,
        snapLabel: bestLabel,
        magneticGuides: guides,
      );
    }

    // -------------------------------------------------------------------------
    // 3. SNAP TO OTHER ZONES' EDGES & STANDARD WALL GAPS (0cm, 12cm, 25cm)
    // -------------------------------------------------------------------------
    for (final zone in otherZones) {
      for (int i = 0; i < zone.polygon.length; i++) {
        final a = zone.polygon[i];
        final b = zone.polygon[(i + 1) % zone.polygon.length];
        final ab = b - a;
        final abLen2 = ab.dx * ab.dx + ab.dy * ab.dy;
        if (abLen2 < 1e-6) continue;

        final abLen = math.sqrt(abLen2);
        final unitAb = ab / abLen;
        final normal = Offset(-unitAb.dy, unitAb.dx); // outward normal

        for (final gap in wallGaps) {
          final targetA = a + normal * gap;
          final targetB = b + normal * gap;

          // Projection onto line segment
          final ap = raw - targetA;
          final t = (ap.dx * unitAb.dx + ap.dy * unitAb.dy) / abLen;

          if (t >= -0.05 && t <= 1.05) {
            final proj = targetA + unitAb * (t.clamp(0.0, 1.0) * abLen);
            final dist = (raw - proj).distance;
            if (dist <= bestDistance) {
              bestDistance = dist;
              bestPoint = proj;
              bestType = gap == 0.0
                  ? ArchitectZoneSnapType.zoneEdge
                  : ArchitectZoneSnapType.zoneWallGap;
              bestLabel = gap == 0.0
                  ? '${zone.name} (Edge)'
                  : '${zone.name} (+${(gap * 100).round()} cm)';
              guides = [(targetA - unitAb * 1.5, targetB + unitAb * 1.5)];
            }
          }
        }
      }
    }

    // -------------------------------------------------------------------------
    // 4. SNAP TO STRUCTURAL GRID AXES
    // -------------------------------------------------------------------------
    Offset? axisX;
    Offset? axisY;
    double distanceX = tolerance + 1e-9, distanceY = tolerance + 1e-9;
    String? labelX, labelY;
    void considerAxis(Offset point, String label) {
      final distance = (point - raw).distance;
      if (distance <= bestDistance && distance <= tolerance) {
        bestDistance = distance;
        bestPoint = point;
        bestType = ArchitectZoneSnapType.gridAxis;
        bestLabel = label;
        guides = [];
      }
    }

    final axes = project.gridAxes.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    for (final axis in axes) {
      final vertical = (axis.end.dx - axis.start.dx).abs() < 1e-9;
      final horizontal = (axis.end.dy - axis.start.dy).abs() < 1e-9;
      if (vertical) {
        final d = (raw.dx - axis.start.dx).abs();
        if (d < distanceX) {
          distanceX = d;
          axisX = Offset(axis.start.dx, raw.dy);
          labelX = 'Axis ${axis.name}';
        }
      } else if (horizontal) {
        final d = (raw.dy - axis.start.dy).abs();
        if (d < distanceY) {
          distanceY = d;
          axisY = Offset(raw.dx, axis.start.dy);
          labelY = 'Axis ${axis.name}';
        }
      } else {
        considerAxis(axis.projectPoint(raw), 'Axis ${axis.name}');
      }

    }
    if (axisX != null) considerAxis(axisX, labelX!);
    if (axisY != null) considerAxis(axisY, labelY!);
    if (axisX != null && axisY != null) {
      final intersection = Offset(axisX.dx, axisY.dy);
      if ((intersection - raw).distance <= tolerance &&
          (bestType == ArchitectZoneSnapType.none ||
              bestType == ArchitectZoneSnapType.gridAxis)) {
        bestPoint = intersection;
        bestType = ArchitectZoneSnapType.gridAxis;
        bestLabel = '$labelX × $labelY';
        guides = [];
      }
    }

    if (bestType == ArchitectZoneSnapType.none) {
      final common = ArchitectSnapHelper.snapFree(
        rawPoint: raw,
        project: project,
        tolerance: tolerance,
        alignment: true,
        excludedIds: {?excludedZoneId},
        underlay: underlay,
        frame: frame,
        visibility: visibility,
      );
      if (common.isSnapped) {
        return ArchitectZoneSnapResult(
          point: common.point,
          isSnapped: true,
          snapType: ArchitectZoneSnapType.element,
          snapLabel: common.snapLabel,
          magneticGuides: common.magneticGuides,
        );
      }
    }
    final isSnapped = bestType != ArchitectZoneSnapType.none;
    return ArchitectZoneSnapResult(
      point: isSnapped
          ? bestPoint
          : ArchitectSnapHelper.precision(project).inputPoint(raw),
      isSnapped: isSnapped,
      snapType: bestType,
      snapLabel: bestLabel,
      magneticGuides: guides,
      mergeCandidateIndex: mergeCandidate,
    );
  }
}
