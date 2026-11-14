import 'dart:math' as math;
import 'dart:ui';

import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../models/architect_landscape_models.dart';

/// Parametric 3D mesh builder for architectural site fences and retaining walls.
///
/// Generates crisp, outward-wound solid geometry for all [ArchitectSiteFencePreset]
/// types (masonry piers with individual spaced wood boards, rock-filled gabion
/// baskets with galvanized welded-wire cages, tilted modern louvers, classic
/// wrought iron with spear finials, and battered RC retaining walls with
/// footings, coping, and weep holes).
class ArchitectFence3dMesh {
  ArchitectFence3dMesh._();

  // --- Shared PBR Material Singletons (matched sRGB colors for fallback painter) ---
  static const _galvanizedSteelMat = MeshMaterial(
    name: 'fence_galvanized_wire',
    baseColorFactor: [0.64, 0.69, 0.74, 1.0],
    metallicFactor: 0.78,
    roughnessFactor: 0.34,
  );
  static const _galvanizedWireColor = Color(0xFFD2DAE2);

  static const _anthraciteMat = MeshMaterial(
    name: 'fence_anthracite_steel',
    baseColorFactor: [0.025, 0.035, 0.052, 1.0],
    metallicFactor: 0.45,
    roughnessFactor: 0.46,
  );
  static const _anthraciteColor = Color(0xFF2B3440);

  static const _anthraciteLouverMat = MeshMaterial(
    name: 'fence_anthracite_louver',
    baseColorFactor: [0.044, 0.060, 0.088, 1.0],
    metallicFactor: 0.50,
    roughnessFactor: 0.40,
  );
  static const _anthraciteLouverColor = Color(0xFF3B4656);

  static const _wroughtIronMat = MeshMaterial(
    name: 'fence_wrought_iron',
    baseColorFactor: [0.014, 0.018, 0.024, 1.0],
    metallicFactor: 0.65,
    roughnessFactor: 0.38,
  );
  static const _wroughtIronColor = Color(0xFF1F242B);

  // --- Non-metallic Architectural Colors ---
  static const _pierBodyColor = Color(0xFFE6E1D8);
  static const _pierRevealColor = Color(0xFF64748B);
  static const _pierCapFlangeColor = Color(0xFFCBD5E1);
  static const _pierCapCrownColor = Color(0xFFB6C2CF);

  static const _plinthBodyColor = Color(0xFF9EA7B3);
  static const _plinthCapColor = Color(0xFFD5DCE4);

  static const _battenWoodColor = Color(0xFF6B4423);
  static const _boardPalette = <Color>[
    Color(0xFFB87B44),
    Color(0xFFA06736),
    Color(0xFFC48850),
    Color(0xFF965E30),
  ];

  static const _gabionCoreShadowColor = Color(0xFF3E3B37);
  static const _gabionStonePalette = <Color>[
    Color(0xFF9E9A92),
    Color(0xFF837E76),
    Color(0xFFB5AEA3),
    Color(0xFF706B63),
    Color(0xFFA6998A),
    Color(0xFF8F969C),
    Color(0xFFC2BBB0),
    Color(0xFF635F58),
  ];

  static const _rcFootingColor = Color(0xFF7D8793);
  static const _rcStemColor = Color(0xFF9AA5B4);
  static const _rcCapColor = Color(0xFFD1D8E0);
  static const _rcJointColor = Color(0xFF475569);
  static const _rcWeepPipeColor = Color(0xFF334155);
  static const _rcWeepBoreColor = Color(0xFF0F172A);

  /// Builds 3D triangles for [fence], grounded on [groundZAt].
  ///
  /// When [detailed] is false (used by architectural elevation projection),
  /// tiny sub-cobble stone boulders in gabions are omitted while retaining full
  /// structural slats, louvers, pickets, piers, and gabion wire-mesh cages.
  static List<Triangle3D> build(
    ArchitectSiteFence fence, {
    required double Function(Offset p) groundZAt,
    bool detailed = true,
  }) {
    final pts = _cleanChain(fence.points);
    if (pts.length < 2) return const [];

    final isClosed =
        fence.closed &&
        pts.length >= 3 &&
        (pts.last - pts.first).distance > 1e-4;
    final tris = <Triangle3D>[];

    switch (fence.preset) {
      case ArchitectSiteFencePreset.piersAndSlats:
        _buildPiersAndSlats(tris, fence, pts, isClosed, groundZAt);
      case ArchitectSiteFencePreset.gabionFence:
      case ArchitectSiteFencePreset.gabionRetaining:
        _buildGabion(tris, fence, pts, isClosed, groundZAt, detailed: detailed);
      case ArchitectSiteFencePreset.modernLouvers:
        _buildModernLouvers(tris, fence, pts, isClosed, groundZAt);
      case ArchitectSiteFencePreset.classicIron:
        _buildClassicIron(
          tris,
          fence,
          pts,
          isClosed,
          groundZAt,
          detailed: detailed,
        );
      case ArchitectSiteFencePreset.rcRetaining:
        _buildRcRetaining(
          tris,
          fence,
          pts,
          isClosed,
          groundZAt,
          detailed: detailed,
        );
    }

    return tris;
  }

  // ===========================================================================
  // 1. MASONRY PIERS + HORIZONTAL TIMBER BOARDS
  // ===========================================================================

