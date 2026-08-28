import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/services/recent_files_service.dart';
import 'models/cdr_document.dart';
import 'parser/cdr_parser.dart';

/// Interactive CorelDRAW (.cdr) Vector Graphics Viewer Screen.
class CdrViewerScreen extends StatefulWidget {
  final String filePath;

  const CdrViewerScreen({super.key, required this.filePath});

  @override
  State<CdrViewerScreen> createState() => _CdrViewerScreenState();
}

class _CdrViewerScreenState extends State<CdrViewerScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  int _fileSizeBytes = 0;

  CdrDocument? _document;
  CdrCanvasTheme _canvasTheme = CdrCanvasTheme.darkCad;
  int _rotationQuarterTurns = 0; // 0 = 0°, 1 = 90°, 2 = 180°, 3 = 270°
  bool _flipHorizontal = false;
  bool _flipVertical = false;

  final TransformationController _transformController = TransformationController();

  String get _fileName => widget.filePath.split(Platform.pathSeparator).last;

  @override
  void initState() {
    super.initState();
    _loadCdrFile();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _loadCdrFile() async {
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

      final doc = CdrParser.parse(bytes, fileSizeBytes: _fileSizeBytes);

      if (mounted) {
        setState(() {
          _document = doc;
          _isLoading = false;
        });
      }
    } catch (e) {
      await RecentFilesService.removeRecentFile(widget.filePath);
      if (mounted) {
        setState(() {
          _errorMessage = 'Error reading CorelDRAW file:\n$e';
          _isLoading = false;
        });
      }
    }
  }

  void _rotateClockwise() {
    HapticFeedback.selectionClick();
    setState(() {
      _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
    });
  }

  void _resetTransform() {
    HapticFeedback.selectionClick();
    setState(() {
      _rotationQuarterTurns = 0;
      _flipHorizontal = false;
      _flipVertical = false;
      _transformController.value = Matrix4.identity();
    });
  }

  void _showPropertiesSheet() {
    if (_document == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF131A26) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.palette_outlined,
                        color: Color(0xFF16A34A),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CorelDRAW • Document Info',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _fileName,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _buildInfoTile('Version / Generator:', _document!.generator, Icons.computer_rounded, isDark),
                if (_document!.title != null && _document!.title!.isNotEmpty)
                  _buildInfoTile('Title:', _document!.title!, Icons.title_rounded, isDark),
                _buildInfoTile('Resolution:', _document!.formattedDimensions, Icons.aspect_ratio_rounded, isDark),
                _buildInfoTile('Container Type:', _document!.isZipBased ? 'Modern ZIP Container (X4+)' : 'Legacy RIFF Container (v3–X3)', Icons.archive_outlined, isDark),
                _buildInfoTile('Pages:', '${_document!.pageCount} page(s)', Icons.layers_outlined, isDark),
                _buildInfoTile('File Size:', _document!.formattedFileSize, Icons.sd_storage_outlined, isDark),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF16A34A)),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareOriginalCdr() async {
    try {
      await Share.shareXFiles(
        [XFile(widget.filePath, name: _fileName, mimeType: 'application/vnd.corel-draw')],
        text: _fileName,
      );
    } catch (_) {}
  }

  Future<void> _exportAndSharePng() async {
    if (_document == null) return;
    try {
      final tempDir = await getTemporaryDirectory();
      final baseName = _fileName.replaceAll(RegExp(r'\.cdr$', caseSensitive: false), '');
      final pngPath = '${tempDir.path}${Platform.pathSeparator}${baseName}_preview.png';
      final pngFile = File(pngPath);
      await pngFile.writeAsBytes(_document!.imageBytes);

      await Share.shareXFiles(
        [XFile(pngPath, name: '${baseName}_preview.png', mimeType: 'image/png')],
        text: 'Exported from $_fileName',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export PNG: $e')),
        );
      }
    }
  }

  Future<void> _printDocument() async {
    if (_document == null) return;
    try {
      await Printing.layoutPdf(
        onLayout: (format) async => _document!.imageBytes,
        name: _fileName,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: _canvasTheme.background,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0.5,
        title: Text(
          _fileName,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: const [],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0B132B) : const Color(0xFFF1F5F9),
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                  width: 0.5,
                ),
                bottom: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                const Spacer(),

                // Theme Switcher
                PopupMenuButton<CdrCanvasTheme>(
                  icon: const Icon(Icons.palette_outlined, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  tooltip: 'Canvas Background',
                  onSelected: (t) => setState(() => _canvasTheme = t),
                  itemBuilder: (_) => CdrCanvasTheme.values.map((t) {
                    final isSelected = _canvasTheme == t;
                    return PopupMenuItem(
                      value: t,
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: t.background,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.grey),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(t.label),
                          if (isSelected) ...[
                            const Spacer(),
                            const Icon(Icons.check, size: 16, color: Color(0xFF16A34A)),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),

                // Rotate 90° Clockwise
                IconButton(
                  icon: const Icon(Icons.rotate_right_rounded, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  tooltip: 'Rotate 90°',
                  onPressed: _rotateClockwise,
                ),

                // Flip Options
                PopupMenuButton<String>(
                  icon: const Icon(Icons.flip_rounded, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  tooltip: 'Flip Orientation',
                  onSelected: (v) {
                    setState(() {
                      if (v == 'horizontal') _flipHorizontal = !_flipHorizontal;
                      if (v == 'vertical') _flipVertical = !_flipVertical;
                    });
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'horizontal',
                      child: Row(
                        children: [
                          const Icon(Icons.swap_horiz_rounded, size: 18),
                          const SizedBox(width: 10),
                          const Text('Flip Horizontal'),
                          if (_flipHorizontal) ...[
                            const Spacer(),
                            const Icon(Icons.check, size: 16, color: Color(0xFF16A34A)),
                          ],
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'vertical',
                      child: Row(
                        children: [
                          const Icon(Icons.swap_vert_rounded, size: 18),
                          const SizedBox(width: 10),
                          const Text('Flip Vertical'),
                          if (_flipVertical) ...[
                            const Spacer(),
                            const Icon(Icons.check, size: 16, color: Color(0xFF16A34A)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                // Document Properties
                IconButton(
                  icon: const Icon(Icons.info_outline_rounded, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  tooltip: 'Properties',
                  onPressed: _showPropertiesSheet,
                ),

                // Share / Export Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.share_outlined, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                  tooltip: 'Share & Export',
                  onSelected: (v) {
                    if (v == 'share_cdr') _shareOriginalCdr();
                    if (v == 'export_png') _exportAndSharePng();
                    if (v == 'print') _printDocument();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'share_cdr',
                      child: Row(
                        children: [
                          Icon(Icons.file_upload_outlined, size: 18),
                          SizedBox(width: 10),
                          Text('Share Original .CDR'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'export_png',
                      child: Row(
                        children: [
                          Icon(Icons.image_outlined, size: 18),
                          SizedBox(width: 10),
                          Text('Export as PNG Image'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'print',
                      child: Row(
                        children: [
                          Icon(Icons.print_outlined, size: 18),
                          SizedBox(width: 10),
                          Text('Print / Export PDF'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF16A34A)),
            SizedBox(height: 16),
            Text('Opening CorelDRAW vector design...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image_rounded, size: 54, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                onPressed: _loadCdrFile,
              ),
            ],
          ),
        ),
      );
    }

    if (_document == null) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // Background grid for checkerboard
            if (_canvasTheme == CdrCanvasTheme.checkerboard)
              Positioned.fill(
                child: CustomPaint(
                  painter: _CheckerboardPainter(
                    color1: const Color(0xFF2A2A2A),
                    color2: const Color(0xFF383838),
                  ),
                ),
              ),

            // Interactive Image Viewer
            InteractiveViewer(
              transformationController: _transformController,
              minScale: 0.1,
              maxScale: 30.0,
              boundaryMargin: const EdgeInsets.all(300),
              child: Center(
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..rotateZ(_rotationQuarterTurns * (math.pi / 2.0))
                    ..scaleByDouble(
                      _flipHorizontal ? -1.0 : 1.0,
                      _flipVertical ? -1.0 : 1.0,
                      1.0,
                      1.0,
                    ),
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Image.memory(
                      _document!.imageBytes,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, error, _) {
                        return Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text('Failed to render preview: $error'),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

            // Floating Navigation & Fit Controls
            Positioned(
              bottom: 24,
              right: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildFloatingBtn(
                    icon: Icons.add,
                    tooltip: 'Zoom In (+)',
                    onTap: () {
                      final m = _transformController.value.clone();
                      m.scaleByDouble(1.25, 1.25, 1.0, 1.0);
                      _transformController.value = m;
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildFloatingBtn(
                    icon: Icons.remove,
                    tooltip: 'Zoom Out (-)',
                    onTap: () {
                      final m = _transformController.value.clone();
                      m.scaleByDouble(0.8, 0.8, 1.0, 1.0);
                      _transformController.value = m;
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildFloatingBtn(
                    icon: Icons.fit_screen_outlined,
                    tooltip: 'Reset View',
                    onTap: _resetTransform,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFloatingBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.95),
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon, size: 20),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for Photoshop/CorelDRAW style transparent checkerboard canvas.
class _CheckerboardPainter extends CustomPainter {
  final Color color1;
  final Color color2;
  static const double squareSize = 16.0;

  const _CheckerboardPainter({
    required this.color1,
    required this.color2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()..color = color1;
    final paint2 = Paint()..color = color2;

    final cols = (size.width / squareSize).ceil();
    final rows = (size.height / squareSize).ceil();

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final paint = (r + c) % 2 == 0 ? paint1 : paint2;
        canvas.drawRect(
          Rect.fromLTWH(c * squareSize, r * squareSize, squareSize, squareSize),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CheckerboardPainter oldDelegate) => false;
}