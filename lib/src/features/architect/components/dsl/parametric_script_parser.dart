// === SECTION: PARAMETRIC SCRIPT PARSER & DYNAMIC COMPONENT DEFINITION ===
// Table of Contents:
// 1. SIMPLE MATH EXPRESSION EVALUATOR
// 2. DYNAMIC SCRIPTED DEFINITION (ScriptedComponentDefinition)
// 3. PARAMETRIC SCRIPT PARSER (ParametricScriptParser)

import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/architect_component.dart';
import '../../models/architect_component_definition.dart';

// ===========================================================================
// 1. SIMPLE MATH EXPRESSION EVALUATOR
// ===========================================================================

/// Evaluates simple arithmetic expressions containing variables like 'width', 'depth', 'height'.
class SimpleMathEvaluator {
  static double evaluate(dynamic expr, Map<String, double> vars) {
    if (expr is num) return expr.toDouble();
    if (expr is! String) return 0.0;
    var str = expr.trim();
    if (str.isEmpty) return 0.0;

    // Direct variable lookup
    if (vars.containsKey(str)) return vars[str]!;
    final directNum = double.tryParse(str);
    if (directNum != null) return directNum;

    // Substitute variable names with their numeric values
    for (final entry in vars.entries) {
      str = str.replaceAll(entry.key, entry.value.toString());
    }

    try {
      return _evaluateTokens(str);
    } catch (_) {
      return 0.0;
    }
  }

  static double _evaluateTokens(String expr) {
    // Basic addition and subtraction splitter
    final addParts = _splitByTopLevelOp(expr, '+');
    if (addParts.length > 1) {
      return addParts.map(_evaluateTokens).reduce((a, b) => a + b);
    }

    final subParts = _splitByTopLevelOp(expr, '-');
    if (subParts.length > 1) {
      var result = _evaluateTokens(subParts[0]);
      for (var i = 1; i < subParts.length; i++) {
        result -= _evaluateTokens(subParts[i]);
      }
      return result;
    }

    final mulParts = _splitByTopLevelOp(expr, '*');
    if (mulParts.length > 1) {
      return mulParts.map(_evaluateTokens).reduce((a, b) => a * b);
    }

    final divParts = _splitByTopLevelOp(expr, '/');
    if (divParts.length > 1) {
      var result = _evaluateTokens(divParts[0]);
      for (var i = 1; i < divParts.length; i++) {
        final divisor = _evaluateTokens(divParts[i]);
        result = divisor.abs() > 1e-9 ? result / divisor : 0.0;
      }
      return result;
    }

    return double.tryParse(expr.trim()) ?? 0.0;
  }

  static List<String> _splitByTopLevelOp(String str, String op) {
    final result = <String>[];
    var depth = 0;
    var start = 0;
    for (var i = 0; i < str.length; i++) {
      final ch = str[i];
      if (ch == '(') depth++;
      if (ch == ')') depth--;
      if (depth == 0 && ch == op && i > 0 && i < str.length - 1) {
        result.add(str.substring(start, i).trim());
        start = i + 1;
      }
    }
    result.add(str.substring(start).trim());
    return result;
  }
}

// ===========================================================================
// 2. DYNAMIC SCRIPTED DEFINITION (ScriptedComponentDefinition)
// ===========================================================================

/// A component definition instantiated at runtime from code or JSON script.
class ScriptedComponentDefinition extends ArchitectComponentDefinition {
  final String _id;
  final String _name;
  final ArchitectComponentCategory _category;
  final ComponentPlacementMode _placementMode;
  final List<ParametricFieldSchema> _schema;
  final List<Map<String, dynamic>> _solids;
  final List<Map<String, dynamic>> _symbolDetails;
  final String rawSourceJson;

