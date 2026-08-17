import 'dart:math' as math;

/// Evaluates Excel formulas within a 2D sheet data grid.
class ExcelFormulaEvaluator {
  /// Evaluates a raw formula string (e.g. `=SUM(A1:A10)` or `A1+B1`) given the raw cell values.
  static String evaluate({
    required String formula,
    required dynamic Function(int row, int col) getCellValue,
    required int maxRows,
    required int maxCols,
  }) {
    String cleanFormula = formula.trim();
    if (cleanFormula.startsWith('=')) {
      cleanFormula = cleanFormula.substring(1).trim();
    }
    if (cleanFormula.isEmpty) return '';

    try {
      final result = _evaluateExpression(
        cleanFormula,
        getCellValue,
        maxRows,
        maxCols,
        {},
      );
      if (result == null) return formula;

      if (result is double) {
        if (result.isNaN) return '#VALUE!';
        if (result.isInfinite) return '#DIV/0!';
        if (result == result.roundToDouble()) {
          return result.toInt().toString();
        }
        // Round to clean decimal representation
        final fixed = result.toStringAsFixed(4);
        final trimmed = fixed.replaceAll(RegExp(r'\.?0+$'), '');
        return trimmed;
      }
      return result.toString();
    } catch (_) {
      return formula;
    }
  }

  static dynamic _evaluateExpression(
    String expr,
    dynamic Function(int row, int col) getCellValue,
    int maxRows,
    int maxCols,
    Set<String> visited,
  ) {
    expr = expr.trim();
    if (expr.isEmpty) return null;

    // Check for function calls: FUNC(args)
    final funcMatch = RegExp(r'^([A-Za-z_]+)\((.*)\)$', dotAll: true).firstMatch(expr);
    if (funcMatch != null) {
      final funcName = funcMatch.group(1)!.toUpperCase();
      final innerArgs = funcMatch.group(2)!;
      return _evaluateFunction(funcName, innerArgs, getCellValue, maxRows, maxCols, visited);
    }

    // Check for single cell reference: e.g. A1, $A$1, BC12
    final cellRefMatch = RegExp(r'^\$?([A-Za-z]+)\$?([0-9]+)$').firstMatch(expr);
    if (cellRefMatch != null) {
      final colStr = cellRefMatch.group(1)!.toUpperCase();
      final rowStr = cellRefMatch.group(2)!;
      final col = _columnLetterToIndex(colStr);
      final row = int.parse(rowStr) - 1;

      final key = '$row:$col';
      if (visited.contains(key)) return 0.0; // Prevent circular dependency
      visited.add(key);

      final val = getCellValue(row, col);
      return _parseToNumberOrString(val);
    }

    // Check for plain number
    final numVal = double.tryParse(expr);
    if (numVal != null) return numVal;

    // String literal in quotes: "text"
    if ((expr.startsWith('"') && expr.endsWith('"')) ||
        (expr.startsWith("'") && expr.endsWith("'"))) {
      return expr.substring(1, expr.length - 1);
    }

    // Basic arithmetic (+, -, *, /)
    return _evaluateArithmetic(expr, getCellValue, maxRows, maxCols, visited);
  }

