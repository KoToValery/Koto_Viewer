import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../models/architect_wall_type.dart';
import '../services/architect_element_id.dart';
import '../services/architect_wall_compositions.dart';
import 'architect_wall_type_label.dart';
import 'architect_wall_composition_editor.dart';

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
  late ArchitectProject project = widget.project;
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
    final draft = copy
        ? type.copyWith(
            id: ArchitectElementId.next('wall_type'),
            name: '',
            labelId: type.labelId ?? type.id,
          )
        : type;
    await showDialog<void>(
      context: context,
      builder: (_) => ArchitectWallCompositionEditor(
        project: project,
        type: draft,
        requireName: copy,
        typeUseCount: copy ? 0 : uses(type.id),
        onApply: (value, _, changed) => !copy && !changed
            ? true
            : apply(
                SetArchitectWallComposition(
                  type: value,
                  replaceTypeId: copy ? null : type.id,
                ).apply(project),
              ),
      ),
    );
  }

  Future<void> remove(ArchitectWallType type) async {
    var replacement = '';
    if (uses(type.id) > 0) {
      final choices = project.wallTypes.where((t) => t.id != type.id).toList();
      if (choices.isEmpty) return;
      replacement = choices.first.id;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.l10n.wallTypeReplacement),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ctx.l10n.wallTypeInUse),
              DropdownButtonFormField<String>(
                initialValue: replacement,
                items: [
                  for (final t in choices)
                    DropdownMenuItem(
                      value: t.id,
                      child: Text(t.compactLabel(ctx.l10n)),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) replacement = v;
                },
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

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.wallTypesTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: l.close,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('wall-type-add'),
                  onPressed: () => edit(
                    ArchitectWallType.standardCatalog().first,
                    copy: true,
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(l.wallNewType),
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final type in project.wallTypes)
                      ListTile(
                        key: ValueKey('wall-type-row-${type.id}'),
                        contentPadding: EdgeInsets.zero,
                        leading: SizedBox(
                          width: 24,
                          height: 36,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final layer in type.resolvedLayers)
                                Expanded(
                                  flex: (layer.thickness * 10000).round().clamp(
                                    1,
                                    100000,
                                  ),
                                  child: ColoredBox(
                                    color: layer.material.color,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        title: Text(type.compactLabel(l)),
                        subtitle: Text(
                          project.formatLength(type.totalThickness),
                        ),
                        onTap: () => edit(type),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: l.wallTypeCopy,
                              onPressed: () => edit(type, copy: true),
                              icon: const Icon(Icons.copy),
                            ),
                            IconButton(
                              tooltip: l.delete,
                              onPressed: project.wallTypes.length > 1
                                  ? () => remove(type)
                                  : null,
                              icon: const Icon(Icons.delete_outline),
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
      ),
    );
  }
}
