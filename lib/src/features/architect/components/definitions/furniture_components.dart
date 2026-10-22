// === SECTION: FURNITURE PARAMETRIC COMPONENT DEFINITIONS ===
// Table of Contents:
// 1. DOUBLE BED (FurnitureBedDouble)
// 2. SINGLE BED (FurnitureBedSingle)
// 3. WARDROBE (FurnitureWardrobe)
// 4. DINING TABLE WITH CHAIRS (FurnitureDiningTableSet)
// 5. LIVING ROOM SOFA (FurnitureSofa)
// 6. OFFICE DESK (FurnitureOfficeDesk)

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/architect_component.dart';
import '../../models/architect_component_definition.dart';

// ===========================================================================
// 1. DOUBLE BED (FurnitureBedDouble)
// ===========================================================================

class FurnitureBedDouble extends ArchitectComponentDefinition {
  @override
  String get id => 'furniture_bed_double';

  @override
  String get defaultName => 'Double Bed';

  @override
  ArchitectComponentCategory get category => ArchitectComponentCategory.furniture;

  @override
  ComponentPlacementMode get placementMode => ComponentPlacementMode.wallAttached;

  @override
  List<ParametricFieldSchema> get schema => const [
    ParametricFieldSchema(
      key: 'width',
      label: 'Width',
      defaultValue: 1.80,
      min: 1.40,
      max: 2.20,
      step: 0.10,
    ),
    ParametricFieldSchema(
      key: 'depth',
      label: 'Length',
      defaultValue: 2.00,
      min: 1.90,
      max: 2.20,
      step: 0.05,
    ),
    ParametricFieldSchema(
      key: 'height',
      label: 'Headboard Height',
      defaultValue: 0.95,
      min: 0.75,
      max: 1.25,
      step: 0.05,
    ),
  ];

  @override
  CachedComponentGeometry generateGeometry(Map<String, dynamic> params) {
    final w = (params['width'] as num?)?.toDouble() ?? 1.80;
    final d = (params['depth'] as num?)?.toDouble() ?? 2.00;
    final h = (params['height'] as num?)?.toDouble() ?? 0.95;

    final builder = ParametricSolidBuilder(width: w, depth: d, height: h);
    final wHalf = w / 2.0;
    final headboardD = 0.08;
    final mattressH = 0.45;

    // 1. Headboard (against wall at Y = 0)
    builder.addBox(
      origin: Offset(-wHalf, 0.0),
      boxWidth: w,
      boxDepth: headboardD,
      boxHeight: h,
      color: const Color(0xFF5D4037), // Dark wood
    );

    builder.addBox(
      boxWidth: w,
      boxDepth: d,
      boxHeight: h * .20,
      color: const Color(0xFF8D6E63),
    );

    // 2. Mattress
    final mattressW = w * 0.94;
    final mattressD = d - headboardD - 0.04;
    builder.addBox(
      origin: Offset(-mattressW / 2.0, headboardD + 0.02),
      boxWidth: mattressW,
      boxDepth: mattressD,
      boxHeight: mattressH,
      color: const Color(0xFFECEFF1), // Off-white linen
    );

    // 3. Two Pillows in 3D
    final pillowW = mattressW * 0.44;
    final pillowD = 0.38;
    final pillowH = 0.12;
    for (final sign in [-1.0, 1.0]) {
      final px = sign * (pillowW * 0.55);
      builder.addBox(
        origin: Offset(px - pillowW / 2.0, headboardD + 0.06),
        boxWidth: pillowW,
        boxDepth: pillowD,
        boxHeight: pillowH,
        zBottom: mattressH,
        color: const Color(0xFFFFFFFF),
      );
    }

    // 2D CAD Plan Block Details
    // Headboard rectangle
    final headboardPath = Path()
      ..addRect(Rect.fromLTRB(-wHalf, 0.0, wHalf, headboardD));
    builder.add2DDetailPath(headboardPath);

    // Pillows in 2D with standard architectural X-cross
    for (final sign in [-1.0, 1.0]) {
      final px = sign * (pillowW * 0.55);
      final pRect = Rect.fromLTRB(
        px - pillowW / 2.0,
        headboardD + 0.06,
        px + pillowW / 2.0,
        headboardD + 0.06 + pillowD,
      );
      final pPath = Path()
        ..addRRect(RRect.fromRectAndRadius(pRect, const Radius.circular(0.04)));
      builder.add2DDetailPath(pPath);

      // Pillow cross seams
      builder.add2DDetailLine(pRect.topLeft, pRect.bottomRight);
      builder.add2DDetailLine(pRect.topRight, pRect.bottomLeft);
    }

    // Blanket fold line
    final foldY = headboardD + mattressD * 0.55;
    builder.add2DDetailLine(
      Offset(-mattressW / 2.0, foldY),
      Offset(mattressW / 2.0, foldY),
    );

    return builder.build(defaultName);
  }
}

