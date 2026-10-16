// === SECTION: ARCHITECTURAL UPPER OVERHANG DETECTOR ===
import 'dart:math' as math;
import 'dart:ui';
import '../models/architect_overhang.dart';
import '../models/architect_project.dart';
import '../models/architect_wall.dart';
import '../models/architect_wall_type.dart';
import '../models/architect_zone.dart';
import '../rendering/architect_wall_network.dart';

/// Analyzes architectural project storeys to identify cantilevered erkers (еркери)
/// and balconies (балкони) extending from an upper storey over the active floor.
class ArchitectOverhangDetector {
  ArchitectOverhangDetector._();

  static final _cache = Expando<List<ArchitectOverhang>>();

  /// Returns cached or detected overhangs for the given project's active storey.
  static List<ArchitectOverhang> forProject(ArchitectProject project) =>
      _cache[project] ??= detectOverhangs(project);

  /// Clears detector cache if needed.
  static void clearCache() {
    // Expando naturally clears with garbage collection or project replacement.
  }

  /// Finds the storey immediately above the active storey in elevation.
  static ArchitectStorey? findUpperStorey(ArchitectProject project) {
    final activeElevation = project.activeStorey.elevation;
    final sorted = [...project.storeys]
      ..sort((a, b) => a.elevation == b.elevation
          ? a.id.compareTo(b.id)
          : a.elevation.compareTo(b.elevation));

    for (final s in sorted) {
      if (s.elevation > activeElevation + 1e-4) {
        return s;
      }
    }
    return null;
  }

  /// Scans the project and detects all upper floor erkers and balconies
  /// that project over the active storey.
  static List<ArchitectOverhang> detectOverhangs(ArchitectProject project) {
    final activeStorey = project.activeStorey;
    final upperStorey = findUpperStorey(project);
    if (upperStorey == null) return const [];

    final overhangs = <ArchitectOverhang>[];

    // 1. Build the complete 2D footprint of the active storey (interior rooms + walls + slabs)
    final lowerFootprint = buildStoreyFootprint(activeStorey);

    // 2. Extract upper floor balconies (terraces, parapet-enclosed areas, balcony slabs)
    final detectedBalconies = _detectBalconies(
      upperStorey: upperStorey,
      lowerFootprint: lowerFootprint,
      lowerWalls: activeStorey.walls,
      wallTypes: project.wallTypes,
    );
    overhangs.addAll(detectedBalconies);

    // 3. Extract upper floor erkers (cantilevered rooms, enclosed zones, overhang slabs)
    final detectedErkers = _detectErkers(
      upperStorey: upperStorey,
      lowerFootprint: lowerFootprint,
      lowerWalls: activeStorey.walls,
      existingOverhangs: overhangs,
      wallTypes: project.wallTypes,
    );
    overhangs.addAll(detectedErkers);

    return overhangs;
  }

  /// Builds a continuous 2D [Path] representing the entire footprint of a storey
  /// (slabs, zones, enclosed wall rooms, and wall bodies).
  static Path buildStoreyFootprint(ArchitectStorey storey) {
    var footprint = Path();

    // Slabs
    for (final slab in storey.slabs) {
      if (slab.polygon.length >= 3) {
        footprint = Path.combine(
          PathOperation.union,
          footprint,
          Path()..addPolygon(slab.polygon, true),
        );
      }
    }

    // Zones
    for (final zone in storey.zones) {
      if (zone.polygon.length >= 3) {
        footprint = Path.combine(
          PathOperation.union,
          footprint,
          Path()..addPolygon(zone.polygon, true),
        );
      }
    }

    // Wall closed room loops
    final wallLoops = _findWallLoops(storey.walls);
    for (final loop in wallLoops) {
      if (loop.length >= 3) {
        footprint = Path.combine(
          PathOperation.union,
          footprint,
          Path()..addPolygon(loop, true),
        );
      }
    }

    // Wall solid bodies
    if (storey.walls.isNotEmpty) {
      final wallBodies = ArchitectWallNetwork.body(storey.walls);
      footprint = Path.combine(PathOperation.union, footprint, wallBodies);
    }

    return footprint;
  }

