import '../services/architect_slab_geometry.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../models/architect_project.dart';
import 'architect_wall_network.dart';
import 'architect_stair_mesh.dart';

/// Real-time 3D solid mesh builder for architectural projects.
class Architect3dBuilder {
  /// Builds a complete [Mesh3D] from an [ArchitectProject].
  static Mesh3D buildProjectMesh(
    ArchitectProject project, {
    bool previewGeometry = true,
  }) {
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

      // The same material solids are used by actual vertical stair sections.
      for (final stair in storey.stairs) {
        final solids = [
          ...ArchitectStairMesh.body(stair),
          ...ArchitectStairMesh.railings(
            stair,
            storey: storey,
            project: project,
          ),
        ];
        for (final solid in solids) {
          for (final triangle in solid.triangles) {
            Vector3 point(Vector3 p) =>
                Vector3(p.x, p.y, p.z + storey.elevation);
            allTris.add(
              Triangle3D(
                v0: point(triangle.v0),
                v1: point(triangle.v1),
                v2: point(triangle.v2),
                normal: triangle.normal,
                isDoubleSided: triangle.isDoubleSided,
                color: stair.design?.isDraft == true
                    ? const Color(0xFFD32F2F)
                    : triangle.color,
              ),
            );
          }
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
        allTris.addAll(
          ArchitectStairMesh.verticalPrism(
            beam.polygonCorners,
            storey.elevation + beam.baseOffset,
            storey.elevation + beam.baseOffset + beam.depth,
            StairSolidMaterial.concrete,
          ).triangles,
        );
      }

      // Add 3D floor tiles for functional zones
      for (final zone in storey.zones) {
        if (!previewGeometry) continue;
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

      for (final slab in storey.slabs) {
        allTris.addAll(ArchitectSlabGeometry.mesh(project, storey, slab));
      }

      for (final roof in storey.roofs) {
        allTris.addAll(_buildRoofMesh(storey, roof));
      }

      // Compatibility preview for storeys with no explicitly drawn slabs.
      // Never used by the section engine.
      // Add a base concrete slab plate under the storey
      if (previewGeometry && hasWalls && storey.slabs.isEmpty) {
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

    if (previewGeometry && allTris.isEmpty) {
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

  static List<Triangle3D> _buildRoofMesh(
    ArchitectStorey storey,
    ArchitectRoofPlane roof,
  ) {
    final pts = roof.points;
    if (pts.length < 3) return const [];
    final tris = <Triangle3D>[];

    final topMat = roof.assembly.layers.firstOrNull?.material;
    final topColor = switch (topMat) {
      ArchitectRoofMaterial.clayTiles => const Color(0xFFC85A32),
      ArchitectRoofMaterial.concreteTiles => const Color(0xFF78909C),
      ArchitectRoofMaterial.metalSeam => const Color(0xFF546E7A),
      ArchitectRoofMaterial.bitumenShingles => const Color(0xFF5D4037),
      ArchitectRoofMaterial.waterproofing => const Color(0xFF455A64),
      _ => const Color(0xFFC85A32),
    };
    const fasciaColor = Color(0xFFCFA16B);

    Vector3 topAt(Offset p) =>
        Vector3(p.dx, p.dy, storey.elevation + roof.topElevationAt(p));
    Vector3 botAt(Offset p) =>
        Vector3(p.dx, p.dy, storey.elevation + roof.undersideElevationAt(p));

    final v0T = topAt(pts[0]);
    final v0B = botAt(pts[0]);
    for (var i = 1; i < pts.length - 1; i++) {
      final v1T = topAt(pts[i]);
      final v2T = topAt(pts[i + 1]);
      tris.add(
        Triangle3D(
          v0: v0T,
          v1: v1T,
          v2: v2T,
          color: topColor,
          isDoubleSided: true,
        ),
      );

      final v1B = botAt(pts[i]);
      final v2B = botAt(pts[i + 1]);
      tris.add(
        Triangle3D(
          v0: v0B,
          v1: v2B,
          v2: v1B,
          color: fasciaColor,
          isDoubleSided: true,
        ),
      );
    }

    for (var i = 0; i < pts.length; i++) {
      final a = pts[i];
      final b = pts[(i + 1) % pts.length];
      final aT = topAt(a), bT = topAt(b);
      final aB = botAt(a), bB = botAt(b);
      tris.add(
        Triangle3D(
          v0: aB,
          v1: bB,
          v2: bT,
          color: fasciaColor,
          isDoubleSided: true,
        ),
      );
      tris.add(
        Triangle3D(
          v0: aB,
          v1: bT,
          v2: aT,
          color: fasciaColor,
          isDoubleSided: true,
        ),
      );
    }

    return tris;
  }
}