// ===========================================================================
// 2. SINGLE BED (FurnitureBedSingle)
// ===========================================================================

class FurnitureBedSingle extends ArchitectComponentDefinition {
  @override
  String get id => 'furniture_bed_single';

  @override
  String get defaultName => 'Single Bed';

  @override
  ArchitectComponentCategory get category => ArchitectComponentCategory.furniture;

  @override
  ComponentPlacementMode get placementMode => ComponentPlacementMode.wallAttached;

  @override
  List<ParametricFieldSchema> get schema => const [
    ParametricFieldSchema(
      key: 'width',
      label: 'Width',
      defaultValue: 0.90,
      min: 0.80,
      max: 1.20,
      step: 0.05,
    ),
    ParametricFieldSchema(
      key: 'depth',
      label: 'Length',
      defaultValue: 2.00,
      min: 1.90,
      max: 2.15,
      step: 0.05,
    ),
    ParametricFieldSchema(
      key: 'height',
      label: 'Headboard Height',
      defaultValue: 0.85,
      min: 0.70,
      max: 1.10,
      step: 0.05,
    ),
  ];

  @override
  CachedComponentGeometry generateGeometry(Map<String, dynamic> params) {
    final w = (params['width'] as num?)?.toDouble() ?? 0.90;
    final d = (params['depth'] as num?)?.toDouble() ?? 2.00;
    final h = (params['height'] as num?)?.toDouble() ?? 0.85;

    final builder = ParametricSolidBuilder(width: w, depth: d, height: h);
    final wHalf = w / 2.0;
    final headboardD = 0.06;
    final mattressH = 0.42;

    // Headboard
    builder.addBox(
      origin: Offset(-wHalf, 0.0),
      boxWidth: w,
      boxDepth: headboardD,
      boxHeight: h,
      color: const Color(0xFF6D4C41),
    );

    builder.addBox(
      boxWidth: w,
      boxDepth: d,
      boxHeight: h * .20,
      color: const Color(0xFF8D6E63),
    );

    // Mattress
    final mattressW = w * 0.92;
    final mattressD = d - headboardD - 0.04;
    builder.addBox(
      origin: Offset(-mattressW / 2.0, headboardD + 0.02),
      boxWidth: mattressW,
      boxDepth: mattressD,
      boxHeight: mattressH,
      color: const Color(0xFFECEFF1),
    );

    // Single Pillow
    final pillowW = mattressW * 0.75;
    final pillowD = 0.36;
    builder.addBox(
      origin: Offset(-pillowW / 2.0, headboardD + 0.06),
      boxWidth: pillowW,
      boxDepth: pillowD,
      boxHeight: 0.12,
      zBottom: mattressH,
      color: const Color(0xFFFFFFFF),
    );

    // 2D CAD Plan Details
    final headboardPath = Path()
      ..addRect(Rect.fromLTRB(-wHalf, 0.0, wHalf, headboardD));
    builder.add2DDetailPath(headboardPath);

    final pRect = Rect.fromLTRB(
      -pillowW / 2.0,
      headboardD + 0.06,
      pillowW / 2.0,
      headboardD + 0.06 + pillowD,
    );
    builder.add2DDetailPath(
      Path()
        ..addRRect(RRect.fromRectAndRadius(pRect, const Radius.circular(0.04))),
    );
    builder.add2DDetailLine(pRect.topLeft, pRect.bottomRight);
    builder.add2DDetailLine(pRect.topRight, pRect.bottomLeft);

    final foldY = headboardD + mattressD * 0.55;
    builder.add2DDetailLine(
      Offset(-mattressW / 2.0, foldY),
      Offset(mattressW / 2.0, foldY),
    );

    return builder.build(defaultName);
  }
}

// ===========================================================================
// 3. WARDROBE (FurnitureWardrobe)
// ===========================================================================

class FurnitureWardrobe extends ArchitectComponentDefinition {
  @override
  String get id => 'furniture_wardrobe';

  @override
  String get defaultName => 'Wardrobe';