  static dynamic _evaluateFunction(
    String funcName,
    String argsString,
    dynamic Function(int row, int col) getCellValue,
    int maxRows,
    int maxCols,
    Set<String> visited,
  ) {
    final values = _extractFunctionArguments(argsString, getCellValue, maxRows, maxCols, visited);

    switch (funcName) {
      case 'SUM':
        if (values.isEmpty) return 0.0;
        return values.fold<double>(0.0, (sum, v) => sum + _toDouble(v));
      case 'AVERAGE':
      case 'AVG':
        if (values.isEmpty) return 0.0;
        final numValues = values.map(_toDouble).toList();
        final sum = numValues.fold<double>(0.0, (a, b) => a + b);
        return sum / numValues.length;
      case 'MIN':
        if (values.isEmpty) return 0.0;
        return values.map(_toDouble).reduce(math.min);
      case 'MAX':
        if (values.isEmpty) return 0.0;
        return values.map(_toDouble).reduce(math.max);
      case 'COUNT':
        return values.where((v) => _isNumeric(v)).length.toDouble();
      case 'COUNTA':
        return values.where((v) => v != null && v.toString().trim().isNotEmpty).length.toDouble();
      case 'ABS':
        return values.isNotEmpty ? _toDouble(values.first).abs() : 0.0;
      case 'ROUND':
        if (values.isEmpty) return 0.0;
        final val = _toDouble(values[0]);
        final digits = values.length > 1 ? _toDouble(values[1]).toInt() : 0;
        final factor = math.pow(10, digits);
        return (val * factor).round() / factor;
      case 'SQRT':
        if (values.isEmpty) return 0.0;
        final val = _toDouble(values[0]);
        return val >= 0 ? math.sqrt(val) : 0.0;
      case 'IF':
        // IF(condition, value_if_true, value_if_false)
        final rawArgs = _splitTopLevelArgs(argsString);
        if (rawArgs.isEmpty) return '';
        final cond = _evaluateCondition(rawArgs[0], getCellValue, maxRows, maxCols, visited);
        if (cond) {
          return rawArgs.length > 1
              ? _evaluateExpression(rawArgs[1], getCellValue, maxRows, maxCols, visited)
              : true;
        } else {
          return rawArgs.length > 2
              ? _evaluateExpression(rawArgs[2], getCellValue, maxRows, maxCols, visited)
              : false;
        }
      case 'CONCATENATE':
      case 'CONCAT':
        return values.map((v) => v?.toString() ?? '').join();
      default:
        return null;
    }
  }

  static List<dynamic> _extractFunctionArguments(
    String argsString,
    dynamic Function(int row, int col) getCellValue,
    int maxRows,
    int maxCols,
    Set<String> visited,
  ) {
    final List<dynamic> results = [];
    final args = _splitTopLevelArgs(argsString);

    for (final arg in args) {
      final trimmed = arg.trim();
      // Check for cell range: e.g. A1:B10
      final rangeMatch = RegExp(r'^\$?([A-Za-z]+)\$?([0-9]+):\$?([A-Za-z]+)\$?([0-9]+)$').firstMatch(trimmed);
      if (rangeMatch != null) {
        final startCol = _columnLetterToIndex(rangeMatch.group(1)!.toUpperCase());
        final startRow = int.parse(rangeMatch.group(2)!) - 1;
        final endCol = _columnLetterToIndex(rangeMatch.group(3)!.toUpperCase());
        final endRow = int.parse(rangeMatch.group(4)!) - 1;

        final minR = math.min(startRow, endRow);
        final maxR = math.max(startRow, endRow);
        final minC = math.min(startCol, endCol);
        final maxC = math.max(startCol, endCol);

        for (int r = minR; r <= maxR; r++) {
          for (int c = minC; c <= maxC; c++) {
            final val = getCellValue(r, c);
            if (val != null) {
              final parsed = _parseToNumberOrString(val);
              if (parsed != null) results.add(parsed);
            }
          }
        }
      } else {
        final val = _evaluateExpression(trimmed, getCellValue, maxRows, maxCols, visited);
        if (val != null) results.add(val);
      }
    }
    return results;
  }

  static List<String> _splitTopLevelArgs(String str) {
    final List<String> args = [];
    int depth = 0;
    int start = 0;

    for (int i = 0; i < str.length; i++) {
      final char = str[i];
      if (char == '(') {
        depth++;
      } else if (char == ')') {
        depth--;
      } else if ((char == ',' || char == ';') && depth == 0) {
        args.add(str.substring(start, i).trim());
        start = i + 1;
      }
    }
    if (start < str.length) {
      args.add(str.substring(start).trim());
    }
    return args;
  }

  static bool _evaluateCondition(
    String condStr,
    dynamic Function(int row, int col) getCellValue,
    int maxRows,
    int maxCols,
    Set<String> visited,
  ) {
    for (final op in ['>=', '<=', '<>', '!=', '>', '<', '=']) {
      if (condStr.contains(op)) {
        final parts = condStr.split(op);
        if (parts.length == 2) {
          final left = _evaluateExpression(parts[0], getCellValue, maxRows, maxCols, visited);
          final right = _evaluateExpression(parts[1], getCellValue, maxRows, maxCols, visited);

          final lNum = _toDouble(left);
          final rNum = _toDouble(right);

          switch (op) {
            case '>=': return lNum >= rNum;
            case '<=': return lNum <= rNum;
            case '>': return lNum > rNum;
            case '<': return lNum < rNum;
            case '<>':
            case '!=': return left != right;
            case '=': return left == right || lNum == rNum;
          }
        }
      }
    }
    final val = _evaluateExpression(condStr, getCellValue, maxRows, maxCols, visited);
    return val == true || (val is num && val != 0);
  }

