import 'package:flutter/material.dart';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../models/cantilever_analysis_models.dart';
import '../models/seismic_analysis_models.dart';
import '../models/structural_element.dart';
import '../models/vertical_capacity_models.dart';

/// Builds a real-time hardware-accelerated 3D polygon mesh from the 2D BIM storeys,
/// columns, shear walls, and slabs.
class Structural3dMeshBuilder {
  const Structural3dMeshBuilder._();

  /// Converts a [StructuralProject] into a complete [Mesh3D].
  static Mesh3D buildProjectMesh(
    StructuralProject project, {
    List<CantileverZone> cantileverZones = const [],
    VerticalCapacityReport? verticalReport,
    SeismicAnalysisReport? seismicReport,
    int? highlightStoreyIndex,
    double cadUnitsPerMeter = 1.0,
  }) {
    final List<Triangle3D> triangles = [];
    final List<ElementMeshGroup> groups = [];

    for (int sIdx = 0; sIdx < project.storeys.length; sIdx++) {
      final storey = project.resolveCeilingStorey(project.storeys[sIdx]);
      final bool isCurrentStorey =
          highlightStoreyIndex == null || highlightStoreyIndex == sIdx;

      final double zBase = storey.elevation * cadUnitsPerMeter;
      final double zTop =
          (storey.elevation + storey.height - storey.floorFinishThickness) *
          cadUnitsPerMeter;
      final List<Triangle3D> storeyTriangles = [];

      // 0. Extrude Ground Foundations (Strip footings or Mat) at elevation 0.00 if no basement
      if (storey.elevation.abs() < 1e-4 && !project.hasBasement) {
        if (project.foundationType == FoundationType.stripFooting) {
          final strips = project.computeDefaultStripFoundations(
            storey,
            cadUnitsPerMeter: cadUnitsPerMeter,
          );
          final double zFoundTop = zBase;
          final double zFoundBottom = zBase - 0.60 * cadUnitsPerMeter;
          for (final strip in strips) {
            final fTris = _extrudePolygon(
              strip,
              zFoundBottom,
              zFoundTop,
              topColor: isCurrentStorey
                  ? const Color(0xFF607D8B)
                  : const Color(0x66607D8B),
              sideColor: isCurrentStorey
                  ? const Color(0xFF455A64)
                  : const Color(0x66455A64),
            );
            storeyTriangles.addAll(fTris);
          }
        } else {
          final mat = project.computeDefaultMatFoundation(
            storey,
            cadUnitsPerMeter: cadUnitsPerMeter,
          );
          if (mat != null) {
            final double zFoundTop = zBase;
            final double zFoundBottom =
                zBase - mat.thickness * cadUnitsPerMeter;
            final fTris = _extrudePolygon(
              mat.polygon,
              zFoundBottom,
              zFoundTop,
              topColor: isCurrentStorey
                  ? const Color(0xFF607D8B)
                  : const Color(0x66607D8B),
              sideColor: isCurrentStorey
                  ? const Color(0xFF455A64)
                  : const Color(0x66455A64),
            );
            storeyTriangles.addAll(fTris);
          }
        }
      }

      // 1. Extrude Columns (with EC2 vertical capacity & EC8 floating column color tinting)
      for (final col in storey.columns) {
        final vCheck = verticalReport?.getCheckForColumn(col.id);
        final bool isFloating =
            seismicReport?.isColumnFloating(col.id) ?? false;
        final Color topColor;
        final Color sideColor;

        if (isFloating) {
          // Magenta / Purple alert for floating (transfer) columns in 3D
          topColor = isCurrentStorey
              ? const Color(0xFFE040FB)
              : const Color(0x99E040FB);
          sideColor = isCurrentStorey
              ? const Color(0xFFAA00FF)
              : const Color(0x99AA00FF);
        } else if (vCheck != null &&
            vCheck.status == VerticalCapacityStatus.critical) {
          // Red glowing alert for overloaded columns
          topColor = isCurrentStorey
              ? const Color(0xFFFF1744)
              : const Color(0x99FF1744);
          sideColor = isCurrentStorey
              ? const Color(0xFFD50000)
              : const Color(0x99D50000);
        } else if (vCheck != null &&
            vCheck.status == VerticalCapacityStatus.warning) {
          // Amber/Orange alert for near-capacity columns
          topColor = isCurrentStorey
              ? const Color(0xFFFFD54F)
              : const Color(0x99FFD54F);
          sideColor = isCurrentStorey
              ? const Color(0xFFFF8F00)
              : const Color(0x99FF8F00);
        } else {
          // Standard blue BIM column styling
          topColor = isCurrentStorey
              ? const Color(0xFF1E88E5)
              : const Color(0x661E88E5);
          sideColor = isCurrentStorey
              ? const Color(0xFF1565C0)
              : const Color(0x661565C0);
        }

        final colTris = _extrudePolygon(
          col.polygonVertices,
          zBase,
          zTop,
          topColor: topColor,
          sideColor: sideColor,
        );
        storeyTriangles.addAll(colTris);
      }

      // 2. Extrude Shear Walls
      for (final wall in storey.shearWalls) {
        final wallTris = _extrudePolygon(
          wall.polygonVertices,
          zBase,
          zTop,
          topColor: isCurrentStorey
              ? const Color(0xFF546E7A)
              : const Color(0x66546E7A),
          sideColor: isCurrentStorey
              ? const Color(0xFF37474F)
              : const Color(0x6637474F),
        );
        storeyTriangles.addAll(wallTris);
      }

      // 2b. Extrude Beams (reinforced concrete beams underneath the slab at ceiling level)
      for (final beam in storey.beams) {
        final double beamZTop = zTop;
        final double beamZBottom = zTop - beam.depth * cadUnitsPerMeter;
        final beamTris = _extrudePolygon(
          beam.polygonVertices,
          beamZBottom,
          beamZTop,
          topColor: isCurrentStorey
              ? const Color(0xFFFB8C00)
              : const Color(0x66FB8C00),
          sideColor: isCurrentStorey
              ? const Color(0xFFE65100)
              : const Color(0x66E65100),
        );
        storeyTriangles.addAll(beamTris);
      }

      // 3. Extrude Slabs (plate with slab thickness at ceiling level / таван)
      const slab3dPalette = [
        Color(0xFF00B0FF), // Sky Blue
        Color(0xFF00E676), // Emerald Green
        Color(0xFFFFB300), // Warm Amber
        Color(0xFFAA00FF), // Vivid Purple
        Color(0xFFFF5252), // Coral Red
        Color(0xFF00E5FF), // Deep Cyan
        Color(0xFFFF9100), // Orange
        Color(0xFF3D5AFE), // Royal Indigo
      ];

      for (int slabIdx = 0; slabIdx < storey.slabs.length; slabIdx++) {
        final slab = storey.slabs[slabIdx];
        final Color baseColor = slab.colorValue != null
            ? Color(slab.colorValue!)
            : slab3dPalette[slabIdx % slab3dPalette.length];

        final double slabZTop =
            storey.structuralElevationFor(slab) * cadUnitsPerMeter;
        final double slabZBottom =
            storey.slabSoffitElevationFor(slab) * cadUnitsPerMeter;

        final slabTris = _extrudeSlab(
          slab,
          slabZBottom,
          slabZTop,
          topColor: isCurrentStorey
              ? baseColor
              : baseColor.withValues(alpha: 0.4),
          sideColor: isCurrentStorey
              ? baseColor.withValues(alpha: 0.8)
              : baseColor.withValues(alpha: 0.25),
        );
        storeyTriangles.addAll(slabTris);

        // Extrude vertical void walls for slab openings (shafts, stairwells)
        for (final op in slab.openings) {
          if (op.length >= 3) {
            final opSides = _extrudeSidesOnly(
              op,
              slabZBottom,
              slabZTop,
              sideColor: isCurrentStorey
                  ? const Color(0xFF78909C)
                  : const Color(0x6678909C),
            );
            storeyTriangles.addAll(opSides);
          }
        }
      }

      triangles.addAll(storeyTriangles);
      groups.add(
        ElementMeshGroup(
          id: storey.id,
          category: storey.name,
          triangles: storeyTriangles,
        ),
      );
    }

    return Mesh3D(name: project.title, triangles: triangles, groups: groups);
  }

