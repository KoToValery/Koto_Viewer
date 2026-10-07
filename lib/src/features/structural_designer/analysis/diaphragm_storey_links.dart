import '../models/structural_element.dart';
import 'slab_topology_analyzer.dart';
import 'slab_contact_geometry.dart';

enum RegionLinkKind { oneToOne, branching, unmatched, unknown }

/// Geometric overlap across adjacent elevations, not a load-path proof.
class DiaphragmStoreyLink {
  final int upperRegion;
  final List<int> lowerRegions;
  final String lowerStoreyName;
  final double? coverage;
  final RegionLinkKind kind;
  const DiaphragmStoreyLink(
    this.upperRegion,
    this.lowerRegions,
    this.lowerStoreyName,
    this.coverage,
    this.kind,
  );

  static List<DiaphragmStoreyLink> between(
    StoreyLevel upper,
    StoreyLevel lower,
    double scale,
  ) {
    final u = SlabTopologyAnalyzer.analyze(upper.slabs, scale);
    final l = SlabTopologyAnalyzer.analyze(lower.slabs, scale);
    if (u.regions.isEmpty) return const [];
    List<DiaphragmStoreyLink> unknown() => [
      for (var i = 0; i < u.regions.length; i++)
        DiaphragmStoreyLink(
          i,
          const [],
          lower.name,
          null,
          RegionLinkKind.unknown,
        ),
    ];
    if (l.regions.isEmpty) return unknown();
    final overlaps = [
      for (final _ in u.regions) List<double>.filled(l.regions.length, 0),
    ];
    final areas = List<double>.filled(u.regions.length, 0);
    for (var i = 0; i < u.regions.length; i++) {
      for (final aIndex in u.regions[i]) {
        final a = upper.slabs[aIndex];
        final own = SlabContactGeometry.measure(a.polygon, [a], scale);
        if (own == null) return unknown();
        areas[i] += own.areaM2;
        for (var j = 0; j < l.regions.length; j++) {
          final floors = [for (final b in l.regions[j]) lower.slabs[b]];
          final full = SlabContactGeometry.measure(a.polygon, floors, scale);
          if (full == null) return unknown();
          var area = full.areaM2;
          for (final hole in a.openings) {
            final cut = SlabContactGeometry.measure(hole, floors, scale);
            if (cut == null) return unknown();
            area -= cut.areaM2;
          }
          overlaps[i][j] += area.clamp(0.0, double.infinity);
        }
      }
    }
    return [
      for (var i = 0; i < u.regions.length; i++)
        (() {
          final matches = [
            for (var j = 0; j < l.regions.length; j++)
              if (overlaps[i][j] > 1e-10) j,
          ];
          final branching =
              matches.length > 1 ||
              matches.any(
                (j) => overlaps.where((row) => row[j] > 1e-10).length > 1,
              );
          return DiaphragmStoreyLink(
            i,
            matches,
            lower.name,
            areas[i] > 1e-10
                ? (overlaps[i].fold<double>(0, (a, b) => a + b) / areas[i])
                      .clamp(0.0, 1.0)
                : null,
            matches.isEmpty
                ? RegionLinkKind.unmatched
                : branching
                ? RegionLinkKind.branching
                : RegionLinkKind.oneToOne,
          );
        })(),
    ];
  }
}
