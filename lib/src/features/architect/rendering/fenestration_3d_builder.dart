// === SECTION: ARCHITECTURAL FENESTRATION 3D SOLID MESH BUILDER ===
// Table of Contents:
// 1. MAIN ENTRY POINT (build3D)
// 2. 5-CHAMBER FRAME MESH GENERATOR
// 3. SUBDIVISION, MULLION & TRANSOM EXTRUSION
// 4. DOUBLE GLAZING UNIT EXTRUSION (24 mm) & EPDM GASKET
// 5. EXTERIOR CASING / TRIM EXTRUSION (Sitting on wall & insulation)
// 6. EXTERIOR SILL PLATE
// 7. 3D PRISM HELPERS
// 8. INTERIOR HARDWARE & HINGES (Windows & Doors)

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../models/architect_fenestration_style.dart';

/// Builds real-time solid 3D mesh triangles for parametric windows and doors.
class Fenestration3dBuilder {
  Fenestration3dBuilder._();

  // Standard Colors
  static const Color frameColor = Color(0xFF37474F); // Dark slate PVC/Al frame
  static const Color sashColor = Color(0xFF455A64);  // Inner moving sash frame
  static const Color glassColor = Color(0x994FC3F7); // Cyan double glazing unit
  static const Color sillColor = Color(0xFF90A4AE);  // Metal/stone exterior sill
  static const Color gasketColor = Color(0xFF1B1B1B); // Black EPDM rubber glazing gasket
  static const Color hingeColor = Color(0xFF263238); // Hardware hinge barrel
  static const Color hingeCapColor = Color(0xFF2E3D44); // Hardware hinge cap & bracket
  static const Color handleColor = Color(0xFFB0BEC5); // Hardware lever handle
  static const Color handleRosetteColor = Color(0xFF546E7A); // Hardware handle rosette

  /// Generates the complete 3D mesh of the fenestration element hosted within a wall.
  static List<Triangle3D> buildOpening3D({
    required ArchitectFenestrationStyle style,
    required Offset wallStart,
    required Offset wallEnd,
    required double wallThickness,
    required double coreThickness,
    required double insulationThickness,
    required double exteriorSign, // +1 or -1 along wall normal pointing to exterior
    required double offsetRatio,
    required double width,
    required double height,
    required double sillHeight,
    required double storeyElevation,
    bool isHingeLeft = true,
  }) {
    final List<Triangle3D> tris = [];
    final wallVec = wallEnd - wallStart;
    final wallLen = wallVec.distance;
    if (wallLen < 1e-4) return tris;

    final u = wallVec / wallLen; // Vector along wall baseline
    final n = Offset(-u.dy, u.dx); // Vector normal across wall thickness

    final centerPos = wallStart + u * (offsetRatio * wallLen);
    final halfW = width / 2.0;

    // Heights
    final zBottom = storeyElevation + sillHeight;
    final zTop = zBottom + height;

    // Center in masonry core (5-chamber frame depth = 70 mm = 0.07 m)
    final coreCenterShift =
        (wallThickness - coreThickness) / 2.0 * (-exteriorSign);
    final frameCenter = centerPos + n * coreCenterShift;
    final fDepth = style.frameDepth;
    final fFace = style.frameFaceWidth;
    final halfFDepth = fDepth / 2.0;

    // 1. Outer 5-Chamber Frame Jambs, Lintel & Bottom
    _buildOuterFrame(
      tris: tris,
      frameCenter: frameCenter,
      u: u,
      n: n,
      halfW: halfW,
      halfFDepth: halfFDepth,
      fFace: fFace,
      zBottom: zBottom,
      zTop: zTop,
      isWindow: style.kind == FenestrationKind.window,
    );

    // 2. Subdivisions (Transoms, Mullions, Sashes, Double Glazing)
    _buildSubdivisions3D(
      tris: tris,
      node: style.rootSubdivision,
      frameCenter: frameCenter,
      u: u,
      n: n,
      halfFDepth: halfFDepth,
      glazingThick: style.glazingThickness,
      fFace: fFace,
      left: -halfW + fFace,
      right: halfW - fFace,
      bottomZ: zBottom + (style.kind == FenestrationKind.window ? fFace : 0.0),
      topZ: zTop - fFace,
      exteriorSign: exteriorSign,
      kind: style.kind,
    );

    // 3. Exterior Casing / Trim (Обрамчване)
    // Sits directly on the exterior wall/insulation face without intersecting the wall body!
    if (style.hasCasing) {
      _buildExteriorCasing(
        tris: tris,
        style: style,
        centerPos: centerPos,
        u: u,
        n: n,
        wallThickness: wallThickness,
        coreThickness: coreThickness,
        insulationThickness: insulationThickness,
        exteriorSign: exteriorSign,
        halfW: halfW,
        zBottom: zBottom,
        zTop: zTop,
      );
    }

    // 4. Exterior Sill Plate (if window without bottom casing)
    if (style.kind == FenestrationKind.window && !style.hasCasing) {
      _buildExteriorSillPlate(
        tris: tris,
        centerPos: centerPos,
        u: u,
        n: n,
        wallThickness: wallThickness,
        exteriorSign: exteriorSign,
        halfW: halfW,
        zBottom: zBottom,
      );
    }

    // 5. Interior-facing 3D Barrel Hinges for doors
    if (style.kind == FenestrationKind.door) {
      _buildDoorHinges3D(
        tris: tris,
        frameCenter: frameCenter,
        u: u,
        n: n,
        halfW: halfW,
        fFace: fFace,
        wallThickness: wallThickness,
        exteriorSign: exteriorSign,
        zBottom: zBottom,
        zTop: zTop,
        isHingeLeft: isHingeLeft,
      );
    }

    return tris;
  }

