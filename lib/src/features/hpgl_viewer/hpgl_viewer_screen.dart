import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../eps_viewer/models/eps_models.dart';
import 'models/hpgl_models.dart';
import 'parser/hpgl_parser.dart';

/// HP-GL CAD Plotter (.plt, .hpgl) Viewer Screen.
class HpglViewerScreen extends StatefulWidget {
  final String filePath;

  const HpglViewerScreen({super.key, required this.filePath});

  @override
  State<HpglViewerScreen> createState() => _HpglViewerScreenState();
}

class _HpglViewerScreenState extends State<HpglViewerScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  int _fileSizeBytes = 0;

  HpglDocument? _document;
  EpsCanvasTheme _canvasTheme = EpsCanvasTheme.darkCad;
  bool _showGrid = true;

  final TransformationController _transformController = TransformationController();

  String get _fileName => widget.filePath.split(Platform.pathSeparator).last;

  @override
  void initState() {
    super.initState();
    _loadHpglFile();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _loadHpglFile() async {
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

      final doc = HpglParser.parse(bytes, fileName: _fileName);

      if (mounted) {
        setState(() {
          _document = doc;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error reading HPGL plotter file: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _resetView() {
    _transformController.value = Matrix4.identity();
  }

  void _zoomIn() {
    final matrix = _transformController.value.clone()..scale(1.25, 1.25);
    _transformController.value = matrix;
  }

  void _zoomOut() {
    final matrix = _transformController.value.clone()..scale(0.8, 0.8);
    _transformController.value = matrix;
  }

  void _showInfoSheet() {
    if (_document == null) return;
    final theme = Theme.of(context);
    final bounds = _document!.boundingBox;

    final formattedSize = _fileSizeBytes < 1024 * 1024
        ? '${(_fileSizeBytes / 1024).toStringAsFixed(1)} KB'
        : '${(_fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';

    // 1 plotter unit = 0.025 mm (40 units / mm)
    final widthMm = bounds.width * 0.025;
    final heightMm = bounds.height * 0.025;

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
                      color: const Color(0xFFD97706).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.architecture_rounded, color: Color(0xFFD97706)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'HPGL Plotter • Properties',
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
              _buildInfoRow('Drawing Extents (mm):', '${widthMm.toStringAsFixed(1)} × ${heightMm.toStringAsFixed(1)} mm'),
              _buildInfoRow('Plotter Units:', '${bounds.width.toStringAsFixed(0)} × ${bounds.height.toStringAsFixed(0)} units'),
              _buildInfoRow('Vector Paths:', '${_document!.elements.length} strokes'),
              _buildInfoRow('Total Vertices:', '${_document!.totalPoints} points'),
              _buildInfoRow('Pens Used:', '${_document!.penCount} pens'),
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
                '${_document!.elements.length} paths • ${_document!.penCount} pens • ${(_document!.boundingBox.width * 0.025).toStringAsFixed(0)}×${(_document!.boundingBox.height * 0.025).toStringAsFixed(0)} mm',
                style: TextStyle(fontSize: 11.5, color: theme.textTheme.bodySmall?.color),
              ),
          ],
        ),
        actions: [
          // Theme Menu
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
            tooltip: 'Plotter Properties',
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
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFFD97706)),
                  SizedBox(height: 16),
                  Text('Loading HPGL Plotter Drawing...', style: TextStyle(color: Colors.white70)),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
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
                          onPressed: _loadHpglFile,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : Stack(
                  children: [
                    // Interactive Canvas with Infinite Vector Zoom & Pan
                    InteractiveViewer(
                      transformationController: _transformController,
                      minScale: 0.01,
                      maxScale: 1000.0,
                      boundaryMargin: const EdgeInsets.all(1500.0),
                      child: Center(
                        child: CustomPaint(
                          size: Size(
                            math.max(300.0, _document!.boundingBox.width * 0.05),
                            math.max(300.0, _document!.boundingBox.height * 0.05),
                          ),
                          painter: _HpglPainter(
                            document: _document!,
                            theme: _canvasTheme,
                            showGrid: _showGrid,
                          ),
                        ),
                      ),
                    ),

                    // Floating Zoom Controls
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
                            icon: Icons.fit_screen_outlined,
                            tooltip: 'Fit to View',
                            onTap: _resetView,
                            theme: theme,
                          ),
                        ],
                      ),
                    ),
                  ],
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

class _HpglPainter extends CustomPainter {
  final HpglDocument document;
  final EpsCanvasTheme theme;
  final bool showGrid;

  const _HpglPainter({
    required this.document,
    required this.theme,
    required this.showGrid,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = document.boundingBox;
    const margin = 20.0;
    final scale = (bounds.width > 0 && bounds.height > 0)
        ? math.min((size.width - 40) / bounds.width, (size.height - 40) / bounds.height)
        : 0.05;

    final docW = bounds.width * scale + margin * 2;
    final docH = bounds.height * scale + margin * 2;

    // Draw Background
    canvas.drawRect(Rect.fromLTWH(0, 0, docW, docH), Paint()..color = theme.background);

    // Draw CAD Grid
    if (showGrid) {
      final gridPaint = Paint()
        ..color = theme.gridColor
        ..strokeWidth = 0.5;
      const step = 40.0;
      for (double x = 0; x <= docW; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, docH), gridPaint);
      }
      for (double y = 0; y <= docH; y += step) {
        canvas.drawLine(Offset(0, y), Offset(docW, y), gridPaint);
      }
    }

    Offset mapPoint(Offset p) {
      final x = margin + (p.dx - bounds.minX) * scale;
      final y = margin + (bounds.maxY - p.dy) * scale; // Invert Y
      return Offset(x, y);
    }

    for (final el in document.elements) {
      if (el.points.isEmpty) continue;

      final path = Path();
      final p0 = mapPoint(el.points.first);
      path.moveTo(p0.dx, p0.dy);

      for (int i = 1; i < el.points.length; i++) {
        final pt = mapPoint(el.points[i]);
        path.lineTo(pt.dx, pt.dy);
      }

      if (el.isClosed) {
        path.close();
      }

      Color drawColor = el.color;
      if (theme.isDark && drawColor.computeLuminance() < 0.08) {
        drawColor = Colors.white70;
      } else if (!theme.isDark && drawColor.computeLuminance() > 0.92) {
        drawColor = Colors.black87;
      }

      final strokePaint = Paint()
        ..color = drawColor
        ..strokeWidth = math.max(0.75, el.lineWidth)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HpglPainter oldDelegate) {
    return oldDelegate.document != document ||
        oldDelegate.theme != theme ||
        oldDelegate.showGrid != showGrid;
  }
}
