// ============================================================================
// TABLE OF CONTENTS (grep: "=== SECTION:")
// 1. === SECTION: ENUMS & MATERIAL DEFINITIONS ===
// 2. === SECTION: ARCHITECT DECORATIVE ELEMENT MODEL ===
// 3. === SECTION: GEOMETRIC TRANSFORMATIONS & STRETCHING ===
// 4. === SECTION: STANDARD ARCHITECTURAL PRESETS ===
// ============================================================================

import 'dart:math' as math;
import 'dart:ui';
import '../../../core/l10n/generated/app_localizations.dart';
import 'architect_slab_assembly.dart';

// === SECTION: ENUMS & MATERIAL DEFINITIONS ===

enum ArchitectDecorativeMaterial {
  eps,
  plaster,
  stone,
  timber,
  concrete,
  metal;

  String label(AppLocalizations l10n) => switch (this) {
    eps => l10n.architectDecorativeMaterialEps,
    plaster => l10n.architectDecorativeMaterialPlaster,
    stone => l10n.architectDecorativeMaterialStone,
    timber => l10n.architectDecorativeMaterialTimber,
    concrete => l10n.architectDecorativeMaterialConcrete,
    metal => l10n.architectDecorativeMaterialMetal,
  };

  Color get defaultColor => switch (this) {
    eps => const Color(0xFFF5F2EB),
    plaster => const Color(0xFFECEFF1),
    stone => const Color(0xFFD7CCC8),
    timber => const Color(0xFFBCAAA4),
    concrete => const Color(0xFFB0BEC5),
    metal => const Color(0xFF90A4AE),
  };

  SlabMaterial get sectionMaterial => switch (this) {
    eps => SlabMaterial.xps,
    plaster => SlabMaterial.plaster,
    stone => SlabMaterial.tile,
    timber => SlabMaterial.parquet,
    concrete => SlabMaterial.concrete,
    metal => SlabMaterial.custom,
  };

  String get defaultHatchId => switch (this) {
    eps => 'dots',
    plaster => 'reverseDiagonal',
    stone => 'diagonal',
    timber => 'wood',
    concrete => 'concrete',
    metal => 'metal',
  };
}

enum ArchitectDecorativeCreationMode { facade, section, studio }

// === SECTION: ARCHITECT DECORATIVE ELEMENT MODEL ===

/// 3D architectural decorative element (cornices, window frames, brackets,
/// pilasters, facade reliefs, rustication, and perforated panels).
///
/// Defined in a local 3D coordinate system `(U, V, Z)`:
/// - `origin`: 2D Plan point `(X, Y)` where `(u = 0, v = 0)`.
/// - `tangent`: Unit vector in Plan along `+U` (horizontal along facade/wall).
/// - `normal`: Unit vector in Plan along `+V` (outward depth direction).
/// - `baseOffset`: Elevation `Z` relative to the parent storey's finished floor.
/// - `normalOffset`: Shift along `normal` (`+V`) from `origin`.
class ArchitectDecorativeElement {
  final String id;
  final String name;
  final String? presetId;
  final ArchitectDecorativeCreationMode mode;
  final String? hostWallId;
  final int hostWallSide;
  final Offset origin;
  final Offset tangent;
  final Offset normal;
  final double baseOffset;
  final double normalOffset;

  /// Front silhouette in `(u, z)` coordinates (metres, `u >= 0, z >= 0`).
  final List<Offset> frontPolygon;
  final List<List<Offset>> frontHoles;

  /// Cross-section profile in `(v, z)` coordinates (metres, `v >= 0, z >= 0`).
  final List<Offset> sidePolygon;
  final List<List<Offset>> sideHoles;

  /// Extrusion span along `U` when created in Section, or width of `frontPolygon`.
  final double spanLength;

  /// Nominal thickness along `V` (default 0.05 m = 5 cm when drawn on Facade).
  final double depth;

  /// Optional hollow frame inset width (metres). When > 0, creates an inner
  /// offset opening inside `frontPolygon`.
  final double? frameWidth;

