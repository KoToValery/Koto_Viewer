import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_grid_preset.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';
import 'package:kotoview/src/features/architect/models/architect_wall_type.dart';

void main() {
  group('ArchitectWallType statutory parapet tests', () {
    test('resolveParapetHeight returns 1.05m for < 5 storeys and < 20m elevation', () {
      expect(ArchitectWallType.resolveParapetHeight(storeyElevation: 0.0, storeyIndex: 1), 1.05);
      expect(ArchitectWallType.resolveParapetHeight(storeyElevation: 12.0, storeyIndex: 4), 1.05);
    });

    test('resolveParapetHeight returns 1.20m for >= 5 storeys or >= 20m elevation', () {
      expect(ArchitectWallType.resolveParapetHeight(storeyElevation: 14.0, storeyIndex: 5), 1.20);
      expect(ArchitectWallType.resolveParapetHeight(storeyElevation: 16.8, storeyIndex: 6), 1.20);
      expect(ArchitectWallType.resolveParapetHeight(storeyElevation: 25.0, storeyIndex: 8), 1.20);
      expect(ArchitectWallType.resolveParapetHeight(storeyElevation: 21.0, storeyIndex: 4), 1.20);
    });

    test('standardCatalog returns 5 predefined wall types with exact physical dimensions', () {
      final catalog = ArchitectWallType.standardCatalog(
        parapetHeight: 1.05,
        parapetFinish: ParapetFinish.cap,
      );

      expect(catalog.length, 5);

      final extInsulated = catalog.firstWhere((w) => w.id == 'ext_25_12_eps');
      expect(extInsulated.brickThickness, 0.25);
      expect(extInsulated.insulationThickness, 0.12);
      expect(extInsulated.totalThickness, closeTo(0.37, 1e-4));
      expect(extInsulated.usage, WallUsage.exterior);

      final partition = catalog.firstWhere((w) => w.id == 'int_12_partition');
      expect(partition.totalThickness, 0.12);
      expect(partition.usage, WallUsage.interior);

      final brick25 = catalog.firstWhere((w) => w.id == 'ext_25_brick');
      expect(brick25.totalThickness, 0.25);
      expect(brick25.usage, WallUsage.exterior);

      final bearing = catalog.firstWhere((w) => w.id == 'bearing_25_concrete');
      expect(bearing.totalThickness, 0.25);
      expect(bearing.usage, WallUsage.bearing);

      final parapet = catalog.firstWhere((w) => w.id == 'parapet_12');
      expect(parapet.totalThickness, 0.12);
      expect(parapet.customHeight, 1.05);
      expect(parapet.parapetFinish, ParapetFinish.cap);
      expect(parapet.usage, WallUsage.parapet);
    });

    test('standardCatalog adapts parapet height and finish', () {
      final catalog = ArchitectWallType.standardCatalog(
        parapetHeight: 1.20,
        parapetFinish: ParapetFinish.handrailPipes,
      );

      final parapet = catalog.firstWhere((w) => w.id == 'parapet_12');
      expect(parapet.customHeight, 1.20);
      expect(parapet.parapetFinish, ParapetFinish.handrailPipes);
    });

    test('ArchitectWallType serialization and deserialization', () {
      const original = ArchitectWallType(
        id: 'custom_wall',
        name: 'Custom Wall 32',
        usage: WallUsage.exterior,
        totalThickness: 0.32,
        brickThickness: 0.20,
        insulationThickness: 0.12,
        customHeight: 1.20,
        parapetFinish: ParapetFinish.cap,
        colorValue: 0xFF123456,
      );

      final json = original.toJson();
      final restored = ArchitectWallType.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.usage, original.usage);
      expect(restored.totalThickness, original.totalThickness);
      expect(restored.brickThickness, original.brickThickness);
      expect(restored.insulationThickness, original.insulationThickness);
      expect(restored.customHeight, original.customHeight);
      expect(restored.parapetFinish, original.parapetFinish);
      expect(restored.colorValue, original.colorValue);
    });
  });

  group('ArchitectGridPreset tests', () {
    test('standardPresets contains parking 7.20 / 6.60 preset', () {
      final presets = ArchitectGridPreset.standardPresets();
      expect(presets.isNotEmpty, isTrue);

      final parkingPreset = presets.firstWhere((p) => p.id == 'preset_parking_72_66');
      expect(parkingPreset.spacingX, 7.20);
      expect(parkingPreset.spacingY, 6.60);
      expect(parkingPreset.axesX, 4);
      expect(parkingPreset.axesY, 3);
    });

    test('generateAxes creates numbered vertical axes and lettered horizontal axes for 7.20 / 6.60', () {
      final preset = ArchitectGridPreset.standardPresets().firstWhere(
        (p) => p.id == 'preset_parking_72_66',
      );

      final axes = preset.generateAxes();
      expect(axes.length, 7); // 4 in X, 3 in Y

      final verticalAxes = axes.where((a) => (a.start.dx - a.end.dx).abs() < 1e-4).toList();
      final horizontalAxes = axes.where((a) => (a.start.dy - a.end.dy).abs() < 1e-4).toList();

      expect(verticalAxes.length, 4);
      expect(horizontalAxes.length, 3);

      // Vertical axes should be labeled 1, 2, 3, 4
      expect(verticalAxes[0].name, '1');
      expect(verticalAxes[1].name, '2');
      expect(verticalAxes[2].name, '3');
      expect(verticalAxes[3].name, '4');

      // Horizontal axes should be labeled A, B, C
      expect(horizontalAxes[0].name, 'A');
      expect(horizontalAxes[1].name, 'B');
      expect(horizontalAxes[2].name, 'C');

      // Coordinate distances
      expect(verticalAxes[1].start.dx - verticalAxes[0].start.dx, closeTo(7.20, 1e-4));
      expect(horizontalAxes[1].start.dy - horizontalAxes[0].start.dy, closeTo(6.60, 1e-4));
    });

    test('generateAxes for none preset returns empty list', () {
      final nonePreset = ArchitectGridPreset.standardPresets().firstWhere(
        (p) => p.type == GridPresetType.none,
      );
      final axes = nonePreset.generateAxes();
      expect(axes, isEmpty);
    });

    test('generateAxes with custom overrides', () {
      final customPreset = ArchitectGridPreset.standardPresets().firstWhere(
        (p) => p.type == GridPresetType.custom,
      );
      final axes = customPreset.generateAxes(
        customAxesX: 3,
        customAxesY: 2,
        customSpacingX: 5.0,
        customSpacingY: 8.0,
      );
      expect(axes.length, 5);
      final verticalAxes = axes.where((a) => (a.start.dx - a.end.dx).abs() < 1e-4).toList();
      final horizontalAxes = axes.where((a) => (a.start.dy - a.end.dy).abs() < 1e-4).toList();
      expect(verticalAxes.length, 3);
      expect(horizontalAxes.length, 2);
      expect(verticalAxes[1].start.dx - verticalAxes[0].start.dx, closeTo(5.0, 1e-4));
      expect(horizontalAxes[1].start.dy - horizontalAxes[0].start.dy, closeTo(8.0, 1e-4));
    });
  });

  group('ArchitectProject.starterWithCatalog tests', () {
    test('creates configured storeys, grid axes, and wall types', () {
      final project = ArchitectProject.starterWithCatalog(
        name: 'Concept Residence',
        storeyCount: 3,
        groundHeight: 3.20,
        typicalHeight: 2.80,
      );

      expect(project.name, 'Concept Residence');
      expect(project.storeys.where((s)=>!s.isRoof).length, 3);
      expect(project.storeys.last.isRoof, isTrue);
      expect(project.storeys[0].height, 3.20);
      expect(project.storeys[0].elevation, 0.0);
      expect(project.storeys[1].height, 2.80);
      expect(project.storeys[1].elevation, 3.20);
      expect(project.storeys[2].height, 2.80);
      expect(project.storeys[2].elevation, 6.00);

      // Grid axes generated from default parking preset (4 X + 3 Y = 7)
      expect(project.gridAxes.length, 7);

      // Wall catalog initialized
      expect(project.wallTypes.length, 5);

      // 3 storeys -> parapet should be 1.05m
      final parapet = project.wallTypes.firstWhere((w) => w.id == 'parapet_12');
      expect(parapet.customHeight, 1.05);
    });

    test('sets 1.20m parapet when storey count exceeds 5 storeys', () {
      final project = ArchitectProject.starterWithCatalog(
        name: 'High-rise Tower',
        storeyCount: 8,
        groundHeight: 3.40,
        typicalHeight: 3.00,
      );

      expect(project.storeys.where((s)=>!s.isRoof).length, 8);
      expect(project.storeys.last.isRoof, isTrue);
      final parapet = project.wallTypes.firstWhere((w) => w.id == 'parapet_12');
      expect(parapet.customHeight, 1.20);
    });

    test('ArchitectProject serialization preserves wallTypes and gridAxes', () {
      final project = ArchitectProject.starterWithCatalog(
        name: 'Serialization Test',
        storeyCount: 2,
      );

      final json = project.toJson();
      final restored = ArchitectProject.fromJson(json);

      expect(restored.id, project.id);
      expect(restored.name, project.name);
      expect(restored.wallTypes.length, project.wallTypes.length);
      expect(restored.gridAxes.length, project.gridAxes.length);
      expect(restored.wallTypes.first.id, project.wallTypes.first.id);
    });

    test('preserves custom units and parametric wall thicknesses', () {
      final customWalls = [
        const ArchitectWallType(
          id: 'ext_25_12_eps',
          name: 'Custom Insulated Wall (43 cm)',
          usage: WallUsage.exterior,
          totalThickness: 0.43,
          brickThickness: 0.28,
          insulationThickness: 0.15,
        ),
        const ArchitectWallType(
          id: 'parapet_12',
          name: 'Custom Parapet 15 cm',
          usage: WallUsage.parapet,
          totalThickness: 0.15,
          customHeight: 1.20,
          parapetFinish: ParapetFinish.handrailPipes,
        ),
      ];

      final project = ArchitectProject.starterWithCatalog(
        name: 'Parametric Units Villa',
        storeyCount: 2,
        units: ArchitectUnit.feet,
        wallTypes: customWalls,
      );

      expect(project.units, ArchitectUnit.feet);
      expect(project.wallTypes.length, 2);
      expect(project.wallTypes.first.totalThickness, closeTo(0.43, 1e-4));
      expect(project.wallTypes.first.brickThickness, closeTo(0.28, 1e-4));
      expect(project.wallTypes.first.insulationThickness, closeTo(0.15, 1e-4));
      expect(project.wallTypes.last.customHeight, 1.20);
      expect(project.wallTypes.last.parapetFinish, ParapetFinish.handrailPipes);

      final json = project.toJson();
      final restored = ArchitectProject.fromJson(json);
      expect(restored.units, ArchitectUnit.feet);
      expect(restored.wallTypes.length, 2);
      expect(restored.wallTypes.first.totalThickness, closeTo(0.43, 1e-4));
    });
  });

  group('ArchitectUnit tests', () {
    test('metric units classification and formatting', () {
      expect(ArchitectUnit.meters.isMetric, isTrue);
      expect(ArchitectUnit.meters.isImperial, isFalse);
      expect(ArchitectUnit.meters.format(3.00), '3.00 m');
      expect(ArchitectUnit.meters.toUnit(3.0), 3.0);
      expect(ArchitectUnit.meters.fromUnit(3.0), 3.0);

      expect(ArchitectUnit.centimeters.isMetric, isTrue);
      expect(ArchitectUnit.centimeters.isImperial, isFalse);
      expect(ArchitectUnit.centimeters.format(0.25), '25 cm');
      expect(ArchitectUnit.centimeters.toUnit(0.25), 25.0);
      expect(ArchitectUnit.centimeters.fromUnit(25.0), closeTo(0.25, 1e-4));

      expect(ArchitectUnit.millimeters.isMetric, isTrue);
      expect(ArchitectUnit.millimeters.isImperial, isFalse);
      expect(ArchitectUnit.millimeters.format(0.25), '250 mm');
      expect(ArchitectUnit.millimeters.toUnit(0.25), 250.0);
      expect(ArchitectUnit.millimeters.fromUnit(250.0), closeTo(0.25, 1e-4));
    });

    test('imperial units classification and formatting', () {
      expect(ArchitectUnit.feet.isImperial, isTrue);
      expect(ArchitectUnit.feet.isMetric, isFalse);
      expect(ArchitectUnit.feet.scaleToMeters, 0.3048);
      expect(ArchitectUnit.feet.symbol, 'ft');
      expect(ArchitectUnit.feet.toUnit(0.3048), closeTo(1.0, 1e-4));
      expect(ArchitectUnit.feet.fromUnit(1.0), closeTo(0.3048, 1e-4));
      expect(ArchitectUnit.feet.format(3.00), '9′ 10 1/8″');

      expect(ArchitectUnit.inches.isImperial, isTrue);
      expect(ArchitectUnit.inches.isMetric, isFalse);
      expect(ArchitectUnit.inches.scaleToMeters, 0.0254);
      expect(ArchitectUnit.inches.symbol, 'in');
      expect(ArchitectUnit.inches.toUnit(0.254), closeTo(10.0, 1e-4));
      expect(ArchitectUnit.inches.fromUnit(10.0), closeTo(0.254, 1e-4));
      expect(ArchitectUnit.inches.format(0.25), '9 13/16 in');
    });
  });
}
