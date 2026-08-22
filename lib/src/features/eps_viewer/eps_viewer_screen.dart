import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'models/eps_models.dart';
import 'parser/eps_parser.dart';
import 'rendering/eps_painter.dart';

/// Encapsulated PostScript (.eps) Vector Viewer Screen with desktop fit & rotation.
class EpsViewerScreen extends StatefulWidget {
  final String filePath;

  const EpsViewerScreen({super.key, required this.filePath});

  @override
  State<EpsViewerScreen> createState() => _EpsViewerScreenState();
}

class _EpsViewerScreenState extends State<EpsViewerScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  int _fileSizeBytes = 0;

  EpsDocument? _document;
  EpsCanvasTheme _canvasTheme = EpsCanvasTheme.darkCad;
  bool _showGrid = true;
  int _rotationQuarterTurns = 0; // 0 = 0°, 1 = 90°, 2 = 180°, 3 = 270°
  bool _flipHorizontal = false;
  bool _flipVertical = false;

  Size _viewportSize = Size.zero;
  final TransformationController _transformController = TransformationController();

  String get _fileName => widget.filePath.split(Platform.pathSeparator).last;

  @override
  void initState() {
    super.initState();
    _loadEpsFile();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _loadEpsFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        throw Exception('File not found: ${widget.filePath}');
      }

      _fileSizeBytes = await file.length();
      final bytes = await file.readAsBytes();

      final doc = EpsParser.parse(bytes);

      if (mounted) {
        setState(() {
          _document = doc;
          _isLoading = false;
        });

        // Auto-fit to screen once rendered
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fitToScreen();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error reading EPS file: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// Calculates the exact translation and scale matrix to center and fit the EPS drawing in viewport.
  void _fitToScreen() {
    if (_document == null || _viewportSize.isEmpty) {
      _transformController.value = Matrix4.identity();
      return;
    }

    final bounds = _document!.metadata.boundingBox;
    final double rawW = bounds.width > 0 ? bounds.width : 500.0;
    final double rawH = bounds.height > 0 ? bounds.height : 500.0;

    final isRotated90or270 = _rotationQuarterTurns % 2 != 0;
    final double contentW = isRotated90or270 ? rawH : rawW;
    final double contentH = isRotated90or270 ? rawW : rawH;

    const double padding = 40.0;
    final double availW = math.max(_viewportSize.width - padding * 2, 10.0);
    final double availH = math.max(_viewportSize.height - padding * 2, 10.0);

    final double scale = math.min(availW / contentW, availH / contentH);

    final double dx = (_viewportSize.width - contentW * scale) / 2.0;
    final double dy = (_viewportSize.height - contentH * scale) / 2.0;

    final matrix = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(scale, scale);

    _transformController.value = matrix;
  }

  void _zoomIn() {
    _zoomBy(1.3);
  }

  void _zoomOut() {
    _zoomBy(1 / 1.3);
  }

  void _zoomBy(double factor, {Offset? focalPoint}) {
    if (_viewportSize.isEmpty) return;

    final targetPoint = focalPoint ?? Offset(_viewportSize.width / 2, _viewportSize.height / 2);
    final currentMatrix = _transformController.value;

    final translation = currentMatrix.getTranslation();
    final scale = currentMatrix.getMaxScaleOnAxis();

    final newScale = (scale * factor).clamp(0.002, 2000.0);

    final dx = targetPoint.dx - (targetPoint.dx - translation.x) * (newScale / scale);
    final dy = targetPoint.dy - (targetPoint.dy - translation.y) * (newScale / scale);

    final newMatrix = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(newScale);

    _transformController.value = newMatrix;
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final double zoomFactor = event.scrollDelta.dy < 0 ? 1.15 : 0.85;
      _zoomBy(zoomFactor, focalPoint: event.localPosition);
    }
  }

  void _rotateClockwise() {
    setState(() {
      _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitToScreen());
  }

  void _toggleFlipHorizontal() {
    setState(() {
      _flipHorizontal = !_flipHorizontal;
    });
  }

  void _toggleFlipVertical() {
    setState(() {
      _flipVertical = !_flipVertical;
    });
  }

  void _showInfoSheet() {
    if (_document == null) return;
    final theme = Theme.of(context);
    final meta = _document!.metadata;
    final bounds = meta.boundingBox;

    final formattedSize = _fileSizeBytes < 1024 * 1024
        ? '${(_fileSizeBytes / 1024).toStringAsFixed(1)} KB'
        : '${(_fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.gesture_rounded, color: Color(0xFF8B5CF6)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'EPS Vector • Properties',
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
              _buildInfoRow('File Name:', _fileName),
              _buildInfoRow('File Size:', formattedSize),
              _buildInfoRow('Bounding Box:', '${bounds.width.toStringAsFixed(1)} × ${bounds.height.toStringAsFixed(1)} pt'),
              if (meta.orientation != null) _buildInfoRow('Orientation:', meta.orientation!),
              if (meta.title != null) _buildInfoRow('Title:', meta.title!),
              if (meta.creator != null) _buildInfoRow('Creator:', meta.creator!),
              if (meta.creationDate != null) _buildInfoRow('Date:', meta.creationDate!),
              _buildInfoRow('Vector Paths:', '${_document!.paths.length} elements'),
              _buildInfoRow('Current Rotation:', '${_rotationQuarterTurns * 90}°'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _shareFile() {
    Share.shareXFiles([XFile(widget.filePath)], subject: _fileName);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: _canvasTheme.background,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(true),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _fileName,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            if (_document != null)
              Text(
                '${_document!.paths.length} paths • ${_document!.metadata.boundingBox.width.toStringAsFixed(0)} × ${_document!.metadata.boundingBox.height.toStringAsFixed(0)} pt'
                '${_rotationQuarterTurns > 0 ? " • ${_rotationQuarterTurns * 90}°" : ""}',
                style: TextStyle(fontSize: 11.5, color: theme.textTheme.bodySmall?.color),
              ),
          ],
        ),
        actions: [
          // Fit to Screen Button in Top Bar
          IconButton(
            icon: const Icon(Icons.fit_screen_outlined),
            tooltip: 'Fit to Screen',
            onPressed: _document != null ? _fitToScreen : null,
          ),

          // Rotate 90°
          IconButton(
            icon: const Icon(Icons.rotate_right_rounded),
            tooltip: 'Rotate 90° Clockwise',
            onPressed: _document != null ? _rotateClockwise : null,
          ),

          // Canvas Theme Menu
          PopupMenuButton<EpsCanvasTheme>(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Canvas Theme',
            onSelected: (t) => setState(() => _canvasTheme = t),
            itemBuilder: (context) => EpsCanvasTheme.values.map((t) {
              return PopupMenuItem<EpsCanvasTheme>(
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
                    if (_canvasTheme == t) ...[
                      const Spacer(),
                      Icon(Icons.check, size: 18, color: theme.colorScheme.primary),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),

          // Grid Toggle Button
          IconButton(
            icon: Icon(
              _showGrid ? Icons.grid_on : Icons.grid_off,
              color: _showGrid ? theme.colorScheme.primary : null,
            ),
            tooltip: 'Grid',
            onPressed: () => setState(() => _showGrid = !_showGrid),
          ),

          // Info Dialog
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Information',
            onPressed: _showInfoSheet,
          ),

          // Share Button
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
            onPressed: _shareFile,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

          if (_isLoading) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                  SizedBox(height: 16),
                  Text('Loading EPS Vector Graphic...', style: TextStyle(color: Colors.white70)),
                ],
              ),
            );
          }

          if (_errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loadEpsFile,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (_document == null) {
            return const SizedBox.shrink();
          }

          final bounds = _document!.metadata.boundingBox;
          final isRotated90or270 = _rotationQuarterTurns % 2 != 0;
          final double canvasW = isRotated90or270 ? bounds.height : bounds.width;
          final double canvasH = isRotated90or270 ? bounds.width : bounds.height;

          return Stack(
            children: [
              // Interactive Canvas with Infinite Vector Zoom & Pan + Mouse Wheel Support
              Listener(
                onPointerSignal: _handlePointerSignal,
                child: InteractiveViewer(
                  transformationController: _transformController,
                  minScale: 0.002,
                  maxScale: 2000.0,
                  boundaryMargin: const EdgeInsets.all(2500.0),
                  child: Center(
                    child: CustomPaint(
                      size: Size(
                        math.max(10.0, canvasW),
                        math.max(10.0, canvasH),
                      ),
                      painter: EpsPainter(
                        document: _document!,
                        theme: _canvasTheme,
                        showGrid: _showGrid,
                        rotationQuarterTurns: _rotationQuarterTurns,
                        flipHorizontal: _flipHorizontal,
                        flipVertical: _flipVertical,
                      ),
                    ),
                  ),
                ),
              ),

              // Floating Controls (Zoom, Fit, Rotate, Flip)
              Positioned(
                bottom: 24,
                right: 20,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFloatingButton(
                      icon: Icons.add,
                      tooltip: 'Zoom In (+)',
                      onTap: _zoomIn,
                      theme: theme,
                    ),
                    const SizedBox(height: 8),
                    _buildFloatingButton(
                      icon: Icons.remove,
                      tooltip: 'Zoom Out (-)',
                      onTap: _zoomOut,
                      theme: theme,
                    ),
                    const SizedBox(height: 8),
                    _buildFloatingButton(
                      icon: Icons.rotate_right_rounded,
                      tooltip: 'Rotate 90°',
                      onTap: _rotateClockwise,
                      theme: theme,
                    ),
                    const SizedBox(height: 8),
                    _buildFloatingButton(
                      icon: Icons.flip_rounded,
                      tooltip: 'Flip Vertical',
                      onTap: _toggleFlipVertical,
                      theme: theme,
                    ),
                    const SizedBox(height: 8),
                    _buildFloatingButton(
                      icon: Icons.fit_screen_outlined,
                      tooltip: 'Fit to View (Center)',
                      onTap: _fitToScreen,
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
      color: theme.colorScheme.surface.withValues(alpha: 0.92),
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