  // ===========================================================================
  // SECTION 2: 5-CHAMBER FRAME MESH GENERATOR
  // ===========================================================================

  static void _buildOuterFrame({
    required List<Triangle3D> tris,
    required Offset frameCenter,
    required Offset u,
    required Offset n,
    required double halfW,
    required double halfFDepth,
    required double fFace,
    required double zBottom,
    required double zTop,
    required bool isWindow,
  }) {
    // Left Jamb (вертикална лява каса)
    final lj1 = frameCenter - u * halfW - n * halfFDepth;
    final lj2 = frameCenter - u * (halfW - fFace) - n * halfFDepth;
    final lj3 = frameCenter - u * (halfW - fFace) + n * halfFDepth;
    final lj4 = frameCenter - u * halfW + n * halfFDepth;
    _addBox3D(tris, lj1, lj2, lj3, lj4, zBottom, zTop, frameColor);

    // Right Jamb (вертикална дясна каса)
    final rj1 = frameCenter + u * (halfW - fFace) - n * halfFDepth;
    final rj2 = frameCenter + u * halfW - n * halfFDepth;
    final rj3 = frameCenter + u * halfW + n * halfFDepth;
    final rj4 = frameCenter + u * (halfW - fFace) + n * halfFDepth;
    _addBox3D(tris, rj1, rj2, rj3, rj4, zBottom, zTop, frameColor);

    // Head Jamb / Lintel (горна хоризонтална каса)
    final hj1 = frameCenter - u * (halfW - fFace) - n * halfFDepth;
    final hj2 = frameCenter + u * (halfW - fFace) - n * halfFDepth;
    final hj3 = frameCenter + u * (halfW - fFace) + n * halfFDepth;
    final hj4 = frameCenter - u * (halfW - fFace) + n * halfFDepth;
    _addBox3D(tris, hj1, hj2, hj3, hj4, zTop - fFace, zTop, frameColor);

    // Sill Jamb / Bottom Rail (долна хоризонтална каса за прозорци)
    if (isWindow) {
      _addBox3D(tris, hj1, hj2, hj3, hj4, zBottom, zBottom + fFace, frameColor);
    }
  }

  // ===========================================================================
  // SECTION 3: SUBDIVISION, MULLION & TRANSOM EXTRUSION
  // ===========================================================================

