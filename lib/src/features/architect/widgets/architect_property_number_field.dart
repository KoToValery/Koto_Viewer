import 'package:kotoview/src/core/icons/app_icon.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../bim_editing/widgets/bim_numeric_keypad.dart';
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

  Future<void> _openKeypad(BuildContext context) async {
    ArchitectPropertiesShell.of(context)?.expand();
    if (widget.readOnly) return;
    final decimals =
        widget.descriptor.measure == ArchitectPropertyMeasure.count ? 0 : 3;
    final scale = widget.descriptor.scale(widget.project);
    final result = await BimNumericKeypad.showInputDialog(
      context,
      title: widget.label,
      initialText: controller.text,
      unitLabel: widget.descriptor.unit(widget.project),
      decimals: decimals,
      allowNegative: widget.descriptor.minimum < 0,
      min: widget.descriptor.minimum.isFinite
          ? widget.descriptor.minimum / scale
          : null,
      max: widget.descriptor.maximum.isFinite
          ? widget.descriptor.maximum / scale
          : null,
    );
    if (!mounted || result == null) return;
    final formatted = ArchitectUnit.trimZeros(result.toStringAsFixed(9));
    controller.text = formatted;
    edited = true;
    final parsed = widget.descriptor.parse(formatted, widget.project);
    if (parsed != null) widget.onChanged(parsed);
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    focusNode: focus,
    readOnly: widget.readOnly,
    keyboardType: TextInputType.none,
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
    onTap: () => _openKeypad(context),
  );
}