  final ArchitectDecorativeMaterial material;
  final Color? customColor;
  final bool showOnPlan;
  final bool isPreset;

  const ArchitectDecorativeElement({
    required this.id,
    this.name = '',
    this.presetId,
    this.mode = ArchitectDecorativeCreationMode.facade,
    this.hostWallId,
    this.hostWallSide = 1,
    this.origin = Offset.zero,
    this.tangent = const Offset(1, 0),
    this.normal = const Offset(0, 1),
    this.baseOffset = 0.0,
    this.normalOffset = 0.0,
    required this.frontPolygon,
    this.frontHoles = const [],
    required this.sidePolygon,
    this.sideHoles = const [],
    this.spanLength = 1.0,
    this.depth = 0.05,
    this.frameWidth,
    this.material = ArchitectDecorativeMaterial.eps,
    this.customColor,
    this.showOnPlan = false,
    this.isPreset = false,
  });

  /// Creates an element from a 2D contour drawn on a Facade (Elevation).
  factory ArchitectDecorativeElement.fromFacadeContour({
    required String id,
    required List<Offset> contour,
    List<List<Offset>> holes = const [],
    required Offset origin,
    required Offset tangent,
    required Offset normal,
    required double baseOffset,
    double normalOffset = 0.0,
    double depth = 0.05,
    double? frameWidth,
    String? hostWallId,
    int hostWallSide = 1,
    ArchitectDecorativeMaterial material = ArchitectDecorativeMaterial.eps,
    bool showOnPlan = false,
    String name = '',
  }) {
    final normalized = _normalizeContour(contour);
    final w = math.max(0.01, normalized.bounds.width);
    final h = math.max(0.01, normalized.bounds.height);
    final d = math.max(0.005, depth);
    final shiftedHoles = [
      for (final hole in holes)
        [for (final pt in hole) pt - normalized.bounds.topLeft],
    ];
    return ArchitectDecorativeElement(
      id: id,
      name: name,
      mode: ArchitectDecorativeCreationMode.facade,
      hostWallId: hostWallId,
      hostWallSide: hostWallSide,
      origin: origin + tangent * normalized.bounds.left,
      tangent: tangent,
      normal: normal,
      baseOffset: baseOffset + normalized.bounds.top,
      normalOffset: normalOffset,
      frontPolygon: normalized.points,
      frontHoles: shiftedHoles,
      sidePolygon: [
        const Offset(0, 0),
        Offset(d, 0),
        Offset(d, h),
        Offset(0, h),
      ],
      spanLength: w,
      depth: d,
      frameWidth: frameWidth != null && frameWidth > 0 ? frameWidth : null,
      material: material,
      showOnPlan: showOnPlan,
    );
  }

  /// Creates an element from a 2D cross-section profile drawn in a Section.
  factory ArchitectDecorativeElement.fromSectionProfile({
    required String id,
    required List<Offset> profile,
    List<List<Offset>> holes = const [],
    required Offset origin,
    required Offset tangent,
    required Offset normal,
    required double baseOffset,
    double normalOffset = 0.0,
    double spanLength = 1.0,
    String? hostWallId,
    int hostWallSide = 1,
    ArchitectDecorativeMaterial material = ArchitectDecorativeMaterial.eps,
    bool showOnPlan = false,
    String name = '',
  }) {
    final normalized = _normalizeContour(profile);
    final d = math.max(0.01, normalized.bounds.width);
    final h = math.max(0.01, normalized.bounds.height);
    final len = math.max(0.02, spanLength);
    final shiftedHoles = [
      for (final hole in holes)
        [for (final pt in hole) pt - normalized.bounds.topLeft],
    ];
    return ArchitectDecorativeElement(
      id: id,
      name: name,
      mode: ArchitectDecorativeCreationMode.section,
      hostWallId: hostWallId,
      hostWallSide: hostWallSide,
      origin: origin,
      tangent: tangent,
      normal: normal,
      baseOffset: baseOffset + normalized.bounds.top,
      normalOffset: normalOffset + normalized.bounds.left,
      frontPolygon: [
        const Offset(0, 0),
        Offset(len, 0),
        Offset(len, h),
        Offset(0, h),
      ],
      sidePolygon: normalized.points,
      sideHoles: shiftedHoles,
      spanLength: len,
      depth: d,
      material: material,
      showOnPlan: showOnPlan,
    );
  }

