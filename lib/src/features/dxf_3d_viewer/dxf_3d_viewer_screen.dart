import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/models/pdf_item.dart';
import '../../core/services/recent_files_service.dart';
import 'models/mesh_3d.dart';
import 'parser/stl_parser.dart';
import 'parser/obj_parser.dart';
import 'parser/glb_gltf_parser.dart';
import 'parser/step_parser.dart';
import 'parser/iges_parser.dart';
import 'rendering/cad_3d_camera.dart';
import 'rendering/cad_3d_mesh_painter.dart';

/// Interactive 3D CAD & Model Viewer Screen for STL, OBJ, GLTF, GLB, STEP, and IGES files.
class Dxf3DViewerScreen extends StatefulWidget {
  final String filePath;
  final String? title;

  const Dxf3DViewerScreen({
    super.key,
    required this.filePath,
    this.title,
  });

  @override
  State<Dxf3DViewerScreen> createState() => _Dxf3DViewerScreenState();
}

class _Dxf3DViewerScreenState extends State<Dxf3DViewerScreen> {
  final Cad3DCamera _camera = Cad3DCamera();

  Mesh3D? _mesh;
  bool _isLoading = true;
  String? _errorMessage;
  late String _fileName;
  int _fileSizeBytes = 0;

  Cad3DShadingMode _shadingMode = Cad3DShadingMode.cadShadedEdges;
  Cad3DTheme _theme = Cad3DTheme.darkCad;
  bool _showBoundingBox = true;
  bool _showGrid = true;

  Offset? _lastPanPos;
  double _baseScale = 1.0;

  @override
  void initState() {
    super.initState();
    _fileName = widget.title ?? widget.filePath.split(Platform.pathSeparator).last;
    _load3DModel();
  }

