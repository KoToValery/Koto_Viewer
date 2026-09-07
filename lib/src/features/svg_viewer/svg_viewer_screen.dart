import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/models/pdf_item.dart';
import '../../core/services/recent_files_service.dart';

/// Available canvas themes for the SVG viewer.
enum SvgCanvasTheme {
  lightStudio('Light Studio', Color(0xFFF2F2F6), Color(0xFFDCDCE4)),
  darkStudio('Dark Studio', Color(0xFF1E1E24), Color(0xFF2C2C34)),
  pureWhite('Pure White', Color(0xFFFFFFFF), Color(0xFFE5E5E5)),
  pureBlack('Pure Black', Color(0xFF121212), Color(0xFF242424)),
  darkCad('Dark CAD', Color(0xFF1E1E1E), Color(0xFF2E2E2E)),
  blueprint('Blueprint', Color(0xFF0D253A), Color(0xFF194364));

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
  final int imageCount;

  const SvgMetadata({
    this.width,
    this.height,
    this.viewBox,
    this.pathCount = 0,
    this.shapeCount = 0,
    this.textCount = 0,
    this.imageCount = 0,
  });

  int get totalElements => pathCount + shapeCount + textCount + imageCount;

  String get summary {
    final List<String> parts = [];
    if (pathCount > 0) parts.add('$pathCount paths');
    if (shapeCount > 0) parts.add('$shapeCount shapes');
    if (textCount > 0) parts.add('$textCount text');
    if (imageCount > 0) parts.add('$imageCount images');
    return parts.isEmpty ? '$totalElements elements' : parts.join(', ');
  }
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

  SvgCanvasTheme _canvasTheme = SvgCanvasTheme.lightStudio;
  bool _showWhitePage = true;
  bool _showGrid = true;
  double _currentScale = 1.0;
  bool _hasFittedInitial = false;

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

          debugPrint('[SVG_VIEWER] Loaded "${widget.filePath}": ${metadata.summary}, viewBox=${metadata.viewBox}, size=${metadata.width}x${metadata.height}');