  /// Detects upper storey balconies (terrace zones, balcony slabs, parapet enclosures).
  static List<ArchitectOverhang> _detectBalconies({
    required ArchitectStorey upperStorey,
    required Path lowerFootprint,
    required List<ArchitectWall> lowerWalls,
    required List<ArchitectWallType> wallTypes,
  }) {
    final balconies = <ArchitectOverhang>[];

    // A. Upper Terrace Zones
    for (final zone in upperStorey.zones) {
      if (zone.polygon.length < 3) continue;
      final isTerrace = zone.category == ArchitectZoneCategory.terrace ||
          _isBalconyKeyword(zone.name);

      if (isTerrace) {
        final depth = _calculateOverhangDepth(zone.polygon, lowerWalls);
        balconies.add(ArchitectOverhang(
          id: 'balcony_${upperStorey.id}_zone_${zone.id}',
          kind: ArchitectOverhangKind.balcony,
          polygon: zone.polygon,
          path: Path()..addPolygon(zone.polygon, true),
          customLabel: zone.name.isNotEmpty ? zone.name : null,
          area: zone.area,
          overhangDepth: depth,
          sourceStoreyId: upperStorey.id,
          sourceStoreyName: upperStorey.name,
          sourceStoreyElevation: upperStorey.elevation,
        ));
      }
    }

    // B. Upper Balcony Slabs (labeled as balcony or terrace)
    for (final slab in upperStorey.slabs) {
      if (slab.polygon.length < 3) continue;
      if (_isBalconyKeyword(slab.label)) {
        // Skip if already covered by an existing zone balcony
        if (balconies.any((b) => (b.centroid - slab.centroid).distance < 0.50)) {
          continue;
        }
        final depth = _calculateOverhangDepth(slab.polygon, lowerWalls);
        balconies.add(ArchitectOverhang(
          id: 'balcony_${upperStorey.id}_slab_${slab.id}',
          kind: ArchitectOverhangKind.balcony,
          polygon: slab.polygon,
          path: Path()..addPolygon(slab.polygon, true),
          customLabel: slab.label,
          area: slab.area,
          overhangDepth: depth,
          sourceStoreyId: upperStorey.id,
          sourceStoreyName: upperStorey.name,
          sourceStoreyElevation: upperStorey.elevation,
        ));
      }
    }

    // C. Upper Parapet Wall loops
    final catalog = {
      for (final type in ArchitectWallType.standardCatalog()) type.id: type,
      for (final type in wallTypes) type.id: type,
    };
    final parapetWalls = upperStorey.walls.where((w) {
      final type = catalog[w.wallTypeId];
      return type?.usage == WallUsage.parapet ||
          w.height <= 1.50 ||
          (w.wallTypeId?.toLowerCase().contains('parapet') ?? false);
    }).toList();

    if (parapetWalls.length >= 3) {
      final parapetLoops = _findWallLoops(parapetWalls);
      for (var i = 0; i < parapetLoops.length; i++) {
        final loop = parapetLoops[i];
        final area = _polygonArea(loop);
        if (area < 0.20) continue;
        final centroid = _polygonCentroid(loop);
        if (balconies.any((b) => (b.centroid - centroid).distance < 0.50)) {
          continue;
        }
        final depth = _calculateOverhangDepth(loop, lowerWalls);
        balconies.add(ArchitectOverhang(
          id: 'balcony_${upperStorey.id}_parapet_$i',
          kind: ArchitectOverhangKind.balcony,
          polygon: loop,
          path: Path()..addPolygon(loop, true),
          area: area,
          overhangDepth: depth,
          sourceStoreyId: upperStorey.id,
          sourceStoreyName: upperStorey.name,
          sourceStoreyElevation: upperStorey.elevation,
        ));
      }
    }

    return balconies;
  }

