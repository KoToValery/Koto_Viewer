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

  /// Builds 3D triangles for [fence], grounded on [groundZAt] (and optional
  /// nullable [tryGroundZAt] so transverse probes over cutout holes are ignored
  /// instead of pulling the fence down to a fallback datum).
  ///
  /// When [detailed] is false (used by architectural elevation projection),
  /// tiny sub-cobble stone boulders in gabions are omitted while retaining full
  /// structural slats, louvers, pickets, piers, and gabion wire-mesh cages.
  static List<Triangle3D> build(
    ArchitectSiteFence fence, {
    required double Function(Offset p) groundZAt,
    double? Function(Offset p)? tryGroundZAt,
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
        _buildPiersAndSlats(
          tris,
          fence,
          pts,
          isClosed,
          groundZAt,
          tryGroundZAt: tryGroundZAt,
        );
      case ArchitectSiteFencePreset.gabionFence:
      case ArchitectSiteFencePreset.gabionRetaining:
        _buildGabion(
          tris,
          fence,
          pts,
          isClosed,
          groundZAt,
          tryGroundZAt: tryGroundZAt,
          detailed: detailed,
        );
      case ArchitectSiteFencePreset.modernLouvers:
        _buildModernLouvers(
          tris,
          fence,
          pts,
          isClosed,
          groundZAt,
          tryGroundZAt: tryGroundZAt,
        );
      case ArchitectSiteFencePreset.classicIron:
        _buildClassicIron(
          tris,
          fence,
          pts,
          isClosed,
          groundZAt,
          tryGroundZAt: tryGroundZAt,
          detailed: detailed,
        );
      case ArchitectSiteFencePreset.rcRetaining:
        _buildRcRetaining(
          tris,
          fence,
          pts,
          isClosed,
          groundZAt,
          tryGroundZAt: tryGroundZAt,
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
    double Function(Offset p) groundZAt, {
    double? Function(Offset p)? tryGroundZAt,
  }) {
    final h = math.max(0.60, fence.height);
    final plinthH = fence.plinthHeight.clamp(0.18, h * 0.45);
    final halfT = math.max(0.08, fence.thickness * 0.5);
    final pierSize = math.max(fence.pierSize, math.max(halfT * 2.5, 0.34));
    final pierHalf = pierSize * 0.5;
    final plinthHalf = math.max(halfT * 0.92, 0.11);
    final probeOffset = math.max(plinthHalf, pierHalf) + 0.10;
    final isStepped = fence.slopeMode == ArchitectFenceSlopeMode.stepped;
    const embed = 0.20;

    final plan = _planBays(pts, isClosed, fence.pierSpacing);
    final grounding = _samplePlanGrounding(
      plan,
      probeOffset: probeOffset,
      groundZAt: groundZAt,
      tryGroundZAt: tryGroundZAt,
    );

    // 1. Bay-segmented concrete plinth + overhanging cap ledge
    for (var bIdx = 0; bIdx < plan.bays.length; bIdx++) {
      final bay = plan.bays[bIdx];
      final bGround = grounding.bays[bIdx];
      final trim = math.min(pierHalf - 0.01, bay.length * 0.25);
      if (bay.length - 2 * trim < 0.04) continue;
      final pStart = bay.start + bay.u * trim;
      final pEnd = bay.end - bay.u * trim;

      if (isStepped) {
        final zBot = bGround.zLowMin - embed;
        final zBodyTop = bGround.zHighMax + plinthH - 0.035;
        final zCapTop = bGround.zHighMax + plinthH;
        _addSlopedBeam(
          tris,
          a: pStart,
          b: pEnd,
          n: bay.n,
          halfThick: plinthHalf,
          zBotA: zBot,
          zTopA: zBodyTop,
          zBotB: zBot,
          zTopB: zBodyTop,
          color: _plinthBodyColor,
        );
        _addSlopedBeam(
          tris,
          a: pStart,
          b: pEnd,
          n: bay.n,
          halfThick: plinthHalf + 0.015,
          zBotA: zBodyTop,
          zTopA: zCapTop,
          zBotB: zBodyTop,
          zTopB: zCapTop,
          color: _plinthCapColor,
        );
      } else {
        final t0 = trim / bay.length;
        final t1 = 1.0 - t0;
        _addSegmentedBayBeam(
          tris,
          bay: bay,
          bGround: bGround,
          tStart: t0,
          tEnd: t1,
          halfThick: plinthHalf,
          zBotFromLow: -embed,
          zTopFromHigh: plinthH - 0.035,
          color: _plinthBodyColor,
        );
        _addSegmentedBayBeam(
          tris,
          bay: bay,
          bGround: bGround,
          tStart: t0,
          tEnd: t1,
          halfThick: plinthHalf + 0.015,
          zBotFromLow: plinthH - 0.035,
          zTopFromHigh: plinthH,
          useHighForBot: true,
          color: _plinthCapColor,
        );
      }
    }

    // 2. Oriented masonry piers with reveal collar & stepped pyramid cap
    for (var nIdx = 0; nIdx < plan.nodes.length; nIdx++) {
      final node = plan.nodes[nIdx];
      final span = grounding.nodeSpan(
        nIdx,
        stepped: isStepped,
        embed: embed,
        height: h,
      );
      _addMasonryPier(
        tris,
        center: node.pos,
        u: node.u,
        n: node.n,
        halfW: pierHalf,
        zBot: span.zBot,
        zTop: span.zTop,
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
      final bGround = grounding.bays[bIdx];
      final clearSpan = bay.length - pierSize;
      if (clearSpan < 0.10) continue;

      final edgeInset = pierHalf - 0.005;
      final pStart = bay.start + bay.u * edgeInset;
      final pEnd = bay.end - bay.u * edgeInset;
      final u = bay.u;
      final n = bay.n;
      final tStart = (edgeInset / bay.length).clamp(0.0, 0.45);
      final tEnd = (1.0 - tStart).clamp(0.55, 1.0);
      final za = isStepped
          ? bGround.zHighMax
          : bGround.sampleAtT(tStart).zHigh;
      final zb = isStepped ? bGround.zHighMax : bGround.sampleAtT(tEnd).zHigh;

      // Side steel U-channel cleats at pier inner faces
      for (final (edgeCenter, ez) in [
        (pStart + u * 0.016, za),
        (pEnd - u * 0.016, zb),
      ]) {
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
        final mz = isStepped ? bGround.zHighMax : bGround.sampleAtT(0.5).zHigh;
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
    double? Function(Offset p)? tryGroundZAt,
    required bool detailed,
  }) {
    final h = math.max(0.45, fence.height);
    final halfT = math.max(0.14, fence.thickness * 0.5);
    final isRetaining = fence.preset == ArchitectSiteFencePreset.gabionRetaining;
    final isStepped = fence.slopeMode == ArchitectFenceSlopeMode.stepped;

    var totalLen = 0.0;
    final segCount = isClosed ? pts.length : pts.length - 1;
    for (var i = 0; i < segCount; i++) {
      totalLen += (pts[(i + 1) % pts.length] - pts[i]).distance;
    }
    if (totalLen < 0.05) return;

    final plan = _planBays(pts, isClosed, math.max(1.20, fence.pierSpacing));
    final grounding = _samplePlanGrounding(
      plan,
      probeOffset: halfT + 0.12,
      groundZAt: groundZAt,
      tryGroundZAt: tryGroundZAt,
    );

    // For tall retaining gabion walls, step upper course back like terraced cages.
    final steppedRetaining = isRetaining && h >= 0.90;
    final lowerTopOff = steppedRetaining ? h * 0.52 : h;
    final upperHalfT = steppedRetaining ? math.max(0.16, halfT * 0.68) : halfT;
    final upperShiftN = steppedRetaining ? (halfT - upperHalfT) * 0.65 : 0.0;

    if (isRetaining) {
      // Concrete levelling pad at toe/base (bay-stepped or sloped)
      final padHalf = halfT + 0.08;
      final miterPadL = ArchitectPathway.offsetChain(
        pts,
        padHalf,
        closed: isClosed,
      );
      final miterPadR = ArchitectPathway.offsetChain(
        pts,
        -padHalf,
        closed: isClosed,
      );
      for (var bIdx = 0; bIdx < plan.bays.length; bIdx++) {
        final bay = plan.bays[bIdx];
        final bGround = grounding.bays[bIdx];
        final (lA, lB) = _bayOffsetEndpoints(bay, miterPadL, padHalf);
        final (rA, rB) = _bayOffsetEndpoints(bay, miterPadR, -padHalf);
        final zBotA = isStepped
            ? bGround.zLowMin - 0.14
            : bGround.samples.first.zLow - 0.14;
        final zBotB = isStepped
            ? bGround.zLowMin - 0.14
            : bGround.samples.last.zLow - 0.14;
        _addPrismSpan(
          tris,
          bl0: lA,
          bl1: lB,
          br0: rA,
          br1: rB,
          tl0: lA,
          tl1: lB,
          tr0: rA,
          tr1: rB,
          zB0: zBotA,
          zB1: zBotB,
          zT0: zBotA + 0.12,
          zT1: zBotB + 0.12,
          color: _plinthBodyColor,
          capStart: !isClosed && bIdx == 0 || isStepped,
          capEnd: !isClosed && bIdx == plan.bays.length - 1 || isStepped,
        );
      }
    }

    // Build lower basket course
    _buildGabionTier(
      tris,
      pts: pts,
      isClosed: isClosed,
      plan: plan,
      grounding: grounding,
      isStepped: isStepped,
      leftOffset: halfT,
      rightOffset: halfT,
      zBotOff: -0.02,
      zTopOff: lowerTopOff,
      botFollowsHigh: false,
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
        plan: plan,
        grounding: grounding,
        isStepped: isStepped,
        leftOffset: upperHalfT + upperShiftN,
        rightOffset: upperHalfT - upperShiftN,
        zBotOff: lowerTopOff,
        zTopOff: h,
        botFollowsHigh: true,
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
    required _FenceBayPlan plan,
    required _PlanGrounding grounding,
    required bool isStepped,
    required double leftOffset,
    required double rightOffset,
    required double zBotOff,
    required double zTopOff,
    required bool botFollowsHigh,
    required double totalLen,
    required int tierIndex,
    required bool detailed,
    required bool includeTopLid,
  }) {
    final tierH = zTopOff - zBotOff;
    if (tierH < 0.12 || plan.bays.isEmpty) return;

    const inset = 0.028;
    final coreLeft = math.max(0.05, leftOffset - inset);
    final coreRight = math.max(0.05, rightOffset - inset);
    final miterCoreL = ArchitectPathway.offsetChain(
      pts,
      coreLeft,
      closed: isClosed,
    );
    final miterCoreR = ArchitectPathway.offsetChain(
      pts,
      -coreRight,
      closed: isClosed,
    );

    const wireHalf = 0.0045;
    const frameHalf = 0.0085;
    final cageLeft = leftOffset + 0.005;
    final cageRight = rightOffset + 0.005;
    final miterCageL = ArchitectPathway.offsetChain(
      pts,
      cageLeft,
      closed: isClosed,
    );
    final miterCageR = ArchitectPathway.offsetChain(
      pts,
      -cageRight,
      closed: isClosed,
    );

    // Adapt boulder density gently on very long perimeter fences for smooth FPS.
    final pitchScale = totalLen > 24.0
        ? (totalLen / 24.0).clamp(1.0, 1.85)
        : 1.0;
    final rockPitchU = 0.21 * pitchScale;
    final rockPitchZ = 0.17 * math.min(pitchScale, 1.35);

    final bayCount = plan.bays.length;
    double bayBotZ(_BayTerrainInfo g, {required bool start}) {
      if (isStepped) {
        return (botFollowsHigh ? g.zHighMax : g.zLowMin) + zBotOff;
      }
      final s = start ? g.samples.first : g.samples.last;
      return (botFollowsHigh ? s.zHigh : s.zLow) + zBotOff;
    }

    double bayTopZ(_BayTerrainInfo g, {required bool start}) {
      if (isStepped) return g.zHighMax + zTopOff;
      final s = start ? g.samples.first : g.samples.last;
      return s.zHigh + zTopOff;
    }

    for (var bIdx = 0; bIdx < bayCount; bIdx++) {
      final bay = plan.bays[bIdx];
      final bGround = grounding.bays[bIdx];
      final a = bay.start;
      final b = bay.end;
      final len = bay.length;
      if (len < 0.08) continue;
      final u = bay.u;
      final n = bay.n;

      final zBotA = bayBotZ(bGround, start: true);
      final zBotB = bayBotZ(bGround, start: false);
      final zTopA = bayTopZ(bGround, start: true);
      final zTopB = bayTopZ(bGround, start: false);
      final effTierH = math.max(zTopA - zBotA, zTopB - zBotB);
      if (effTierH < 0.12) continue;

      final hasPrev = isClosed || bIdx > 0;
      final hasNext = isClosed || bIdx < bayCount - 1;
      final prevIdx = (bIdx - 1 + bayCount) % bayCount;
      final nextIdx = (bIdx + 1) % bayCount;
      final prevTopEnd = hasPrev
          ? bayTopZ(grounding.bays[prevIdx], start: false)
          : zTopA;
      final nextTopStart = hasNext
          ? bayTopZ(grounding.bays[nextIdx], start: true)
          : zTopB;
      final prevBotEnd = hasPrev
          ? bayBotZ(grounding.bays[prevIdx], start: false)
          : zBotA;
      final nextBotStart = hasNext
          ? bayBotZ(grounding.bays[nextIdx], start: true)
          : zBotB;

      final stepStart = !hasPrev ||
          (zTopA - prevTopEnd).abs() > 0.02 ||
          (zBotA - prevBotEnd).abs() > 0.02;
      final stepEnd = !hasNext ||
          (zTopB - nextTopStart).abs() > 0.02 ||
          (zBotB - nextBotStart).abs() > 0.02;

      // 1. Dark recessed inner stone shadow bed (mitered at corners)
      final (clA, clB) = _bayOffsetEndpoints(bay, miterCoreL, coreLeft);
      final (crA, crB) = _bayOffsetEndpoints(bay, miterCoreR, -coreRight);
      if (isStepped) {
        _addPrismSpan(
          tris,
          bl0: clA,
          bl1: clB,
          br0: crA,
          br1: crB,
          tl0: clA,
          tl1: clB,
          tr0: crA,
          tr1: crB,
          zB0: zBotA + 0.015,
          zB1: zBotB + 0.015,
          zT0: zTopA - 0.018,
          zT1: zTopB - 0.018,
          color: _gabionCoreShadowColor,
          capStart: stepStart,
          capEnd: stepEnd,
        );
      } else {
        // Subdivide sloped core along bay's 5 terrain samples to hug dips cleanly.
        for (var k = 0; k < bGround.samples.length - 1; k++) {
          final t0 = k / (bGround.samples.length - 1);
          final t1 = (k + 1) / (bGround.samples.length - 1);
          final s0 = bGround.samples[k];
          final s1 = bGround.samples[k + 1];
          final subBot0 = (botFollowsHigh ? s0.zHigh : s0.zLow) + zBotOff;
          final subBot1 = (botFollowsHigh ? s1.zHigh : s1.zLow) + zBotOff;
          final subTop0 = s0.zHigh + zTopOff;
          final subTop1 = s1.zHigh + zTopOff;
          _addPrismSpan(
            tris,
            bl0: Offset.lerp(clA, clB, t0)!,
            bl1: Offset.lerp(clA, clB, t1)!,
            br0: Offset.lerp(crA, crB, t0)!,
            br1: Offset.lerp(crA, crB, t1)!,
            tl0: Offset.lerp(clA, clB, t0)!,
            tl1: Offset.lerp(clA, clB, t1)!,
            tr0: Offset.lerp(crA, crB, t0)!,
            tr1: Offset.lerp(crA, crB, t1)!,
            zB0: subBot0 + 0.015,
            zB1: subBot1 + 0.015,
            zT0: subTop0 - 0.018,
            zT1: subTop1 - 0.018,
            color: _gabionCoreShadowColor,
            capStart: k == 0 && stepStart,
            capEnd: k == bGround.samples.length - 2 && stepEnd,
          );
        }
      }

      // 2A. Faceted 3D quarry/river cobbles on both exposed faces (+n and -n)
      final mlA = _baySingleEndpoint(bay, miterCageL, cageLeft, start: true);
      final mlB = _baySingleEndpoint(bay, miterCageL, cageLeft, start: false);
      final mrA = _baySingleEndpoint(bay, miterCageR, -cageRight, start: true);
      final mrB = _baySingleEndpoint(bay, miterCageR, -cageRight, start: false);

      if (detailed && len > 0.22) {
        final avgBot = (zBotA + zBotB) * 0.5;
        final avgTop = (zTopA + zTopB) * 0.5;
        final zSpan = avgTop - avgBot;
        final rows = math.max(1, ((zSpan - 0.10) / rockPitchZ).floor());
        final rowStep = (zSpan - 0.10) / rows;
        final startTrim = math.min(0.11, len * 0.12);
        final usableLen = math.max(0.08, len - 2 * startTrim);

        for (var r = 0; r < rows; r++) {
          final relFrac = (0.05 + (r + 0.5) * rowStep) / zSpan;
          final stagger = r.isOdd ? rockPitchU * 0.48 : 0.0;
          final cols = math.max(1, ((usableLen - stagger) / rockPitchU).floor());
          final colStep = (usableLen - stagger) / cols;

          for (var c = 0; c < cols; c++) {
            final along = startTrim + stagger + (c + 0.5) * colStep;
            final t = (along / len).clamp(0.0, 1.0);
            final zBotHere = zBotA + (zBotB - zBotA) * t;
            final zTopHere = zTopA + (zTopB - zTopA) * t;
            final zMidAbs = zBotHere + (zTopHere - zBotHere) * relFrac;
            final center2D = a + u * along;

            for (final sideSign in const [1.0, -1.0]) {
              final hVal = _hash4(
                bIdx + tierIndex * 31,
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
                zCenter: zMidAbs + jitterZ,
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

          // Open ends or stepped vertical risers receive end cobbles
          if (stepStart || stepEnd) {
            final endSpecs = <(Offset endPt, double zMinEnd, double zMaxEnd, Offset outDir, int seed)>[
              if (stepStart && (!hasPrev || zTopA > prevTopEnd + 0.02 || zBotA < prevBotEnd - 0.02))
                (a, zBotA, zTopA, -u, 701 + bIdx),
              if (stepEnd && (!hasNext || zTopB > nextTopStart + 0.02 || zBotB < nextBotStart - 0.02))
                (b, zBotB, zTopB, u, 709 + bIdx),
            ];
            final spanN = (coreLeft + coreRight) * 0.86;
            final endCols = math.max(1, (spanN / 0.19).round());
            final endStepN = spanN / endCols;
            for (final (endPt, zMinEnd, zMaxEnd, outDir, seed) in endSpecs) {
              final zMidEnd = zMinEnd + (zMaxEnd - zMinEnd) * relFrac;
              for (var ec = 0; ec < endCols; ec++) {
                final offN = -coreRight * 0.86 + (ec + 0.5) * endStepN;
                final hVal = _hash4(seed, tierIndex, r, ec);
                final stoneColor = _gabionStonePalette[
                    (hVal >> 12) % _gabionStonePalette.length];
                _addGabionCobble(
                  tris,
                  baseCenter: endPt + n * offN - outDir * 0.015,
                  zCenter: zMidEnd,
                  u: n,
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
            final zTopHere = zTopA + (zTopB - zTopA) * t;
            final center2D = a + u * along;
            for (var rn = 0; rn < rowsN; rn++) {
              final offN = -rightOffset + 0.03 + (rn + 0.5) * stepN;
              final hVal = _hash4(bIdx + 97, tierIndex, c, rn);
              final stoneColor = _gabionStonePalette[
                  (hVal >> 12) % _gabionStonePalette.length];
              _addGabionCobble(
                tris,
                baseCenter: center2D + n * offN,
                zCenter: zTopHere - 0.024,
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

      // 2B. Galvanized steel wire basket frames (~1.0 m compartments) & weldmesh
      final compartments = math.max(1, len.round());
      final cellLen = len / compartments;
      final wireStepZ = detailed ? 0.15 : 0.28;
      final wireStepU = detailed ? 0.16 : 0.30;

      // Top & bottom border rods on both mitered faces
      for (final (zA, zB) in [
        (zBotA + 0.012, zBotB + 0.012),
        (zTopA - 0.012, zTopB - 0.012),
      ]) {
        for (final (fa, fb) in [(mlA, mlB), (mrA, mrB)]) {
          _addSlopedBeam(
            tris,
            a: fa,
            b: fb,
            n: n,
            halfThick: frameHalf,
            zBotA: zA - frameHalf,
            zTopA: zA + frameHalf,
            zBotB: zB - frameHalf,
            zTopB: zB + frameHalf,
            color: _galvanizedWireColor,
            material: _galvanizedSteelMat,
          );
        }
      }

      // Intermediate horizontal welded wires on both mitered faces
      final hWireCount = math.max(1, ((effTierH - 0.12) / wireStepZ).floor());
      for (var w = 1; w <= hWireCount; w++) {
        final frac = w / (hWireCount + 1);
        final zRodA = (zBotA + 0.02) + ((zTopA - 0.02) - (zBotA + 0.02)) * frac;
        final zRodB = (zBotB + 0.02) + ((zTopB - 0.02) - (zBotB + 0.02)) * frac;
        for (final (fa, fb) in [(mlA, mlB), (mrA, mrB)]) {
          _addSlopedBeam(
            tris,
            a: fa,
            b: fb,
            n: n,
            halfThick: wireHalf,
            zBotA: zRodA - wireHalf,
            zTopA: zRodA + wireHalf,
            zBotB: zRodB - wireHalf,
            zTopB: zRodB + wireHalf,
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
        final zBotHere = zBotA + (zBotB - zBotA) * t;
        final zTopHere = zTopA + (zTopB - zTopA) * t;
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
            zBot: zBotHere,
            zTop: zTopHere,
            color: _galvanizedWireColor,
            material: _galvanizedSteelMat,
          );
        }

        // Transverse cross-wire tying front & back faces at compartment ribs & top lid
        if (isRib) {
          final midN = (cageLeft - cageRight) * 0.5;
          final halfSpanN = (cageLeft + cageRight) * 0.5;
          for (final zTie in [zBotHere + 0.012, zTopHere - 0.012]) {
            _addOrientedBox(
              tris,
              center: pos + n * midN,
              u: u,
              n: n,
              halfU: frameHalf,
              halfN: halfSpanN,
              zBot: zTie - frameHalf,
              zTop: zTie + frameHalf,
              color: _galvanizedWireColor,
              material: _galvanizedSteelMat,
            );
          }
          // Close open ends & stepped riser faces with transverse horizontal mesh wires
          if ((vw == 0 && stepStart) || (vw == totalVWires && stepEnd)) {
            for (var w = 1; w <= hWireCount; w++) {
              final frac = w / (hWireCount + 1);
              final zRod =
                  (zBotHere + 0.02) + ((zTopHere - 0.02) - (zBotHere + 0.02)) * frac;
              _addOrientedBox(
                tris,
                center: pos + n * midN,
                u: u,
                n: n,
                halfU: wireHalf,
                halfN: halfSpanN,
                zBot: zRod - wireHalf,
                zTop: zRod + wireHalf,
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
            zBot: zTopHere - wireHalf * 2,
            zTop: zTopHere,
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
    double Function(Offset p) groundZAt, {
    double? Function(Offset p)? tryGroundZAt,
  }) {
    final h = math.max(0.60, fence.height);
    final plinthH = fence.plinthHeight
        .clamp(0.14, math.min<double>(0.30, h * 0.25))
        .toDouble();
    final halfT = math.max(0.06, fence.thickness * 0.5);
    final postSize = fence.pierSize.clamp(0.08, 0.14);
    final postHalf = postSize * 0.5;
    final plinthHalf = math.max(halfT * 0.85, postHalf + 0.015);
    final probeOffset = plinthHalf + 0.10;
    final isStepped = fence.slopeMode == ArchitectFenceSlopeMode.stepped;
    const embed = 0.18;

    final plan = _planBays(pts, isClosed, fence.pierSpacing);
    final grounding = _samplePlanGrounding(
      plan,
      probeOffset: probeOffset,
      groundZAt: groundZAt,
      tryGroundZAt: tryGroundZAt,
    );

    // 1. Sleek low concrete kerb plinth per bay
    for (var bIdx = 0; bIdx < plan.bays.length; bIdx++) {
      final bay = plan.bays[bIdx];
      final bGround = grounding.bays[bIdx];
      if (isStepped) {
        final zBot = bGround.zLowMin - embed;
        final zTop = bGround.zHighMax + plinthH;
        _addSlopedBeam(
          tris,
          a: bay.start,
          b: bay.end,
          n: bay.n,
          halfThick: plinthHalf,
          zBotA: zBot,
          zTopA: zTop,
          zBotB: zBot,
          zTopB: zTop,
          color: _plinthBodyColor,
        );
      } else {
        _addSegmentedBayBeam(
          tris,
          bay: bay,
          bGround: bGround,
          tStart: 0.0,
          tEnd: 1.0,
          halfThick: plinthHalf,
          zBotFromLow: -embed,
          zTopFromHigh: plinthH,
          color: _plinthBodyColor,
        );
      }
    }

    // 2. Slim anthracite powder-coated steel posts + post cap plates (+ corner plinth pedestal)
    for (var nIdx = 0; nIdx < plan.nodes.length; nIdx++) {
      final node = plan.nodes[nIdx];
      final span = grounding.nodeSpan(
        nIdx,
        stepped: isStepped,
        embed: embed,
        height: h,
      );
      if (node.isBendCorner && plinthHalf > postHalf) {
        final plinthTop = isStepped
            ? span.zTop - h + plinthH
            : grounding.nodes[nIdx].zHigh + plinthH;
        _addOrientedBox(
          tris,
          center: node.pos,
          u: node.u,
          n: node.n,
          halfU: plinthHalf,
          halfN: plinthHalf,
          zBot: span.zBot,
          zTop: plinthTop,
          color: _plinthBodyColor,
        );
      }
      _addOrientedBox(
        tris,
        center: node.pos,
        u: node.u,
        n: node.n,
        halfU: postHalf,
        halfN: postHalf,
        zBot: span.zBot,
        zTop: span.zTop - 0.016,
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
        zBot: span.zTop - 0.016,
        zTop: span.zTop,
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

    for (var bIdx = 0; bIdx < plan.bays.length; bIdx++) {
      final bay = plan.bays[bIdx];
      final bGround = grounding.bays[bIdx];
      if (bay.length - postSize < 0.10) continue;
      final edgeInset = postHalf - 0.004;
      final pStart = bay.start + bay.u * edgeInset;
      final pEnd = bay.end - bay.u * edgeInset;
      final tStart = (edgeInset / bay.length).clamp(0.0, 0.45);
      final tEnd = (1.0 - tStart).clamp(0.55, 1.0);
      final za = isStepped
          ? bGround.zHighMax
          : bGround.sampleAtT(tStart).zHigh;
      final zb = isStepped ? bGround.zHighMax : bGround.sampleAtT(tEnd).zHigh;

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
        final mz = isStepped ? bGround.zHighMax : bGround.sampleAtT(0.5).zHigh;
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
    double? Function(Offset p)? tryGroundZAt,
    required bool detailed,
  }) {
    final h = math.max(0.75, fence.height);
    final plinthH = fence.plinthHeight.clamp(0.20, h * 0.42);
    final halfT = math.max(0.08, fence.thickness * 0.5);
    final pierSize = math.max(fence.pierSize, math.max(halfT * 2.4, 0.34));
    final pierHalf = pierSize * 0.5;
    final plinthHalf = math.max(halfT * 0.90, 0.11);
    final probeOffset = math.max(plinthHalf, pierHalf) + 0.10;
    final isStepped = fence.slopeMode == ArchitectFenceSlopeMode.stepped;
    const embed = 0.20;

    final plan = _planBays(pts, isClosed, fence.pierSpacing);
    final grounding = _samplePlanGrounding(
      plan,
      probeOffset: probeOffset,
      groundZAt: groundZAt,
      tryGroundZAt: tryGroundZAt,
    );

    // 1. Bay-segmented concrete plinth + cast stone coping
    for (var bIdx = 0; bIdx < plan.bays.length; bIdx++) {
      final bay = plan.bays[bIdx];
      final bGround = grounding.bays[bIdx];
      final trim = math.min(pierHalf - 0.01, bay.length * 0.25);
      if (bay.length - 2 * trim < 0.04) continue;
      final pStart = bay.start + bay.u * trim;
      final pEnd = bay.end - bay.u * trim;

      if (isStepped) {
        final zBot = bGround.zLowMin - embed;
        final zBodyTop = bGround.zHighMax + plinthH - 0.035;
        final zCapTop = bGround.zHighMax + plinthH;
        _addSlopedBeam(
          tris,
          a: pStart,
          b: pEnd,
          n: bay.n,
          halfThick: plinthHalf,
          zBotA: zBot,
          zTopA: zBodyTop,
          zBotB: zBot,
          zTopB: zBodyTop,
          color: _plinthBodyColor,
        );
        _addSlopedBeam(
          tris,
          a: pStart,
          b: pEnd,
          n: bay.n,
          halfThick: plinthHalf + 0.015,
          zBotA: zBodyTop,
          zTopA: zCapTop,
          zBotB: zBodyTop,
          zTopB: zCapTop,
          color: _plinthCapColor,
        );
      } else {
        final t0 = trim / bay.length;
        final t1 = 1.0 - t0;
        _addSegmentedBayBeam(
          tris,
          bay: bay,
          bGround: bGround,
          tStart: t0,
          tEnd: t1,
          halfThick: plinthHalf,
          zBotFromLow: -embed,
          zTopFromHigh: plinthH - 0.035,
          color: _plinthBodyColor,
        );
        _addSegmentedBayBeam(
          tris,
          bay: bay,
          bGround: bGround,
          tStart: t0,
          tEnd: t1,
          halfThick: plinthHalf + 0.015,
          zBotFromLow: plinthH - 0.035,
          zTopFromHigh: plinthH,
          useHighForBot: true,
          color: _plinthCapColor,
        );
      }
    }

    // 2. Oriented masonry piers
    for (var nIdx = 0; nIdx < plan.nodes.length; nIdx++) {
      final node = plan.nodes[nIdx];
      final span = grounding.nodeSpan(
        nIdx,
        stepped: isStepped,
        embed: embed,
        height: h,
      );
      _addMasonryPier(
        tris,
        center: node.pos,
        u: node.u,
        n: node.n,
        halfW: pierHalf,
        zBot: span.zBot,
        zTop: span.zTop,
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

    for (var bIdx = 0; bIdx < plan.bays.length; bIdx++) {
      final bay = plan.bays[bIdx];
      final bGround = grounding.bays[bIdx];
      final clearSpan = bay.length - pierSize;
      if (clearSpan < 0.16) continue;
      final edgeInset = pierHalf - 0.004;
      final pStart = bay.start + bay.u * edgeInset;
      final pEnd = bay.end - bay.u * edgeInset;
      final tStart = (edgeInset / bay.length).clamp(0.0, 0.45);
      final tEnd = (1.0 - tStart).clamp(0.55, 1.0);
      final za = isStepped
          ? bGround.zHighMax
          : bGround.sampleAtT(tStart).zHigh;
      final zb = isStepped ? bGround.zHighMax : bGround.sampleAtT(tEnd).zHigh;

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
        final distAlong = pierHalf + i * step;
        final pos = bay.start + bay.u * distAlong;
        final pz = isStepped
            ? bGround.zHighMax
            : bGround.sampleAtT((distAlong / bay.length).clamp(0.0, 1.0)).zHigh;
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
          final distAlong = pierHalf + (i + 0.5) * step;
          final pos = bay.start + bay.u * distAlong;
          final pz = isStepped
              ? bGround.zHighMax
              : bGround
                    .sampleAtT((distAlong / bay.length).clamp(0.0, 1.0))
                    .zHigh;
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
    double? Function(Offset p)? tryGroundZAt,
    required bool detailed,
  }) {
    final h = math.max(0.50, fence.height);
    final halfTBot = math.max(0.11, fence.thickness * 0.5);
    // Keep back (+n) near vertical and batter front (-n) slope cleanly.
    final halfTTop = math.max(0.08, halfTBot * 0.72);
    final topBack = halfTBot * 0.94;
    final topFront = math.max(0.06, halfTTop * 2 - topBack);
    final isStepped = fence.slopeMode == ArchitectFenceSlopeMode.stepped;

    final plan = _planBays(pts, isClosed, math.max(1.50, fence.pierSpacing));
    final grounding = _samplePlanGrounding(
      plan,
      probeOffset: halfTBot + 0.20,
      groundZAt: groundZAt,
      tryGroundZAt: tryGroundZAt,
    );

    final footL = halfTBot + 0.34;
    final footR = halfTBot + 0.16;
    final capBotL = topBack + 0.03;
    final capBotR = topFront + 0.03;
    final capTopL = topBack + 0.02;
    final capTopR = topFront + 0.02;

    final mFootL = ArchitectPathway.offsetChain(pts, footL, closed: isClosed);
    final mFootR = ArchitectPathway.offsetChain(pts, -footR, closed: isClosed);
    final mStemBL = ArchitectPathway.offsetChain(pts, halfTBot, closed: isClosed);
    final mStemBR = ArchitectPathway.offsetChain(pts, -halfTBot, closed: isClosed);
    final mStemTL = ArchitectPathway.offsetChain(pts, topBack, closed: isClosed);
    final mStemTR = ArchitectPathway.offsetChain(pts, -topFront, closed: isClosed);
    final mCapBL = ArchitectPathway.offsetChain(pts, capBotL, closed: isClosed);
    final mCapBR = ArchitectPathway.offsetChain(pts, -capBotR, closed: isClosed);
    final mCapTL = ArchitectPathway.offsetChain(pts, capTopL, closed: isClosed);
    final mCapTR = ArchitectPathway.offsetChain(pts, -capTopR, closed: isClosed);

    final bayCount = plan.bays.length;
    for (var bIdx = 0; bIdx < bayCount; bIdx++) {
      final bay = plan.bays[bIdx];
      final bGround = grounding.bays[bIdx];
      final (fl0, fl1) = _bayOffsetEndpoints(bay, mFootL, footL);
      final (fr0, fr1) = _bayOffsetEndpoints(bay, mFootR, -footR);
      final (sbl0, sbl1) = _bayOffsetEndpoints(bay, mStemBL, halfTBot);
      final (sbr0, sbr1) = _bayOffsetEndpoints(bay, mStemBR, -halfTBot);
      final (stl0, stl1) = _bayOffsetEndpoints(bay, mStemTL, topBack);
      final (str0, str1) = _bayOffsetEndpoints(bay, mStemTR, -topFront);
      final (cbl0, cbl1) = _bayOffsetEndpoints(bay, mCapBL, capBotL);
      final (cbr0, cbr1) = _bayOffsetEndpoints(bay, mCapBR, -capBotR);
      final (ctl0, ctl1) = _bayOffsetEndpoints(bay, mCapTL, capTopL);
      final (ctr0, ctr1) = _bayOffsetEndpoints(bay, mCapTR, -capTopR);

      if (isStepped) {
        final zLow = bGround.zLowMin;
        final zTop = bGround.zHighMax + h;
        final hasPrev = isClosed || bIdx > 0;
        final hasNext = isClosed || bIdx < bayCount - 1;
        final prevG = hasPrev ? grounding.bays[(bIdx - 1 + bayCount) % bayCount] : bGround;
        final nextG = hasNext ? grounding.bays[(bIdx + 1) % bayCount] : bGround;
        final capStart = !hasPrev ||
            (zLow - prevG.zLowMin).abs() > 0.015 ||
            (bGround.zHighMax - prevG.zHighMax).abs() > 0.015;
        final capEnd = !hasNext ||
            (zLow - nextG.zLowMin).abs() > 0.015 ||
            (bGround.zHighMax - nextG.zHighMax).abs() > 0.015;

        // 1. Protruding RC strip footing
        _addPrismSpan(
          tris,
          bl0: fl0,
          bl1: fl1,
          br0: fr0,
          br1: fr1,
          tl0: fl0,
          tl1: fl1,
          tr0: fr0,
          tr1: fr1,
          zB0: zLow - 0.32,
          zB1: zLow - 0.32,
          zT0: zLow - 0.06,
          zT1: zLow - 0.06,
          color: _rcFootingColor,
          capStart: capStart,
          capEnd: capEnd,
        );
        // 2. Tapered battered concrete stem wall
        _addPrismSpan(
          tris,
          bl0: sbl0,
          bl1: sbl1,
          br0: sbr0,
          br1: sbr1,
          tl0: stl0,
          tl1: stl1,
          tr0: str0,
          tr1: str1,
          zB0: zLow - 0.06,
          zB1: zLow - 0.06,
          zT0: zTop - 0.06,
          zT1: zTop - 0.06,
          color: _rcStemColor,
          capStart: capStart,
          capEnd: capEnd,
        );
        // 3. Beveled/overhanging precast concrete coping cap
        _addPrismSpan(
          tris,
          bl0: cbl0,
          bl1: cbl1,
          br0: cbr0,
          br1: cbr1,
          tl0: ctl0,
          tl1: ctl1,
          tr0: ctr0,
          tr1: ctr1,
          zB0: zTop - 0.06,
          zB1: zTop - 0.06,
          zT0: zTop,
          zT1: zTop,
          color: _rcCapColor,
          capStart: capStart,
          capEnd: capEnd,
        );
      } else {
        final subCount = bGround.samples.length - 1;
        for (var k = 0; k < subCount; k++) {
          final t0 = k / subCount;
          final t1 = (k + 1) / subCount;
          final s0 = bGround.samples[k];
          final s1 = bGround.samples[k + 1];
          final isOpenStart = !isClosed && bIdx == 0 && k == 0;
          final isOpenEnd = !isClosed && bIdx == bayCount - 1 && k == subCount - 1;
          _addPrismSpan(
            tris,
            bl0: Offset.lerp(fl0, fl1, t0)!,
            bl1: Offset.lerp(fl0, fl1, t1)!,
            br0: Offset.lerp(fr0, fr1, t0)!,
            br1: Offset.lerp(fr0, fr1, t1)!,
            tl0: Offset.lerp(fl0, fl1, t0)!,
            tl1: Offset.lerp(fl0, fl1, t1)!,
            tr0: Offset.lerp(fr0, fr1, t0)!,
            tr1: Offset.lerp(fr0, fr1, t1)!,
            zB0: s0.zLow - 0.32,
            zB1: s1.zLow - 0.32,
            zT0: s0.zLow - 0.06,
            zT1: s1.zLow - 0.06,
            color: _rcFootingColor,
            capStart: isOpenStart,
            capEnd: isOpenEnd,
          );
          _addPrismSpan(
            tris,
            bl0: Offset.lerp(sbl0, sbl1, t0)!,
            bl1: Offset.lerp(sbl0, sbl1, t1)!,
            br0: Offset.lerp(sbr0, sbr1, t0)!,
            br1: Offset.lerp(sbr0, sbr1, t1)!,
            tl0: Offset.lerp(stl0, stl1, t0)!,
            tl1: Offset.lerp(stl0, stl1, t1)!,
            tr0: Offset.lerp(str0, str1, t0)!,
            tr1: Offset.lerp(str0, str1, t1)!,
            zB0: s0.zLow - 0.06,
            zB1: s1.zLow - 0.06,
            zT0: s0.zHigh + h - 0.06,
            zT1: s1.zHigh + h - 0.06,
            color: _rcStemColor,
            capStart: isOpenStart,
            capEnd: isOpenEnd,
          );
          _addPrismSpan(
            tris,
            bl0: Offset.lerp(cbl0, cbl1, t0)!,
            bl1: Offset.lerp(cbl0, cbl1, t1)!,
            br0: Offset.lerp(cbr0, cbr1, t0)!,
            br1: Offset.lerp(cbr0, cbr1, t1)!,
            tl0: Offset.lerp(ctl0, ctl1, t0)!,
            tl1: Offset.lerp(ctl0, ctl1, t1)!,
            tr0: Offset.lerp(ctr0, ctr1, t0)!,
            tr1: Offset.lerp(ctr0, ctr1, t1)!,
            zB0: s0.zHigh + h - 0.06,
            zB1: s1.zHigh + h - 0.06,
            zT0: s0.zHigh + h,
            zT1: s1.zHigh + h,
            color: _rcCapColor,
            capStart: isOpenStart,
            capEnd: isOpenEnd,
          );
        }
      }

      if (!detailed || bay.length < 0.40) continue;

      // 4. Control joint reveals at bay end (for intermediate joints) & weep holes
      final u = bay.u;
      final n = bay.n;
      final len = bay.length;
      if (isClosed || bIdx < bayCount - 1) {
        final zJointBot = isStepped
            ? bGround.zLowMin
            : bGround.samples.last.zLow;
        final zJointTop = isStepped
            ? bGround.zHighMax + h - 0.06
            : bGround.samples.last.zHigh + h - 0.06;
        _addOrientedBox(
          tris,
          center: bay.end,
          u: u,
          n: n,
          halfU: 0.012,
          halfN: halfTBot + 0.004,
          zBot: zJointBot,
          zTop: zJointTop,
          color: _rcJointColor,
        );
      }

      // Weep hole drainage pipes along the battered front (-n) face
      final weepZOff = math.min(0.26, h * 0.35);
      final batterRatio = (halfTBot - topFront) / math.max(0.25, h - 0.06);
      for (var d = 0.90; d < len - 0.35; d += 1.80) {
        final t = d / len;
        final sample = bGround.sampleAtT(t);
        final zFront = isStepped ? bGround.zRightMin : sample.zRight;
        final zTopHere = (isStepped ? bGround.zHighMax : sample.zHigh) + h;
        final zWeep = math.min(zFront + weepZOff, zTopHere - 0.14);
        final heightAboveBot = math.max(0.0, zWeep - bGround.zLowMin);
        final frontFaceOut = (halfTBot - batterRatio * heightAboveBot).clamp(
          topFront,
          halfTBot,
        );
        final p = Offset.lerp(bay.start, bay.end, t)! - n * (frontFaceOut + 0.008);
        _addOrientedBox(
          tris,
          center: p,
          u: u,
          n: n,
          halfU: 0.028,
          halfN: 0.018,
          zBot: zWeep - 0.028,
          zTop: zWeep + 0.028,
          color: _rcWeepPipeColor,
        );
        _addOrientedBox(
          tris,
          center: p - n * 0.010,
          u: u,
          n: n,
          halfU: 0.016,
          halfN: 0.012,
          zBot: zWeep - 0.016,
          zTop: zWeep + 0.016,
          color: _rcWeepBoreColor,
        );
      }
    }
  }

  // ===========================================================================
  // 6. SHARED PRISM, PIER, BAY, GROUNDING & HASH HELPERS
  // ===========================================================================

  static _PlanGrounding _samplePlanGrounding(
    _FenceBayPlan plan, {
    required double probeOffset,
    required double Function(Offset p) groundZAt,
    double? Function(Offset p)? tryGroundZAt,
  }) {
    final nodeSamples = [
      for (final node in plan.nodes)
        _samplePoint(node.pos, node.n, probeOffset, groundZAt, tryGroundZAt),
    ];
    final bayInfos = <_BayTerrainInfo>[];
    for (final bay in plan.bays) {
      final samples = <_CrossSectionSample>[];
      var zLowMin = double.infinity;
      var zHighMax = double.negativeInfinity;
      var zRightMin = double.infinity;
      for (var k = 0; k <= 4; k++) {
        final t = k / 4.0;
        final pt = Offset.lerp(bay.start, bay.end, t)!;
        final s = _samplePoint(
          pt,
          bay.n,
          probeOffset,
          groundZAt,
          tryGroundZAt,
        );
        samples.add(s);
        if (s.zLow < zLowMin) zLowMin = s.zLow;
        if (s.zHigh > zHighMax) zHighMax = s.zHigh;
        if (s.zRight < zRightMin) zRightMin = s.zRight;
      }
      bayInfos.add(
        _BayTerrainInfo(
          samples: samples,
          zLowMin: zLowMin,
          zHighMax: zHighMax,
          zRightMin: zRightMin,
        ),
      );
    }
    return _PlanGrounding(plan, nodeSamples, bayInfos);
  }

  static _CrossSectionSample _samplePoint(
    Offset p,
    Offset n,
    double probeOffset,
    double Function(Offset p) groundZAt,
    double? Function(Offset p)? tryGroundZAt,
  ) {
    double? evalOpt(Offset pt) =>
        tryGroundZAt != null ? tryGroundZAt(pt) : groundZAt(pt);

    final zC = evalOpt(p);
    final zL = evalOpt(p + n * probeOffset);
    final zR = evalOpt(p - n * probeOffset);
    final fallback = zC ?? zL ?? zR ?? groundZAt(p);
    final effC = zC ?? fallback;
    final effL = zL ?? fallback;
    final effR = zR ?? fallback;
    final zLow = math.min(effC, math.min(effL, effR));
    final zHigh = math.max(effC, math.max(effL, effR));
    return _CrossSectionSample(
      zLow: zLow,
      zHigh: zHigh,
      zLeft: effL,
      zRight: effR,
    );
  }

  static (Offset, Offset) _bayOffsetEndpoints(
    _FenceBay bay,
    List<Offset> miterChain,
    double signedOffset,
  ) => (
    _baySingleEndpoint(bay, miterChain, signedOffset, start: true),
    _baySingleEndpoint(bay, miterChain, signedOffset, start: false),
  );

  static Offset _baySingleEndpoint(
    _FenceBay bay,
    List<Offset> miterChain,
    double signedOffset, {
    required bool start,
  }) {
    final vertexIdx = start ? bay.startVertexIdx : bay.endVertexIdx;
    if (vertexIdx != null && vertexIdx >= 0 && vertexIdx < miterChain.length) {
      return miterChain[vertexIdx];
    }
    final pt = start ? bay.start : bay.end;
    return pt + bay.n * signedOffset;
  }

  static void _addSegmentedBayBeam(
    List<Triangle3D> tris, {
    required _FenceBay bay,
    required _BayTerrainInfo bGround,
    required double tStart,
    required double tEnd,
    required double halfThick,
    required double zBotFromLow,
    required double zTopFromHigh,
    bool useHighForBot = false,
    required Color color,
    MeshMaterial? material,
  }) {
    if (tEnd <= tStart + 1e-4) return;
    const subCount = 4;
    for (var k = 0; k < subCount; k++) {
      final ta = tStart + (tEnd - tStart) * (k / subCount);
      final tb = tStart + (tEnd - tStart) * ((k + 1) / subCount);
      final pa = Offset.lerp(bay.start, bay.end, ta)!;
      final pb = Offset.lerp(bay.start, bay.end, tb)!;
      final sa = bGround.sampleAtT(ta);
      final sb = bGround.sampleAtT(tb);
      _addSlopedBeam(
        tris,
        a: pa,
        b: pb,
        n: bay.n,
        halfThick: halfThick,
        zBotA: (useHighForBot ? sa.zHigh : sa.zLow) + zBotFromLow,
        zTopA: sa.zHigh + zTopFromHigh,
        zBotB: (useHighForBot ? sb.zHigh : sb.zLow) + zBotFromLow,
        zTopB: sb.zHigh + zTopFromHigh,
        color: color,
        material: material,
        includeEndCaps: k == 0 || k == subCount - 1,
      );
    }
  }

  static void _addPrismSpan(
    List<Triangle3D> tris, {
    required Offset bl0,
    required Offset bl1,
    required Offset br0,
    required Offset br1,
    required Offset tl0,
    required Offset tl1,
    required Offset tr0,
    required Offset tr1,
    required double zB0,
    required double zB1,
    required double zT0,
    required double zT1,
    required Color color,
    MeshMaterial? material,
    bool capStart = true,
    bool capEnd = true,
  }) {
    if ((zT0 - zB0).abs() < 1e-5 && (zT1 - zB1).abs() < 1e-5) return;
    final vbl0 = Vector3(bl0.dx, bl0.dy, zB0);
    final vbl1 = Vector3(bl1.dx, bl1.dy, zB1);
    final vbr0 = Vector3(br0.dx, br0.dy, zB0);
    final vbr1 = Vector3(br1.dx, br1.dy, zB1);
    final vtl0 = Vector3(tl0.dx, tl0.dy, zT0);
    final vtl1 = Vector3(tl1.dx, tl1.dy, zT1);
    final vtr0 = Vector3(tr0.dx, tr0.dy, zT0);
    final vtr1 = Vector3(tr1.dx, tr1.dy, zT1);

    final c = (vbl0 + vbl1 + vbr0 + vbr1 + vtl0 + vtl1 + vtr0 + vtr1) * 0.125;
    _addOutwardQuad(tris, vtl0, vtr0, vtr1, vtl1, c, color, material: material);
    _addOutwardQuad(tris, vbl0, vbl1, vbr1, vbr0, c, color, material: material);
    _addOutwardQuad(tris, vbl0, vtl0, vtl1, vbl1, c, color, material: material);
    _addOutwardQuad(tris, vbr0, vbr1, vtr1, vtr0, c, color, material: material);
    if (capStart) {
      _addOutwardQuad(tris, vbl0, vbr0, vtr0, vtl0, c, color, material: material);
    }
    if (capEnd) {
      _addOutwardQuad(tris, vbl1, vtl1, vtr1, vbr1, c, color, material: material);
    }
  }

  static void _addMasonryPier(
    List<Triangle3D> tris, {
    required Offset center,
    required Offset u,
    required Offset n,
    required double halfW,
    required double zBot,
    required double zTop,
  }) {
    final zShaftTop = math.max(zBot + 0.15, zTop - 0.075);
    final zNeckTop = zShaftTop + 0.015;
    final zFlangeTop = zNeckTop + 0.025;
    final zPeak = math.max(zFlangeTop + 0.01, zTop);

    // Pier masonry shaft
    _addOrientedBox(
      tris,
      center: center,
      u: u,
      n: n,
      halfU: halfW,
      halfN: halfW,
      zBot: zBot,
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
    final cornerNodeIndices = <int?>[];

    // Segment unit vectors
    final segDirs = <Offset>[];
    for (var i = 0; i < segCount; i++) {
      final d = pts[(i + 1) % pts.length] - pts[i];
      final len = d.distance;
      segDirs.add(len > 1e-6 ? d / len : const Offset(1, 0));
    }

    for (var i = 0; i < segCount; i++) {
      final a = pts[i];
      final d = pts[(i + 1) % pts.length] - a;
      final len = d.distance;
      if (len < 1e-4) {
        cornerNodeIndices.add(null);
        continue;
      }
      final u = d / len;
      final hasPrev = i > 0 || isClosed;
      var nodeU = u;
      var isBendCorner = false;
      if (hasPrev) {
        final prevU = segDirs[(i - 1 + segCount) % segCount];
        final dot = prevU.dx * u.dx + prevU.dy * u.dy;
        isBendCorner = dot < 0.99;
        if (dot > 0.65) {
          final avg = prevU + u;
          final avgLen = avg.distance;
          if (avgLen > 1e-4) nodeU = avg / avgLen;
        } else {
          nodeU = prevU;
        }
      }
      cornerNodeIndices.add(nodes.length);
      nodes.add(
        _FenceNode(
          a,
          nodeU,
          Offset(-nodeU.dy, nodeU.dx),
          isBendCorner: isBendCorner,
        ),
      );
    }

    int? endNodeIdx;
    if (!isClosed && segCount > 0) {
      final lastU = segDirs.last;
      endNodeIdx = nodes.length;
      nodes.add(_FenceNode(pts.last, lastU, Offset(-lastU.dy, lastU.dx)));
    }

    for (var i = 0; i < segCount; i++) {
      final startCornerIdx = cornerNodeIndices[i];
      if (startCornerIdx == null) continue;
      final nextVertexIdx = (i + 1) % pts.length;
      final endCornerIdx = (!isClosed && i == segCount - 1)
          ? endNodeIdx!
          : (cornerNodeIndices[nextVertexIdx] ??
                cornerNodeIndices.firstWhere((e) => e != null)!);

      final a = pts[i];
      final b = pts[nextVertexIdx];
      final d = b - a;
      final len = d.distance;
      if (len < 1e-4) continue;
      final u = d / len;
      final n = Offset(-u.dy, u.dx);

      final bayCount = math.max(1, (len / safeSpacing).round());
      var prevNodeIdx = startCornerIdx;
      for (var k = 0; k < bayCount; k++) {
        final s = Offset.lerp(a, b, k / bayCount)!;
        final e = Offset.lerp(a, b, (k + 1) / bayCount)!;
        final int curEndNodeIdx;
        if (k == bayCount - 1) {
          curEndNodeIdx = endCornerIdx;
        } else {
          curEndNodeIdx = nodes.length;
          nodes.add(_FenceNode(e, u, n));
        }
        bays.add(
          _FenceBay(
            start: s,
            end: e,
            u: u,
            n: n,
            length: len / bayCount,
            startNodeIdx: prevNodeIdx,
            endNodeIdx: curEndNodeIdx,
            startVertexIdx: k == 0 ? i : null,
            endVertexIdx: k == bayCount - 1 ? nextVertexIdx : null,
          ),
        );
        prevNodeIdx = curEndNodeIdx;
      }
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
  final bool isBendCorner;
  const _FenceNode(this.pos, this.u, this.n, {this.isBendCorner = false});
}

class _FenceBay {
  final Offset start;
  final Offset end;
  final Offset u;
  final Offset n;
  final double length;
  final int startNodeIdx;
  final int endNodeIdx;
  final int? startVertexIdx;
  final int? endVertexIdx;

  const _FenceBay({
    required this.start,
    required this.end,
    required this.u,
    required this.n,
    required this.length,
    required this.startNodeIdx,
    required this.endNodeIdx,
    this.startVertexIdx,
    this.endVertexIdx,
  });
}

class _FenceBayPlan {
  final List<_FenceNode> nodes;
  final List<_FenceBay> bays;
  const _FenceBayPlan(this.nodes, this.bays);
}

class _CrossSectionSample {
  final double zLow;
  final double zHigh;
  final double zLeft;
  final double zRight;

  const _CrossSectionSample({
    required this.zLow,
    required this.zHigh,
    required this.zLeft,
    required this.zRight,
  });
}

class _BayTerrainInfo {
  final List<_CrossSectionSample> samples;
  final double zLowMin;
  final double zHighMax;
  final double zRightMin;

  const _BayTerrainInfo({
    required this.samples,
    required this.zLowMin,
    required this.zHighMax,
    required this.zRightMin,
  });

  _CrossSectionSample sampleAtT(double t) {
    final clamped = t.clamp(0.0, 1.0);
    final scaled = clamped * (samples.length - 1);
    final idx = scaled.floor().clamp(0, samples.length - 2);
    final f = scaled - idx;
    final a = samples[idx];
    final b = samples[idx + 1];
    return _CrossSectionSample(
      zLow: a.zLow + (b.zLow - a.zLow) * f,
      zHigh: a.zHigh + (b.zHigh - a.zHigh) * f,
      zLeft: a.zLeft + (b.zLeft - a.zLeft) * f,
      zRight: a.zRight + (b.zRight - a.zRight) * f,
    );
  }
}

class _PlanGrounding {
  final _FenceBayPlan plan;
  final List<_CrossSectionSample> nodes;
  final List<_BayTerrainInfo> bays;

  const _PlanGrounding(this.plan, this.nodes, this.bays);

  ({double zBot, double zTop}) nodeSpan(
    int nodeIdx, {
    required bool stepped,
    required double embed,
    required double height,
  }) {
    final nodeSample = nodes[nodeIdx];
    if (!stepped) {
      return (zBot: nodeSample.zLow - embed, zTop: nodeSample.zHigh + height);
    }
    var minLow = nodeSample.zLow;
    var maxHigh = double.negativeInfinity;
    for (var i = 0; i < plan.bays.length; i++) {
      final bay = plan.bays[i];
      if (bay.startNodeIdx == nodeIdx || bay.endNodeIdx == nodeIdx) {
        final g = bays[i];
        if (g.zLowMin < minLow) minLow = g.zLowMin;
        if (g.zHighMax > maxHigh) maxHigh = g.zHighMax;
      }
    }
    if (!maxHigh.isFinite) maxHigh = nodeSample.zHigh;
    return (zBot: minLow - embed, zTop: maxHigh + height);
  }
}