  static void _buildSubdivisions3D({
    required List<Triangle3D> tris,
    required FenestrationSubdivision node,
    required Offset frameCenter,
    required Offset u,
    required Offset n,
    required double halfFDepth,
    required double glazingThick,
    required double fFace,
    required double left,
    required double right,
    required double bottomZ,
    required double topZ,
    required double exteriorSign,
    required FenestrationKind kind,
  }) {
    final curW = right - left;
    final curH = topZ - bottomZ;
    if (curW <= 0.02 || curH <= 0.02) return;

    if (node.isSplit) {
      if (node.isVertical) {
        // Vertical mullion splits
        double currentX = left;
        for (int i = 0; i < node.children.length; i++) {
          final w = curW * node.ratios[i];
          final childRight = currentX + w;

          // Add vertical dividing mullion bar between panes
          if (i < node.children.length - 1) {
            final mCenter = childRight;
            final m1 = frameCenter + u * (mCenter - fFace / 2) - n * halfFDepth;
            final m2 = frameCenter + u * (mCenter + fFace / 2) - n * halfFDepth;
            final m3 = frameCenter + u * (mCenter + fFace / 2) + n * halfFDepth;
            final m4 = frameCenter + u * (mCenter - fFace / 2) + n * halfFDepth;
            _addBox3D(tris, m1, m2, m3, m4, bottomZ, topZ, frameColor);
          }

          _buildSubdivisions3D(
            tris: tris,
            node: node.children[i],
            frameCenter: frameCenter,
            u: u,
            n: n,
            halfFDepth: halfFDepth,
            glazingThick: glazingThick,
            fFace: fFace,
            left: currentX,
            right: childRight,
            bottomZ: bottomZ,
            topZ: topZ,
            exteriorSign: exteriorSign,
            kind: kind,
          );

          currentX = childRight;
        }
      } else {
        // Horizontal transom splits
        double currentZ = bottomZ;
        for (int i = 0; i < node.children.length; i++) {
          final h = curH * node.ratios[i];
          final childTop = currentZ + h;

          // Add horizontal transom bar between panes
          if (i < node.children.length - 1) {
            final tCenter = childTop;
            final t1 = frameCenter + u * left - n * halfFDepth;
            final t2 = frameCenter + u * right - n * halfFDepth;
            final t3 = frameCenter + u * right + n * halfFDepth;
            final t4 = frameCenter + u * left + n * halfFDepth;
            _addBox3D(
              tris,
              t1,
              t2,
              t3,
              t4,
              tCenter - fFace / 2,
              tCenter + fFace / 2,
              frameColor,
            );
          }

          _buildSubdivisions3D(
            tris: tris,
            node: node.children[i],
            frameCenter: frameCenter,
            u: u,
            n: n,
            halfFDepth: halfFDepth,
            glazingThick: glazingThick,
            fFace: fFace,
            left: left,
            right: right,
            bottomZ: currentZ,
            topZ: childTop,
            exteriorSign: exteriorSign,
            kind: kind,
          );

          currentZ = childTop;
        }
      }
      return;
    }

    // Leaf Pane
    final pane = node.pane;
    if (pane == null) return;

    if (pane.isOpenable) {
      // Movable sash inner profile (60 mm face)
      final sProfile = pane.sashProfileWidth;
      final sLeft = left + sProfile;
      final sRight = right - sProfile;
      final sBottom = bottomZ + sProfile;
      final sTop = topZ - sProfile;

      // Outer boundary of moving sash
      final b1 = frameCenter + u * left - n * (halfFDepth * 0.95);
      final b2 = frameCenter + u * right - n * (halfFDepth * 0.95);
      final b3 = frameCenter + u * right + n * (halfFDepth * 0.95);
      final b4 = frameCenter + u * left + n * (halfFDepth * 0.95);

      // Left sash stile
      final ls1 = b1;
      final ls2 = frameCenter + u * sLeft - n * (halfFDepth * 0.95);
      final ls3 = frameCenter + u * sLeft + n * (halfFDepth * 0.95);
      final ls4 = b4;
      _addBox3D(tris, ls1, ls2, ls3, ls4, bottomZ, topZ, sashColor);

      // Right sash stile
      final rs1 = frameCenter + u * sRight - n * (halfFDepth * 0.95);
      final rs2 = b2;
      final rs3 = b3;
      final rs4 = frameCenter + u * sRight + n * (halfFDepth * 0.95);
      _addBox3D(tris, rs1, rs2, rs3, rs4, bottomZ, topZ, sashColor);

      // Top sash rail
      final ts1 = ls2;
      final ts2 = rs1;
      final ts3 = rs4;
      final ts4 = ls3;
      _addBox3D(tris, ts1, ts2, ts3, ts4, sTop, topZ, sashColor);

      // Bottom sash rail
      _addBox3D(tris, ts1, ts2, ts3, ts4, bottomZ, sBottom, sashColor);

      // Double Glazing inside sash
      if (pane.isGlazed) {
        _buildDoubleGlazingPane(
          tris: tris,
          pane: pane,
          frameCenter: frameCenter,
          u: u,
          n: n,
          left: sLeft,
          right: sRight,
          bottomZ: sBottom,
          topZ: sTop,
          glazingThick: glazingThick,
        );
      } else {
        // Solid panel (e.g. door infill)
        _buildSolidInfillPane(
          tris: tris,
          frameCenter: frameCenter,
          u: u,
          n: n,
          left: sLeft,
          right: sRight,
          bottomZ: sBottom,
          topZ: sTop,
          depth: halfFDepth * 0.8,
        );
      }

      // Interior-facing window hinges for operable sashes
      if (kind == FenestrationKind.window) {
        _buildWindowSashHinges3D(
          tris: tris,
          frameCenter: frameCenter,
          u: u,
          n: n,
          halfFDepth: halfFDepth,
          exteriorSign: exteriorSign,
          paneType: pane.paneType,
          left: left,
          right: right,
          bottomZ: bottomZ,
          topZ: topZ,
        );
      }
    } else {
      // Fixed Glazing unit directly inside frame
      if (pane.isGlazed) {
        _buildDoubleGlazingPane(
          tris: tris,
          pane: pane,
          frameCenter: frameCenter,
          u: u,
          n: n,
          left: left,
          right: right,
          bottomZ: bottomZ,
          topZ: topZ,
          glazingThick: glazingThick,
        );
      } else {
        _buildSolidInfillPane(
          tris: tris,
          frameCenter: frameCenter,
          u: u,
          n: n,
          left: left,
          right: right,
          bottomZ: bottomZ,
          topZ: topZ,
          depth: halfFDepth * 0.8,
        );
      }
    }
  }