  /// Split the planar plate into horizontal trapezoids between ring vertices.
  /// Even/odd crossings handle concave outlines and every opening without
  /// drawing cap triangles across voids. Winding of the rings is irrelevant.
  static List<Triangle3D> _extrudeSlab(
    StructuralSlab slab,
    double zMin,
    double zMax, {
    required Color topColor,
    required Color sideColor,
  }) {
    final rings = [slab.polygon, ...slab.openings];
    final tris = _extrudeSidesOnly(
      slab.polygon,
      zMin,
      zMax,
      sideColor: sideColor,
    );
    final ys = rings.expand((r) => r.map((p) => p.dy)).toSet().toList()..sort();
    for (var band = 0; band + 1 < ys.length; band++) {
      final low = ys[band], high = ys[band + 1];
      final mid = low + (high - low) / 2;
      final edges = <(Offset, Offset)>[];
      for (final ring in rings) {
        for (var i = 0; i < ring.length; i++) {
          final a = ring[i], b = ring[(i + 1) % ring.length];
          if ((a.dy < mid && b.dy > mid) || (b.dy < mid && a.dy > mid)) {
            edges.add((a, b));
          }
        }
      }
      double xAt((Offset, Offset) edge, double y) =>
          edge.$1.dx +
          (edge.$2.dx - edge.$1.dx) *
              (y - edge.$1.dy) /
              (edge.$2.dy - edge.$1.dy);
      edges.sort((a, b) => xAt(a, mid).compareTo(xAt(b, mid)));
      for (var i = 0; i + 1 < edges.length; i += 2) {
        final poly = [
          Offset(xAt(edges[i], low), low),
          Offset(xAt(edges[i + 1], low), low),
          Offset(xAt(edges[i + 1], high), high),
          Offset(xAt(edges[i], high), high),
        ];
        for (final z in [zMax, zMin]) {
          for (final vertices in [
            [poly[0], poly[1], poly[2]],
            [poly[0], poly[2], poly[3]],
          ]) {
            if (StructuralSlab.calculateArea(vertices) <= 0) continue;
            final v = vertices.map((p) => Vector3(p.dx, p.dy, z)).toList();
            tris.add(
              Triangle3D(
                v0: v[0],
                v1: z == zMax ? v[1] : v[2],
                v2: z == zMax ? v[2] : v[1],
                color: z == zMax ? topColor : sideColor,
                isDoubleSided: true,
              ),
            );
          }
        }
      }
    }
    return tris;
  }

