// === SECTION: SANITARY PARAMETRIC COMPONENT DEFINITIONS ===
// Table of Contents:
// 1. WALL-HUNG TOILET (SanitaryToiletWallHung)
// 2. FLOOR-STANDING TOILET (SanitaryToiletFloorStanding)
// 3. WASHBASIN & VANITY (SanitaryWashbasinCabinet)
// 4. BATHTUB (SanitaryBathtub)
// 5. SHOWER TRAY & ENCLOSURE (SanitaryShower)
// 6. LINEAR FLOOR DRAIN (SanitaryLinearDrain)
// 7. FLOOR DRAIN (SanitaryFloorDrain)

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/architect_component.dart';
import '../../models/architect_component_definition.dart';

// ===========================================================================
// 1. WALL-HUNG TOILET (SanitaryToiletWallHung)
// ===========================================================================

class SanitaryToiletWallHung extends ArchitectComponentDefinition {
  @override
  String get id => 'sanitary_toilet_wall_hung';

  @override
  String get defaultName => 'Wall-hung Toilet';

  @override
  ArchitectComponentCategory get category => ArchitectComponentCategory.sanitary;

  @override
  ComponentPlacementMode get placementMode => ComponentPlacementMode.wallAttached;

  @override
  List<ParametricFieldSchema> get schema => const [
    ParametricFieldSchema(
      key: 'width',
      label: 'Width',
      defaultValue: 0.36,
      min: 0.30,
      max: 0.45,
      step: 0.01,
    ),
    ParametricFieldSchema(
      key: 'depth',
      label: 'Depth',
      defaultValue: 0.54,
      min: 0.46,
      max: 0.62,
      step: 0.01,
    ),
    ParametricFieldSchema(
      key: 'height',
      label: 'Height',
      defaultValue: 0.40,
      min: 0.32,
      max: 0.48,
      step: 0.01,
    ),
  ];

  @override
  CachedComponentGeometry generateGeometry(Map<String, dynamic> params) {
    final w = (params['width'] as num?)?.toDouble() ?? .36;
    final d = (params['depth'] as num?)?.toDouble() ?? .54;
    final h = (params['height'] as num?)?.toDouble() ?? .40;
    final builder = ParametricSolidBuilder(width: w, depth: d, height: h);
    builder.addBasin(
      center: Offset(0, d / 2),
      basinWidth: w,
      basinDepth: d,
      basinHeight: h,
      wall: w * .09,
      base: h * .50,
      roundedBody: true,
    );
    builder.add2DDetailPath(
      Path()..addOval(
        Rect.fromCenter(
          center: Offset(0, d / 2),
          width: w * .82,
          height: d - w * .18,
        ),
      ),
    );
    return builder.build(defaultName);
  }
}

// ===========================================================================
// 2. FLOOR-STANDING TOILET (SanitaryToiletFloorStanding)
// ===========================================================================

class SanitaryToiletFloorStanding extends ArchitectComponentDefinition {
  @override
  String get id => 'sanitary_toilet_floor_standing';

  @override
  String get defaultName => 'Floor-standing Toilet';

  @override
  ArchitectComponentCategory get category => ArchitectComponentCategory.sanitary;

  @override
  ComponentPlacementMode get placementMode => ComponentPlacementMode.wallAttached;

  @override
  List<ParametricFieldSchema> get schema => const [
    ParametricFieldSchema(
      key: 'width',
      label: 'Width',
      defaultValue: 0.38,
      min: 0.34,
      max: 0.45,
      step: 0.01,
    ),
    ParametricFieldSchema(
      key: 'depth',
      label: 'Depth',
      defaultValue: 0.68,
      min: 0.60,
      max: 0.75,
      step: 0.01,
    ),
    ParametricFieldSchema(
      key: 'height',
      label: 'Height',
      defaultValue: 0.80,
      min: 0.70,
      max: 0.88,
      step: 0.01,
    ),
  ];