  /// Detects upper storey erkers (enclosed heated rooms projecting outward).
  static List<ArchitectOverhang> _detectErkers({
    required ArchitectStorey upperStorey,
    required Path lowerFootprint,
    required List<ArchitectWall> lowerWalls,
    required List<ArchitectOverhang> existingOverhangs,
    required List<ArchitectWallType> wallTypes,
  }) {
    final erkers = <ArchitectOverhang>[];
    final footprintMetrics = lowerFootprint.computeMetrics();
    final hasLowerFootprint = footprintMetrics.isNotEmpty;

    // A. Upper Non-Terrace Zones projecting beyond lower footprint
    for (final zone in upperStorey.zones) {
      if (zone.polygon.length < 3) continue;
      if (zone.category == ArchitectZoneCategory.terrace ||
          _isBalconyKeyword(zone.name)) {
        continue;
      }

      final zonePath = Path()..addPolygon(zone.polygon, true);
      if (!hasLowerFootprint) continue;

      final diff = Path.combine(PathOperation.difference, zonePath, lowerFootprint);
      for (final metric in diff.computeMetrics()) {
        if (metric.length < 0.50) continue; // Skip noise perimeter < 50 cm
        final poly = _extractPolygonFromMetric(metric);
        final area = _polygonArea(poly);
        if (area < 0.15) continue; // Min 0.15 m²

        final depth = _calculateOverhangDepth(poly, lowerWalls);
        if (depth < 0.15) continue; // Min 15 cm projection

        // Check if overlaps an existing balcony
        final center = _polygonCentroid(poly);
        if (existingOverhangs.any((o) => (o.centroid - center).distance < 0.40)) {
          continue;
        }

        erkers.add(ArchitectOverhang(
          id: 'erker_${upperStorey.id}_zone_${zone.id}_${erkers.length}',
          kind: ArchitectOverhangKind.erker,
          polygon: poly,
          path: metric.extractPath(0, metric.length),
          customLabel: zone.name.isNotEmpty ? zone.name : null,
          area: area,
          overhangDepth: depth,
          sourceStoreyId: upperStorey.id,
          sourceStoreyName: upperStorey.name,
          sourceStoreyElevation: upperStorey.elevation,
        ));
      }
    }

    // B. Upper Floor Slabs projecting beyond lower footprint
    for (final slab in upperStorey.slabs) {
      if (slab.polygon.length < 3) continue;
      if (_isBalconyKeyword(slab.label)) continue;

      final slabPath = Path()..addPolygon(slab.polygon, true);
      if (!hasLowerFootprint) continue;

      final diff = Path.combine(PathOperation.difference, slabPath, lowerFootprint);
      for (final metric in diff.computeMetrics()) {
        if (metric.length < 0.50) continue;
        final poly = _extractPolygonFromMetric(metric);
        final area = _polygonArea(poly);
        if (area < 0.15) continue;

        final depth = _calculateOverhangDepth(poly, lowerWalls);
        if (depth < 0.15) continue;

        final center = _polygonCentroid(poly);
        if ([...existingOverhangs, ...erkers]
            .any((o) => (o.centroid - center).distance < 0.40)) {
          continue;
        }

        erkers.add(ArchitectOverhang(
          id: 'erker_${upperStorey.id}_slab_${slab.id}_${erkers.length}',
          kind: ArchitectOverhangKind.erker,
          polygon: poly,
          path: metric.extractPath(0, metric.length),
          customLabel: _isErkerKeyword(slab.label) ? slab.label : null,
          area: area,
          overhangDepth: depth,
          sourceStoreyId: upperStorey.id,
          sourceStoreyName: upperStorey.name,
          sourceStoreyElevation: upperStorey.elevation,
        ));
      }
    }

    // C. Upper Floor Exterior Wall Loops (when no zones or slabs present)
    if (upperStorey.zones.isEmpty && upperStorey.slabs.isEmpty) {
      final upperLoops = _findWallLoops(upperStorey.walls);
      for (var i = 0; i < upperLoops.length; i++) {
        final loop = upperLoops[i];
        if (loop.length < 3) continue;

        final loopPath = Path()..addPolygon(loop, true);
        if (!hasLowerFootprint) continue;

        final diff = Path.combine(PathOperation.difference, loopPath, lowerFootprint);
        for (final metric in diff.computeMetrics()) {
          if (metric.length < 0.50) continue;
          final poly = _extractPolygonFromMetric(metric);
          final area = _polygonArea(poly);
          if (area < 0.15) continue;

          final depth = _calculateOverhangDepth(poly, lowerWalls);
          if (depth < 0.15) continue;

          final center = _polygonCentroid(poly);
          if ([...existingOverhangs, ...erkers]
              .any((o) => (o.centroid - center).distance < 0.40)) {
            continue;
          }

          erkers.add(ArchitectOverhang(
            id: 'erker_${upperStorey.id}_wall_loop_${i}_${erkers.length}',
            kind: ArchitectOverhangKind.erker,
            polygon: poly,
            path: metric.extractPath(0, metric.length),
            area: area,
            overhangDepth: depth,
            sourceStoreyId: upperStorey.id,
            sourceStoreyName: upperStorey.name,
            sourceStoreyElevation: upperStorey.elevation,
          ));
        }
      }
    }

    return erkers;
  }