  // ===========================================================================
  // SECTION 4: DOUBLE GLAZING UNIT EXTRUSION (24 mm)
  // ===========================================================================

  static void _buildDoubleGlazingPane({
    required List<Triangle3D> tris,
    required FenestrationPane pane,
    required Offset frameCenter,
    required Offset u,
    required Offset n,
    required double left,
    required double right,
    required double bottomZ,
    required double topZ,
    required double glazingThick,
  }) {
    if (right <= left + 0.02 || topZ <= bottomZ + 0.02) return;

    final halfGlass = (glazingThick / 2.0).clamp(0.010, 0.015);
    final g1 = frameCenter + u * left - n * halfGlass;
    final g2 = frameCenter + u * right - n * halfGlass;
    final g3 = frameCenter + u * right + n * halfGlass;
    final g4 = frameCenter + u * left + n * halfGlass;

    _addBox3D(tris, g1, g2, g3, g4, bottomZ + 0.005, topZ - 0.005, glassColor);

    // Black Rubber Glazing Gasket (черно гумено уплътнение за стъклопакета)
    // Outlines the perimeter of the double glazing unit on both exterior and interior faces.
    const gasketW = 0.008; // 8 mm width of visible rubber seal
    if (right - left > 2 * gasketW + 0.01 && topZ - bottomZ > 2 * gasketW + 0.01) {
      final halfGasket = halfGlass + 0.002; // Protrudes 2mm proud of glass on both faces

      void addGasketStrip(double x1, double x2, double z1, double z2) {
        if (x2 <= x1 + 1e-4 || z2 <= z1 + 1e-4) return;
        final gb1 = frameCenter + u * x1 - n * halfGasket;
        final gb2 = frameCenter + u * x2 - n * halfGasket;
        final gb3 = frameCenter + u * x2 + n * halfGasket;
        final gb4 = frameCenter + u * x1 + n * halfGasket;
        _addBox3D(tris, gb1, gb2, gb3, gb4, z1, z2, gasketColor);
      }

      // Left vertical gasket strip
      addGasketStrip(left, left + gasketW, bottomZ, topZ);
      // Right vertical gasket strip
      addGasketStrip(right - gasketW, right, bottomZ, topZ);
      // Bottom horizontal gasket strip
      addGasketStrip(left + gasketW, right - gasketW, bottomZ, bottomZ + gasketW);
      // Top horizontal gasket strip
      addGasketStrip(left + gasketW, right - gasketW, topZ - gasketW, topZ);
    }

    // Build 3D solid muntin bars (шпроси)
    if (pane.hasMuntins) {
      final mThick = pane.muntinWidth;
      final mHalf = mThick / 2.0;
      final mDepth = halfGlass * 1.05;

      // Vertical muntins
      final spanX = right - left;
      for (int c = 1; c <= pane.muntinCols; c++) {
        final cx = left + (spanX / (pane.muntinCols + 1)) * c;
        final mb1 = frameCenter + u * (cx - mHalf) - n * mDepth;
        final mb2 = frameCenter + u * (cx + mHalf) - n * mDepth;
        final mb3 = frameCenter + u * (cx + mHalf) + n * mDepth;
        final mb4 = frameCenter + u * (cx - mHalf) + n * mDepth;
        _addBox3D(
          tris,
          mb1,
          mb2,
          mb3,
          mb4,
          bottomZ + 0.01,
          topZ - 0.01,
          sashColor,
        );
      }

      // Horizontal muntins
      final spanZ = topZ - bottomZ;
      for (int r = 1; r <= pane.muntinRows; r++) {
        final cz = bottomZ + (spanZ / (pane.muntinRows + 1)) * r;
        final mb1 = frameCenter + u * left - n * mDepth;
        final mb2 = frameCenter + u * right - n * mDepth;
        final mb3 = frameCenter + u * right + n * mDepth;
        final mb4 = frameCenter + u * left + n * mDepth;
        _addBox3D(
          tris,
          mb1,
          mb2,
          mb3,
          mb4,
          cz - mHalf,
          cz + mHalf,
          sashColor,
        );
      }
    }
  }

