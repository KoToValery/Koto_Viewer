// === SECTION: KITCHEN PARAMETRIC COMPONENT DEFINITIONS ===
// Table of Contents:
// 1. MODULAR BASE CABINET (KitchenBaseCabinet)
// 2. KITCHEN SINK UNIT (KitchenSinkCabinet)
// 3. REFRIGERATOR (KitchenRefrigerator)
// 4. COOKTOP & OVEN (KitchenCooktopOven)

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/architect_component.dart';
import '../../models/architect_component_definition.dart';

// ===========================================================================
// 1. MODULAR BASE CABINET (KitchenBaseCabinet)
// ===========================================================================

class KitchenBaseCabinet extends ArchitectComponentDefinition {
  @override
  String get id => 'kitchen_base_cabinet';

  @override
  String get defaultName => 'Kitchen Base Cabinet';

  @override
  ArchitectComponentCategory get category => ArchitectComponentCategory.kitchen;

  @override
  ComponentPlacementMode get placementMode => ComponentPlacementMode.wallAttached;

  @override
  List<ParametricFieldSchema> get schema => const [
    ParametricFieldSchema(
      key: 'width',
      label: 'Width',
      defaultValue: 0.60,
      min: 0.30,
      max: 1.20,
      step: 0.05,
    ),
    ParametricFieldSchema(
      key: 'depth',
      label: 'Depth',
      defaultValue: 0.60,
      min: 0.50,
      max: 0.70,
      step: 0.02,
    ),
    ParametricFieldSchema(
      key: 'height',
      label: 'Height',
      defaultValue: 0.86,
      min: 0.80,
      max: 0.92,
      step: 0.01,
    ),
  ];

  @override
  CachedComponentGeometry generateGeometry(Map<String, dynamic> params) {
    final w = (params['width'] as num?)?.toDouble() ?? 0.60;
    final d = (params['depth'] as num?)?.toDouble() ?? 0.60;
    final h = (params['height'] as num?)?.toDouble() ?? 0.86;

    final builder = ParametricSolidBuilder(width: w, depth: d, height: h);
    final wHalf = w / 2.0;
    final plinthH = 0.10;
    final plinthInset = 0.05;
    final topH = 0.04;

    // 1. Plinth base
    builder.addBox(
      origin: Offset(-wHalf, plinthInset),
      boxWidth: w,
      boxDepth: d - plinthInset,
      boxHeight: plinthH,
      color: const Color(0xFF37474F), // Dark charcoal plinth
    );

    // 2. Carcass
    builder.addBox(
      origin: Offset(-wHalf, 0.0),
      boxWidth: w,
      boxDepth: d * 0.96,
      boxHeight: h - plinthH - topH,
      zBottom: plinthH,
      color: const Color(0xFFECEFF1), // White / light gray
    );

    // 3. Countertop
    builder.addBox(
      origin: Offset(-wHalf, 0.0),
      boxWidth: w,
      boxDepth: d,
      boxHeight: topH,
      zBottom: h - topH,
      color: const Color(0xFF78909C), // Slate countertop
    );

    // 2D CAD Plan Details
    // Door handle or line
    final handleY = d - 0.02;
    builder.add2DDetailLine(
      Offset(-wHalf * 0.5, handleY),
      Offset(wHalf * 0.5, handleY),
    );

    return builder.build(defaultName);
  }
}

// ===========================================================================
// 2. KITCHEN SINK UNIT (KitchenSinkCabinet)
// ===========================================================================

class KitchenSinkCabinet extends ArchitectComponentDefinition {
  final bool legacyDimensions;
  KitchenSinkCabinet({this.legacyDimensions = false});
  @override
  String get id =>
      legacyDimensions ? 'kitchen_sink_cabinet' : 'kitchen_sink_unit';

  @override
  String get defaultName => 'Kitchen Sink Unit';

  @override
  ArchitectComponentCategory get category => ArchitectComponentCategory.kitchen;

  @override
  ComponentPlacementMode get placementMode => ComponentPlacementMode.wallAttached;

  @override
  List<ParametricFieldSchema> get schema => [
    ParametricFieldSchema(
      key: 'width',
      label: 'Width',
      defaultValue: 0.80,
      min: 0.60,
      max: 1.20,
      step: 0.05,
    ),
    ParametricFieldSchema(
      key: 'depth',
      label: 'Depth',
      defaultValue: 0.60,
      min: 0.55,
      max: 0.70,
      step: 0.02,
    ),
    ParametricFieldSchema(
      key: 'height',
      label: 'Height',
      defaultValue: legacyDimensions ? .86 : 1.08,
      min: .80,
      max: 1.20,
      step: 0.01,
    ),
  ];

  @override
  CachedComponentGeometry generateGeometry(Map<String, dynamic> params) {
    final w = (params['width'] as num?)?.toDouble() ?? .80;
    final d = (params['depth'] as num?)?.toDouble() ?? .60;
    final requestedH =
        (params['height'] as num?)?.toDouble() ??
        (legacyDimensions ? .86 : 1.08);
    final h = legacyDimensions ? requestedH + .22 : requestedH;
    final tapH = h * (.22 / 1.08);
    final basinH = h * (.16 / 1.08);
    final baseH = h - tapH - basinH;
    final builder = ParametricSolidBuilder(width: w, depth: d, height: h);
    builder.addBox(
      boxWidth: w,
      boxDepth: d,
      boxHeight: baseH,
      color: const Color(0xFFECEFF1),
    );
    builder.addBasin(
      center: Offset(0, d / 2),
      basinWidth: w,
      basinDepth: d,
      basinHeight: basinH,
      zBottom: baseH,
      wall: math.min(w, d) * .20,
      base: basinH * .15,
      rectangular: true,
      color: const Color(0xFFCFD8DC),
    );
    builder.addCylinder(
      center: Offset(0, d * .06),
      radius: w * .025,
      cylinderHeight: tapH,
      zBottom: h - tapH,
      color: const Color(0xFFB0BEC5),
    );
    builder.add2DDetailPath(
      Path()..addOval(
        Rect.fromCircle(center: Offset(0, d / 2), radius: math.min(w, d) * .05),
      ),
    );
    return builder.build(defaultName);
  }
}

