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
    ParametricFieldSchema(key: 'width', label: 'Width', defaultValue: 0.36, min: 0.30, max: 0.45, step: 0.01),
    ParametricFieldSchema(key: 'depth', label: 'Depth', defaultValue: 0.54, min: 0.46, max: 0.62, step: 0.01),
    ParametricFieldSchema(key: 'height', label: 'Height', defaultValue: 0.40, min: 0.32, max: 0.48, step: 0.01),
  ];

  @override
  CachedComponentGeometry generateGeometry(Map<String, dynamic> params) {
    final w = (params['width'] as num?)?.toDouble() ?? 0.36;
    final d = (params['depth'] as num?)?.toDouble() ?? 0.54;
    final h = (params['height'] as num?)?.toDouble() ?? 0.40;

    final builder = ParametricSolidBuilder(width: w, depth: d, height: h);
    final wHalf = w / 2.0;
    final porcelain = const Color(0xFFFAFAFA);
    final seatColor = const Color(0xFFECEFF1);

    // 1. Concealed wall connector / rear block (depth ~ 0.14 m)
    final rearDepth = math.min(0.14, d * 0.28);
    builder.addBox(
      origin: Offset(-wHalf * 0.90, 0.0),
      boxWidth: w * 0.90,
      boxDepth: rearDepth,
      boxHeight: h,
      color: porcelain,
    );

    // 2. Main bowl body (front rounded cylinder/box)
    final bowlRadius = wHalf * 0.95;
    final bowlCenterY = rearDepth + (d - rearDepth) * 0.55;
    builder.addCylinder(
      center: Offset(0.0, bowlCenterY),
      radius: bowlRadius,
      cylinderHeight: h * 0.92,
      segments: 20,
      color: porcelain,
    );

    // 3. Toilet seat lid
    builder.addCylinder(
      center: Offset(0.0, bowlCenterY),
      radius: bowlRadius * 0.98,
      cylinderHeight: h * 0.08,
      zBottom: h * 0.92,
      segments: 20,
      color: seatColor,
    );

    // 2D CAD Plan Block Details
    // Rear rectangle
    final rearPath = Path()
      ..addRect(Rect.fromLTRB(-wHalf * 0.90, 0.0, wHalf * 0.90, rearDepth));
    builder.add2DDetailPath(rearPath);

    // Seat contour and inner opening
    final seatOval = Path()
      ..addOval(Rect.fromCenter(
        center: Offset(0.0, bowlCenterY),
        width: w * 0.95,
        height: (d - rearDepth) * 1.15,
      ));
    builder.add2DDetailPath(seatOval);

    final innerOval = Path()
      ..addOval(Rect.fromCenter(
        center: Offset(0.0, bowlCenterY + 0.02),
        width: w * 0.60,
        height: (d - rearDepth) * 0.75,
      ));
    builder.add2DDetailPath(innerOval);

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
    ParametricFieldSchema(key: 'width', label: 'Width', defaultValue: 0.38, min: 0.34, max: 0.45, step: 0.01),
    ParametricFieldSchema(key: 'depth', label: 'Depth', defaultValue: 0.68, min: 0.60, max: 0.75, step: 0.01),
    ParametricFieldSchema(key: 'height', label: 'Height', defaultValue: 0.80, min: 0.70, max: 0.88, step: 0.01),
  ];

  @override
  CachedComponentGeometry generateGeometry(Map<String, dynamic> params) {
    final w = (params['width'] as num?)?.toDouble() ?? 0.38;
    final d = (params['depth'] as num?)?.toDouble() ?? 0.68;
    final h = (params['height'] as num?)?.toDouble() ?? 0.80;

    final builder = ParametricSolidBuilder(width: w, depth: d, height: h);
    final wHalf = w / 2.0;
    final cisternDepth = 0.20;
    final cisternWidth = w * 0.95;
    final porcelain = const Color(0xFFFAFAFA);

    // 1. Water cistern at back
    builder.addBox(
      origin: Offset(-cisternWidth / 2.0, 0.0),
      boxWidth: cisternWidth,
      boxDepth: cisternDepth,
      boxHeight: h,
      color: porcelain,
    );

    // 2. Bowl base & bowl
    final bowlHeight = 0.42;
    final bowlRadius = wHalf * 0.90;
    final bowlCenterY = cisternDepth + (d - cisternDepth) * 0.52;
    builder.addCylinder(
      center: Offset(0.0, bowlCenterY),
      radius: bowlRadius,
      cylinderHeight: bowlHeight,
      segments: 20,
      color: porcelain,
    );

    // 2D CAD Plan Block
    final cisternPath = Path()
      ..addRect(Rect.fromLTRB(-cisternWidth / 2.0, 0.0, cisternWidth / 2.0, cisternDepth));
    builder.add2DDetailPath(cisternPath);

    // Flush button detail
    final buttonPath = Path()
      ..addOval(Rect.fromCenter(
        center: Offset(0.0, cisternDepth * 0.5),
        width: 0.06,
        height: 0.04,
      ));
    builder.add2DDetailPath(buttonPath);

    // Bowl oval
    final bowlOval = Path()
      ..addOval(Rect.fromCenter(
        center: Offset(0.0, bowlCenterY),
        width: w * 0.90,
        height: (d - cisternDepth) * 1.05,
      ));
    builder.add2DDetailPath(bowlOval);

    return builder.build(defaultName);
  }
}

// ===========================================================================
// 3. WASHBASIN & VANITY (SanitaryWashbasinCabinet)
// ===========================================================================

class SanitaryWashbasinCabinet extends ArchitectComponentDefinition {
  @override
  String get id => 'sanitary_washbasin_cabinet';

