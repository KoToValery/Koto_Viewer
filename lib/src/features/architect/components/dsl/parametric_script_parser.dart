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
    final value = expr is num
        ? expr.toDouble()
        : expr is String
        ? _ExpressionReader(expr, vars).read()
        : throw const FormatException('Expected a number or expression');
    if (!value.isFinite) throw const FormatException('Non-finite expression');
    return value;
  }
}

/// Recursive descent preserves precedence, unary signs and complete identifiers.
/// Invalid code is reported to the author instead of creating collapsed solids.
class _ExpressionReader {
  final String source;
  final Map<String, double> variables;
  int position = 0;
  _ExpressionReader(this.source, this.variables);

  bool take(String token) {
    while (position < source.length && source[position].trim().isEmpty) {
      position++;
    }
    if (!source.startsWith(token, position)) return false;
    position += token.length;
    return true;
  }

  double read() {
    final result = sum();
    take(' ');
    if (position != source.length) {
      throw FormatException('Unexpected expression token', source, position);
    }
    return result;
  }

  double sum() {
    var value = product();
    while (true) {
      if (take('+')) {
        value += product();
      } else if (take('-')) {
        value -= product();
      } else {
        return value;
      }
    }
  }

  double product() {
    var value = atom();
    while (true) {
      if (take('*')) {
        value *= atom();
      } else if (take('/')) {
        final divisor = atom();
        if (divisor == 0) throw const FormatException('Division by zero');
        value /= divisor;
      } else {
        return value;
      }
    }
  }

