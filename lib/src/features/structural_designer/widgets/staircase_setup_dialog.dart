import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../analysis/staircase_inventory.dart';
import '../models/structural_element.dart';

enum StaircaseSetupAction { save, zone, opening, detect }

class StaircaseSetupResult {
  final StructuralProject project;
  final StaircaseSetupAction action;
  final String? coreId, storeyId;
  const StaircaseSetupResult(
    this.project,
    this.action, {
    this.coreId,
    this.storeyId,
  });
}

class StaircaseSetupDialog extends StatefulWidget {
  final StructuralProject project;
  final double scale;
  const StaircaseSetupDialog({
    super.key,
    required this.project,
    required this.scale,
  });
  @override
  State<StaircaseSetupDialog> createState() => _StaircaseSetupDialogState();
}

class _StaircaseSetupDialogState extends State<StaircaseSetupDialog> {
  late StructuralProject project = StaircaseInventory.adoptExisting(
    widget.project,
    widget.scale,
  );
  late bool noStairs =
      project.staircaseReviewComplete && project.staircases.isEmpty;
  void finish(StaircaseSetupAction action, {String? coreId, String? storeyId}) {
    Navigator.pop(
      context,
      StaircaseSetupResult(
        project.copyWith(staircaseReviewComplete: true),
        action,
        coreId: coreId,
        storeyId: storeyId,
      ),
    );
  }

  void update(StaircaseCore core) => setState(
    () => project = project.copyWith(
      staircases: [
        for (final c in project.staircases) c.id == core.id ? core : c,
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final floors = project.storeys.toList()
      ..sort((a, b) => a.elevation.compareTo(b.elevation));
    final inventory = StaircaseInventory.evaluate(
      project.copyWith(staircaseReviewComplete: true),
      widget.scale,
    );
    return AlertDialog(
      title: Text(l.staircaseSetupTitle),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.staircaseSetupHint),
              const SizedBox(height: 12),
              if (project.staircases.isEmpty)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.staircaseNoStairs),
                  value: noStairs,
                  onChanged: (v) => setState(() => noStairs = v ?? false),
                ),
              for (final core in project.staircases) ...[
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        core.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: l.delete,
                      onPressed: () => setState(
                        () => project = project.copyWith(
                          staircases: project.staircases
                              .where((c) => c.id != core.id)
                              .toList(),
                          storeys: [
                            for (final s in project.storeys)
                              s.copyWith(
                                staircaseZones: {
                                  for (final e in s.staircaseZones.entries)
                                    if (e.key != core.id) e.key: e.value,
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey('${core.id}/start'),
                  initialValue: floors.any((s) => s.id == core.startStoreyId)
                      ? core.startStoreyId
                      : null,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l.staircaseStart),
                  items: [
                    for (final s in floors)
                      DropdownMenuItem(
                        value: s.id,
                        child: Text(s.elevationLabel),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) update(core.copyWith(startStoreyId: v));
                  },
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey('${core.id}/end'),
                  initialValue: floors.any((s) => s.id == core.endStoreyId)
                      ? core.endStoreyId
                      : null,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l.staircaseEnd),
                  items: [
                    for (final s in floors)
                      DropdownMenuItem(
                        value: s.id,
                        child: Text(s.elevationLabel),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) update(core.copyWith(endStoreyId: v));
                  },
                ),
                if (StaircaseInventory.levels(project, core).isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      l.staircaseScopeMissing,
                      style: const TextStyle(color: Colors.orange),
                    ),
                  ),
                for (final s in StaircaseInventory.levels(project, core))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.elevationLabel,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          inventory.gaps.any(
                                (g) =>
                                    g.coreId == core.id &&
                                    g.storeyId == s.id &&
                                    g.requirement ==
                                        StaircaseRequirement.circulation,
                              )
                              ? l.staircaseZoneMissing
                              : l.staircaseZoneReady,
                        ),
                        if (s.id != core.startStoreyId)
                          Text(
                            inventory.gaps.any(
                                  (g) =>
                                      g.coreId == core.id &&
                                      g.storeyId == s.id &&
                                      g.requirement ==
                                          StaircaseRequirement.opening,
                                )
                                ? l.staircaseOpeningMissing
                                : l.staircaseOpeningReady,
                          ),
                        Wrap(
                          spacing: 6,
                          children: [
                            TextButton(
                              onPressed: () => finish(
                                StaircaseSetupAction.zone,
                                coreId: core.id,
                                storeyId: s.id,
                              ),
                              child: Text(l.staircaseDrawZone),
                            ),
                            TextButton(
                              onPressed: () => finish(
                                StaircaseSetupAction.detect,
                                coreId: core.id,
                                storeyId: s.id,
                              ),
                              child: Text(l.staircaseDetect),
                            ),
                            if (s.id != core.startStoreyId)
                              TextButton(
                                onPressed: () => finish(
                                  StaircaseSetupAction.opening,
                                  coreId: core.id,
                                  storeyId: s.id,
                                ),
                                child: Text(l.staircaseDrawOpening),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
              if (floors.length > 1)
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(l.staircaseAdd),
                  onPressed: () => setState(() {
                    noStairs = false;
                    final id =
                        'stairs_${DateTime.now().microsecondsSinceEpoch}';
                    var number = 1;
                    while (project.staircases.any(
                      (c) => c.name == '${l.openingStaircaseTitle} $number',
                    )) {
                      number++;
                    }
                    project = project.copyWith(
                      staircases: [
                        ...project.staircases,
                        StaircaseCore(
                          id: id,
                          name: '${l.openingStaircaseTitle} $number',
                          startStoreyId: floors.first.id,
                          endStoreyId: floors.last.id,
                        ),
                      ],
                    );
                  }),
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
        FilledButton(
          onPressed: project.staircases.isNotEmpty || noStairs
              ? () => finish(StaircaseSetupAction.save)
              : null,
          child: Text(l.save),
        ),
      ],
    );
  }
}