  static void _buildPiersAndSlats(
    List<Triangle3D> tris,
    ArchitectSiteFence fence,
    List<Offset> pts,
    bool isClosed,
    double Function(Offset p) groundZAt,
  ) {
    final h = math.max(0.60, fence.height);
    final plinthH = fence.plinthHeight.clamp(0.18, h * 0.45);
    final halfT = math.max(0.08, fence.thickness * 0.5);
    final pierSize = math.max(fence.pierSize, math.max(halfT * 2.5, 0.34));
    final pierHalf = pierSize * 0.5;
    final plinthHalf = math.max(halfT * 0.92, 0.11);

    // 1. Continuous concrete plinth + overhanging cap ledge
    _addMiteredProfile(
      tris,
      pts: pts,
      isClosed: isClosed,
      leftBot: plinthHalf,
      rightBot: plinthHalf,
      leftTop: plinthHalf,
      rightTop: plinthHalf,
      zBotAt: (p) => groundZAt(p) - 0.10,
      zTopAt: (p) => groundZAt(p) + plinthH - 0.035,
      color: _plinthBodyColor,
    );
    _addMiteredProfile(
      tris,
      pts: pts,
      isClosed: isClosed,
      leftBot: plinthHalf + 0.015,
      rightBot: plinthHalf + 0.015,
      leftTop: plinthHalf + 0.015,
      rightTop: plinthHalf + 0.015,
      zBotAt: (p) => groundZAt(p) + plinthH - 0.035,
      zTopAt: (p) => groundZAt(p) + plinthH,
      color: _plinthCapColor,
    );

    // 2. Oriented masonry piers with reveal collar & stepped pyramid cap
    final plan = _planBays(pts, isClosed, fence.pierSpacing);
    for (final node in plan.nodes) {
      final gz = groundZAt(node.pos);
      _addMasonryPier(
        tris,
        center: node.pos,
        u: node.u,
        n: node.n,
        halfW: pierHalf,
        zGround: gz,
        height: h,
      );
    }

    // 3. Individual spaced horizontal timber boards per bay
    final zPanelBotOff = plinthH + 0.045;
    final zPanelTopOff = h - 0.10;
    if (zPanelTopOff <= zPanelBotOff + 0.06) return;

    const targetPitch = 0.145;
    const minGap = 0.026;
    final spanH = zPanelTopOff - zPanelBotOff;
    final count = math.max(2, (spanH / targetPitch).round());
    final gap = spanH / count > 0.09 ? 0.030 : minGap;
    final boardH = math.max(
      0.045,
      (spanH - gap * (count - 1)) / count,
    );
    const boardHalfThick = 0.017;

    for (var bIdx = 0; bIdx < plan.bays.length; bIdx++) {
      final bay = plan.bays[bIdx];
      final clearSpan = bay.length - pierSize;
      if (clearSpan < 0.10) continue;

      final pStart = bay.start + bay.u * (pierHalf - 0.005);
      final pEnd = bay.end - bay.u * (pierHalf - 0.005);
      final u = bay.u;
      final n = bay.n;
      final za = groundZAt(pStart);
      final zb = groundZAt(pEnd);

      // Side steel U-channel cleats at pier inner faces
      for (final edgeCenter in [
        pStart + u * 0.016,
        pEnd - u * 0.016,
      ]) {
        final ez = groundZAt(edgeCenter);
        _addOrientedBox(
          tris,
          center: edgeCenter,
          u: u,
          n: n,
          halfU: 0.014,
          halfN: 0.024,
          zBot: ez + plinthH,
          zTop: ez + zPanelTopOff,
          color: _anthraciteColor,
          material: _anthraciteMat,
        );
      }

      // Vertical backing batten at bay midpoint for long spans
      if (clearSpan > 1.35) {
        final mid = Offset.lerp(pStart, pEnd, 0.5)!;
        final mz = groundZAt(mid);
        _addOrientedBox(
          tris,
          center: mid - n * (boardHalfThick + 0.010),
          u: u,
          n: n,
          halfU: 0.018,
          halfN: 0.010,
          zBot: mz + zPanelBotOff,
          zTop: mz + zPanelTopOff,
          color: _battenWoodColor,
        );
      }

      // Discrete horizontal boards with deterministic plank tone variation
      for (var k = 0; k < count; k++) {
        final z0 = zPanelBotOff + k * (boardH + gap);
        final z1 = math.min(zPanelTopOff, z0 + boardH);
        if (z1 - z0 < 0.015) break;
        final boardColor =
            _boardPalette[(bIdx * 3 + k) % _boardPalette.length];
        _addSlopedBeam(
          tris,
          a: pStart,
          b: pEnd,
          n: n,
          halfThick: boardHalfThick,
          zBotA: za + z0,
          zTopA: za + z1,
          zBotB: zb + z0,
          zTopB: zb + z1,
          color: boardColor,
          includeEndCaps: false,
        );
      }
    }
  }

  // ===========================================================================
  // 2. GABION FENCE & GABION RETAINING WALL
  // ===========================================================================

  static void _buildGabion(
    List<Triangle3D> tris,
    ArchitectSiteFence fence,
    List<Offset> pts,
    bool isClosed,
    double Function(Offset p) groundZAt, {
    required bool detailed,
  }) {
    final h = math.max(0.45, fence.height);
    final halfT = math.max(0.14, fence.thickness * 0.5);
    final isRetaining = fence.preset == ArchitectSiteFencePreset.gabionRetaining;

    var totalLen = 0.0;
    final segCount = isClosed ? pts.length : pts.length - 1;
    for (var i = 0; i < segCount; i++) {
      totalLen += (pts[(i + 1) % pts.length] - pts[i]).distance;
    }
    if (totalLen < 0.05) return;

    // For tall retaining gabion walls, step upper course back like terraced cages.
    final steppedRetaining = isRetaining && h >= 0.90;
    final lowerTopOff = steppedRetaining ? h * 0.52 : h;
    final upperHalfT = steppedRetaining ? math.max(0.16, halfT * 0.68) : halfT;
    final upperShiftN = steppedRetaining ? (halfT - upperHalfT) * 0.65 : 0.0;

    if (isRetaining) {
      // Concrete levelling pad at toe/base
      _addMiteredProfile(
        tris,
        pts: pts,
        isClosed: isClosed,
        leftBot: halfT + 0.08,
        rightBot: halfT + 0.08,
        leftTop: halfT + 0.08,
        rightTop: halfT + 0.08,
        zBotAt: (p) => groundZAt(p) - 0.14,
        zTopAt: (p) => groundZAt(p) - 0.02,
        color: _plinthBodyColor,
      );
    }

    // Build lower basket course
    _buildGabionTier(
      tris,
      pts: pts,
      isClosed: isClosed,
      leftOffset: halfT,
      rightOffset: halfT,
      zBotOff: -0.02,
      zTopOff: lowerTopOff,
      groundZAt: groundZAt,
      totalLen: totalLen,
      tierIndex: 0,
      detailed: detailed,
      includeTopLid: !steppedRetaining,
    );

    if (steppedRetaining) {
      _buildGabionTier(
        tris,
        pts: pts,
        isClosed: isClosed,
        leftOffset: upperHalfT + upperShiftN,
        rightOffset: upperHalfT - upperShiftN,
        zBotOff: lowerTopOff,
        zTopOff: h,
        groundZAt: groundZAt,
        totalLen: totalLen,
        tierIndex: 1,
        detailed: detailed,
        includeTopLid: true,
      );
    }
  }

