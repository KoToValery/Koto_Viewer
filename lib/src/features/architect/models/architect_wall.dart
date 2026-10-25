import 'dart:math' as math;
import 'dart:ui';
import '../../bim_editing/geometry/bim_line_geometry.dart';
import 'package:flutter/material.dart';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import 'architect_door.dart';
import 'architect_elements.dart'
    show ArchitectCutDisplayMode, FenestrationElevationDetail;
import 'architect_wall_type.dart';
import 'architect_window.dart';
import 'architect_wall_arc.dart';
import '../rendering/architect_path_solid.dart';
export 'architect_wall_arc.dart';

/// Legacy left/right retain their saved physical placement.
enum WallReferenceLine { center, inner, outer, left, right }

enum WallExteriorSide { left, right }

/// The physical line picked on a source wall, rather than its saved reference.
class ArchitectWallAttachment {
  final ArchitectWall source;
  final WallReferenceLine reference;
  const ArchitectWallAttachment(this.source, this.reference);

  WallExteriorSide sideFor(
    Offset start,
    Offset end,
    double thickness,
    double insulation,
  ) {
    final delta = end - start;
    if (delta.distance < .001) return source.exteriorSide;
    final normal = Offset(-delta.dy, delta.dx) / delta.distance;
    final aligned =
        normal.dx * source.exteriorNormal.dx +
        normal.dy * source.exteriorNormal.dy;
    if (aligned.abs() > 1e-6) {
      return aligned > 0 ? WallExteriorSide.left : WallExteriorSide.right;
    }
    // At a perpendicular corner, keep the core inside the source's end cap.
    double score(WallExteriorSide side) {
      final candidate = ArchitectWall(
        id: 'attachment',
        startPoint: start,
        endPoint: end,
        thickness: thickness,
        insulationThicknessOverride: insulation,
        referenceLine: reference,
        exteriorSide: side,
      );
      final d = candidate.coreCenterStart - source.coreCenterStart;
      final along = d.dx * source.unitVector.dx + d.dy * source.unitVector.dy;
      return math.min(along, source.length - along);
    }

    return score(WallExteriorSide.left) >= score(WallExteriorSide.right)
        ? WallExteriorSide.left
        : WallExteriorSide.right;
  }
}

/// Represents an architectural parametric wall with hosted openings (doors/windows).
class ArchitectWall {
  final String id;
  final double arcBulge;
  final List<ArchitectMaterialLayer> layers;
  final ArchitectWallLocation? location;
  final bool loadBearing;
  final ArchitectWallPlinth plinth;
  final Offset startPoint;
  final Offset endPoint;
  final double thickness; // in meters (default 0.25 m = 25 cm)
  final double height; // in meters (default 2.80 m or 1.05/1.20 m for parapets)
  final double
  baseOffset; // in meters relative to storey elevation (default 0.0 m)
  final bool followStoreyHeight;
  final WallCoreMaterial? coreMaterialOverride;
  final WallInsulationMaterial insulationMaterial;
  final WallReferenceLine referenceLine;
  final WallExteriorSide exteriorSide;
  final double? insulationThicknessOverride;
  final bool connectStart;
  final bool connectEnd;
  final String? wallTypeId;
  final ParapetFinish? parapetFinish;
  final ArchitectCutDisplayMode cutDisplayMode;
  final List<ArchitectDoor> doors;
  final List<ArchitectWindow> windows;

  const ArchitectWall({
    required this.id,
    this.arcBulge = 0,
    this.layers = const [],
    this.location,
    this.loadBearing = false,
    this.plinth = const ArchitectWallPlinth(),
    required this.startPoint,
    required this.endPoint,
    this.thickness = 0.25,
    this.height = 2.80,
    this.baseOffset = 0.0,
    this.followStoreyHeight = true,
    this.coreMaterialOverride,
    this.insulationMaterial = WallInsulationMaterial.eps,
    this.referenceLine = WallReferenceLine.center,
    this.exteriorSide = WallExteriorSide.left,
    this.insulationThicknessOverride,
    this.connectStart = true,
    this.connectEnd = true,
    this.wallTypeId,
    this.parapetFinish,
    this.cutDisplayMode = ArchitectCutDisplayMode.auto,
    this.doors = const [],
    this.windows = const [],
  });

  bool get isParapet =>
      height < 1.50 || (wallTypeId != null && wallTypeId!.contains('parapet'));

  bool isCutAt(double storeyCutPlane) {
    return switch (cutDisplayMode) {
      ArchitectCutDisplayMode.cut => true,
      ArchitectCutDisplayMode.projected => false,
      ArchitectCutDisplayMode.overhead => false,
      ArchitectCutDisplayMode.auto => () {
        if (isParapet) return false;
        final zLow = baseOffset;
        final zHigh = baseOffset + height;
        return zLow <= storeyCutPlane && storeyCutPlane <= zHigh;
      }(),
    };
  }

