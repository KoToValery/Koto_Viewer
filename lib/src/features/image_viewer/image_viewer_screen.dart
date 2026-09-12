import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/recent_files_service.dart';

class _IcoFrame {
  final int width;
  final int height;
  final Uint8List pngBytes;

  _IcoFrame({
    required this.width,
    required this.height,
    required this.pngBytes,
  });
}

/// Interactive Image Viewer Screen supporting PNG, JPG, JPEG, WEBP, GIF, BMP, ICO, and PSD.
class ImageViewerScreen extends StatefulWidget {
  final String filePath;

  const ImageViewerScreen({
    super.key,
    required this.filePath,
  });

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  bool _isLoading = true;
  String? _error;

  // Formats
  bool _isIco = false;
  bool _isPsd = false;

  // Decoded image data
  List<_IcoFrame>? _icoFrames;
  Uint8List? _psdBytes;
  Uint8List? _rasterBytes;

  // Metadata
  int? _imageWidth;
  int? _imageHeight;
  int _fileSizeBytes = 0;
  DateTime? _fileLastModified;
  String _formatLabel = '';

  // UI / View State
  int _selectedFrameIndex = 0; // For ICO
  bool _showGrid = false; // For ICO
  bool _pixelated = false;
  int _bgMode = 0; // 0 = checkerboard, 1 = dark, 2 = light
  int _rotationQuarterTurns = 0; // 0 = 0°, 1 = 90°, 2 = 180°, 3 = 270°
  bool _flipHorizontal = false;
  bool _flipVertical = false;

  final TransformationController _transformationController =
      TransformationController();

  String get _fileName => widget.filePath.contains('/')
      ? widget.filePath.split('/').where((s) => s.isNotEmpty).last
      : widget.filePath.split(Platform.pathSeparator).last;

  String get _formattedFileSize {
    if (_fileSizeBytes < 1024) return '$_fileSizeBytes B';
    if (_fileSizeBytes < 1024 * 1024) {
      return '${(_fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(_fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final lower = widget.filePath.toLowerCase();
    _isIco = lower.endsWith('.ico');
    _isPsd = lower.endsWith('.psd') || lower.endsWith('.psb');

    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        throw Exception('File not found: ${widget.filePath}');
      }

      _fileSizeBytes = await file.length();
      final stat = await file.stat();
      _fileLastModified = stat.modified;

      if (_isIco) {
        _formatLabel = 'ICO Icon';
        final frames = await compute(_decodeIcoCompute, widget.filePath);
        if (mounted) {
          setState(() {
            _icoFrames = frames;
            _isLoading = false;
            _selectedFrameIndex = 0;
            if (frames.isEmpty) {
              _error = 'Could not decode ICO frames.';
            } else {
              _imageWidth = frames.first.width;
              _imageHeight = frames.first.height;
            }
          });
        }
      } else if (_isPsd) {
        _formatLabel = 'PSD Document';
        final bytes = await compute(_decodePsdCompute, widget.filePath);
        if (bytes != null) {
          try {
            final decoded = img.decodeImage(bytes);
            if (decoded != null) {
              _imageWidth = decoded.width;
              _imageHeight = decoded.height;
            }
          } catch (_) {}
        }
        if (mounted) {
          setState(() {
            _psdBytes = bytes;
            _isLoading = false;
            if (bytes == null) {
              _error = 'Could not decode PSD composite image.';
            }
          });
        }
      } else {
        // Standard raster image (PNG, JPG, JPEG, WEBP, GIF, BMP)
        final bytes = await file.readAsBytes();
        int? w;
        int? h;

        try {
          final decoded = img.decodeImage(bytes);
          if (decoded != null) {
            w = decoded.width;
            h = decoded.height;
          }
        } catch (_) {}

        final ext = widget.filePath.contains('.')
            ? widget.filePath.split('.').last.toUpperCase()
            : 'IMAGE';

        switch (ext) {
          case 'PNG':
            _formatLabel = 'PNG Image';
            break;
          case 'JPG':
          case 'JPEG':
            _formatLabel = 'JPEG Photo';
            break;
          case 'WEBP':
            _formatLabel = 'WebP Image';
            break;
          case 'GIF':
            _formatLabel = 'GIF Animation';
            break;
          case 'BMP':
            _formatLabel = 'BMP Bitmap';
            break;
          default:
            _formatLabel = '$ext Image';
        }

        if (mounted) {
          setState(() {
            _rasterBytes = bytes;
            _imageWidth = w;
            _imageHeight = h;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      await RecentFilesService.removeRecentFile(widget.filePath);
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
          _isLoading = false;
        });
      }
    }
  }

