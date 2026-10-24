// === SECTION: ARCHITECTURAL FLOOR DRAIN 3D MESH BUILDER ===
// Table of Contents:
// 1. MATERIAL & HELPERS
// 2. SLOPING FLOOR FINISH MESH
// 3. 3D DRAIN GRATE SOLID (Round & Linear)

import 'dart:math' as math;
import 'dart:ui';
import '../../cad_3d/models/mesh_3d.dart';
import '../models/architect_floor_drain.dart';
import '../models/architect_project.dart';
import '../services/architect_floor_drain_geometry.dart';

class ArchitectFloorDrainMesh {
  ArchitectFloorDrainMesh._();

  static const _tileColor = Color(0xFFECEFF1); // Light bathroom ceramic tile
  static const _grateColor = Color(0xFFB0BEC5); // Stainless steel grate
  static const _grateMaterial = MeshMaterial(
    name: 'stainless_steel',
    metallicFactor: 0.85,
    roughnessFactor: 0.25,
  );

  static List<Triangle3D> build(
    ArchitectProject project,
    ArchitectStorey storey,
    ArchitectFloorDrain drain,
  ) {
    if (drain.polygon.length < 3) return const [];
    final triangles = <Triangle3D>[];
    final baseElevation = storey.elevation + storey.floorFinishThickness;

    _buildSlopingFloor(triangles, drain, baseElevation);
    if (drain.isLinear) {
      _buildLinearGrate(triangles, drain, baseElevation);
    } else {
      _buildRoundGrate(triangles, drain, baseElevation);
    }

    return triangles;
  }

  // ===========================================================================
  // 2. SLOPING FLOOR FINISH MESH
  // ===========================================================================

  static void _buildSlopingFloor(
    List<Triangle3D> triangles,
    ArchitectFloorDrain drain,
    double baseElevation,
  ) {
    final poly = drain.polygon;
    final drainCenter = drain.position;
    final zBottom = baseElevation - 0.05; // 5 cm screed depth

    void addTri(Vector3 a, Vector3 b, Vector3 c, Color color) {
      triangles.add(
        Triangle3D(
          v0: a,
          v1: b,
          v2: c,
          color: color,
          isDoubleSided: true,
        ),
      );
    }

    // Top sloping surface: fan from drain axis to each perimeter segment
    for (var i = 0; i < poly.length; i++) {
      final p1 = poly[i];
      final p2 = poly[(i + 1) % poly.length];

      final z1 = baseElevation + ArchitectFloorDrainGeometry.fall(drain, p1);
      final z2 = baseElevation + ArchitectFloorDrainGeometry.fall(drain, p2);

      final n1 = ArchitectFloorDrainGeometry.nearestOnAxis(drain, p1);
      final n2 = ArchitectFloorDrainGeometry.nearestOnAxis(drain, p2);

      final vTop1 = Vector3(p1.dx, p1.dy, z1);
      final vTop2 = Vector3(p2.dx, p2.dy, z2);
      final vGrate1 = Vector3(n1.dx, n1.dy, baseElevation);
      final vGrate2 = Vector3(n2.dx, n2.dy, baseElevation);

      if ((n1 - n2).distanceSquared < 1e-6) {
        addTri(vGrate1, vTop1, vTop2, _tileColor);
      } else {
        addTri(vGrate1, vTop1, vTop2, _tileColor);
        addTri(vGrate1, vTop2, vGrate2, _tileColor);
      }

      // Perimeter skirts
      final vBot1 = Vector3(p1.dx, p1.dy, zBottom);
      final vBot2 = Vector3(p2.dx, p2.dy, zBottom);
      addTri(vBot1, vBot2, vTop2, const Color(0xFFCFD8DC));
      addTri(vBot1, vTop2, vTop1, const Color(0xFFCFD8DC));
    }

    // Bottom cap
    final centerBot = Vector3(drainCenter.dx, drainCenter.dy, zBottom);
    for (var i = 0; i < poly.length; i++) {
      final p1 = poly[i];
      final p2 = poly[(i + 1) % poly.length];
      addTri(
        centerBot,
        Vector3(p2.dx, p2.dy, zBottom),
        Vector3(p1.dx, p1.dy, zBottom),
        const Color(0xFF90A4AE),
      );
    }
  }

  // ===========================================================================
  // 3. 3D DRAIN GRATE SOLID (Round & Linear)
  // ===========================================================================