  Future<void> _load3DModel() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        setState(() {
          _errorMessage = 'File not found: ${widget.filePath}';
          _isLoading = false;
        });
        return;
      }

      final stat = await file.stat();
      _fileSizeBytes = stat.size;

      final lower = widget.filePath.toLowerCase();
      Mesh3D mesh;

      if (lower.endsWith('.step') || lower.endsWith('.stp') || lower.endsWith('.p21')) {
        mesh = await StepParser.parseFromFile(widget.filePath);
      } else if (lower.endsWith('.iges') || lower.endsWith('.igs')) {
        mesh = await IgesParser.parseFromFile(widget.filePath);
      } else if (lower.endsWith('.stl')) {
        mesh = await StlParser.parseFromFile(widget.filePath);
      } else if (lower.endsWith('.obj')) {
        mesh = await ObjParser.parseFromFile(widget.filePath);
      } else if (lower.endsWith('.glb') || lower.endsWith('.gltf')) {
        mesh = await GlbGltfParser.parseFromFile(widget.filePath);
      } else {
        // Fallback: try STEP -> STL -> OBJ
        try {
          mesh = await StepParser.parseFromFile(widget.filePath);
        } catch (_) {
          try {
            mesh = await StlParser.parseFromFile(widget.filePath);
          } catch (_) {
            mesh = await ObjParser.parseFromFile(widget.filePath);
          }
        }
      }

      // Record in recent files
      final pdfItem = PdfItem(
        path: widget.filePath,
        name: _fileName,
        sizeInBytes: _fileSizeBytes,
        lastOpened: DateTime.now(),
      );
      await RecentFilesService.addRecentFile(pdfItem);

      if (mounted) {
        setState(() {
          _mesh = mesh;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading 3D Model: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    _lastPanPos = details.localFocalPoint;
    _baseScale = _camera.zoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_lastPanPos == null) return;

    final delta = details.localFocalPoint - _lastPanPos!;
    _lastPanPos = details.localFocalPoint;

    setState(() {
      if (details.pointerCount == 1) {
        // 1 finger: Orbit Rotation
        _camera.orbit(delta.dx, delta.dy);
      } else if (details.pointerCount >= 2) {
        // 2 fingers: Pan and Zoom
        _camera.pan(delta);
        _camera.zoom = (_baseScale * details.scale).clamp(0.05, 100.0);
      }
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _lastPanPos = null;
  }

  void _resetView() {
    HapticFeedback.selectionClick();
    setState(() {
      _camera.reset();
    });
  }

  void _setViewPreset(Cad3DViewPreset preset) {
    HapticFeedback.selectionClick();
    setState(() {
      _camera.setPreset(preset);
    });
  }

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
                  child: Icon(Icons.analytics_outlined, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '3D Model • Properties',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _fileName,
                        style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
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
              value: '${_formatDimension(bounds.sizeX)}  ×  ${_formatDimension(bounds.sizeY)}  ×  ${_formatDimension(bounds.sizeZ)}',
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
        crossAxisAlignment: valueOnNewLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: valueOnNewLine
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 3),
                      Text(
                        value,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF)),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _shareFile() {
    Share.shareXFiles(
      [XFile(widget.filePath)],
      subject: _fileName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: _theme.background,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(true),
        ),
        title: Text(
          _fileName,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Quick Views Menu
          PopupMenuButton<Cad3DViewPreset>(
            icon: const Icon(Icons.videocam_outlined),
            tooltip: 'Camera View',
            onSelected: _setViewPreset,
            itemBuilder: (context) => Cad3DViewPreset.values.map((v) {
              return PopupMenuItem<Cad3DViewPreset>(
                value: v,
                child: Row(
                  children: [
                    Icon(v.icon, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Text(v.label),
                  ],
                ),
              );
            }).toList(),
          ),

          // Shading Mode Menu
          PopupMenuButton<Cad3DShadingMode>(
            icon: Icon(_shadingMode.icon),
            tooltip: 'Rendering Mode',
            onSelected: (m) => setState(() => _shadingMode = m),
            itemBuilder: (context) => Cad3DShadingMode.values.map((m) {
              return PopupMenuItem<Cad3DShadingMode>(
                value: m,
                child: Row(
                  children: [
                    Icon(m.icon, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Text(m.label),
                    if (_shadingMode == m) ...[
                      const Spacer(),
                      Icon(Icons.check, size: 18, color: theme.colorScheme.primary),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),

          // Canvas Theme Menu
          PopupMenuButton<Cad3DTheme>(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Theme',
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
                    Text(t.label),
                    if (_theme == t) ...[
                      const Spacer(),
                      Icon(Icons.check, size: 18, color: theme.colorScheme.primary),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),

          // Bounding Box Toggle
          IconButton(
            icon: Icon(
              _showBoundingBox ? Icons.crop_free : Icons.crop_square,
              color: _showBoundingBox ? theme.colorScheme.primary : null,
            ),
            tooltip: 'Bounding Box',
            onPressed: () => setState(() => _showBoundingBox = !_showBoundingBox),
          ),

          // 3D Model Info & Metrics
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: '3D Properties',
            onPressed: _showMetricsSheet,
          ),

          // Share
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
            onPressed: _shareFile,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (_isLoading) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading 3D Model & Mesh...'),
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
                    const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage ?? 'Failed to parse 3D mesh.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _load3DModel,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Stack(
            children: [
              // 3D Gesture Detector & Canvas
              GestureDetector(
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onScaleEnd: _onScaleEnd,
                onDoubleTap: _resetView,
                child: CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: Cad3DMeshPainter(
                    mesh: _mesh!,
                    camera: _camera,
                    shadingMode: _shadingMode,
                    theme: _theme,
                    showBoundingBox: _showBoundingBox,
                    showGrid: _showGrid,
                  ),
                ),
              ),

              // Floating Controls (Zoom +, Zoom -, Fit)
              Positioned(
                bottom: 24,
                right: 20,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFloatingButton(
                      icon: Icons.add,
                      tooltip: 'Zoom In (+)',
                      onTap: () => setState(() => _camera.zoomBy(1.2)),
                      theme: theme,
                    ),
                    const SizedBox(height: 8),
                    _buildFloatingButton(
                      icon: Icons.remove,
                      tooltip: 'Zoom Out (-)',
                      onTap: () => setState(() => _camera.zoomBy(0.8)),
                      theme: theme,
                    ),
                    const SizedBox(height: 8),
                    _buildFloatingButton(
                      icon: Icons.fit_screen_outlined,
                      tooltip: 'Reset / Isometric View',
                      onTap: _resetView,
                      theme: theme,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Icon(icon, size: 20, color: theme.colorScheme.onSurface),
          ),
        ),
      ),
    );
  }
}
