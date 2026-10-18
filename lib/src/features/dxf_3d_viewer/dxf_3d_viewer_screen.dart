import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/models/pdf_item.dart';
import '../../core/services/project_bundle_service.dart';
import '../project_viewer/widgets/project_presentation_bar.dart';
import '../../core/services/recent_files_service.dart';
import 'models/ifc_model.dart';
import 'models/mesh_3d.dart';
import 'parser/stl_parser.dart';
import 'parser/obj_parser.dart';
import 'parser/glb_gltf_parser.dart';
import 'parser/step_parser.dart';
import 'parser/iges_parser.dart';
import 'parser/ifc_parser.dart';
import 'parser/fbx_parser.dart';
import 'parser/three_mf_parser.dart';
import 'widgets/ifc_bim_sheet.dart';
import '../cad_3d/cad_3d_controller.dart';
import '../cad_3d/widgets/cad_3d_viewport.dart';
import '../cad_3d/rendering/cad_3d_labels.dart';
import 'rendering/cad_3d_camera.dart';
import 'rendering/cad_3d_mesh_painter.dart';
import '../cad_3d/rendering/cad_3d_backend.dart';
import 'package:archive/archive.dart';

import '../../core/errors/app_error_handler.dart';
import '../../core/widgets/viewer_loading_screen.dart';
import '../../core/l10n/l10n_extensions.dart';

/// Interactive 3D CAD & Model Viewer Screen for STL, OBJ, GLTF, GLB, STEP, IGES, IFC, and FBX files.
class Dxf3DViewerScreen extends StatefulWidget {
  final String filePath;
  final String? title;
  final bool addToRecent;
  final ProjectBundleInfo? projectBundle;
  final int? currentProjectIndex;
  final void Function(int newIndex)? onSwitchProjectItem;

  const Dxf3DViewerScreen({
    super.key,
    required this.filePath,
    this.title,
    this.addToRecent = true,
    this.projectBundle,
    this.currentProjectIndex,
    this.onSwitchProjectItem,
  });

  @override
  State<Dxf3DViewerScreen> createState() => _Dxf3DViewerScreenState();
}

class _Dxf3DViewerScreenState extends State<Dxf3DViewerScreen> {
  final Cad3DController _navigation = Cad3DController();
  Cad3DCamera get _camera => _navigation.camera;

  Mesh3D? _mesh;
  IfcModel? _ifcModel;
  bool _isLoading = true;
  String? _errorMessage;
  late String _fileName;
  int _fileSizeBytes = 0;

  final Cad3DShadingMode _shadingMode = Cad3DShadingMode.smoothShaded;
  Cad3DTheme _theme = Cad3DTheme.darkCad;
  final bool _showGrid = true;
  Color? _customModelColor;
  Cad3DInteractionMode get _interactionMode => _navigation.mode;

  bool _useNativeDepth = true;
  bool _isFullscreen = true;
  Cad3DInteractionMode _lastMode = Cad3DInteractionMode.orbit;

  void _onNavigationChanged() {
    if (_lastMode != _navigation.mode) {
      setState(() => _lastMode = _navigation.mode);
    }
  }

  void _toggleFullscreen() {
    HapticFeedback.selectionClick();
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
  }

