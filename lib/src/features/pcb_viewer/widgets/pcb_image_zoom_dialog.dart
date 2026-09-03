import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/pcb_models.dart';

/// Full-screen interactive zoom and pan viewer for images in a PCB archive.
class PcbImageZoomDialog extends StatefulWidget {
  final List<PcbImageItem> images;
  final int initialIndex;

  const PcbImageZoomDialog({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  /// Helper to show this viewer dialog with a slide/fade transition.
  static Future<void> show(
    BuildContext context, {
    required List<PcbImageItem> images,
    int initialIndex = 0,
  }) {
    return showDialog(
      context: context,
      useSafeArea: false,
      barrierColor: Colors.black87,
      builder: (context) => PcbImageZoomDialog(
        images: images,
        initialIndex: initialIndex,
      ),
    );
  }

  @override
  State<PcbImageZoomDialog> createState() => _PcbImageZoomDialogState();
}

class _PcbImageZoomDialogState extends State<PcbImageZoomDialog> {
  late int _currentIndex;
  final TransformationController _transformController = TransformationController();
  final FocusNode _focusNode = FocusNode();
  Size _viewportSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.images.length - 1);
  }

  @override
  void dispose() {
    _transformController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
  }

  void _zoomIn() {
    _zoomBy(1.3);
  }

  void _zoomOut() {
    _zoomBy(1.0 / 1.3);
  }

  void _zoomBy(double factor, {Offset? focalPoint}) {
    if (_viewportSize.isEmpty) return;

    final targetPoint = focalPoint ?? Offset(_viewportSize.width / 2, _viewportSize.height / 2);
    final currentMatrix = _transformController.value;

    final translation = currentMatrix.getTranslation();
    final scale = currentMatrix.getMaxScaleOnAxis();
    final newScale = (scale * factor).clamp(0.2, 30.0);

    final dx = targetPoint.dx - (targetPoint.dx - translation.x) * (newScale / scale);
    final dy = targetPoint.dy - (targetPoint.dy - translation.y) * (newScale / scale);

    final newMatrix = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(newScale);

    _transformController.value = newMatrix;
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final double zoomFactor = event.scrollDelta.dy < 0 ? 1.2 : 0.833;
      _zoomBy(zoomFactor, focalPoint: event.localPosition);
    }
  }

  void _handleDoubleTap(TapDownDetails details) {
    final currentScale = _transformController.value.getMaxScaleOnAxis();
    if (currentScale > 1.2) {
      _resetZoom();
    } else {
      _zoomBy(2.5, focalPoint: details.localPosition);
    }
  }

  void _nextImage() {
    if (_currentIndex < widget.images.length - 1) {
      setState(() {
        _currentIndex++;
        _resetZoom();
      });
    }
  }

  void _previousImage() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _resetZoom();
      });
    }
  }

  void _onKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _nextImage();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _previousImage();
      } else if (event.logicalKey == LogicalKeyboardKey.equal || event.logicalKey == LogicalKeyboardKey.numpadAdd) {
        _zoomIn();
      } else if (event.logicalKey == LogicalKeyboardKey.minus || event.logicalKey == LogicalKeyboardKey.numpadSubtract) {
        _zoomOut();
      } else if (event.logicalKey == LogicalKeyboardKey.digit0 || event.logicalKey == LogicalKeyboardKey.numpad0) {
        _resetZoom();
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentImg = widget.images[_currentIndex];
    final sizeKb = (currentImg.bytes.length / 1024).toStringAsFixed(1);

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(
          builder: (context, constraints) {
            _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

            return Stack(
              children: [
                // Interactive Image View with Zoom & Pan
                Positioned.fill(
                  child: Listener(
                    onPointerSignal: _handlePointerSignal,
                    child: GestureDetector(
                      onDoubleTapDown: _handleDoubleTap,
                      child: InteractiveViewer(
                        transformationController: _transformController,
                        minScale: 0.2,
                        maxScale: 30.0,
                        boundaryMargin: const EdgeInsets.all(1500),
                        child: Center(
                          child: Image.memory(
                            currentImg.bytes,
                            fit: BoxFit.contain,
                            errorBuilder: (ctx, err, stack) => const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.broken_image, size: 64, color: Colors.white38),
                                SizedBox(height: 12),
                                Text(
                                  'Could not load image',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Top Bar with File Name, Dimensions, and Actions
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black87, Colors.transparent],
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            tooltip: 'Close (Esc)',
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  currentImg.fileName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '$sizeKb KB • ${_currentIndex + 1} of ${widget.images.length}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.restart_alt, color: Colors.white),
                            tooltip: 'Reset Zoom (100%)',
                            onPressed: _resetZoom,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Floating Next & Previous Navigation Arrows (if multiple images)
                if (widget.images.length > 1) ...[
                  if (_currentIndex > 0)
                    Positioned(
                      left: 16,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          radius: 24,
                          child: IconButton(
                            icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                            tooltip: 'Previous Image (Left Arrow)',
                            onPressed: _previousImage,
                          ),
                        ),
                      ),
                    ),
                  if (_currentIndex < widget.images.length - 1)
                    Positioned(
                      right: 16,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          radius: 24,
                          child: IconButton(
                            icon: const Icon(Icons.chevron_right, color: Colors.white, size: 28),
                            tooltip: 'Next Image (Right Arrow)',
                            onPressed: _nextImage,
                          ),
                        ),
                      ),
                    ),
                ],

                // Floating Zoom Controls (Bottom Right)
                Positioned(
                  bottom: widget.images.length > 1 ? 100 : 24,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black87.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24, width: 0.8),
                      boxShadow: const [
                        BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 3)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.white, size: 22),
                          tooltip: 'Zoom In (+)',
                          onPressed: _zoomIn,
                        ),
                        const Divider(height: 1, color: Colors.white24),
                        IconButton(
                          icon: const Icon(Icons.remove, color: Colors.white, size: 22),
                          tooltip: 'Zoom Out (-)',
                          onPressed: _zoomOut,
                        ),
                        const Divider(height: 1, color: Colors.white24),
                        IconButton(
                          icon: const Icon(Icons.fit_screen_outlined, color: Colors.white, size: 22),
                          tooltip: 'Fit to View',
                          onPressed: _resetZoom,
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Thumbnail Strip (if multiple images)
                if (widget.images.length > 1)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      child: Container(
                        height: 84,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black87, Colors.transparent],
                          ),
                        ),
                        child: Center(
                          child: ListView.separated(
                            shrinkWrap: true,
                            scrollDirection: Axis.horizontal,
                            itemCount: widget.images.length,
                            separatorBuilder: (context, index) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final img = widget.images[index];
                              final isSelected = index == _currentIndex;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _currentIndex = index;
                                    _resetZoom();
                                  });
                                },
                                child: Container(
                                  width: 68,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFF10B981) : Colors.white24,
                                      width: isSelected ? 2.5 : 1.0,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Image.memory(
                                    img.bytes,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