  static void _buildGabionTier(
    List<Triangle3D> tris, {
    required List<Offset> pts,
    required bool isClosed,
    required double leftOffset,
    required double rightOffset,
    required double zBotOff,
    required double zTopOff,
    required double Function(Offset p) groundZAt,
    required double totalLen,
    required int tierIndex,
    required bool detailed,
    required bool includeTopLid,
  }) {
    final tierH = zTopOff - zBotOff;
    if (tierH < 0.12) return;

    // 1. Dark recessed inner stone shadow bed (inset 2.8 cm inside cage wire)
    const inset = 0.028;
    final coreLeft = math.max(0.05, leftOffset - inset);
    final coreRight = math.max(0.05, rightOffset - inset);
    _addMiteredProfile(
      tris,
      pts: pts,
      isClosed: isClosed,
      leftBot: coreLeft,
      rightBot: coreRight,
      leftTop: coreLeft,
      rightTop: coreRight,
      zBotAt: (p) => groundZAt(p) + zBotOff + 0.015,
      zTopAt: (p) => groundZAt(p) + zTopOff - 0.018,
      color: _gabionCoreShadowColor,
    );

    // 2. Protruding faceted 3D stones + galvanized weldmesh cage per segment
    final segCount = isClosed ? pts.length : pts.length - 1;
    // Adapt boulder density gently on very long perimeter fences for smooth FPS.
    final pitchScale = totalLen > 24.0
        ? (totalLen / 24.0).clamp(1.0, 1.85)
        : 1.0;
    final rockPitchU = 0.21 * pitchScale;
    final rockPitchZ = 0.17 * math.min(pitchScale, 1.35);

    const wireHalf = 0.0045;
    const frameHalf = 0.0085;
    final cageLeft = leftOffset + 0.005;
    final cageRight = rightOffset + 0.005;
    final miterLeft = ArchitectPathway.offsetChain(
      pts,
      cageLeft,
      closed: isClosed,
    );
    final miterRight = ArchitectPathway.offsetChain(
      pts,
      -cageRight,
      closed: isClosed,
    );

    for (var s = 0; s < segCount; s++) {
      final nextIdx = (s + 1) % pts.length;
      final a = pts[s];
      final b = pts[nextIdx];
      final delta = b - a;
      final len = delta.distance;
      if (len < 0.08) continue;
      final u = delta / len;
      final n = Offset(-u.dy, u.dx);
      final za = groundZAt(a);
      final zb = groundZAt(b);

      // A. Faceted 3D quarry/river cobbles on both exposed faces (+n and -n)
      if (detailed && len > 0.22) {
        final zMin = zBotOff + 0.05;
        final zMax = zTopOff - 0.05;
        final rows = math.max(1, ((zMax - zMin) / rockPitchZ).floor());
        final rowStep = (zMax - zMin) / rows;
        final startTrim = math.min(0.11, len * 0.12);
        final usableLen = math.max(0.08, len - 2 * startTrim);

        for (var r = 0; r < rows; r++) {
          final zMidRel = zMin + (r + 0.5) * rowStep;
          final stagger = r.isOdd ? rockPitchU * 0.48 : 0.0;
          final cols = math.max(1, ((usableLen - stagger) / rockPitchU).floor());
          final colStep = (usableLen - stagger) / cols;

          for (var c = 0; c < cols; c++) {
            final along = startTrim + stagger + (c + 0.5) * colStep;
            final t = (along / len).clamp(0.0, 1.0);
            final zGroundHere = za + (zb - za) * t;
            final center2D = a + u * along;

            for (final sideSign in const [1.0, -1.0]) {
              final hVal = _hash4(
                s + tierIndex * 31,
                r,
                c,
                sideSign > 0 ? 1 : 2,
              );
              final jitterU = ((hVal & 0xF) / 15.0 - 0.5) * colStep * 0.16;
              final jitterZ =
                  (((hVal >> 4) & 0xF) / 15.0 - 0.5) * rowStep * 0.16;
              final sizeScale = 0.80 + (((hVal >> 8) & 0xF) / 15.0) * 0.28;
              final stoneColor = _gabionStonePalette[
                  (hVal >> 12) % _gabionStonePalette.length];

              final halfU = colStep * 0.44 * sizeScale;
              final halfZ = rowStep * 0.44 * sizeScale;
              final faceOut = sideSign > 0 ? leftOffset : rightOffset;
              final coreOut = sideSign > 0 ? coreLeft : coreRight;
              final protrude = faceOut - coreOut + 0.008;

              _addGabionCobble(
                tris,
                baseCenter: center2D +
                    u * jitterU +
                    n * (sideSign * (coreOut - 0.008)),
                zCenter: zGroundHere + zMidRel + jitterZ,
                u: u,
                outNormal: n * sideSign,
                halfU: halfU,
                halfZ: halfZ,
                protrude: protrude,
                hashBits: hVal,
                color: stoneColor,
              );
            }
          }

          // Open start / finish end cobbles so ends match the side faces
          if (!isClosed && (s == 0 || s == segCount - 1)) {
            final endSpecs = <(Offset endPt, double zEnd, Offset outDir, int seed)>[
              if (s == 0) (a, za, -u, 701),
              if (s == segCount - 1) (b, zb, u, 709),
            ];
            final spanN = (coreLeft + coreRight) * 0.86;
            final endCols = math.max(1, (spanN / 0.19).round());
            final endStepN = spanN / endCols;
            final nTan = Offset(-u.dy, u.dx);
            for (final (endPt, zEnd, outDir, seed) in endSpecs) {
              for (var ec = 0; ec < endCols; ec++) {
                final offN = -coreRight * 0.86 + (ec + 0.5) * endStepN;
                final hVal = _hash4(seed, tierIndex, r, ec);
                final stoneColor = _gabionStonePalette[
                    (hVal >> 12) % _gabionStonePalette.length];
                _addGabionCobble(
                  tris,
                  baseCenter: endPt + nTan * offN - outDir * 0.015,
                  zCenter: zEnd + zMidRel,
                  u: nTan,
                  outNormal: outDir,
                  halfU: endStepN * 0.43,
                  halfZ: rowStep * 0.42,
                  protrude: 0.022,
                  hashBits: hVal,
                  color: stoneColor,
                );
              }
            }
          }
        }

        // Top exposed cobble layer on uppermost basket surface
        if (includeTopLid) {
          final topCols = math.max(1, (usableLen / (rockPitchU * 1.05)).floor());
          final topStep = usableLen / topCols;
          final basketSpanN = leftOffset + rightOffset;
          final rowsN = math.max(1, (basketSpanN / 0.22).round());
          final stepN = (basketSpanN - 0.06) / rowsN;
          for (var c = 0; c < topCols; c++) {
            final along = startTrim + (c + 0.5) * topStep;
            final t = (along / len).clamp(0.0, 1.0);
            final zGroundHere = za + (zb - za) * t;
            final center2D = a + u * along;
            for (var rn = 0; rn < rowsN; rn++) {
              final offN =
                  -rightOffset + 0.03 + (rn + 0.5) * stepN;
              final hVal = _hash4(s + 97, tierIndex, c, rn);
              final stoneColor = _gabionStonePalette[
                  (hVal >> 12) % _gabionStonePalette.length];
              _addGabionCobble(
                tris,
                baseCenter: center2D + n * offN,
                zCenter: zGroundHere + zTopOff - 0.024,
                u: u,
                outNormal: Offset.zero,
                halfU: topStep * 0.42,
                halfZ: stepN * 0.42,
                protrude: 0.022,
                hashBits: hVal,
                color: stoneColor,
                upwardZ: true,
              );
            }
          }
        }
      }

      // B. Galvanized steel wire basket frames (~1.0 m compartments) & weldmesh
      final compartments = math.max(1, len.round());
      final cellLen = len / compartments;
      final wireStepZ = detailed ? 0.15 : 0.28;
      final wireStepU = detailed ? 0.16 : 0.30;
      final mlA = miterLeft[s];
      final mlB = miterLeft[nextIdx];
      final mrA = miterRight[s];
      final mrB = miterRight[nextIdx];

      // Top & bottom border rods on both mitered faces
      for (final zRod in [zBotOff + 0.012, zTopOff - 0.012]) {
        for (final (fa, fb) in [(mlA, mlB), (mrA, mrB)]) {
          _addSlopedBeam(
            tris,
            a: fa,
            b: fb,
            n: n,
            halfThick: frameHalf,
            zBotA: za + zRod - frameHalf,
            zTopA: za + zRod + frameHalf,
            zBotB: zb + zRod - frameHalf,
            zTopB: zb + zRod + frameHalf,
            color: _galvanizedWireColor,
            material: _galvanizedSteelMat,
          );
        }
      }

      // Intermediate horizontal welded wires on both mitered faces
      final hWireCount = math.max(1, ((tierH - 0.12) / wireStepZ).floor());
      final hStep = (tierH - 0.04) / (hWireCount + 1);
      for (var w = 1; w <= hWireCount; w++) {
        final zRod = zBotOff + 0.02 + w * hStep;
        for (final (fa, fb) in [(mlA, mlB), (mrA, mrB)]) {
          _addSlopedBeam(
            tris,
            a: fa,
            b: fb,
            n: n,
            halfThick: wireHalf,
            zBotA: za + zRod - wireHalf,
            zTopA: za + zRod + wireHalf,
            zBotB: zb + zRod - wireHalf,
            zTopB: zb + zRod + wireHalf,
            color: _galvanizedWireColor,
            material: _galvanizedSteelMat,
            includeEndCaps: false,
          );
        }
      }

      // Vertical heavy compartment ribs every ~1.0 m + fine vertical mesh wires
      final vWiresPerCell = math.max(2, (cellLen / wireStepU).round());
      final totalVWires = compartments * vWiresPerCell;
      for (var vw = 0; vw <= totalVWires; vw++) {
        final t = vw / totalVWires;
        final pos = Offset.lerp(a, b, t)!;
        final gz = za + (zb - za) * t;
        final isRib = vw % vWiresPerCell == 0;
        final rHalf = isRib ? frameHalf : wireHalf;
        final leftWirePos = Offset.lerp(mlA, mlB, t)!;
        final rightWirePos = Offset.lerp(mrA, mrB, t)!;

        for (final wPos in [leftWirePos, rightWirePos]) {
          _addOrientedBox(
            tris,
            center: wPos,
            u: u,
            n: n,
            halfU: rHalf,
            halfN: rHalf,
            zBot: gz + zBotOff,
            zTop: gz + zTopOff,
            color: _galvanizedWireColor,
            material: _galvanizedSteelMat,
          );
        }

        // Transverse cross-wire tying front & back faces at compartment ribs & top lid
        if (isRib) {
          final midN = (cageLeft - cageRight) * 0.5;
          final halfSpanN = (cageLeft + cageRight) * 0.5;
          for (final zTie in [zBotOff + 0.012, zTopOff - 0.012]) {
            _addOrientedBox(
              tris,
              center: pos + n * midN,
              u: u,
              n: n,
              halfU: frameHalf,
              halfN: halfSpanN,
              zBot: gz + zTie - frameHalf,
              zTop: gz + zTie + frameHalf,
              color: _galvanizedWireColor,
              material: _galvanizedSteelMat,
            );
          }
          // Close open fence end faces with transverse horizontal mesh wires
          if (!isClosed &&
              ((s == 0 && vw == 0) || (s == segCount - 1 && vw == totalVWires))) {
            for (var w = 1; w <= hWireCount; w++) {
              final zRod = zBotOff + 0.02 + w * hStep;
              _addOrientedBox(
                tris,
                center: pos + n * midN,
                u: u,
                n: n,
                halfU: wireHalf,
                halfN: halfSpanN,
                zBot: gz + zRod - wireHalf,
                zTop: gz + zRod + wireHalf,
                color: _galvanizedWireColor,
                material: _galvanizedSteelMat,
              );
            }
          }
        } else if (includeTopLid && detailed && vw.isEven) {
          final midN = (cageLeft - cageRight) * 0.5;
          final halfSpanN = (cageLeft + cageRight) * 0.5;
          _addOrientedBox(
            tris,
            center: pos + n * midN,
            u: u,
            n: n,
            halfU: wireHalf,
            halfN: halfSpanN,
            zBot: gz + zTopOff - wireHalf * 2,
            zTop: gz + zTopOff,
            color: _galvanizedWireColor,
            material: _galvanizedSteelMat,
          );
        }
      }
    }
  }