  @override
  CachedComponentGeometry generateGeometry(Map<String, dynamic> params) {
    final w = (params['width'] as num?)?.toDouble() ?? .38;
    final d = (params['depth'] as num?)?.toDouble() ?? .68;
    final h = (params['height'] as num?)?.toDouble() ?? .80;
    final builder = ParametricSolidBuilder(width: w, depth: d, height: h);
    final cisternDepth = d * .25;
    builder.addBox(
      boxWidth: w,
      boxDepth: cisternDepth,
      boxHeight: h,
      color: const Color(0xFFFAFAFA),
    );
    final bowlDepth = d - cisternDepth;
    builder.addBasin(
      center: Offset(0, cisternDepth + bowlDepth / 2),
      basinWidth: w,
      basinDepth: bowlDepth,
      basinHeight: h * .52,
      wall: w * .09,
      base: h * .26,
      roundedBody: true,
    );
    builder.add2DDetailPath(
      Path()..addOval(
        Rect.fromCenter(
          center: Offset(0, cisternDepth * .5),
          width: w * .15,
          height: cisternDepth * .2,
        ),
      ),
    );
    return builder.build(defaultName);
  }
}

// ===========================================================================
// 3. WASHBASIN & VANITY (SanitaryWashbasinCabinet)
// ===========================================================================

class SanitaryWashbasinCabinet extends ArchitectComponentDefinition {
  final bool legacyDimensions;
  SanitaryWashbasinCabinet({this.legacyDimensions = false});
  @override
  String get id =>
      legacyDimensions ? 'sanitary_washbasin_cabinet' : 'sanitary_vanity';

  @override
  String get defaultName => 'Washbasin Vanity';

  @override
  ArchitectComponentCategory get category => ArchitectComponentCategory.sanitary;

  @override
  ComponentPlacementMode get placementMode => ComponentPlacementMode.wallAttached;

  @override
  List<ParametricFieldSchema> get schema => [
    ParametricFieldSchema(
      key: 'width',
      label: 'Width',
      defaultValue: 0.80,
      min: 0.50,
      max: 1.50,
      step: 0.05,
    ),
    ParametricFieldSchema(
      key: 'depth',
      label: 'Depth',
      defaultValue: 0.48,
      min: 0.38,
      max: 0.60,
      step: 0.02,
    ),
    ParametricFieldSchema(
      key: 'height',
      label: 'Height',
      defaultValue: legacyDimensions ? .85 : 1.01,
      min: 0.91,
      max: 1.08,
      step: 0.01,
    ),
  ];

  @override
  CachedComponentGeometry generateGeometry(Map<String, dynamic> params) {
    final w = (params['width'] as num?)?.toDouble() ?? .80;
    final d = (params['depth'] as num?)?.toDouble() ?? .48;
    final requestedH =
        (params['height'] as num?)?.toDouble() ??
        (legacyDimensions ? .85 : 1.01);
    final h = legacyDimensions ? requestedH + .16 : requestedH;
    final builder = ParametricSolidBuilder(width: w, depth: d, height: h);
    final tapHeight = h * (.16 / 1.01);
    final basinHeight = h * (.14 / 1.01);
    final cabinetHeight = h - tapHeight - basinHeight;
    builder.addBox(
      boxWidth: w,
      boxDepth: d,
      boxHeight: cabinetHeight,
      color: const Color(0xFFBCAAA4),
    );
    builder.addBasin(
      center: Offset(0, d / 2),
      basinWidth: w,
      basinDepth: d,
      basinHeight: basinHeight,
      zBottom: cabinetHeight,
      wall: math.min(w, d) * .16,
      base: basinHeight * .2,
      rectangular: true,
    );
    builder.addCylinder(
      center: Offset(0, d * .06),
      radius: w * .025,
      cylinderHeight: tapHeight,
      zBottom: h - tapHeight,
      color: const Color(0xFFB0BEC5),
    );
    builder.add2DDetailPath(
      Path()..addOval(Rect.fromCircle(center: Offset(0, d / 2), radius: .025)),
    );
    return builder.build(defaultName);
  }
}

// ===========================================================================
// 4. BATHTUB (SanitaryBathtub)
// ===========================================================================

class SanitaryBathtub extends ArchitectComponentDefinition {
  @override
  String get id => 'sanitary_bathtub';

  @override
  String get defaultName => 'Bathtub';