  // ===========================================================================
  // GEOMETRIC HELPERS
  // ===========================================================================

  static bool _isBalconyKeyword(String? text) {
    if (text == null) return false;
    final lower = text.toLowerCase();
    return lower.contains('балкон') ||
        lower.contains('balcon') ||
        lower.contains('тераса') ||
        lower.contains('terrace') ||
        lower.contains('лоджия') ||
        lower.contains('loggia');
  }

  static bool _isErkerKeyword(String? text) {
    if (text == null) return false;
    final lower = text.toLowerCase();
    return lower.contains('еркер') ||
        lower.contains('erker') ||
        lower.contains('bay') ||
        lower.contains('oriel');
  }

  static double _calculateOverhangDepth(
    List<Offset> poly,
    List<ArchitectWall> lowerWalls,
  ) {
    if (poly.isEmpty) return 0.0;
    if (lowerWalls.isEmpty) {
      // If no lower walls, find max span from centroid
      final center = _polygonCentroid(poly);
      double maxD = 0.0;
      for (final p in poly) {
        maxD = math.max(maxD, (p - center).distance);
      }
      return maxD;
    }

    double maxOverhang = 0.0;
    for (final p in poly) {
      double minDist = double.infinity;
      for (final wall in lowerWalls) {
        final d = _pointToSegmentDistance(p, wall.startPoint, wall.endPoint);
        if (d < minDist) minDist = d;
      }
      if (minDist.isFinite && minDist > maxOverhang) {
        maxOverhang = minDist;
      }
    }
    return maxOverhang;
  }

  static double _pointToSegmentDistance(Offset p, Offset a, Offset b) {
    final abX = b.dx - a.dx;
    final abY = b.dy - a.dy;
    final lenSq = abX * abX + abY * abY;
    if (lenSq < 1e-9) return (p - a).distance;
    final t = (((p.dx - a.dx) * abX + (p.dy - a.dy) * abY) / lenSq)
        .clamp(0.0, 1.0);
    final proj = Offset(a.dx + t * abX, a.dy + t * abY);
    return (p - proj).distance;
  }

  static List<Offset> _extractPolygonFromMetric(PathMetric metric) {
    final points = <Offset>[];
    final length = metric.length;
    if (length <= 0) return points;

    const step = 0.12; // Sample every 12 cm
    final numSteps = math.max((length / step).ceil(), 12);
    final actualStep = length / numSteps;

    for (var i = 0; i < numSteps; i++) {
      final tangent = metric.getTangentForOffset(i * actualStep);
      if (tangent != null) {
        if (points.isEmpty ||
            (tangent.position - points.last).distance > 0.03) {
          points.add(tangent.position);
        }
      }
    }
    return _simplifyCollinear(points);
  }

  static List<Offset> _simplifyCollinear(
    List<Offset> points, {
    double epsilon = 0.015,
  }) {
    if (points.length < 3) return points;
    final result = <Offset>[points.first];
    for (var i = 1; i < points.length; i++) {
      final prev = result.last;
      final curr = points[i];
      final next = points[(i + 1) % points.length];

      final v1 = curr - prev;
      final v2 = next - curr;
      final len1 = v1.distance;
      final len2 = v2.distance;

      if (len1 < 0.01) continue;
      if (len2 < 0.01) {
        result.add(curr);
        continue;
      }

      final cross = (v1.dx * v2.dy - v1.dy * v2.dx).abs() / (len1 * len2);
      if (cross > epsilon) {
        result.add(curr);
      }
    }
    return result;
  }

