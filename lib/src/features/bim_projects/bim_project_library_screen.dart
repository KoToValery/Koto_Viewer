import 'package:flutter/material.dart';
import '../../core/l10n/l10n_extensions.dart';
import 'models/bim_work_project.dart';
import 'screens/bim_alignment_screen.dart';
import 'screens/bim_workspace_screen.dart';
import 'services/bim_export_service.dart';
import 'services/bim_project_library_service.dart';
import 'widgets/bim_new_project_wizard.dart';

/// Screen listing all user's standalone BiM Work Projects with options to
/// open, align, rename, export ZIP packages, or create new projects.
class BimProjectLibraryScreen extends StatefulWidget {
  const BimProjectLibraryScreen({super.key});

  @override
  State<BimProjectLibraryScreen> createState() => _BimProjectLibraryScreenState();
}

class _BimProjectLibraryScreenState extends State<BimProjectLibraryScreen> {
  bool _isLoading = true;
  List<BimWorkProject> _projects = [];

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoading = true);
    final projects = await BimProjectLibraryService.instance.listProjects();
    if (mounted) {
      setState(() {
        _projects = projects;
        _isLoading = false;
      });
    }
  }

  void _openNewProjectWizard() {
    BimNewProjectWizard.show(
      context,
      onProjectCreatedWithProject: (newProject) {
        _loadProjects();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BimAlignmentScreen(project: newProject),
          ),
        ).then((_) => _loadProjects());
      },
    );
  }

  void _openProject(BimWorkProject project) {
    if (!project.isAligned) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.bimProjectAlignFirstPrompt),
          backgroundColor: const Color(0xFFF57C00),
          action: SnackBarAction(
            label: context.l10n.bimProjectAlignStoreys,
            textColor: Colors.white,
            onPressed: () => _openAlignment(project),
          ),
        ),
      );
      _openAlignment(project);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BimWorkspaceScreen(project: project),
      ),
    ).then((_) => _loadProjects());
  }

  void _openAlignment(BimWorkProject project) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BimAlignmentScreen(project: project),
      ),
    ).then((_) => _loadProjects());
  }

  Future<void> _exportProjectZip(BimWorkProject project) async {
    try {
      final structural = await BimProjectLibraryService.instance.loadStructuralProject(project.id);
      if (structural == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.exportFailed('Model not found'))),
          );
        }
        return;
      }

      final zipFile = await BimExportService.exportProjectZip(
        project: project,
        structural: structural,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.bimProjectExportSuccess(zipFile.uri.pathSegments.last)),
            backgroundColor: const Color(0xFF1E88E5),
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

  Future<void> _confirmDeleteProject(BimWorkProject project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: Text(
          context.l10n.bimProjectDeleteConfirmTitle,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          context.l10n.bimProjectDeleteConfirmMessage(project.name),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.cancel, style: const TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.delete, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await BimProjectLibraryService.instance.deleteProject(project.id);
      _loadProjects();
    }
  }

  Future<void> _promptRenameProject(BimWorkProject project) async {
    final controller = TextEditingController(text: project.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: Text(
          context.l10n.bimProjectRename,
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: context.l10n.bimProjectNameHint,
            hintStyle: const TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.cancel, style: const TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.save, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.trim().isNotEmpty) {
      await BimProjectLibraryService.instance.renameProject(project.id, controller.text.trim());
      _loadProjects();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: const Color(0xFF121216),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A22),
        elevation: 0,
        title: Text(
          l10n.bimProjectLibraryTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: l10n.bimProjectNew,
            onPressed: _openNewProjectWizard,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
          : _projects.isEmpty
              ? _buildEmptyState(context)
              : RefreshIndicator(
                  color: const Color(0xFF00E5FF),
                  backgroundColor: const Color(0xFF1E1E24),
                  onRefresh: _loadProjects,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    itemCount: _projects.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final project = _projects[index];
                      return _buildProjectCard(context, project);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF00E5FF),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          l10n.bimProjectNew,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: _openNewProjectWizard,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = context.l10n;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.apartment_rounded,
                size: 64,
                color: Color(0xFF00E5FF),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.bimProjects,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.bimProjectNoProjects,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.bimProjectNew),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _openNewProjectWizard,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectCard(BuildContext context, BimWorkProject project) {
    final l10n = context.l10n;
    final isReady = project.isAligned;
    final formattedDate =
        '${project.updatedAt.day.toString().padLeft(2, '0')}.${project.updatedAt.month.toString().padLeft(2, '0')}.${project.updatedAt.year}';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isReady
              ? const Color(0xFF00E5FF).withValues(alpha: 0.3)
              : Colors.white10,
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openProject(project),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Title, Location and Popup Menu
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.apartment_rounded,
                        color: Color(0xFF00E5FF),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (project.location.isNotEmpty) ...[
                                const Icon(Icons.location_on_outlined, color: Colors.white54, size: 13),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    project.location,
                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text('•', style: TextStyle(color: Colors.white38, fontSize: 12)),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                formattedDate,
                                style: const TextStyle(color: Colors.white38, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, color: Colors.white60),
                      color: const Color(0xFF282832),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (val) {
                        switch (val) {
                          case 'export':
                            _exportProjectZip(project);
                            break;
                          case 'rename':
                            _promptRenameProject(project);
                            break;
                          case 'delete':
                            _confirmDeleteProject(project);
                            break;
                        }
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'export',
                          child: Row(
                            children: [
                              const Icon(Icons.folder_zip_rounded, color: Color(0xFF00E5FF), size: 18),
                              const SizedBox(width: 10),
                              Text(l10n.bimProjectExportAllZip, style: const TextStyle(color: Colors.white, fontSize: 13)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: [
                              const Icon(Icons.edit_rounded, color: Colors.white70, size: 18),
                              const SizedBox(width: 10),
                              Text(l10n.bimProjectRename, style: const TextStyle(color: Colors.white, fontSize: 13)),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(height: 8),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                              const SizedBox(width: 10),
                              Text(l10n.delete, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Badges row: Storeys count, Status Badge
                Row(
                  children: [
                    // Storeys badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.layers_outlined, size: 14, color: Colors.white70),
                          const SizedBox(width: 6),
                          Text(
                            l10n.bimProjectStoreysCount(project.storeys.length),
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isReady
                            ? const Color(0xFF00E676).withValues(alpha: 0.15)
                            : const Color(0xFFFF9100).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isReady ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                            size: 14,
                            color: isReady ? const Color(0xFF00E676) : const Color(0xFFFF9100),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isReady ? l10n.bimProjectStatusReady : l10n.bimProjectStatusAlignment,
                            style: TextStyle(
                              color: isReady ? const Color(0xFF00E676) : const Color(0xFFFF9100),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Action buttons: Open Model & Align Drawings
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.visibility_rounded, size: 16),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            l10n.bimProjectOpen,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E5FF),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _openProject(project),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.architecture_rounded, size: 16),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            l10n.bimProjectAlignStoreys,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _openAlignment(project),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