  // ===========================================================================
  // 3. MODERN TILTED LOUVER FENCE
  // ===========================================================================

  static void _buildModernLouvers(
    List<Triangle3D> tris,
    ArchitectSiteFence fence,
    List<Offset> pts,
    bool isClosed,
    double Function(Offset p) groundZAt,
  ) {
    final h = math.max(0.60, fence.height);
    final plinthH = fence.plinthHeight.clamp(0.14, math.min(0.30, h * 0.25));
    final halfT = math.max(0.06, fence.thickness * 0.5);
    final postSize = fence.pierSize.clamp(0.08, 0.14);
    final postHalf = postSize * 0.5;
    final plinthHalf = math.max(halfT * 0.85, postHalf + 0.015);

    // 1. Sleek low concrete kerb plinth
    _addMiteredProfile(
      tris,
      pts: pts,
      isClosed: isClosed,
      leftBot: plinthHalf,
      rightBot: plinthHalf,
      leftTop: plinthHalf,
      rightTop: plinthHalf,
      zBotAt: (p) => groundZAt(p) - 0.08,
      zTopAt: (p) => groundZAt(p) + plinthH,
      color: _plinthBodyColor,
    );

    // 2. Slim anthracite powder-coated steel posts + post cap plates
    final plan = _planBays(pts, isClosed, fence.pierSpacing);
    for (final node in plan.nodes) {
      final gz = groundZAt(node.pos);
      _addOrientedBox(
        tris,
        center: node.pos,
        u: node.u,
        n: node.n,
        halfU: postHalf,
        halfN: postHalf,
        zBot: gz - 0.08,
        zTop: gz + h - 0.016,
        color: _anthraciteColor,
        material: _anthraciteMat,
      );
      _addOrientedBox(
        tris,
        center: node.pos,
        u: node.u,
        n: node.n,
        halfU: postHalf + 0.012,
        halfN: postHalf + 0.012,
        zBot: gz + h - 0.016,
        zTop: gz + h,
        color: _anthraciteLouverColor,
        material: _anthraciteLouverMat,
      );
    }

    // 3. Top U-channel coping rail + tilted aluminum louver blades per bay
    final zBladeBot = plinthH + 0.035;
    final zBladeTop = h - 0.055;
    if (zBladeTop <= zBladeBot + 0.06) return;

    const pitch = 0.082;
    final count = math.max(3, ((zBladeTop - zBladeBot) / pitch).floor());
    final actualPitch = (zBladeTop - zBladeBot) / count;
    // 38-degree tilted slat cross section: depth along n ~ 0.086 m, rise in z ~ 0.058 m
    final bladeHalfSpanN = math.min(halfT * 0.72, 0.045);
    const tiltDz = 0.048;
    const bladeThickZ = 0.014;

    for (final bay in plan.bays) {
      if (bay.length - postSize < 0.10) continue;
      final pStart = bay.start + bay.u * (postHalf - 0.004);
      final pEnd = bay.end - bay.u * (postHalf - 0.004);
      final za = groundZAt(pStart);
      final zb = groundZAt(pEnd);

      // Top rail spanning post to post
      _addSlopedBeam(
        tris,
        a: pStart,
        b: pEnd,
        n: bay.n,
        halfThick: math.min(postHalf * 0.65, 0.030),
        zBotA: za + h - 0.045,
        zTopA: za + h - 0.010,
        zBotB: zb + h - 0.045,
        zTopB: zb + h - 0.010,
        color: _anthraciteColor,
        material: _anthraciteMat,
        includeEndCaps: false,
      );

      // Center vertical stiffener behind blades on wide bays
      if (bay.length > 1.55) {
        final mid = Offset.lerp(pStart, pEnd, 0.5)!;
        final mz = groundZAt(mid);
        _addOrientedBox(
          tris,
          center: mid,
          u: bay.u,
          n: bay.n,
          halfU: 0.012,
          halfN: 0.012,
          zBot: mz + plinthH,
          zTop: mz + h - 0.035,
          color: _anthraciteColor,
          material: _anthraciteMat,
        );
      }

      // Tilted louver slats
      for (var k = 0; k < count; k++) {
        final zMidOff = zBladeBot + (k + 0.5) * actualPitch;
        _addTiltedLouverBlade(
          tris,
          a: pStart,
          b: pEnd,
          n: bay.n,
          za: za + zMidOff,
          zb: zb + zMidOff,
          halfSpanN: bladeHalfSpanN,
          tiltDz: tiltDz,
          halfThickZ: bladeThickZ * 0.5,
          color: _anthraciteLouverColor,
          material: _anthraciteLouverMat,
        );
      }
    }
  }