  @override
  ArchitectComponentCategory get category => ArchitectComponentCategory.storage;

  @override
  ComponentPlacementMode get placementMode => ComponentPlacementMode.wallAttached;

  @override
  List<ParametricFieldSchema> get schema => const [
    ParametricFieldSchema(
      key: 'width',
      label: 'Width',
      defaultValue: 1.80,
      min: 0.80,
      max: 3.50,
      step: 0.10,
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
      defaultValue: 2.20,
      min: 1.90,
      max: 2.70,
      step: 0.05,
    ),
  ];

  @override
  CachedComponentGeometry generateGeometry(Map<String, dynamic> params) {
    final w = (params['width'] as num?)?.toDouble() ?? 1.80;
    final d = (params['depth'] as num?)?.toDouble() ?? 0.60;
    final h = (params['height'] as num?)?.toDouble() ?? 2.20;

    final builder = ParametricSolidBuilder(width: w, depth: d, height: h);
    final wHalf = w / 2.0;

    // 1. Carcass body
    builder.addBox(
      origin: Offset(-wHalf, 0.0),
      boxWidth: w,
      boxDepth: d,
      boxHeight: h,
      color: const Color(0xFFD7CCC8), // Light oak / neutral
    );

    // 2D CAD Plan Details: Standard architectural diagonal cross
    builder.add2DDetailLine(Offset(-wHalf, 0.0), Offset(wHalf, d));
    builder.add2DDetailLine(Offset(-wHalf, d), Offset(wHalf, 0.0));

    // Internal clothes hanger rail line
    final railY = d * 0.40;
    final railPath = Path()
      ..moveTo(-wHalf + 0.05, railY)
      ..lineTo(wHalf - 0.05, railY);
    builder.add2DDetailPath(railPath);

    return builder.build(defaultName);
  }
}

// ===========================================================================
// 4. DINING TABLE WITH CHAIRS (FurnitureDiningTableSet)
// ===========================================================================

class FurnitureDiningTableSet extends ArchitectComponentDefinition {
  final bool legacyDimensions;
  FurnitureDiningTableSet({this.legacyDimensions = false});
  @override
  String get id =>
      legacyDimensions ? 'furniture_dining_table' : 'furniture_dining_set';

  @override
  String get defaultName => 'Dining Table & Chairs';

  @override
  ArchitectComponentCategory get category =>
      ArchitectComponentCategory.furniture;

  @override
  ComponentPlacementMode get placementMode =>
      ComponentPlacementMode.freeStanding;

  @override
  List<ParametricFieldSchema> get schema => [
    ParametricFieldSchema(
      key: 'width',
      label: 'Width',
      defaultValue: legacyDimensions ? .90 : 1.53,
      min: .75,
      max: 3.0,
      step: 0.05,
    ),
    ParametricFieldSchema(
      key: 'depth',
      label: 'Length',
      defaultValue: 1.60,
      min: 1.10,
      max: 2.60,
      step: 0.10,
    ),
    ParametricFieldSchema(
      key: 'height',
      label: 'Table Height',
      defaultValue: legacyDimensions ? .76 : .82,
      min: .70,
      max: 1.0,
      step: 0.02,
    ),
  ];

