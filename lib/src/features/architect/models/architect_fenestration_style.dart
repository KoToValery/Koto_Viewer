import '../rendering/architect_vector_scene.dart';
import '../rendering/architect_opening_plan_painter.dart';
import '../rendering/architect_canvas_palette.dart';
// === SECTION: ARCHITECTURAL PARAMETRIC FENESTRATION MODEL ===
// Table of Contents:
// 1. ENUMS (FenestrationKind, PaneType, GlazingType, CasingPlacement)
// 2. FENESTRATION PANE & SUBDIVISION TREE
// 3. ARCHITECT FENESTRATION STYLE ENTITY
// 4. 2D PARAMETRIC PLAN DRAWING (HORIZONTAL CUT)
// 5. 2D PARAMETRIC ELEVATION DRAWING (FACADE CUT)
// 6. STANDARD PRESETS CATALOG
// 7. JSON SERIALIZATION

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/generated/app_localizations.dart';

/// Semantic classification of the fenestration element.
enum FenestrationKind { window, door }

/// Operational type of a specific pane / cell in the fenestration raster.
enum PaneType {
  /// Fixed glazed pane (глухо остъкляване, не се отваря).
  fixedGlazing,

  /// Side-hung casement turning left (отваряемо крило наляво).
  casementLeft,

  /// Side-hung casement turning right (отваряемо крило надясно).
  casementRight,

  /// Dual-action tilt and turn sash (двуосно отваряне / падащо и отваряемо).
  tiltAndTurn,

  /// Top-hung hopper sash / transom vent (оберлихт / фрамуга / отваряне отгоре).
  topHopper,

  /// Solid opaque insulated panel (плътен термопанел).
  solidPanel,

  /// Full door leaf with handle (вратно крило).
  doorLeaf,
}

/// Glazing unit structure.
enum GlazingType {
  single,
  double, // standard double glazing (двуслоен стъклопакет 24mm: 4-16-4)
  triple, // triple glazing (трислоен стъклопакет 36mm)
}

/// Infill is independent of the mechanism: a solid door still opens.
enum FenestrationInfill { glazing, solid }

/// Position of exterior decorative trim / casing.
enum CasingPlacement {
  exterior, // façade side only
  interior, // room side only
  both, // both façade and room sides
}

// =============================================================================
// SECTION 2: FENESTRATION PANE & SUBDIVISION TREE
// =============================================================================

/// Single pane or panel in a window/door raster.
class FenestrationPane {
  final String id;
  final PaneType paneType;
  final double sashProfileWidth; // default 0.06m (60mm)
  final bool hasHandle;
  final FenestrationInfill? infill;
  final int muntinCols; // vertical muntins / шпроси (0..4)
  final int muntinRows; // horizontal muntins / шпроси (0..4)
  final double muntinWidth; // muntin profile width (default 0.02 = 20mm)

  const FenestrationPane({
    required this.id,
    this.paneType = PaneType.fixedGlazing,
    this.sashProfileWidth = 0.06,
    this.hasHandle = false,
    this.infill,
    this.muntinCols = 0,
    this.muntinRows = 0,
    this.muntinWidth = 0.02,
  });

  bool get isOpenable =>
      paneType == PaneType.casementLeft ||
      paneType == PaneType.casementRight ||
      paneType == PaneType.tiltAndTurn ||
      paneType == PaneType.topHopper ||
      paneType == PaneType.doorLeaf;

  bool get isGlazed => infill == null
      ? paneType != PaneType.solidPanel
      : infill == FenestrationInfill.glazing;
  bool get isSolidPanel => !isGlazed;

  bool get hasMuntins => isGlazed && (muntinCols > 0 || muntinRows > 0);

  FenestrationPane copyWith({
    String? id,
    PaneType? paneType,
    double? sashProfileWidth,
    bool? hasHandle,
    FenestrationInfill? infill,
    int? muntinCols,
    int? muntinRows,
    double? muntinWidth,
  }) => FenestrationPane(
    id: id ?? this.id,
    paneType: paneType ?? this.paneType,
    sashProfileWidth: sashProfileWidth ?? this.sashProfileWidth,
    hasHandle: hasHandle ?? this.hasHandle,
    infill: infill ?? this.infill,
    muntinCols: muntinCols ?? this.muntinCols,
    muntinRows: muntinRows ?? this.muntinRows,
    muntinWidth: muntinWidth ?? this.muntinWidth,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'paneType': paneType.name,
    'sashProfileWidth': sashProfileWidth,
    'hasHandle': hasHandle,
    if (infill != null) 'infill': infill!.name,
    if (muntinCols > 0) 'muntinCols': muntinCols,
    if (muntinRows > 0) 'muntinRows': muntinRows,
    if (muntinWidth != 0.02) 'muntinWidth': muntinWidth,
  };

  factory FenestrationPane.fromJson(
    Map<String, dynamic> json,
  ) => FenestrationPane(
    id: json['id'] as String? ?? 'p_${DateTime.now().microsecondsSinceEpoch}',
    paneType: PaneType.values.firstWhere(
      (t) => t.name == json['paneType'],
      orElse: () => PaneType.fixedGlazing,
    ),
    sashProfileWidth: (json['sashProfileWidth'] as num?)?.toDouble() ?? 0.06,
    hasHandle: json['hasHandle'] as bool? ?? false,
    infill: FenestrationInfill.values
        .where((v) => v.name == json['infill'])
        .firstOrNull,
    muntinCols: (json['muntinCols'] as num?)?.toInt() ?? 0,
    muntinRows: (json['muntinRows'] as num?)?.toInt() ?? 0,
    muntinWidth: (json['muntinWidth'] as num?)?.toDouble() ?? 0.02,
  );
}

/// Node in the recursive subdivision tree of the fenestration opening.
class FenestrationSubdivision {
  final String id;
  final bool isSplit;
  final bool
  isVertical; // true = vertical splits (columns), false = horizontal splits (transom)
  final List<double> ratios; // proportional widths or heights (sum = 1.0)
  final List<FenestrationSubdivision> children;
  final FenestrationPane? pane;

  const FenestrationSubdivision({
    required this.id,
    this.isSplit = false,
    this.isVertical = true,
    this.ratios = const [1.0],
    this.children = const [],
    this.pane,
  });

  FenestrationSubdivision copyWith({
    String? id,
    bool? isSplit,
    bool? isVertical,
    List<double>? ratios,
    List<FenestrationSubdivision>? children,
    FenestrationPane? pane,
  }) => FenestrationSubdivision(
    id: id ?? this.id,
    isSplit: isSplit ?? this.isSplit,
    isVertical: isVertical ?? this.isVertical,
    ratios: ratios ?? this.ratios,
    children: children ?? this.children,
    pane: pane ?? this.pane,
  );

  /// Recursively finds a pane by ID.
  FenestrationPane? findPane(String paneId) {
    if (!isSplit && pane?.id == paneId) return pane;
    for (final child in children) {
      final found = child.findPane(paneId);
      if (found != null) return found;
    }
    return null;
  }

  /// Replaces a pane in the tree with an updated pane.
  FenestrationSubdivision updatePane(FenestrationPane updated) {
    if (!isSplit) {
      if (pane?.id == updated.id) {
        return copyWith(pane: updated);
      }
      return this;
    }
    return copyWith(
      children: children.map((c) => c.updatePane(updated)).toList(),
    );
  }

  /// Collects all leaf panes.
  List<FenestrationPane> collectPanes() {
    if (!isSplit) {
      return pane != null ? [pane!] : [];
    }
    final List<FenestrationPane> result = [];
    for (final child in children) {
      result.addAll(child.collectPanes());
    }
    return result;
  }

  /// Splits this node into [count] parts along [vertical].
  FenestrationSubdivision split({
    required bool vertical,
    int count = 2,
    List<double>? customRatios,
  }) {
    final eqRatios = customRatios ?? List.filled(count, 1.0 / count);
    final newChildren = List.generate(
      count,
      (i) => FenestrationSubdivision(
        id: '${id}_$i',
        isSplit: false,
        pane: FenestrationPane(
          id: 'pane_${id}_$i',
          paneType: pane?.paneType ?? PaneType.fixedGlazing,
          sashProfileWidth: pane?.sashProfileWidth ?? 0.06,
          hasHandle: pane?.hasHandle ?? false,
          infill: pane?.infill,
          muntinCols: pane?.muntinCols ?? 0,
          muntinRows: pane?.muntinRows ?? 0,
          muntinWidth: pane?.muntinWidth ?? 0.02,
        ),
      ),
    );
    return copyWith(
      isSplit: true,
      isVertical: vertical,
      ratios: eqRatios,
      children: newChildren,
      pane: null,
    );
  }

