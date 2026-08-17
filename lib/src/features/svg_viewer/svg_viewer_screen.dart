import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/models/pdf_item.dart';
import '../../core/services/recent_files_service.dart';

/// Available canvas themes for the SVG viewer.
enum SvgCanvasTheme {
  darkCad('Dark CAD', Color(0xFF1E1E1E), Color(0xFF2E2E2E)),
  blueprint('Blueprint', Color(0xFF0D253A), Color(0xFF194364)),
  lightStudio('Light Studio', Color(0xFFF5F5F7), Color(0xFFE2E2E6)),
  pureBlack('Pure Black', Color(0xFF000000), Color(0xFF1F1F1F)),
  pureWhite('Pure White', Color(0xFFFFFFFF), Color(0xFFE0E0E0));

  final String label;
  final Color background;
  final Color gridColor;

  const SvgCanvasTheme(this.label, this.background, this.gridColor);

  bool get isDark => background.computeLuminance() < 0.5;
}

/// Metadata extracted from parsed SVG header.
class SvgMetadata {
  final double? width;
  final double? height;
  final Rect? viewBox;
  final int pathCount;
  final int shapeCount;
  final int textCount;

  const SvgMetadata({
    this.width,
    this.height,
    this.viewBox,
    this.pathCount = 0,
    this.shapeCount = 0,
    this.textCount = 0,
  });

  int get totalElements => pathCount + shapeCount + textCount;
}

/// Dedicated 2D Vector Viewer Screen for SVG files.
class SvgViewerScreen extends StatefulWidget {
  final String filePath;
  final String? title;

  const SvgViewerScreen({
    super.key,
    required this.filePath,
    this.title,
  });

  @override
  State<SvgViewerScreen> createState() => _SvgViewerScreenState();
}

class _SvgViewerScreenState extends State<SvgViewerScreen> {
  final TransformationController _transformController = TransformationController();

  String _svgContent = '';
  SvgMetadata _metadata = const SvgMetadata();
  bool _isLoading = true;
  String? _errorMessage;
  late String _fileName;
  int _fileSizeBytes = 0;

  SvgCanvasTheme _canvasTheme = SvgCanvasTheme.darkCad;
  bool _showGrid = true;
  double _currentScale = 1.0;

  @override
  void initState() {
    super.initState();
    _fileName = widget.title ?? widget.filePath.split(Platform.pathSeparator).last;
    _transformController.addListener(_onTransformChanged);
    _loadSvgFile();
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    if ((scale - _currentScale).abs() > 0.001) {
      setState(() {
        _currentScale = scale;
      });
    }
  }