  void _handleBack() {
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    } else {
      Navigator.of(context).maybePop(true);
    }
  }

  @override
  void initState() {
    super.initState();
    _fileName =
        widget.title ?? widget.filePath.split(Platform.pathSeparator).last;
    _navigation.addListener(_onNavigationChanged);
    _load3DModel();
  }

  @override
  void dispose() {
    _navigation.removeListener(_onNavigationChanged);
    _navigation.dispose();
    super.dispose();
  }

  Future<void> _load3DModel() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          setState(() {
            _errorMessage =
                l10n?.fileNotFoundOrInaccessible ??
                'File not found or cannot be accessed.';
            _isLoading = false;
          });
        }
        return;
      }

      final stat = await file.stat();
      _fileSizeBytes = stat.size;

      final lower = widget.filePath.toLowerCase();
      Mesh3D mesh;

      if (lower.endsWith('.ifc')) {
        final ifc = await IfcParser.parseFromFile(widget.filePath);
        _ifcModel = ifc;
        mesh = ifc.toMesh3D();
      } else if (lower.endsWith('.step') ||
          lower.endsWith('.stp') ||
          lower.endsWith('.p21')) {
        mesh = await StepParser.parseFromFile(widget.filePath);
      } else if (lower.endsWith('.iges') || lower.endsWith('.igs')) {
        mesh = await IgesParser.parseFromFile(widget.filePath);
      } else if (lower.endsWith('.stl')) {
        mesh = await StlParser.parseFromFile(widget.filePath);
      } else if (lower.endsWith('.obj')) {
        mesh = await ObjParser.parseFromFile(widget.filePath);
      } else if (lower.endsWith('.glb') || lower.endsWith('.gltf')) {
        mesh = await GlbGltfParser.parseFromFile(widget.filePath);
      } else if (lower.endsWith('.fbx')) {
        mesh = await FbxParser.parseFromFile(widget.filePath);
      } else if (lower.endsWith('.3mf')) {
        mesh = await ThreeMfParser.parseFromFile(widget.filePath);
      } else {
        // Fallback: try FBX -> STEP -> STL -> OBJ
        try {
          mesh = await FbxParser.parseFromFile(widget.filePath);
        } on Exception {
          // FBX fallback failed, try STEP
          try {
            mesh = await StepParser.parseFromFile(widget.filePath);
          } on Exception {
            // STEP fallback failed, try STL
            try {
              mesh = await StlParser.parseFromFile(widget.filePath);
            } on Exception {
              // STL fallback failed, try OBJ
              mesh = await ObjParser.parseFromFile(widget.filePath);
            }
          }
        }
      }

      if (mesh.triangles.isEmpty) {
        throw const FormatException('No 3D mesh geometry found in model file');
      }

      // Record in recent files
      if (widget.addToRecent) {
        final pdfItem = PdfItem(
          path: widget.filePath,
          name: _fileName,
          sizeInBytes: _fileSizeBytes,
          lastOpened: DateTime.now(),
        );
        await RecentFilesService.addRecentFile(pdfItem);
      }

      if (mounted) {
        setState(() {
          _mesh = mesh;
          _isLoading = false;
        });
      }
    } on FileSystemException catch (e, stack) {
      AppErrorHandler.recordError(
        e,
        stack,
        context: 'Dxf3DViewer._loadModel.fs',
      );
      await RecentFilesService.removeRecentFile(widget.filePath);
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          _errorMessage =
              l10n?.fileNotFoundOrInaccessible ??
              'File not found or cannot be accessed.';
          _isLoading = false;
        });
      }
    } on ArchiveException catch (e, stack) {
      AppErrorHandler.recordError(
        e,
        stack,
        context: 'Dxf3DViewer._loadModel.archive',
      );
      await RecentFilesService.removeRecentFile(widget.filePath);
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          _errorMessage =
              l10n?.errorLoading3dModel(e.message) ??
              'Error loading 3D model: ${e.message}';
          _isLoading = false;
        });
      }
    } on FormatException catch (e, stack) {
      AppErrorHandler.recordError(
        e,
        stack,
        context: 'Dxf3DViewer._loadModel.format',
      );
      await RecentFilesService.removeRecentFile(widget.filePath);
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          _errorMessage =
              l10n?.errorLoading3dModel(e.message) ??
              'Error loading 3D model: ${e.message}';
          _isLoading = false;
        });
      }
    } on Exception catch (e, stack) {
      AppErrorHandler.recordError(e, stack, context: 'Dxf3DViewer._loadModel');
      await RecentFilesService.removeRecentFile(widget.filePath);
      if (mounted) {
        final cleanMsg = e.toString().replaceFirst(
          RegExp(r'^Exception:\s*'),
          '',
        );
        final l10n = AppLocalizations.of(context);
        setState(() {
          _errorMessage =
              l10n?.errorLoading3dModel(cleanMsg) ??
              'Error loading 3D model: $cleanMsg';
          _isLoading = false;
        });
      }
    }
  }

  void _toggleInteractionMode() {
    final next = switch (_interactionMode) {
      Cad3DInteractionMode.orbit => Cad3DInteractionMode.pan,
      Cad3DInteractionMode.pan => Cad3DInteractionMode.fly,
      Cad3DInteractionMode.fly => Cad3DInteractionMode.orbit,
    };
    _setInteractionMode(next);
  }

  void _setInteractionMode(Cad3DInteractionMode mode) =>
      _navigation.setMode(mode);
  void _resetView() => _navigation.reset();
  void _setViewPreset(Cad3DViewPreset preset) => _navigation.setPreset(preset);
  String _formatDimension(double val) {
    if (val >= 1000.0) {
      return '${(val / 1000.0).toStringAsFixed(2)} m';
    } else if (val >= 10.0) {
      return '${val.toStringAsFixed(1)} mm';
    }
    return '${val.toStringAsFixed(2)} mm';
  }

  void _showMetricsSheet() {
    if (_mesh == null) return;
    final theme = Theme.of(context);
    final bounds = _mesh!.bounds;

    final formattedSize = _fileSizeBytes < 1024 * 1024
        ? '${(_fileSizeBytes / 1024).toStringAsFixed(1)} KB'
        : '${(_fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.analytics_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '3D Model • Properties',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _fileName,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildMetricTile(
              label: '3D Dimensions (X × Y × Z):',
              value:
                  '${_formatDimension(bounds.sizeX)}  ×  ${_formatDimension(bounds.sizeY)}  ×  ${_formatDimension(bounds.sizeZ)}',
              icon: Icons.crop_free_rounded,
              valueOnNewLine: true,
            ),
            _buildMetricTile(
              label: 'Polygons (Triangles):',
              value: '${_mesh!.triangleCount} triangles',
              icon: Icons.change_history_rounded,
            ),
            _buildMetricTile(
              label: 'Surface Area:',
              value: '${_mesh!.surfaceArea.toStringAsFixed(1)} mm²',
              icon: Icons.square_foot_rounded,
            ),
            _buildMetricTile(
              label: 'Volume:',
              value: '${(_mesh!.volume / 1000.0).toStringAsFixed(2)} cm³',
              icon: Icons.view_in_ar_rounded,
            ),
            _buildMetricTile(
              label: 'File Size:',
              value: formattedSize,
              icon: Icons.folder_open_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    bool valueOnNewLine = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        crossAxisAlignment: valueOnNewLine
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: valueOnNewLine
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00E5FF),
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _shareFile() {
    Share.shareXFiles([XFile(widget.filePath)], subject: _fileName);
  }

  void _openBimSheet() {
    if (_ifcModel == null) return;
    IfcBimSheet.show(
      context: context,
      ifcModel: _ifcModel!,
      isDark: _theme.isDark,
      onFiltersChanged: () {
        final newMesh = _ifcModel!.toMesh3D();
        setState(() {
          _mesh = newMesh;
        });
      },
    );
  }

  Widget _buildInteractionModeSwitch(ThemeData theme, AppLocalizations l10n) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? Colors.white12
              : Colors.black12,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeButton(
            icon: Icons.threed_rotation_rounded,
            tooltip: '${l10n.orbitMode} (${l10n.rotateModelTooltip})',
            isSelected: _interactionMode == Cad3DInteractionMode.orbit,
            onTap: () => _setInteractionMode(Cad3DInteractionMode.orbit),
            theme: theme,
          ),
          _buildModeButton(
            icon: Icons.pan_tool_rounded,
            tooltip: '${l10n.dragMode} (${l10n.dragModelTooltip})',
            isSelected: _interactionMode == Cad3DInteractionMode.pan,
            onTap: () => _setInteractionMode(Cad3DInteractionMode.pan),
            theme: theme,
          ),
          _buildModeButton(
            icon: Icons.flight_takeoff_rounded,
            tooltip: '${l10n.flyMode} (${l10n.flyModeTooltip})',
            isSelected: _interactionMode == Cad3DInteractionMode.fly,
            onTap: () => _setInteractionMode(Cad3DInteractionMode.fly),
            theme: theme,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDxf3dActionButtons(
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return [
      // Quick Views Menu & Controls
      PopupMenuButton<dynamic>(
        icon: const Icon(Icons.videocam_outlined, size: 20),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
        tooltip: l10n.cad3dCamera,
        onSelected: (val) {
          if (val is Cad3DViewPreset) {
            _setViewPreset(val);
          } else if (val == 'toggle_invert_y') {
            HapticFeedback.selectionClick();
            setState(() {
              _camera.invertY = !_camera.invertY;
              _navigation.changed();
            });
          }
        },
        itemBuilder: (context) => [
          ...Cad3DViewPreset.values.map((v) {
            return PopupMenuItem<dynamic>(
              value: v,
              child: Row(
                children: [
                  Icon(v.icon, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Text(v.localizedLabel(l10n)),
                ],
              ),
            );
          }),
          const PopupMenuDivider(),
          PopupMenuItem<dynamic>(
            value: 'toggle_invert_y',
            child: Row(
              children: [
                Icon(
                  _camera.invertY
                      ? Icons.swap_vert_rounded
                      : Icons.swap_vert_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Text(l10n.cad3dInvertY),
                const Spacer(),
                if (_camera.invertY)
                  Icon(Icons.check, size: 18, color: theme.colorScheme.primary),
              ],
            ),
          ),
        ],
      ),

      // Canvas Theme Menu
      PopupMenuButton<Cad3DTheme>(
        icon: const Icon(Icons.palette_outlined, size: 20),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
        tooltip: l10n.theme,
        onSelected: (t) => setState(() => _theme = t),
        itemBuilder: (context) => Cad3DTheme.values.map((t) {
          return PopupMenuItem<Cad3DTheme>(
            value: t,
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: t.background,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey, width: 1),
                  ),
                ),
                const SizedBox(width: 10),
                Text(t.localizedLabel(l10n)),
                if (_theme == t) ...[
                  const Spacer(),
                  Icon(Icons.check, size: 18, color: theme.colorScheme.primary),
                ],
              ],
            ),
          );
        }).toList(),
      ),

      // The legacy native backend has a software Z-buffer, not GPU acceleration.
      if (Cad3DRenderBackend.acceleratedAvailable)
        IconButton(
          icon: Icon(_useNativeDepth ? Icons.layers : Icons.layers_outlined),
          tooltip: _useNativeDepth
              ? l10n.cad3dNativeDepthOn
              : l10n.cad3dNativeDepthOff,
          onPressed: () => setState(() => _useNativeDepth = !_useNativeDepth),
        ),
      // BIM Storeys & Categories (when IFC model is loaded)
      if (_ifcModel != null)
        IconButton(
          icon: const Icon(Icons.apartment_rounded, size: 20),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
          color: const Color(0xFF00E5FF),
          tooltip: l10n.bimStoreysAndCategories,
          onPressed: _openBimSheet,
        ),

      // 3D Model Info & Metrics
      IconButton(
        icon: const Icon(Icons.info_outline, size: 20),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
        tooltip: l10n.properties3d,
        onPressed: _showMetricsSheet,
      ),

      // Share
      IconButton(
        icon: const Icon(Icons.share_outlined, size: 20),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
        tooltip: l10n.share,
        onPressed: _shareFile,
      ),

      // Fullscreen Toggle
      IconButton(
        icon: Icon(
          _isFullscreen
              ? Icons.fullscreen_exit_rounded
              : Icons.fullscreen_rounded,
          size: 20,
        ),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
        tooltip: _isFullscreen ? 'Exit Fullscreen' : 'Fullscreen',
        onPressed: _toggleFullscreen,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_isLoading) {
      return ViewerLoadingScreen(
        fileName: _fileName,
        fileSizeBytes: _fileSizeBytes,
        icon: Icons.view_in_ar_rounded,
        accentColor: const Color(0xFF00E5FF),
        loadingTitle: l10n.loading3dModel,
        statusMessage: l10n.statusTriangulatingMesh,
        onCancel: _handleBack,
      );
    }

    final theme = Theme.of(context);
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return PopScope(
      canPop: !_isFullscreen,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isFullscreen) {
          _toggleFullscreen();
        }
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (_isFullscreen) {
              _toggleFullscreen();
            } else {
              _handleBack();
            }
          },
          const SingleActivator(LogicalKeyboardKey.keyF): () {
            _toggleFullscreen();
          },
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: _theme.background,
            appBar: _isFullscreen
                ? null
                : AppBar(
                    backgroundColor: theme.colorScheme.surface,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: l10n.back,
                      onPressed: _handleBack,
                    ),
                    title: Text(
                      _fileName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    actions: isLandscape
                        ? [
                            _buildInteractionModeSwitch(theme, l10n),
                            const SizedBox(width: 8),
                            ..._buildDxf3dActionButtons(theme, l10n),
                          ]
                        : const [],
                    bottom: isLandscape
                        ? null
                        : PreferredSize(
                            preferredSize: const Size.fromHeight(44),
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: theme.brightness == Brightness.dark
                                        ? Colors.white10
                                        : Colors.black12,
                                  ),
                                ),
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minWidth: math.max(
                                          0.0,
                                          constraints.maxWidth - 24.0,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          _buildInteractionModeSwitch(
                                            theme,
                                            l10n,
                                          ),
                                          const SizedBox(width: 8),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: _buildDxf3dActionButtons(
                                              theme,
                                              l10n,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                  ),
            body: LayoutBuilder(
              builder: (context, constraints) {
                if (_isLoading) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(l10n.loading3dModel),
                      ],
                    ),
                  );
                }

                if (_errorMessage != null || _mesh == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage ?? l10n.failedToParse3dMesh,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _load3DModel,
                            icon: const Icon(Icons.refresh),
                            label: Text(l10n.retry),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Stack(
                  children: [
                    Positioned.fill(
                      child: Cad3DViewport(
                        mesh: _mesh!,
                        controller: _navigation,
                        theme: _theme,
                        shadingMode: _shadingMode,
                        showGrid: _showGrid,
                        showControls: false,
                        preferNativeDepth: _useNativeDepth,
                        modelColor: _customModelColor,
                      ),
                    ),
                    // Drag Mode Active Indicator Pill
                    if (_interactionMode == Cad3DInteractionMode.pan)
                      Positioned(
                        top: 16,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: InkWell(
                            onTap: _toggleInteractionMode,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF00E5FF,
                                ).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(
                                    0xFF00E5FF,
                                  ).withValues(alpha: 0.8),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.pan_tool_rounded,
                                    size: 15,
                                    color: Color(0xFF00E5FF),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    l10n.dragModeActive,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF00E5FF),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Fly Mode Active Indicator Pill
                    if (_interactionMode == Cad3DInteractionMode.fly)
                      Positioned(
                        top: 16,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: InkWell(
                            onTap: _toggleInteractionMode,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF00E5FF,
                                ).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(
                                    0xFF00E5FF,
                                  ).withValues(alpha: 0.8),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.flight_takeoff_rounded,
                                    size: 15,
                                    color: Color(0xFF00E5FF),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    l10n.flyModeActive,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF00E5FF),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Floating Controls (Flight Mode, 3D Orbit, Drag, Fit to Screen)
                    Positioned(
                      bottom: 24,
                      right: 20,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildFloatingButton(
                            icon: Icons.flight_takeoff_rounded,
                            tooltip: '${l10n.flyMode} (${l10n.flyModeTooltip})',
                            isActive:
                                _interactionMode == Cad3DInteractionMode.fly,
                            onTap: () => _setInteractionMode(
                              _interactionMode == Cad3DInteractionMode.fly
                                  ? Cad3DInteractionMode.orbit
                                  : Cad3DInteractionMode.fly,
                            ),
                            theme: theme,
                          ),
                          const SizedBox(height: 8),
                          _buildFloatingButton(
                            icon: Icons.threed_rotation_rounded,
                            tooltip:
                                '${l10n.orbitMode} (${l10n.rotateModelTooltip})',
                            isActive:
                                _interactionMode == Cad3DInteractionMode.orbit,
                            onTap: () =>
                                _setInteractionMode(Cad3DInteractionMode.orbit),
                            theme: theme,
                          ),
                          const SizedBox(height: 8),
                          _buildFloatingButton(
                            icon: Icons.pan_tool_rounded,
                            tooltip:
                                '${l10n.dragMode} (${l10n.dragModelTooltip})',
                            isActive:
                                _interactionMode == Cad3DInteractionMode.pan,
                            onTap: () =>
                                _setInteractionMode(Cad3DInteractionMode.pan),
                            theme: theme,
                          ),
                          const SizedBox(height: 8),
                          _buildFloatingButton(
                            icon: Icons.fit_screen_outlined,
                            tooltip: l10n.centerView,
                            onTap: _resetView,
                            theme: theme,
                          ),
                        ],
                      ),
                    ),

                    // Presentation Mode Switcher Bar
                    if (widget.projectBundle != null)
                      Positioned(
                        bottom: 24,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: ProjectPresentationBar(
                            projectBundle: widget.projectBundle!,
                            currentIndex: widget.currentProjectIndex ?? 0,
                            onSwitchProjectItem: widget.onSwitchProjectItem,
                            onExit: _handleBack,
                          ),
                        ),
                      ),

                    // Floating Back Button in Fullscreen
                    if (_isFullscreen)
                      Positioned(
                        top: 16,
                        left: 16,
                        child: SafeArea(
                          child: Material(
                            color: Colors.black54,
                            shape: const CircleBorder(),
                            elevation: 4,
                            clipBehavior: Clip.antiAlias,
                            child: IconButton(
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              tooltip: l10n.back,
                              onPressed: _handleBack,
                            ),
                          ),
                        ),
                      ),

                    // Floating Exit Fullscreen Button
                    if (_isFullscreen)
                      Positioned(
                        top: 16,
                        right: 16,
                        child: SafeArea(
                          child: Material(
                            color: Colors.black54,
                            shape: const CircleBorder(),
                            elevation: 4,
                            clipBehavior: Clip.antiAlias,
                            child: IconButton(
                              icon: const Icon(
                                Icons.fullscreen_exit_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              tooltip: 'Exit Fullscreen (ESC)',
                              onPressed: _toggleFullscreen,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton({
    required IconData icon,
    required String tooltip,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF00E5FF).withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: isSelected
                ? Border.all(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                    width: 1,
                  )
                : null,
          ),
          child: Icon(
            icon,
            size: 18,
            color: isSelected
                ? const Color(0xFF00E5FF)
                : theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required ThemeData theme,
    bool isActive = false,
    Color? activeColor,
  }) {
    final effectiveActiveColor = activeColor ?? const Color(0xFF00E5FF);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isActive
            ? effectiveActiveColor
            : theme.colorScheme.surface.withValues(alpha: 0.9),
        shape: const CircleBorder(),
        elevation: isActive ? 6 : 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Icon(
              icon,
              size: 20,
              color: isActive ? Colors.black : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