  static dynamic _evaluateArithmetic(
    String expr,
    dynamic Function(int row, int col) getCellValue,
    int maxRows,
    int maxCols,
    Set<String> visited,
  ) {
    // Handle string concatenation operator '&'
    if (expr.contains('&')) {
      final parts = _splitByOperator(expr, '&');
      if (parts.length > 1) {
        final evaluatedParts = parts.map((p) => _evaluateExpression(p, getCellValue, maxRows, maxCols, visited)?.toString() ?? '').join();
        return evaluatedParts;
      }
    }

    // Split on + or - outside parentheses
    final addSubParts = _splitByTopLevelOperators(expr, ['+', '-']);
    if (addSubParts.length > 1) {
      double total = 0.0;
      for (final part in addSubParts) {
        final sign = part.operator == '-' ? -1.0 : 1.0;
        final val = _evaluateExpression(part.expression, getCellValue, maxRows, maxCols, visited);
        total += sign * _toDouble(val);
      }
      return total;
    }

    // Split on * or / outside parentheses
    final mulDivParts = _splitByTopLevelOperators(expr, ['*', '/']);
    if (mulDivParts.length > 1) {
      double total = 1.0;
      for (int i = 0; i < mulDivParts.length; i++) {
        final part = mulDivParts[i];
        final val = _toDouble(_evaluateExpression(part.expression, getCellValue, maxRows, maxCols, visited));
        if (i == 0) {
          total = val;
        } else if (part.operator == '/') {
          if (val == 0) return double.infinity;
          total /= val;
        } else {
          total *= val;
        }
      }
      return total;
    }

    return null;
  }

  static List<_OpPart> _splitByTopLevelOperators(String expr, List<String> ops) {
    final List<_OpPart> parts = [];
    int depth = 0;
    int start = 0;
    String currentOp = '+';

    for (int i = 0; i < expr.length; i++) {
      final char = expr[i];
      if (char == '(') {
        depth++;
      } else if (char == ')') {
        depth--;
      } else if (depth == 0 && i > 0 && ops.contains(char)) {
        parts.add(_OpPart(currentOp, expr.substring(start, i).trim()));
        currentOp = char;
        start = i + 1;
      }
    }
    if (start < expr.length) {
      parts.add(_OpPart(currentOp, expr.substring(start).trim()));
    }
    return parts;
  }

  static List<String> _splitByOperator(String expr, String op) {
    final List<String> parts = [];
    int depth = 0;
    int start = 0;

    for (int i = 0; i < expr.length; i++) {
      final char = expr[i];
      if (char == '(') {
        depth++;
      } else if (char == ')') {
        depth--;
      } else if (depth == 0 && char == op) {
        parts.add(expr.substring(start, i).trim());
        start = i + 1;
      }
    }
    if (start < expr.length) {
      parts.add(expr.substring(start).trim());
    }
    return parts;
  }

  static int _columnLetterToIndex(String colStr) {
    int index = 0;
    for (int i = 0; i < colStr.length; i++) {
      index = index * 26 + (colStr.codeUnitAt(i) - 64);
    }
    return index - 1;
  }

  static dynamic _parseToNumberOrString(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    final str = val.toString().trim();
    final numVal = double.tryParse(str);
    if (numVal != null) return numVal;
    return str;
  }

  static double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    final str = val.toString().trim();
    return double.tryParse(str) ?? 0.0;
  }

  static bool _isNumeric(dynamic val) {
    if (val is num) return true;
    if (val == null) return false;
    return double.tryParse(val.toString().trim()) != null;
  }
}

class _OpPart {
  final String operator;
  final String expression;
  _OpPart(this.operator, this.expression);
}