  bool isOverheadAt(double storeyCutPlane) {
    return switch (cutDisplayMode) {
      ArchitectCutDisplayMode.overhead => true,
      ArchitectCutDisplayMode.auto => baseOffset > storeyCutPlane,
      _ => false,
    };
  }

  double effectiveHeight(double storeyHeight) =>
      followStoreyHeight && !isParapet ? storeyHeight : height;
  WallCoreMaterial get coreMaterial =>
      (layers.isNotEmpty
          ? WallCoreMaterial.values
                .where(
                  (m) =>
                      m.name ==
                      layers
                          .firstWhere((l) => l.role == ArchitectLayerRole.core)
                          .material
                          .name,
                )
                .firstOrNull
          : null) ??
      coreMaterialOverride ??
      (wallTypeId == 'bearing_25_concrete'
          ? WallCoreMaterial.concrete
          : WallCoreMaterial.brick);

  bool get isCurved => arcBulge.abs() > 1e-8;
  ArchitectWallArc? get arc =>
      isCurved ? ArchitectWallArc(startPoint, endPoint, arcBulge) : null;
  double get length => arc?.length ?? (endPoint - startPoint).distance;
  double get centerLineOffset =>
      centerOffset.dx * normalVector.dx + centerOffset.dy * normalVector.dy;
  Offset referencePointAt(double ratio) =>
      arc?.pointAt(ratio) ?? startPoint + (endPoint - startPoint) * ratio;
  Offset tangentAt(double ratio) => arc?.tangentAt(ratio) ?? unitVector;
  Offset normalAt(double ratio) {
    final u = tangentAt(ratio);
    return Offset(-u.dy, u.dx);
  }

  Offset centerPointAt(double ratio) =>
      arc?.pointAt(ratio, leftOffset: centerLineOffset) ??
      centerStart + unitVector * (length * ratio);
  (Offset, Offset) openingAxis(double ratio) {
    final p = centerPointAt(ratio), u = tangentAt(ratio);
    return (p - u * (length * ratio), p + u * (length * (1 - ratio)));
  }

  List<Offset> facePolygon(
    double low,
    double high, {
    double from = 0,
    double to = 1,
  }) =>
      arc?.face(
        low,
        high,
        from: from,
        to: to,
        envelopeOffset: centerLineOffset.abs() + thickness / 2,
      ) ??
      [
        referencePointAt(from) + normalVector * low,
        referencePointAt(to) + normalVector * low,
        referencePointAt(to) + normalVector * high,
        referencePointAt(from) + normalVector * high,
      ];
  void validateGeometry() {
    if (!arcBulge.isFinite ||
        arcBulge.abs() > 100 ||
        (isCurved &&
            arc!.radius -
                    math.max(
                      (centerLineOffset - thickness / 2).abs(),
                      (centerLineOffset + thickness / 2).abs(),
                    ) <=
                .001)) {
      throw ArgumentError('Invalid wall arc radius');
    }
    if (isCurved) {
      for (final opening in [
        ...doors.map((o) => (o.offsetRatio, o.width)),
        ...windows.map((o) => (o.offsetRatio, o.width)),
      ]) {
        final half = openingArcSpan(opening.$2) / 2;
        if (!half.isFinite ||
            opening.$1 * length < half - 1e-8 ||
            (1 - opening.$1) * length < half - 1e-8) {
          throw ArgumentError('Opening does not fit the curved host');
        }
      }
    }
  }

  /// A straight frame cuts a chord; its occupied angle must fit every skin.
  double openingArcSpan(double width) {
    if (!isCurved) return width;
    final inner = arc!.radius - (centerLineOffset.abs() + thickness / 2);
    if (!width.isFinite || width <= 0 || inner <= 0 || width >= 2 * inner) {
      return double.infinity;
    }
    return 2 * arc!.radius * math.asin(width / (2 * inner));
  }

  List<Offset> intersections(ArchitectWall other, {bool finite = true}) {
    if (isCurved && other.isCurved) {
      return arc!.arcIntersections(other.arc!, finite: finite);
    }
    if (isCurved) {
      return arc!.lineIntersections(
        other.startPoint,
        other.endPoint,
        finite: finite,
      );
    }
    if (other.isCurved) {
      return other.arc!.lineIntersections(startPoint, endPoint, finite: finite);
    }
    final p = BimLineGeometry.intersection(
      startPoint,
      endPoint,
      other.startPoint,
      other.endPoint,
      firstFinite: finite,
      secondFinite: finite,
    );
    return [?p];
  }