  // ===========================================================================
  // 4. CLASSIC WROUGHT IRON + MASONRY PIERS
  // ===========================================================================

  static void _buildClassicIron(
    List<Triangle3D> tris,
    ArchitectSiteFence fence,
    List<Offset> pts,
    bool isClosed,
    double Function(Offset p) groundZAt, {
    required bool detailed,
  }) {
    final h = math.max(0.75, fence.height);
    final plinthH = fence.plinthHeight.clamp(0.20, h * 0.42);
    final halfT = math.max(0.08, fence.thickness * 0.5);
    final pierSize = math.max(fence.pierSize, math.max(halfT * 2.4, 0.34));
    final pierHalf = pierSize * 0.5;
    final plinthHalf = math.max(halfT * 0.90, 0.11);

    // 1. Plinth + cast stone coping
    _addMiteredProfile(
      tris,
      pts: pts,
      isClosed: isClosed,
      leftBot: plinthHalf,
      rightBot: plinthHalf,
      leftTop: plinthHalf,
      rightTop: plinthHalf,
      zBotAt: (p) => groundZAt(p) - 0.10,
      zTopAt: (p) => groundZAt(p) + plinthH - 0.035,
      color: _plinthBodyColor,
    );
    _addMiteredProfile(
      tris,
      pts: pts,
      isClosed: isClosed,
      leftBot: plinthHalf + 0.015,
      rightBot: plinthHalf + 0.015,
      leftTop: plinthHalf + 0.015,
      rightTop: plinthHalf + 0.015,
      zBotAt: (p) => groundZAt(p) + plinthH - 0.035,
      zTopAt: (p) => groundZAt(p) + plinthH,
      color: _plinthCapColor,
    );

    // 2. Oriented masonry piers
    final plan = _planBays(pts, isClosed, fence.pierSpacing);
    for (final node in plan.nodes) {
      _addMasonryPier(
        tris,
        center: node.pos,
        u: node.u,
        n: node.n,
        halfW: pierHalf,
        zGround: groundZAt(node.pos),
        height: h,
      );
    }

    // 3. Wrought iron rails, vertical pickets, spear finials, and lower dog-bars
    final zBotRailOff = plinthH + 0.10;
    final zTopRailOff = h - 0.22;
    if (zTopRailOff <= zBotRailOff + 0.22) return;
    final zLowDogRailOff = math.min(
      zBotRailOff + 0.24,
      zBotRailOff + (zTopRailOff - zBotRailOff) * 0.34,
    );
    final zSpearBaseOff = zTopRailOff + 0.08;
    final zSpearTipOff = zSpearBaseOff + 0.095;

    for (final bay in plan.bays) {
      final clearSpan = bay.length - pierSize;
      if (clearSpan < 0.16) continue;
      final pStart = bay.start + bay.u * (pierHalf - 0.004);
      final pEnd = bay.end - bay.u * (pierHalf - 0.004);
      final za = groundZAt(pStart);
      final zb = groundZAt(pEnd);

      // Horizontal wrought iron rails (bottom, dog-bar rail, top)
      for (final zRail in [zBotRailOff, zLowDogRailOff, zTopRailOff]) {
        _addSlopedBeam(
          tris,
          a: pStart,
          b: pEnd,
          n: bay.n,
          halfThick: 0.016,
          zBotA: za + zRail - 0.012,
          zTopA: za + zRail + 0.012,
          zBotB: zb + zRail - 0.012,
          zTopB: zb + zRail + 0.012,
          color: _wroughtIronColor,
          material: _wroughtIronMat,
          includeEndCaps: false,
        );
      }

      // Pickets evenly spaced inside clear opening
      final pitch = detailed ? 0.135 : 0.16;
      final picketCount = math.max(2, (clearSpan / pitch).floor());
      final step = clearSpan / (picketCount + 1);

      for (var i = 1; i <= picketCount; i++) {
        final pos = bay.start + bay.u * (pierHalf + i * step);
        final pz = groundZAt(pos);
        // Main vertical square picket shaft
        _addOrientedBox(
          tris,
          center: pos,
          u: bay.u,
          n: bay.n,
          halfU: 0.009,
          halfN: 0.009,
          zBot: pz + zBotRailOff - 0.02,
          zTop: pz + zSpearBaseOff,
          color: _wroughtIronColor,
          material: _wroughtIronMat,
        );
        // Decorative collar below spearhead
        _addOrientedBox(
          tris,
          center: pos,
          u: bay.u,
          n: bay.n,
          halfU: 0.016,
          halfN: 0.016,
          zBot: pz + zTopRailOff - 0.015,
          zTop: pz + zTopRailOff + 0.015,
          color: _wroughtIronColor,
          material: _wroughtIronMat,
        );
        // 4-sided diamond spearhead finial above top rail
        _addPyramidCap(
          tris,
          center: pos,
          u: bay.u,
          n: bay.n,
          botHalfU: 0.020,
          botHalfN: 0.018,
          topHalfU: 0.001,
          topHalfN: 0.001,
          zBot: pz + zSpearBaseOff,
          zTop: pz + zSpearTipOff,
          color: _wroughtIronColor,
          material: _wroughtIronMat,
        );
      }

      // Shorter intermediate dog-bars between main pickets in the lower band
      if (detailed) {
        for (var i = 0; i <= picketCount; i++) {
          final pos = bay.start + bay.u * (pierHalf + (i + 0.5) * step);
          final pz = groundZAt(pos);
          _addOrientedBox(
            tris,
            center: pos,
            u: bay.u,
            n: bay.n,
            halfU: 0.007,
            halfN: 0.007,
            zBot: pz + zBotRailOff,
            zTop: pz + zLowDogRailOff + 0.04,
            color: _wroughtIronColor,
            material: _wroughtIronMat,
          );
          _addPyramidCap(
            tris,
            center: pos,
            u: bay.u,
            n: bay.n,
            botHalfU: 0.013,
            botHalfN: 0.013,
            topHalfU: 0.001,
            topHalfN: 0.001,
            zBot: pz + zLowDogRailOff + 0.04,
            zTop: pz + zLowDogRailOff + 0.08,
            color: _wroughtIronColor,
            material: _wroughtIronMat,
          );
        }
      }
    }
  }

  // ===========================================================================
  // 5. REINFORCED CONCRETE RETAINING WALL
  // ===========================================================================

