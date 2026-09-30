import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/structural_designer/analysis/cantilever_detector.dart';
import 'package:kotoview/src/features/structural_designer/models/cantilever_analysis_models.dart';
import 'package:kotoview/src/features/structural_designer/models/structural_element.dart';

void main() {
  group('CantileverDetector Tests', () {
    test('Detects linear cantilever overhang', () {
      // Slab 10m x 10m, columns placed at X=0..8, leaving X=8..10 (2.0m cantilever)
      final storey = StoreyLevel(
        id: 'storey_1',
        name: 'Етаж 1',
        columns: const [
          StructuralColumn(id: 'c1', center: Offset(0, 0)),
          StructuralColumn(id: 'c2', center: Offset(0, 10)),
          StructuralColumn(id: 'c3', center: Offset(8, 0)),
          StructuralColumn(id: 'c4', center: Offset(8, 10)),
        ],
        slabs: const [
          StructuralSlab(
            id: 'slab_1',
            polygon: [
              Offset(0, 0),
              Offset(10, 0), // Extends 2.0m past c3
              Offset(10, 10), // Extends 2.0m past c4
              Offset(0, 10),
            ],
            thickness: 0.20,
          ),
        ],
      );

      final zones = CantileverDetector.analyzeStorey(storey: storey);
      expect(zones, isNotEmpty);
      expect(zones.any((z) => z.length >= 1.5), isTrue);
    });

    test('Detects corner double cantilever (Ъглов еркер)', () {
      // Slab corner at (10, 10), but column is inset at (8.5, 8.5)
      // This creates a 1.5m x 1.5m corner overhang with no support
      final storey = StoreyLevel(
        id: 'storey_corner',
        name: 'Етаж 2',
        columns: const [
          StructuralColumn(id: 'c1', center: Offset(0, 0)),
          StructuralColumn(id: 'c2', center: Offset(0, 10)),
          StructuralColumn(id: 'c3', center: Offset(10, 0)),
          StructuralColumn(id: 'c_inset', center: Offset(8.5, 8.5)), // Inset column
        ],
        slabs: const [
          StructuralSlab(
            id: 'slab_corner',
            polygon: [
              Offset(0, 0),
              Offset(10, 0),
              Offset(10, 10), // Unsupported corner!
              Offset(0, 10),
            ],
            thickness: 0.20,
          ),
        ],
      );

      final zones = CantileverDetector.analyzeStorey(storey: storey);
      final cornerZone = zones.firstWhere((z) => z.isCorner);
      expect(cornerZone.type, CantileverType.cornerBiaxial);
      expect(cornerZone.effectiveDiagonal, isNotNull);
      expect(cornerZone.effectiveDiagonal!, greaterThan(1.5));
    });

    test('Detects transfer stacked column on cantilever between storeys', () {
      final storey1 = StoreyLevel(
        id: 's1',
        name: 'Етаж 1',
        columns: const [
          StructuralColumn(id: 's1_c1', center: Offset(0, 0)),
          StructuralColumn(id: 's1_c2', center: Offset(6, 0)),
        ],
        slabs: const [
          StructuralSlab(
            id: 's1_slab',
            polygon: [
              Offset(0, 0),
              Offset(8, 0), // 2m cantilever beyond (6,0)
              Offset(8, 6),
              Offset(0, 6),
            ],
            thickness: 0.20,
          ),
        ],
      );

      final storey2 = StoreyLevel(
        id: 's2',
        name: 'Етаж 2',
        columns: const [
          StructuralColumn(id: 's2_c1', center: Offset(0, 0)),
          StructuralColumn(id: 's2_c2', center: Offset(6, 0)),
          // Column planted on cantilever at X=7.5m!
          StructuralColumn(id: 's2_c_stacked', center: Offset(7.5, 3.0)),
        ],
        slabs: const [
          StructuralSlab(
            id: 's2_slab',
            polygon: [
              Offset(0, 0),
              Offset(8, 0),
              Offset(8, 6),
              Offset(0, 6),
            ],
            thickness: 0.20,
          ),
        ],
      );

      final project = StructuralProject(
        storeys: [storey1, storey2],
        activeStoreyIndex: 1,
      );

      final summary = CantileverDetector.analyzeProject(project);
      expect(summary.transferCantilevers, greaterThan(0));
      final transferZone = summary.zones.firstWhere((z) => z.isTransfer);
      expect(transferZone.riskLevel, CantileverRiskLevel.critical);
      expect(transferZone.stackedColumnId, 's2_c_stacked');
    });
  });
}
