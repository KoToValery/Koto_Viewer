import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/structural_designer/analysis/deflection_calculator.dart';
import 'package:kotoview/src/features/structural_designer/models/cantilever_analysis_models.dart';

void main() {
  group('DeflectionCalculator Tests', () {
    test('Linear Cantilever evaluation within limits', () {
      final zone = DeflectionCalculator.evaluateCantilever(
        id: 'test_linear_1',
        type: CantileverType.linear,
        storeyName: 'Етаж 1',
        supportEdgeStart: const Offset(0, 0),
        supportEdgeEnd: const Offset(0, 5),
        overhangTip: const Offset(1.0, 2.5),
        length: 1.0, // 1.0m overhang
        slabThickness: 0.20, // 20cm thickness -> L/h = 5.0 <= 7
      );

      expect(zone.type, CantileverType.linear);
      expect(zone.slendernessRatio, closeTo(5.0, 0.01));
      expect(zone.riskLevel, CantileverRiskLevel.safe);
      expect(zone.limitDeflectionMm, closeTo(4.0, 0.01)); // 1000 / 250 = 4.0 mm
      expect(zone.longTermDeflectionMm, greaterThan(0.0));
      expect(zone.longTermDeflectionMm, lessThan(zone.limitDeflectionMm));
    });

    test('Double Corner Cantilever (Ъглов еркер) with torsional amplification', () {
      final cornerZone = DeflectionCalculator.evaluateCantilever(
        id: 'test_corner_1',
        type: CantileverType.cornerBiaxial,
        storeyName: 'Етаж 2',
        supportEdgeStart: const Offset(8.5, 8.5),
        supportEdgeEnd: const Offset(10.0, 8.5),
        overhangTip: const Offset(10.0, 10.0),
        length: 1.5, // Lx = 1.5m
        lengthY: 1.5, // Ly = 1.5m
        slabThickness: 0.20, // 20cm
      );

      expect(cornerZone.type, CantileverType.cornerBiaxial);
      expect(cornerZone.isCorner, isTrue);
      // Diagonal reach: sqrt(1.5^2 + 1.5^2) = ~2.121 m
      expect(cornerZone.effectiveDiagonal!, closeTo(2.121, 0.01));
      // Slenderness based on diagonal: 2.121 / 0.20 = ~10.6 -> Critical (>10)
      expect(cornerZone.slendernessRatio, greaterThan(10.0));
      expect(cornerZone.riskLevel, CantileverRiskLevel.critical);
      expect(cornerZone.recommendations, isNotEmpty);
    });

    test('Stacked Transfer Cantilever (Колона върху еркер) is Critical', () {
      final transferZone = DeflectionCalculator.evaluateCantilever(
        id: 'test_transfer_1',
        type: CantileverType.transferStacked,
        storeyName: 'Етаж 3',
        supportEdgeStart: const Offset(0, 0),
        supportEdgeEnd: const Offset(0, 0),
        overhangTip: const Offset(1.2, 0),
        length: 1.2,
        slabThickness: 0.20,
        stackedColumnLoadKn: 150.0, // 150 kN column from upper floor
        stackedColumnId: 'col_upper_1',
      );

      expect(transferZone.type, CantileverType.transferStacked);
      expect(transferZone.isTransfer, isTrue);
      expect(transferZone.riskLevel, CantileverRiskLevel.critical);
      expect(transferZone.recommendations.any((r) => r.contains('Засадена колона')), isTrue);
    });
  });
}
