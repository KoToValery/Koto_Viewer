import 'package:kotoview/src/core/icons/app_icon.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../models/architect_section.dart';
import '../models/architect_elevation.dart';
import '../services/architect_command_controller.dart';
import '../services/architect_properties_session.dart';
import 'architect_properties_shell.dart';
import 'architect_property_number_field.dart';
import 'architect_section_visibility_dialog.dart';

class ArchitectViewPropertiesDialog extends StatefulWidget {
  final ValueChanged<ArchitectProject?>? onPreview;
  final ArchitectProject project;
  final String viewId;
  final ArchitectCommandController controller;
  final VoidCallback? onOpenView, onReverse, onDelete;
  const ArchitectViewPropertiesDialog({
    super.key,
    this.onPreview,
    required this.project,
    required this.viewId,
    required this.controller,
    this.onOpenView,
    this.onReverse,
    this.onDelete,
  });
  @override
  State<ArchitectViewPropertiesDialog> createState() => _ViewState();
}

class _ViewState extends State<ArchitectViewPropertiesDialog> {
  final _form = GlobalKey<FormState>();
  late final _local = ArchitectCommandController(widget.project);
  late final _name = TextEditingController(text: _section?.name ?? '');
  ArchitectSection? get _section =>
      widget.project.sections.where((s) => s.id == widget.viewId).firstOrNull;
  ArchitectElevation? get _elevation =>
      widget.project.elevations.where((s) => s.id == widget.viewId).firstOrNull;
  late bool _hasDepth = (_section?.viewDepth ?? _elevation?.viewDepth) != null;
  late double _depth = _section?.viewDepth ?? _elevation?.viewDepth ?? 10;
  bool _reverse = false, _edited = false;
  String? _error;
  ArchitectProject _candidate() => _local.project.copyWith(
    sections: [
      for (final s in _local.project.sections)
        if (s.id == widget.viewId)
          (_reverse ? s.reversed() : s).copyWith(
            name: _name.text.trim(),
            viewDepth: _hasDepth ? _depth : null,
            clearViewDepth: !_hasDepth,
          )
        else
          s,
    ],
    elevations: [
      for (final e in _local.project.elevations)
        if (e.id == widget.viewId)
          (_reverse ? e.copyWith(viewSide: -e.viewSide) : e).copyWith(
            viewDepth: _hasDepth ? _depth : null,
            clearViewDepth: !_hasDepth,
          )
        else
          e,
    ],
  );
  bool _save({bool close = true}) {
    if (!_form.currentState!.validate()) return false;
    if (!identical(widget.controller.project, widget.project)) {
      setState(() => _error = context.l10n.propertiesStale);
      return false;
    }
    if (_edited) widget.controller.commit(_candidate());
    if (close) Navigator.pop(context);
    return true;
  }

  Timer? _timer;
  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 200), () {
      if (mounted && identical(widget.controller.project, widget.project)) {
        widget.onPreview?.call(_candidate());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.onPreview?.call(null);
    _name.dispose();
    _local.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ArchitectPropertiesShell(
      title: _section != null
          ? l.architectToolSection
          : l.architectToolElevation,
      isDirty: () => _edited,
      onSave: () => _save(),
      content: Form(
        key: _form,
        onChanged: () => _edited = true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_section != null)
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(labelText: l.architectViewRename),
                  onChanged: (_) => setState(() => _edited = true),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.architectViewDepth),
                subtitle: !_hasDepth ? Text(l.architectViewUnlimited) : null,
                value: _hasDepth,
                onChanged: (v) => setState(() {
                  _edited = true;
                  _hasDepth = v;
                }),
              ),
              if (_hasDepth)
                ArchitectPropertyNumberField(
                  descriptor: const ArchitectPropertyDescriptor('viewDepth'),
                  project: widget.project,
                  label: l.architectViewDepth,
                  value: _depth,
                  onChanged: (v) => setState(() {
                    _edited = true;
                    _depth = v;
                  }),
                ),
              const SizedBox(height: 16),
              if (_section != null)
                OutlinedButton.icon(
                  icon: const AppIcon(AppIconId.visible),
                  label: Text(l.architectSectionVisibility),
                  onPressed: () async {
                    await showArchitectSectionVisibility(
                      context,
                      _local,
                      sectionId: widget.viewId,
                    );
                    if (mounted) setState(() => _edited = true);
                  },
                ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const AppIcon(AppIconId.flipHorizontal),
                label: Text(l.architectFacadeReverse),
                onPressed: () => setState(() {
                  _edited = true;
                  _reverse = !_reverse;
                }),
              ),
              if (widget.onOpenView != null)
                TextButton.icon(
                  icon: const AppIcon(AppIconId.external),
                  label: Text(l.propertiesSaveOpen),
                  onPressed: () {
                    if (_save()) {
                      widget.onOpenView!();
                    }
                  },
                ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(onPressed: () => _save(), child: Text(l.save)),
      ],
    );
  }
}

Future<void> showArchitectViewPropertiesDialog({
  required BuildContext context,
  required ArchitectProject project,
  required String viewId,
  required ArchitectCommandController controller,
  ValueChanged<ArchitectProject?>? onPreview,
  ValueChanged<double>? onDockWidth,
  ValueChanged<EdgeInsets>? onInsets,
  VoidCallback? onOpenView,
  VoidCallback? onReverse,
  VoidCallback? onDelete,
}) => showArchitectProperties<void>(
  context: context,
  onDockWidth: onDockWidth,
  onInsets: onInsets,
  builder: (_) => ArchitectViewPropertiesDialog(
    project: project,
    viewId: viewId,
    controller: controller,
    onPreview: onPreview,
    onOpenView: onOpenView,
    onReverse: onReverse,
    onDelete: onDelete,
  ),
);
