import 'package:flutter_test/flutter_test.dart';
import 'package:kotoview/src/features/xlsx_viewer/excel_formula_evaluator.dart';

void main() {
  group('ExcelFormulaEvaluator Tests', () {
    final grid = <int, Map<int, dynamic>>{
      0: {0: 10, 1: 20, 2: 30}, // A1=10, B1=20, C1=30
      1: {0: 5, 1: 15, 2: 25},  // A2=5, B2=15, C2=25
      2: {0: 100, 1: 'Koto', 2: 0},
    };

    dynamic getCell(int r, int c) {
      return grid[r]?[c];
    }

    test('evaluates SUM with range', () {
      final res = ExcelFormulaEvaluator.evaluate(
        formula: '=SUM(A1:C1)',
        getCellValue: getCell,
        maxRows: 3,
        maxCols: 3,
      );
      expect(res, '60');
    });

    test('evaluates SUM with 2D range', () {
      final res = ExcelFormulaEvaluator.evaluate(
        formula: 'SUM(A1:B2)',
        getCellValue: getCell,
        maxRows: 3,
        maxCols: 3,
      );
      expect(res, '50'); // 10 + 20 + 5 + 15 = 50
    });

    test('evaluates AVERAGE', () {
      final res = ExcelFormulaEvaluator.evaluate(
        formula: '=AVERAGE(A1:C1)',
        getCellValue: getCell,
        maxRows: 3,
        maxCols: 3,
      );
      expect(res, '20'); // (10+20+30)/3 = 20
    });

    test('evaluates MIN and MAX', () {
      final minRes = ExcelFormulaEvaluator.evaluate(
        formula: '=MIN(A1:C2)',
        getCellValue: getCell,
        maxRows: 3,
        maxCols: 3,
      );
      expect(minRes, '5');

      final maxRes = ExcelFormulaEvaluator.evaluate(
        formula: '=MAX(A1:C2)',
        getCellValue: getCell,
        maxRows: 3,
        maxCols: 3,
      );
      expect(maxRes, '30');
    });

    test('evaluates basic arithmetic expressions', () {
      final addRes = ExcelFormulaEvaluator.evaluate(
        formula: '=A1 + B1',
        getCellValue: getCell,
        maxRows: 3,
        maxCols: 3,
      );
      expect(addRes, '30');

      final mulRes = ExcelFormulaEvaluator.evaluate(
        formula: '=A1 * A2',
        getCellValue: getCell,
        maxRows: 3,
        maxCols: 3,
      );
      expect(mulRes, '50');
    });

    test('evaluates IF condition', () {
      final ifTrue = ExcelFormulaEvaluator.evaluate(
        formula: '=IF(A1 > 5, "Large", "Small")',
        getCellValue: getCell,
        maxRows: 3,
        maxCols: 3,
      );
      expect(ifTrue, 'Large');

      final ifFalse = ExcelFormulaEvaluator.evaluate(
        formula: '=IF(A2 > 10, "Large", "Small")',
        getCellValue: getCell,
        maxRows: 3,
        maxCols: 3,
      );
      expect(ifFalse, 'Small');
    });

    test('evaluates direct cell reference', () {
      final ref = ExcelFormulaEvaluator.evaluate(
        formula: '=A1',
        getCellValue: getCell,
        maxRows: 3,
        maxCols: 3,
      );
      expect(ref, '10');
    });
  });
}