  /// Splits an individual leaf pane identified by [targetPaneId].
  FenestrationSubdivision splitPane(
    String targetPaneId, {
    required bool vertical,
    int count = 2,
    List<double>? customRatios,
  }) {
    if (!isSplit) {
      if (pane?.id == targetPaneId) {
        return split(
          vertical: vertical,
          count: count,
          customRatios: customRatios,
        );
      }
      return this;
    }
    return copyWith(
      children: children
          .map(
            (c) => c.splitPane(
              targetPaneId,
              vertical: vertical,
              count: count,
              customRatios: customRatios,
            ),
          )
          .toList(),
    );
  }

  /// Collapses an individual division or pane back to a single leaf pane.
  FenestrationSubdivision collapsePane(String targetPaneId) {
    if (!isSplit) return this;
    final hasDirectTarget = children.any(
      (c) => !c.isSplit && c.pane?.id == targetPaneId,
    );
    if (hasDirectTarget) {
      final keepPane = children
          .firstWhere((c) => c.pane != null, orElse: () => children.first)
          .pane;
      return FenestrationSubdivision(
        id: id,
        isSplit: false,
        pane:
            keepPane?.copyWith(id: 'pane_$id') ??
            FenestrationPane(id: 'pane_$id', paneType: PaneType.fixedGlazing),
      );
    }
    return copyWith(
      children: children.map((c) => c.collapsePane(targetPaneId)).toList(),
    );
  }

  /// Sets the exact metric dimension of a child leaf pane along [isWidth].
  FenestrationSubdivision setChildMetricDimension({
    required String targetPaneId,
    required double newDimension,
    required Rect bounds,
    required bool isWidth,
  }) {
    if (!isSplit) return this;

    if (isVertical == isWidth) {
      final childIdx = children.indexWhere(
        (c) => c.findPane(targetPaneId) != null,
      );
      if (childIdx >= 0 && children.length > 1) {
        final totalDim = isWidth ? bounds.width : bounds.height;
        if (totalDim > 0.05) {
          final maxAllowed = totalDim - 0.10 * (children.length - 1);
          final clampedDim = newDimension.clamp(0.10, maxAllowed);
          final newRatio = (clampedDim / totalDim).clamp(0.05, 0.95);
          final oldRatio = ratios[childIdx];
          final remainingOld = (1.0 - oldRatio).clamp(0.001, 1.0);
          final remainingNew = (1.0 - newRatio).clamp(0.001, 1.0);

          final nextRatios = List<double>.from(ratios);
          nextRatios[childIdx] = newRatio;
          for (int i = 0; i < nextRatios.length; i++) {
            if (i != childIdx) {
              nextRatios[i] = (ratios[i] * (remainingNew / remainingOld)).clamp(
                0.02,
                0.95,
              );
            }
          }
          final sum = nextRatios.reduce((a, b) => a + b);
          final normalized = nextRatios.map((r) => r / sum).toList();
          return copyWith(ratios: normalized);
        }
      }
    }

    double currentOffset = 0.0;
    final updatedChildren = <FenestrationSubdivision>[];
    for (int i = 0; i < children.length; i++) {
      final r = ratios[i];
      final childRect = isVertical
          ? Rect.fromLTWH(
              bounds.left + currentOffset,
              bounds.top,
              bounds.width * r,
              bounds.height,
            )
          : Rect.fromLTWH(
              bounds.left,
              bounds.top + currentOffset,
              bounds.width,
              bounds.height * r,
            );
      currentOffset += isVertical ? bounds.width * r : bounds.height * r;

      updatedChildren.add(
        children[i].setChildMetricDimension(
          targetPaneId: targetPaneId,
          newDimension: newDimension,
          bounds: childRect,
          isWidth: isWidth,
        ),
      );
    }
    return copyWith(children: updatedChildren);
  }

  /// Collects metric bounding rects for every leaf pane.
  Map<String, Rect> collectPaneRects(Rect bounds) {
    if (!isSplit) {
      return pane != null ? {pane!.id: bounds} : {};
    }
    final result = <String, Rect>{};
    double currentOffset = 0.0;
    for (int i = 0; i < children.length; i++) {
      final r = ratios[i];
      final childRect = isVertical
          ? Rect.fromLTWH(
              bounds.left + currentOffset,
              bounds.top,
              bounds.width * r,
              bounds.height,
            )
          : Rect.fromLTWH(
              bounds.left,
              bounds.top + currentOffset,
              bounds.width,
              bounds.height * r,
            );
      currentOffset += isVertical ? bounds.width * r : bounds.height * r;
      result.addAll(children[i].collectPaneRects(childRect));
    }
    return result;
  }

  /// Hit tests a metric point (x, y) in meters to locate the tapped leaf pane.
  (FenestrationPane, Rect)? hitTest(Offset metricPoint, Rect bounds) {
    if (!isSplit) {
      if (pane != null && bounds.contains(metricPoint)) {
        return (pane!, bounds);
      }
      return null;
    }
    double currentOffset = 0.0;
    for (int i = 0; i < children.length; i++) {
      final r = ratios[i];
      final childRect = isVertical
          ? Rect.fromLTWH(
              bounds.left + currentOffset,
              bounds.top,
              bounds.width * r,
              bounds.height,
            )
          : Rect.fromLTWH(
              bounds.left,
              bounds.top + currentOffset,
              bounds.width,
              bounds.height * r,
            );
      currentOffset += isVertical ? bounds.width * r : bounds.height * r;
      if (childRect.contains(metricPoint)) {
        final found = children[i].hitTest(metricPoint, childRect);
        if (found != null) return found;
      }
    }
    return null;
  }