          if (!_viewportSize.isEmpty) {
            _hasFittedInitial = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _fitToScreen();
            });
          }
        }
    } catch (e) {
      await RecentFilesService.removeRecentFile(widget.filePath);
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading SVG: $e';
          _isLoading = false;
        });
      }
    }
  }

  static double _convertUnitToPixels(double val, String unit) {
    switch (unit) {
      case 'mm':
        return val * 3.7795275591;
      case 'cm':
        return val * 37.795275591;
      case 'in':
        return val * 96.0;
      case 'pt':
        return val * 1.3333333333;
      default:
        return val;
    }
  }

  SvgMetadata _parseSvgMetadata(String svg) {
    double? width;
    double? height;
    Rect? viewBox;

    final vbMatch = RegExp(
      r'''viewBox\s*=\s*["']\s*([-\d.]+)[,\s]+([-\d.]+)[,\s]+([-\d.]+)[,\s]+([-\d.]+)''',
      caseSensitive: false,
    ).firstMatch(svg);
    if (vbMatch != null) {
      final minX = double.tryParse(vbMatch.group(1)!) ?? 0;
      final minY = double.tryParse(vbMatch.group(2)!) ?? 0;
      final vbW = double.tryParse(vbMatch.group(3)!) ?? 100;
      final vbH = double.tryParse(vbMatch.group(4)!) ?? 100;
      if (vbW > 0 && vbH > 0) {
        viewBox = Rect.fromLTWH(minX, minY, vbW, vbH);
        width = vbW;
        height = vbH;
      }
    }

    if (viewBox == null) {
      final widthMatch = RegExp(
        r'''<svg[^>]*\bwidth\s*=\s*["']([\d.]+)(px|pt|mm|cm|in)?["']''',
        caseSensitive: false,
      ).firstMatch(svg);
      if (widthMatch != null) {
        final val = double.tryParse(widthMatch.group(1)!);
        final unit = widthMatch.group(2)?.toLowerCase() ?? 'px';
        if (val != null && val > 0) {
          width = _convertUnitToPixels(val, unit);
        }
      }

      final heightMatch = RegExp(
        r'''<svg[^>]*\bheight\s*=\s*["']([\d.]+)(px|pt|mm|cm|in)?["']''',
        caseSensitive: false,
      ).firstMatch(svg);
      if (heightMatch != null) {
        final val = double.tryParse(heightMatch.group(1)!);
        final unit = heightMatch.group(2)?.toLowerCase() ?? 'px';
        if (val != null && val > 0) {
          height = _convertUnitToPixels(val, unit);
        }
      }
    }

    final pathCount = RegExp(r'<path\b', caseSensitive: false).allMatches(svg).length;
    final shapeCount = RegExp(r'<(?:rect|circle|ellipse|line|polyline|polygon)\b', caseSensitive: false).allMatches(svg).length;
    final textCount = RegExp(r'<text\b', caseSensitive: false).allMatches(svg).length;
    final imageCount = RegExp(r'<image\b', caseSensitive: false).allMatches(svg).length;

    return SvgMetadata(
      width: width,
      height: height,
      viewBox: viewBox,
      pathCount: pathCount,
      shapeCount: shapeCount,
      textCount: textCount,
      imageCount: imageCount,
    );
  }

  Size _viewportSize = Size.zero;

  void _fitToScreen() {
    if (_viewportSize.isEmpty) {
      _transformController.value = Matrix4.identity();
      return;
    }

    final svgWidth = _metadata.width ?? _metadata.viewBox?.width ?? 600.0;
    final svgHeight = _metadata.height ?? _metadata.viewBox?.height ?? 600.0;

    const double padding = 32.0;
    final double availW = math.max(_viewportSize.width - padding * 2, 10.0);
    final double availH = math.max(_viewportSize.height - padding * 2, 10.0);

    final double scale = math.min(availW / svgWidth, availH / svgHeight);

    final double dx = (_viewportSize.width - svgWidth * scale) / 2.0;
    final double dy = (_viewportSize.height - svgHeight * scale) / 2.0;

    final matrix = Matrix4.identity()
      ..translateByDouble(dx, dy, 0.0, 1.0)
      ..scaleByDouble(scale, scale, 1.0, 1.0);

    _transformController.value = matrix;
    debugPrint('[SVG_VIEWER] _fitToScreen: viewport=$_viewportSize, svg=${svgWidth.toStringAsFixed(1)}x${svgHeight.toStringAsFixed(1)}, scale=${scale.toStringAsFixed(4)}, dx=${dx.toStringAsFixed(1)}, dy=${dy.toStringAsFixed(1)}');
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
      ..translateByDouble(dx, dy, 0.0, 1.0)
      ..scaleByDouble(newScale, newScale, 1.0, 1.0);

    _transformController.value = newMatrix;
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final double zoomFactor = event.scrollDelta.dy < 0 ? 1.15 : 0.85;
      _zoomBy(zoomFactor, focalPoint: event.localPosition);
    }
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
              child: const Icon(Icons.palette_rounded, color: Color(0xFFFF8C00)),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'SVG Properties',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('File Name', _fileName),
            _buildInfoRow('File Size', formattedSize),
            if (_metadata.width != null && _metadata.height != null)
              _buildInfoRow(
                'Dimensions',
                '${_metadata.width!.toStringAsFixed(0)} × ${_metadata.height!.toStringAsFixed(0)} px',
              ),
            if (_metadata.viewBox != null)
              _buildInfoRow(
                'ViewBox',
                '${_metadata.viewBox!.width.toStringAsFixed(0)} × ${_metadata.viewBox!.height.toStringAsFixed(0)}',
              ),
            _buildInfoRow('Paths', '${_metadata.pathCount}'),
            _buildInfoRow('Basic Shapes', '${_metadata.shapeCount}'),
            if (_metadata.textCount > 0)
              _buildInfoRow('Text Elements', '${_metadata.textCount}'),
            if (_metadata.imageCount > 0)
              _buildInfoRow('Embedded Images', '${_metadata.imageCount}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.grey, fontSize: 13)),
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
        title: Text(
          _fileName,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.brightness == Brightness.dark ? Colors.white10 : Colors.black12,
                ),
              ),
            ),
            child: Row(
              children: [
                const Spacer(),

                // White Page Sheet Toggle
                IconButton(
                  icon: Icon(
                    _showWhitePage ? Icons.description : Icons.description_outlined,
                    size: 20,
                    color: _showWhitePage ? theme.colorScheme.primary : null,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  tooltip: _showWhitePage ? 'White Page: ON' : 'White Page: OFF (Transparent)',
                  onPressed: () => setState(() => _showWhitePage = !_showWhitePage),
                ),

                // Fit to Screen Button
                IconButton(
                  icon: const Icon(Icons.fit_screen_outlined, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  tooltip: 'Fit to Screen',
                  onPressed: _svgContent.isNotEmpty ? _fitToScreen : null,
                ),

                // Theme Switcher Menu
                PopupMenuButton<SvgCanvasTheme>(
                  icon: const Icon(Icons.palette_outlined, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  tooltip: 'Canvas Theme',
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
                    size: 20,
                    color: _showGrid ? theme.colorScheme.primary : null,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  tooltip: 'Grid',
                  onPressed: () => setState(() => _showGrid = !_showGrid),
                ),

                // Info Dialog
                IconButton(
                  icon: const Icon(Icons.info_outline, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  tooltip: 'Information',
                  onPressed: _showInfoDialog,
                ),

                // Share Button
                IconButton(
                  icon: const Icon(Icons.share_outlined, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  tooltip: 'Share',
                  onPressed: _shareFile,
                ),
              ],
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final newSize = Size(constraints.maxWidth, constraints.maxHeight);
          final wasEmpty = _viewportSize.isEmpty;
          _viewportSize = newSize;

          if ((wasEmpty || !_hasFittedInitial) && !newSize.isEmpty && _svgContent.isNotEmpty) {
            _hasFittedInitial = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _fitToScreen();
            });
          }

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
                      label: const Text('Retry'),
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
              // Background Grid
              if (_showGrid)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SvgGridPainter(
                      gridColor: _canvasTheme.gridColor,
                      scale: _currentScale,
                    ),
                  ),
                ),

              // Interactive Canvas with SVG Rendering + Mouse Wheel
              Listener(
                onPointerSignal: _handlePointerSignal,
                child: InteractiveViewer(
                  transformationController: _transformController,
                  minScale: 0.002,
                  maxScale: 2000.0,
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(2500.0),
                  child: Container(
                    width: svgWidth,
                    height: svgHeight,
                    decoration: BoxDecoration(
                      color: _showWhitePage ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: _showWhitePage
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 16,
                                spreadRadius: 1,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SvgPicture.file(
                      File(widget.filePath),
                      width: svgWidth,
                      height: svgHeight,
                      fit: BoxFit.contain,
                      placeholderBuilder: (context) => const Center(
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('[SVG_VIEWER] SvgPicture.file error: $error, falling back to SvgPicture.string');
                        return SvgPicture.string(
                          _svgContent,
                          width: svgWidth,
                          height: svgHeight,
                          fit: BoxFit.contain,
                          errorBuilder: (context, strErr, strStack) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  'Error rendering SVG: $strErr',
                                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          },
                        );
                      },
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
