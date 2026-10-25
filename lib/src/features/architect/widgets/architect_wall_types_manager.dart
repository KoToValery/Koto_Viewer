import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../models/architect_wall_type.dart';
import '../services/architect_element_id.dart';
import '../services/architect_wall_compositions.dart';
import 'architect_wall_composition_editor.dart';
import 'architect_wall_type_picker.dart';
import 'architect_wall_type_label.dart';

class ArchitectWallTypesManager extends StatefulWidget {
  final ArchitectProject project;
  final bool Function(ArchitectProject) onApply;
  const ArchitectWallTypesManager({
    super.key,
    required this.project,
    required this.onApply,
  });
  @override
  State<ArchitectWallTypesManager> createState() => _TypesState();
}

class _TypesState extends State<ArchitectWallTypesManager> {
  late ArchitectProject project =
      widget.project.wallTypes.any((t) => t.isCatalogType)
      ? widget.project
      : widget.project.copyWith(
          wallTypes: [
            ...ArchitectWallType.standardCatalog(),
            ...widget.project.wallTypes,
          ],
        );
  String? activeId;
  int uses(String id) => project.storeys.fold(
    0,
    (v, s) => v + s.walls.where((w) => w.wallTypeId == id).length,
  );
  bool apply(ArchitectProject next) {
    if (!widget.onApply(next)) return false;
    setState(() => project = next);
    return true;
  }

  Future<void> edit(ArchitectWallType type, {bool copy = false}) async {
    setState(() => activeId = type.id);
    final draft = copy
        ? type.copyWith(
            id: ArchitectElementId.next('wall_type'),
            name: '',
            labelId: type.labelId ?? type.id,
            isCatalogType: true,
          )
        : type;
    await showDialog<void>(
      context: context,
      builder: (_) => ArchitectWallCompositionEditor(
        project: project,
        type: draft,
        isNewType: copy,
        typeUseCount: copy ? 0 : uses(type.id),
        onApply: (value, _, changed) {
          if (!copy && !changed) return true;
          if (copy &&
              !changed &&
              project.wallTypes.any((t) => t.id == type.id)) {
            return true;
          }
          final accepted = apply(
            SetArchitectWallComposition(
              type: value,
              replaceTypeId: copy ? null : type.id,
            ).apply(project),
          );
          if (accepted) setState(() => activeId = value.id);
          return accepted;
        },
      ),
    );
  }

  Future<void> remove(ArchitectWallType type) async {
    var replacement = '';
    if (uses(type.id) > 0) {
      final choices = project.wallTypes
          .where(
            (t) =>
                t.id != type.id &&
                t.isCatalogType &&
                t.isParapet == type.isParapet,
          )
          .toList();
      if (choices.isEmpty) return;
      replacement = choices.first.id;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, update) => AlertDialog(
            title: Text(ctx.l10n.wallTypeReplacement),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(ctx.l10n.wallTypeInUse),
                OutlinedButton(
                  onPressed: () async {
                    final result = await showArchitectWallTypePicker(
                      ctx,
                      types: choices,
                      activeType: choices.firstWhere(
                        (t) => t.id == replacement,
                      ),
                      unit: project.units,
                      projectId: project.id,
                    );
                    if (result != null && ctx.mounted) {
                      update(() => replacement = result.type.id);
                    }
                  },
                  child: Text(
                    choices
                        .firstWhere((t) => t.id == replacement)
                        .catalogLabel(ctx.l10n, project.units),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(ctx.l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(ctx.l10n.applyAction),
              ),
            ],
          ),
        ),
      );
      if (accepted != true || !mounted) return;
    }
    apply(
      DeleteArchitectWallType(
        type.id,
        replacementId: replacement,
      ).apply(project),
    );
  }

  Future<void> newType() async {
    final templates = ArchitectWallType.standardCatalog();
    final result = await showArchitectWallTypePicker(
      context,
      types: templates,
      activeType: templates.first,
      projectId: '${project.id}_templates',
      unit: project.units,
    );
    if (result != null && mounted) await edit(result.type, copy: true);
  }

  @override
  Widget build(BuildContext context) {
    final types = project.wallTypes.where((t) => t.isCatalogType).toList();
    final browser = ArchitectWallCatalogBrowser(
      types: types,
      activeType:
          types.where((t) => t.id == activeId).firstOrNull ?? types.first,
      projectId: project.id,
      unit: project.units,
      manage: true,
      onSelect: (type) => edit(type),
      onCopy: (type) => edit(type, copy: true),
      onDelete: types.length > 1 ? remove : null,
      canDelete: (type) =>
          uses(type.id) == 0 ||
          types.any((t) => t.id != type.id && t.isParapet == type.isParapet),
      onNewType: newType,
      onClose: () => Navigator.pop(context),
    );
    if (MediaQuery.sizeOf(context).width < 600) {
      return Dialog.fullscreen(child: SafeArea(child: browser));
    }
    return Dialog(child: SizedBox(width: 620, height: 700, child: browser));
  }
}