  @override
  ArchitectComponentCategory get category => ArchitectComponentCategory.sanitary;

  @override
  ComponentPlacementMode get placementMode => ComponentPlacementMode.wallAttached;

  @override
  List<ParametricFieldSchema> get schema => const [
    ParametricFieldSchema(
      key: 'width',
      label: 'Width',
      defaultValue: 0.75,
      min: 0.70,
      max: 0.90,
      step: 0.05,
    ),
    ParametricFieldSchema(
      key: 'depth',
      label: 'Length',
      defaultValue: 1.70,
      min: 1.40,
      max: 1.90,
      step: 0.05,
    ),
    ParametricFieldSchema(
      key: 'height',
      label: 'Height',
      defaultValue: 0.58,
      min: 0.48,
      max: 0.68,
      step: 0.02,
    ),
  ];

  @override
  CachedComponentGeometry generateGeometry(Map<String, dynamic> params) {
    final w = (params['width'] as num?)?.toDouble() ?? .75;
    final d = (params['depth'] as num?)?.toDouble() ?? 1.70;
    final h = (params['height'] as num?)?.toDouble() ?? .58;
    final builder = ParametricSolidBuilder(width: w, depth: d, height: h);
    builder.addBasin(
      center: Offset(0, d / 2),
      basinWidth: w,
      basinDepth: d,
      basinHeight: h,
      wall: math.min(w, d) * .10,
      base: h * .12,
      rectangular: true,
    );
    builder.add2DDetailPath(
      Path()..addOval(Rect.fromCircle(center: Offset(0, d * .75), radius: .03)),
    );
    return builder.build(defaultName);
  }
}

// ===========================================================================
// 5. SHOWER TRAY (SanitaryShower)
// ===========================================================================

class SanitaryShower extends ArchitectComponentDefinition {
  @override
  String get id => 'sanitary_shower';

  @override
  String get defaultName => 'Shower Enclosure';

  @override
  ArchitectComponentCategory get category => ArchitectComponentCategory.sanitary;

  @override
  ComponentPlacementMode get placementMode => ComponentPlacementMode.wallAttached;

  @override
  List<ParametricFieldSchema> get schema => const [
    ParametricFieldSchema(
      key: 'width',
      label: 'Width',
      defaultValue: 0.90,
      min: 0.80,
      max: 1.40,
      step: 0.05,
    ),
    ParametricFieldSchema(
      key: 'depth',
      label: 'Depth',
      defaultValue: 0.90,
      min: 0.80,
      max: 1.40,
      step: 0.05,
    ),
    ParametricFieldSchema(
      key: 'height',
      label: 'Height',
      defaultValue: 2.00,
      min: 1.80,
      max: 2.20,
      step: 0.05,
    ),
  ];

  @override
  CachedComponentGeometry generateGeometry(Map<String, dynamic> params) {
    final w = (params['width'] as num?)?.toDouble() ?? 0.90;
    final d = (params['depth'] as num?)?.toDouble() ?? 0.90;
    final h = (params['height'] as num?)?.toDouble() ?? 2.00;

    final builder = ParametricSolidBuilder(width: w, depth: d, height: h);
    final wHalf = w / 2.0;

    // 1. Shower tray (0.06 m high)
    builder.addBox(
      origin: Offset(-wHalf, 0.0),
      boxWidth: w,
      boxDepth: d,
      boxHeight: 0.06,
      color: const Color(0xFFFAFAFA),
    );

    // 2. Glass corner enclosure screen
    builder.addBox(
      origin: Offset(wHalf - 0.01, 0.0),
      boxWidth: 0.01,
      boxDepth: d,
      boxHeight: h - 0.06,
      zBottom: 0.06,
      color: const Color(0x66B0BEC5), // Translucent glass
    );
    builder.addBox(
      origin: Offset(-wHalf, d - 0.01),
      boxWidth: w,
      boxDepth: 0.01,
      boxHeight: h - 0.06,
      zBottom: 0.06,
      color: const Color(0x66B0BEC5),
    );

    // 2D CAD Plan Details
    // Center drain
    final drainX = 0.0;
    final drainY = d * 0.50;
    final drain = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(drainX, drainY),
          width: 0.08,
          height: 0.08,
        ),
      );
    builder.add2DDetailPath(drain);

    // Slope fall diagonal lines toward drain
    builder.add2DDetailLine(Offset(-wHalf, 0.0), Offset(drainX, drainY));
    builder.add2DDetailLine(Offset(wHalf, 0.0), Offset(drainX, drainY));
    builder.add2DDetailLine(Offset(wHalf, d), Offset(drainX, drainY));
    builder.add2DDetailLine(Offset(-wHalf, d), Offset(drainX, drainY));

    return builder.build(defaultName);
  }
}