  static void _buildSolidInfillPane({
    required List<Triangle3D> tris,
    required Offset frameCenter,
    required Offset u,
    required Offset n,
    required double left,
    required double right,
    required double bottomZ,
    required double topZ,
    required double depth,
  }) {
    final s1 = frameCenter + u * left - n * depth;
    final s2 = frameCenter + u * right - n * depth;
    final s3 = frameCenter + u * right + n * depth;
    final s4 = frameCenter + u * left + n * depth;

    const panelColor = Color(0xFF6D4C41);
    _addBox3D(tris, s1, s2, s3, s4, bottomZ, topZ, panelColor);
  }

  // ===========================================================================
  // SECTION 5: EXTERIOR CASING / TRIM (Mounted on exterior wall & insulation)
  // ===========================================================================

  static void _buildExteriorCasing({
    required List<Triangle3D> tris,
    required ArchitectFenestrationStyle style,
    required Offset centerPos,
    required Offset u,
    required Offset n,
    required double wallThickness,
    required double coreThickness,
    required double insulationThickness,
    required double exteriorSign,
    required double halfW,
    required double zBottom,
    required double zTop,
  }) {
    final cWidth = style.casingWidth;
    final cProj = style.casingProjection;
    final cColor = style.casingColor;

    // Exterior finished wall surface plane:
    // Sits at distance `dExt` from wall centerline:
    // If wall has insulation, exterior surface is coreFace + insulation
    final halfWall = wallThickness / 2.0;
    final extSurfaceBase = centerPos + n * (exteriorSign * halfWall);
    final extProjBase = extSurfaceBase + n * (exteriorSign * cProj);

    // Left Casing Ear: from (centerPos - u * (halfW + cWidth)) to (centerPos - u * halfW)
    final lc1 = (extSurfaceBase - u * (halfW + cWidth));
    final lc2 = (extSurfaceBase - u * halfW);
    final lc3 = (extProjBase - u * halfW);
    final lc4 = (extProjBase - u * (halfW + cWidth));

    final bZ = style.includeBottomCasing ? zBottom - cWidth : zBottom;
    final tZ = zTop + cWidth;

    _addBoxFromPoints(tris, lc1, lc2, lc3, lc4, bZ, tZ, cColor);

    // Right Casing Ear: from (centerPos + u * halfW) to (centerPos + u * (halfW + cWidth))
    final rc1 = (extSurfaceBase + u * halfW);
    final rc2 = (extSurfaceBase + u * (halfW + cWidth));
    final rc3 = (extProjBase + u * (halfW + cWidth));
    final rc4 = (extProjBase + u * halfW);

    _addBoxFromPoints(tris, rc1, rc2, rc3, rc4, bZ, tZ, cColor);

    // Lintel Casing Header (Горно обрамчване): spans between outer casing edges
    final tc1 = (extSurfaceBase - u * (halfW + cWidth));
    final tc2 = (extSurfaceBase + u * (halfW + cWidth));
    final tc3 = (extProjBase + u * (halfW + cWidth));
    final tc4 = (extProjBase - u * (halfW + cWidth));

    _addBoxFromPoints(tris, tc1, tc2, tc3, tc4, zTop, tZ, cColor);

    // Bottom Casing Sill (Долно обрамчване, ако е включено)
    if (style.includeBottomCasing) {
      _addBoxFromPoints(tris, tc1, tc2, tc3, tc4, bZ, zBottom, cColor);
    }
  }

  // ===========================================================================
  // SECTION 6: EXTERIOR SILL PLATE
  // ===========================================================================