  ArchitectWall withExtendedEnds({Offset? start, Offset? end}) {
    if (!isCurved) return copyWith(startPoint: start, endPoint: end);
    final a = start ?? startPoint,
        b = end ?? endPoint,
        from = arc!.parameter(a),
        to = arc!.parameter(b),
        sweep = arc!.sweep * (to - from);
    if (sweep.abs() < .000001 ||
        sweep.abs() >= 2 * math.pi - .0001 ||
        sweep.sign != arc!.sweep.sign) {
      throw ArgumentError('Invalid arc extension');
    }
    final result = copyWith(
      startPoint: a,
      endPoint: b,
      arcBulge: math.tan(sweep / 4),
    );
    result.validateGeometry();
    return result;
  }

  static final _standardInsulation = {
    for (final type in ArchitectWallType.standardCatalog())
      type.id: type.insulationThickness,
  };
  double get insulationThickness => layers.isNotEmpty
      ? layers
            .where((l) => l.role == ArchitectLayerRole.insulation)
            .fold(0.0, (v, l) => v + l.thickness)
      : (insulationThicknessOverride ?? _standardInsulation[wallTypeId] ?? 0)
            .clamp(0.0, math.max(0.0, thickness - .001));
  bool get hasInsulation => insulationThickness > 1e-4;
  bool get isLoadBearing =>
      layers.isEmpty && wallTypeId == 'bearing_25_concrete'
      ? true
      : loadBearing;
  bool get isInterior => !isExterior;
  bool get isExterior => location == null
      ? !{'int_12_partition', 'bearing_25_concrete'}.contains(wallTypeId) &&
            (hasInsulation ||
                {
                  'ext_25_brick',
                  'ext_25_12_eps',
                  'parapet_12',
                }.contains(wallTypeId))
      : location == ArchitectWallLocation.exterior;
  List<ArchitectMaterialLayer> get resolvedLayers => layers.isNotEmpty
      ? layers
      : [
          if (insulationThickness > 0)
            ArchitectMaterialLayer(
              id: 'insulation',
              material: switch (insulationMaterial) {
                WallInsulationMaterial.eps => ArchitectMaterial.eps,
                WallInsulationMaterial.xps => ArchitectMaterial.xps,
                _ => ArchitectMaterial.stoneWool,
              },
              role: ArchitectLayerRole.insulation,
              thickness: insulationThickness,
            ),
          ArchitectMaterialLayer(
            id: 'core',
            material: ArchitectMaterial.values.byName(coreMaterial.name),
            role: ArchitectLayerRole.core,
            thickness: thickness - insulationThickness,
          ),
        ];
  double get exteriorBuildUp {
    if (layers.isEmpty) return insulationThickness;
    return layers
        .takeWhile((l) => l.role != ArchitectLayerRole.core)
        .fold(0, (v, l) => v + l.thickness);
  }

  double get interiorBuildUp {
    if (layers.isEmpty) return 0;
    return layers.reversed
        .takeWhile((l) => l.role != ArchitectLayerRole.core)
        .fold(0, (v, l) => v + l.thickness);
  }

  double get coreAsymmetry => exteriorBuildUp - interiorBuildUp;
  double get coreThickness => layers.isEmpty
      ? thickness - insulationThickness
      : layers
            .where((l) => l.role == ArchitectLayerRole.core)
            .fold(0.0, (v, l) => v + l.thickness);
  double get exteriorSign => exteriorSide == WallExteriorSide.left ? 1 : -1;
  Offset get exteriorNormal => normalVector * exteriorSign;
  Offset get coreCenterStart =>
      centerStart - normalAt(0) * exteriorSign * coreAsymmetry / 2;
  Offset get coreCenterEnd =>
      centerEnd - normalAt(1) * exteriorSign * coreAsymmetry / 2;

  Offset get unitVector {
    final len = (endPoint - startPoint).distance;
    if (len < 1e-4) return const Offset(1, 0);
    return (endPoint - startPoint) / len;
  }

  Offset get normalVector {
    final u = unitVector;
    return Offset(-u.dy, u.dx);
  }

  Offset get centerOffset =>
      normalVector *
      switch (referenceLine) {
        WallReferenceLine.center => exteriorSign * coreAsymmetry / 2,
        WallReferenceLine.inner => exteriorSign * thickness / 2,
        WallReferenceLine.outer => -exteriorSign * thickness / 2,
        WallReferenceLine.left => -thickness / 2,
        WallReferenceLine.right => thickness / 2,
      };
  Offset get centerStart => startPoint + normalAt(0) * centerLineOffset;
  Offset get centerEnd => endPoint + normalAt(1) * centerLineOffset;

  /// 4 corner points of the 2D wall polygon.
  List<Offset> get polygonCorners {
    return facePolygon(
      centerLineOffset - thickness / 2,
      centerLineOffset + thickness / 2,
    );
  }

