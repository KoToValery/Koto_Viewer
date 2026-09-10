import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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

  List<_IcoFrame>? _icoFrames;
  Uint8List? _psdBytes;
  bool _isIco = false;
  bool _isPsd = false;

  int _selectedFrameIndex = 0;
  bool _showGrid = false;
  bool _pixelated = false;
  int _bgMode = 0; // 0 = checkerboard, 1 = dark, 2 = light

  final TransformationController _transformationController =
      TransformationController();

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
    final lower = widget.filePath.toLowerCase();
    _isIco = lower.endsWith('.ico');
    _isPsd = lower.endsWith('.psd') || lower.endsWith('.psb');

    try {
      if (_isIco) {
        final frames = await compute(_decodeIcoCompute, widget.filePath);
        if (mounted) {
          setState(() {
            _icoFrames = frames;
            _isLoading = false;
            _selectedFrameIndex = 0;
            if (frames.isEmpty) {
              _error = "Could not decode ICO frames.";
            }
          });
        }
      } else if (_isPsd) {
        final bytes = await compute(_decodePsdCompute, widget.filePath);
        if (mounted) {
          setState(() {
            _psdBytes = bytes;
            _isLoading = false;
            if (bytes == null) {
              _error = "Could not decode PSD file.";
            }
          });
        }
      } else {
        setState(() {
          _error = "Unsupported format.";
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
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

  Future<void> _shareCurrentFrame() async {
    if (_icoFrames == null || _icoFrames!.isEmpty) {
      await Share.shareXFiles([XFile(widget.filePath)]);
      return;
    }

    final frame = _icoFrames![_selectedFrameIndex];
    try {
      final tempDir = await getTemporaryDirectory();
      final baseName = widget.filePath.contains('/')
          ? widget.filePath.split('/').where((s) => s.isNotEmpty).last
          : widget.filePath.split(Platform.pathSeparator).last;
      final nameWithoutExt = baseName.replaceAll(RegExp(r'\.ico$', caseSensitive: false), '');
      final framePath = '${tempDir.path}/${nameWithoutExt}_${frame.width}x${frame.height}.png';
      final file = File(framePath);
      await file.writeAsBytes(frame.pngBytes);
      await Share.shareXFiles(
        [XFile(framePath, mimeType: 'image/png', name: '${nameWithoutExt}_${frame.width}x${frame.height}.png')],
        text: '$baseName (${frame.width}x${frame.height})',
      );
    } catch (_) {
      await Share.shareXFiles([XFile(widget.filePath)]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.filePath.contains('/')
        ? widget.filePath.split('/').where((s) => s.isNotEmpty).last
        : widget.filePath.split(Platform.pathSeparator).last;

    return Scaffold(
      appBar: AppBar(
        title: Text(fileName),
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
            // Pixelated / Sharp toggle for small icons
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
            // Share menu / button
            PopupMenuButton<String>(
              icon: const Icon(Icons.share_rounded, size: 20),
              tooltip: 'Share',
              onSelected: (val) {
                if (val == 'frame') {
                  _shareCurrentFrame();
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
                      Text('Share current size (${_icoFrames![_selectedFrameIndex].width}×${_icoFrames![_selectedFrameIndex].height} PNG)'),
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
              ],
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {
                Share.shareXFiles([XFile(widget.filePath)]);
              },
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
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image_rounded, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      final fileName = widget.filePath.contains('/')
          ? widget.filePath.split('/').where((s) => s.isNotEmpty).last
          : widget.filePath.split(Platform.pathSeparator).last;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Decoding $fileName...'),
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
            padding: const EdgeInsets.all(8.0),
            child: const Text(
              'Flattened composite preview — layers are not shown.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            child: Center(
              child: InteractiveViewer(
                minScale: 0.2,
                maxScale: 10.0,
                child: Image.memory(_psdBytes!),
              ),
            ),
          ),
        ],
      );
    }

    if (_isIco && _icoFrames != null && _icoFrames!.isNotEmpty) {
      return _showGrid ? _buildIcoGridView() : _buildIcoSingleView();
    }

    return const SizedBox();
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
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
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
              // Floating reset zoom button
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton.small(
                  heroTag: 'resetZoom',
                  tooltip: 'Reset Zoom (1:1)',
                  backgroundColor: theme.colorScheme.surface.withOpacity(0.85),
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
                  color: theme.dividerColor.withOpacity(0.2),
                ),
              ),
            ),
            child: SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _icoFrames!.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final f = _icoFrames![i];
                  final isSelected = i == _selectedFrameIndex;
                  return ChoiceChip(
                    avatar: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Image.memory(f.pngBytes, fit: BoxFit.contain),
                    ),
                    label: Text('${f.width}×${f.height}'),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _selectedFrameIndex = i;
                        _resetZoom();
                      });
                    },
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
        maxCrossAxisExtent: 160,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
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
