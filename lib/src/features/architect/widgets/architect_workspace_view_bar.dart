import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../services/architect_workspace_view_controller.dart';
import 'architect_elevation_labels.dart';

class ArchitectWorkspaceViewBar extends StatelessWidget {
  final ArchitectProject project;
  final ArchitectWorkspaceView view;
  final String? viewId;
  final Map<ArchitectWorkspaceView, String> lastViewIds;
  final void Function(ArchitectWorkspaceView, String?) onSelected;
  final ValueChanged<ArchitectWorkspaceView> onManage;
  final void Function(ArchitectWorkspaceView, String?, String)? onDraft;

  const ArchitectWorkspaceViewBar({
    super.key,
    required this.project,
    required this.view,
    required this.viewId,
    required this.lastViewIds,
    required this.onSelected,
    required this.onManage,
    this.onDraft,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final elevation = project.elevations
        .where(
          (e) =>
              e.id ==
              (view == ArchitectWorkspaceView.elevation
                  ? viewId
                  : lastViewIds[ArchitectWorkspaceView.elevation]),
        )
        .firstOrNull;
    final section = project.sections
        .where(
          (e) =>
              e.id ==
              (view == ArchitectWorkspaceView.section
                  ? viewId
                  : lastViewIds[ArchitectWorkspaceView.section]),
        )
        .firstOrNull;
    return Material(
      color: const Color(0xFF1E1E26),
      child: Row(
        children: [
          for (final type in ArchitectWorkspaceView.values)
            Expanded(
              child: PopupMenuButton<String>(
                key: ValueKey('architect-view-${type.name}'),
                tooltip: switch (type) {
                  ArchitectWorkspaceView.plan => l.architectStoreys,
                  ArchitectWorkspaceView.elevation => l.architectFacades,
                  ArchitectWorkspaceView.section => l.buildingSections,
                },
                onSelected: (id) {
                  if ([
                    'new',
                    'edit',
                    'depth',
                    'step',
                    'straight',
                    'visibility',
                  ].contains(id)) {
                    onDraft?.call(
                      type,
                      type == ArchitectWorkspaceView.section
                          ? section?.id
                          : elevation?.id,
                      id,
                    );
                    return;
                  }
                  if (id == 'manage') {
                    onManage(type);
                  } else {
                    onSelected(type, id);
                  }
                },
                itemBuilder: (_) => [
                  if (type == ArchitectWorkspaceView.plan) ...[
                    for (final s in project.orderedPlanStoreys)
                      CheckedPopupMenuItem(
                        value: s.id,
                        checked: s.id == project.activeStoreyId,
                        child: Row(
                          children: [
                            if (s.isRoof) ...[
                              const Icon(
                                Icons.roofing,
                                size: 18,
                                color: Color(0xFF00E5FF),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l.architectRoofPlan,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ] else ...[
                              Expanded(
                                child: Text(
                                  s.name.contains(s.elevationLabel)
                                      ? s.name
                                      : '${s.name} · ${s.elevationLabel}',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (project.roofStorey == null)
                      PopupMenuItem(
                        value: 'add_roof_plan',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.add_home_work_outlined,
                              size: 18,
                              color: Color(0xFF00E5FF),
                            ),
                            const SizedBox(width: 8),
                            Text(l.architectAddRoofPlan),
                          ],
                        ),
                      ),
                  ],
                  if (type == ArchitectWorkspaceView.elevation)
                    for (var i = 0; i < project.elevations.length; i++)
                      CheckedPopupMenuItem(
                        value: project.elevations[i].id,
                        checked: viewId == project.elevations[i].id,
                        child: Text(
                          '${architectElevationLabel(l, project.elevations[i], (project.northSymbol?.angle ?? 0))} · ${i + 1}',
                        ),
                      ),
                  if (type == ArchitectWorkspaceView.section)
                    for (var i = 0; i < project.sections.length; i++)
                      CheckedPopupMenuItem(
                        value: project.sections[i].id,
                        checked: viewId == project.sections[i].id,
                        child: Text(
                          project.sections[i].name.isNotEmpty
                              ? project.sections[i].name
                              : l.architectSectionNumber(i + 1),
                        ),
                      ),
                  if (type != ArchitectWorkspaceView.plan)
                    PopupMenuItem(
                      value: 'new',
                      child: Text(
                        type == ArchitectWorkspaceView.section
                            ? l.buildingSectionNew
                            : l.architectFacadeNew,
                      ),
                    ),
                  if (type != ArchitectWorkspaceView.plan &&
                      (type == ArchitectWorkspaceView.section
                          ? section != null
                          : elevation != null)) ...[
                    PopupMenuItem(
                      value: 'edit',
                      child: Text(l.architectFacadeEdit),
                    ),
                    PopupMenuItem(
                      value: 'depth',
                      child: Text(l.architectViewDepth),
                    ),
                    PopupMenuItem(
                      value: 'step',
                      child: Text(l.architectViewStep),
                    ),
                    PopupMenuItem(
                      value: 'straight',
                      child: Text(l.architectViewStraight),
                    ),
                  ],
                  if (type != ArchitectWorkspaceView.plan)
                    PopupMenuItem(
                      value: 'manage',
                      key: ValueKey(
                        type == ArchitectWorkspaceView.elevation
                            ? 'architect-building-elevations'
                            : 'architect-building-sections',
                      ),
                      child: Text(l.architectManageViews),
                    ),
                  if (type == ArchitectWorkspaceView.section)
                    PopupMenuItem(
                      value: 'visibility',
                      key: const ValueKey('architect-section-visibility'),
                      child: Text(l.architectViewVisibility),
                    ),
                ],
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: type == view
                            ? Colors.cyanAccent
                            : Colors.white12,
                        width: type == view ? 2 : 1,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              switch (type) {
                                ArchitectWorkspaceView.plan =>
                                  l.architectFacadePlan,
                                ArchitectWorkspaceView.elevation =>
                                  l.architectFacades,
                                ArchitectWorkspaceView.section =>
                                  l.buildingSections,
                              },
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: type == view
                                    ? Colors.cyanAccent
                                    : Colors.white70,
                              ),
                            ),
                            Text(
                              switch (type) {
                                ArchitectWorkspaceView.plan =>
                                  project.activeStorey.isRoof
                                      ? l.architectRoofPlan
                                      : project.activeStorey.elevationLabel,
                                ArchitectWorkspaceView.elevation =>
                                  elevation == null
                                      ? '—'
                                      : architectElevationLabel(
                                          l,
                                          elevation,
                                          (project.northSymbol?.angle ?? 0),
                                        ),
                                ArchitectWorkspaceView.section =>
                                  section == null
                                      ? '—'
                                      : section.name.isNotEmpty
                                      ? section.name
                                      : l.architectSectionNumber(
                                          project.sections.indexOf(section) + 1,
                                        ),
                              },
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_drop_down,
                        size: 18,
                        color: Colors.white70,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
