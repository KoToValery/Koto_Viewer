// === SECTION: ARCHITECTURAL COMPONENT STUDIO (CODE GENERATOR & LIVE 2D/3D PREVIEW) ===
// Table of Contents:
// 1. DIALOG CONTAINER & CODE EDITOR STATE
// 2. LIVE 2D PLAN SYMBOL PREVIEW
// 3. LIVE 3D ORBIT PREVIEW PAINTER
// 4. CODE TEMPLATES & DART EXPORTER

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../cad_3d/models/mesh_3d.dart';
import '../components/dsl/parametric_script_parser.dart';
import '../models/architect_component.dart';
import '../models/architect_component_definition.dart';

import '../services/component_library_service.dart';

/// In-app interactive IDE / studio for designing parametric 3D/2D components directly from code.
class ComponentStudioDialog extends StatefulWidget {
  final String? initialScriptJson;

  const ComponentStudioDialog({super.key, this.initialScriptJson});

  static Future<void> show(BuildContext context, {String? initialScriptJson}) {
    return showDialog(
      context: context,
      builder: (ctx) => ComponentStudioDialog(initialScriptJson: initialScriptJson),
    );
  }

  @override
  State<ComponentStudioDialog> createState() => _ComponentStudioDialogState();
}

class _ComponentStudioDialogState extends State<ComponentStudioDialog>
    with SingleTickerProviderStateMixin {
  late TextEditingController _codeController;
  late TabController _previewTabController;

  ScriptedComponentDefinition? _compiledDefinition;
  CachedComponentGeometry? _currentGeometry;
  String? _compileError;

  // Active testing parameters
  double _testWidth = 0.80;
  double _testDepth = 0.60;
  double _testHeight = 0.85;

  // 3D Orbit camera angles
  double _camPitch = 0.55;
  double _camYaw = 0.65;

  @override
  void initState() {
    super.initState();
    _previewTabController = TabController(length: 2, vsync: this);
    _codeController = TextEditingController(
      text: widget.initialScriptJson ?? _defaultTemplates.values.first,
    );
    _recompile();
  }

  @override
  void dispose() {
    _previewTabController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _recompile() {
    setState(() {
      try {
        _compiledDefinition = ParametricScriptParser.parse(_codeController.text);
        final defaultParams = _compiledDefinition!.defaultParameters;
        _testWidth = (defaultParams['width'] as num?)?.toDouble() ?? 0.80;
        _testDepth = (defaultParams['depth'] as num?)?.toDouble() ?? 0.60;
        _testHeight = (defaultParams['height'] as num?)?.toDouble() ?? 0.85;
        _evaluateCurrentGeometry();
        _compileError = null;
      } catch (e) {
        _compileError = e.toString();
      }
    });
  }

  void _evaluateCurrentGeometry() {
    if (_compiledDefinition == null) return;
    final params = {
      'width': _testWidth,
      'depth': _testDepth,
      'height': _testHeight,
    };
    _currentGeometry = _compiledDefinition!.generateGeometry(params);
  }

  Future<void> _saveToLibrary() async {
    if (_compiledDefinition == null) return;
    await ComponentLibraryService.instance.saveCustomScript(_codeController.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.architectComponentSavedMsg),
        backgroundColor: const Color(0xFF00E5FF),
      ),
    );
  }

  void _exportDartCode() {
    if (_compiledDefinition == null) return;
    final dartCode = _generateDartClass(_compiledDefinition!, _codeController.text);
    Clipboard.setData(ClipboardData(text: dartCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.architectComponentExportDartMsg),
        backgroundColor: const Color(0xFF00E5FF),
      ),
    );
  }

  String _generateDartClass(ScriptedComponentDefinition def, String rawJson) {
    final className = def.defaultName.replaceAll(RegExp(r'\s+'), '');
    return '''
// Auto-generated parametric component: $className
import 'package:flutter/material.dart';
import '../models/architect_component.dart';
import '../models/architect_component_definition.dart';
import '../components/dsl/parametric_script_parser.dart';

class $className extends ArchitectComponentDefinition {
  static final _compiled = ParametricScriptParser.parse(r\'\'\'
$rawJson
\'\'\');

  @override
  String get id => _compiled.id;

  @override
  String get defaultName => _compiled.defaultName;

  @override
  ArchitectComponentCategory get category => _compiled.category;

  @override
  ComponentPlacementMode get placementMode => _compiled.placementMode;

  @override
  List<ParametricFieldSchema> get schema => _compiled.schema;

  @override
  CachedComponentGeometry generateGeometry(Map<String, dynamic> params) =>
      _compiled.generateGeometry(params);
}
''';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Dialog(
      backgroundColor: const Color(0xFF181820),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 760),
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
              child: Row(
                children: [
                  const Icon(Icons.integration_instructions, color: Color(0xFF00E5FF), size: 22),
                  const SizedBox(width: 10),
                  Text(
                    l.architectComponentStudioTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Template Picker
                  DropdownButton<String>(
                    dropdownColor: const Color(0xFF262633),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    value: null,
                    hint: Text(l.architectComponentTemplateHint, style: const TextStyle(color: Colors.white60)),
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final entry in _defaultTemplates.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.key),
                        ),
                    ],
                    onChanged: (val) {
                      if (val != null && _defaultTemplates.containsKey(val)) {
                        _codeController.text = _defaultTemplates[val]!;
                        _recompile();
                      }
                    },
                  ),
                  const Spacer(),
                  // Compile Button
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: Text(l.architectComponentCompileBtn),
                    onPressed: _recompile,
                  ),
                  const SizedBox(width: 8),
                  // Save Button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00E5FF),
                      side: const BorderSide(color: Color(0xFF00E5FF)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: Text(l.architectComponentSaveBtn),
                    onPressed: _saveToLibrary,
                  ),
                  const SizedBox(width: 8),
                  // Export Dart
                  IconButton(
                    icon: const Icon(Icons.file_copy_outlined, color: Colors.white70),
                    tooltip: l.architectComponentExportDartTooltip,
                    onPressed: _exportDartCode,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF2D2D3D)),

            // Body: Code Editor (Left) & Preview Panel (Right)
            Expanded(
              child: Row(
                children: [
                  // Left side: Code / Script Editor
                  Expanded(
                    flex: 5,
                    child: Container(
                      color: const Color(0xFF14141A),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _codeController,
                              maxLines: null,
                              expands: true,
                              style: const TextStyle(
                                fontFamily: 'Consolas',
                                fontSize: 12.5,
                                color: Color(0xFFE0E0E0),
                                height: 1.4,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          if (_compileError != null)
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4A1414),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _compileError!,
                                style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 11),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const VerticalDivider(width: 1, color: Color(0xFF2D2D3D)),

                  // Right side: Interactive 2D & 3D Live Preview
                  Expanded(
                    flex: 6,
                    child: Column(
                      children: [
                        // Tabs: 2D vs 3D
                        Container(
                          color: const Color(0xFF22222E),
                          child: TabBar(
                            controller: _previewTabController,
                            indicatorColor: const Color(0xFF00E5FF),
                            labelColor: const Color(0xFF00E5FF),
                            unselectedLabelColor: Colors.white60,
                            tabs: [
                              Tab(icon: const Icon(Icons.crop_square, size: 18), text: l.architect2dPlanSymbol),
                              Tab(icon: const Icon(Icons.view_in_ar, size: 18), text: l.architect3dSolidMesh),
                            ],
                          ),
                        ),

                        // Preview Canvas Area
                        Expanded(
                          child: TabBarView(
                            controller: _previewTabController,
                            children: [
                              // 2D Preview
                              Container(
                                color: const Color(0xFF1E1E26),
                                child: _currentGeometry == null
                                    ? const SizedBox.shrink()
                                    : CustomPaint(
                                        painter: _Live2dSymbolPainter(
                                          _currentGeometry!.block2d,
                                          _testWidth,
                                          _testDepth,
                                        ),
                                      ),
                              ),

                              // 3D Preview with interactive drag
                              GestureDetector(
                                onPanUpdate: (details) {
                                  setState(() {
                                    _camYaw += details.delta.dx * 0.01;
                                    _camPitch = (_camPitch - details.delta.dy * 0.01)
                                        .clamp(-math.pi / 2.5, math.pi / 2.5);
                                  });
                                },
                                child: Container(
                                  color: const Color(0xFF121218),
                                  child: _currentGeometry == null
                                      ? const SizedBox.shrink()
                                      : CustomPaint(
                                          painter: _Live3dMeshPainter(
                                            _currentGeometry!.mesh3d,
                                            _camPitch,
                                            _camYaw,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Parameter Testing Sliders Panel
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          color: const Color(0xFF1E1E26),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildSliderRow(
                                label: '${l.architectPropertyWidth}: ${(_testWidth * 100).round()} cm',
                                value: _testWidth,
                                min: 0.20,
                                max: 3.00,
                                onChanged: (v) {
                                  setState(() {
                                    _testWidth = v;
                                    _evaluateCurrentGeometry();
                                  });
                                },
                              ),
                              _buildSliderRow(
                                label: '${l.architectPropertyDepth}: ${(_testDepth * 100).round()} cm',
                                value: _testDepth,
                                min: 0.20,
                                max: 3.00,
                                onChanged: (v) {
                                  setState(() {
                                    _testDepth = v;
                                    _evaluateCurrentGeometry();
                                  });
                                },
                              ),
                              _buildSliderRow(
                                label: '${l.architectPropertyHeight}: ${(_testHeight * 100).round()} cm',
                                value: _testHeight,
                                min: 0.20,
                                max: 3.00,
                                onChanged: (v) {
                                  setState(() {
                                    _testHeight = v;
                                    _evaluateCurrentGeometry();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            activeColor: const Color(0xFF00E5FF),
            inactiveColor: const Color(0xFF37474F),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  static final Map<String, String> _defaultTemplates = {
    'Custom Desk': const JsonEncoder.withIndent('  ').convert({
      'id': 'custom_standing_desk',
      'name': 'Parametric Standing Desk',
      'category': 'office',
      'placementMode': 'wallAttached',
      'defaultParams': {'width': 1.40, 'depth': 0.70, 'height': 0.75},
      'solids': [
        {
          'type': 'box',
          'origin': ['-width/2', 0.0, 'height - 0.04'],
          'size': ['width', 'depth', 0.04],
          'color': '#8D6E63',
        },
        {
          'type': 'box',
          'origin': ['-width/2 + 0.06', 'depth*0.3', 0.0],
          'size': [0.08, 0.08, 'height - 0.04'],
          'color': '#37474F',
        },
        {
          'type': 'box',
          'origin': ['width/2 - 0.14', 'depth*0.3', 0.0],
          'size': [0.08, 0.08, 'height - 0.04'],
          'color': '#37474F',
        },
      ],
      'symbol2d': {
        'details': [
          {
            'type': 'line',
            'from': ['-width/2 + 0.14', 0.0],
            'to': ['-width/2 + 0.14', 'depth'],
          },
        ],
      },
    }),
    'Wall-hung Basin': const JsonEncoder.withIndent('  ').convert({
      'id': 'custom_washbasin',
      'name': 'Modern Wall Basin',
      'category': 'sanitary',
      'placementMode': 'wallAttached',
      'defaultParams': {'width': 0.60, 'depth': 0.45, 'height': 0.40},
      'solids': [
        {
          'type': 'box',
          'origin': ['-width/2', 0.0, 0.0],
          'size': ['width', 'depth', 'height'],
          'color': '#FAFAFA',
        },
        {
          'type': 'cylinder',
          'center': [0.0, 'depth*0.5'],
          'radius': 'width*0.28',
          'height': 'height*0.8',
          'zBottom': 'height*0.2',
          'color': '#ECEFF1',
        },
      ],
      'symbol2d': {
        'details': [
          {
            'type': 'oval',
            'center': [0.0, 'depth*0.5'],
            'width': 'width*0.75',
            'depth': 'depth*0.65',
          },
          {
            'type': 'circle',
            'center': [0.0, 'depth*0.5'],
            'width': 0.05,
          },
        ],
      },
    }),
  };
}

// ===========================================================================
// 2. LIVE 2D PLAN SYMBOL PAINTER
// ===========================================================================

class _Live2dSymbolPainter extends CustomPainter {
  final ArchitectComponentBlock2D block;
  final double width;
  final double depth;

  const _Live2dSymbolPainter(this.block, this.width, this.depth);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final scaleX = (size.width * 0.70) / (width > 1e-4 ? width : 1.0);
    final scaleY = (size.height * 0.70) / (depth > 1e-4 ? depth : 1.0);
    final scale = math.min(scaleX, scaleY);

    canvas.save();
    canvas.translate(size.width / 2.0, size.height / 2.0);
    canvas.scale(scale, scale);
    canvas.translate(0.0, -depth / 2.0);

    // Grid floor guidelines
    final gridPaint = Paint()
      ..color = const Color(0xFF2C2C3A)
      ..strokeWidth = 0.5 / scale;
    for (var x = -1.5; x <= 1.5; x += 0.20) {
      canvas.drawLine(Offset(x, -0.5), Offset(x, depth + 0.5), gridPaint);
    }
    for (var y = -0.5; y <= depth + 0.5; y += 0.20) {
      canvas.drawLine(Offset(-1.5, y), Offset(1.5, y), gridPaint);
    }

    // 1. Whiteout mask
    canvas.drawPath(block.boundsMask, Paint()..color = Colors.white);

    // 2. Outer contour
    canvas.drawPath(
      block.outline,
      Paint()
        ..color = const Color(0xFF263238)
        ..strokeWidth = 1.4 / scale
        ..style = PaintingStyle.stroke,
    );

    // 3. Details
    final detailPaint = Paint()
      ..color = const Color(0xFF546E7A)
      ..strokeWidth = 0.9 / scale
      ..style = PaintingStyle.stroke;
    for (final p in block.detailPaths) {
      canvas.drawPath(p, detailPaint);
    }

    // 4. Insertion point indicator at (0, 0)
    canvas.drawCircle(Offset.zero, 4.0 / scale, Paint()..color = const Color(0xFF00E5FF));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _Live2dSymbolPainter oldDelegate) => true;
}

// ===========================================================================
// 3. LIVE 3D ORBIT PREVIEW PAINTER
// ===========================================================================

class _Live3dMeshPainter extends CustomPainter {
  final Mesh3D mesh;
  final double pitch;
  final double yaw;

  const _Live3dMeshPainter(this.mesh, this.pitch, this.yaw);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || mesh.triangles.isEmpty) return;

    final bounds = mesh.bounds;
    final maxDim = math.max(bounds.maxDimension, 0.20);
    final scale = (size.height * 0.45) / maxDim;
    final center = bounds.center;

    final cosY = math.cos(yaw);
    final sinY = math.sin(yaw);
    final cosP = math.cos(pitch);
    final sinP = math.sin(pitch);

    // Rotate points around center
    Offset project(Vector3 p) {
      final dx = p.x - center.x;
      final dy = p.y - center.y;
      final dz = p.z - center.z;

      // Yaw rotation (Z-up)
      final x1 = dx * cosY - dy * sinY;
      final y1 = dx * sinY + dy * cosY;
      final z1 = dz;

      // Pitch rotation
      final x2 = x1;
            final z2 = y1 * sinP + z1 * cosP;

      return Offset(
        size.width / 2.0 + x2 * scale,
        size.height / 2.0 - z2 * scale,
      );
    }

    double depth(Triangle3D t) {
      final c = t.centroid;
      final dx = c.x - center.x;
      final dy = c.y - center.y;
      final dz = c.z - center.z;
      final y1 = dx * sinY + dy * cosY;
      return y1 * cosP - dz * sinP;
    }

    // Painter's algorithm sort
    final sortedTris = List<Triangle3D>.from(mesh.triangles)
      ..sort((a, b) => depth(b).compareTo(depth(a)));

    final lightDir = Vector3(0.5, 0.4, 0.8).normalized();

    for (final t in sortedTris) {
      final p0 = project(t.v0);
      final p1 = project(t.v1);
      final p2 = project(t.v2);

      final n = t.normal;
      final dot = math.max(0.25, n.dot(lightDir));
      final baseColor = t.color ?? const Color(0xFFECEFF1);
      final shadedColor = Color.fromARGB(
        (baseColor.a * 255.0).round().clamp(0, 255),
        ((baseColor.r * 255.0).round().clamp(0, 255) * dot).round().clamp(0, 255),
        ((baseColor.g * 255.0).round().clamp(0, 255) * dot).round().clamp(0, 255),
        ((baseColor.b * 255.0).round().clamp(0, 255) * dot).round().clamp(0, 255),
      );

      final path = Path()
        ..moveTo(p0.dx, p0.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close();

      canvas.drawPath(path, Paint()..color = shadedColor);
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0x33000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Live3dMeshPainter oldDelegate) => true;
}