  static void _buildExteriorSillPlate({
    required List<Triangle3D> tris,
    required Offset centerPos,
    required Offset u,
    required Offset n,
    required double wallThickness,
    required double exteriorSign,
    required double halfW,
    required double zBottom,
  }) {
    const sillOverhang = 0.04;
    const sillDepth = 0.06;
    final halfWall = wallThickness / 2.0;

    final baseP = centerPos + n * (exteriorSign * halfWall);
    final outP = baseP + n * (exteriorSign * sillDepth);

    final sp1 = baseP - u * (halfW + sillOverhang);
    final sp2 = baseP + u * (halfW + sillOverhang);
    final sp3 = outP + u * (halfW + sillOverhang);
    final sp4 = outP - u * (halfW + sillOverhang);

    _addBoxFromPoints(
      tris,
      sp1,
      sp2,
      sp3,
      sp4,
      zBottom - 0.03,
      zBottom,
      sillColor,
    );
  }

  // ===========================================================================
  // SECTION 7: 3D PRISM HELPERS
  // ===========================================================================

  static void _addBox3D(
    List<Triangle3D> tris,
    Offset b1,
    Offset b2,
    Offset b3,
    Offset b4,
    double zMin,
    double zMax,
    Color color,
  ) {
    if (zMax <= zMin + 1e-4) return;
    final v1B = Vector3(b1.dx, b1.dy, zMin);
    final v2B = Vector3(b2.dx, b2.dy, zMin);
    final v3B = Vector3(b3.dx, b3.dy, zMin);
    final v4B = Vector3(b4.dx, b4.dy, zMin);

    final v1T = Vector3(b1.dx, b1.dy, zMax);
    final v2T = Vector3(b2.dx, b2.dy, zMax);
    final v3T = Vector3(b3.dx, b3.dy, zMax);
    final v4T = Vector3(b4.dx, b4.dy, zMax);

    // Top
    tris.add(Triangle3D(v0: v1T, v1: v2T, v2: v3T, color: color));
    tris.add(Triangle3D(v0: v1T, v1: v3T, v2: v4T, color: color));

    // Bottom
    tris.add(Triangle3D(v0: v1B, v1: v3B, v2: v2B, color: color));
    tris.add(Triangle3D(v0: v1B, v1: v4B, v2: v3B, color: color));

    // Front
    tris.add(Triangle3D(v0: v1B, v1: v2B, v2: v2T, color: color));
    tris.add(Triangle3D(v0: v1B, v1: v2T, v2: v1T, color: color));

    // Back
    tris.add(Triangle3D(v0: v3B, v1: v4B, v2: v4T, color: color));
    tris.add(Triangle3D(v0: v3B, v1: v4T, v2: v3T, color: color));

    // Left
    tris.add(Triangle3D(v0: v4B, v1: v1B, v2: v1T, color: color));
    tris.add(Triangle3D(v0: v4B, v1: v1T, v2: v4T, color: color));

    // Right
    tris.add(Triangle3D(v0: v2B, v1: v3B, v2: v3T, color: color));
    tris.add(Triangle3D(v0: v2B, v1: v3T, v2: v2T, color: color));
  }

  static void _addBoxFromPoints(
    List<Triangle3D> tris,
    Offset b1,
    Offset b2,
    Offset b3,
    Offset b4,
    double zMin,
    double zMax,
    Color color,
  ) {
    _addBox3D(tris, b1, b2, b3, b4, zMin, zMax, color);
  }

  // ===========================================================================
  // SECTION 8: INTERIOR HARDWARE & HINGES (Windows & Doors)
  // ===========================================================================