  @override
  String get defaultName => 'Washbasin Vanity';

  @override
  ArchitectComponentCategory get category => ArchitectComponentCategory.sanitary;

  @override
  ComponentPlacementMode get placementMode => ComponentPlacementMode.wallAttached;

  @override
  List<ParametricFieldSchema> get schema => const [
    ParametricFieldSchema(key: 'width', label: 'Width', defaultValue: 0.80, min: 0.50, max: 1.50, step: 0.05),
    ParametricFieldSchema(key: 'depth', label: 'Depth', defaultValue: 0.48, min: 0.38, max: 0.60, step: 0.02),
    ParametricFieldSchema(key: 'height', label: 'Height', defaultValue: 0.85, min: 0.75, max: 0.92, step: 0.01),
  ];

  @override
  CachedComponentGeometry generateGeometry(Map<String, dynamic> params) {
    final w = (params['width'] as num?)?.toDouble() ?? 0.80;
    final d = (params['depth'] as num?)?.toDouble() ?? 0.48;
    final h = (params['height'] as num?)?.toDouble() ?? 0.85;

    final builder = ParametricSolidBuilder(width: w, depth: d, height: h);
    final wHalf = w / 2.0;

    // 1. Wooden vanity base (height h - 0.12 m)
    final baseH = h - 0.12;
    builder.addBox(
      origin: Offset(-wHalf, 0.0),
      boxWidth: w,
      boxDepth: d * 0.96,
      boxHeight: baseH,
      color: const Color(0xFF795548), // Warm walnut/wood
    );

    // 2. Ceramic countertop (thickness 0.12 m)
    builder.addBox(
      origin: Offset(-wHalf, 0.0),
      boxWidth: w,
      boxDepth: d,
      boxHeight: 0.12,
      zBottom: baseH,
      color: const Color(0xFFFAFAFA),
    );

    // 3. Faucet fixture
    builder.addCylinder(
      center: Offset(0.0, d * 0.16),
      radius: 0.022,
      cylinderHeight: 0.16,
      zBottom: h,
      color: const Color(0xFFCFD8DC), // Chrome
    );

    // 2D CAD Plan Block Details
    // Basin bowl inner oval
    final basinOval = Path()
      ..addOval(Rect.fromCenter(
        center: Offset(0.0, d * 0.56),
        width: math.min(w * 0.72, 0.52),
        height: d * 0.60,
      ));
    builder.add2DDetailPath(basinOval);

    // Drain hole
    final drain = Path()
      ..addOval(Rect.fromCenter(
        center: Offset(0.0, d * 0.56),
        width: 0.05,
        height: 0.05,
      ));
    builder.add2DDetailPath(drain);

    // Faucet base
    final tap = Path()
      ..addOval(Rect.fromCenter(
        center: Offset(0.0, d * 0.16),
        width: 0.045,
        height: 0.045,
      ));
    builder.add2DDetailPath(tap);

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
    ParametricFieldSchema(key: 'width', label: 'Width', defaultValue: 0.75, min: 0.70, max: 0.90, step: 0.05),
    ParametricFieldSchema(key: 'depth', label: 'Length', defaultValue: 1.70, min: 1.40, max: 1.90, step: 0.05),
    ParametricFieldSchema(key: 'height', label: 'Height', defaultValue: 0.58, min: 0.48, max: 0.68, step: 0.02),
  ];

  @override
  CachedComponentGeometry generateGeometry(Map<String, dynamic> params) {
    final w = (params['width'] as num?)?.toDouble() ?? 0.75;
    final d = (params['depth'] as num?)?.toDouble() ?? 1.70;
    final h = (params['height'] as num?)?.toDouble() ?? 0.58;

    final builder = ParametricSolidBuilder(width: w, depth: d, height: h);
    final wHalf = w / 2.0;

    // 1. Tub outer apron
    builder.addBox(
      origin: Offset(-wHalf, 0.0),
      boxWidth: w,
      boxDepth: d,
      boxHeight: h,
      color: const Color(0xFFFAFAFA),
    );

    // 2D CAD Plan Block Details
    final rimMargin = 0.08;
    final innerBasin = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTRB(-wHalf + rimMargin, rimMargin, wHalf - rimMargin, d - rimMargin),
        const Radius.circular(0.18),
      ));
    builder.add2DDetailPath(innerBasin);

    // Drain circle
    final drain = Path()
      ..addOval(Rect.fromCenter(
        center: Offset(0.0, d - 0.25),
        width: 0.06,
        height: 0.06,
      ));
    builder.add2DDetailPath(drain);

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
    ParametricFieldSchema(key: 'width', label: 'Width', defaultValue: 0.90, min: 0.80, max: 1.40, step: 0.05),
    ParametricFieldSchema(key: 'depth', label: 'Depth', defaultValue: 0.90, min: 0.80, max: 1.40, step: 0.05),
    ParametricFieldSchema(key: 'height', label: 'Height', defaultValue: 2.00, min: 1.80, max: 2.20, step: 0.05),
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
      ..addOval(Rect.fromCenter(
        center: Offset(drainX, drainY),
        width: 0.08,
        height: 0.08,
      ));
    builder.add2DDetailPath(drain);

    // Slope fall diagonal lines toward drain
    builder.add2DDetailLine(Offset(-wHalf, 0.0), Offset(drainX, drainY));
    builder.add2DDetailLine(Offset(wHalf, 0.0), Offset(drainX, drainY));
    builder.add2DDetailLine(Offset(wHalf, d), Offset(drainX, drainY));
    builder.add2DDetailLine(Offset(-wHalf, d), Offset(drainX, drainY));

    return builder.build(defaultName);
  }
}
