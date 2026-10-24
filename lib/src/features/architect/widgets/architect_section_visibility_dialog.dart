import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_section_visibility.dart';
import '../services/architect_command_controller.dart';

/// Saves project defaults and view overrides together, with one undo step.
Future<void> showArchitectSectionVisibility(
  BuildContext context,
  ArchitectCommandController controller, {
  String? sectionId,
}) async {
  final initial = controller.project;
  final section = initial.sections.where((s) => s.id == sectionId).firstOrNull;
  var defaults = initial.sectionVisibility;
  var overrides = section?.visibility ?? const ArchitectSectionVisibility();
  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final l = context.l10n;
        String modeLabel(ArchitectSectionDisplay mode) => switch (mode) {
          ArchitectSectionDisplay.cutAndProjection =>
            l.architectSectionCutAndView,
          ArchitectSectionDisplay.cutOnly => l.architectSectionCutOnly,
          ArchitectSectionDisplay.hidden => l.architectSectionHidden,
        };
        Widget rules(bool forProject) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              forProject
                  ? l.architectSectionProjectRules
                  : l.architectSectionViewRules,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final category in ArchitectSectionCategory.values)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: DropdownButtonFormField<String>(
                  key: ValueKey(
                    'section-visibility-${forProject ? 'default' : 'view'}-${category.name}',
                  ),
                  initialValue: forProject
                      ? defaults.modeFor(category).name
                      : overrides.categories[category]?.name ?? 'inherit',
                  isExpanded: true,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: switch (category) {
                      ArchitectSectionCategory.gutters =>
                        l.architectDrainageGutter,
                      ArchitectSectionCategory.downpipes =>
                        l.architectDrainagePipes,
                    },
                  ),
                  items: [
                    if (!forProject)
                      DropdownMenuItem(
                        value: 'inherit',
                        child: Text(l.architectSectionInherit),
                      ),
                    for (final mode in ArchitectSectionDisplay.values)
                      DropdownMenuItem(
                        value: mode.name,
                        child: Text(modeLabel(mode)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    final mode = ArchitectSectionDisplay.values
                        .where((mode) => mode.name == value)
                        .firstOrNull;
                    setState(() {
                      if (forProject) {
                        defaults = defaults.withMode(category, mode);
                      } else {
                        overrides = overrides.withMode(category, mode);
                      }
                    });
                  },
                ),
              ),
          ],
        );
        return AlertDialog(
          title: Row(
            children: [
              Expanded(child: Text(l.architectSectionVisibility)),
              Tooltip(
                message: l.architectSectionVisibilityHelp,
                child: const Icon(Icons.info_outline, size: 20),
              ),
            ],
          ),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (section != null) ...[
                    rules(false),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 8),
                  ],
                  rules(true),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.cancel),
            ),
            FilledButton(
              key: const ValueKey('section-visibility-save'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.save),
            ),
          ],
        );
      },
    ),
  );
  if (saved != true) return;
  if (mapEquals(defaults.categories, initial.sectionVisibility.categories) &&
      mapEquals(
        overrides.categories,
        section?.visibility.categories ?? const {},
      )) {
    return;
  }
  final current = controller.project;
  controller.commit(
    current.copyWith(
      sectionVisibility: defaults,
      sections: [
        for (final old in current.sections)
          if (old.id == section?.id)
            old.copyWith(visibility: overrides)
          else
            old,
      ],
    ),
  );
}
