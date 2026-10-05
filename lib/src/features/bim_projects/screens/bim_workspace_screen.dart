import 'package:flutter/material.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../../structural_designer/models/structural_bim_context.dart';
import '../../structural_designer/models/structural_element.dart';
import '../../structural_designer/services/structural_persistence_service.dart';
import '../../structural_designer/structural_designer_screen.dart';
import '../models/bim_work_project.dart';
import '../services/bim_export_service.dart';
import '../services/bim_project_library_service.dart';
import '../services/bim_underlay_loader.dart';
import 'bim_alignment_screen.dart';

/// Workspace screen that loads an entire multi-storey BiM Work Project,
/// coordinates its transformed CAD underlays, binds autosave and storey synchronization,
/// and embeds the full [StructuralDesignerScreen] with BiM context.
class BimWorkspaceScreen extends StatefulWidget {
  final BimWorkProject project;

  const BimWorkspaceScreen({
    super.key,
    required this.project,
  });

  @override
  State<BimWorkspaceScreen> createState() => _BimWorkspaceScreenState();
}

class _BimWorkspaceScreenState extends State<BimWorkspaceScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  late BimWorkProject _project;
  StructuralProject? _structuralProject;
  LoadedBimUnderlays? _underlays;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _loadWorkspace();
  }

  Future<void> _loadWorkspace() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final latestProject =
          await BimProjectLibraryService.instance.getProject(_project.id) ?? _project;

      // Load and align all underlays into unified coordinate space
      final loadedUnderlays = await BimUnderlayLoader.loadAndAlign(project: latestProject);

      // Load or initialize structural model
      StructuralProject? structural =
          await BimProjectLibraryService.instance.loadStructuralProject(latestProject.id);

      if (structural == null || structural.storeys.isEmpty) {
        // Initialize structural storeys matching the project storeys
        final storeys = latestProject.storeys.map((s) {
          return StoreyLevel(
            id: s.storeyId,
            name: s.name,
            elevation: s.elevation,
            height: s.height,
          );
        }).toList();

        // Default active storey: ground floor (elevation near 0) or first above-ground
        int activeIdx = storeys.indexWhere((s) => s.elevation.abs() < 1e-4);
        if (activeIdx == -1) {
          activeIdx = storeys.indexWhere((s) => s.elevation >= 0);
          if (activeIdx == -1) activeIdx = 0;
        }

        structural = StructuralProject(
          title: latestProject.name,
          storeys: storeys.isNotEmpty
              ? storeys
              : const [StoreyLevel(id: 'default_ground', name: 'Ground Floor', elevation: 0.0, height: 3.0)],
          activeStoreyIndex: activeIdx.clamp(0, (storeys.length - 1).clamp(0, 999)),
        );

        await BimProjectLibraryService.instance.saveStructuralProject(latestProject.id, structural);
      }

      if (mounted) {
        setState(() {
          _project = latestProject;
          _structuralProject = structural;
          _underlays = loadedUnderlays;
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('Error loading BiM workspace: $e\n$stack');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _onProjectChanged(StructuralProject updated) {
    _structuralProject = updated;
    BimProjectLibraryService.instance.saveStructuralProject(_project.id, updated);
  }

  void _onLayerVisibilityChanged(String storeyId, Map<String, bool> layerVisibility) {
    final updatedStoreys = _project.storeys.map((s) {
      if (s.storeyId == storeyId) {
        return s.copyWith(layerVisibility: Map<String, bool>.from(layerVisibility));
      }
      return s;
    }).toList();

    _project = _project.copyWith(storeys: updatedStoreys);
    BimProjectLibraryService.instance.saveProjectManifest(_project);
  }

  void _onWallsDetected(String storeyId) {
    // Wall detection completed on a storey
  }

  Future<void> _handleExport(BuildContext context, StructuralProject project, String activeStoreyId) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.share_rounded, color: Color(0xFF00E5FF), size: 22),
                  const SizedBox(width: 10),
                  Text(
                    context.l10n.exportBimModel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Storey DXF Export
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.architecture_rounded, color: Color(0xFFFFB300)),
                ),
                title: Text(
                  context.l10n.bimProjectExportStoreyDxf,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  context.l10n.bimProjectExportStoreyDxfSubtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  try {
                    final file = await BimExportService.exportStoreyDxf(
                      project: _project,
                      structural: project,
                      storeyId: activeStoreyId,
                      cadUnitsPerMeter: _underlays?.cadUnitsPerMeter ?? 1.0,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.l10n.bimProjectExportSuccess(file.uri.pathSegments.last)),
                          backgroundColor: const Color(0xFF1E88E5),
                        ),
                      );
                    }
                    await BimExportService.shareFile(file);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.l10n.exportFailed(e.toString()))),
                      );
                    }
                  }
                },
              ),
              const Divider(color: Colors.white12),
              // Full Project Package ZIP Export
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.folder_zip_rounded, color: Color(0xFF00E5FF)),
                ),
                title: Text(
                  context.l10n.bimProjectExportAllZip,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  context.l10n.bimProjectExportAllZipSubtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  try {
                    final file = await BimExportService.exportProjectZip(
                      project: _project,
                      structural: project,
                      cadUnitsPerMeter: _underlays?.cadUnitsPerMeter ?? 1.0,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.l10n.bimProjectExportSuccess(file.uri.pathSegments.last)),
                          backgroundColor: const Color(0xFF1E88E5),
                        ),
                      );
                    }
                    await BimExportService.shareFile(file);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.l10n.exportFailed(e.toString()))),
                      );
                    }
                  }
                },
              ),
              const Divider(color: Colors.white12),
              // BiM Model JSON Export
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFAB47BC).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.data_object_rounded, color: Color(0xFFAB47BC)),
                ),
                title: Text(
                  context.l10n.exportBimJson,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'JSON (.bim.json)',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  try {
                    final file = await StructuralPersistenceService.exportToJsonFile(
                      project: project,
                      baseName: _project.name,
                    );
                    await StructuralPersistenceService.shareFile(file);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.l10n.exportFailed(e.toString()))),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openStoreyManager() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BimAlignmentScreen(
          project: _project,
        ),
      ),
    );
    if (mounted) {
      _loadWorkspace();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF121216),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF00E5FF)),
              const SizedBox(height: 20),
              Text(
                context.l10n.bimProjectLoading,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null || _structuralProject == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF121216),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1A22),
          title: Text(_project.name),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Failed to load project',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(context.l10n.retry),
                  onPressed: _loadWorkspace,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final underlaysMap = _underlays?.underlaysByStorey ?? {};
    final projectBounds = _underlays?.projectBounds ?? Rect.zero;
    final unitsPerMeter = _underlays?.cadUnitsPerMeter ?? 1.0;

    // Active underlay document fallback
    final activeStoreyId = _structuralProject!.activeStorey.id;
    final primaryDoc = underlaysMap[activeStoreyId] ??
        (underlaysMap.isNotEmpty ? underlaysMap.values.first : DxfDocument.empty());

    final bimContext = StructuralBimContext(
      underlaysByStorey: underlaysMap,
      projectBounds: projectBounds,
      cadUnitsPerMeter: unitsPerMeter,
      onProjectChanged: _onProjectChanged,
      onLayerVisibilityChanged: _onLayerVisibilityChanged,
      onWallsDetected: _onWallsDetected,
      onExport: _handleExport,
      onManageStoreys: _openStoreyManager,
    );

    return StructuralDesignerScreen(
      document: primaryDoc,
      title: _project.name,
      initialProject: _structuralProject,
      bimContext: bimContext,
    );
  }
}