  static List<_IcoFrame> _decodeIcoCompute(String filePath) {
    final bytes = File(filePath).readAsBytesSync();
    final decoder = img.IcoDecoder();
    if (!decoder.isValidFile(bytes)) return [];
    decoder.startDecode(bytes);
    final frames = <_IcoFrame>[];
    final count = (decoder.numFrames() as num).toInt();
    for (int i = 0; i < count; i++) {
      final frame = decoder.decodeFrame(i);
      if (frame != null) {
        frames.add(_IcoFrame(
          width: frame.width,
          height: frame.height,
          pngBytes: Uint8List.fromList(img.encodePng(frame)),
        ));
      }
    }
    // Sort by size descending so highest resolution comes first
    frames.sort((a, b) => (b.width * b.height).compareTo(a.width * a.height));
    return frames;
  }

  static Uint8List? _decodePsdCompute(String filePath) {
    final bytes = File(filePath).readAsBytesSync();
    final decoded = img.PsdDecoder().decode(bytes);
    if (decoded == null) return null;
    return Uint8List.fromList(img.encodePng(decoded));
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  void _resetTransform() {
    setState(() {
      _rotationQuarterTurns = 0;
      _flipHorizontal = false;
      _flipVertical = false;
      _resetZoom();
    });
  }

  void _rotate90() {
    setState(() {
      _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
    });
  }

  void _toggleFlipH() {
    setState(() => _flipHorizontal = !_flipHorizontal);
  }

  void _toggleFlipV() {
    setState(() => _flipVertical = !_flipVertical);
  }

  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      _resetZoom();
    } else {
      _transformationController.value = Matrix4.identity()..scale(2.5, 2.5);
    }
  }

  void _zoomIn() {
    final m = _transformationController.value.clone();
    m.scaleByDouble(1.25, 1.25, 1.0, 1.0);
    _transformationController.value = m;
  }

  void _zoomOut() {
    final m = _transformationController.value.clone();
    m.scaleByDouble(0.8, 0.8, 1.0, 1.0);
    _transformationController.value = m;
  }

  Future<void> _shareCurrentFile() async {
    if (_isIco && _icoFrames != null && _icoFrames!.isNotEmpty) {
      await _shareCurrentFrame();
    } else {
      await Share.shareXFiles([XFile(widget.filePath)], subject: _fileName);
    }
  }

  Future<void> _shareCurrentFrame() async {
    if (_icoFrames == null || _icoFrames!.isEmpty) {
      await Share.shareXFiles([XFile(widget.filePath)]);
      return;
    }

    final frame = _icoFrames![_selectedFrameIndex];
    try {
      final tempDir = await getTemporaryDirectory();
      final nameWithoutExt = _fileName.replaceAll(RegExp(r'\.ico$', caseSensitive: false), '');
      final framePath = '${tempDir.path}/${nameWithoutExt}_${frame.width}x${frame.height}.png';
      final file = File(framePath);
      await file.writeAsBytes(frame.pngBytes);
      await Share.shareXFiles(
        [XFile(framePath, mimeType: 'image/png', name: '${nameWithoutExt}_${frame.width}x${frame.height}.png')],
        text: '$_fileName (${frame.width}x${frame.height})',
      );
    } catch (_) {
      await Share.shareXFiles([XFile(widget.filePath)]);
    }
  }

  Future<void> _printOrExportPdf() async {
    final bytes = _rasterBytes ??
        (_psdBytes ??
            (_icoFrames != null && _icoFrames!.isNotEmpty
                ? _icoFrames![_selectedFrameIndex].pngBytes
                : null));

    if (bytes == null) return;

    try {
      final doc = pw.Document();
      final imgWidget = pw.MemoryImage(bytes);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context ctx) {
            return pw.Center(
              child: pw.Image(imgWidget, fit: pw.BoxFit.contain),
            );
          },
        ),
      );
      await Printing.layoutPdf(
        onLayout: (format) async => doc.save(),
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

  void _showPropertiesSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String resolutionStr = 'Unknown';
    String mpStr = '';
    String aspectStr = '';

    if (_imageWidth != null && _imageHeight != null) {
      resolutionStr = '$_imageWidth × $_imageHeight px';
      final mp = (_imageWidth! * _imageHeight!) / 1000000.0;
      mpStr = '${mp.toStringAsFixed(2)} MP';

      final gcd = _calculateGcd(_imageWidth!, _imageHeight!);
      final rw = _imageWidth! ~/ gcd;
      final rh = _imageHeight! ~/ gcd;
      if (rw <= 32 && rh <= 32) {
        aspectStr = '$rw:$rh';
      } else {
        final ratio = _imageWidth! / _imageHeight!;
        aspectStr = '${ratio.toStringAsFixed(2)}:1';
      }
    }

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
                        color: const Color(0xFFDB2777).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.image_rounded,
                        color: Color(0xFFDB2777),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Image Properties',
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
                _buildInfoRow('Format:', _formatLabel, Icons.category_rounded, isDark),
                _buildInfoRow('Resolution:', resolutionStr, Icons.aspect_ratio_rounded, isDark),
                if (mpStr.isNotEmpty)
                  _buildInfoRow('Megapixels:', mpStr, Icons.camera_alt_outlined, isDark),
                if (aspectStr.isNotEmpty)
                  _buildInfoRow('Aspect Ratio:', aspectStr, Icons.crop_rounded, isDark),
                _buildInfoRow('File Size:', _formattedFileSize, Icons.sd_storage_outlined, isDark),
                if (_fileLastModified != null)
                  _buildInfoRow(
                    'Modified:',
                    '${_fileLastModified!.year}-${_fileLastModified!.month.toString().padLeft(2, '0')}-${_fileLastModified!.day.toString().padLeft(2, '0')} ${_fileLastModified!.hour.toString().padLeft(2, '0')}:${_fileLastModified!.minute.toString().padLeft(2, '0')}',
                    Icons.access_time_rounded,
                    isDark,
                  ),
                _buildInfoRow('Path:', widget.filePath, Icons.folder_outlined, isDark),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  int _calculateGcd(int a, int b) {
    while (b != 0) {
      final t = b;
      b = a % b;
      a = t;
    }
    return a;
  }

  Widget _buildInfoRow(String label, String value, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFFDB2777)),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _fileName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_imageWidth != null && _imageHeight != null)
              Text(
                '${_imageWidth}×$_imageHeight • $_formatLabel • $_formattedFileSize',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
          ],
        ),
        actions: [
          if (_isIco && _icoFrames != null && _icoFrames!.isNotEmpty) ...[
            // Background mode toggle (Checkerboard / Dark / Light)
            IconButton(
              icon: Icon(
                _bgMode == 0
                    ? Icons.grid_on_rounded
                    : _bgMode == 1
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                size: 20,
              ),
              tooltip: _bgMode == 0
                  ? 'Background: Checkerboard'
                  : _bgMode == 1
                      ? 'Background: Dark'
                      : 'Background: Light',
              onPressed: () {
                setState(() {
                  _bgMode = (_bgMode + 1) % 3;
                });
              },
            ),
            // Pixelated / Sharp toggle
            if (!_showGrid)
              IconButton(
                icon: Icon(
                  _pixelated ? Icons.grain_rounded : Icons.blur_linear_rounded,
                  size: 20,
                ),
                tooltip: _pixelated ? 'Rendering: Crisp (Pixel-perfect)' : 'Rendering: Smooth',
                onPressed: () {
                  setState(() {
                    _pixelated = !_pixelated;
                  });
                },
              ),
            // View Mode: Single vs Grid
            IconButton(
              icon: Icon(
                _showGrid ? Icons.image_rounded : Icons.grid_view_rounded,
                size: 20,
              ),
              tooltip: _showGrid ? 'Single Image View' : 'All Resolutions Grid',
              onPressed: () {
                setState(() {
                  _showGrid = !_showGrid;
                  if (!_showGrid) _resetZoom();
                });
              },
            ),
            // Properties
            IconButton(
              icon: const Icon(Icons.info_outline_rounded, size: 20),
              tooltip: 'Properties',
              onPressed: _showPropertiesSheet,
            ),
            // Share menu
            PopupMenuButton<String>(
              icon: const Icon(Icons.share_rounded, size: 20),
              tooltip: 'Share',
              onSelected: (val) {
                if (val == 'frame') {
                  _shareCurrentFrame();
                } else if (val == 'print') {
                  _printOrExportPdf();
                } else {
                  Share.shareXFiles([XFile(widget.filePath)]);
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'frame',
                  child: Row(
                    children: [
                      const Icon(Icons.photo_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text('Share size (${_icoFrames![_selectedFrameIndex].width}×${_icoFrames![_selectedFrameIndex].height} PNG)'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'file',
                  child: Row(
                    children: [
                      Icon(Icons.file_copy_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Share original .ico file'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'print',
                  child: Row(
                    children: [
                      Icon(Icons.print_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Print / Save as PDF'),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            // Standard Raster & PSD Actions
            // Background toggle
            IconButton(
              icon: Icon(
                _bgMode == 0
                    ? Icons.grid_on_rounded
                    : _bgMode == 1
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                size: 20,
              ),
              tooltip: _bgMode == 0
                  ? 'Background: Checkerboard'
                  : _bgMode == 1
                      ? 'Background: Dark'
                      : 'Background: Light',
              onPressed: () {
                setState(() {
                  _bgMode = (_bgMode + 1) % 3;
                });
              },
            ),
            // Pixelated / Sharp toggle
            IconButton(
              icon: Icon(
                _pixelated ? Icons.grain_rounded : Icons.blur_linear_rounded,
                size: 20,
              ),
              tooltip: _pixelated ? 'Rendering: Crisp (Pixel-perfect)' : 'Rendering: Smooth',
              onPressed: () {
                setState(() {
                  _pixelated = !_pixelated;
                });
              },
            ),
            // Rotate 90°
            IconButton(
              icon: const Icon(Icons.rotate_right_rounded, size: 21),
              tooltip: 'Rotate 90°',
              onPressed: _rotate90,
            ),
            // Flip Menu
            PopupMenuButton<String>(
              icon: const Icon(Icons.flip_rounded, size: 20),
              tooltip: 'Flip Image',
              onSelected: (val) {
                if (val == 'h') _toggleFlipH();
                if (val == 'v') _toggleFlipV();
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'h',
                  child: Row(
                    children: [
                      const Icon(Icons.swap_horiz_rounded, size: 18),
                      const SizedBox(width: 8),
                      const Text('Flip Horizontal'),
                      if (_flipHorizontal) ...[
                        const Spacer(),
                        const Icon(Icons.check, size: 16, color: Color(0xFF16A34A)),
                      ],
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'v',
                  child: Row(
                    children: [
                      const Icon(Icons.swap_vert_rounded, size: 18),
                      const SizedBox(width: 8),
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
            // Properties
            IconButton(
              icon: const Icon(Icons.info_outline_rounded, size: 20),
              tooltip: 'Properties',
              onPressed: _showPropertiesSheet,
            ),
            // Share & Export Menu
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 20),
              tooltip: 'More Actions',
              onSelected: (val) {
                if (val == 'share') _shareCurrentFile();
                if (val == 'print') _printOrExportPdf();
                if (val == 'reset') _resetTransform();
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Share File'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'print',
                  child: Row(
                    children: [
                      Icon(Icons.print_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Print / Save PDF'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'reset',
                  child: Row(
                    children: [
                      Icon(Icons.fit_screen_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Reset View & Transforms'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image_rounded, size: 54, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadImage,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Loading $_fileName...'),
          ],
        ),
      );
    }

    if (_isPsd && _psdBytes != null) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            child: const Text(
              'Flattened composite preview — layers are not shown.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ),
          Expanded(child: _buildInteractiveImageView(_psdBytes!)),
        ],
      );
    }

    if (_isIco && _icoFrames != null && _icoFrames!.isNotEmpty) {
      return _showGrid ? _buildIcoGridView() : _buildIcoSingleView();
    }

    if (_rasterBytes != null) {
      return _buildInteractiveImageView(_rasterBytes!);
    }

    return const SizedBox();
  }

  Widget _buildInteractiveImageView(Uint8List imageBytes) {
    return Stack(
      children: [
        Positioned.fill(
          child: _buildBackgroundContainer(
            child: GestureDetector(
              onDoubleTap: _handleDoubleTap,
              child: InteractiveViewer(
                transformationController: _transformationController,
                minScale: 0.05,
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
                    child: Image.memory(
                      imageBytes,
                      fit: BoxFit.contain,
                      filterQuality: _pixelated ? FilterQuality.none : FilterQuality.high,
                      errorBuilder: (_, error, _) {
                        return Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text('Failed to render image: $error'),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Floating Zoom and Reset Controls
        Positioned(
          bottom: 24,
          right: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFloatingBtn(
                icon: Icons.add,
                tooltip: 'Zoom In (+)',
                onTap: _zoomIn,
              ),
              const SizedBox(height: 8),
              _buildFloatingBtn(
                icon: Icons.remove,
                tooltip: 'Zoom Out (-)',
                onTap: _zoomOut,
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
  }

  Widget _buildFloatingBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isDark ? Colors.white12 : Colors.black12,
          width: 0.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: isDark ? Colors.white : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildIcoSingleView() {
    final theme = Theme.of(context);
    final currentFrame = _icoFrames![_selectedFrameIndex];

    return Column(
      children: [
        // Top info strip
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          child: Row(
            children: [
              Icon(Icons.photo_size_select_actual_outlined,
                  size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                '${currentFrame.width} × ${currentFrame.height} px',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${(currentFrame.pngBytes.lengthInBytes / 1024).toStringAsFixed(1)} KB',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${_selectedFrameIndex + 1} of ${_icoFrames!.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        // Main image canvas with zoom & pan
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: _buildBackgroundContainer(
                  child: GestureDetector(
                    onDoubleTap: _handleDoubleTap,
                    child: InteractiveViewer(
                      transformationController: _transformationController,
                      minScale: 0.1,
                      maxScale: 30.0,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Image.memory(
                            currentFrame.pngBytes,
                            filterQuality: _pixelated
                                ? FilterQuality.none
                                : FilterQuality.medium,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Floating reset zoom button
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton.small(
                  heroTag: 'resetZoom',
                  tooltip: 'Reset Zoom (1:1)',
                  backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.85),
                  foregroundColor: theme.colorScheme.onSurface,
                  onPressed: _resetZoom,
                  child: const Icon(Icons.restart_alt_rounded, size: 20),
                ),
              ),
            ],
          ),
        ),

        // Bottom resolution selector strip (if more than 1 resolution)
        if (_icoFrames!.length > 1)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              border: Border(
                top: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: SizedBox(
              height: 52,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _icoFrames!.length,
                itemBuilder: (context, index) {
                  final frame = _icoFrames![index];
                  final isSelected = index == _selectedFrameIndex;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedFrameIndex = index;
                            _imageWidth = frame.width;
                            _imageHeight = frame.height;
                            _resetZoom();
                          });
                        }
                      },
                      avatar: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Image.memory(
                            frame.pngBytes,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.none,
                          ),
                        ),
                      ),
                      label: Text('${frame.width}×${frame.height}'),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildIcoGridView() {
    final theme = Theme.of(context);

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: _icoFrames!.length,
      itemBuilder: (context, index) {
        final frame = _icoFrames![index];
        final isSelected = index == _selectedFrameIndex;

        return Card(
          clipBehavior: Clip.antiAlias,
          elevation: isSelected ? 4 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected ? theme.colorScheme.primary : Colors.transparent,
              width: isSelected ? 2 : 0,
            ),
          ),
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedFrameIndex = index;
                _imageWidth = frame.width;
                _imageHeight = frame.height;
                _showGrid = false;
                _resetZoom();
              });
            },
            child: Column(
              children: [
                Expanded(
                  child: _buildBackgroundContainer(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Image.memory(
                          frame.pngBytes,
                          fit: BoxFit.contain,
                          filterQuality: _pixelated
                              ? FilterQuality.none
                              : FilterQuality.medium,
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  color: isSelected
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isSelected) ...[
                        Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        '${frame.width}×${frame.height}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackgroundContainer({required Widget child}) {
    if (_bgMode == 1) {
      // Dark
      return Container(color: Colors.black, child: child);
    } else if (_bgMode == 2) {
      // Light
      return Container(color: Colors.white, child: child);
    } else {
      // Checkerboard
      return CustomPaint(
        painter: _CheckerboardPainter.adaptive(context),
        child: child,
      );
    }
  }
}

class _CheckerboardPainter extends CustomPainter {
  final double checkSize;
  final Color color1;
  final Color color2;

  _CheckerboardPainter({
    required this.checkSize,
    required this.color1,
    required this.color2,
  });

  factory _CheckerboardPainter.adaptive(BuildContext context, {double checkSize = 14}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _CheckerboardPainter(
      checkSize: checkSize,
      color1: isDark ? const Color(0xFF23272E) : const Color(0xFFEEEEEE),
      color2: isDark ? const Color(0xFF1E2127) : const Color(0xFFFFFFFF),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()..color = color1;
    final paint2 = Paint()..color = color2;
    canvas.drawRect(Offset.zero & size, paint2);

    for (double y = 0; y < size.height; y += checkSize) {
      for (double x = 0; x < size.width; x += checkSize) {
        if (((x / checkSize).floor() + (y / checkSize).floor()) % 2 == 0) {
          canvas.drawRect(Rect.fromLTWH(x, y, checkSize, checkSize), paint1);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CheckerboardPainter oldDelegate) {
    return oldDelegate.color1 != color1 ||
        oldDelegate.color2 != color2 ||
        oldDelegate.checkSize != checkSize;
  }
}
