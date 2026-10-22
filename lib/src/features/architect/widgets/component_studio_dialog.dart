import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/l10n/l10n_extensions.dart';
import 'component_preview_painters.dart';
import '../components/dsl/parametric_script_parser.dart';

import '../models/architect_component_definition.dart';
import '../services/component_library_service.dart';
import 'component_dimensions_dialog.dart';

class ComponentStudioDialog extends StatefulWidget {
  final String? initialScriptJson;
  const ComponentStudioDialog({super.key, this.initialScriptJson});
  static Future<void> show(BuildContext context, {String? initialScriptJson}) =>
      showDialog(
        context: context,
        builder: (_) =>
            ComponentStudioDialog(initialScriptJson: initialScriptJson),
      );
  @override
  State<ComponentStudioDialog> createState() => _ComponentStudioDialogState();
}

class _ComponentStudioDialogState extends State<ComponentStudioDialog>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _code = TextEditingController(
    text: widget.initialScriptJson ?? '',
  );
  late final TabController _tabs = TabController(length: 3, vsync: this);
  ScriptedComponentDefinition? _definition;
  CachedComponentGeometry? _geometry;
  Map<String, dynamic> _parameters = {};
  String? _error;
  bool _dirty = true;
  bool _saving = false;
  double _pitch = .55, _yaw = .65;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(_onTab);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_code.text.isEmpty) _code.text = _template(false);
    if (_definition == null && _error == null) _compile();
  }

  void _onTab() {
    if (_tabs.index != 0 && _dirty) _compile();
    if (mounted) setState(() {});
  }

  bool _compile() {
    try {
      final definition = ParametricScriptParser.parse(_code.text);
      final parameters = definition.defaultParameters;
      final geometry = definition.resolveGeometry(parameters);
      setState(() {
        _definition = definition;
        _parameters = parameters;
        _geometry = geometry;
        _error = null;
        _dirty = false;
      });
      return true;
    } catch (e) {
      setState(() {
        _definition = null;
        _geometry = null;
        _error = e.toString();
      });
      return false;
    }
  }

  Future<void> _resize() async {
    if ((_dirty && !_compile()) || _definition == null) return;
    final values = await ComponentDimensionsDialog.show(
      context,
      _definition!,
      _parameters,
    );
    if (values == null || !mounted) return;
    setState(() {
      _parameters = values;
      _geometry = _definition!.resolveGeometry(values);
    });
  }

  Future<void> _save() async {
    if (_saving || (_dirty && !_compile()) || _definition == null) return;
    setState(() => _saving = true);
    try {
      final data =
          jsonDecode(_definition!.rawSourceJson) as Map<String, dynamic>;
      data['defaultParams'] = _parameters;
      final source = const JsonEncoder.withIndent('  ').convert(data);
      await ComponentLibraryService.instance.saveCustomScript(source);
      if (!mounted) return;
      _code.text = source;
      _definition = ParametricScriptParser.parse(source);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.architectComponentSavedMsg)),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _export() {
    if ((_dirty && !_compile()) || _definition == null) return;
    final data = jsonDecode(_definition!.rawSourceJson) as Map<String, dynamic>;
    data['defaultParams'] = _parameters;
    // JSON is reusable both through import and the code editor.
    Clipboard.setData(
      ClipboardData(text: const JsonEncoder.withIndent('  ').convert(data)),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.architectComponentExportJsonMsg)),
    );
  }

  void _exportDart() {
    if ((_dirty && !_compile()) || _definition == null) return;
    final data = jsonDecode(_definition!.rawSourceJson) as Map<String, dynamic>;
    data['defaultParams'] = _parameters;
    final literal = jsonEncode(jsonEncode(data)).replaceAll(r'$', r'\$');
    final className =
        'LibraryComponent_${_definition!.id.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')}';
    final source =
        '''
import 'package:kotoview/src/features/architect/components/dsl/parametric_script_parser.dart';
import 'package:kotoview/src/features/architect/models/architect_component.dart';
import 'package:kotoview/src/features/architect/models/architect_component_definition.dart';

class $className extends ArchitectComponentDefinition {
  static final _definition = ParametricScriptParser.parse($literal);
  @override
  String get id => _definition.id;
  @override
  String get defaultName => _definition.defaultName;
  @override
  ArchitectComponentCategory get category => _definition.category;
  @override
  ComponentPlacementMode get placementMode => _definition.placementMode;
  @override
  List<ParametricFieldSchema> get schema => _definition.schema;
  @override
  CachedComponentGeometry generateGeometry(Map<String, dynamic> params) =>
      _definition.generateGeometry(params);
}
''';
    Clipboard.setData(ClipboardData(text: source));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.architectComponentExportDartMsg)),
    );
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTab);
    _tabs.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final phone = MediaQuery.sizeOf(context).width < 600;
    return Dialog(
      backgroundColor: const Color(0xFF181820),
      insetPadding: EdgeInsets.all(phone ? 8 : 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 760),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.architectComponentStudioTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  PopupMenuButton<bool>(
                    tooltip: l.architectComponentTemplateHint,
                    icon: const Icon(
                      Icons.description_outlined,
                      color: Colors.white70,
                    ),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: false,
                        child: Text(l.architectTemplateDesk),
                      ),
                      PopupMenuItem(
                        value: true,
                        child: Text(l.architectTemplateBasin),
                      ),
                    ],
                    onSelected: (basin) {
                      _code.text = _template(basin);
                      _compile();
                    },
                  ),
                  PopupMenuButton<bool>(
                    tooltip: l.architectComponentExportJsonTooltip,
                    icon: const Icon(
                      Icons.copy_outlined,
                      color: Colors.white70,
                    ),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: false,
                        child: Text(l.architectComponentExportJsonTooltip),
                      ),
                      PopupMenuItem(
                        value: true,
                        child: Text(l.architectComponentExportDartTooltip),
                      ),
                    ],
                    onSelected: (dart) => dart ? _exportDart() : _export(),
                  ),
                  IconButton(
                    tooltip: l.close,
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabs,
              labelColor: Colors.cyanAccent,
              unselectedLabelColor: Colors.white60,
              tabs: [
                Tab(text: l.architectComponentCode),
                const Tab(text: '2D'),
                const Tab(text: '3D'),
              ],
            ),
            if (_error != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 110),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.architectComponentInvalid,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                        SelectableText(
                          _error!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      key: const ValueKey('component-studio-code'),
                      controller: _code,
                      expands: true,
                      maxLines: null,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                      ),
                      onChanged: (_) => setState(() {
                        _dirty = true;
                        _error = null;
                      }),
                    ),
                  ),
                  ColoredBox(
                    color: Colors.white,
                    child: _geometry == null
                        ? const SizedBox.shrink()
                        : CustomPaint(
                            painter: ComponentPlanPreviewPainter(
                              _geometry!.block2d,
                              (_parameters['width'] as num).toDouble(),
                              (_parameters['depth'] as num).toDouble(),
                            ),
                          ),
                  ),
                  GestureDetector(
                    onPanUpdate: (d) => setState(() {
                      _yaw += d.delta.dx * .01;
                      _pitch = (_pitch - d.delta.dy * .01).clamp(
                        -math.pi / 2.5,
                        math.pi / 2.5,
                      );
                    }),
                    child: ColoredBox(
                      color: const Color(0xFF121218),
                      child: _geometry == null
                          ? const SizedBox.shrink()
                          : CustomPaint(
                              painter: ComponentMeshPreviewPainter(
                                _geometry!.mesh3d,
                                _pitch,
                                _yaw,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _definition == null ? null : _resize,
                    icon: const Icon(Icons.straighten),
                    label: Text(l.architectPropertySize),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: l.architectComponentCompileBtn,
                    icon: const Icon(
                      Icons.play_arrow,
                      color: Colors.cyanAccent,
                    ),
                    onPressed: () {
                      if (_compile()) _tabs.animateTo(1);
                    },
                  ),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(l.save),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _template(bool basin) => const JsonEncoder.withIndent('  ').convert(
    basin
        ? {
            'id': 'custom_basin_${DateTime.now().microsecondsSinceEpoch}',
            'name': context.l10n.architectTemplateBasin,
            'category': 'sanitary',
            'placementMode': 'wallAttached',
            'defaultParams': {'width': .60, 'depth': .45, 'height': .18},
            'solids': [
              {
                'type': 'basin',
                'center': [0, 'depth/2'],
                'width': 'width',
                'depth': 'depth',
                'height': 'height',
                'wall': .025,
                'base': .035,
              },
            ],
            'symbol2d': {
              'details': [
                {
                  'type': 'circle',
                  'center': [0, 'depth/2'],
                  'width': .045,
                },
              ],
            },
          }
        : {
            'id': 'custom_desk_${DateTime.now().microsecondsSinceEpoch}',
            'name': context.l10n.architectTemplateDesk,
            'category': 'office',
            'placementMode': 'freeStanding',
            'defaultParams': {
              'width': 1.40,
              'depth': .70,
              'height': .75,
              'top': .035,
            },
            'solids': [
              {
                'type': 'box',
                'origin': ['-width/2', 0, 'height-top'],
                'size': ['width', 'depth', 'top'],
                'color': '#BCAAA4',
              },
              for (final x in ['-width/2+.05', 'width/2-.10'])
                for (final y in ['.05', 'depth-.10'])
                  {
                    'type': 'box',
                    'origin': [x, y, 0],
                    'size': [.05, .05, 'height-top'],
                    'color': '#78909C',
                  },
            ],
          },
  );
}
