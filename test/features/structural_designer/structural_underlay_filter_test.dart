import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/dxf_viewer/models/dxf_models.dart';
import 'package:kotoview/src/features/structural_designer/analysis/structural_underlay_filter.dart';

void main() {
  group('StructuralUnderlayFilter Tests', () {
    test('1. Isolates the thickest White layer and hides all other layers', () {
      final layers = [
        DxfLayer(name: 'WALLS_MAIN', colorIndex: 7, lineweight: 0.50), // White, thickest (0.50mm)
        DxfLayer(name: 'DETAILS_THIN', colorIndex: 7, lineweight: 0.18), // White, thin (0.18mm)
        DxfLayer(name: 'DOORS', colorIndex: 1, lineweight: 0.50), // Red, 0.50mm (non-white)
        DxfLayer(name: 'DIMENSIONS', colorIndex: 2, lineweight: 0.25), // Yellow, 0.25mm
        DxfLayer(name: 'FURNITURE', colorIndex: 3, lineweight: 0.18), // Green, 0.18mm
      ];

      final visible = StructuralUnderlayFilter.filterLayers(layers: layers);

      expect(visible, equals({'WALLS_MAIN'}));
    });

    test('2. Multiple White layers sharing the maximum thickness all remain visible', () {
      final layers = [
        DxfLayer(name: 'EXT_WALLS', colorIndex: 7, lineweight: 0.70), // White, 0.70mm
        DxfLayer(name: 'CORE_WALLS', colorIndex: 7, lineweight: 0.70), // White, 0.70mm
        DxfLayer(name: 'HATCHING', colorIndex: 7, lineweight: 0.13), // White, 0.13mm
        DxfLayer(name: 'TEXT_LAYER', colorIndex: 4, lineweight: 0.70), // Cyan, 0.70mm
      ];

      final visible = StructuralUnderlayFilter.filterLayers(layers: layers);

      expect(visible, equals({'EXT_WALLS', 'CORE_WALLS'}));
    });

    test('3. When lines have NO thickness (null or 0), all White layers remain and non-white hide', () {
      final layers = [
        DxfLayer(name: 'COLUMNS', colorIndex: 7), // White, no lineweight
        DxfLayer(name: 'WALLS', colorIndex: 7), // White, no lineweight
        DxfLayer(name: 'DOORS', colorIndex: 1), // Red, no lineweight
        DxfLayer(name: 'FURNITURE', colorIndex: 2), // Yellow, no lineweight
        DxfLayer(name: 'ELECTRICAL', colorIndex: 4), // Cyan, no lineweight
      ];

      final visible = StructuralUnderlayFilter.filterLayers(layers: layers);

      expect(visible, equals({'COLUMNS', 'WALLS'}));
    });

    test('4. When lines have NO thickness, excludes obvious negative clutter layers', () {
      final layers = [
        DxfLayer(name: 'WALLS_PLAN', colorIndex: 7), // White, no lineweight
        DxfLayer(name: 'HATCH_PATTERN', colorIndex: 7), // White, negative keyword
        DxfLayer(name: 'DIM_LEVELS', colorIndex: 7), // White, negative keyword
        DxfLayer(name: 'DOORS_RED', colorIndex: 1), // Red
      ];

      final visible = StructuralUnderlayFilter.filterLayers(layers: layers);

      expect(visible, equals({'WALLS_PLAN'}));
    });

    test('5. When NO White layers exist, filters slabs/structural elements and ignores wall keywords', () {
      final layers = [
        DxfLayer(name: 'A-WALL-EXTR', colorIndex: 1), // Red, 'wall' - no longer detected by keyword!
        DxfLayer(name: 'PLOCHA_ET0', colorIndex: 4), // Cyan, 'plocha' - structural slab
        DxfLayer(name: 'STENA_BETON', colorIndex: 3), // Green, 'stena' - no longer detected by keyword!
        DxfLayer(name: 'DOORS_SWING', colorIndex: 2), // Yellow, 'door' -> negative
        DxfLayer(name: 'FURNITURE_OFFICE', colorIndex: 5), // Blue, 'furn' -> negative
      ];

      final visible = StructuralUnderlayFilter.filterLayers(layers: layers);

      // Walls are no longer detected by hardcoded keywords ('wall', 'stena'); only structural slabs/elements remain
      expect(visible, equals({'PLOCHA_ET0'}));
    });

    test('6. Supports Bulgarian Cyrillic structural keywords (плоча, колона) without hardcoded wall keywords', () {
      final layers = [
        DxfLayer(name: 'Стени_носещи', colorIndex: 2), // Yellow, 'стени' - not matched by keyword
        DxfLayer(name: 'Стоманобетонна_плоча', colorIndex: 1), // Red, 'плоча' - matched
        DxfLayer(name: 'Колони_стб', colorIndex: 3), // Green, 'колони' - matched
        DxfLayer(name: 'Размери_коти', colorIndex: 4), // Cyan, negative 'размер'
        DxfLayer(name: 'Текст_описания', colorIndex: 5), // Blue, negative 'текст'
      ];

      final visible = StructuralUnderlayFilter.filterLayers(layers: layers);

      expect(visible, equals({'Стоманобетонна_плоча', 'Колони_стб'}));
    });

    test('7. Recognizes TrueColor White (0x00FFFFFF or RGB >= 220) with thickness', () {
      final layers = [
        DxfLayer(name: 'TC_WALLS', colorIndex: 1, trueColor: 0x00FFFFFF, lineweight: 0.50), // Pure white TrueColor
        DxfLayer(name: 'TC_THIN_WHITE', colorIndex: 1, trueColor: 0x00F0F0F0, lineweight: 0.18), // Near-white TrueColor
        DxfLayer(name: 'TC_BLUE_WALL', colorIndex: 5, trueColor: 0x000000FF, lineweight: 0.50), // Pure blue TrueColor
      ];

      final visible = StructuralUnderlayFilter.filterLayers(layers: layers);

      expect(visible, equals({'TC_WALLS'}));
    });

    test('8. Recognizes entity-level lineweights and colors when layers lack them', () {
      final layerWalls = DxfLayer(name: 'ANON_LAYER_1', colorIndex: 7); // White, lineweight null
      final layerThin = DxfLayer(name: 'ANON_LAYER_2', colorIndex: 7); // White, lineweight null

      final entities = [
        const DxfLine(
          layer: 'ANON_LAYER_1',
          p1: Offset(0, 0),
          p2: Offset(10, 0),
          lineWeight: 0.60, // Entity has 0.60mm thickness
        ),
        const DxfLine(
          layer: 'ANON_LAYER_2',
          p1: Offset(0, 0),
          p2: Offset(5, 0),
          lineWeight: 0.15, // Entity has 0.15mm thickness
        ),
      ];

      final visible = StructuralUnderlayFilter.filterLayers(
        layers: [layerWalls, layerThin],
        entities: entities,
      );

      expect(visible, equals({'ANON_LAYER_1'}));
    });

    test('9. Returns empty set when no layers match, preventing UI blankout', () {
      final layers = [
        DxfLayer(name: 'FURNITURE', colorIndex: 2), // Yellow, non-white, negative
        DxfLayer(name: 'DIMENSIONS', colorIndex: 1), // Red, non-white, negative
      ];

      final visible = StructuralUnderlayFilter.filterLayers(layers: layers);

      expect(visible, isEmpty);
    });

    test('10. Excludes empty layer 0 and DEFPOINTS, selecting real structural slab layers', () {
      final layers = [
        DxfLayer(name: '0', colorIndex: 7), // Empty layer 0
        DxfLayer(name: 'DEFPOINTS', colorIndex: 7), // Empty DEFPOINTS
        DxfLayer(name: 'SLAB_FOUNDATION', colorIndex: 1, lineweight: 0.35), // Red slab with entities
        DxfLayer(name: 'DOORS', colorIndex: 2),
      ];

      final entities = [
        const DxfLine(layer: 'SLAB_FOUNDATION', p1: Offset(0, 0), p2: Offset(10, 0)),
        const DxfLine(layer: 'SLAB_FOUNDATION', p1: Offset(10, 0), p2: Offset(10, 10)),
        const DxfLine(layer: 'DOORS', p1: Offset(2, 0), p2: Offset(4, 0)),
      ];

      final visible = StructuralUnderlayFilter.filterLayers(
        layers: layers,
        entities: entities,
      );

      // '0' and 'DEFPOINTS' have 0 entities and are ignored; 'SLAB_FOUNDATION' is correctly selected!
      expect(visible, equals({'SLAB_FOUNDATION'}));
    });

    test('11. Counts entities inside blocks and includes structural block layers', () {
      final layers = [
        DxfLayer(name: '0', colorIndex: 7),
        DxfLayer(name: 'A-SLAB', colorIndex: 4, lineweight: 0.50), // Cyan slab inside block
      ];

      final blocks = {
        'SLAB_BLOCK': DxfBlock(
          name: 'SLAB_BLOCK',
          basePoint: Offset.zero,
          entities: [
            const DxfLine(layer: 'A-SLAB', p1: Offset(0, 0), p2: Offset(5, 0)),
          ],
        ),
      };

      final visible = StructuralUnderlayFilter.filterLayers(
        layers: layers,
        blocks: blocks,
      );

      expect(visible, equals({'A-SLAB'}));
    });

    test('12. Preserves 12 cm walls with same white color as 25 cm walls in a separate layer', () {
      final layers = [
        DxfLayer(name: 'WALLS_25', colorIndex: 7, lineweight: 0.50), // White, 25cm exterior/bearing
        DxfLayer(name: 'WALLS_12', colorIndex: 7, lineweight: 0.25), // White, 12cm interior partition
        DxfLayer(name: 'FURNITURE', colorIndex: 7, lineweight: 0.13), // White, clutter
        DxfLayer(name: 'DOORS', colorIndex: 1, lineweight: 0.50), // Red
      ];

      final visible = StructuralUnderlayFilter.filterLayers(layers: layers);

      // Both 25cm and 12cm walls stay visible, thin clutter and doors hidden
      expect(visible, equals({'WALLS_25', 'WALLS_12'}));
    });

    test('13. Preserves Bulgarian partition walls (Преградни) alongside 25cm walls by lineweight without keyword reliance', () {
      final layers = [
        DxfLayer(name: 'Стени_25см', colorIndex: 7, lineweight: 0.50), // White 25cm
        DxfLayer(name: 'Преградни_стени_12', colorIndex: 7, lineweight: 0.25), // White 12cm
        DxfLayer(name: 'Зидария_12', colorIndex: 2, lineweight: 0.25), // Non-white without geometry - not matched by word
        DxfLayer(name: 'Щрих_штрих', colorIndex: 7, lineweight: 0.13), // Hatch
      ];

      final visible = StructuralUnderlayFilter.filterLayers(layers: layers);

      expect(visible.contains('Стени_25см'), isTrue);
      expect(visible.contains('Преградни_стени_12'), isTrue);
      // Non-white layer without geometry is not selected simply because it has 'Зидария' or '12' in its name
      expect(visible.contains('Зидария_12'), isFalse);
      expect(visible.contains('Щрих_штрих'), isFalse);
    });

    test('14. Preserves thickest white layers and 12cm walls without requiring wall keywords (no rigid keyword filtering)', () {
      // Layers named arbitrarily by CAD drafter (e.g. A-GEN-01, AR_MASONRY) without the word "wall" or "стена"
      final layers = [
        DxfLayer(name: 'LAYER_HEAVY', colorIndex: 7, lineweight: 0.50), // White, thickest (25cm)
        DxfLayer(name: 'LAYER_MEDIUM', colorIndex: 7, lineweight: 0.25), // White, medium (12cm)
        DxfLayer(name: 'LAYER_THIN', colorIndex: 7, lineweight: 0.09), // White, thin
        DxfLayer(name: 'LAYER_RED', colorIndex: 1, lineweight: 0.50), // Non-white
      ];

      final visible = StructuralUnderlayFilter.filterLayers(layers: layers);

      // Heavy and medium white layers are preserved unconditionally
      expect(visible.contains('LAYER_HEAVY'), isTrue);
      expect(visible.contains('LAYER_MEDIUM'), isTrue);
      expect(visible.contains('LAYER_THIN'), isFalse);
      expect(visible.contains('LAYER_RED'), isFalse);
    });

    test('15. matchesSlabKeyword correctly matches English, Cyrillic, and Latinized Bulgarian slab keywords', () {
      expect(StructuralUnderlayFilter.matchesSlabKeyword('SLAB'), isTrue);
      expect(StructuralUnderlayFilter.matchesSlabKeyword('Slabs_Level1'), isTrue);
      expect(StructuralUnderlayFilter.matchesSlabKeyword('КОТА_ПЛОЧА'), isTrue);
      expect(StructuralUnderlayFilter.matchesSlabKeyword('Плочи_кота_0'), isTrue);
      expect(StructuralUnderlayFilter.matchesSlabKeyword('AR_PLOCHA'), isTrue);
      expect(StructuralUnderlayFilter.matchesSlabKeyword('ploca_etaj1'), isTrue);
      expect(StructuralUnderlayFilter.matchesSlabKeyword('furniture_slab'), isFalse); // clutter keyword
      expect(StructuralUnderlayFilter.matchesSlabKeyword('random_layer'), isFalse);
    });

    test('16. detectSlabLayers separates non-empty slab layers from empty slab layers', () {
      final doc = DxfDocument(
        layers: {
          'SLAB_MAIN': DxfLayer(name: 'SLAB_MAIN', colorIndex: 3),
          'ПЛОЧА_EMPTY': DxfLayer(name: 'ПЛОЧА_EMPTY', colorIndex: 3),
          'WALLS': DxfLayer(name: 'WALLS', colorIndex: 7),
        },
        blocks: const {},
        entities: [
          DxfLine(p1: const Offset(0, 0), p2: const Offset(10, 0), layer: 'SLAB_MAIN'),
          DxfLine(p1: const Offset(0, 0), p2: const Offset(10, 0), layer: 'WALLS'),
        ],
        headerVars: const {},
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        entityStats: const {},
      );

      final result = StructuralUnderlayFilter.detectSlabLayers(doc);

      expect(result.foundAny, isTrue);
      expect(result.hasValidLayers, isTrue);
      expect(result.detectedLayers, equals(['SLAB_MAIN']));
      expect(result.emptyLayers, equals(['ПЛОЧА_EMPTY']));

      // Empty document test
      final emptyDoc = DxfDocument(
        layers: {
          'WALLS': DxfLayer(name: 'WALLS', colorIndex: 7),
        },
        blocks: const {},
        entities: const [],
        headerVars: const {},
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        entityStats: const {},
      );
      final emptyResult = StructuralUnderlayFilter.detectSlabLayers(emptyDoc);
      expect(emptyResult.foundAny, isFalse);
      expect(emptyResult.hasValidLayers, isFalse);
      expect(emptyResult.detectedLayers, isEmpty);
      expect(emptyResult.emptyLayers, isEmpty);
    });

    test('17. Slab layers are included in filterLayers alongside white wall layers', () {
      final layers = [
        DxfLayer(name: 'WALLS_250', colorIndex: 7, lineweight: 0.50),
        DxfLayer(name: 'SLAB_OUTLINE', colorIndex: 4, lineweight: 0.25), // Cyan slab layer
        DxfLayer(name: 'DOORS', colorIndex: 1, lineweight: 0.25),
      ];

      final visible = StructuralUnderlayFilter.filterLayers(layers: layers);
      expect(visible.contains('WALLS_250'), isTrue);
      expect(visible.contains('SLAB_OUTLINE'), isTrue);
      expect(visible.contains('DOORS'), isFalse);
    });
  });
}
