import 'dart:io';
import 'package:flutter/material.dart';
import 'package:kotoview/src/core/icons/app_icon.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../bim_projects/models/bim_coordinate_frame.dart';
import '../../bim_projects/models/bim_work_project.dart';
import '../../bim_projects/services/bim_export_service.dart';
import '../../bim_projects/services/bim_project_library_service.dart';
import '../../bim_projects/services/bim_underlay_loader.dart';
import '../models/architect_project.dart';
import '../services/architect_underlay_service.dart';
import '../widgets/architect_project_wizard_dialog.dart';
import 'architect_workspace_screen.dart';

/// Dedicated Architectural Studio tab displaying user's architectural projects,
/// quick creation wizard (with storey overlays), and blank workspace entry.
class ArchitectStudioTab extends StatefulWidget {
  final BimProjectLibraryService? libraryService;
  const ArchitectStudioTab({super.key, this.libraryService});

  @override
  State<ArchitectStudioTab> createState() => ArchitectStudioTabState();
}

class ArchitectStudioTabState extends State<ArchitectStudioTab>
    with AutomaticKeepAliveClientMixin {
  BimProjectLibraryService get _library =>
      widget.libraryService ?? BimProjectLibraryService.instance;

  bool _isLoading = true;
  List<BimWorkProject> _projects = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    refreshProjects();
  }

  Future<void> refreshProjects() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final all = await _library.listProjects();
    if (mounted) {
      setState(() {
        _projects = all
            .where((p) => p.projectType == BimProjectType.architectural)
            .toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _openArchitectProjectWizard() async {
    final archProject = await ArchitectProjectWizardDialog.show(context);
    if (archProject == null || !mounted) return;

    final storeys = archProject.storeys.map((s) {
      final underlayConfig = archProject.cadUnderlays[s.id];
      return BimStoreyUnderlay(
        storeyId: s.id,
        name: s.name,
        elevation: s.elevation,
        height: s.height,
        sourceFileName: underlayConfig?.fileName,
      );
    }).toList();

    final bimProject = await _library.createProject(
      name: archProject.name,
      storeys: storeys,
      projectType: BimProjectType.architectural,
      initialArchitectProject: archProject,
    );

    // Import and attach any selected CAD underlays into the created project
    final configs = <String, ArchitectCadUnderlayConfig>{};
    for (final entry in archProject.cadUnderlays.entries) {
      final file = entry.value.externalSourcePath != null
          ? File(entry.value.externalSourcePath!)
          : null;
      if (file != null && await file.exists()) {
        try {
          final res = await ArchitectUnderlayService.instance
              .importOrReloadCadUnderlay(
                projectId: bimProject.id,
                storeyId: entry.key,
                sourceFile: file,
                existingConfig: null,
              );
          configs[entry.key] = res.config;
          await _library.attachUnderlayFile(bimProject.id, entry.key, file);
        } catch (e) {
          debugPrint('[ArchitectStudioTab] import underlay error: $e');
        }
      }
    }

    var updatedArchProject = archProject.copyWith(id: bimProject.id);
    if (configs.isNotEmpty) {
      updatedArchProject = updatedArchProject.copyWith(cadUnderlays: configs);
      await _library.saveArchitectProject(bimProject.id, updatedArchProject);
    }

    refreshProjects();

    if (!mounted) return;
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ArchitectWorkspaceScreen(
              initialProject: updatedArchProject,
              bimProject: bimProject,
            ),
          ),
        )
        .then((_) => refreshProjects());
  }

  void _openBlankWorkspace() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(builder: (_) => const ArchitectWorkspaceScreen()),
        )
        .then((_) => refreshProjects());
  }

  Future<void> _openProject(BimWorkProject project) async {
    final archProject = await _library.loadArchitectProject(project.id);
    LoadedBimUnderlays? underlays;
    if (project.hasUnderlays) {
      try {
        underlays = await BimUnderlayLoader.loadAndAlign(
          project: project,
          mode: BimUnderlayLoadMode.architecturalOriginal,
        );
      } catch (_) {}
    }
    if (!mounted) return;
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ArchitectWorkspaceScreen(
              initialProject: archProject,
              bimProject: project,
              underlaysByStorey: underlays?.underlaysByStorey,
              underlayFrame: BimCoordinateFrame(
                origin: underlays?.referenceControlPoint ?? Offset.zero,
                unitsPerMeter: underlays?.cadUnitsPerMeter ?? 1,
              ),
            ),
          ),
        )
        .then((_) => refreshProjects());
  }

  Future<void> _confirmDeleteProject(BimWorkProject project) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.bimProjectDeleteConfirmTitle),
        content: Text(l10n.bimProjectDeleteConfirmMessage(project.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _library.deleteProject(project.id);
      refreshProjects();
    }
  }

  Future<void> _renameProject(BimWorkProject project) async {
    final l10n = context.l10n;
    final controller = TextEditingController(text: project.name);
    final formKey = GlobalKey<FormState>();

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.bimProjectRename),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.bimProjectName,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? l10n.bimProjectName : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(ctx).pop(controller.text.trim());
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && mounted) {
      await _library.renameProject(project.id, newName);
      refreshProjects();
    }
  }

  Future<void> _exportProjectZip(BimWorkProject project) async {
    try {
      final archProject = await _library.loadArchitectProject(project.id);
      if (archProject == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.exportFailed('Architectural model not found'),
              ),
            ),
          );
        }
        return;
      }
      final zipFile = await BimExportService.exportArchitecturalProjectZip(
        project: project,
        architect: archProject,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.bimProjectExportSuccess(
                zipFile.uri.pathSegments.last,
              ),
            ),
            backgroundColor: const Color(0xFF00E676),
          ),
        );
      }
      await BimExportService.shareFile(zipFile);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.exportFailed(e.toString()))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = context.l10n;

    return RefreshIndicator(
      onRefresh: refreshProjects,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroActions(context),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const AppIcon(
                              AppIconId.measureAngle,
                              size: 18,
                              color: Color(0xFFFFB300),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.architectProjectsTitle,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            Text(
                              '${_projects.length}',
                              style: TextStyle(
                                color: Theme.of(context).hintColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                      ],
                    ),
                  ),
                ),
                if (_projects.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(context),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            _buildProjectCard(context, _projects[index]),
                        childCount: _projects.length,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildHeroActions(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFB300).withValues(alpha: 0.18),
            const Color(0xFFF57C00).withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFB300).withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB300).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const AppIcon(
                  AppIconId.measureAngle,
                  color: Color(0xFFFFB300),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.moduleArchitectStudio,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.bimProjectArchitecturalDesc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const AppIcon(AppIconId.add, size: 16),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      l10n.architectNewProject,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB300),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _openArchitectProjectWizard,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const AppIcon(AppIconId.brush, size: 16),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(l10n.architectBlankWorkspace),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _openBlankWorkspace,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB300).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const AppIcon(
                AppIconId.measureAngle,
                size: 48,
                color: Color(0xFFFFB300),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              l10n.architectProjectsTitle,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.architectNoProjects,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).hintColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const AppIcon(AppIconId.add),
              label: Text(l10n.architectNewProject),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB300),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _openArchitectProjectWizard,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectCard(BuildContext context, BimWorkProject project) {
    final l10n = context.l10n;
    final formattedDate =
        '${project.updatedAt.day.toString().padLeft(2, '0')}.${project.updatedAt.month.toString().padLeft(2, '0')}.${project.updatedAt.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFB300).withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const AppIcon(
                    AppIconId.measureAngle,
                    size: 20,
                    color: Color(0xFFFFB300),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        project.location.isNotEmpty
                            ? '${project.location} • $formattedDate'
                            : formattedDate,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const AppIcon(AppIconId.moreVertical, size: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (val) {
                    if (val == 'rename') _renameProject(project);
                    if (val == 'delete') _confirmDeleteProject(project);
                    if (val == 'export') {
                      _exportProjectZip(project);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          const AppIcon(AppIconId.edit, size: 16),
                          const SizedBox(width: 10),
                          Text(l10n.bimProjectRename),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'export',
                      child: Row(
                        children: [
                          const AppIcon(AppIconId.download, size: 16),
                          const SizedBox(width: 10),
                          Text(l10n.bimProjectExportAllZip),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const AppIcon(
                            AppIconId.delete,
                            size: 16,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            l10n.delete,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppIcon(AppIconId.layers, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        l10n.bimProjectStoreysCount(project.storeys.length),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (project.hasUnderlays) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AppIcon(
                          AppIconId.cadUnderlay,
                          size: 13,
                          color: Color(0xFF00B0FF),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.architectWizardStoreyOverlay,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0091EA),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const AppIcon(AppIconId.visible, size: 16),
                label: Text(
                  l10n.bimProjectOpen,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB300),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _openProject(project),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