  @override
  CachedComponentGeometry generateGeometry(Map<String, dynamic> params) {
    final overallW =
        (params['width'] as num?)?.toDouble() ??
        (legacyDimensions ? .90 : 1.53);
    final w = legacyDimensions ? overallW : overallW * (.90 / 1.53);
    final d = (params['depth'] as num?)?.toDouble() ?? 1.60;
    final overallH =
        (params['height'] as num?)?.toDouble() ??
        (legacyDimensions ? .76 : .82);
    final h = legacyDimensions ? overallH : overallH * (.76 / .82);

    final builder = ParametricSolidBuilder(width: w, depth: d, height: h);
    final wHalf = w / 2.0;

    // 1. Tabletop slab (thickness 0.04 m)
    builder.addBox(
      origin: Offset(-wHalf, 0.0),
      boxWidth: w,
      boxDepth: d,
      boxHeight: 0.04,
      zBottom: h - 0.04,
      color: const Color(0xFF8D6E63), // Wood brown
    );

    // 2. 4 Legs
    final legSize = 0.06;
    final legH = h - 0.04;
    final legInset = 0.05;
    final legCoords = [
      Offset(-wHalf + legInset, legInset),
      Offset(wHalf - legInset - legSize, legInset),
      Offset(wHalf - legInset - legSize, d - legInset - legSize),
      Offset(-wHalf + legInset, d - legInset - legSize),
    ];
    for (final origin in legCoords) {
      builder.addBox(
        origin: origin,
        boxWidth: legSize,
        boxDepth: legSize,
        boxHeight: legH,
        color: const Color(0xFF4E342E),
      );
    }

    // 3. Chairs placed along the two long sides (X = -wHalf and X = wHalf)
    final chairW = d * (.42 / 1.60);
    final chairD = w * (.42 / .90);
    final chairCountPerSide = math.max(1, (d / 0.70).floor());
    final spacing = d / (chairCountPerSide + 1);
    builder.add2DDetailPath(
      Path()..addRect(Rect.fromLTRB(-wHalf, 0, wHalf, d)),
    );

    void chair(Offset origin, bool left) {
      final seatZ = h * (.45 / .76);
      final seatThickness = h * (.035 / .76);
      builder.addBox(
        origin: origin,
        boxWidth: chairD,
        boxDepth: chairW,
        boxHeight: seatThickness,
        zBottom: seatZ,
        color: const Color(0xFFB0BEC5),
      );
      for (final x in [.025, chairD - .055]) {
        for (final y in [.025, chairW - .055]) {
          builder.addBox(
            origin: origin + Offset(x, y),
            boxWidth: .03,
            boxDepth: .03,
            boxHeight: seatZ,
            color: const Color(0xFF78909C),
          );
        }
      }
      builder.addBox(
        origin: origin + Offset(left ? 0 : chairD - .035, 0),
        boxWidth: .035,
        boxDepth: chairW,
        boxHeight:
            (legacyDimensions ? h * (.82 / .76) : overallH) -
            seatZ -
            seatThickness,
        zBottom: seatZ + seatThickness,
        color: const Color(0xFF90A4AE),
      );
    }

    for (var i = 1; i <= chairCountPerSide; i++) {
      final cy = i * spacing;
      // Left chair (tucked slightly under table)
      final leftOrigin = Offset(-wHalf - chairD * 0.75, cy - chairW / 2.0);
      chair(leftOrigin, true);

      // Right chair
      final rightOrigin = Offset(wHalf - chairD * 0.25, cy - chairW / 2.0);
      chair(rightOrigin, false);

      // 2D detail lines for chairs
      builder.add2DDetailLine(
        leftOrigin + const Offset(.035, 0),
        leftOrigin + Offset(.035, chairW),
      );
      builder.add2DDetailLine(
        rightOrigin + Offset(chairD - .035, 0),
        rightOrigin + Offset(chairD - .035, chairW),
      );
    }

    return builder.build(defaultName);
  }
}

// ===========================================================================
// 5. LIVING ROOM SOFA (FurnitureSofa)
// ===========================================================================

class FurnitureSofa extends ArchitectComponentDefinition {
  @override
  String get id => 'furniture_sofa';

  @override
  String get defaultName => 'Sofa';

  @override
  ArchitectComponentCategory get category => ArchitectComponentCategory.furniture;

  @override
  ComponentPlacementMode get placementMode => ComponentPlacementMode.wallAttached;

  @override
  List<ParametricFieldSchema> get schema => const [
    ParametricFieldSchema(
      key: 'width',
      label: 'Width',
      defaultValue: 2.10,
      min: 1.50,
      max: 2.80,
      step: 0.10,
    ),
    ParametricFieldSchema(
      key: 'depth',
      label: 'Depth',
      defaultValue: 0.90,
      min: 0.80,
      max: 1.05,
      step: 0.02,
    ),
    ParametricFieldSchema(
      key: 'height',
      label: 'Backrest Height',
      defaultValue: 0.82,
      min: 0.70,
      max: 0.95,
      step: 0.02,
    ),
  ];