  static void _buildDoorHinges3D({
    required List<Triangle3D> tris,
    required Offset frameCenter,
    required Offset u,
    required Offset n,
    required double halfW,
    required double fFace,
    required double wallThickness,
    required double exteriorSign,
    required double zBottom,
    required double zTop,
    bool isHingeLeft = true,
  }) {
    final halfThick = wallThickness / 2.0;
    // Interior face is opposite to exteriorSign
    final interiorDir = -exteriorSign;
    final hingeX = isHingeLeft ? -(halfW - fFace) : (halfW - fFace);
    final hingePos = (frameCenter + u * hingeX) +
        n * (interiorDir * halfThick + interiorDir * 0.012);

    final height = zTop - zBottom;
    void addHingeBarrel(double zC) {
      const hingeR = 0.013;
      const halfH = 0.045;
      final zHMin = zC - halfH;
      final zHMax = zC + halfH;
      const segs = 8;
      final pts = List.generate(segs, (i) {
        final a = i * 2 * math.pi / segs;
        return hingePos + Offset(math.cos(a), math.sin(a)) * hingeR;
      });

      const barrelCol = hingeColor;
      const capCol = hingeCapColor;

      for (var i = 0; i < segs; i++) {
        final pA = pts[i];
        final pB = pts[(i + 1) % segs];
        final vAB = Vector3(pA.dx, pA.dy, zHMin);
        final vBB = Vector3(pB.dx, pB.dy, zHMin);
        final vAT = Vector3(pA.dx, pA.dy, zHMax);
        final vBT = Vector3(pB.dx, pB.dy, zHMax);

        tris.add(Triangle3D(v0: vAB, v1: vBB, v2: vBT, color: barrelCol));
        tris.add(Triangle3D(v0: vAB, v1: vBT, v2: vAT, color: barrelCol));
      }

      final cT = Vector3(hingePos.dx, hingePos.dy, zHMax);
      final cB = Vector3(hingePos.dx, hingePos.dy, zHMin);
      for (var i = 0; i < segs; i++) {
        final pA = pts[i];
        final pB = pts[(i + 1) % segs];
        tris.add(Triangle3D(
          v0: cT,
          v1: Vector3(pA.dx, pA.dy, zHMax),
          v2: Vector3(pB.dx, pB.dy, zHMax),
          color: capCol,
        ));
        tris.add(Triangle3D(
          v0: cB,
          v1: Vector3(pB.dx, pB.dy, zHMin),
          v2: Vector3(pA.dx, pA.dy, zHMin),
          color: capCol,
        ));
      }
    }

    addHingeBarrel(zTop - 0.22);
    addHingeBarrel(zBottom + height * 0.55);
    addHingeBarrel(zBottom + 0.25);
  }

  static void _buildWindowSashHinges3D({
    required List<Triangle3D> tris,
    required Offset frameCenter,
    required Offset u,
    required Offset n,
    required double halfFDepth,
    required double exteriorSign,
    required PaneType paneType,
    required double left,
    required double right,
    required double bottomZ,
    required double topZ,
  }) {
    final interiorDir = -exteriorSign;

    if (paneType == PaneType.topHopper) {
      _buildWindowHinge3D(
        tris: tris,
        frameCenter: frameCenter,
        u: u,
        n: n,
        interiorDir: interiorDir,
        halfFDepth: halfFDepth,
        hingeX: left + 0.04,
        zCenter: bottomZ + 0.025,
        isHingeLeft: true,
      );
      _buildWindowHinge3D(
        tris: tris,
        frameCenter: frameCenter,
        u: u,
        n: n,
        interiorDir: interiorDir,
        halfFDepth: halfFDepth,
        hingeX: right - 0.04,
        zCenter: bottomZ + 0.025,
        isHingeLeft: false,
      );
      return;
    }

    final bool isHingeLeft;
    if (paneType == PaneType.casementLeft) {
      isHingeLeft = true;
    } else if (paneType == PaneType.casementRight) {
      isHingeLeft = false;
    } else if (paneType == PaneType.tiltAndTurn) {
      isHingeLeft = !(right > 0.05 && left >= -0.05);
    } else {
      isHingeLeft = true;
    }

    final hingeX = isHingeLeft ? (left + 0.012) : (right - 0.012);
    final topHingeZ = topZ - 0.06;
    final bottomHingeZ = bottomZ + 0.06;

    // Top hinge
    _buildWindowHinge3D(
      tris: tris,
      frameCenter: frameCenter,
      u: u,
      n: n,
      interiorDir: interiorDir,
      halfFDepth: halfFDepth,
      hingeX: hingeX,
      zCenter: topHingeZ,
      isHingeLeft: isHingeLeft,
    );

    // Bottom hinge
    _buildWindowHinge3D(
      tris: tris,
      frameCenter: frameCenter,
      u: u,
      n: n,
      interiorDir: interiorDir,
      halfFDepth: halfFDepth,
      hingeX: hingeX,
      zCenter: bottomHingeZ,
      isHingeLeft: isHingeLeft,
    );

    // Interior window handle on the opposite side of hinges
    final handleX = isHingeLeft ? (right - 0.025) : (left + 0.025);
    final handleZ = (bottomZ + topZ) / 2.0;
    _buildWindowHandle3D(
      tris: tris,
      frameCenter: frameCenter,
      u: u,
      n: n,
      interiorDir: interiorDir,
      halfFDepth: halfFDepth,
      handleX: handleX,
      handleZ: handleZ,
      pointingLeft: isHingeLeft,
    );
  }

