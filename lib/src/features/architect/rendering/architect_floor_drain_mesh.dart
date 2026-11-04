import '../services/architect_drain_surface.dart';
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
    final surface = ArchitectDrainSurface.of(drain);
    final bottom = baseElevation - .05;
    void tri(Vector3 a, Vector3 b, Vector3 c, Color color) => triangles.add(
      Triangle3D(v0: a, v1: b, v2: c, color: color, isDoubleSided: true),
    );
    Vector3 at(Offset p, double z) => Vector3(p.dx, p.dy, z);
    for (final t in surface.triangles) {
      tri(
        at(t.a, baseElevation + t.za),
        at(t.b, baseElevation + t.zb),
        at(t.c, baseElevation + t.zc),
        _tileColor,
      );
      tri(
        at(t.c, bottom),
        at(t.b, bottom),
        at(t.a, bottom),
        const Color(0xFF90A4AE),
      );
    }
    for (final (a, b) in surface.boundary) {
      final za = baseElevation + (surface.heightAt(a) ?? 0),
          zb = baseElevation + (surface.heightAt(b) ?? 0);
      tri(at(a, bottom), at(b, bottom), at(b, zb), const Color(0xFFCFD8DC));
      tri(at(a, bottom), at(b, zb), at(a, za), const Color(0xFFCFD8DC));
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

      final pOut0 = Vector3(
        c.dx + math.cos(a0) * r,
        c.dy + math.sin(a0) * r,
        zTop,
      );
      final pOut1 = Vector3(
        c.dx + math.cos(a1) * r,
        c.dy + math.sin(a1) * r,
        zTop,
      );
      final pIn0 = Vector3(
        c.dx + math.cos(a0) * innerR,
        c.dy + math.sin(a0) * innerR,
        zTop,
      );
      final pIn1 = Vector3(
        c.dx + math.cos(a1) * innerR,
        c.dy + math.sin(a1) * innerR,
        zTop,
      );

      // Outer rim
      quad(pIn0, pIn1, pOut1, pOut0);

      // Radial grate slots: alternate solid spoke / slot
      if (i % 2 == 0) {
        final pTrap0 = Vector3(
          c.dx + math.cos(a0) * trapR,
          c.dy + math.sin(a0) * trapR,
          zTop,
        );
        final pTrap1 = Vector3(
          c.dx + math.cos(a1) * trapR,
          c.dy + math.sin(a1) * trapR,
          zTop,
        );
        quad(pTrap0, pTrap1, pIn1, pIn0);
      } else {
        // Recessed slot to trap depth
        final pTrap0 = Vector3(
          c.dx + math.cos(a0) * trapR,
          c.dy + math.sin(a0) * trapR,
          zTrap,
        );
        final pTrap1 = Vector3(
          c.dx + math.cos(a1) * trapR,
          c.dy + math.sin(a1) * trapR,
          zTrap,
        );
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