  ArchitectWall copyWith({
    String? id,
    double? arcBulge,
    List<ArchitectMaterialLayer>? layers,
    ArchitectWallLocation? location,
    bool? loadBearing,
    ArchitectWallPlinth? plinth,
    Offset? startPoint,
    Offset? endPoint,
    double? thickness,
    double? height,
    double? baseOffset,
    bool? followStoreyHeight,
    WallCoreMaterial? coreMaterial,
    WallInsulationMaterial? insulationMaterial,
    WallReferenceLine? referenceLine,
    WallExteriorSide? exteriorSide,
    double? insulationThicknessOverride,
    bool? connectStart,
    bool? connectEnd,
    String? wallTypeId,
    ParapetFinish? parapetFinish,
    ArchitectCutDisplayMode? cutDisplayMode,
    List<ArchitectDoor>? doors,
    List<ArchitectWindow>? windows,
  }) => ArchitectWall(
    id: id ?? this.id,
    arcBulge: arcBulge ?? this.arcBulge,
    layers: layers ?? this.layers,
    location: location ?? this.location,
    loadBearing: loadBearing ?? this.loadBearing,
    plinth: plinth ?? this.plinth,
    startPoint: startPoint ?? this.startPoint,
    endPoint: endPoint ?? this.endPoint,
    thickness: thickness ?? this.thickness,
    height: height ?? this.height,
    baseOffset: baseOffset ?? this.baseOffset,
    followStoreyHeight: followStoreyHeight ?? this.followStoreyHeight,
    coreMaterialOverride: coreMaterial ?? coreMaterialOverride,
    insulationMaterial: insulationMaterial ?? this.insulationMaterial,
    referenceLine: referenceLine ?? this.referenceLine,
    exteriorSide: exteriorSide ?? this.exteriorSide,
    insulationThicknessOverride:
        insulationThicknessOverride ?? this.insulationThicknessOverride,
    connectStart: connectStart ?? this.connectStart,
    connectEnd: connectEnd ?? this.connectEnd,
    wallTypeId: wallTypeId ?? this.wallTypeId,
    parapetFinish: parapetFinish ?? this.parapetFinish,
    cutDisplayMode: cutDisplayMode ?? this.cutDisplayMode,
    doors: doors ?? this.doors,
    windows: windows ?? this.windows,
  );

  bool get isDetached => !connectStart && !connectEnd;

  bool connectsAt(Offset point) {
    if (isDetached) return false;
    if (isCurved) {
      final r = arc!.parameter(point);
      return (r.abs() > 1e-7 || connectStart) &&
          ((r - 1).abs() > 1e-7 || connectEnd);
    }
    final delta = point - startPoint;
    final along = delta.dx * unitVector.dx + delta.dy * unitVector.dy;
    return (along.abs() >= 1e-8 || connectStart) &&
        ((along - length).abs() >= 1e-8 || connectEnd);
  }

  List<Offset> get coreCorners {
    final offset = centerLineOffset - exteriorSign * coreAsymmetry / 2;
    return facePolygon(offset - coreThickness / 2, offset + coreThickness / 2);
  }

  /// Change the material side without moving the masonry/concrete core.
  ArchitectWall mirroredAroundCore() {
    final flipped = copyWith(
      exteriorSide: exteriorSide == WallExteriorSide.left
          ? WallExteriorSide.right
          : WallExteriorSide.left,
    );
    if (isCurved) {
      final shift =
          centerLineOffset -
          exteriorSign * coreAsymmetry / 2 -
          (flipped.centerLineOffset - flipped.exteriorSign * coreAsymmetry / 2);
      return flipped.copyWith(
        startPoint: arc!.pointAt(0, leftOffset: shift),
        endPoint: arc!.pointAt(1, leftOffset: shift),
      );
    }
    final shift = coreCenterStart - flipped.coreCenterStart;
    return flipped.copyWith(
      startPoint: flipped.startPoint + shift,
      endPoint: flipped.endPoint + shift,
    );
  }

  ArchitectWall addDoor(ArchitectDoor door) {
    return copyWith(doors: [...doors, door]);
  }

  ArchitectWall removeDoor(String doorId) {
    return copyWith(doors: doors.where((d) => d.id != doorId).toList());
  }

  ArchitectWall addWindow(ArchitectWindow window) {
    return copyWith(windows: [...windows, window]);
  }

  ArchitectWall removeWindow(String windowId) {
    return copyWith(windows: windows.where((w) => w.id != windowId).toList());
  }