  /// Collapses children and resets to a single leaf pane.
  FenestrationSubdivision collapse() {
    return FenestrationSubdivision(
      id: id,
      isSplit: false,
      pane: FenestrationPane(id: 'pane_$id', paneType: PaneType.fixedGlazing),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'isSplit': isSplit,
    'isVertical': isVertical,
    'ratios': ratios,
    'children': children.map((c) => c.toJson()).toList(),
    'pane': pane?.toJson(),
  };

  factory FenestrationSubdivision.fromJson(
    Map<String, dynamic> json,
  ) => FenestrationSubdivision(
    id: json['id'] as String? ?? 'sub_${DateTime.now().microsecondsSinceEpoch}',
    isSplit: json['isSplit'] as bool? ?? false,
    isVertical: json['isVertical'] as bool? ?? true,
    ratios:
        (json['ratios'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        const [1.0],
    children:
        (json['children'] as List<dynamic>?)
            ?.map(
              (e) =>
                  FenestrationSubdivision.fromJson(e as Map<String, dynamic>),
            )
            .toList() ??
        const [],
    pane: json['pane'] != null
        ? FenestrationPane.fromJson(json['pane'] as Map<String, dynamic>)
        : null,
  );
}

// =============================================================================
// SECTION 3: ARCHITECT FENESTRATION STYLE ENTITY
// =============================================================================

/// Full parametric blueprint for a window or door.
class FenestrationTransom {
  final double height;
  final FenestrationSubdivision subdivision;
  const FenestrationTransom({
    this.height = .40,
    this.subdivision = const FenestrationSubdivision(
      id: 'transom',
      pane: FenestrationPane(id: 'transom_pane'),
    ),
  });
  FenestrationTransom copyWith({
    double? height,
    FenestrationSubdivision? subdivision,
  }) => FenestrationTransom(
    height: height ?? this.height,
    subdivision: subdivision ?? this.subdivision,
  );
  Map<String, dynamic> toJson() => {
    'height': height,
    'subdivision': subdivision.toJson(),
  };
  factory FenestrationTransom.fromJson(Map<String, dynamic> json) =>
      FenestrationTransom(
        height: (json['height'] as num?)?.toDouble() ?? .40,
        subdivision: FenestrationSubdivision.fromJson(
          json['subdivision'] as Map<String, dynamic>,
        ),
      );
}

/// Bottom-up model coordinates. Clear pane rectangles never overlap profiles.
class FenestrationLayout {
  final Map<String, ({FenestrationPane pane, Rect rect})> panes;
  final List<Rect> dividers;
  const FenestrationLayout(this.panes, this.dividers);
}

class ArchitectFenestrationStyle {
  final String id;
  final String name;
  final FenestrationKind kind;

  // Geometry
  final double defaultWidth; // m (e.g. 1.40 m)
  final double defaultHeight; // m (e.g. 1.40 m for window, 2.00 m for door)
  final double defaultSillHeight; // m (e.g. 0.85 m for window, 0.00 m for door)

  // 5-Chamber Profile Parameters
  final double frameDepth; // standard 5-chamber PVC is 0.07 m (70 mm)
  final double frameFaceWidth; // profile face width 0.07 m (70 mm)
  final bool centerInCore; // place frame centered in masonry core

  // Glazing Parameters
  final GlazingType glazingType;
  final double glazingThickness; // standard double glazing is 0.024 m (24 mm)
  final int glassColorValue; // e.g. 0x884FC3F7

  // Exterior Casing / Architrave (Обрамчване / Обшивка)
  final bool hasCasing;
  final double
  casingWidth; // width of trim around opening on wall face (0.10 m)
  final double
  casingProjection; // projection forward in front of wall/insulation (0.03 m)
  final CasingPlacement casingPlacement;
  final int casingColorValue; // 0xFFECEFF1
  final bool
  includeBottomCasing; // true = trim under window; false = external sill ledge

  // Subdivision tree
  final FenestrationSubdivision rootSubdivision;
  final FenestrationTransom? transom;

  const ArchitectFenestrationStyle({
    required this.id,
    required this.name,
    this.kind = FenestrationKind.window,
    this.defaultWidth = 1.40,
    this.defaultHeight = 1.40,
    this.defaultSillHeight = 0.85,
    this.frameDepth = 0.07,
    this.frameFaceWidth = 0.07,
    this.centerInCore = true,
    this.glazingType = GlazingType.double,
    this.glazingThickness = 0.024,
    this.glassColorValue = 0x884FC3F7,
    this.hasCasing = false,
    this.casingWidth = 0.10,
    this.casingProjection = 0.03,
    this.casingPlacement = CasingPlacement.exterior,
    this.casingColorValue = 0xFFECEFF1,
    this.includeBottomCasing = false,
    required this.rootSubdivision,
    this.transom,
  });

  Color get glassColor => Color(glassColorValue);
  Color get casingColor => Color(casingColorValue);
  bool get isPreset => standardCatalog().any((s) => s.id == id);
  double get doorBodyHeight => defaultHeight - (transom?.height ?? 0);
  List<FenestrationPane> get panes => [
    ...rootSubdivision.collectPanes(),
    ...?transom?.subdivision.collectPanes(),
  ];

  ArchitectFenestrationStyle withTransom(FenestrationTransom? next) => copyWith(
    defaultHeight: doorBodyHeight + (next?.height ?? 0),
    transom: next,
    clearTransom: next == null,
  );

  /// Nominal zones are used for metric editing; physical profiles use resolveLayout.
  FenestrationSubdivision subdivisionForHeight(double height) {
    final top = transom;
    if (top == null || kind != FenestrationKind.door) return rootSubdivision;
    return FenestrationSubdivision(
      id: 'assembly',
      isSplit: true,
      isVertical: false,
      ratios: [(height - top.height) / height, top.height / height],
      children: [rootSubdivision, top.subdivision],
    );
  }

  FenestrationLayout resolveLayout({double? width, double? height}) {
    final w = width ?? defaultWidth,
        h = height ?? defaultHeight,
        f = frameFaceWidth;
    final leaves = <String, ({FenestrationPane pane, Rect rect})>{};
    final dividers = <Rect>[];
    void visit(FenestrationSubdivision node, Rect r) {
      if (r.width <= 0 || r.height <= 0) return;
      if (!node.isSplit) {
        if (node.pane != null) {
          leaves[node.pane!.id] = (pane: node.pane!, rect: r);
        }
        return;
      }
      var cursor = node.isVertical ? r.left : r.top;
      for (var i = 0; i < node.children.length; i++) {
        final length = (node.isVertical ? r.width : r.height) * node.ratios[i];
        final start = cursor + (i == 0 ? 0 : f / 2);
        final end =
            cursor + length - (i == node.children.length - 1 ? 0 : f / 2);
        visit(
          node.children[i],
          node.isVertical
              ? Rect.fromLTRB(start, r.top, end, r.bottom)
              : Rect.fromLTRB(r.left, start, r.right, end),
        );
        cursor += length;
        if (i < node.children.length - 1) {
          dividers.add(
            node.isVertical
                ? Rect.fromLTWH(cursor - f / 2, r.top, f, r.height)
                : Rect.fromLTWH(r.left, cursor - f / 2, r.width, f),
          );
        }
      }
    }

    final bottom = kind == FenestrationKind.window ? f : 0.0;
    final inner = Rect.fromLTRB(f, bottom, w - f, h - f);
    if (transom != null && kind == FenestrationKind.door) {
      final split = h - transom!.height;
      visit(rootSubdivision, Rect.fromLTRB(f, bottom, w - f, split - f / 2));
      visit(
        transom!.subdivision,
        Rect.fromLTRB(f, split + f / 2, w - f, h - f),
      );
      dividers.add(Rect.fromLTWH(f, split - f / 2, w - 2 * f, f));
    } else {
      visit(rootSubdivision, inner);
    }
    return FenestrationLayout(leaves, dividers);
  }

  ArchitectFenestrationStyle copyWith({
    String? id,
    String? name,
    FenestrationKind? kind,
    double? defaultWidth,
    double? defaultHeight,
    double? defaultSillHeight,
    double? frameDepth,
    double? frameFaceWidth,
    bool? centerInCore,
    GlazingType? glazingType,
    double? glazingThickness,
    int? glassColorValue,
    bool? hasCasing,
    double? casingWidth,
    double? casingProjection,
    CasingPlacement? casingPlacement,
    int? casingColorValue,
    bool? includeBottomCasing,
    FenestrationSubdivision? rootSubdivision,
    FenestrationTransom? transom,
    bool clearTransom = false,
  }) => ArchitectFenestrationStyle(
    id: id ?? this.id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    defaultWidth: defaultWidth ?? this.defaultWidth,
    defaultHeight: defaultHeight ?? this.defaultHeight,
    defaultSillHeight: defaultSillHeight ?? this.defaultSillHeight,
    frameDepth: frameDepth ?? this.frameDepth,
    frameFaceWidth: frameFaceWidth ?? this.frameFaceWidth,
    centerInCore: centerInCore ?? this.centerInCore,
    glazingType: glazingType ?? this.glazingType,
    glazingThickness: glazingThickness ?? this.glazingThickness,
    glassColorValue: glassColorValue ?? this.glassColorValue,
    hasCasing: hasCasing ?? this.hasCasing,
    casingWidth: casingWidth ?? this.casingWidth,
    casingProjection: casingProjection ?? this.casingProjection,
    casingPlacement: casingPlacement ?? this.casingPlacement,
    casingColorValue: casingColorValue ?? this.casingColorValue,
    includeBottomCasing: includeBottomCasing ?? this.includeBottomCasing,
    rootSubdivision: rootSubdivision ?? this.rootSubdivision,
    transom: clearTransom ? null : transom ?? this.transom,
  );

  /// Sets the exact metric dimension for a child leaf pane along [isWidth].
  ArchitectFenestrationStyle setPaneMetricDimension(
    String paneId,
    double newDimension,
    bool isWidth,
  ) {
    final top = transom;
    final inTop = top?.subdivision.findPane(paneId) != null;
    final tree = inTop ? top!.subdivision : rootSubdivision;
    final zoneHeight = inTop ? top!.height : doorBodyHeight;
    final rect = tree.collectPaneRects(
      Rect.fromLTWH(0, 0, defaultWidth, zoneHeight),
    )[paneId];
    if (rect == null) return this;
    final span = isWidth ? rect.width : rect.height;
    final total = isWidth ? defaultWidth : zoneHeight;
    if ((span - total).abs() < 1e-6) {
      if (isWidth) return copyWith(defaultWidth: newDimension.clamp(.40, 5.0));
      if (inTop) return withTransom(top!.copyWith(height: newDimension));
      return copyWith(defaultHeight: newDimension + (top?.height ?? 0));
    }
    final changed = tree.setChildMetricDimension(
      targetPaneId: paneId,
      newDimension: newDimension,
      bounds: Rect.fromLTWH(0, 0, defaultWidth, zoneHeight),
      isWidth: isWidth,
    );
    return inTop
        ? copyWith(transom: top!.copyWith(subdivision: changed))
        : copyWith(rootSubdivision: changed);
  }

  /// Splits an individual leaf pane identified by [paneId].
  ArchitectFenestrationStyle splitPane(
    String paneId, {
    required bool vertical,
    int count = 2,
    List<double>? customRatios,
  }) {
    if (transom?.subdivision.findPane(paneId) != null) {
      return copyWith(
        transom: transom!.copyWith(
          subdivision: transom!.subdivision.splitPane(
            paneId,
            vertical: vertical,
            count: count,
            customRatios: customRatios,
          ),
        ),
      );
    }
    return copyWith(
      rootSubdivision: rootSubdivision.splitPane(
        paneId,
        vertical: vertical,
        count: count,
        customRatios: customRatios,
      ),
    );
  }

  /// Collapses an individual division or pane back to a single leaf pane.
  ArchitectFenestrationStyle collapsePane(String paneId) {
    if (transom?.subdivision.findPane(paneId) != null) {
      return copyWith(
        transom: transom!.copyWith(
          subdivision: transom!.subdivision.collapsePane(paneId),
        ),
      );
    }
    return copyWith(rootSubdivision: rootSubdivision.collapsePane(paneId));
  }

  /// Updates a specific pane with new properties.
  ArchitectFenestrationStyle updatePane(FenestrationPane updated) {
    if (transom?.subdivision.findPane(updated.id) != null) {
      return copyWith(
        transom: transom!.copyWith(
          subdivision: transom!.subdivision.updatePane(updated),
        ),
      );
    }
    return copyWith(rootSubdivision: rootSubdivision.updatePane(updated));
  }

  /// Hit tests a metric point (x, y) relative to bottom-left opening origin.
  (FenestrationPane, Rect)? hitTest(Offset metricPoint) {
    return subdivisionForHeight(
      defaultHeight,
    ).hitTest(metricPoint, Rect.fromLTWH(0, 0, defaultWidth, defaultHeight));
  }

  /// Hit tests from canvas pixel coordinates.
  (FenestrationPane, Rect)? hitTestFromCanvas(
    Offset canvasPoint,
    Size canvasSize,
  ) {
    final margin = hasCasing ? (casingWidth * 1.8 + 0.20) : 0.25;
    final totalW = defaultWidth + margin * 2;
    final totalH = defaultHeight + margin * 2;
    final scaleX = canvasSize.width / totalW;
    final scaleY = canvasSize.height / totalH;
    final scale = math.min(scaleX, scaleY) * 0.90;
    final origin = Offset(
      canvasSize.width / 2 - (defaultWidth / 2) * scale,
      canvasSize.height / 2 + (defaultHeight / 2) * scale,
    );
    final x = (canvasPoint.dx - origin.dx) / scale;
    final y = (origin.dy - canvasPoint.dy) / scale;
    if (x < -0.05 ||
        x > defaultWidth + 0.05 ||
        y < -0.05 ||
        y > defaultHeight + 0.05) {
      return null;
    }
    final point = Offset(x, y);
    for (final entry in resolveLayout().panes.values) {
      if (entry.rect.contains(point)) return (entry.pane, entry.rect);
    }
    return null;
  }

  /// Gets the metric rect for a given pane ID.
  Rect? getPaneRect(String paneId) {
    return subdivisionForHeight(defaultHeight).collectPaneRects(
      Rect.fromLTWH(0, 0, defaultWidth, defaultHeight),
    )[paneId];
  }

  List<({Offset hinge, Offset direction, Offset normal, double length})>
  doorPlanLeaves({
    required Offset center,
    required Offset direction,
    required Offset normal,
    required double width,
    required double height,
    required double wallThickness,
    bool isHingeLeft = true,
    bool openInward = true,
    double openAngleDeg = 90,
    double cutHeight = 1.20,
  }) {
    if (kind != FenestrationKind.door) return const [];
    final entries = resolveLayout(width: width, height: height).panes.values
        .where(
          (e) =>
              e.rect.top <= cutHeight &&
              e.rect.bottom > cutHeight &&
              e.pane.isOpenable &&
              transom?.subdivision.findPane(e.pane.id) == null,
        )
        .toList();
    return [
      for (final e in entries)
        () {
          final left = entries.length == 1
              ? isHingeLeft
              : e.rect.center.dx < width / 2;
          final sign = openInward ? 1.0 : -1.0;
          final hinge =
              center +
              direction * ((left ? e.rect.left : e.rect.right) - width / 2) +
              normal * (sign * wallThickness / 2);
          final angle =
              math.atan2(direction.dy, direction.dx) +
              (left
                  ? sign * openAngleDeg * math.pi / 180
                  : math.pi - sign * openAngleDeg * math.pi / 180);
          final leafU = Offset(math.cos(angle), math.sin(angle));
          return (
            hinge: hinge,
            direction: leafU,
            normal: Offset(-leafU.dy, leafU.dx) * (sign * (left ? -1 : 1)),
            length: e.rect.width,
          );
        }(),
    ];
  }

  // ===========================================================================
  // SECTION 4: 2D PARAMETRIC PLAN DRAWING (HORIZONTAL CUT)
  // ===========================================================================

  /// Draws the horizontal 2D architectural CAD plan cut of the window/door in the wall.
  void paintPlan2D({
    required Canvas canvas,
    ArchitectCanvasPalette palette = const ArchitectCanvasPalette.light(),
    required Offset wallStart,
    required Offset wallEnd,
    required double wallThickness,
    required double coreThickness,
    required double insulationThickness,
    double? coreCenterShift,
    required double
    exteriorSign, // +1 or -1 along normal vector towards exterior
    required double offsetRatio,
    required double elementWidth,
    required double elementHeight,
    required double elementSillHeight,
    required double zoomScale,
    bool isSelected = false,
    bool wallGeometryProvided = false,
    bool showDimensions = true,
    double cutPlaneHeight = 1.20,
    bool isHingeLeft = true,
    bool openInward = true,
    double openAngleDeg = 90,
    double leafThickness = .04,
  }) {
    final wallVec = wallEnd - wallStart;
    final wallLen = wallVec.distance;
    if (wallLen < 1e-4) return;

    final u = wallVec / wallLen; // Vector along wall baseline
    final n = Offset(-u.dy, u.dx); // Vector normal across wall thickness

    final centerPos = wallStart + u * (offsetRatio * wallLen);
    final halfW = elementWidth / 2.0;
    final halfWallThick = wallThickness / 2.0;

    final pLeftBase = centerPos - u * halfW;
    final pRightBase = centerPos + u * halfW;

    // Paints
    final openingCutPaint = Paint()
      ..color = palette.background
      ..style = PaintingStyle.fill;

    final framePaint = Paint()
      ..color = isSelected
          ? const Color(0xFF00E5FF)
          : palette.foreground(const Color(0xFF263238))
      ..strokeWidth = (isSelected ? 2.2 : 1.4) / zoomScale
      ..style = PaintingStyle.stroke;

    final frameFillPaint = Paint()
      ..color = const Color(0xFFECEFF1)
      ..style = PaintingStyle.fill;

    final casingPaint = Paint()
      ..color = isSelected
          ? const Color(0xFF00E5FF)
          : palette.foreground(const Color(0xFF546E7A))
      ..strokeWidth = 1.5 / zoomScale
      ..style = PaintingStyle.stroke;

    final casingFillPaint = Paint()
      ..color = const Color(0xFFF4F5F6)
      ..style = PaintingStyle.fill;

    // 1. Cut rough wall opening through wall body (Fill with white mask)
    final maskHalfThick = halfWallThick + 1.5 / zoomScale;
    final openingPath = Path()
      ..moveTo(
        pLeftBase.dx - n.dx * maskHalfThick,
        pLeftBase.dy - n.dy * maskHalfThick,
      )
      ..lineTo(
        pRightBase.dx - n.dx * maskHalfThick,
        pRightBase.dy - n.dy * maskHalfThick,
      )
      ..lineTo(
        pRightBase.dx + n.dx * maskHalfThick,
        pRightBase.dy + n.dy * maskHalfThick,
      )
      ..lineTo(
        pLeftBase.dx + n.dx * maskHalfThick,
        pLeftBase.dy + n.dy * maskHalfThick,
      )
      ..close();
    if (!wallGeometryProvided) canvas.drawPath(openingPath, openingCutPaint);

    // 2. Wall jamb edges (Линии на зида при светлия отвор)
    if (!wallGeometryProvided) {
      canvas.drawLine(
        pLeftBase - n * halfWallThick,
        pLeftBase + n * halfWallThick,
        framePaint,
      );
      canvas.drawLine(
        pRightBase - n * halfWallThick,
        pRightBase + n * halfWallThick,
        framePaint,
      );
    }
    // 3. Frame Positioning: Center in masonry core (5-chamber depth = 70 mm)
    // Frame center is offset along normal by (exteriorSign * (wallThickness - coreThickness)/2) if asymmetric
    final resolvedCoreShift =
        coreCenterShift ??
        (wallThickness - coreThickness) / 2.0 * (-exteriorSign);
    final frameCenter = kind == FenestrationKind.door
        ? centerPos
        : centerPos + n * resolvedCoreShift;
    final halfFrameDepth =
        (kind == FenestrationKind.door ? wallThickness : frameDepth) / 2.0;

    // Draw Left and Right Frame Jambs (Каса: frameFaceWidth x frameDepth)
    void drawFrameJamb(Offset baseCorner, bool isLeft) {
      final dir = isLeft ? 1.0 : -1.0;
      final c1 = baseCorner - n * halfFrameDepth;
      final c2 = baseCorner + n * halfFrameDepth;
      final c3 = c2 + u * (dir * frameFaceWidth);
      final c4 = c1 + u * (dir * frameFaceWidth);

      final path = Path()
        ..moveTo(c1.dx, c1.dy)
        ..lineTo(c2.dx, c2.dy)
        ..lineTo(c3.dx, c3.dy)
        ..lineTo(c4.dx, c4.dy)
        ..close();

      canvas.drawPath(path, frameFillPaint);
      canvas.drawPath(path, framePaint);
    }

    drawFrameJamb(frameCenter - u * halfW, true);
    drawFrameJamb(frameCenter + u * halfW, false);

    final layout = resolveLayout(width: elementWidth, height: elementHeight);
    final cut = (cutPlaneHeight - elementSillHeight).clamp(
      .001,
      elementHeight - .001,
    );
    for (final entry in layout.panes.values) {
      final r = entry.rect;
      if (cut < r.top || cut >= r.bottom) continue;
      final isDoorLeaf =
          kind == FenestrationKind.door &&
          entry.pane.isOpenable &&
          transom?.subdivision.findPane(entry.pane.id) == null;
      if (isDoorLeaf) continue;
      ArchitectOpeningPlanPainter.paintWindowPane(
        canvas: canvas,
        left: frameCenter + u * (r.left - halfW),
        right: frameCenter + u * (r.right - halfW),
        direction: u,
        normal: n,
        frameDepth: frameDepth,
        glazingThickness: glazingThickness,
        openable: entry.pane.isOpenable,
        zoomScale: zoomScale,
        palette: palette,
        isSelected: isSelected,
      );
    }
    for (final r in layout.dividers) {
      if (cut < r.top || cut >= r.bottom) continue;
      final a = frameCenter + u * (r.left - halfW),
          b = frameCenter + u * (r.right - halfW);
      final path = Path()
        ..moveTo((a - n * halfFrameDepth).dx, (a - n * halfFrameDepth).dy)
        ..lineTo((b - n * halfFrameDepth).dx, (b - n * halfFrameDepth).dy)
        ..lineTo((b + n * halfFrameDepth).dx, (b + n * halfFrameDepth).dy)
        ..lineTo((a + n * halfFrameDepth).dx, (a + n * halfFrameDepth).dy)
        ..close();
      canvas.drawPath(path, frameFillPaint);
      canvas.drawPath(path, framePaint);
    }
    final doorLeaves = doorPlanLeaves(
      center: centerPos,
      direction: u,
      normal: n,
      width: elementWidth,
      height: elementHeight,
      wallThickness: wallThickness,
      isHingeLeft: isHingeLeft,
      openInward: openInward,
      openAngleDeg: openAngleDeg,
      cutHeight: cut,
    );
    for (final leaf in doorLeaves) {
      final a = leaf.hinge, b = a + leaf.direction * leaf.length;
      final c = b + leaf.normal * leafThickness,
          d = a + leaf.normal * leafThickness;
      canvas.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy)
          ..lineTo(c.dx, c.dy)
          ..lineTo(d.dx, d.dy)
          ..close(),
        framePaint,
      );
      final closed =
          (leaf.hinge - centerPos).dx * u.dx +
                  (leaf.hinge - centerPos).dy * u.dy <
              0
          ? u
          : -u;
      final start = math.atan2(closed.dy, closed.dx);
      var sweep = math.atan2(leaf.direction.dy, leaf.direction.dx) - start;
      while (sweep > math.pi) {
        sweep -= 2 * math.pi;
      }
      while (sweep < -math.pi) {
        sweep += 2 * math.pi;
      }
      for (var angle = 0.0; angle < sweep.abs(); angle += .08) {
        canvas.drawArc(
          Rect.fromCircle(center: a, radius: leaf.length),
          start + sweep.sign * angle,
          sweep.sign * math.min(.052, sweep.abs() - angle),
          false,
          framePaint,
        );
      }
    }

    // 6. Exterior Casing / Architrave (Обрамчване по стената и изолацията)
    // Mounted on exterior surface: coreFace + insulationThickness
    if (hasCasing) {
      for (final side in [
        if (casingPlacement != CasingPlacement.interior) exteriorSign,
        if (casingPlacement != CasingPlacement.exterior) -exteriorSign,
      ]) {
        final extFaceDist = halfWallThick; // distance to exterior surface
        final casingBaseNormal = n * (side * extFaceDist);
        final casingProjVector = n * (side * casingProjection);

        // Left Casing Ear: from (pLeft - u * casingWidth) to pLeft
        final lc1 = (pLeftBase + casingBaseNormal) - u * casingWidth;
        final lc2 = (pLeftBase + casingBaseNormal);
        final lc3 = lc2 + casingProjVector;
        final lc4 = lc1 + casingProjVector;

        final leftCasingPath = Path()
          ..moveTo(lc1.dx, lc1.dy)
          ..lineTo(lc2.dx, lc2.dy)
          ..lineTo(lc3.dx, lc3.dy)
          ..lineTo(lc4.dx, lc4.dy)
          ..close();
        canvas.drawPath(leftCasingPath, casingFillPaint);
        canvas.drawPath(leftCasingPath, casingPaint);

        // Right Casing Ear: from pRight to (pRight + u * casingWidth)
        final rc1 = (pRightBase + casingBaseNormal);
        final rc2 = (pRightBase + casingBaseNormal) + u * casingWidth;
        final rc3 = rc2 + casingProjVector;
        final rc4 = rc1 + casingProjVector;

        final rightCasingPath = Path()
          ..moveTo(rc1.dx, rc1.dy)
          ..lineTo(rc2.dx, rc2.dy)
          ..lineTo(rc3.dx, rc3.dy)
          ..lineTo(rc4.dx, rc4.dy)
          ..close();
        canvas.drawPath(rightCasingPath, casingFillPaint);
        canvas.drawPath(rightCasingPath, casingPaint);
      }
    }

    if (kind == FenestrationKind.window) {
      ArchitectOpeningPlanPainter.paintWindowSill(
        canvas: canvas,
        center: centerPos,
        direction: u,
        exteriorNormal: n * exteriorSign,
        sillHeight: elementSillHeight,
        width: elementWidth,
        wallThickness: wallThickness,
        zoomScale: zoomScale,
        palette: palette,
        isSelected: isSelected,
      );
    }

    // 8. Architectural Dimension Notation (W/H, sill)
    if (showDimensions && zoomScale > 15.0) {
      final wCm = (elementWidth * 100).round();
      final hCm = (elementHeight * 100).round();
      final sillCm = (elementSillHeight * 100).round();
      final text = kind == FenestrationKind.door && sillCm == 0
          ? '$wCm/$hCm'
          : '$wCm/$hCm\nh=$sillCm';

      final tp = ArchitectTextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: isSelected
                ? const Color(0xFF00E5FF)
                : palette.foreground(const Color(0xFF45515B)),
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            height: 1.1,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      final labelPos = centerPos + n * (halfWallThick + 0.20);
      canvas.translate(labelPos.dx, labelPos.dy);

      double angle = math.atan2(u.dy, u.dx);
      if (angle > math.pi / 2 || angle < -math.pi / 2) {
        angle += math.pi;
      }
      canvas.rotate(angle);
      canvas.scale(1.0 / zoomScale);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  // ===========================================================================
  // SECTION 5: 2D PARAMETRIC ELEVATION DRAWING (FACADE CUT)
  // ===========================================================================

  /// Draws the interactive 2D facade elevation in the editor workspace.
  void paintElevation2D({
    required Canvas canvas,
    required Size size,
    String? selectedPaneId,
    bool showDimensions = true,
  }) {
    final margin = hasCasing ? (casingWidth * 1.8 + 0.20) : 0.25;
    final totalW = defaultWidth + margin * 2;
    final totalH = defaultHeight + margin * 2;

    final scaleX = size.width / totalW;
    final scaleY = size.height / totalH;
    final scale = math.min(scaleX, scaleY) * 0.90;

    final origin = Offset(
      size.width / 2 - (defaultWidth / 2) * scale,
      size.height / 2 + (defaultHeight / 2) * scale,
    );

    // Paints
    final framePaint = Paint()
      ..color = const Color(0xFF37474F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final frameFill = Paint()
      ..color = const Color(0xFFECEFF1)
      ..style = PaintingStyle.fill;

    final glassFill = Paint()
      ..color = const Color(0xFFF7F9FA)
      ..style = PaintingStyle.fill;

    final swingLinePaint = Paint()
      ..color = const Color(0xFF78909C)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final selectedPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final casingPaint = Paint()
      ..color = const Color(0xFF546E7A)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final casingFill = Paint()
      ..color = const Color(0xFFF4F5F6)
      ..style = PaintingStyle.fill;

    // Helper: converts metric (x, y from bottom-left) to canvas pixels
    Offset toCanvas(double x, double y) =>
        Offset(origin.dx + x * scale, origin.dy - y * scale);

    // 1. Exterior Casing (if enabled)
    if (hasCasing) {
      final cLeft = -casingWidth;
      final cRight = defaultWidth + casingWidth;
      final cTop = defaultHeight + casingWidth;
      final cBottom = includeBottomCasing ? -casingWidth : 0.0;

      final p1 = toCanvas(cLeft, cTop);
      final p2 = toCanvas(cRight, cTop);
      final p3 = toCanvas(cRight, cBottom);
      final p4 = toCanvas(cLeft, cBottom);

      final casingOuter = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..lineTo(p4.dx, p4.dy)
        ..close();

      final openingP1 = toCanvas(0, defaultHeight);
      final openingP2 = toCanvas(defaultWidth, defaultHeight);
      final openingP3 = toCanvas(defaultWidth, 0);
      final openingP4 = toCanvas(0, 0);

      final casingInner = Path()
        ..moveTo(openingP1.dx, openingP1.dy)
        ..lineTo(openingP2.dx, openingP2.dy)
        ..lineTo(openingP3.dx, openingP3.dy)
        ..lineTo(openingP4.dx, openingP4.dy)
        ..close();

      final fullCasing = Path.combine(
        PathOperation.difference,
        casingOuter,
        casingInner,
      );
      canvas.drawPath(fullCasing, casingFill);
      canvas.drawPath(fullCasing, casingPaint);
    }

    // 2. Outer Frame Outer Box
    final o1 = toCanvas(0, defaultHeight);
    final o2 = toCanvas(defaultWidth, defaultHeight);
    final o3 = toCanvas(defaultWidth, 0);
    final o4 = toCanvas(0, 0);

    final outerPath = Path()
      ..moveTo(o1.dx, o1.dy)
      ..lineTo(o2.dx, o2.dy)
      ..lineTo(o3.dx, o3.dy)
      ..lineTo(o4.dx, o4.dy)
      ..close();

    canvas.drawPath(outerPath, frameFill);
    canvas.drawPath(outerPath, framePaint);

    // Physical layout is shared with 3D and the horizontal cut.
    final layout = resolveLayout();
    for (final divider in layout.dividers) {
      final r = Rect.fromPoints(
        toCanvas(divider.left, divider.top),
        toCanvas(divider.right, divider.bottom),
      );
      canvas.drawRect(r, frameFill);
      canvas.drawRect(r, framePaint);
    }
    for (final entry in layout.panes.values) {
      _renderSubdivisionElevation(
        canvas: canvas,
        node: FenestrationSubdivision(id: entry.pane.id, pane: entry.pane),
        rect: entry.rect.inflate(frameFaceWidth),
        frameFace: frameFaceWidth,
        toCanvas: toCanvas,
        scale: scale,
        framePaint: framePaint,
        frameFill: frameFill,
        glassFill: glassFill,
        swingLinePaint: swingLinePaint,
        selectedPaint: selectedPaint,
        selectedPaneId: selectedPaneId,
      );
    }
    if (showDimensions) _drawElevationDimensions(canvas, origin, scale);
  }

  void _renderSubdivisionElevation({
    required Canvas canvas,
    required FenestrationSubdivision node,
    required Rect rect, // in meters: left, top=bottom-based, width, height
    required double frameFace,
    required Offset Function(double x, double y) toCanvas,
    required double scale,
    required Paint framePaint,
    required Paint frameFill,
    required Paint glassFill,
    required Paint swingLinePaint,
    required Paint selectedPaint,
    String? selectedPaneId,
  }) {
    // Leaf Pane
    final pane = node.pane;
    if (pane == null) return;

    // Pane daylight inner opening
    final inset = frameFace;
    final inX = rect.left + inset;
    final inY = rect.top + inset;
    final inW = math.max(0.05, rect.width - 2 * inset);
    final inH = math.max(0.05, rect.height - 2 * inset);

    final cp1 = toCanvas(inX, inY + inH);
    final cp2 = toCanvas(inX + inW, inY + inH);
    final cp3 = toCanvas(inX + inW, inY);
    final cp4 = toCanvas(inX, inY);

    final panePath = Path()
      ..moveTo(cp1.dx, cp1.dy)
      ..lineTo(cp2.dx, cp2.dy)
      ..lineTo(cp3.dx, cp3.dy)
      ..lineTo(cp4.dx, cp4.dy)
      ..close();

    // Fill glass / solid
    if (pane.isGlazed) {
      canvas.drawPath(panePath, glassFill);
    } else {
      canvas.drawPath(
        panePath,
        Paint()
          ..color = const Color(0xFFF1F1F1)
          ..style = PaintingStyle.fill,
      );
    }
    canvas.drawPath(panePath, framePaint);

    // If moving sash, draw nested sash profile and swing triangle
    if (pane.isOpenable) {
      final sProfile = pane.sashProfileWidth;
      final sX = inX + sProfile;
      final sY = inY + sProfile;
      final sW = math.max(0.04, inW - 2 * sProfile);
      final sH = math.max(0.04, inH - 2 * sProfile);

      final sp1 = toCanvas(sX, sY + sH);
      final sp2 = toCanvas(sX + sW, sY + sH);
      final sp3 = toCanvas(sX + sW, sY);
      final sp4 = toCanvas(sX, sY);

      final sashInnerPath = Path()
        ..moveTo(sp1.dx, sp1.dy)
        ..lineTo(sp2.dx, sp2.dy)
        ..lineTo(sp3.dx, sp3.dy)
        ..lineTo(sp4.dx, sp4.dy)
        ..close();

      // Distinct sash frame body between outer daylight opening and glass
      final sashFramePath = Path.combine(
        PathOperation.difference,
        panePath,
        sashInnerPath,
      );
      canvas.drawPath(
        sashFramePath,
        Paint()
          ..color = const Color(0xFFECEFF1)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(sashFramePath, framePaint);
      canvas.drawPath(sashInnerPath, framePaint);

      // Swing direction symbol (European CAD standard triangle pointing from hinges to handle)
      final midH = toCanvas(inX + inW, inY + inH / 2.0);
      final midL = toCanvas(inX, inY + inH / 2.0);
      final midTop = toCanvas(inX + inW / 2.0, inY + inH);

      if (pane.paneType == PaneType.casementLeft) {
        // Hinge on left, apex on right center
        canvas.drawLine(cp1, midH, swingLinePaint);
        canvas.drawLine(cp4, midH, swingLinePaint);
      } else if (pane.paneType == PaneType.casementRight) {
        // Hinge on right, apex on left center
        canvas.drawLine(cp2, midL, swingLinePaint);
        canvas.drawLine(cp3, midL, swingLinePaint);
      } else if (pane.paneType == PaneType.tiltAndTurn) {
        // Hinge left + bottom tilt
        canvas.drawLine(cp1, midH, swingLinePaint);
        canvas.drawLine(cp4, midH, swingLinePaint);
        canvas.drawLine(cp4, midTop, swingLinePaint);
        canvas.drawLine(cp3, midTop, swingLinePaint);
      } else if (pane.paneType == PaneType.topHopper) {
        // Bottom hinge, top apex
        canvas.drawLine(cp4, midTop, swingLinePaint);
        canvas.drawLine(cp3, midTop, swingLinePaint);
      } else if (pane.paneType == PaneType.doorLeaf) {
        // Door leaf diagonal
        canvas.drawLine(cp1, midH, swingLinePaint);
        canvas.drawLine(cp4, midH, swingLinePaint);
      }

      // Draw CAD handle icon
      final handleOffset = pane.paneType == PaneType.casementLeft
          ? midH - const Offset(12, 0)
          : pane.paneType == PaneType.casementRight
          ? midL + const Offset(12, 0)
          : pane.paneType == PaneType.tiltAndTurn
          ? midH - const Offset(12, 0)
          : pane.paneType == PaneType.doorLeaf
          ? midH - const Offset(14, 0)
          : null;
      if (handleOffset != null) {
        final hR = RRect.fromRectAndRadius(
          Rect.fromCenter(center: handleOffset, width: 6, height: 16),
          const Radius.circular(3),
        );
        canvas.drawRRect(
          hR,
          Paint()
            ..color = const Color(0xFF263238)
            ..style = PaintingStyle.fill,
        );
      }
    }

    // Draw Muntin bars (шпроси) if configured
    if (pane.hasMuntins) {
      final gL = pane.isOpenable ? (inX + pane.sashProfileWidth) : inX;
      final gB = pane.isOpenable ? (inY + pane.sashProfileWidth) : inY;
      final gW = pane.isOpenable
          ? math.max(0.04, inW - 2 * pane.sashProfileWidth)
          : inW;
      final gH = pane.isOpenable
          ? math.max(0.04, inH - 2 * pane.sashProfileWidth)
          : inH;
      final mW = pane.muntinWidth;

      for (int c = 1; c <= pane.muntinCols; c++) {
        final mx = gL + (gW / (pane.muntinCols + 1)) * c;
        final p1 = toCanvas(mx - mW / 2, gB + gH);
        final p2 = toCanvas(mx + mW / 2, gB);
        final mR = Rect.fromPoints(p1, p2);
        canvas.drawRect(mR, frameFill);
        canvas.drawRect(mR, framePaint);
      }
      for (int r = 1; r <= pane.muntinRows; r++) {
        final my = gB + (gH / (pane.muntinRows + 1)) * r;
        final p1 = toCanvas(gL, my + mW / 2);
        final p2 = toCanvas(gL + gW, my - mW / 2);
        final mR = Rect.fromPoints(p1, p2);
        canvas.drawRect(mR, frameFill);
        canvas.drawRect(mR, framePaint);
      }
    }

    // If selected, highlight with glowing cyan border and dimension pill
    if (pane.id == selectedPaneId) {
      canvas.drawPath(panePath, selectedPaint);
      canvas.drawPath(
        panePath,
        Paint()
          ..color = const Color(0xFF00E5FF)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke,
      );

      // Dimension pill in center of selected pane
      final centerP = toCanvas(inX + inW / 2, inY + inH / 2);
      final nominal = getPaneRect(pane.id) ?? rect;
      final dimStr =
          '${(nominal.width * 100).round()} × ${(nominal.height * 100).round()} cm';
      final dimTp = ArchitectTextPainter(
        text: TextSpan(
          text: dimStr,
          style: const TextStyle(
            color: Color(0xFF00E5FF),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final badgeRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: centerP,
          width: dimTp.width + 12,
          height: dimTp.height + 6,
        ),
        const Radius.circular(4),
      );
      canvas.drawRRect(
        badgeRect,
        Paint()
          ..color = const Color(0xF2FFFFFF)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(
        badgeRect,
        Paint()
          ..color = const Color(0xFF00E5FF)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke,
      );
      dimTp.paint(canvas, centerP - Offset(dimTp.width / 2, dimTp.height / 2));
    }
  }

  void _drawElevationDimensions(Canvas canvas, Offset origin, double scale) {
    final dimPaint = Paint()
      ..color = const Color(0xFF45515B)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const dimOffset = 32.0;

    // Segmented dimension chains for individual columns at bottom
    final slices =
        rootSubdivision
            .collectPaneRects(Rect.fromLTWH(0, 0, defaultWidth, doorBodyHeight))
            .values
            .where(
              (r) =>
                  r.top <= doorBodyHeight / 2 && r.bottom > doorBodyHeight / 2,
            )
            .toList()
          ..sort((a, b) => a.left.compareTo(b.left));
    if (slices.length > 1) {
      final subY = origin.dy + 14.0;
      for (final slice in slices) {
        final sX1 = origin.dx + slice.left * scale;
        final sX2 = origin.dx + slice.right * scale;
        canvas.drawLine(Offset(sX1, subY), Offset(sX2, subY), dimPaint);
        canvas.drawLine(Offset(sX1, subY - 3), Offset(sX1, subY + 3), dimPaint);
        canvas.drawLine(Offset(sX2, subY - 3), Offset(sX2, subY + 3), dimPaint);
        final sText = '${((slice.right - slice.left) * 100).round()}';
        final sTp = ArchitectTextPainter(
          text: TextSpan(
            text: sText,
            style: const TextStyle(
              color: Color(0xFF0277BD),
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        sTp.paint(canvas, Offset((sX1 + sX2) / 2 - sTp.width / 2, subY + 2));
      }
    }

    // Bottom horizontal dimension (Total Width in cm)
    final bY = origin.dy + dimOffset;
    final bX1 = origin.dx;
    final bX2 = origin.dx + defaultWidth * scale;
    canvas.drawLine(Offset(bX1, bY), Offset(bX2, bY), dimPaint);
    canvas.drawLine(Offset(bX1, bY - 4), Offset(bX1, bY + 4), dimPaint);
    canvas.drawLine(Offset(bX2, bY - 4), Offset(bX2, bY + 4), dimPaint);

    final wText = '${(defaultWidth * 100).round()} cm';
    final wPainter = ArchitectTextPainter(
      text: TextSpan(
        text: wText,
        style: const TextStyle(
          color: Color(0xFF0277BD),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    wPainter.paint(
      canvas,
      Offset((bX1 + bX2) / 2 - wPainter.width / 2, bY + 2),
    );

    // Left vertical dimension (Total Height in cm)
    final lX = origin.dx - dimOffset;
    final lY1 = origin.dy;
    final lY2 = origin.dy - defaultHeight * scale;
    canvas.drawLine(Offset(lX, lY1), Offset(lX, lY2), dimPaint);
    canvas.drawLine(Offset(lX - 4, lY1), Offset(lX + 4, lY1), dimPaint);
    canvas.drawLine(Offset(lX - 4, lY2), Offset(lX + 4, lY2), dimPaint);

    final hText = '${(defaultHeight * 100).round()} cm';
    final hPainter = ArchitectTextPainter(
      text: TextSpan(
        text: hText,
        style: const TextStyle(
          color: Color(0xFF0277BD),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(lX - 4, (lY1 + lY2) / 2);
    canvas.rotate(-math.pi / 2);
    hPainter.paint(canvas, Offset(-hPainter.width / 2, -hPainter.height));
    canvas.restore();
  }

  /// Returns the localized display name for preset styles, or [name] for custom user styles.
  String localizedName(AppLocalizations l10n) {
    switch (id) {
      case 'win_single_casement':
        return l10n.architectFenestrationPresetSingleCasement;
      case 'win_double_casement':
        return l10n.architectFenestrationPresetDoubleCasement;
      case 'win_double_with_casing':
        return l10n.architectFenestrationPresetDoubleWithCasing;
      case 'win_triple_casement':
        return l10n.architectFenestrationPresetTripleCasement;
      case 'win_with_transom':
        return l10n.architectFenestrationPresetWithTransom;
      case 'door_interior_standard':
        return l10n.architectFenestrationPresetDoorInterior;
      case 'door_entrance_casing':
        return l10n.architectFenestrationPresetDoorEntranceCasing;
      case 'door_balcony_glass':
        return l10n.architectFenestrationPresetDoorBalconyGlass;
      default:
        return name;
    }
  }

  // ===========================================================================
  // SECTION 6: STANDARD PRESETS CATALOG
  // ===========================================================================

  static List<ArchitectFenestrationStyle> standardCatalog() => [
    // 1. Single Casement Window 80x140 cm (5-chamber, double glazing)
    ArchitectFenestrationStyle(
      id: 'win_single_casement',
      name: 'Еднокрил 80/140 (5-камерен)',
      kind: FenestrationKind.window,
      defaultWidth: 0.80,
      defaultHeight: 1.40,
      defaultSillHeight: 0.85,
      hasCasing: false,
      rootSubdivision: const FenestrationSubdivision(
        id: 'root',
        pane: FenestrationPane(id: 'pane_main', paneType: PaneType.tiltAndTurn),
      ),
    ),

    // 2. Double Casement Window 140x140 cm (1 turn + 1 tilt&turn)
    ArchitectFenestrationStyle(
      id: 'win_double_casement',
      name: 'Двукрил 140/140 (5-камерен)',
      kind: FenestrationKind.window,
      defaultWidth: 1.40,
      defaultHeight: 1.40,
      defaultSillHeight: 0.85,
      hasCasing: false,
      rootSubdivision: const FenestrationSubdivision(
        id: 'root',
        isSplit: true,
        isVertical: true,
        ratios: [0.5, 0.5],
        children: [
          FenestrationSubdivision(
            id: 'sub_0',
            pane: FenestrationPane(
              id: 'p_left',
              paneType: PaneType.casementLeft,
            ),
          ),
          FenestrationSubdivision(
            id: 'sub_1',
            pane: FenestrationPane(
              id: 'p_right',
              paneType: PaneType.tiltAndTurn,
            ),
          ),
        ],
      ),
    ),

    // 3. Double Casement Window with Exterior Casing (10 cm trim, 3 cm projection)
    ArchitectFenestrationStyle(
      id: 'win_double_with_casing',
      name: 'Двукрил 140/140 с обрамчване',
      kind: FenestrationKind.window,
      defaultWidth: 1.40,
      defaultHeight: 1.40,
      defaultSillHeight: 0.85,
      hasCasing: true,
      casingWidth: 0.10,
      casingProjection: 0.03,
      rootSubdivision: const FenestrationSubdivision(
        id: 'root',
        isSplit: true,
        isVertical: true,
        ratios: [0.5, 0.5],
        children: [
          FenestrationSubdivision(
            id: 'sub_0',
            pane: FenestrationPane(
              id: 'p_left',
              paneType: PaneType.casementLeft,
            ),
          ),
          FenestrationSubdivision(
            id: 'sub_1',
            pane: FenestrationPane(
              id: 'p_right',
              paneType: PaneType.tiltAndTurn,
            ),
          ),
        ],
      ),
    ),

    // 4. Triple Casement Window 210x140 cm (center fixed, 2 sides open)
    ArchitectFenestrationStyle(
      id: 'win_triple_casement',
      name: 'Трикрил 210/140 (фикс + 2 крила)',
      kind: FenestrationKind.window,
      defaultWidth: 2.10,
      defaultHeight: 1.40,
      defaultSillHeight: 0.85,
      hasCasing: false,
      rootSubdivision: const FenestrationSubdivision(
        id: 'root',
        isSplit: true,
        isVertical: true,
        ratios: [0.333, 0.334, 0.333],
        children: [
          FenestrationSubdivision(
            id: 'sub_0',
            pane: FenestrationPane(
              id: 'p_left',
              paneType: PaneType.casementLeft,
            ),
          ),
          FenestrationSubdivision(
            id: 'sub_1',
            pane: FenestrationPane(
              id: 'p_mid',
              paneType: PaneType.fixedGlazing,
            ),
          ),
          FenestrationSubdivision(
            id: 'sub_2',
            pane: FenestrationPane(
              id: 'p_right',
              paneType: PaneType.tiltAndTurn,
            ),
          ),
        ],
      ),
    ),

    // 5. Window with Transom 140x180 cm (Фрамуга горе + 2 крила долу)
    ArchitectFenestrationStyle(
      id: 'win_with_transom',
      name: 'Прозорец с надстройка 140/180',
      kind: FenestrationKind.window,
      defaultWidth: 1.40,
      defaultHeight: 1.80,
      defaultSillHeight: 0.85,
      hasCasing: false,
      rootSubdivision: const FenestrationSubdivision(
        id: 'root',
        isSplit: true,
        isVertical: false, // horizontal transom
        ratios: [0.75, 0.25], // lower 1.35m, upper 0.45m
        children: [
          FenestrationSubdivision(
            id: 'sub_lower',
            isSplit: true,
            isVertical: true,
            ratios: [0.5, 0.5],
            children: [
              FenestrationSubdivision(
                id: 'sub_l0',
                pane: FenestrationPane(
                  id: 'p_l0',
                  paneType: PaneType.casementLeft,
                ),
              ),
              FenestrationSubdivision(
                id: 'sub_l1',
                pane: FenestrationPane(
                  id: 'p_l1',
                  paneType: PaneType.tiltAndTurn,
                ),
              ),
            ],
          ),
          FenestrationSubdivision(
            id: 'sub_upper',
            pane: FenestrationPane(
              id: 'p_transom',
              paneType: PaneType.topHopper,
            ),
          ),
        ],
      ),
    ),

    // 6. Standard Interior Door 90x200 cm
    ArchitectFenestrationStyle(
      id: 'door_interior_standard',
      name: 'Интериорна врата 90/200',
      kind: FenestrationKind.door,
      defaultWidth: 0.90,
      defaultHeight: 2.00,
      defaultSillHeight: 0.00,
      frameFaceWidth: 0.04,
      frameDepth: 0.05,
      hasCasing: false,
      rootSubdivision: const FenestrationSubdivision(
        id: 'root',
        pane: FenestrationPane(id: 'p_door', paneType: PaneType.doorLeaf),
      ),
    ),

    // 7. Exterior Entrance Door with Casing & Glass Side Infill 100x210 cm
    ArchitectFenestrationStyle(
      id: 'door_entrance_casing',
      name: 'Входна врата с обрамчване 100/210',
      kind: FenestrationKind.door,
      defaultWidth: 1.00,
      defaultHeight: 2.10,
      defaultSillHeight: 0.00,
      frameFaceWidth: 0.07,
      frameDepth: 0.07,
      hasCasing: true,
      casingWidth: 0.10,
      casingProjection: 0.03,
      includeBottomCasing: false,
      rootSubdivision: const FenestrationSubdivision(
        id: 'root',
        pane: FenestrationPane(id: 'p_entrance', paneType: PaneType.doorLeaf),
      ),
    ),

    // 8. Single Glazed Balcony / Terrace Door 90x210 cm (5-chamber, double glazing)
    ArchitectFenestrationStyle(
      id: 'door_balcony_glass',
      name: 'Балконска остъклена врата 90/210',
      kind: FenestrationKind.door,
      defaultWidth: 0.90,
      defaultHeight: 2.10,
      defaultSillHeight: 0.00,
      frameFaceWidth: 0.07,
      frameDepth: 0.07,
      hasCasing: false,
      rootSubdivision: const FenestrationSubdivision(
        id: 'root',
        pane: FenestrationPane(
          id: 'p_balcony_glass',
          paneType: PaneType.tiltAndTurn,
        ),
      ),
    ),
  ];

  // ===========================================================================
  // SECTION 7: JSON SERIALIZATION
  // ===========================================================================

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'defaultWidth': defaultWidth,
    'defaultHeight': defaultHeight,
    'defaultSillHeight': defaultSillHeight,
    'frameDepth': frameDepth,
    'frameFaceWidth': frameFaceWidth,
    'centerInCore': centerInCore,
    'glazingType': glazingType.name,
    'glazingThickness': glazingThickness,
    'glassColorValue': glassColorValue,
    'hasCasing': hasCasing,
    'casingWidth': casingWidth,
    'casingProjection': casingProjection,
    'casingPlacement': casingPlacement.name,
    'casingColorValue': casingColorValue,
    'includeBottomCasing': includeBottomCasing,
    'rootSubdivision': rootSubdivision.toJson(),
    if (transom != null) 'transom': transom!.toJson(),
  };

  factory ArchitectFenestrationStyle.fromJson(
    Map<String, dynamic> json,
  ) => ArchitectFenestrationStyle(
    id: json['id'] as String,
    name: json['name'] as String,
    kind: FenestrationKind.values.firstWhere(
      (k) => k.name == json['kind'],
      orElse: () => FenestrationKind.window,
    ),
    defaultWidth: (json['defaultWidth'] as num?)?.toDouble() ?? 1.40,
    defaultHeight: (json['defaultHeight'] as num?)?.toDouble() ?? 1.40,
    defaultSillHeight: (json['defaultSillHeight'] as num?)?.toDouble() ?? 0.85,
    frameDepth: (json['frameDepth'] as num?)?.toDouble() ?? 0.07,
    frameFaceWidth: (json['frameFaceWidth'] as num?)?.toDouble() ?? 0.07,
    centerInCore: json['centerInCore'] as bool? ?? true,
    glazingType: GlazingType.values.firstWhere(
      (g) => g.name == json['glazingType'],
      orElse: () => GlazingType.double,
    ),
    glazingThickness: (json['glazingThickness'] as num?)?.toDouble() ?? 0.024,
    glassColorValue: (json['glassColorValue'] as num?)?.toInt() ?? 0x884FC3F7,
    hasCasing: json['hasCasing'] as bool? ?? false,
    casingWidth: (json['casingWidth'] as num?)?.toDouble() ?? 0.10,
    casingProjection: (json['casingProjection'] as num?)?.toDouble() ?? 0.03,
    casingPlacement: CasingPlacement.values.firstWhere(
      (c) => c.name == json['casingPlacement'],
      orElse: () => CasingPlacement.exterior,
    ),
    casingColorValue: (json['casingColorValue'] as num?)?.toInt() ?? 0xFFECEFF1,
    includeBottomCasing: json['includeBottomCasing'] as bool? ?? false,
    rootSubdivision: FenestrationSubdivision.fromJson(
      json['rootSubdivision'] as Map<String, dynamic>,
    ),
    transom: json['transom'] is Map<String, dynamic>
        ? FenestrationTransom.fromJson(json['transom'] as Map<String, dynamic>)
        : null,
  );
}