  static void _buildRcRetaining(
    List<Triangle3D> tris,
    ArchitectSiteFence fence,
    List<Offset> pts,
    bool isClosed,
    double Function(Offset p) groundZAt, {
    required bool detailed,
  }) {
    final h = math.max(0.50, fence.height);
    final halfTBot = math.max(0.11, fence.thickness * 0.5);
    // Keep back (+n) near vertical and batter front (-n) slope cleanly.
    final halfTTop = math.max(0.08, halfTBot * 0.72);
    final topBack = halfTBot * 0.94;
    final topFront = math.max(0.06, halfTTop * 2 - topBack);

    // 1. Protruding RC strip footing (heel on +n, toe on -n)
    _addMiteredProfile(
      tris,
      pts: pts,
      isClosed: isClosed,
      leftBot: halfTBot + 0.34,
      rightBot: halfTBot + 0.16,
      leftTop: halfTBot + 0.34,
      rightTop: halfTBot + 0.16,
      zBotAt: (p) => groundZAt(p) - 0.32,
      zTopAt: (p) => groundZAt(p) - 0.06,
      color: _rcFootingColor,
    );

    // 2. Tapered battered concrete stem wall
    _addMiteredProfile(
      tris,
      pts: pts,
      isClosed: isClosed,
      leftBot: halfTBot,
      rightBot: halfTBot,
      leftTop: topBack,
      rightTop: topFront,
      zBotAt: (p) => groundZAt(p) - 0.06,
      zTopAt: (p) => groundZAt(p) + h - 0.06,
      color: _rcStemColor,
    );

    // 3. Beveled/overhanging precast concrete coping cap
    _addMiteredProfile(
      tris,
      pts: pts,
      isClosed: isClosed,
      leftBot: topBack + 0.03,
      rightBot: topFront + 0.03,
      leftTop: topBack + 0.02,
      rightTop: topFront + 0.02,
      zBotAt: (p) => groundZAt(p) + h - 0.06,
      zTopAt: (p) => groundZAt(p) + h,
      color: _rcCapColor,
    );

    if (!detailed) return;

    // 4. Control joint reveals & front PVC weep-hole drainage pipes
    final segCount = isClosed ? pts.length : pts.length - 1;
    final batterRatio = (halfTBot - topFront) / math.max(0.25, h - 0.06);
    for (var s = 0; s < segCount; s++) {
      final a = pts[s];
      final b = pts[(s + 1) % pts.length];
      final delta = b - a;
      final len = delta.distance;
      if (len < 0.40) continue;
      final u = delta / len;
      final n = Offset(-u.dy, u.dx);
      final za = groundZAt(a);
      final zb = groundZAt(b);

      // Control joint shadow bands every ~3.0 m
      for (var d = 3.0; d < len - 0.40; d += 3.0) {
        final t = d / len;
        final p = Offset.lerp(a, b, t)!;
        final gz = za + (zb - za) * t;
        _addOrientedBox(
          tris,
          center: p,
          u: u,
          n: n,
          halfU: 0.012,
          halfN: halfTBot + 0.004,
          zBot: gz,
          zTop: gz + h - 0.06,
          color: _rcJointColor,
        );
      }

      // Weep hole drainage pipes along the battered front (-n) face
      final weepZOff = math.min(0.26, h * 0.35);
      final frontFaceOut = halfTBot - batterRatio * weepZOff;
      for (var d = 0.90; d < len - 0.35; d += 1.80) {
        final t = d / len;
        final p = Offset.lerp(a, b, t)! - n * (frontFaceOut + 0.008);
        final gz = za + (zb - za) * t;
        _addOrientedBox(
          tris,
          center: p,
          u: u,
          n: n,
          halfU: 0.028,
          halfN: 0.018,
          zBot: gz + weepZOff - 0.028,
          zTop: gz + weepZOff + 0.028,
          color: _rcWeepPipeColor,
        );
        _addOrientedBox(
          tris,
          center: p - n * 0.010,
          u: u,
          n: n,
          halfU: 0.016,
          halfN: 0.012,
          zBot: gz + weepZOff - 0.016,
          zTop: gz + weepZOff + 0.016,
          color: _rcWeepBoreColor,
        );
      }
    }
  }

  // ===========================================================================
  // 6. SHARED PRISM, PIER, BAY & HASH HELPERS
  // ===========================================================================

  static void _addMasonryPier(
    List<Triangle3D> tris, {
    required Offset center,
    required Offset u,
    required Offset n,
    required double halfW,
    required double zGround,
    required double height,
  }) {
    final zShaftTop = zGround + math.max(0.25, height - 0.075);
    final zNeckTop = zShaftTop + 0.015;
    final zFlangeTop = zNeckTop + 0.025;
    final zPeak = zGround + height;

    // Pier masonry shaft
    _addOrientedBox(
      tris,
      center: center,
      u: u,
      n: n,
      halfU: halfW,
      halfN: halfW,
      zBot: zGround - 0.10,
      zTop: zShaftTop,
      color: _pierBodyColor,
    );
    // Dark shadow reveal collar under cap
    _addOrientedBox(
      tris,
      center: center,
      u: u,
      n: n,
      halfU: math.max(0.04, halfW - 0.012),
      halfN: math.max(0.04, halfW - 0.012),
      zBot: zShaftTop,
      zTop: zNeckTop,
      color: _pierRevealColor,
    );
    // Overhanging precast coping flange
    final capHalf = halfW + 0.036;
    _addOrientedBox(
      tris,
      center: center,
      u: u,
      n: n,
      halfU: capHalf,
      halfN: capHalf,
      zBot: zNeckTop,
      zTop: zFlangeTop,
      color: _pierCapFlangeColor,
    );
    // Beveled pyramid cap crown
    _addPyramidCap(
      tris,
      center: center,
      u: u,
      n: n,
      botHalfU: capHalf,
      botHalfN: capHalf,
      topHalfU: halfW * 0.32,
      topHalfN: halfW * 0.32,
      zBot: zFlangeTop,
      zTop: zPeak,
      color: _pierCapCrownColor,
    );
  }

  static _FenceBayPlan _planBays(
    List<Offset> pts,
    bool isClosed,
    double pierSpacing,
  ) {
    final safeSpacing = math.max(0.80, pierSpacing);
    final segCount = isClosed ? pts.length : pts.length - 1;
    final bays = <_FenceBay>[];
    final nodes = <_FenceNode>[];

    // Segment unit vectors
    final segDirs = <Offset>[];
    for (var i = 0; i < segCount; i++) {
      final d = pts[(i + 1) % pts.length] - pts[i];
      final len = d.distance;
      segDirs.add(len > 1e-6 ? d / len : const Offset(1, 0));
    }

    for (var i = 0; i < segCount; i++) {
      final a = pts[i];
      final b = pts[(i + 1) % pts.length];
      final d = b - a;
      final len = d.distance;
      if (len < 1e-4) continue;
      final u = d / len;
      final n = Offset(-u.dy, u.dx);

      // Node at segment start vertex (avoid duplicate corner pier; square off ~90° bends)
      final hasPrev = i > 0 || isClosed;
      Offset nodeU = u;
      if (hasPrev) {
        final prevU = segDirs[(i - 1 + segCount) % segCount];
        final dot = prevU.dx * u.dx + prevU.dy * u.dy;
        if (dot > 0.65) {
          final avg = prevU + u;
          final avgLen = avg.distance;
          if (avgLen > 1e-4) nodeU = avg / avgLen;
        } else {
          nodeU = prevU;
        }
      }
      nodes.add(_FenceNode(a, nodeU, Offset(-nodeU.dy, nodeU.dx)));

      final bayCount = math.max(1, (len / safeSpacing).round());
      for (var k = 0; k < bayCount; k++) {
        final s = Offset.lerp(a, b, k / bayCount)!;
        final e = Offset.lerp(a, b, (k + 1) / bayCount)!;
        bays.add(_FenceBay(s, e, u, n, len / bayCount));
        if (k > 0) {
          nodes.add(_FenceNode(s, u, n));
        }
      }
    }

    if (!isClosed && segCount > 0) {
      final lastU = segDirs.last;
      nodes.add(_FenceNode(pts.last, lastU, Offset(-lastU.dy, lastU.dx)));
    }

    return _FenceBayPlan(nodes, bays);
  }