  /// Projects a click [point] onto the baseline, returning normalized ratio [0..1] and distance.
  (double ratio, double dist) projectPoint(Offset point) {
    if (isCurved) {
      final ratio = arc!.parameter(point);
      return (ratio, (point - centerPointAt(ratio.clamp(0, 1))).distance);
    }
    final len = length;
    if (len < 1e-4) return (0.0, (point - startPoint).distance);
    final ratio = BimLineGeometry.parameter(point, centerStart, centerEnd);
    final dist =
        (point - BimLineGeometry.closest(point, centerStart, centerEnd))
            .distance;
    return (ratio, dist);
  }

  /// Tests if a screen/model point lies within the wall body.
  bool containsPoint(Offset point, {double tolerance = 0.10}) {
    final (ratio, dist) = projectPoint(point);
    return dist <= (thickness / 2.0 + tolerance) &&
        ratio >= 0.0 &&
        ratio <= 1.0;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (isCurved) 'arcBulge': arcBulge,
    'layers': layers.map((l) => l.toJson()).toList(),
    if (location != null) 'location': location!.name,
    'loadBearing': loadBearing,
    'plinth': plinth.toJson(),
    'startPoint': {'x': startPoint.dx, 'y': startPoint.dy},
    'endPoint': {'x': endPoint.dx, 'y': endPoint.dy},
    'thickness': thickness,
    'height': height,
    'baseOffset': baseOffset,
    'followStoreyHeight': followStoreyHeight && !isParapet,
    'coreMaterial': coreMaterial.name,
    'insulationMaterial': insulationMaterial.name,
    'referenceLine': referenceLine.name,
    'exteriorSide': exteriorSide.name,
    'insulationThicknessOverride': insulationThicknessOverride,
    'connectStart': connectStart,
    'connectEnd': connectEnd,
    'wallTypeId': wallTypeId,
    'parapetFinish': parapetFinish?.name,
    'cutDisplayMode': cutDisplayMode.name,
    'doors': doors.map((d) => d.toJson()).toList(),
    'windows': windows.map((w) => w.toJson()).toList(),
  };

  factory ArchitectWall.fromJson(Map<String, dynamic> json) => ArchitectWall(
    id: json['id'] as String,
    arcBulge: (json['arcBulge'] as num?)?.toDouble() ?? 0,
    layers: (json['layers'] as List? ?? [])
        .map(
          (l) => ArchitectMaterialLayer.fromJson(
            Map<String, dynamic>.from(l as Map),
          ),
        )
        .toList(),
    location: ArchitectWallLocation.values
        .where((v) => v.name == json['location'])
        .firstOrNull,
    loadBearing: json['loadBearing'] as bool? ?? false,
    plinth: ArchitectWallPlinth.fromJson(
      Map<String, dynamic>.from(json['plinth'] as Map? ?? {}),
    ),
    startPoint: Offset(
      (json['startPoint']['x'] as num).toDouble(),
      (json['startPoint']['y'] as num).toDouble(),
    ),
    endPoint: Offset(
      (json['endPoint']['x'] as num).toDouble(),
      (json['endPoint']['y'] as num).toDouble(),
    ),
    thickness: (json['thickness'] as num?)?.toDouble() ?? 0.25,
    height: (json['height'] as num?)?.toDouble() ?? 2.80,
    baseOffset: (json['baseOffset'] as num?)?.toDouble() ?? 0.0,
    followStoreyHeight: json['followStoreyHeight'] as bool? ?? false,
    coreMaterialOverride: WallCoreMaterial.values
        .where((m) => m.name == json['coreMaterial'])
        .firstOrNull,
    insulationMaterial:
        WallInsulationMaterial.values
            .where((m) => m.name == json['insulationMaterial'])
            .firstOrNull ??
        WallInsulationMaterial.eps,
    referenceLine: WallReferenceLine.values.firstWhere(
      (value) => value.name == json['referenceLine'],
      orElse: () => WallReferenceLine.center,
    ),
    exteriorSide: WallExteriorSide.values.firstWhere(
      (value) => value.name == json['exteriorSide'],
      orElse: () => WallExteriorSide.left,
    ),
    insulationThicknessOverride: (json['insulationThicknessOverride'] as num?)
        ?.toDouble(),
    connectStart: json['connectStart'] as bool? ?? true,
    connectEnd: json['connectEnd'] as bool? ?? true,
    wallTypeId: json['wallTypeId'] as String?,
    parapetFinish: json['parapetFinish'] != null
        ? ParapetFinish.values.firstWhere(
            (p) => p.name == json['parapetFinish'],
            orElse: () => ParapetFinish.cap,
          )
        : null,
    cutDisplayMode: ArchitectCutDisplayMode.fromName(
      json['cutDisplayMode'] as String?,
    ),
    doors:
        (json['doors'] as List<dynamic>?)
            ?.map((d) => ArchitectDoor.fromJson(d as Map<String, dynamic>))
            .toList() ??
        const [],
    windows:
        (json['windows'] as List<dynamic>?)
            ?.map((w) => ArchitectWindow.fromJson(w as Map<String, dynamic>))
            .toList() ??
        const [],
  );