  @override
  CachedComponentGeometry generateGeometry(Map<String, dynamic> params) {
    final w = (params['width'] as num?)?.toDouble() ?? 2.10;
    final d = (params['depth'] as num?)?.toDouble() ?? 0.90;
    final h = (params['height'] as num?)?.toDouble() ?? 0.82;

    final builder = ParametricSolidBuilder(width: w, depth: d, height: h);
    final wHalf = w / 2.0;
    final armrestW = 0.18;
    final backrestD = 0.22;
    final seatH = 0.44;
    final fabric = const Color(0xFF546E7A); // Slate blue fabric

    // 1. Backrest (along Y = 0)
    builder.addBox(
      origin: Offset(-wHalf, 0.0),
      boxWidth: w,
      boxDepth: backrestD,
      boxHeight: h,
      color: fabric,
    );

    // 2. Left & Right Armrests
    builder.addBox(
      origin: Offset(-wHalf, backrestD),
      boxWidth: armrestW,
      boxDepth: d - backrestD,
      boxHeight: h * 0.75,
      color: fabric,
    );
    builder.addBox(
      origin: Offset(wHalf - armrestW, backrestD),
      boxWidth: armrestW,
      boxDepth: d - backrestD,
      boxHeight: h * 0.75,
      color: fabric,
    );

    // 3. Seat Cushions
    final seatingW = w - 2 * armrestW;
    final seatingD = d - backrestD;
    builder.addBox(
      origin: Offset(-seatingW / 2.0, backrestD),
      boxWidth: seatingW,
      boxDepth: seatingD,
      boxHeight: seatH,
      color: const Color(0xFF455A64),
    );

    // 2D CAD Plan Block Details
    // Backrest line
    builder.add2DDetailLine(
      Offset(-wHalf, backrestD),
      Offset(wHalf, backrestD),
    );

    // Armrest lines
    builder.add2DDetailLine(
      Offset(-wHalf + armrestW, backrestD),
      Offset(-wHalf + armrestW, d),
    );
    builder.add2DDetailLine(
      Offset(wHalf - armrestW, backrestD),
      Offset(wHalf - armrestW, d),
    );

    // Seat cushion division (2 or 3 cushions)
    final cushionCount = w > 2.0 ? 3 : 2;
    final cW = seatingW / cushionCount;
    for (var i = 1; i < cushionCount; i++) {
      final cx = -seatingW / 2.0 + i * cW;
      builder.add2DDetailLine(Offset(cx, backrestD), Offset(cx, d));
    }

    return builder.build(defaultName);
  }
}

// ===========================================================================
// 6. OFFICE DESK (FurnitureOfficeDesk)
// ===========================================================================

class FurnitureOfficeDesk extends ArchitectComponentDefinition {
  @override
  String get id => 'furniture_office_desk';

  @override
  String get defaultName => 'Office Desk';

  @override
  ArchitectComponentCategory get category => ArchitectComponentCategory.office;

  @override
  ComponentPlacementMode get placementMode => ComponentPlacementMode.wallAttached;

  @override
  List<ParametricFieldSchema> get schema => const [
    ParametricFieldSchema(
      key: 'width',
      label: 'Width',
      defaultValue: 1.40,
      min: 1.00,
      max: 2.00,
      step: 0.10,
    ),
    ParametricFieldSchema(
      key: 'depth',
      label: 'Depth',
      defaultValue: 0.70,
      min: 0.60,
      max: 0.90,
      step: 0.05,
    ),
    ParametricFieldSchema(
      key: 'height',
      label: 'Height',
      defaultValue: 0.75,
      min: 0.70,
      max: 0.80,
      step: 0.01,
    ),
  ];

  @override
  CachedComponentGeometry generateGeometry(Map<String, dynamic> params) {
    final w = (params['width'] as num?)?.toDouble() ?? 1.40;
    final d = (params['depth'] as num?)?.toDouble() ?? 0.70;
    final h = (params['height'] as num?)?.toDouble() ?? 0.75;

    final builder = ParametricSolidBuilder(width: w, depth: d, height: h);
    final wHalf = w / 2.0;

    // Desktop surface
    builder.addBox(
      origin: Offset(-wHalf, 0.0),
      boxWidth: w,
      boxDepth: d,
      boxHeight: 0.03,
      zBottom: h - 0.03,
      color: const Color(0xFFCFD8DC),
    );

    // Left drawer pedestal
    final pedW = 0.40;
    builder.addBox(
      origin: Offset(-wHalf, 0.0),
      boxWidth: pedW,
      boxDepth: d * 0.90,
      boxHeight: h - 0.03,
      color: const Color(0xFF90A4AE),
    );

    // Right leg panel
    builder.addBox(
      origin: Offset(wHalf - 0.04, 0.0),
      boxWidth: 0.04,
      boxDepth: d,
      boxHeight: h - 0.03,
      color: const Color(0xFF607D8B),
    );

    // 2D CAD Plan Details
    // Pedestal drawer line
    builder.add2DDetailLine(
      Offset(-wHalf + pedW, 0.0),
      Offset(-wHalf + pedW, d * 0.90),
    );

    return builder.build(defaultName);
  }
}
