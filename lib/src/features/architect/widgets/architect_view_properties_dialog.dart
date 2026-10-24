import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_elevation.dart';
import '../models/architect_project.dart';
import '../models/architect_section.dart';
import '../services/architect_command_controller.dart';
import 'architect_elevation_labels.dart';
import 'architect_section_visibility_dialog.dart';

class ArchitectViewPropertiesDialog extends StatefulWidget {
  final ArchitectProject project;
  final String viewId;
  final ArchitectCommandController controller;
  final VoidCallback? onOpenView;
  final VoidCallback? onReverse;
  final VoidCallback? onDelete;

  const ArchitectViewPropertiesDialog({
    super.key,
    required this.project,
    required this.viewId,
    required this.controller,
    this.onOpenView,
    this.onReverse,
    this.onDelete,
  });

  @override
  State<ArchitectViewPropertiesDialog> createState() =>
      _ArchitectViewPropertiesDialogState();
}

class _ArchitectViewPropertiesDialogState
    extends State<ArchitectViewPropertiesDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _depthController;
  late bool _hasDepth;

  ArchitectSection? get _section =>
      widget.project.sections.where((s) => s.id == widget.viewId).firstOrNull;

  ArchitectElevation? get _elevation => widget.project.elevations
      .where((e) => e.id == widget.viewId)
      .firstOrNull;

  bool get _isSection => _section != null;

  @override
  void initState() {
    super.initState();
    final sec = _section;
    final el = _elevation;
    final initialDepth = sec?.viewDepth ?? el?.viewDepth;
    _hasDepth = initialDepth != null;
    _nameController = TextEditingController(text: sec?.name ?? '');
    _depthController = TextEditingController(
      text: initialDepth != null ? initialDepth.toStringAsFixed(2) : '10.00',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _depthController.dispose();
    super.dispose();
  }

  void _save() {
    final depthVal = _hasDepth ? double.tryParse(_depthController.text) : null;
    final p = widget.controller.project;

    if (_isSection) {
      widget.controller.commit(
        p.copyWith(
          sections: [
            for (final s in p.sections)
              if (s.id == widget.viewId)
                s.copyWith(
                  name: _nameController.text.trim(),
                  viewDepth: depthVal,
                  clearViewDepth: !_hasDepth,
                )
              else
                s,
          ],
        ),
      );
    } else {
      widget.controller.commit(
        p.copyWith(
          elevations: [
            for (final e in p.elevations)
              if (e.id == widget.viewId)
                e.copyWith(
                  viewDepth: depthVal,
                  clearViewDepth: !_hasDepth,
                )
              else
                e,
          ],
        ),
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final sec = _section;
    final el = _elevation;
    final title = _isSection
        ? (sec!.name.isNotEmpty
            ? sec.name
            : l.architectSectionNumber(
                widget.project.sections.indexOf(sec) + 1,
              ))
        : (el != null
            ? architectElevationLabel(
                l,
                el,
                widget.project.northSymbol?.angle ?? 0,
              )
            : l.architectFacade);

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E24),
      title: Row(
        children: [
          Icon(
            _isSection ? Icons.splitscreen_outlined : Icons.apartment,
            color: const Color(0xFF00E5FF),
            size: 22,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isSection) ...[
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: l.architectViewRename,
                  labelStyle: const TextStyle(color: Colors.white70),
                  hintText: sec != null && sec.name.isEmpty
                      ? l.architectSectionNumber(
                          widget.project.sections.indexOf(sec) + 1,
                        )
                      : null,
                  hintStyle: const TextStyle(color: Colors.white38),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF00E5FF)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                l.architectViewDepth,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              subtitle: Text(
                _hasDepth
                    ? '${_depthController.text} m'
                    : l.architectViewUnlimited,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              value: _hasDepth,
              activeTrackColor: const Color(0xFF00E5FF),
              onChanged: (val) => setState(() => _hasDepth = val),
            ),
            if (_hasDepth) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _depthController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: '${l.architectViewDepth} (m)',
                  labelStyle: const TextStyle(color: Colors.white70),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF00E5FF)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_isSection) ...[
              OutlinedButton.icon(
                icon: const Icon(
                  Icons.visibility_outlined,
                  size: 18,
                  color: Color(0xFF00E5FF),
                ),
                label: Text(
                  l.architectSectionVisibility,
                  style: const TextStyle(color: Colors.white),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                ),
                onPressed: () {
                  showArchitectSectionVisibility(
                    context,
                    widget.controller,
                    sectionId: widget.viewId,
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.flip_rounded, size: 18),
                    label: Text(
                      l.architectFacadeReverse,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                    ),
                    onPressed: () {
                      widget.onReverse?.call();
                      Navigator.of(context).pop();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.visibility, size: 18),
                    label: Text(
                      _isSection
                          ? l.architectOpenSection
                          : l.architectOpenElevation,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00838F),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onOpenView?.call();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
                size: 18,
              ),
              label: Text(
                l.delete,
                style: const TextStyle(color: Colors.redAccent),
              ),
              onPressed: () {
                widget.onDelete?.call();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel, style: const TextStyle(color: Colors.white60)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E5FF),
            foregroundColor: Colors.black,
          ),
          onPressed: _save,
          child: Text(
            l.applyAction,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

Future<void> showArchitectViewPropertiesDialog({
  required BuildContext context,
  required ArchitectProject project,
  required String viewId,
  required ArchitectCommandController controller,
  VoidCallback? onOpenView,
  VoidCallback? onReverse,
  VoidCallback? onDelete,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => ArchitectViewPropertiesDialog(
      project: project,
      viewId: viewId,
      controller: controller,
      onOpenView: onOpenView,
      onReverse: onReverse,
      onDelete: onDelete,
    ),
  );
}