  Path openingCutoutAt(
    double heightAboveBase, {
    Set<String> suppressedOpeningIds = const {},
  }) {
    final path = Path();
    for (final op in [
      ...doors
          .where((o) => !suppressedOpeningIds.contains(o.id))
          .map((o) => (o.offsetRatio, o.width, o.sillHeight, o.height)),
      ...windows
          .where((o) => !suppressedOpeningIds.contains(o.id))
          .map((o) => (o.offsetRatio, o.width, o.sillHeight, o.height)),
    ]) {
      if (heightAboveBase <= op.$3 || heightAboveBase >= op.$3 + op.$4) {
        continue;
      }
      final center = centerPointAt(op.$1),
          u = tangentAt(op.$1),
          normal = normalAt(op.$1);
      final depth =
          thickness / 2 +
          (isCurved ? op.$2 * op.$2 / (4 * arc!.radius) : 0) +
          .001;
      final a = center - u * (op.$2 / 2),
          b = center + u * (op.$2 / 2),
          n = normal * depth;
      path.addPolygon([a - n, b - n, b + n, a + n], true);
    }
    return path;
  }

  /// Physical material slices, ordered outside to inside and split at the plinth.
  List<ArchitectWallMaterialSlice> materialSlices(
    double storeyElevation, {
    Set<String> suppressedOpeningIds = const {},
  }) {
    final result = <ArchitectWallMaterialSlice>[];
    final composition = resolvedLayers;
    final firstCore = composition.indexWhere(
      (l) => l.role == ArchitectLayerRole.core,
    );
    final z0 = storeyElevation + baseOffset, z1 = z0 + height;
    var cursor = 0.0;
    for (var index = 0; index < composition.length; index++) {
      final layer = composition[index];
      final shift =
          exteriorNormal * (thickness / 2 - cursor - layer.thickness / 2);
      final faceOffset =
          centerLineOffset +
          exteriorSign * (thickness / 2 - cursor - layer.thickness / 2);
      final from =
              arc?.pointAt(0, leftOffset: faceOffset) ?? centerStart + shift,
          to = arc?.pointAt(1, leftOffset: faceOffset) ?? centerEnd + shift;
      final band = plinth.enabled && isExterior && index < firstCore;
      final breaks = <double>[z0, z1];
      if (band) {
        for (final z in [
          plinth.baseElevation,
          plinth.baseElevation + plinth.height,
        ]) {
          if (z > z0 && z < z1) breaks.add(z);
        }
      }
      breaks.sort();
      for (var j = 0; j + 1 < breaks.length; j++) {
        final bottom = breaks[j], top = breaks[j + 1], mid = (bottom + top) / 2;
        final inPlinth =
            band &&
            mid >= plinth.baseElevation &&
            mid < plinth.baseElevation + plinth.height;
        final material = inPlinth
            ? layer.role == ArchitectLayerRole.insulation
                  ? ArchitectMaterial.xps
                  : plinth.finish
            : layer.material;
        final segment = copyWith(
          layers: const [],
          thickness: layer.thickness,
          insulationThicknessOverride: 0,
          startPoint: from,
          endPoint: to,
          referenceLine: WallReferenceLine.center,
          baseOffset: bottom - storeyElevation,
          height: top - bottom,
          followStoreyHeight: false,
          plinth: const ArchitectWallPlinth(),
          doors: [
            for (final d in doors)
              if (!suppressedOpeningIds.contains(d.id))
                d.copyWith(sillHeight: d.sillHeight + z0 - bottom),
          ],
          windows: [
            for (final w in windows)
              if (!suppressedOpeningIds.contains(w.id))
                w.copyWith(sillHeight: w.sillHeight + z0 - bottom),
          ],
        );
        result.add(
          ArchitectWallMaterialSlice(
            segment,
            material,
            layer.id,
            surfaceFinish:
                inPlinth &&
                    index == 0 &&
                    layer.role == ArchitectLayerRole.insulation
                ? plinth.finish
                : null,
          ),
        );
      }
      cursor += layer.thickness;
    }
    return result;
  }

  // ===========================================================================
  // 3D SOLID WALL EXTRUSION WITH BOOLEAN CUTOUTS
  // ===========================================================================

