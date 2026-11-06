import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/architect/models/architect_layer.dart';
import 'package:kotoview/src/features/architect/models/architect_project.dart';

void main() {
  group('ArchitectLayer System', () {
    test('ArchitectLayer.defaultLayers has 16 standard layers with standard IDs', () {
      final defaults = ArchitectLayer.defaultLayers();
      expect(defaults.length, 16);

      final ids = defaults.map((l) => l.id).toSet();
      expect(ids.contains(ArchitectLayer.wallLayerId), isTrue);
      expect(ids.contains(ArchitectLayer.doorLayerId), isTrue);
      expect(ids.contains(ArchitectLayer.windowLayerId), isTrue);
      expect(ids.contains(ArchitectLayer.slabLayerId), isTrue);
      expect(ids.contains(ArchitectLayer.roofLayerId), isTrue);
      expect(ids.contains(ArchitectLayer.columnLayerId), isTrue);
      expect(ids.contains(ArchitectLayer.beamLayerId), isTrue);
      expect(ids.contains(ArchitectLayer.stairLayerId), isTrue);
      expect(ids.contains(ArchitectLayer.zoneLayerId), isTrue);
      expect(ids.contains(ArchitectLayer.dimensionLayerId), isTrue);
      expect(ids.contains(ArchitectLayer.textLayerId), isTrue);
      expect(ids.contains(ArchitectLayer.gridLayerId), isTrue);
      expect(ids.contains(ArchitectLayer.hatchLayerId), isTrue);
      expect(ids.contains(ArchitectLayer.cadLayerId), isTrue);
      expect(ids.contains(ArchitectLayer.furnitureLayerId), isTrue);
      expect(ids.contains(ArchitectLayer.drainageLayerId), isTrue);

      for (final l in defaults) {
        expect(l.isStandard, isTrue);
        expect(l.visible, isTrue);
      }
    });

    test('ArchitectProject.effectiveLayers returns defaults if none set', () {
      final project = ArchitectProject.starter(name: 'Test');
      expect(project.effectiveLayers.length, 16);
    });

    test('ArchitectProject resolves default elementLayerId by element type', () {
      final project = ArchitectProject.starter(name: 'Test');

      expect(project.elementLayerId('wall_1', ArchitectLayer.wallLayerId), ArchitectLayer.wallLayerId);
      expect(project.elementLayerId('door_1', ArchitectLayer.doorLayerId), ArchitectLayer.doorLayerId);
      expect(project.elementLayerId('win_1', ArchitectLayer.windowLayerId), ArchitectLayer.windowLayerId);
      expect(project.elementLayerId('hatch_1', ArchitectLayer.hatchLayerId), ArchitectLayer.hatchLayerId);
      expect(project.elementLayerId('line_1', ArchitectLayer.cadLayerId), ArchitectLayer.cadLayerId);
    });

    test('Custom layer assignment overrides default elementLayerId', () {
      final customLayer = const ArchitectLayer(
        id: 'CUSTOM_DEMO',
        name: 'Demolition',
      );
      final project = ArchitectProject.starter(name: 'Test').copyWith(
        layers: [...ArchitectLayer.defaultLayers(), customLayer],
        elementLayers: const {'wall_special': 'CUSTOM_DEMO'},
      );

      expect(project.elementLayerId('wall_special', ArchitectLayer.wallLayerId), 'CUSTOM_DEMO');
    });

    test('isElementVisible respects layer visibility', () {
      // By default, visible
      var project = ArchitectProject.starter(name: 'Test');
      expect(project.isElementVisible('w1', ArchitectLayer.wallLayerId), isTrue);

      // Hide A-WALL layer
      final updatedLayers = project.effectiveLayers.map((l) {
        if (l.id == ArchitectLayer.wallLayerId) return l.copyWith(visible: false);
        return l;
      }).toList();

      project = project.copyWith(layers: updatedLayers);
      expect(project.isElementVisible('w1', ArchitectLayer.wallLayerId), isFalse);
    });

    test('JSON serialization roundtrip preserves custom layers and element assignments', () {
      final customLayer = const ArchitectLayer(
        id: 'CUSTOM_DEMO',
        name: 'Demolition',
        isStandard: false,
        visible: false,
        colorValue: 0xFFFF0000,
      );

      final project = ArchitectProject.starter(name: 'Test').copyWith(
        layers: [...ArchitectLayer.defaultLayers(), customLayer],
        elementLayers: const {'wall_100': 'CUSTOM_DEMO'},
      );

      final json = project.toJson();
      final restored = ArchitectProject.fromJson(json);

      expect(restored.effectiveLayers.any((l) => l.id == 'CUSTOM_DEMO'), isTrue);
      final restoredCustom = restored.effectiveLayers.firstWhere((l) => l.id == 'CUSTOM_DEMO');
      expect(restoredCustom.name, 'Demolition');
      expect(restoredCustom.visible, isFalse);
      expect(restoredCustom.colorValue, 0xFFFF0000);
      expect(restored.elementLayers['wall_100'], 'CUSTOM_DEMO');
    });
  });
}