  static void _buildWindowHinge3D({
    required List<Triangle3D> tris,
    required Offset frameCenter,
    required Offset u,
    required Offset n,
    required double interiorDir,
    required double halfFDepth,
    required double hingeX,
    required double zCenter,
    required bool isHingeLeft,
  }) {
    const hingeR = 0.009; // 9 mm radius (18 mm cylinder)
    const halfH = 0.025;  // 50 mm total height
    final zHMin = zCenter - halfH;
    final zHMax = zCenter + halfH;

    final interiorFacePos =
        frameCenter + u * hingeX + n * (interiorDir * halfFDepth);
    final hingePos =
        interiorFacePos + n * (interiorDir * (hingeR * 0.9));

    const segs = 8;
    final pts = List.generate(segs, (i) {
      final a = i * 2 * math.pi / segs;
      return hingePos + Offset(math.cos(a), math.sin(a)) * hingeR;
    });

    const barrelCol = hingeColor;
    const capCol = hingeCapColor;

    for (var i = 0; i < segs; i++) {
      final pA = pts[i];
      final pB = pts[(i + 1) % segs];
      final vAB = Vector3(pA.dx, pA.dy, zHMin);
      final vBB = Vector3(pB.dx, pB.dy, zHMin);
      final vAT = Vector3(pA.dx, pA.dy, zHMax);
      final vBT = Vector3(pB.dx, pB.dy, zHMax);

      tris.add(Triangle3D(v0: vAB, v1: vBB, v2: vBT, color: barrelCol));
      tris.add(Triangle3D(v0: vAB, v1: vBT, v2: vAT, color: barrelCol));
    }

    final cT = Vector3(hingePos.dx, hingePos.dy, zHMax);
    final cB = Vector3(hingePos.dx, hingePos.dy, zHMin);
    for (var i = 0; i < segs; i++) {
      final pA = pts[i];
      final pB = pts[(i + 1) % segs];
      tris.add(Triangle3D(
        v0: cT,
        v1: Vector3(pA.dx, pA.dy, zHMax),
        v2: Vector3(pB.dx, pB.dy, zHMax),
        color: capCol,
      ));
      tris.add(Triangle3D(
        v0: cB,
        v1: Vector3(pB.dx, pB.dy, zHMin),
        v2: Vector3(pA.dx, pA.dy, zHMin),
        color: capCol,
      ));
    }

    // Mounting bracket connecting barrel to sash stile
    final bracketSide = isHingeLeft ? -1.0 : 1.0;
    final bP1 = interiorFacePos - u * (bracketSide * 0.012) - n * (interiorDir * 0.004);
    final bP2 = interiorFacePos + u * (bracketSide * 0.012) - n * (interiorDir * 0.004);
    final bP3 = interiorFacePos + u * (bracketSide * 0.012) + n * (interiorDir * (hingeR * 0.9));
    final bP4 = interiorFacePos - u * (bracketSide * 0.012) + n * (interiorDir * (hingeR * 0.9));

    _addBox3D(tris, bP1, bP2, bP3, bP4, zCenter - 0.015, zCenter + 0.015, capCol);
  }

  static void _buildWindowHandle3D({
    required List<Triangle3D> tris,
    required Offset frameCenter,
    required Offset u,
    required Offset n,
    required double interiorDir,
    required double halfFDepth,
    required double handleX,
    required double handleZ,
    required bool pointingLeft,
  }) {
    final facePos = frameCenter + u * handleX + n * (interiorDir * halfFDepth);

    // 1. Base rosette
    final r1 = facePos - u * 0.012;
    final r2 = facePos + u * 0.012;
    final r3 = facePos + u * 0.012 + n * (interiorDir * 0.008);
    final r4 = facePos - u * 0.012 + n * (interiorDir * 0.008);
    _addBox3D(tris, r1, r2, r3, r4, handleZ - 0.028, handleZ + 0.028, handleRosetteColor);

    // 2. Neck
    final neckBase = facePos + n * (interiorDir * 0.008);
    final neckOut = facePos + n * (interiorDir * 0.038);
    final nk1 = neckBase - u * 0.007;
    final nk2 = neckBase + u * 0.007;
    final nk3 = neckOut + u * 0.007;
    final nk4 = neckOut - u * 0.007;
    _addBox3D(tris, nk1, nk2, nk3, nk4, handleZ - 0.007, handleZ + 0.007, handleColor);

    // 3. Ergonomic lever pointing down
    final hLev1 = neckOut - u * 0.007;
    final hLev2 = neckOut + u * 0.007;
    final hLev3 = neckOut + u * 0.007 + n * (interiorDir * 0.012);
    final hLev4 = neckOut - u * 0.007 + n * (interiorDir * 0.012);
    _addBox3D(tris, hLev1, hLev2, hLev3, hLev4, handleZ - 0.10, handleZ + 0.007, handleColor);
  }
}