  static double _polygonArea(List<Offset> poly) => _signedArea(poly).abs();

  static double _signedArea(List<Offset> poly) {
    if (poly.length < 3) return 0.0;
    double sum = 0.0;
    for (var i = 0; i < poly.length; i++) {
      final p1 = poly[i];
      final p2 = poly[(i + 1) % poly.length];
      sum += (p1.dx * p2.dy - p2.dx * p1.dy);
    }
    return sum / 2.0;
  }

  static Offset _polygonCentroid(List<Offset> poly) {
    if (poly.isEmpty) return Offset.zero;
    double cx = 0, cy = 0;
    for (final p in poly) {
      cx += p.dx;
      cy += p.dy;
    }
    return Offset(cx / poly.length, cy / poly.length);
  }

  /// Discovers closed planar loops/rooms from connected wall reference lines.
  static List<List<Offset>> _findWallLoops(List<ArchitectWall> walls) {
    if (walls.length < 3) return const [];

    final nodes = <Offset>[];
    int getNode(Offset p) {
      for (var i = 0; i < nodes.length; i++) {
        if ((nodes[i] - p).distance <= 0.20) return i;
      }
      nodes.add(p);
      return nodes.length - 1;
    }

    final adj = <int, List<int>>{};

    for (final wall in walls) {
      if (wall.length < 0.10) continue;
      final u = getNode(wall.startPoint);
      final v = getNode(wall.endPoint);
      if (u == v) continue;

      adj.putIfAbsent(u, () => <int>[]).add(v);
      adj.putIfAbsent(v, () => <int>[]).add(u);
    }

    // Sort outgoing neighbors counter-clockwise
    for (var u = 0; u < nodes.length; u++) {
      final outgoing = adj[u];
      if (outgoing == null) continue;
      final pU = nodes[u];
      outgoing.sort((a, b) {
        final angleA = math.atan2(nodes[a].dy - pU.dy, nodes[a].dx - pU.dx);
        final angleB = math.atan2(nodes[b].dy - pU.dy, nodes[b].dx - pU.dx);
        return angleA.compareTo(angleB);
      });
    }

    final loops = <List<Offset>>[];
    final visited = <String>{};

    for (var startU = 0; startU < nodes.length; startU++) {
      final neighbors = adj[startU];
      if (neighbors == null) continue;

      for (final startV in neighbors) {
        final edgeKey = '$startU->$startV';
        if (visited.contains(edgeKey)) continue;

        final cycle = <int>[startU];
        var currU = startU;
        var currV = startV;
        var valid = true;

        while (true) {
          visited.add('$currU->$currV');
          cycle.add(currV);
          if (currV == startU) break;
          if (cycle.length > 40) {
            valid = false;
            break;
          }

          final pV = nodes[currV];
          final inAngle =
              math.atan2(nodes[currU].dy - pV.dy, nodes[currU].dx - pV.dx);

          final outgoing = adj[currV];
          if (outgoing == null || outgoing.isEmpty) {
            valid = false;
            break;
          }

          int? bestW;
          var minAngle = double.infinity;
          for (final w in outgoing) {
            if (w == currU && outgoing.length > 1) continue;
            final outAngle =
                math.atan2(nodes[w].dy - pV.dy, nodes[w].dx - pV.dx);
            var diff = outAngle - inAngle;
            while (diff <= 0) {
              diff += 2 * math.pi;
            }
            while (diff > 2 * math.pi) {
              diff -= 2 * math.pi;
            }
            if (diff < minAngle) {
              minAngle = diff;
              bestW = w;
            }
          }

          if (bestW == null) {
            valid = false;
            break;
          }

          currU = currV;
          currV = bestW;
        }

        if (valid && cycle.length >= 4) {
          final poly = [
            for (var i = 0; i < cycle.length - 1; i++) nodes[cycle[i]]
          ];
          final area = _signedArea(poly);
          // Positive area = counter-clockwise interior room face
          if (area > 0.50 && area < 50000.0) {
            loops.add(poly);
          }
        }
      }
    }

    return loops;
  }
}