  Future<void> _loadSvgFile() async {
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

      final content = await file.readAsString();
      final metadata = _parseSvgMetadata(content);

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
          _svgContent = content;
          _metadata = metadata;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading SVG: $e';
          _isLoading = false;
        });
      }
    }
  }

  SvgMetadata _parseSvgMetadata(String svg) {
    double? width;
    double? height;
    Rect? viewBox;

    // 1. Extract viewBox="minX minY width height"
    final vbMatch = RegExp(r'''viewBox\s*=\s*["']\s*([-\d.]+)[,\s]+([-\d.]+)[,\s]+([-\d.]+)[,\s]+([-\d.]+)''', caseSensitive: false).firstMatch(svg);
    if (vbMatch != null) {
      final minX = double.tryParse(vbMatch.group(1)!) ?? 0;
      final minY = double.tryParse(vbMatch.group(2)!) ?? 0;
      final vbW = double.tryParse(vbMatch.group(3)!) ?? 100;
      final vbH = double.tryParse(vbMatch.group(4)!) ?? 100;
      viewBox = Rect.fromLTWH(minX, minY, vbW, vbH);
      width = vbW;
      height = vbH;
    }

    // 2. Extract explicit width & height if available
    final widthMatch = RegExp(r'''<svg[^>]*\bwidth\s*=\s*["']([\d.]+)(?:px|pt|mm|cm)?["']''', caseSensitive: false).firstMatch(svg);
    if (widthMatch != null) {
      width = double.tryParse(widthMatch.group(1)!);
    }

    final heightMatch = RegExp(r'''<svg[^>]*\bheight\s*=\s*["']([\d.]+)(?:px|pt|mm|cm)?["']''', caseSensitive: false).firstMatch(svg);
    if (heightMatch != null) {
      height = double.tryParse(heightMatch.group(1)!);
    }

    // 3. Count elements
    final pathCount = RegExp(r'<path\b', caseSensitive: false).allMatches(svg).length;
    final shapeCount = RegExp(r'<(?:rect|circle|ellipse|line|polyline|polygon)\b', caseSensitive: false).allMatches(svg).length;
    final textCount = RegExp(r'<text\b', caseSensitive: false).allMatches(svg).length;

    return SvgMetadata(
      width: width,
      height: height,
      viewBox: viewBox,
      pathCount: pathCount,
      shapeCount: shapeCount,
      textCount: textCount,
    );
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

  void _showInfoDialog() {
    final formattedSize = _fileSizeBytes < 1024 * 1024
        ? '${(_fileSizeBytes / 1024).toStringAsFixed(1)} KB'
        : '${(_fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF8C00).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.gesture, color: Color(0xFFFF8C00), size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'SVG Информация',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Файл:', _fileName),
            _buildInfoRow('Размер:', formattedSize),
            if (_metadata.width != null && _metadata.height != null)
              _buildInfoRow('Размери:', '${_metadata.width!.toStringAsFixed(1)} × ${_metadata.height!.toStringAsFixed(1)} px'),
            if (_metadata.viewBox != null)
              _buildInfoRow('viewBox:', '${_metadata.viewBox!.width.toStringAsFixed(0)} × ${_metadata.viewBox!.height.toStringAsFixed(0)}'),
            const Divider(height: 20),
            _buildInfoRow('Векторни пътища (paths):', '${_metadata.pathCount}'),
            _buildInfoRow('Геометрични фигури:', '${_metadata.shapeCount}'),
            _buildInfoRow('Текстови елементи:', '${_metadata.textCount}'),
            _buildInfoRow('Общо елементи:', '${_metadata.totalElements}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Затвори'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Colors.white70),
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF8C00).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'SVG 2D Vector',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF8C00),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${(_currentScale * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Theme Switcher Menu
          PopupMenuButton<SvgCanvasTheme>(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Цветова тема на фона',
            onSelected: (t) => setState(() => _canvasTheme = t),
            itemBuilder: (context) => SvgCanvasTheme.values.map((t) {
              return PopupMenuItem<SvgCanvasTheme>(
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
            tooltip: 'Мрежа (Grid)',
            onPressed: () => setState(() => _showGrid = !_showGrid),
          ),

          // Info Dialog
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Информация',
            onPressed: _showInfoDialog,
          ),

          // Share Button
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Сподели',
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
                  Text('Loading SVG Vector...'),
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
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loadSvgFile,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Повторен опит'),
                    ),
                  ],
                ),
              ),
            );
          }

          final svgWidth = _metadata.width ?? _metadata.viewBox?.width ?? 600.0;
          final svgHeight = _metadata.height ?? _metadata.viewBox?.height ?? 600.0;

          return Stack(
            children: [
              // Interactive Canvas with Background Grid & SVG Rendering
              InteractiveViewer(
                transformationController: _transformController,
                minScale: 0.01,
                maxScale: 1000.0,
                boundaryMargin: const EdgeInsets.all(1200.0),
                child: CustomPaint(
                  painter: _showGrid
                      ? _SvgGridPainter(
                          gridColor: _canvasTheme.gridColor,
                          scale: _currentScale,
                        )
                      : null,
                  child: Center(
                    child: Container(
                      width: svgWidth,
                      height: svgHeight,
                      alignment: Alignment.center,
                      child: SvgPicture.string(
                        _svgContent,
                        width: svgWidth,
                        height: svgHeight,
                        fit: BoxFit.contain,
                      ),
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
                      tooltip: 'Приближи (+)',
                      onTap: _zoomIn,
                      theme: theme,
                    ),
                    const SizedBox(height: 8),
                    _buildFloatingButton(
                      icon: Icons.remove,
                      tooltip: 'Отдалечи (-)',
                      onTap: _zoomOut,
                      theme: theme,
                    ),
                    const SizedBox(height: 8),
                    _buildFloatingButton(
                      icon: Icons.fit_screen_outlined,
                      tooltip: 'Центрирай / Начален мащаб',
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

/// Custom painter to render dynamic background CAD grid for SVG canvas.
class _SvgGridPainter extends CustomPainter {
  final Color gridColor;
  final double scale;

  _SvgGridPainter({
    required this.gridColor,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final clampedScale = scale.clamp(0.001, 1000.0);
    double step = 40.0;

    if (clampedScale > 3.0) {
      step = 20.0;
    } else if (clampedScale < 0.4) {
      step = 100.0;
    }

    final paint = Paint()
      ..color = gridColor.withValues(alpha: 0.35)
      ..strokeWidth = 0.8
      ..isAntiAlias = true;

    // Draw vertical grid lines
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal grid lines
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SvgGridPainter oldDelegate) {
    return oldDelegate.gridColor != gridColor || (oldDelegate.scale - scale).abs() > 0.05;
  }
}