  static ({List<Offset> points, Rect bounds}) _normalizeContour(
    List<Offset> raw,
  ) {
    if (raw.isEmpty) {
      return (
        points: const [
          Offset(0, 0),
          Offset(0.2, 0),
          Offset(0.2, 0.2),
          Offset(0, 0.2),
        ],
        bounds: const Rect.fromLTWH(0, 0, 0.2, 0.2),
      );
    }
    var minX = raw.first.dx, maxX = raw.first.dx;
    var minY = raw.first.dy, maxY = raw.first.dy;
    for (final p in raw) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    final bounds = Rect.fromLTRB(minX, minY, maxX, maxY);
    return (
      points: [for (final p in raw) Offset(p.dx - minX, p.dy - minY)],
      bounds: bounds,
    );
  }

  Color get effectiveColor => customColor ?? material.defaultColor;

  Rect get frontBounds => _polygonBounds(frontPolygon, spanLength, 0.20);
  Rect get sideBounds => _polygonBounds(sidePolygon, depth, frontBounds.height);

  double get width => math.max(0.01, frontBounds.width);
  double get height =>
      math.max(0.01, math.max(frontBounds.height, sideBounds.height));
  double get effectiveDepth => math.max(0.005, sideBounds.width);

  static Rect _polygonBounds(
    List<Offset> pts,
    double fallbackW,
    double fallbackH,
  ) {
    if (pts.isEmpty) return Rect.fromLTWH(0, 0, fallbackW, fallbackH);
    var minX = pts.first.dx, maxX = pts.first.dx;
    var minY = pts.first.dy, maxY = pts.first.dy;
    for (final p in pts) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  bool get hasValidGeometry =>
      frontPolygon.length >= 3 &&
      sidePolygon.length >= 3 &&
      width >= 0.005 &&
      height >= 0.005 &&
      effectiveDepth >= 0.002;

  // === SECTION: GEOMETRIC TRANSFORMATIONS & STRETCHING ===

  /// Stretches or shrinks the element's horizontal span `U` (e.g. on Facade).
  ArchitectDecorativeElement withWidth(
    double nextWidth, {
    bool anchorRight = false,
  }) {
    final targetW = nextWidth.clamp(0.02, 100.0);
    final oldW = width;
    if ((targetW - oldW).abs() < 1e-6) return this;
    final scale = targetW / oldW;
    final b = frontBounds;
    final scaledFront = [
      for (final p in frontPolygon)
        Offset((p.dx - b.left) * scale, p.dy - b.top),
    ];
    final scaledHoles = [
      for (final hole in frontHoles)
        [for (final p in hole) Offset((p.dx - b.left) * scale, p.dy - b.top)],
    ];
    final shift = anchorRight ? (oldW - targetW) : 0.0;
    return copyWith(
      origin: origin + tangent * shift,
      frontPolygon: scaledFront,
      frontHoles: scaledHoles,
      spanLength: targetW,
    );
  }

  /// Stretches or shrinks the element's vertical height `Z`.
  ArchitectDecorativeElement withHeight(
    double nextHeight, {
    bool anchorTop = false,
  }) {
    final targetH = nextHeight.clamp(0.02, 50.0);
    final oldH = height;
    if ((targetH - oldH).abs() < 1e-6) return this;
    final scale = targetH / oldH;
    final fb = frontBounds, sb = sideBounds;
    final scaledFront = [
      for (final p in frontPolygon)
        Offset(p.dx - fb.left, (p.dy - fb.top) * scale),
    ];
    final scaledFrontHoles = [
      for (final hole in frontHoles)
        [for (final p in hole) Offset(p.dx - fb.left, (p.dy - fb.top) * scale)],
    ];
    final scaledSide = [
      for (final p in sidePolygon)
        Offset(p.dx - sb.left, (p.dy - sb.top) * scale),
    ];
    final scaledSideHoles = [
      for (final hole in sideHoles)
        [for (final p in hole) Offset(p.dx - sb.left, (p.dy - sb.top) * scale)],
    ];
    final dz = anchorTop ? (oldH - targetH) : 0.0;
    return copyWith(
      baseOffset: baseOffset + dz,
      frontPolygon: scaledFront,
      frontHoles: scaledFrontHoles,
      sidePolygon: scaledSide,
      sideHoles: scaledSideHoles,
    );
  }

  /// Adjusts the element's thickness/projection `V` (depth).
  ArchitectDecorativeElement withDepth(double nextDepth) {
    final targetD = nextDepth.clamp(0.005, 20.0);
    final oldD = effectiveDepth;
    if ((targetD - oldD).abs() < 1e-6) return copyWith(depth: targetD);
    final scale = targetD / oldD;
    final sb = sideBounds;
    final scaledSide = [
      for (final p in sidePolygon)
        Offset((p.dx - sb.left) * scale, p.dy - sb.top),
    ];
    final scaledSideHoles = [
      for (final hole in sideHoles)
        [for (final p in hole) Offset((p.dx - sb.left) * scale, p.dy - sb.top)],
    ];
    return copyWith(
      depth: targetD,
      sidePolygon: scaledSide,
      sideHoles: scaledSideHoles,
    );
  }

  ArchitectDecorativeElement translatedInPlan(Offset delta) =>
      copyWith(origin: origin + delta);

  ArchitectDecorativeElement rotatedInPlan(Offset pivot, double angleRad) {
    final c = math.cos(angleRad), s = math.sin(angleRad);
    Offset rotVec(Offset v) => Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
    final d = origin - pivot;
    return copyWith(
      origin: pivot + rotVec(d),
      tangent: rotVec(tangent),
      normal: rotVec(normal),
    );
  }

  ArchitectDecorativeElement mirroredInPlan(Offset lineA, Offset lineB) {
    final dir = lineB - lineA;
    final len = dir.distance;
    if (len < 1e-8) return this;
    final u = dir / len;
    Offset reflectVec(Offset v) {
      final dot = v.dx * u.dx + v.dy * u.dy;
      return Offset(2 * dot * u.dx - v.dx, 2 * dot * u.dy - v.dy);
    }

    final rel = origin - lineA;
    final reflectedOrigin = lineA + reflectVec(rel);
    final nextTangent = reflectVec(tangent);
    final nextNormal = reflectVec(normal);
    // Keep front coordinate U positive along the mirrored span
    return copyWith(
      origin: reflectedOrigin + nextTangent * width,
      tangent: -nextTangent,
      normal: nextNormal,
    );
  }

  ArchitectDecorativeElement copyWith({
    String? id,
    String? name,
    String? presetId,
    bool clearPresetId = false,
    ArchitectDecorativeCreationMode? mode,
    String? hostWallId,
    bool clearHostWallId = false,
    int? hostWallSide,
    Offset? origin,
    Offset? tangent,
    Offset? normal,
    double? baseOffset,
    double? normalOffset,
    List<Offset>? frontPolygon,
    List<List<Offset>>? frontHoles,
    List<Offset>? sidePolygon,
    List<List<Offset>>? sideHoles,
    double? spanLength,
    double? depth,
    double? frameWidth,
    bool clearFrameWidth = false,
    ArchitectDecorativeMaterial? material,
    Color? customColor,
    bool clearCustomColor = false,
    bool? showOnPlan,
    bool? isPreset,
  }) => ArchitectDecorativeElement(
    id: id ?? this.id,
    name: name ?? this.name,
    presetId: clearPresetId ? null : (presetId ?? this.presetId),
    mode: mode ?? this.mode,
    hostWallId: clearHostWallId ? null : (hostWallId ?? this.hostWallId),
    hostWallSide: hostWallSide ?? this.hostWallSide,
    origin: origin ?? this.origin,
    tangent: tangent ?? this.tangent,
    normal: normal ?? this.normal,
    baseOffset: baseOffset ?? this.baseOffset,
    normalOffset: normalOffset ?? this.normalOffset,
    frontPolygon: frontPolygon ?? this.frontPolygon,
    frontHoles: frontHoles ?? this.frontHoles,
    sidePolygon: sidePolygon ?? this.sidePolygon,
    sideHoles: sideHoles ?? this.sideHoles,
    spanLength: spanLength ?? this.spanLength,
    depth: depth ?? this.depth,
    frameWidth: clearFrameWidth ? null : (frameWidth ?? this.frameWidth),
    material: material ?? this.material,
    customColor: clearCustomColor ? null : (customColor ?? this.customColor),
    showOnPlan: showOnPlan ?? this.showOnPlan,
    isPreset: isPreset ?? this.isPreset,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    if (name.isNotEmpty) 'name': name,
    if (presetId != null) 'presetId': presetId,
    'mode': mode.name,
    if (hostWallId != null) 'hostWallId': hostWallId,
    if (hostWallSide != 1) 'hostWallSide': hostWallSide,
    'origin': {'x': origin.dx, 'y': origin.dy},
    'tangent': {'x': tangent.dx, 'y': tangent.dy},
    'normal': {'x': normal.dx, 'y': normal.dy},
    'baseOffset': baseOffset,
    if (normalOffset != 0.0) 'normalOffset': normalOffset,
    'frontPolygon': [
      for (final p in frontPolygon) {'x': p.dx, 'y': p.dy},
    ],
    if (frontHoles.isNotEmpty)
      'frontHoles': [
        for (final hole in frontHoles)
          [
            for (final p in hole) {'x': p.dx, 'y': p.dy},
          ],
      ],
    'sidePolygon': [
      for (final p in sidePolygon) {'x': p.dx, 'y': p.dy},
    ],
    if (sideHoles.isNotEmpty)
      'sideHoles': [
        for (final hole in sideHoles)
          [
            for (final p in hole) {'x': p.dx, 'y': p.dy},
          ],
      ],
    'spanLength': spanLength,
    'depth': depth,
    if (frameWidth != null) 'frameWidth': frameWidth,
    'material': material.name,
    if (customColor != null) 'customColor': customColor!.toARGB32(),
    if (showOnPlan) 'showOnPlan': true,
    if (isPreset) 'isPreset': true,
  };

  factory ArchitectDecorativeElement.fromJson(Map<String, dynamic> json) {
    Offset readPt(Object? raw, [Offset fallback = Offset.zero]) {
      if (raw is Map) {
        return Offset(
          (raw['x'] as num?)?.toDouble() ?? fallback.dx,
          (raw['y'] as num?)?.toDouble() ?? fallback.dy,
        );
      }
      return fallback;
    }

    List<Offset> readPoly(Object? raw) {
      if (raw is! List) return const [];
      return [
        for (final item in raw)
          if (item is Map) readPt(item),
      ];
    }

    List<List<Offset>> readHoles(Object? raw) {
      if (raw is! List) return const [];
      return [
        for (final hole in raw)
          if (hole is List) readPoly(hole),
      ];
    }

    final tangent = readPt(json['tangent'], const Offset(1, 0));
    final normal = readPt(
      json['normal'],
      Offset(-tangent.dy, tangent.dx),
    );
    final modeName = json['mode'] as String?;
    final matName = json['material'] as String?;
    return ArchitectDecorativeElement(
      id: (json['id'] as String?) ?? 'decor_unknown',
      name: (json['name'] as String?) ?? '',
      presetId: json['presetId'] as String?,
      mode: ArchitectDecorativeCreationMode.values
              .where((m) => m.name == modeName)
              .firstOrNull ??
          ArchitectDecorativeCreationMode.facade,
      hostWallId: json['hostWallId'] as String?,
      hostWallSide: (json['hostWallSide'] as num?)?.toInt() ?? 1,
      origin: readPt(json['origin']),
      tangent: tangent,
      normal: normal,
      baseOffset: (json['baseOffset'] as num?)?.toDouble() ?? 0.0,
      normalOffset: (json['normalOffset'] as num?)?.toDouble() ?? 0.0,
      frontPolygon: readPoly(json['frontPolygon']),
      frontHoles: readHoles(json['frontHoles']),
      sidePolygon: readPoly(json['sidePolygon']),
      sideHoles: readHoles(json['sideHoles']),
      spanLength: (json['spanLength'] as num?)?.toDouble() ?? 1.0,
      depth: (json['depth'] as num?)?.toDouble() ?? 0.05,
      frameWidth: (json['frameWidth'] as num?)?.toDouble(),
      material: ArchitectDecorativeMaterial.values
              .where((m) => m.name == matName)
              .firstOrNull ??
          ArchitectDecorativeMaterial.eps,
      customColor: json['customColor'] is num
          ? Color((json['customColor'] as num).toInt())
          : null,
      showOnPlan: json['showOnPlan'] as bool? ?? false,
      isPreset: json['isPreset'] as bool? ?? false,
    );
  }

  // === SECTION: STANDARD ARCHITECTURAL PRESETS ===

  static String localizedPresetName(
    AppLocalizations l10n,
    ArchitectDecorativeElement element,
  ) => switch (element.presetId ?? element.id) {
    'preset_cornice' => l10n.architectDecorativePresetCornice,
    'preset_window_frame' => l10n.architectDecorativePresetWindowFrame,
    'preset_window_sill' => l10n.architectDecorativePresetWindowSill,
    'preset_bracket' => l10n.architectDecorativePresetBracket,
    'preset_keystone' => l10n.architectDecorativePresetKeystone,
    'preset_pilaster' => l10n.architectDecorativePresetPilaster,
    'preset_perforated_panel' => l10n.architectDecorativePresetPerforatedPanel,
    _ => element.name.isNotEmpty
        ? element.name
        : l10n.architectCategoryDecorative,
  };

  static List<ArchitectDecorativeElement> standardCatalog() => [
    // 1. Stepped Eaves Cornice (Подстрешен корниз)
    const ArchitectDecorativeElement(
      id: 'preset_cornice',
      presetId: 'preset_cornice',
      mode: ArchitectDecorativeCreationMode.section,
      spanLength: 2.00,
      depth: 0.18,
      material: ArchitectDecorativeMaterial.eps,
      isPreset: true,
      frontPolygon: [
        Offset(0, 0),
        Offset(2.00, 0),
        Offset(2.00, 0.22),
        Offset(0, 0.22),
      ],
      sidePolygon: [
        Offset(0, 0),
        Offset(0.05, 0),
        Offset(0.05, 0.05),
        Offset(0.11, 0.08),
        Offset(0.11, 0.14),
        Offset(0.18, 0.16),
        Offset(0.18, 0.22),
        Offset(0, 0.22),
      ],
    ),
    // 2. Window Frame Molding (Прозоречна рамка)
    const ArchitectDecorativeElement(
      id: 'preset_window_frame',
      presetId: 'preset_window_frame',
      mode: ArchitectDecorativeCreationMode.facade,
      spanLength: 1.40,
      depth: 0.05,
      frameWidth: 0.10,
      material: ArchitectDecorativeMaterial.eps,
      isPreset: true,
      frontPolygon: [
        Offset(0, 0),
        Offset(1.40, 0),
        Offset(1.40, 1.60),
        Offset(0, 1.60),
      ],
      sidePolygon: [
        Offset(0, 0),
        Offset(0.05, 0),
        Offset(0.05, 1.60),
        Offset(0, 1.60),
      ],
    ),
    // 3. Profiled Window Sill (Подпрозоречен перваз)
    const ArchitectDecorativeElement(
      id: 'preset_window_sill',
      presetId: 'preset_window_sill',
      mode: ArchitectDecorativeCreationMode.studio,
      spanLength: 1.44,
      depth: 0.09,
      material: ArchitectDecorativeMaterial.stone,
      isPreset: true,
      frontPolygon: [
        Offset(0, 0),
        Offset(1.44, 0),
        Offset(1.44, 0.12),
        Offset(0, 0.12),
      ],
      sidePolygon: [
        Offset(0, 0),
        Offset(0.04, 0),
        Offset(0.06, 0.04),
        Offset(0.09, 0.05),
        Offset(0.09, 0.12),
        Offset(0, 0.12),
      ],
    ),
    // 4. Decorative Eaves Bracket / Corbel (Конзола под стреха)
    const ArchitectDecorativeElement(
      id: 'preset_bracket',
      presetId: 'preset_bracket',
      mode: ArchitectDecorativeCreationMode.studio,
      spanLength: 0.14,
      depth: 0.28,
      material: ArchitectDecorativeMaterial.timber,
      isPreset: true,
      frontPolygon: [
        Offset(0, 0),
        Offset(0.14, 0),
        Offset(0.14, 0.36),
        Offset(0, 0.36),
      ],
      sidePolygon: [
        Offset(0, 0),
        Offset(0.08, 0),
        Offset(0.12, 0.12),
        Offset(0.20, 0.22),
        Offset(0.28, 0.26),
        Offset(0.28, 0.36),
        Offset(0, 0.36),
      ],
    ),
    // 5. Keystone (Ключов камък)
    const ArchitectDecorativeElement(
      id: 'preset_keystone',
      presetId: 'preset_keystone',
      mode: ArchitectDecorativeCreationMode.studio,
      spanLength: 0.26,
      depth: 0.07,
      material: ArchitectDecorativeMaterial.stone,
      isPreset: true,
      frontPolygon: [
        Offset(0.04, 0),
        Offset(0.22, 0),
        Offset(0.26, 0.30),
        Offset(0, 0.30),
      ],
      sidePolygon: [
        Offset(0, 0),
        Offset(0.05, 0),
        Offset(0.07, 0.30),
        Offset(0, 0.30),
      ],
    ),
    // 6. Facade Pilaster (Пиластър)
    const ArchitectDecorativeElement(
      id: 'preset_pilaster',
      presetId: 'preset_pilaster',
      mode: ArchitectDecorativeCreationMode.studio,
      spanLength: 0.32,
      depth: 0.06,
      material: ArchitectDecorativeMaterial.stone,
      showOnPlan: true,
      isPreset: true,
      frontPolygon: [
        Offset(0, 0),
        Offset(0.32, 0),
        Offset(0.32, 2.60),
        Offset(0, 2.60),
      ],
      sidePolygon: [
        Offset(0, 0),
        Offset(0.06, 0),
        Offset(0.06, 0.20),
        Offset(0.045, 0.22),
        Offset(0.045, 2.42),
        Offset(0.06, 2.45),
        Offset(0.06, 2.60),
        Offset(0, 2.60),
      ],
    ),
    // 7. Perforated Facade Screen Panel (Перфорирано пано с отвори)
    const ArchitectDecorativeElement(
      id: 'preset_perforated_panel',
      presetId: 'preset_perforated_panel',
      mode: ArchitectDecorativeCreationMode.facade,
      spanLength: 1.00,
      depth: 0.04,
      material: ArchitectDecorativeMaterial.metal,
      isPreset: true,
      frontPolygon: [
        Offset(0, 0),
        Offset(1.00, 0),
        Offset(1.00, 2.00),
        Offset(0, 2.00),
      ],
      frontHoles: [
        [
          Offset(0.12, 0.15),
          Offset(0.44, 0.15),
          Offset(0.44, 0.90),
          Offset(0.12, 0.90),
        ],
        [
          Offset(0.56, 0.15),
          Offset(0.88, 0.15),
          Offset(0.88, 0.90),
          Offset(0.56, 0.90),
        ],
        [
          Offset(0.12, 1.10),
          Offset(0.44, 1.10),
          Offset(0.44, 1.85),
          Offset(0.12, 1.85),
        ],
        [
          Offset(0.56, 1.10),
          Offset(0.88, 1.10),
          Offset(0.88, 1.85),
          Offset(0.56, 1.85),
        ],
      ],
      sidePolygon: [
        Offset(0, 0),
        Offset(0.04, 0),
        Offset(0.04, 2.00),
        Offset(0, 2.00),
      ],
    ),
  ];
}