// ===========================================================================
// 6. LINEAR FLOOR DRAIN (SanitaryLinearDrain)
// ===========================================================================

class SanitaryLinearDrain extends ArchitectComponentDefinition {
  @override
  String get id => 'sanitary_linear_drain';

  @override
  bool get defaultVisibleInSection => true;

  @override
  String get defaultName => 'Linear Shower Drain';

  @override
  ArchitectComponentCategory get category => ArchitectComponentCategory.sanitary;

  @override
  ComponentPlacementMode get placementMode => ComponentPlacementMode.freeStanding;

  @override
  List<ParametricFieldSchema> get schema => const [
    ParametricFieldSchema(
      key: 'width',
      label: 'Length',
      defaultValue: 0.80,
      min: 0.50,
      max: 1.50,
      step: 0.05,
    ),
    ParametricFieldSchema(
      key: 'depth',
      label: 'Width',
      defaultValue: 0.09,
      min: 0.06,
      max: 0.20,
      step: 0.01,
    ),
    ParametricFieldSchema(
      key: 'height',
      label: 'Depth',
      defaultValue: 0.06,
      min: 0.04,
      max: 0.12,
      step: 0.01,
    ),
  ];

  @override
  CachedComponentGeometry generateGeometry(Map<String, dynamic> params) {
    final w = (params['width'] as num?)?.toDouble() ?? 0.80;
    final d = (params['depth'] as num?)?.toDouble() ?? 0.09;
    final h = (params['height'] as num?)?.toDouble() ?? 0.06;

    final builder = ParametricSolidBuilder(width: w, depth: d, height: h);
    final wHalf = w / 2.0;

    // 1. Stainless steel outer flange frame
    const flange = 0.015;
    builder.addBox(
      origin: Offset(-wHalf, 0.0),
      boxWidth: w,
      boxDepth: d,
      boxHeight: h * 0.25,
      color: const Color(0xFFB0BEC5),
    );

    // 2. Linear drainage trough / channel basin
    builder.addBasin(
      center: Offset(0, d / 2),
      basinWidth: math.max(0.10, w - flange * 2),
      basinDepth: math.max(0.04, d - flange * 2),
      basinHeight: h * 0.70,
      zBottom: h * 0.25,
      wall: 0.008,
      base: 0.01,
      rectangular: true,
    );

    // 3. Central siphon discharge trap outlet underneath
    builder.addCylinder(
      center: Offset(0, d / 2),
      radius: math.min(0.025, (d - flange * 2) * 0.40),
      cylinderHeight: h * 0.60,
      zBottom: 0.0,
      color: const Color(0xFF78909C),
    );

    // 2D CAD Plan Details
    final outerRect = Rect.fromLTWH(-wHalf, 0, w, d);
    builder.add2DDetailPath(Path()..addRect(outerRect));

    final innerW = math.max(0.10, w - flange * 2);
    final innerD = math.max(0.03, d - flange * 2);
    final innerRect = Rect.fromCenter(
      center: Offset(0, d / 2),
      width: innerW,
      height: innerD,
    );
    builder.add2DDetailPath(Path()..addRect(innerRect));

    final slotSpacing = 0.04;
    final slotCount = (innerW / slotSpacing).floor();
    if (slotCount > 1) {
      final actualSpacing = innerW / (slotCount + 1);
      final startX = -innerW / 2.0;
      final slotTop = d / 2 - innerD * 0.38;
      final slotBottom = d / 2 + innerD * 0.38;
      for (var i = 1; i <= slotCount; i++) {
        final x = startX + i * actualSpacing;
        builder.add2DDetailLine(Offset(x, slotTop), Offset(x, slotBottom));
      }
    }

    final drainCircle = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(0, d / 2),
          width: math.min(0.04, innerD * 0.8),
          height: math.min(0.04, innerD * 0.8),
        ),
      );
    builder.add2DDetailPath(drainCircle);

    return builder.build(defaultName);
  }
}