  static void _buildRoundGrate(
    List<Triangle3D> triangles,
    ArchitectFloorDrain drain,
    double baseElevation,
  ) {
    const segments = 24;
    final c = drain.position;
    final r = drain.size / 2;
    final zTop = baseElevation + 0.002; // Sits flush with finished tile
    final zTrap = baseElevation - 0.03; // Inset trap chamber

    void quad(Vector3 a, Vector3 b, Vector3 c0, Vector3 d) {
      triangles.add(
        Triangle3D(
          v0: a,
          v1: b,
          v2: c0,
          color: _grateColor,
          material: _grateMaterial,
        ),
      );
      triangles.add(
        Triangle3D(
          v0: a,
          v1: c0,
          v2: d,
          color: _grateColor,
          material: _grateMaterial,
        ),
      );
    }

    // Grate rim and inner disc
    final innerR = r * 0.75;
    final trapR = r * 0.25;

    for (var i = 0; i < segments; i++) {
      final a0 = i * 2.0 * math.pi / segments;
      final a1 = (i + 1) * 2.0 * math.pi / segments;

      final pOut0 = Vector3(c.dx + math.cos(a0) * r, c.dy + math.sin(a0) * r, zTop);
      final pOut1 = Vector3(c.dx + math.cos(a1) * r, c.dy + math.sin(a1) * r, zTop);
      final pIn0 = Vector3(c.dx + math.cos(a0) * innerR, c.dy + math.sin(a0) * innerR, zTop);
      final pIn1 = Vector3(c.dx + math.cos(a1) * innerR, c.dy + math.sin(a1) * innerR, zTop);

      // Outer rim
      quad(pIn0, pIn1, pOut1, pOut0);

      // Radial grate slots: alternate solid spoke / slot
      if (i % 2 == 0) {
        final pTrap0 = Vector3(c.dx + math.cos(a0) * trapR, c.dy + math.sin(a0) * trapR, zTop);
        final pTrap1 = Vector3(c.dx + math.cos(a1) * trapR, c.dy + math.sin(a1) * trapR, zTop);
        quad(pTrap0, pTrap1, pIn1, pIn0);
      } else {
        // Recessed slot to trap depth
        final pTrap0 = Vector3(c.dx + math.cos(a0) * trapR, c.dy + math.sin(a0) * trapR, zTrap);
        final pTrap1 = Vector3(c.dx + math.cos(a1) * trapR, c.dy + math.sin(a1) * trapR, zTrap);
        quad(pTrap0, pTrap1, pIn1, pIn0);
      }
    }
  }

  static void _buildLinearGrate(
    List<Triangle3D> triangles,
    ArchitectFloorDrain drain,
    double baseElevation,
  ) {
    final c = drain.position;
    final len = drain.size;
    final w = drain.width;
    final zTop = baseElevation + 0.002;
    final zChamber = baseElevation - 0.035;

    final cosA = math.cos(drain.angle);
    final sinA = math.sin(drain.angle);

    Vector3 localToWorld(double x, double y, double z) {
      final wx = c.dx + x * cosA - y * sinA;
      final wy = c.dy + x * sinA + y * cosA;
      return Vector3(wx, wy, z);
    }

    void quad(Vector3 a, Vector3 b, Vector3 c0, Vector3 d) {
      triangles.add(
        Triangle3D(
          v0: a,
          v1: b,
          v2: c0,
          color: _grateColor,
          material: _grateMaterial,
        ),
      );
      triangles.add(
        Triangle3D(
          v0: a,
          v1: c0,
          v2: d,
          color: _grateColor,
          material: _grateMaterial,
        ),
      );
    }

    final halfL = len / 2.0;
    final halfW = w / 2.0;
    final rim = 0.008; // 8 mm stainless steel flange

    // Flange frame (outer to inner)
    final p0 = localToWorld(-halfL, -halfW, zTop);
    final p1 = localToWorld(halfL, -halfW, zTop);
    final p2 = localToWorld(halfL, halfW, zTop);
    final p3 = localToWorld(-halfL, halfW, zTop);

    final q0 = localToWorld(-halfL + rim, -halfW + rim, zTop);
    final q1 = localToWorld(halfL - rim, -halfW + rim, zTop);
    final q2 = localToWorld(halfL - rim, halfW - rim, zTop);
    final q3 = localToWorld(-halfL + rim, halfW - rim, zTop);

    quad(p0, p1, q1, q0);
    quad(p1, p2, q2, q1);
    quad(p2, p3, q3, q2);
    quad(p3, p0, q0, q3);

    // Channel chamber base
    final b0 = localToWorld(-halfL + rim, -halfW + rim, zChamber);
    final b1 = localToWorld(halfL - rim, -halfW + rim, zChamber);
    final b2 = localToWorld(halfL - rim, halfW - rim, zChamber);
    final b3 = localToWorld(-halfL + rim, halfW - rim, zChamber);

    quad(b0, b1, b2, b3);
    quad(b0, b1, q1, q0);
    quad(b1, b2, q2, q1);
    quad(b2, b3, q3, q2);
    quad(b3, b0, q0, q3);

    // Transverse grate bars (slotted designer linear channel)
    final barCount = (len / 0.04).floor();
    final barW = 0.015;
    for (var i = 1; i < barCount; i++) {
      final bx = -halfL + len * (i / barCount);
      final r0 = localToWorld(bx - barW / 2, -halfW + rim, zTop);
      final r1 = localToWorld(bx + barW / 2, -halfW + rim, zTop);
      final r2 = localToWorld(bx + barW / 2, halfW - rim, zTop);
      final r3 = localToWorld(bx - barW / 2, halfW - rim, zTop);
      quad(r0, r1, r2, r3);
    }
  }
}
