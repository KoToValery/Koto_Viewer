import 'dart:math' as math;
import 'dart:ui';
import '../models/architect_project.dart';
import '../models/architect_zone.dart';

enum ArchitectZoneSnapType {
  none,
  gridAxis,
  zoneVertex,
  zoneEdge,
  zoneWallGap,
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
    String? excludedZoneId,
    int? movingVertexIndex,
    double tolerance = 0.25, // in meters
    List<double> wallGaps = const [0.0, 0.12, 0.25], // standard wall thicknesses
  }) {
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
            snapLabel: 'Обединяване (Merge)',
            mergeCandidateIndex: prevIdx,
          );
        }
        if ((raw - poly[nextIdx]).distance <= tolerance) {
          return ArchitectZoneSnapResult(
            point: poly[nextIdx],
            isSnapped: true,
            snapType: ArchitectZoneSnapType.zoneVertex,
            snapLabel: 'Обединяване (Merge)',
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
          bestLabel = '${zone.name} (Ъгъл)';
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
                  ? '${zone.name} (Ръб)'
                  : '${zone.name} (+${(gap * 100).round()} cm)';
              guides = [
                (targetA - unitAb * 1.5, targetB + unitAb * 1.5),
              ];
            }
          }
        }
      }
    }

    // -------------------------------------------------------------------------
    // 4. SNAP TO STRUCTURAL GRID AXES
    // -------------------------------------------------------------------------
    double snappedX = bestPoint.dx;
    double snappedY = bestPoint.dy;
    bool axisSnapX = false;
    bool axisSnapY = false;
    String? axisLabelX;
    String? axisLabelY;

    for (final axis in project.gridAxes) {
      final isVertical = (axis.end.dx - axis.start.dx).abs() < 1e-3;
      final isHorizontal = (axis.end.dy - axis.start.dy).abs() < 1e-3;

      if (isVertical) {
        // Vertical axis: check dx distance
        final axisX = axis.start.dx;
        final dX = (raw.dx - axisX).abs();
        if (dX <= tolerance) {
          snappedX = axisX;
          axisSnapX = true;
          axisLabelX = 'Ос ${axis.name}';
          guides.add((
            Offset(axisX, raw.dy - 3.0),
            Offset(axisX, raw.dy + 3.0),
          ));
        }
      } else if (isHorizontal) {
        // Horizontal axis: check dy distance
        final axisY = axis.start.dy;
        final dY = (raw.dy - axisY).abs();
        if (dY <= tolerance) {
          snappedY = axisY;
          axisSnapY = true;
          axisLabelY = 'Ос ${axis.name}';
          guides.add((
            Offset(raw.dx - 3.0, axisY),
            Offset(raw.dx + 3.0, axisY),
          ));
        }
      } else {
        // Angled axis: distance to segment
        if (axis.distanceToSegment(raw) <= tolerance) {
          final proj = axis.projectPoint(raw);
          snappedX = proj.dx;
          snappedY = proj.dy;
          bestPoint = proj;
          bestType = ArchitectZoneSnapType.gridAxis;
          bestLabel = 'Ос ${axis.name}';
          final dir = axis.direction;
          guides.add((
            proj - dir * 3.0,
            proj + dir * 3.0,
          ));
        }
      }
    }

    if (axisSnapX || axisSnapY) {
      bestPoint = Offset(snappedX, snappedY);
      bestType = ArchitectZoneSnapType.gridAxis;
      if (axisSnapX && axisSnapY) {
        bestLabel = '$axisLabelX × $axisLabelY';
      } else {
        bestLabel = axisLabelX ?? axisLabelY;
      }
    }

    final isSnapped = bestType != ArchitectZoneSnapType.none;
    return ArchitectZoneSnapResult(
      point: bestPoint,
      isSnapped: isSnapped,
      snapType: bestType,
      snapLabel: bestLabel,
      magneticGuides: guides,
      mergeCandidateIndex: mergeCandidate,
    );
  }
}
