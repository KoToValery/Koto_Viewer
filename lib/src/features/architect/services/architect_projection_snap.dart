import 'dart:ui';
import '../models/architect_project.dart';
import '../rendering/architect_path_solid.dart';
import 'architect_projection_editing.dart';

class ArchitectProjectionSnapResult {
  final Offset delta;
  final Offset? contact;
  const ArchitectProjectionSnapResult(this.delta, [this.contact]);
}

/// Frozen at drag start: wall tops that follow a roof must not chase its snap.
/// Uses real contour edges rather than the bounding box of a pitched roof.
class ArchitectProjectionSnap {
  final _moving = <(Offset, Offset)>[];
  final _targets = <(Offset, Offset)>[];
  final _roofMoving = <(Offset, Offset)>[];
  final _roofTargets = <(Offset, Offset)>[];
  final Set<String> movingIds;

  ArchitectProjectionSnap(
    ArchitectProject project,
    Map<String, Path> paths,
    String id, {
    Map<String, Path> roofProfiles = const {},
  }) : movingIds = {id} {
    final selected = ArchitectProjectionEditing.find(project, id);
    final roof = selected?.storey.roofs.where((r) => r.id == id).firstOrNull;
    if (roof?.roofGroupId != null) {
      movingIds.addAll(
        selected!.storey.roofs
            .where((r) => r.roofGroupId == roof!.roofGroupId)
            .map((r) => r.id),
      );
    }
    void addEdges(Path path, List<(Offset, Offset)> edges) {
      for (final loop in ArchitectPathSolid.contours(path, tolerance: .001)) {
        for (var i = 0; i < loop.length; i++) {
          edges.add((loop[i], loop[(i + 1) % loop.length]));
        }
      }
    }

    for (final entry in roofProfiles.entries) {
      if (!paths.containsKey(entry.key)) continue;
      addEdges(
        entry.value,
        movingIds.contains(entry.key) ? _roofMoving : _roofTargets,
      );
    }
    for (final entry in paths.entries) {
      final edges = movingIds.contains(entry.key) ? _moving : _targets;
      // Tile profiles, battens and flashing must not attract a ridge away
      // from the matching main roof surfaces.
      if (movingIds.contains(entry.key) ||
          !roofProfiles.containsKey(entry.key)) {
        addEdges(entry.value, edges);
      }
      // A supporting wall can already extend to the selected roof. Retain its
      // nominal cap as a stable reference when manually lowering that roof.
      final ref = ArchitectProjectionEditing.find(project, entry.key);
      if (ref?.kind == ArchitectProjectionKind.wall && edges == _targets) {
        final wall = ref!.storey.walls.firstWhere((w) => w.id == ref.id);
        final z =
            ref.storey.elevation +
            wall.baseOffset +
            wall.effectiveHeight(ref.storey.height);
        final bounds = entry.value.getBounds();
        _targets.add((Offset(bounds.left, z), Offset(bounds.right, z)));
      }
    }
  }

  ArchitectProjectionSnapResult resolve(
    Offset raw,
    double tolerance, {
    required bool horizontal,
  }) {
    var best = tolerance;
    var result = ArchitectProjectionSnapResult(raw);
    void candidate(Offset correction, Offset contact) {
      final distance = correction.distance;
      if (distance > best) return;
      best = distance;
      result = ArchitectProjectionSnapResult(raw + correction, contact);
    }

    // Translate a point onto an actual edge. In a section only Z may change;
    // the plan footprint and the roof slope stay fixed.
    Offset? correctionToEdge(Offset p, Offset a, Offset b) {
      final edge = b - a;
      if (horizontal) {
        final length2 = edge.dx * edge.dx + edge.dy * edge.dy;
        final t = length2 < 1e-12
            ? 0.0
            : (((p - a).dx * edge.dx + (p - a).dy * edge.dy) / length2).clamp(
                0.0,
                1.0,
              );
        return a + edge * t - p;
      }
      if (edge.dx.abs() < 1e-8) {
        if ((p.dx - a.dx).abs() > 1e-5) return null;
        // Sliding along a vertical edge does not constrain the roof's height.
        // Only its endpoints provide a useful Z reference.
        final z = (p.dy - a.dy).abs() < (p.dy - b.dy).abs() ? a.dy : b.dy;
        return Offset(0, z - p.dy);
      }
      final t = (p.dx - a.dx) / edge.dx;
      if (t < -1e-6 || t > 1 + 1e-6) return null;
      return Offset(0, a.dy + edge.dy * t - p.dy);
    }

    for (final (moving, targets) in [
      (_roofMoving, _roofTargets),
      (_moving, _targets),
    ]) {
      for (final (a, b) in moving) {
        final movedA = a + raw, movedB = b + raw;
        for (final (c, d) in targets) {
          if (!Rect.fromPoints(
            movedA,
            movedB,
          ).inflate(tolerance).overlaps(Rect.fromPoints(c, d).inflate(1e-6))) {
            continue;
          }
          for (final p in [movedA, movedB]) {
            final correction = correctionToEdge(p, c, d);
            if (correction != null) candidate(correction, p + correction);
          }
          for (final p in [c, d]) {
            final reverse = correctionToEdge(p, movedA, movedB);
            if (reverse != null) candidate(-reverse, p);
          }
        }
      }
      if (result.contact != null) return result;
    }
    return result;
  }
}