// ===========================================================================
// 7. FLOOR DRAIN (SanitaryFloorDrain)
// ===========================================================================

class SanitaryFloorDrain extends ArchitectComponentDefinition {
  @override
  String get id => 'sanitary_floor_drain';

  @override
  bool get defaultVisibleInSection => true;

  @override
  String get defaultName => 'Floor Drain';

  @override
  ArchitectComponentCategory get category => ArchitectComponentCategory.sanitary;

  @override
  ComponentPlacementMode get placementMode => ComponentPlacementMode.freeStanding;

  @override
  List<ParametricFieldSchema> get schema => const [
    ParametricFieldSchema(
      key: 'width',
      label: 'Width',
      defaultValue: 0.15,
      min: 0.10,
      max: 0.30,
      step: 0.01,
    ),
    ParametricFieldSchema(
      key: 'depth',
      label: 'Depth',
      defaultValue: 0.15,
      min: 0.10,
      max: 0.30,
      step: 0.01,
    ),
    ParametricFieldSchema(
      key: 'height',
      label: 'Depth',
      defaultValue: 0.06,
      min: 0.04,
      max: 0.12,
      step: 0.01,
    ),
  ];

  @override
  CachedComponentGeometry generateGeometry(Map<String, dynamic> params) {
    final w = (params['width'] as num?)?.toDouble() ?? 0.15;
    final d = (params['depth'] as num?)?.toDouble() ?? 0.15;
    final h = (params['height'] as num?)?.toDouble() ?? 0.06;

    final builder = ParametricSolidBuilder(width: w, depth: d, height: h);
    final wHalf = w / 2.0;

    // 1. Stainless steel square bezel frame (15×15 cm)
    builder.addBox(
      origin: Offset(-wHalf, 0.0),
      boxWidth: w,
      boxDepth: d,
      boxHeight: h * 0.20,
      color: const Color(0xFFB0BEC5),
    );

    // 2. Inner round basin / drain sump
    final radius = math.min(w, d) * 0.40;
    builder.addBasin(
      center: Offset(0, d / 2),
      basinWidth: radius * 2,
      basinDepth: radius * 2,
      basinHeight: h * 0.75,
      zBottom: h * 0.20,
      wall: 0.006,
      base: 0.01,
      roundedBody: true,
    );

    // 3. Central siphon discharge pipe
    builder.addCylinder(
      center: Offset(0, d / 2),
      radius: radius * 0.45,
      cylinderHeight: h * 0.50,
      zBottom: 0.0,
      color: const Color(0xFF78909C),
    );

    // 2D CAD Plan Details
    final outerRect = Rect.fromLTWH(-wHalf, 0, w, d);
    builder.add2DDetailPath(Path()..addRect(outerRect));

    final grateRect = Rect.fromCenter(
      center: Offset(0, d / 2),
      width: radius * 2,
      height: radius * 2,
    );
    builder.add2DDetailPath(Path()..addOval(grateRect));

    final coreRect = Rect.fromCenter(
      center: Offset(0, d / 2),
      width: radius * 0.9,
      height: radius * 0.9,
    );
    builder.add2DDetailPath(Path()..addOval(coreRect));

    final center = Offset(0, d / 2);
    builder.add2DDetailLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
    );
    builder.add2DDetailLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
    );

    final diag = radius * 0.7071;
    builder.add2DDetailLine(
      Offset(center.dx - diag, center.dy - diag),
      Offset(center.dx + diag, center.dy + diag),
    );
    builder.add2DDetailLine(
      Offset(center.dx - diag, center.dy + diag),
      Offset(center.dx + diag, center.dy - diag),
    );

    return builder.build(defaultName);
  }
}