// ===========================================================================
// 3. REFRIGERATOR (KitchenRefrigerator)
// ===========================================================================

class KitchenRefrigerator extends ArchitectComponentDefinition {
  @override
  String get id => 'kitchen_refrigerator';

  @override
  String get defaultName => 'Refrigerator';

  @override
  ArchitectComponentCategory get category => ArchitectComponentCategory.kitchen;

  @override
  ComponentPlacementMode get placementMode => ComponentPlacementMode.wallAttached;

  @override
  List<ParametricFieldSchema> get schema => const [
    ParametricFieldSchema(
      key: 'width',
      label: 'Width',
      defaultValue: 0.60,
      min: 0.55,
      max: 0.95,
      step: 0.05,
    ),
    ParametricFieldSchema(
      key: 'depth',
      label: 'Depth',
      defaultValue: 0.65,
      min: 0.55,
      max: 0.80,
      step: 0.02,
    ),
    ParametricFieldSchema(
      key: 'height',
      label: 'Height',
      defaultValue: 1.85,
      min: 1.50,
      max: 2.10,
      step: 0.05,
    ),
  ];

  @override
  CachedComponentGeometry generateGeometry(Map<String, dynamic> params) {
    final w = (params['width'] as num?)?.toDouble() ?? 0.60;
    final d = (params['depth'] as num?)?.toDouble() ?? 0.65;
    final h = (params['height'] as num?)?.toDouble() ?? 1.85;

    final builder = ParametricSolidBuilder(width: w, depth: d, height: h);
    final wHalf = w / 2.0;

    // Refrigerator body
    builder.addBox(
      origin: Offset(-wHalf, 0.0),
      boxWidth: w,
      boxDepth: d,
      boxHeight: h,
      color: const Color(0xFFB0BEC5), // Stainless steel / silver
    );

    // 2D CAD Plan Details: Standard architectural diagonal cross
    builder.add2DDetailLine(Offset(-wHalf, 0.0), Offset(wHalf, d));
    builder.add2DDetailLine(Offset(-wHalf, d), Offset(wHalf, 0.0));

    // Door front seam
    builder.add2DDetailLine(Offset(-wHalf, d - 0.04), Offset(wHalf, d - 0.04));

    return builder.build(defaultName);
  }
}

// ===========================================================================
// 4. COOKTOP & OVEN (KitchenCooktopOven)
// ===========================================================================

class KitchenCooktopOven extends ArchitectComponentDefinition {
  @override
  String get id => 'kitchen_cooktop_oven';

  @override
  String get defaultName => 'Cooktop & Oven';

  @override
  ArchitectComponentCategory get category => ArchitectComponentCategory.kitchen;

  @override
  ComponentPlacementMode get placementMode => ComponentPlacementMode.wallAttached;

  @override
  List<ParametricFieldSchema> get schema => const [
    ParametricFieldSchema(
      key: 'width',
      label: 'Width',
      defaultValue: 0.60,
      min: 0.60,
      max: 0.90,
      step: 0.05,
    ),
    ParametricFieldSchema(
      key: 'depth',
      label: 'Depth',
      defaultValue: 0.60,
      min: 0.55,
      max: 0.65,
      step: 0.02,
    ),
    ParametricFieldSchema(
      key: 'height',
      label: 'Height',
      defaultValue: 0.86,
      min: 0.80,
      max: 0.92,
      step: 0.01,
    ),
  ];

  @override
  CachedComponentGeometry generateGeometry(Map<String, dynamic> params) {
    final w = (params['width'] as num?)?.toDouble() ?? 0.60;
    final d = (params['depth'] as num?)?.toDouble() ?? 0.60;
    final h = (params['height'] as num?)?.toDouble() ?? 0.86;

    final builder = ParametricSolidBuilder(width: w, depth: d, height: h);
    final wHalf = w / 2.0;

    // Cabinet & oven housing
    builder.addBox(
      origin: Offset(-wHalf, 0.0),
      boxWidth: w,
      boxDepth: d,
      boxHeight: h,
      color: const Color(0xFF263238), // Dark enamel / modern oven
    );

    // 4 Burner cylinders on top
    final rSmall = 0.06;
    final rLarge = 0.085;
    final burners = [
      (Offset(-wHalf * 0.5, d * 0.35), rLarge),
      (Offset(wHalf * 0.5, d * 0.35), rSmall),
      (Offset(-wHalf * 0.5, d * 0.72), rSmall),
      (Offset(wHalf * 0.5, d * 0.72), rLarge),
    ];

    for (final b in burners) {
      builder.addCylinder(
        center: b.$1,
        radius: b.$2,
        cylinderHeight: 0.005,
        zBottom: h - 0.005,
        segments: 16,
        color: const Color(0xFF424242),
      );

      // 2D CAD Plan Burner Circles
      builder.add2DDetailPath(
        Path()..addOval(Rect.fromCircle(center: b.$1, radius: b.$2)),
      );
    }

    return builder.build(defaultName);
  }
}