  double atom() {
    if (take('+')) return atom();
    if (take('-')) return -atom();
    if (take('(')) {
      final value = sum();
      if (!take(')')) {
        throw const FormatException('Missing closing parenthesis');
      }
      return value;
    }
    final rest = source.substring(position);
    final number = RegExp(
      r'^(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?',
    ).firstMatch(rest);
    if (number != null) {
      position += number[0]!.length;
      return double.parse(number[0]!);
    }
    final name = RegExp(r'^[a-zA-Z_][a-zA-Z_0-9]*').firstMatch(rest)?[0];
    if (name != null && variables.containsKey(name)) {
      position += name.length;
      return variables[name]!;
    }
    throw FormatException(
      'Unknown variable or invalid expression',
      source,
      position,
    );
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
  }) : _id = id,
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
    final w =
        (params['width'] as num?)?.toDouble() ??
        (defaultParameters['width'] as num?)?.toDouble() ??
        0.60;
    final d =
        (params['depth'] as num?)?.toDouble() ??
        (defaultParameters['depth'] as num?)?.toDouble() ??
        0.60;
    final h =
        (params['height'] as num?)?.toDouble() ??
        (defaultParameters['height'] as num?)?.toDouble() ??
        0.80;

    final vars = <String, double>{
      for (final s in _schema) s.key: s.defaultValue,
      'width': w,
      'depth': d,
      'height': h,
      for (final s in _schema)
        if (params.containsKey(s.key)) s.key: (params[s.key] as num).toDouble(),
    };

    final builder = ParametricSolidBuilder(width: w, depth: d, height: h);

    // 1. Process 3D solids
    for (final s in _solids) {
      final type = s['type'] as String? ?? 'box';
      final colorHex = s['color'] as String?;
      final color = _parseColor(colorHex) ?? const Color(0xFFECEFF1);

      if (type == 'box') {
        final originRaw = s['origin'] as List? ?? ['-width/2', 0.0, 0.0];
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
        final radius = SimpleMathEvaluator.evaluate(
          s['radius'] ?? 'width/2',
          vars,
        );
        final cylH = SimpleMathEvaluator.evaluate(
          s['height'] ?? 'height',
          vars,
        );
        final oz = SimpleMathEvaluator.evaluate(s['zBottom'] ?? 0.0, vars);
        final segments = (s['segments'] as num?)?.toInt() ?? 48;

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
      } else if (type == 'basin') {
        final center = s['center'] as List? ?? [0.0, 'depth/2'];
        builder.addBasin(
          center: Offset(
            SimpleMathEvaluator.evaluate(center[0], vars),
            SimpleMathEvaluator.evaluate(center[1], vars),
          ),
          basinWidth: SimpleMathEvaluator.evaluate(s['width'] ?? 'width', vars),
          basinDepth: SimpleMathEvaluator.evaluate(s['depth'] ?? 'depth', vars),
          basinHeight: SimpleMathEvaluator.evaluate(
            s['height'] ?? 'height',
            vars,
          ),
          wall: SimpleMathEvaluator.evaluate(s['wall'] ?? 0.025, vars),
          base: SimpleMathEvaluator.evaluate(s['base'] ?? 0.04, vars),
          zBottom: SimpleMathEvaluator.evaluate(s['zBottom'] ?? 0.0, vars),
          rectangular: s['rectangular'] == true,
          color: color,
        );
      } else {
        throw FormatException('Unsupported solid type: $type');
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
        final ow = SimpleMathEvaluator.evaluate(
          det['width'] ?? 'width*0.8',
          vars,
        );
        final od = SimpleMathEvaluator.evaluate(det['depth'] ?? ow, vars);

        final p = Path()
          ..addOval(
            Rect.fromCenter(center: Offset(cx, cy), width: ow, height: od),
          );
        builder.add2DDetailPath(p);
      } else if (type == 'rect') {
        final originRaw = det['origin'] as List? ?? [0.0, 0.0];
        final ox = SimpleMathEvaluator.evaluate(originRaw[0], vars);
        final oy = SimpleMathEvaluator.evaluate(originRaw[1], vars);
        final rw = SimpleMathEvaluator.evaluate(det['width'] ?? 'width', vars);
        final rd = SimpleMathEvaluator.evaluate(det['depth'] ?? 'depth', vars);

        final p = Path()..addRect(Rect.fromLTWH(ox, oy, rw, rd));
        builder.add2DDetailPath(p);
      } else {
        throw FormatException('Unsupported 2D detail type: $type');
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

    final id =
        data['id'] as String? ??
        'custom_obj_${DateTime.now().millisecondsSinceEpoch}';
    final name = data['name'] as String? ?? '';
    final catStr = data['category'] as String? ?? 'furniture';
    final category = ArchitectComponentCategory.fromName(catStr);
    if (!ArchitectComponentCategory.values.any((c) => c.name == catStr)) {
      throw FormatException('Unknown category: $catStr');
    }
    final placeStr = data['placementMode'] as String? ?? 'freeStanding';
    final placementMode = ComponentPlacementMode.fromName(placeStr);
    if (!ComponentPlacementMode.values.any((m) => m.name == placeStr)) {
      throw FormatException('Unknown placement mode: $placeStr');
    }

    final schemaList = <ParametricFieldSchema>[];
    final defaultParams = data['defaultParams'] as Map<String, dynamic>? ?? {};

    schemaList.add(
      ParametricFieldSchema(
        key: 'width',
        label: 'Width',
        defaultValue: (defaultParams['width'] as num?)?.toDouble() ?? 0.80,
      ),
    );
    schemaList.add(
      ParametricFieldSchema(
        key: 'depth',
        label: 'Depth',
        defaultValue: (defaultParams['depth'] as num?)?.toDouble() ?? 0.80,
      ),
    );
    schemaList.add(
      ParametricFieldSchema(
        key: 'height',
        label: 'Height',
        defaultValue: (defaultParams['height'] as num?)?.toDouble() ?? 0.80,
      ),
    );
    for (final entry in defaultParams.entries) {
      if (['width', 'depth', 'height'].contains(entry.key)) continue;
      schemaList.add(
        ParametricFieldSchema(
          key: entry.key,
          label: entry.key,
          defaultValue: (entry.value as num).toDouble(),
        ),
      );
    }
    if (schemaList.any((s) => !s.defaultValue.isFinite) ||
        schemaList.take(3).any((s) => s.defaultValue <= 0)) {
      throw const FormatException(
        'Default dimensions must be positive and finite',
      );
    }

    final solids =
        (data['solids'] as List?)
            ?.map((item) => Map<String, dynamic>.from(item as Map))
            .toList() ??
        const [];

    final symbolObj = data['symbol2d'] as Map<String, dynamic>?;
    final symbolDetails =
        (symbolObj?['details'] as List?)
            ?.map((item) => Map<String, dynamic>.from(item as Map))
            .toList() ??
        const [];

    if (solids.isEmpty) {
      throw const FormatException('At least one solid is required');
    }
    final definition = ScriptedComponentDefinition(
      id: id,
      name: name,
      category: category,
      placementMode: placementMode,
      schema: schemaList,
      solids: solids,
      symbolDetails: symbolDetails,
      rawSourceJson: jsonEncode({...data, 'id': id}),
    );
    definition.resolveGeometry(definition.defaultParameters);
    return definition;
  }
}
