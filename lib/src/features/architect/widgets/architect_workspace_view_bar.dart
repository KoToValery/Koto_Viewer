import 'package:kotoview/src/core/icons/app_icon.dart';
import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../services/architect_workspace_view_controller.dart';
import 'architect_elevation_labels.dart';

class ArchitectWorkspaceViewBar extends StatelessWidget {
  static double heightFor(BuildContext context) =>
      48 +
      (MediaQuery.textScalerOf(context).scale(32) - 32).clamp(
        0,
        double.infinity,
      );

  final ArchitectProject project;
  final ArchitectWorkspaceView view;
  final ArchitectPlanMode planMode;
  final String? viewId;
  final Map<ArchitectWorkspaceView, String> lastViewIds;
  final bool is3D;
  final bool isPrintPreview;
  final void Function(ArchitectWorkspaceView, String?) onSelected;
  final ValueChanged<ArchitectWorkspaceView> onManage;
  final void Function(ArchitectWorkspaceView, String?, String)? onDraft;
  final VoidCallback? onReturnToPlan;
  final VoidCallback? onToggle3D;

  const ArchitectWorkspaceViewBar({
    super.key,
    required this.project,
    required this.view,
    this.planMode = ArchitectPlanMode.floor,
    required this.viewId,
    required this.lastViewIds,
    this.is3D = false,
    this.isPrintPreview = false,
    required this.onSelected,
    required this.onManage,
    this.onDraft,
    this.onReturnToPlan,
    this.onToggle3D,
  });

