import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_component_definition.dart';
import '../models/component_dimensions.dart';

class ComponentDimensionsDialog extends StatefulWidget {
  final ArchitectComponentDefinition definition;
  final Map<String, dynamic> parameters;
  const ComponentDimensionsDialog({
    super.key,
    required this.definition,
    required this.parameters,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context,
    ArchitectComponentDefinition definition,
    Map<String, dynamic> parameters,
  ) => showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => ComponentDimensionsDialog(
      definition: definition,
      parameters: parameters,
    ),
  );

  @override
  State<ComponentDimensionsDialog> createState() =>
      _ComponentDimensionsDialogState();
}

class _ComponentDimensionsDialogState extends State<ComponentDimensionsDialog> {
  static const axes = ['width', 'depth', 'height'];
  late Map<String, dynamic> _values;
  final _controllers = <String, TextEditingController>{};
  bool _locked = false;
  final Set<String> _invalidAxes = {};
  bool _geometryError = false;

  @override
  void initState() {
    super.initState();
    _values = {
      'visibleInSection': widget.definition.defaultVisibleInSection,
      ...widget.definition.defaultParameters,
      ...widget.parameters,
    };
    for (final axis in axes) {
      _controllers[axis] = TextEditingController(text: _text(axis));
    }
  }

  String _text(String axis) => ((_values[axis] as num) * 100)
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'\.?0+$'), '');

  void _change(String axis, String text) {
    final value = double.tryParse(text.replaceAll(',', '.'));
    try {
      if (value == null) throw const FormatException();
      final resized = resizeComponentDimensions(
        _values,
        axis,
        value / 100,
        lockRatio: _locked,
      );
      setState(() {
        _values = resized;
        _invalidAxes.remove(axis);
        _geometryError = false;
        if (_locked) {
          for (final other in axes.where((a) => a != axis)) {
            _controllers[other]!.text = _text(other);
            _invalidAxes.remove(other);
          }
        }
      });
    } on FormatException {
      setState(() => _invalidAxes.add(axis));
    }
  }

  void _apply() {
    if (_invalidAxes.isNotEmpty) return;
    try {
      widget.definition.resolveGeometry(_values);
      Navigator.of(context).pop(_values);
    } catch (_) {
      setState(() => _geometryError = true);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final labels = [
      l.architectPropertyWidth,
      l.architectPropertyDepth,
      l.architectPropertyHeight,
    ];
    return AlertDialog(
      title: Text(l.architectPropertySize),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < axes.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    key: ValueKey('component-size-${axes[i]}'),
                    controller: _controllers[axes[i]],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: i == 2
                        ? TextInputAction.done
                        : TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: '${labels[i]} (${['X', 'Y', 'Z'][i]})',
                      suffixText: 'cm',
                      border: const OutlineInputBorder(),
                      errorText: _invalidAxes.contains(axes[i])
                          ? l.architectComponentDimensionError
                          : null,
                    ),
                    onChanged: (text) => _change(axes[i], text),
                    onSubmitted: i == 2 ? (_) => _apply() : null,
                  ),
                ),
              Tooltip(
                message: l.architectComponentLockRatioHelp,
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.architectComponentLockRatio),
                  value: _locked,
                  onChanged: (value) => setState(() => _locked = value),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.architectVisibleInSection),
                value: (_values['visibleInSection'] as bool?) ??
                    widget.definition.defaultVisibleInSection,
                onChanged: (value) =>
                    setState(() => _values['visibleInSection'] = value ?? false),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _values = Map.of(widget.definition.defaultParameters);
                  for (final axis in axes) {
                    _controllers[axis]!.text = _text(axis);
                  }
                  _invalidAxes.clear();
                  _geometryError = false;
                }),
                child: Text(l.architectComponentDefaults),
              ),
              if (_geometryError)
                Text(
                  l.architectComponentInvalid,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: _invalidAxes.isEmpty ? _apply : null,
          child: Text(l.applyAction),
        ),
      ],
    );
  }
}
