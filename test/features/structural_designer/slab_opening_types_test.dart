import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';

void main() {
  group('SlabOpeningType & Typed Openings in StructuralSlab', () {
    test('1. Default opening type is shaft when not specified', () {
      final slab = StructuralSlab(
        id: 'slab_1',
        polygon: const [
          Offset(0, 0),
          Offset(10, 0),
          Offset(10, 10),
          Offset(0, 10),
        ],
        openings: const [
          [Offset(1, 1), Offset(2, 1), Offset(2, 2), Offset(1, 2)],
        ],
      );

      expect(slab.openings.length, 1);
      expect(slab.getOpeningType(0), SlabOpeningType.shaft);
      expect(slab.typedOpenings.first.type, SlabOpeningType.shaft);
      expect(slab.typedOpenings.first.defaultCode, 'Щ');
    });

    test('2. Adding typed openings (shaft, staircase, elevator, custom)', () {
      var slab = const StructuralSlab(
        id: 'slab_1',
        polygon: [
          Offset(0, 0),
          Offset(20, 0),
          Offset(20, 20),
          Offset(0, 20),
        ],
      );

      // Add shaft
      slab = slab.addOpening(
        const [Offset(1, 1), Offset(1.4, 1), Offset(1.4, 1.6), Offset(1, 1.6)],
        type: SlabOpeningType.shaft,
      );

      // Add staircase
      slab = slab.addOpening(
        const [Offset(4, 4), Offset(6.4, 4), Offset(6.4, 8.5), Offset(4, 8.5)],
        type: SlabOpeningType.staircase,
      );

      // Add elevator
      slab = slab.addOpening(
        const [Offset(10, 10), Offset(11.8, 10), Offset(11.8, 12.0), Offset(10, 12.0)],
        type: SlabOpeningType.elevator,
      );

      // Add custom
      slab = slab.addOpening(
        const [Offset(15, 15), Offset(17, 15), Offset(17, 17), Offset(15, 17)],
        type: SlabOpeningType.custom,
      );

      expect(slab.openings.length, 4);
      expect(slab.getOpeningType(0), SlabOpeningType.shaft);
      expect(slab.getOpeningType(1), SlabOpeningType.staircase);
      expect(slab.getOpeningType(2), SlabOpeningType.elevator);
      expect(slab.getOpeningType(3), SlabOpeningType.custom);

      final typed = slab.typedOpenings;
      expect(typed[0].defaultCode, 'Щ');
      expect(typed[1].defaultCode, 'СТ');
      expect(typed[2].defaultCode, 'АС');
      expect(typed[3].defaultCode, 'ОТ');
    });

    test('3. Updating and cycling opening type preserves geometry', () {
      var slab = const StructuralSlab(
        id: 'slab_1',
        polygon: [
          Offset(0, 0),
          Offset(20, 0),
          Offset(20, 20),
          Offset(0, 20),
        ],
      );

      slab = slab.addOpening(
        const [Offset(2, 2), Offset(4, 2), Offset(4, 4), Offset(2, 4)],
        type: SlabOpeningType.shaft,
      );
      expect(slab.getOpeningType(0), SlabOpeningType.shaft);

      // Update type to elevator
      slab = slab.updateOpeningType(0, SlabOpeningType.elevator);
      expect(slab.getOpeningType(0), SlabOpeningType.elevator);
      expect(slab.openings[0].length, 4);

      // Update geometry while keeping type
      slab = slab.updateOpening(0, const [
        Offset(2, 2),
        Offset(5, 2),
        Offset(5, 5),
        Offset(2, 5),
      ]);
      expect(slab.getOpeningType(0), SlabOpeningType.elevator);
      expect(slab.openings[0][1], const Offset(5, 2));

      // Remove opening
      slab = slab.removeOpening(0);
      expect(slab.openings.isEmpty, true);
      expect(slab.typedOpenings.isEmpty, true);
    });

    test('4. JSON serialization roundtrip preserves opening types and supports legacy JSON', () {
      final original = StructuralSlab(
        id: 'slab_json',
        polygon: const [Offset(0, 0), Offset(10, 0), Offset(10, 10), Offset(0, 10)],
        openings: const [
          [Offset(1, 1), Offset(2, 1), Offset(2, 2), Offset(1, 2)],
          [Offset(5, 5), Offset(7, 5), Offset(7, 8), Offset(5, 8)],
        ],
        openingTypes: const [
          SlabOpeningType.shaft,
          SlabOpeningType.elevator,
        ],
      );

      final json = original.toJson();
      expect(json['openingTypes'], ['shaft', 'elevator']);

      final restored = StructuralSlab.fromJson(json);
      expect(restored.openings.length, 2);
      expect(restored.getOpeningType(0), SlabOpeningType.shaft);
      expect(restored.getOpeningType(1), SlabOpeningType.elevator);

      // Legacy JSON without openingTypes
      final legacyJson = {
        'id': 'slab_legacy',
        'polygon': [
          {'dx': 0.0, 'dy': 0.0},
          {'dx': 10.0, 'dy': 0.0},
          {'dx': 10.0, 'dy': 10.0},
          {'dx': 0.0, 'dy': 10.0},
        ],
        'openings': [
          [
            {'dx': 1.0, 'dy': 1.0},
            {'dx': 2.0, 'dy': 1.0},
            {'dx': 2.0, 'dy': 2.0},
            {'dx': 1.0, 'dy': 2.0},
          ]
        ],
      };

      final legacyRestored = StructuralSlab.fromJson(legacyJson);
      expect(legacyRestored.openings.length, 1);
      expect(legacyRestored.getOpeningType(0), SlabOpeningType.shaft);
    });
  });
}
