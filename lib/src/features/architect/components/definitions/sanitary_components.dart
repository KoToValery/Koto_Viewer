// === SECTION: SANITARY PARAMETRIC COMPONENT DEFINITIONS ===
// Table of Contents:
// 1. WALL-HUNG TOILET (SanitaryToiletWallHung)
// 2. FLOOR-STANDING TOILET (SanitaryToiletFloorStanding)
// 3. WASHBASIN & VANITY (SanitaryWashbasinCabinet)
// 4. BATHTUB (SanitaryBathtub)
// 5. SHOWER TRAY & ENCLOSURE (SanitaryShower)

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