  /// Builds solid 3D mesh triangles for the wall, splitting it around hosted doors and windows.
  List<Triangle3D> build3D({
    required double storeyElevation,
    Map<Triangle3D, String>? sources,
    bool resolveComposition = true,
    bool includeSolid = true,
    bool includeOpeningMeshes = true,
    Color? solidColor,
    Set<String> suppressedOpeningIds = const {},
    Map<String, FenestrationElevationDetail> openingDetailLevels = const {},
  }) {
    if (resolveComposition && (layers.isNotEmpty || plinth.enabled)) {
      return [
        if (includeSolid)
          for (final part in materialSlices(
            storeyElevation,
            suppressedOpeningIds: suppressedOpeningIds,
          ))
            ...part.build3D(storeyElevation),
        if (includeOpeningMeshes)
          ...build3D(
            storeyElevation: storeyElevation,
            sources: sources,


            resolveComposition: false,
            includeSolid: false,
            suppressedOpeningIds: suppressedOpeningIds,
            openingDetailLevels: openingDetailLevels,
          ),
      ];
    }
    if (isCurved && includeSolid) {
      final bottom = storeyElevation + baseOffset, top = bottom + height;
      final breaks = <double>{bottom, top};
      for (final op in [
        ...doors.map((o) => (o.sillHeight, o.height)),
        ...windows.map((o) => (o.sillHeight, o.height)),
      ]) {
        for (final z in [bottom + op.$1, bottom + op.$1 + op.$2]) {
          if (z > bottom && z < top) breaks.add(z);
        }
      }
      final levels = breaks.toList()..sort();
      return [
        for (var i = 0; i + 1 < levels.length; i++)
          ...ArchitectPathSolid.extrude(
            Path.combine(
              PathOperation.difference,
              Path()..addPolygon(polygonCorners, true),
              openingCutoutAt(
                (levels[i] + levels[i + 1]) / 2 - bottom,
                suppressedOpeningIds: suppressedOpeningIds,
              ),
            ),
            levels[i],
            levels[i + 1],
            solidColor ?? const Color(0xFFECEFF1),
          ),
        if (includeOpeningMeshes)
          ...build3D(
            storeyElevation: storeyElevation,
            sources: sources,


            resolveComposition: false,
            includeSolid: false,
            suppressedOpeningIds: suppressedOpeningIds,
            openingDetailLevels: openingDetailLevels,
          ),
      ];
    }
    final List<Triangle3D> tris = [];
    final len = length;
    if (len < 1e-4) return tris;

    final u = unitVector;
    final n = normalVector;
    final halfThick = thickness / 2.0;

    final wallColor = solidColor ?? const Color(0xFFECEFF1);
    final zBottom = storeyElevation + baseOffset;
    final zTop = zBottom + height;

    // Extrude a solid rectangular prism segment between two offsets along the baseline
    void addWallPrism(
      double startAlong,
      double endAlong,
      double zMin,
      double zMax,
    ) {
      if (!includeSolid) return;
      zMin = math.max(zMin, zBottom);
      zMax = math.min(zMax, zTop);
      if (endAlong <= startAlong + 1e-4 || zMax <= zMin + 1e-4) return;
      final a = centerStart + u * startAlong;
      final b = centerStart + u * endAlong;

      final p1 = a - n * halfThick;
      final p2 = b - n * halfThick;
      final p3 = b + n * halfThick;
      final p4 = a + n * halfThick;

      final v1B = Vector3(p1.dx, p1.dy, zMin);
      final v2B = Vector3(p2.dx, p2.dy, zMin);
      final v3B = Vector3(p3.dx, p3.dy, zMin);
      final v4B = Vector3(p4.dx, p4.dy, zMin);

      final v1T = Vector3(p1.dx, p1.dy, zMax);
      final v2T = Vector3(p2.dx, p2.dy, zMax);
      final v3T = Vector3(p3.dx, p3.dy, zMax);
      final v4T = Vector3(p4.dx, p4.dy, zMax);

      // 4 Vertical sides
      tris.add(Triangle3D(v0: v1B, v1: v2B, v2: v2T, color: wallColor));
      tris.add(Triangle3D(v0: v1B, v1: v2T, v2: v1T, color: wallColor));

      tris.add(Triangle3D(v0: v2B, v1: v3B, v2: v3T, color: wallColor));
      tris.add(Triangle3D(v0: v2B, v1: v3T, v2: v2T, color: wallColor));

      tris.add(Triangle3D(v0: v3B, v1: v4B, v2: v4T, color: wallColor));
      tris.add(Triangle3D(v0: v3B, v1: v4T, v2: v3T, color: wallColor));

      tris.add(Triangle3D(v0: v4B, v1: v1B, v2: v1T, color: wallColor));
      tris.add(Triangle3D(v0: v4B, v1: v1T, v2: v4T, color: wallColor));

      // Top & Bottom caps
      tris.add(Triangle3D(v0: v1T, v1: v2T, v2: v3T, color: wallColor));
      tris.add(Triangle3D(v0: v1T, v1: v3T, v2: v4T, color: wallColor));
      tris.add(Triangle3D(v0: v1B, v1: v3B, v2: v2B, color: wallColor));
      tris.add(Triangle3D(v0: v1B, v1: v4B, v2: v3B, color: wallColor));
    }

    if (doors.isEmpty && windows.isEmpty) {
      // Solid wall without any cutouts
      addWallPrism(0.0, len, zBottom, zTop);
      return tris;
    }

    // Unified list of hosted openings (doors + windows)
    final openings =
        <
          ({
            String id,
            double offsetRatio,
            double width,
            double height,
            double sillHeight,
            List<Triangle3D> Function() build3DTris,
          })
        >[];

    for (final d in doors) {
      if (suppressedOpeningIds.contains(d.id)) continue;
      openings.add((
        id: d.id,
        offsetRatio: d.offsetRatio,
        width: d.width,
        height: d.height,
        sillHeight: d.sillHeight,
        build3DTris: () => d.build3D(
          wallStart: openingAxis(d.offsetRatio).$1,
          wallEnd: openingAxis(d.offsetRatio).$2,
          detailLevel:
              openingDetailLevels[d.id] ?? FenestrationElevationDetail.full3D,
          wallThickness: thickness,
          storeyElevation: storeyElevation + baseOffset,
          coreThickness: coreThickness,
          coreCenterShift: -exteriorSign * coreAsymmetry / 2,
          insulationThickness: insulationThickness,
          exteriorSign: exteriorSign.toDouble(),
        ),
      ));
    }

    for (final w in windows) {
      if (suppressedOpeningIds.contains(w.id)) continue;
      openings.add((
        id: w.id,
        offsetRatio: w.offsetRatio,
        width: w.width,
        height: w.height,
        sillHeight: w.sillHeight,
        build3DTris: () => w.build3D(
          wallStart: openingAxis(w.offsetRatio).$1,
          wallEnd: openingAxis(w.offsetRatio).$2,
          detailLevel:
              openingDetailLevels[w.id] ?? FenestrationElevationDetail.full3D,
          wallThickness: thickness,
          storeyElevation: storeyElevation + baseOffset,
          coreThickness: coreThickness,
          coreCenterShift: -exteriorSign * coreAsymmetry / 2,
          insulationThickness: insulationThickness,
          exteriorSign: exteriorSign.toDouble(),
        ),
      ));
    }

    openings.sort((a, b) => a.offsetRatio.compareTo(b.offsetRatio));

    double currentX = 0.0;
    for (final op in openings) {
      final center = op.offsetRatio * len;
      final opStart = math.max(0.0, center - op.width / 2.0);
      final opEnd = math.min(len, center + op.width / 2.0);

      // 1. Left pier before opening
      if (opStart > currentX) {
        addWallPrism(currentX, opStart, zBottom, zTop);
      }

      // 2. Sill section below opening
      if (op.sillHeight > 0) {
        addWallPrism(opStart, opEnd, zBottom, zBottom + op.sillHeight);
      }

      // 3. Lintel section above opening
      final headZ = zBottom + op.sillHeight + op.height;
      if (headZ < zTop) {
        addWallPrism(opStart, opEnd, headZ, zTop);
      }

      // 4. Opening mesh elements
      final openingMesh = includeOpeningMeshes
          ? op.build3DTris()
          : <Triangle3D>[];
      tris.addAll(openingMesh);
      if (sources != null) {
        for (final t in openingMesh) {
          sources[t] = op.id;
        }
      }

      currentX = math.max(currentX, opEnd);
    }

    // 5. Right pier after last opening
    if (currentX < len) {
      addWallPrism(currentX, len, zBottom, zTop);
    }

    return tris;
  }
}

class ArchitectWallMaterialSlice {
  final ArchitectWall wall;
  final ArchitectMaterial material;
  final String layerId;
  final ArchitectMaterial? surfaceFinish;
  const ArchitectWallMaterialSlice(
    this.wall,
    this.material,
    this.layerId, {
    this.surfaceFinish,
  });
  List<Triangle3D> build3D(double elevation) {
    final triangles = wall.build3D(
      storeyElevation: elevation,
      resolveComposition: false,
      includeOpeningMeshes: false,
      solidColor: material.color,
    );
    if (surfaceFinish == null) return triangles;
    final n = wall.exteriorNormal,
        face = wall.centerStart + n * wall.thickness / 2;
    bool outside(Vector3 v) =>
        ((Offset(v.x, v.y) - face).dx * n.dx +
                (Offset(v.x, v.y) - face).dy * n.dy)
            .abs() <
        1e-8;
    return [
      for (final t in triangles)
        if (outside(t.v0) && outside(t.v1) && outside(t.v2))
          Triangle3D(
            v0: t.v0,
            v1: t.v1,
            v2: t.v2,
            color: surfaceFinish!.color,
            isDoubleSided: t.isDoubleSided,
          )
        else
          t,
    ];
  }
}
