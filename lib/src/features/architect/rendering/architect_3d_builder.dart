import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../models/architect_project.dart';
import 'architect_wall_network.dart';

/// Real-time 3D solid mesh builder for architectural projects.
class Architect3dBuilder {
  /// Builds a complete [Mesh3D] from an [ArchitectProject].
  static Mesh3D buildProjectMesh(ArchitectProject project) {
    final List<Triangle3D> allTris = [];

    // Collect all wall points to find bounding footprint for floor slabs
    double minX = double.infinity, maxX = -double.infinity;
    double minY = double.infinity, maxY = -double.infinity;
    bool hasWalls = false;

    for (final storey in project.storeys) {
      final walls = [
        for (final wall in storey.walls)
          wall.copyWith(height: wall.effectiveHeight(storey.height)),
      ];
      for (final wall in walls) {
        hasWalls = true;
        minX = math.min(minX, math.min(wall.startPoint.dx, wall.endPoint.dx));
        maxX = math.max(maxX, math.max(wall.startPoint.dx, wall.endPoint.dx));
        minY = math.min(minY, math.min(wall.startPoint.dy, wall.endPoint.dy));
        maxY = math.max(maxY, math.max(wall.startPoint.dy, wall.endPoint.dy));

        // Add 3D wall geometry with boolean door cutouts
        allTris.addAll(wall.build3D(storeyElevation: storey.elevation));
      }

      // Fill physical mitres at the same junctions used by the plan view.
      for (final (points, height) in ArchitectWallNetwork.junctions(
        walls,
        solidOnly: true,
      )) {
        const color = Color(0xFFECEFF1);
        Vector3 bottom(Offset p) => Vector3(p.dx, p.dy, storey.elevation);
        Vector3 top(Offset p) => Vector3(p.dx, p.dy, storey.elevation + height);
        for (var i = 0; i < points.length; i++) {
          final a = points[i], b = points[(i + 1) % points.length];
          allTris.add(
            Triangle3D(v0: bottom(a), v1: bottom(b), v2: top(b), color: color),
          );
          allTris.add(
            Triangle3D(v0: bottom(a), v1: top(b), v2: top(a), color: color),
          );
        }
        for (var i = 1; i < points.length - 1; i++) {
          allTris.add(
            Triangle3D(
              v0: top(points[0]),
              v1: top(points[i]),
              v2: top(points[i + 1]),
              color: color,
            ),
          );
          allTris.add(
            Triangle3D(
              v0: bottom(points[0]),
              v1: bottom(points[i + 1]),
              v2: bottom(points[i]),
              color: color,
            ),
          );
        }
      }

      // Add 3D columns
      for (final col in storey.columns) {
        allTris.addAll(
          col.build3D(
            storeyElevation: storey.elevation,
            storeyHeight: storey.height,
          ),
        );
      }

      // Add 3D beams
      for (final beam in storey.beams) {
        final corners = beam.polygonCorners;
        final zTop = storey.elevation + storey.height;
        final zBot = zTop - beam.depth;
        const beamColor = Color(0xFF90A4AE);
        final b1 = Vector3(corners[0].dx, corners[0].dy, zBot);
        final b2 = Vector3(corners[1].dx, corners[1].dy, zBot);
        final b3 = Vector3(corners[2].dx, corners[2].dy, zBot);
        final b4 = Vector3(corners[3].dx, corners[3].dy, zBot);
        final t1 = Vector3(corners[0].dx, corners[0].dy, zTop);
        final t2 = Vector3(corners[1].dx, corners[1].dy, zTop);
        final t3 = Vector3(corners[2].dx, corners[2].dy, zTop);
        final t4 = Vector3(corners[3].dx, corners[3].dy, zTop);
        // Bottom & Sides
        allTris.add(Triangle3D(v0: b1, v1: b2, v2: b3, color: beamColor));
        allTris.add(Triangle3D(v0: b1, v1: b3, v2: b4, color: beamColor));
        allTris.add(Triangle3D(v0: b1, v1: t1, v2: t2, color: beamColor));
        allTris.add(Triangle3D(v0: b1, v1: t2, v2: b2, color: beamColor));
        allTris.add(Triangle3D(v0: b3, v1: t3, v2: t4, color: beamColor));
        allTris.add(Triangle3D(v0: b3, v1: t4, v2: b4, color: beamColor));
      }

      // Add 3D floor tiles for functional zones
      for (final zone in storey.zones) {
        if (zone.polygon.length >= 3) {
          final c = zone.centroid;
          final z = storey.elevation + 0.005; // slightly above floor slab
          final c3D = Vector3(c.dx, c.dy, z);
          final zoneColor = zone.color.withValues(alpha: 0.85);

          for (int i = 0; i < zone.polygon.length; i++) {
            final p1 = zone.polygon[i];
            final p2 = zone.polygon[(i + 1) % zone.polygon.length];
            final v1 = Vector3(p1.dx, p1.dy, z);
            final v2 = Vector3(p2.dx, p2.dy, z);
            allTris.add(Triangle3D(v0: c3D, v1: v1, v2: v2, color: zoneColor));
          }
        }
      }

      // Add a base concrete slab plate under the storey
      if (hasWalls) {
        const margin = 1.0; // 1m slab overhang around building
        final sMinX = minX - margin;
        final sMaxX = maxX + margin;
        final sMinY = minY - margin;
        final sMaxY = maxY + margin;
        final zTop = storey.elevation;
        final zBottom = zTop - 0.20; // 20 cm slab thickness

        const slabColor = Color(0xFFB0BEC5);

        final p1 = Vector3(sMinX, sMinY, zBottom);
        final p2 = Vector3(sMaxX, sMinY, zBottom);
        final p3 = Vector3(sMaxX, sMaxY, zBottom);
        final p4 = Vector3(sMinX, sMaxY, zBottom);

        final p1T = Vector3(sMinX, sMinY, zTop);
        final p2T = Vector3(sMaxX, sMinY, zTop);
        final p3T = Vector3(sMaxX, sMaxY, zTop);
        final p4T = Vector3(sMinX, sMaxY, zTop);

        // Top surface
        allTris.add(Triangle3D(v0: p1T, v1: p2T, v2: p3T, color: slabColor));
        allTris.add(Triangle3D(v0: p1T, v1: p3T, v2: p4T, color: slabColor));

        // Bottom surface
        allTris.add(Triangle3D(v0: p1, v1: p3, v2: p2, color: slabColor));
        allTris.add(Triangle3D(v0: p1, v1: p4, v2: p3, color: slabColor));

        // Sides
        allTris.add(Triangle3D(v0: p1, v1: p2, v2: p2T, color: slabColor));
        allTris.add(Triangle3D(v0: p1, v1: p2T, v2: p1T, color: slabColor));

        allTris.add(Triangle3D(v0: p2, v1: p3, v2: p3T, color: slabColor));
        allTris.add(Triangle3D(v0: p2, v1: p3T, v2: p2T, color: slabColor));

        allTris.add(Triangle3D(v0: p3, v1: p4, v2: p4T, color: slabColor));
        allTris.add(Triangle3D(v0: p3, v1: p4T, v2: p3T, color: slabColor));

        allTris.add(Triangle3D(v0: p4, v1: p1, v2: p1T, color: slabColor));
        allTris.add(Triangle3D(v0: p4, v1: p1T, v2: p4T, color: slabColor));
      }
    }

    if (allTris.isEmpty) {
      // Fallback ground grid plate if no walls exist yet
      const fallbackColor = Color(0xFFCFD8DC);
      const s = 10.0;
      final v1 = Vector3(-s, -s, 0);
      final v2 = Vector3(s, -s, 0);
      final v3 = Vector3(s, s, 0);
      final v4 = Vector3(-s, s, 0);
      allTris.add(Triangle3D(v0: v1, v1: v2, v2: v3, color: fallbackColor));
      allTris.add(Triangle3D(v0: v1, v1: v3, v2: v4, color: fallbackColor));
    }

    return Mesh3D(name: project.name, triangles: allTris);
  }
}