  /// Adds an irregular faceted stone cobble prism protruding along [outNormal]
  /// (or vertically +Z when [upwardZ] is true) so gabions display deep stone relief.
  static void _addGabionCobble(
    List<Triangle3D> tris, {
    required Offset baseCenter,
    required double zCenter,
    required Offset u,
    required Offset outNormal,
    required double halfU,
    required double halfZ,
    required double protrude,
    required int hashBits,
    required Color color,
    bool upwardZ = false,
  }) {
    if (protrude < 0.004) return;
    // Slight deterministic taper & asymmetry so stones don't look like bricks
    final taper = 0.62 + ((hashBits >> 16) & 0x7) / 7.0 * 0.14;
    final tipShiftU = (((hashBits >> 19) & 0x7) / 7.0 - 0.5) * halfU * 0.25;
    final tipShiftV = (((hashBits >> 22) & 0x7) / 7.0 - 0.5) * halfZ * 0.25;

    final baseOrigin = Vector3(baseCenter.dx, baseCenter.dy, zCenter);
    final axisU = Vector3(u.dx, u.dy, 0);
    final axisV = upwardZ
        ? Vector3(-u.dy, u.dx, 0)
        : const Vector3(0, 0, 1);
    final axisOut = upwardZ
        ? const Vector3(0, 0, 1)
        : Vector3(outNormal.dx, outNormal.dy, 0);

    final tipOrigin =
        baseOrigin + axisOut * protrude + axisU * tipShiftU + axisV * tipShiftV;
    final center = (baseOrigin + tipOrigin) * 0.5;

    // 6-sided faceted boulder cross-section (cut corners = natural stone silhouette)
    const rx = [1.0, 0.52, -0.52, -1.0, -0.52, 0.52];
    const ry = [0.0, 0.90, 0.90, 0.0, -0.90, -0.90];
    final bot = <Vector3>[];
    final top = <Vector3>[];
    for (var i = 0; i < 6; i++) {
      final sx = rx[i] * halfU;
      final sy = ry[i] * halfZ;
      bot.add(baseOrigin + axisU * sx + axisV * sy);
      top.add(tipOrigin + axisU * (sx * taper) + axisV * (sy * taper));
    }

    for (var i = 0; i < 6; i++) {
      final j = (i + 1) % 6;
      _addOutwardQuad(tris, bot[i], bot[j], top[j], top[i], center, color);
    }
    // Outer stone face triangle fan (no need for hidden rear base cap in core)
    final tipCenter = tipOrigin;
    for (var i = 0; i < 6; i++) {
      final j = (i + 1) % 6;
      _addOutwardTri(tris, tipCenter, top[i], top[j], center, color);
    }
  }

  static void _addMiteredProfile(
    List<Triangle3D> tris, {
    required List<Offset> pts,
    required bool isClosed,
    required double leftBot,
    required double rightBot,
    required double leftTop,
    required double rightTop,
    required double Function(Offset p) zBotAt,
    required double Function(Offset p) zTopAt,
    required Color color,
    MeshMaterial? material,
  }) {
    final lb = ArchitectPathway.offsetChain(pts, leftBot, closed: isClosed);
    final rb = ArchitectPathway.offsetChain(pts, -rightBot, closed: isClosed);
    final lt = ArchitectPathway.offsetChain(pts, leftTop, closed: isClosed);
    final rt = ArchitectPathway.offsetChain(pts, -rightTop, closed: isClosed);

    final segCount = isClosed ? pts.length : pts.length - 1;
    for (var i = 0; i < segCount; i++) {
      final j = (i + 1) % pts.length;
      final zB0 = zBotAt(pts[i]);
      final zB1 = zBotAt(pts[j]);
      final zT0 = zTopAt(pts[i]);
      final zT1 = zTopAt(pts[j]);
      if ((zT0 - zB0).abs() < 1e-5 && (zT1 - zB1).abs() < 1e-5) continue;

      final bl0 = Vector3(lb[i].dx, lb[i].dy, zB0);
      final bl1 = Vector3(lb[j].dx, lb[j].dy, zB1);
      final br0 = Vector3(rb[i].dx, rb[i].dy, zB0);
      final br1 = Vector3(rb[j].dx, rb[j].dy, zB1);
      final tl0 = Vector3(lt[i].dx, lt[i].dy, zT0);
      final tl1 = Vector3(lt[j].dx, lt[j].dy, zT1);
      final tr0 = Vector3(rt[i].dx, rt[i].dy, zT0);
      final tr1 = Vector3(rt[j].dx, rt[j].dy, zT1);

      final c = (bl0 + bl1 + br0 + br1 + tl0 + tl1 + tr0 + tr1) * 0.125;

      // Top, Bottom, Left (+n), Right (-n)
      _addOutwardQuad(tris, tl0, tr0, tr1, tl1, c, color, material: material);
      _addOutwardQuad(tris, bl0, bl1, br1, br0, c, color, material: material);
      _addOutwardQuad(tris, bl0, tl0, tl1, bl1, c, color, material: material);
      _addOutwardQuad(tris, br0, br1, tr1, tr0, c, color, material: material);

      if (!isClosed && i == 0) {
        _addOutwardQuad(tris, bl0, br0, tr0, tl0, c, color, material: material);
      }
      if (!isClosed && i == segCount - 1) {
        _addOutwardQuad(tris, bl1, tl1, tr1, br1, c, color, material: material);
      }
    }
  }

  static void _addOrientedBox(
    List<Triangle3D> tris, {
    required Offset center,
    required Offset u,
    required Offset n,
    required double halfU,
    required double halfN,
    required double zBot,
    required double zTop,
    required Color color,
    MeshMaterial? material,
  }) => _addPyramidCap(
    tris,
    center: center,
    u: u,
    n: n,
    botHalfU: halfU,
    botHalfN: halfN,
    topHalfU: halfU,
    topHalfN: halfN,
    zBot: zBot,
    zTop: zTop,
    color: color,
    material: material,
  );