  ScriptedComponentDefinition({
    required String id,
    required String name,
    required ArchitectComponentCategory category,
    required ComponentPlacementMode placementMode,
    required List<ParametricFieldSchema> schema,
    required List<Map<String, dynamic>> solids,
    required List<Map<String, dynamic>> symbolDetails,
    required this.rawSourceJson,
  })  : _id = id,
        _name = name,
        _category = category,
        _placementMode = placementMode,
        _schema = schema,
        _solids = solids,
        _symbolDetails = symbolDetails;

  @override
  String get id => _id;

  @override
  String get defaultName => _name;

  @override
  ArchitectComponentCategory get category => _category;

  @override
  ComponentPlacementMode get placementMode => _placementMode;

  @override
  List<ParametricFieldSchema> get schema => _schema;

  @override
  CachedComponentGeometry generateGeometry(Map<String, dynamic> params) {
    final w = (params['width'] as num?)?.toDouble() ??
        (defaultParameters['width'] as num?)?.toDouble() ??
        0.60;
    final d = (params['depth'] as num?)?.toDouble() ??
        (defaultParameters['depth'] as num?)?.toDouble() ??
        0.60;
    final h = (params['height'] as num?)?.toDouble() ??
        (defaultParameters['height'] as num?)?.toDouble() ??
        0.80;

    final vars = <String, double>{
      'width': w,
      'depth': d,
      'height': h,
      for (final s in _schema)
        if (params.containsKey(s.key))
          s.key: (params[s.key] as num).toDouble(),
    };

    final builder = ParametricSolidBuilder(width: w, depth: d, height: h);

    // 1. Process 3D solids
    for (final s in _solids) {
      final type = s['type'] as String? ?? 'box';
      final colorHex = s['color'] as String?;
      final color = _parseColor(colorHex) ?? const Color(0xFFECEFF1);

      if (type == 'box') {
        final originRaw = s['origin'] as List? ?? [0.0, 0.0, 0.0];
        final sizeRaw = s['size'] as List? ?? ['width', 'depth', 'height'];
        final ox = SimpleMathEvaluator.evaluate(originRaw[0], vars);
        final oy = SimpleMathEvaluator.evaluate(originRaw[1], vars);
        final oz = originRaw.length > 2
            ? SimpleMathEvaluator.evaluate(originRaw[2], vars)
            : 0.0;

        final sx = SimpleMathEvaluator.evaluate(sizeRaw[0], vars);
        final sy = SimpleMathEvaluator.evaluate(sizeRaw[1], vars);
        final sz = SimpleMathEvaluator.evaluate(sizeRaw[2], vars);

        builder.addBox(
          origin: Offset(ox, oy),
          boxWidth: sx,
          boxDepth: sy,
          boxHeight: sz,
          zBottom: oz,
          color: color,
        );
      } else if (type == 'cylinder') {
        final centerRaw = s['center'] as List? ?? [0.0, 'depth/2'];
        final radius = SimpleMathEvaluator.evaluate(s['radius'] ?? 'width/2', vars);
        final cylH = SimpleMathEvaluator.evaluate(s['height'] ?? 'height', vars);
        final oz = SimpleMathEvaluator.evaluate(s['zBottom'] ?? 0.0, vars);
        final segments = (s['segments'] as num?)?.toInt() ?? 16;

        final cx = SimpleMathEvaluator.evaluate(centerRaw[0], vars);
        final cy = SimpleMathEvaluator.evaluate(centerRaw[1], vars);

        builder.addCylinder(
          center: Offset(cx, cy),
          radius: radius,
          cylinderHeight: cylH,
          zBottom: oz,
          segments: segments,
          color: color,
        );
      }
    }

    // 2. Process 2D CAD symbol details
    for (final det in _symbolDetails) {
      final type = det['type'] as String? ?? 'line';
      if (type == 'line') {
        final fromRaw = det['from'] as List? ?? [0.0, 0.0];
        final toRaw = det['to'] as List? ?? ['width', 'depth'];
        final fx = SimpleMathEvaluator.evaluate(fromRaw[0], vars);
        final fy = SimpleMathEvaluator.evaluate(fromRaw[1], vars);
        final tx = SimpleMathEvaluator.evaluate(toRaw[0], vars);
        final ty = SimpleMathEvaluator.evaluate(toRaw[1], vars);
        builder.add2DDetailLine(Offset(fx, fy), Offset(tx, ty));
      } else if (type == 'oval' || type == 'circle') {
        final centerRaw = det['center'] as List? ?? [0.0, 'depth/2'];
        final cx = SimpleMathEvaluator.evaluate(centerRaw[0], vars);
        final cy = SimpleMathEvaluator.evaluate(centerRaw[1], vars);
        final ow = SimpleMathEvaluator.evaluate(det['width'] ?? 'width*0.8', vars);
        final od = SimpleMathEvaluator.evaluate(det['depth'] ?? ow, vars);

        final p = Path()..addOval(Rect.fromCenter(center: Offset(cx, cy), width: ow, height: od));
        builder.add2DDetailPath(p);
      } else if (type == 'rect') {
        final originRaw = det['origin'] as List? ?? [0.0, 0.0];
        final ox = SimpleMathEvaluator.evaluate(originRaw[0], vars);
        final oy = SimpleMathEvaluator.evaluate(originRaw[1], vars);
        final rw = SimpleMathEvaluator.evaluate(det['width'] ?? 'width', vars);
        final rd = SimpleMathEvaluator.evaluate(det['depth'] ?? 'depth', vars);

        final p = Path()..addRect(Rect.fromLTWH(ox, oy, rw, rd));
        builder.add2DDetailPath(p);
      }
    }

    return builder.build(defaultName);
  }