  /// Extrudes a 2D polygon in XY plane vertically between [zMin] and [zMax].
  static List<Triangle3D> _extrudePolygon(
    List<Offset> poly,
    double zMin,
    double zMax, {
    required Color topColor,
    required Color sideColor,
  }) {
    final List<Triangle3D> tris = [];
    final int n = poly.length;
    if (n < 3) return tris;

    // 1. Vertical Side Faces (Quads split into 2 Triangles)
    for (int i = 0; i < n; i++) {
      final p1 = poly[i];
      final p2 = poly[(i + 1) % n];

      final v0 = Vector3(p1.dx, p1.dy, zMin);
      final v1 = Vector3(p2.dx, p2.dy, zMin);
      final v2 = Vector3(p2.dx, p2.dy, zMax);
      final v3 = Vector3(p1.dx, p1.dy, zMax);

      tris.add(
        Triangle3D(
          v0: v0,
          v1: v1,
          v2: v2,
          color: sideColor,
          isDoubleSided: true,
        ),
      );
      tris.add(
        Triangle3D(
          v0: v0,
          v1: v2,
          v2: v3,
          color: sideColor,
          isDoubleSided: true,
        ),
      );
    }

    // 2. Top and Bottom Caps (Simple Ear-clipping or Triangle Fan)
    final topVerts = poly.map((p) => Vector3(p.dx, p.dy, zMax)).toList();
    final bottomVerts = poly.map((p) => Vector3(p.dx, p.dy, zMin)).toList();

    final topTris = _triangulatePolygon(topVerts, topColor, isNormalUp: true);
    final bottomTris = _triangulatePolygon(
      bottomVerts,
      sideColor,
      isNormalUp: false,
    );

    tris.addAll(topTris);
    tris.addAll(bottomTris);

    return tris;
  }

  /// Simple fan triangulation for planar 2D polygons in 3D.
  static List<Triangle3D> _triangulatePolygon(
    List<Vector3> verts,
    Color color, {
    required bool isNormalUp,
  }) {
    final List<Triangle3D> tris = [];
    final int n = verts.length;
    if (n < 3) return tris;

    final vRoot = verts[0];
    for (int i = 1; i < n - 1; i++) {
      final vA = verts[i];
      final vB = verts[i + 1];

      if (isNormalUp) {
        tris.add(
          Triangle3D(
            v0: vRoot,
            v1: vA,
            v2: vB,
            color: color,
            isDoubleSided: true,
          ),
        );
      } else {
        tris.add(
          Triangle3D(
            v0: vRoot,
            v1: vB,
            v2: vA,
            color: color,
            isDoubleSided: true,
          ),
        );
      }
    }

    return tris;
  }

  /// Extrudes only the vertical side perimeter faces of a polygon in 3D (for slab openings).
  static List<Triangle3D> _extrudeSidesOnly(
    List<Offset> poly,
    double zMin,
    double zMax, {
    required Color sideColor,
  }) {
    final List<Triangle3D> tris = [];
    final int n = poly.length;
    if (n < 3) return tris;

    for (int i = 0; i < n; i++) {
      final p1 = poly[i];
      final p2 = poly[(i + 1) % n];

      final v0 = Vector3(p1.dx, p1.dy, zMin);
      final v1 = Vector3(p2.dx, p2.dy, zMin);
      final v2 = Vector3(p2.dx, p2.dy, zMax);
      final v3 = Vector3(p1.dx, p1.dy, zMax);

      tris.add(
        Triangle3D(
          v0: v0,
          v1: v1,
          v2: v2,
          color: sideColor,
          isDoubleSided: true,
        ),
      );
      tris.add(
        Triangle3D(
          v0: v0,
          v1: v2,
          v2: v3,
          color: sideColor,
          isDoubleSided: true,
        ),
      );
    }
    return tris;
  }
}
