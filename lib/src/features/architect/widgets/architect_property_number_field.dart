import 'package:kotoview/src/core/icons/app_icon.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../services/architect_properties_session.dart';
import 'architect_properties_shell.dart';

/// Exact input preserves model precision and distinguishes mixed from zero.
class ArchitectPropertyNumberField extends StatefulWidget {
  final ArchitectPropertyDescriptor descriptor;
  final ArchitectProject project;
  final String label;
  final double? value;
  final bool readOnly;
  final String? helper;
  final VoidCallback? onClear;
  final ValueChanged<double> onChanged;
  const ArchitectPropertyNumberField({
    super.key,
    required this.descriptor,
    required this.project,
    required this.label,
    required this.value,
    required this.onChanged,
    this.readOnly = false,
    this.helper,
    this.onClear,
  });
  @override
  State<ArchitectPropertyNumberField> createState() => _NumberState();
}

class _NumberState extends State<ArchitectPropertyNumberField> {
  late final controller = TextEditingController(text: _text());
  final focus = FocusNode();
  bool edited = false;
  String _text() => widget.value == null
      ? ''
      : ArchitectUnit.trimZeros(
          (widget.value! / widget.descriptor.scale(widget.project))
              .toStringAsFixed(9),
        );
  @override
  void didUpdateWidget(covariant ArchitectPropertyNumberField old) {
    super.didUpdateWidget(old);
    if ((!focus.hasFocus || widget.readOnly) &&
        (old.value != widget.value ||
            old.project.units != widget.project.units ||
            old.project.distanceDecimals != widget.project.distanceDecimals)) {
      final nextText = _text();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            (!focus.hasFocus || widget.readOnly) &&
            controller.text != nextText) {
          controller.text = nextText;
        }
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    focusNode: focus,
    readOnly: widget.readOnly,
    keyboardType: TextInputType.numberWithOptions(
      decimal: widget.descriptor.measure != ArchitectPropertyMeasure.count,
      signed: widget.descriptor.minimum < 0,
    ),
    textInputAction: TextInputAction.next,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    decoration: InputDecoration(
      labelText: widget.label,
      suffixText: widget.descriptor.unit(widget.project),
      hintText: widget.value == null ? context.l10n.wallMixedValue : null,
      helperText: widget.helper,
      suffixIcon: widget.onClear != null
          ? IconButton(
              tooltip: context.l10n.propertiesClear,
              icon: const AppIcon(AppIconId.close, size: 18),
              onPressed: () {
                controller.clear();
                edited = false;
                widget.onClear!();
              },
            )
          : widget.readOnly
          ? AppIcon.fromMaterial(
              widget.helper == context.l10n.propertiesCalculated
                  ? Icons.functions
                  : Icons.link,
              size: 18,
            )
          : null,
    ),
    validator: (text) =>
        widget.readOnly ||
            (!edited && (text ?? '').isEmpty && widget.value == null) ||
            widget.descriptor.parse(text ?? '', widget.project) != null
        ? null
        : context.l10n.propertiesInvalid,
    onChanged: (text) {
      edited = true;
      final value = widget.descriptor.parse(text, widget.project);
      if (value != null) widget.onChanged(value);
    },
    onTap: () => ArchitectPropertiesShell.of(context)?.expand(),
  );
}