  static Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final clean = hex.replaceAll('#', '');
    final val = int.tryParse(clean.length == 6 ? 'FF$clean' : clean, radix: 16);
    return val != null ? Color(val) : null;
  }
}

// ===========================================================================
// 3. PARAMETRIC SCRIPT PARSER (ParametricScriptParser)
// ===========================================================================

/// Compiles JSON or script source code into a [ScriptedComponentDefinition].
class ParametricScriptParser {
  static ScriptedComponentDefinition parse(String scriptJson) {
    final data = jsonDecode(scriptJson) as Map<String, dynamic>;

    final id = data['id'] as String? ?? 'custom_obj_${DateTime.now().millisecondsSinceEpoch}';
    final name = data['name'] as String? ?? 'Custom Component';
    final catStr = data['category'] as String? ?? 'furniture';
    final category = ArchitectComponentCategory.fromName(catStr);
    final placeStr = data['placementMode'] as String? ?? 'freeStanding';
    final placementMode = ComponentPlacementMode.fromName(placeStr);

    final schemaList = <ParametricFieldSchema>[];
    final defaultParams = data['defaultParams'] as Map<String, dynamic>? ?? {};

    schemaList.add(ParametricFieldSchema(
      key: 'width',
      label: 'Width',
      defaultValue: (defaultParams['width'] as num?)?.toDouble() ?? 0.80,
    ));
    schemaList.add(ParametricFieldSchema(
      key: 'depth',
      label: 'Depth',
      defaultValue: (defaultParams['depth'] as num?)?.toDouble() ?? 0.80,
    ));
    schemaList.add(ParametricFieldSchema(
      key: 'height',
      label: 'Height',
      defaultValue: (defaultParams['height'] as num?)?.toDouble() ?? 0.80,
    ));

    final solids = (data['solids'] as List?)
            ?.map((item) => Map<String, dynamic>.from(item as Map))
            .toList() ??
        const [];

    final symbolObj = data['symbol2d'] as Map<String, dynamic>?;
    final symbolDetails = (symbolObj?['details'] as List?)
            ?.map((item) => Map<String, dynamic>.from(item as Map))
            .toList() ??
        const [];

    return ScriptedComponentDefinition(
      id: id,
      name: name,
      category: category,
      placementMode: placementMode,
      schema: schemaList,
      solids: solids,
      symbolDetails: symbolDetails,
      rawSourceJson: scriptJson,
    );
  }
}