  static void _addPyramidCap(
    List<Triangle3D> tris, {
    required Offset center,
    required Offset u,
    required Offset n,
    required double botHalfU,
    required double botHalfN,
    required double topHalfU,
    required double topHalfN,
    required double zBot,
    required double zTop,
    required Color color,
    MeshMaterial? material,
  }) {
    if (zTop - zBot < 1e-5) return;
    Offset pt(double su, double sn) => center + u * su + n * sn;
    final b0 = pt(-botHalfU, -botHalfN);
    final b1 = pt(botHalfU, -botHalfN);
    final b2 = pt(botHalfU, botHalfN);
    final b3 = pt(-botHalfU, botHalfN);
    final t0 = pt(-topHalfU, -topHalfN);
    final t1 = pt(topHalfU, -topHalfN);
    final t2 = pt(topHalfU, topHalfN);
    final t3 = pt(-topHalfU, topHalfN);

    final vb0 = Vector3(b0.dx, b0.dy, zBot);
    final vb1 = Vector3(b1.dx, b1.dy, zBot);
    final vb2 = Vector3(b2.dx, b2.dy, zBot);
    final vb3 = Vector3(b3.dx, b3.dy, zBot);
    final vt0 = Vector3(t0.dx, t0.dy, zTop);
    final vt1 = Vector3(t1.dx, t1.dy, zTop);
    final vt2 = Vector3(t2.dx, t2.dy, zTop);
    final vt3 = Vector3(t3.dx, t3.dy, zTop);

    final c = Vector3(center.dx, center.dy, (zBot + zTop) * 0.5);
    _addOutwardQuad(tris, vb0, vb1, vt1, vt0, c, color, material: material);
    _addOutwardQuad(tris, vb1, vb2, vt2, vt1, c, color, material: material);
    _addOutwardQuad(tris, vb2, vb3, vt3, vt2, c, color, material: material);
    _addOutwardQuad(tris, vb3, vb0, vt0, vt3, c, color, material: material);
    if (topHalfU > 0.002 && topHalfN > 0.002) {
      _addOutwardQuad(tris, vt0, vt1, vt2, vt3, c, color, material: material);
    }
    _addOutwardQuad(tris, vb0, vb3, vb2, vb1, c, color, material: material);
  }

  static void _addSlopedBeam(
    List<Triangle3D> tris, {
    required Offset a,
    required Offset b,
    required Offset n,
    required double halfThick,
    required double zBotA,
    required double zTopA,
    required double zBotB,
    required double zTopB,
    required Color color,
    MeshMaterial? material,
    bool includeEndCaps = true,
  }) {
    if ((b - a).distance < 1e-5) return;
    final al = a + n * halfThick;
    final ar = a - n * halfThick;
    final bl = b + n * halfThick;
    final br = b - n * halfThick;

    final abl = Vector3(al.dx, al.dy, zBotA);
    final abr = Vector3(ar.dx, ar.dy, zBotA);
    final atl = Vector3(al.dx, al.dy, zTopA);
    final atr = Vector3(ar.dx, ar.dy, zTopA);
    final bbl = Vector3(bl.dx, bl.dy, zBotB);
    final bbr = Vector3(br.dx, br.dy, zBotB);
    final btl = Vector3(bl.dx, bl.dy, zTopB);
    final btr = Vector3(br.dx, br.dy, zTopB);

    final c = (abl + abr + atl + atr + bbl + bbr + btl + btr) * 0.125;
    _addOutwardQuad(tris, atl, atr, btr, btl, c, color, material: material);
    _addOutwardQuad(tris, abl, bbl, bbr, abr, c, color, material: material);
    _addOutwardQuad(tris, abl, atl, btl, bbl, c, color, material: material);
    _addOutwardQuad(tris, abr, bbr, btr, atr, c, color, material: material);
    if (includeEndCaps) {
      _addOutwardQuad(tris, abl, abr, atr, atl, c, color, material: material);
      _addOutwardQuad(tris, bbl, btl, btr, bbr, c, color, material: material);
    }
  }

  /// Adds a rectangular louver blade tilted across [n] so top edge leans toward +n
  /// and lower edge toward -n (~38° louver slant).
  static void _addTiltedLouverBlade(
    List<Triangle3D> tris, {
    required Offset a,
    required Offset b,
    required Offset n,
    required double za,
    required double zb,
    required double halfSpanN,
    required double tiltDz,
    required double halfThickZ,
    required Color color,
    MeshMaterial? material,
  }) {
    if ((b - a).distance < 1e-5) return;
    final al = a + n * halfSpanN;
    final ar = a - n * halfSpanN;
    final bl = b + n * halfSpanN;
    final br = b - n * halfSpanN;

    final zLa = za + tiltDz * 0.5;
    final zRa = za - tiltDz * 0.5;
    final zLb = zb + tiltDz * 0.5;
    final zRb = zb - tiltDz * 0.5;

    final abl = Vector3(al.dx, al.dy, zLa - halfThickZ);
    final atl = Vector3(al.dx, al.dy, zLa + halfThickZ);
    final abr = Vector3(ar.dx, ar.dy, zRa - halfThickZ);
    final atr = Vector3(ar.dx, ar.dy, zRa + halfThickZ);

    final bbl = Vector3(bl.dx, bl.dy, zLb - halfThickZ);
    final btl = Vector3(bl.dx, bl.dy, zLb + halfThickZ);
    final bbr = Vector3(br.dx, br.dy, zRb - halfThickZ);
    final btr = Vector3(br.dx, br.dy, zRb + halfThickZ);

    final c = (abl + atl + abr + atr + bbl + btl + bbr + btr) * 0.125;
    _addOutwardQuad(tris, atl, atr, btr, btl, c, color, material: material);
    _addOutwardQuad(tris, abl, bbl, bbr, abr, c, color, material: material);
    _addOutwardQuad(tris, abl, atl, btl, bbl, c, color, material: material);
    _addOutwardQuad(tris, abr, bbr, btr, atr, c, color, material: material);
  }

  static void _addOutwardQuad(
    List<Triangle3D> tris,
    Vector3 a,
    Vector3 b,
    Vector3 c,
    Vector3 d,
    Vector3 volumeCenter,
    Color color, {
    MeshMaterial? material,
  }) {
    _addOutwardTri(tris, a, b, c, volumeCenter, color, material: material);
    _addOutwardTri(tris, a, c, d, volumeCenter, color, material: material);
  }

  static void _addOutwardTri(
    List<Triangle3D> tris,
    Vector3 a,
    Vector3 b,
    Vector3 c,
    Vector3 volumeCenter,
    Color color, {
    MeshMaterial? material,
  }) {
    final e1 = b - a;
    final e2 = c - a;
    final n = e1.cross(e2);
    if (n.lengthSquared < 1e-14) return;
    final mid = (a + b + c) / 3.0;
    if (n.dot(mid - volumeCenter) >= 0) {
      tris.add(
        Triangle3D(v0: a, v1: b, v2: c, color: color, material: material),
      );
    } else {
      tris.add(
        Triangle3D(v0: a, v1: c, v2: b, color: color, material: material),
      );
    }
  }

  static List<Offset> _cleanChain(List<Offset> points) {
    final out = <Offset>[];
    for (final p in points) {
      if (out.isEmpty || (p - out.last).distance > 1e-4) {
        out.add(p);
      }
    }
    return out;
  }

  static int _hash4(int a, int b, int c, int d) {
    var h = 0x811C9DC5;
    h = ((h ^ a) * 0x01000193) & 0x7FFFFFFF;
    h = ((h ^ b) * 0x01000193) & 0x7FFFFFFF;
    h = ((h ^ c) * 0x01000193) & 0x7FFFFFFF;
    h = ((h ^ d) * 0x01000193) & 0x7FFFFFFF;
    h ^= h >> 13;
    h = (h * 0x5BD1E995) & 0x7FFFFFFF;
    return h ^ (h >> 15);
  }
}

class _FenceNode {
  final Offset pos;
  final Offset u;
  final Offset n;
  const _FenceNode(this.pos, this.u, this.n);
}

class _FenceBay {
  final Offset start;
  final Offset end;
  final Offset u;
  final Offset n;
  final double length;
  const _FenceBay(this.start, this.end, this.u, this.n, this.length);
}

class _FenceBayPlan {
  final List<_FenceNode> nodes;
  final List<_FenceBay> bays;
  const _FenceBayPlan(this.nodes, this.bays);
}