  Widget _buildTabContent({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool active,
    required bool quickReturn,
  }) {
    final borderColor = active
        ? Colors.cyanAccent
        : (quickReturn
              ? Colors.cyanAccent.withValues(alpha: 0.45)
              : Colors.white12);
    return Container(
      height: heightFor(context),
      decoration: BoxDecoration(
        color: quickReturn ? Colors.cyanAccent.withValues(alpha: 0.12) : null,
        border: Border(
          bottom: BorderSide(
            color: borderColor,
            width: active ? 2 : (quickReturn ? 1.5 : 1),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          if (quickReturn) ...[
            const AppIcon(
              AppIconId.back,
              size: 14,
              color: Colors.cyanAccent,
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: quickReturn
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: (active || quickReturn)
                          ? Colors.cyanAccent
                          : Colors.white70,
                    ),
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
              ],
            ),
          ),
          if (!quickReturn)
            const AppIcon(
              AppIconId.expandMore,
              size: 16,
              color: Colors.white70,
            ),
        ],
      ),
    );
  }

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
    final isPlanCanvas =
        !is3D && !isPrintPreview && view == ArchitectWorkspaceView.plan;
    return Material(
      color: const Color(0xFF1E1E26),
      child: Row(
        children: [
          for (final type in ArchitectWorkspaceView.values)
            Expanded(
              child: Builder(
                builder: (context) {
                  final title = switch (type) {
                    ArchitectWorkspaceView.plan => l.architectFacadePlan,
                    ArchitectWorkspaceView.elevation => l.architectFacades,
                    ArchitectWorkspaceView.section => l.buildingSections,
                  };
                  final subtitle = switch (type) {
                    ArchitectWorkspaceView.plan =>
                      project.activeStorey.isRoof
                          ? l.architectRoofPlan
                          : (planMode == ArchitectPlanMode.ceilingServices
                                ? '${project.activeStorey.elevationLabel} · ${l.architectCeilingPlanShort}'
                                : project.activeStorey.elevationLabel),
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
                  };
                  final quickReturn =
                      type == ArchitectWorkspaceView.plan &&
                      !isPlanCanvas &&
                      onReturnToPlan != null;
                  if (quickReturn) {
                    return Tooltip(
                      message: l.architectBackToPlan,
                      child: InkWell(
                        key: ValueKey('architect-view-${type.name}'),
                        onTap: onReturnToPlan,
                        child: _buildTabContent(
                          context: context,
                          title: title,
                          subtitle: subtitle,
                          active: false,
                          quickReturn: true,
                        ),
                      ),
                    );
                  }
                  final active = !is3D && type == view;
                  return PopupMenuButton<String>(
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
                        'copy_by_storey',
                        'add_ceiling_plan',
                        'remove_ceiling_plan',
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
                    for (final s in project.orderedPlanStoreys) ...[
                      CheckedPopupMenuItem(
                        value: s.id,
                        checked:
                            s.id == project.activeStoreyId &&
                            (s.isRoof ||
                                planMode == ArchitectPlanMode.floor),
                        child: Row(
                          children: [
                            if (s.isRoof) ...[
                              const AppIcon(
                                AppIconId.roof,
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
                      if (!s.isRoof && s.hasCeilingPlan)
                        CheckedPopupMenuItem(
                          value: 'ceiling:${s.id}',
                          checked:
                              s.id == project.activeStoreyId &&
                              planMode == ArchitectPlanMode.ceilingServices,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 14),
                            child: Row(
                              children: [
                                const AppIcon(
                                  AppIconId.layoutGrid,
                                  size: 16,
                                  color: Color(0xFF00E5FF),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    l.architectCeilingPlan,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                    if (!project.activeStorey.isRoof &&
                        !project.activeStorey.hasCeilingPlan)
                      PopupMenuItem(
                        value: 'add_ceiling_plan',
                        child: Row(
                          children: [
                            const AppIcon(
                              AppIconId.layoutGrid,
                              size: 18,
                              color: Color(0xFF00E5FF),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(l.architectAddCeilingPlan)),
                          ],
                        ),
                      ),
                    if (!project.activeStorey.isRoof &&
                        project.activeStorey.hasCeilingPlan &&
                        project.activeStorey.ceilings.isEmpty)
                      PopupMenuItem(
                        value: 'remove_ceiling_plan',
                        child: Row(
                          children: [
                            const AppIcon(
                              AppIconId.layoutGrid,
                              size: 18,
                              color: Colors.white54,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(l.architectRemoveCeilingPlan)),
                          ],
                        ),
                      ),
                    if (project.roofStorey == null)
                      PopupMenuItem(
                        value: 'add_roof_plan',
                        child: Row(
                          children: [
                            const AppIcon(
                              AppIconId.newBuilding,
                              size: 18,
                              color: Color(0xFF00E5FF),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(l.architectAddRoofPlan)),
                          ],
                        ),
                      ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'copy_by_storey',
                      child: AppMenuLabel(
                        icon: AppIconId.duplicate,
                        child: Text(l.architectCopyElementsByStorey),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'manage',
                      child: AppMenuLabel(
                        icon: AppIconId.properties,
                        child: Text(l.architectManageStoreys),
                      ),
                    ),
                  ],
                  if (type == ArchitectWorkspaceView.elevation)
                    for (var i = 0; i < project.elevations.length; i++)
                      CheckedPopupMenuItem(
                        value: project.elevations[i].id,
                        checked: viewId == project.elevations[i].id,
                        child: AppMenuLabel(
                          icon: AppIconId.elevation,
                        child: Text(
                          '${architectElevationLabel(l, project.elevations[i], (project.northSymbol?.angle ?? 0))} · ${i + 1}',
                        ),
                      ),
                      ),
                  if (type == ArchitectWorkspaceView.section)
                    for (var i = 0; i < project.sections.length; i++)
                      CheckedPopupMenuItem(
                        value: project.sections[i].id,
                        checked: viewId == project.sections[i].id,
                        child: AppMenuLabel(
                          icon: AppIconId.section,
                          child: Text(
                          project.sections[i].name.isNotEmpty
                              ? project.sections[i].name
                              : l.architectSectionNumber(i + 1),
                        ),
                      ),
                      ),
                  if (type != ArchitectWorkspaceView.plan)
                    PopupMenuItem(
                      value: 'new',
                      child: AppMenuLabel(
                        icon: AppIconId.add,
                        child: Text(
                        type == ArchitectWorkspaceView.section
                            ? l.buildingSectionNew
                            : l.architectFacadeNew,
                        ),
                      ),
                    ),
                  if (type != ArchitectWorkspaceView.plan &&
                      (type == ArchitectWorkspaceView.section
                          ? section != null
                          : elevation != null)) ...[
                    PopupMenuItem(
                      value: 'edit',
                      child: AppMenuLabel(
                        icon: AppIconId.edit,
                        child: Text(l.architectFacadeEdit),
                    ),
                    ),
                    PopupMenuItem(
                      value: 'depth',
                      child: AppMenuLabel(
                        icon: AppIconId.dimension,
                        child: Text(l.architectViewDepth),
                    ),
                    ),
                    PopupMenuItem(
                      value: 'step',
                      child: AppMenuLabel(
                        icon: AppIconId.stairs,
                        child: Text(l.architectViewStep),
                    ),
                    ),
                    PopupMenuItem(
                      value: 'straight',
                      child: AppMenuLabel(
                        icon: AppIconId.line,
                        child: Text(l.architectViewStraight),
                    ),
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
                      child: AppMenuLabel(
                        icon: AppIconId.properties,
                        child: Text(l.architectManageViews),
                      ),
                    ),
                  if (type == ArchitectWorkspaceView.section)
                    PopupMenuItem(
                      value: 'visibility',
                      key: const ValueKey('architect-section-visibility'),
                      child: AppMenuLabel(
                        icon: AppIconId.visible,
                        child: Text(l.architectViewVisibility),
                      ),
                    ),
                ],
                    child: _buildTabContent(
                      context: context,
                      title: title,
                      subtitle: subtitle,
                      active: active,
                      quickReturn: false,
                    ),
                  );
                },
              ),
            ),
          if (onToggle3D != null)
            Tooltip(
              message: is3D ? l.architectView2D : l.architectView3D,
              child: InkWell(
                key: const ValueKey('architect-view-3d'),
                onTap: onToggle3D,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 46),
                  height: heightFor(context),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: is3D
                        ? Colors.cyanAccent.withValues(alpha: 0.14)
                        : null,
                    border: Border(
                      left: const BorderSide(color: Colors.white12),
                      bottom: BorderSide(
                        color: is3D ? Colors.cyanAccent : Colors.white12,
                        width: is3D ? 2 : 1,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppIcon(
                        AppIconId.view3D,
                        size: 16,
                        color: is3D ? Colors.cyanAccent : Colors.white70,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        l.architectView3DShort,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              is3D ? FontWeight.w700 : FontWeight.w500,
                          color: is3D ? Colors.cyanAccent : Colors.white,
                        ),
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
