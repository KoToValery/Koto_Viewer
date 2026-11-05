import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'architect_properties_shell.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_component_definition.dart';
import '../models/component_dimensions.dart';
import '../models/architect_component.dart';
import 'architect_component_labels.dart';
import '../components/definitions/service_components.dart';

class ComponentDimensionsDialog extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>>? onPreview;
  final bool Function()? isCurrent;
  final ArchitectComponentDefinition definition;
  final Map<String, dynamic> parameters;
  const ComponentDimensionsDialog({
    super.key,
    required this.definition,
    required this.parameters,
    this.onPreview,
    this.isCurrent,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context,
    ArchitectComponentDefinition definition,
    Map<String, dynamic> parameters, {
    ValueChanged<Map<String, dynamic>>? onPreview,
    bool Function()? isCurrent,
    ValueChanged<double>? onDockWidth,
    ValueChanged<EdgeInsets>? onInsets,
  }) => showArchitectProperties<Map<String, dynamic>>(
    context: context,
    onDockWidth: onDockWidth,
    onInsets: onInsets,
    builder: (_) => ComponentDimensionsDialog(
      definition: definition,
      parameters: parameters,
      onPreview: onPreview,
      isCurrent: isCurrent,
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
  late final Map<String, dynamic> _baseline;
  Timer? _timer;
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
    _baseline = Map.of(_values);
    for (final axis in axes) {
      _controllers[axis] = TextEditingController(text: _text(axis));
    }
    if (ServiceComponentDefinition.hasRoofOutlet(widget.definition.id)) {
      for (final key in [
        'aboveRoof',
        'roofClearance',
        if (ServiceComponentDefinition.hasSmokeFlue(widget.definition.id))
          'flueDiameter',
      ]) {
        _controllers[key] = TextEditingController(text: _text(key));
      }
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

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 200), () {
      if (mounted && _invalidAxes.isEmpty) {
        try {
          widget.definition.resolveGeometry(_values);
          widget.onPreview?.call(Map.of(_values));
        } catch (_) {
          /* Invalid geometry is kept in the form. */
        }
      }
    });
  }

  void _apply() {
    if (_invalidAxes.isNotEmpty || widget.isCurrent?.call() == false) return;
    try {
      widget.definition.resolveGeometry(_values);
      Navigator.of(context).pop(_values);
    } catch (_) {
      setState(() => _geometryError = true);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final service =
        widget.definition.category == ArchitectComponentCategory.services;
    final smoke = ServiceComponentDefinition.hasSmokeFlue(widget.definition.id);
    final outlet = ServiceComponentDefinition.hasRoofOutlet(
      widget.definition.id,
    );
    final continuous = ServiceComponentDefinition.continuousIds.contains(
      widget.definition.id,
    );
    final automaticBody = outlet && widget.definition.id != 'service_fireplace';
    final labels = [
      l.architectPropertyWidth,
      l.architectPropertyDepth,
      l.architectPropertyHeight,
    ];
    return ArchitectPropertiesDialog(
      title: Text(
        service
            ? componentLabel(l, widget.definition)
            : l.architectToolComponent,
      ),
      isDirty: () => _invalidAxes.isNotEmpty || !mapEquals(_baseline, _values),
      onSave: _apply,
      content: SingleChildScrollView(
        child: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < axes.length; i++)
                if (!automaticBody ||
                    axes[i] != 'height' ||
                    _values['autoHeight'] == false)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      key: ValueKey('component-size-${axes[i]}'),
                      controller: _controllers[axes[i]],
                      enabled:
                          !automaticBody ||
                          axes[i] != 'height' ||
                          _values['autoHeight'] == false,
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
              if (outlet) ...[
                if (continuous)
                  Tooltip(
                    message: l.architectServiceAllStoreysHelp,
                    child: SwitchListTile.adaptive(
                      key: const ValueKey('service-all-storeys'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.architectServiceAllStoreys),
                      value: _values['allStoreys'] != false,
                      onChanged: (v) =>
                          setState(() => _values['allStoreys'] = v),
                    ),
                  ),
                if (smoke)
                  KeyedSubtree(
                    key: const ValueKey('service-chimney-cap'),
                    child: DropdownButtonFormField<int>(
                      key: ValueKey('chimney-cap-${_values['capType']}'),
                      initialValue: (_values['capType'] as num?)?.toInt() ?? 1,
                      decoration: InputDecoration(
                        labelText: l.architectServiceCap,
                      ),
                      items: [
                        for (final entry in {
                          0: l.architectServiceCapNone,
                          1: l.architectServiceCapFlat,
                          2: l.architectServiceCapPitched,
                          3: l.architectServiceCapConical,
                        }.entries)
                          DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                      ],
                      onChanged: (v) =>
                          setState(() => _values['capType'] = v ?? 1),
                    ),
                  ),
                Tooltip(
                  message: l.architectServiceAutoHeightHelp,
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.architectServiceAutoHeight),
                    value: _values['autoHeight'] != false,
                    onChanged: (v) => setState(() => _values['autoHeight'] = v),
                  ),
                ),
                for (final entry in {
                  'aboveRoof': l.architectServiceAboveRoof,
                  if (smoke) 'flueDiameter': l.architectServiceFlueDiameter,
                  'roofClearance': l.architectServiceRoofClearance,
                }.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      key: ValueKey('service-${entry.key}'),
                      controller: _controllers[entry.key],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: entry.value,
                        suffixText: 'cm',
                        errorText: _invalidAxes.contains(entry.key)
                            ? l.architectComponentDimensionError
                            : null,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (text) {
                        final number = double.tryParse(
                          text.replaceAll(',', '.'),
                        );
                        setState(() {
                          if (number == null ||
                              !number.isFinite ||
                              number < 0 ||
                              number > 1000 ||
                              entry.key == 'flueDiameter' && number < 8) {
                            _invalidAxes.add(entry.key);
                          } else {
                            _invalidAxes.remove(entry.key);
                            _values[entry.key] = number / 100;
                          }
                        });
                      },
                    ),
                  ),
              ],
              if (serviceComponentHelp(l, widget.definition.id)
                  case final String help)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Tooltip(
                    message: help,
                    child: const Icon(Icons.info_outline, size: 20),
                  ),
                ),
              if (!service)
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
                value:
                    (_values['visibleInSection'] as bool?) ??
                    widget.definition.defaultVisibleInSection,
                onChanged: (value) => setState(
                  () => _values['visibleInSection'] = value ?? false,
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _values = Map.of(widget.definition.defaultParameters);
                  for (final axis in _controllers.keys) {
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
