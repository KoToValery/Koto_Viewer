import 'package:flutter/material.dart';
import '../models/comic_models.dart';

/// Controller interface to programmatically control zoom on a [ComicPageItem].
class ComicPageController {
  final VoidCallback zoomIn;
  final VoidCallback zoomOut;
  final VoidCallback resetZoom;
  final ValueGetter<double> getScale;

  const ComicPageController({
    required this.zoomIn,
    required this.zoomOut,
    required this.resetZoom,
    required this.getScale,
  });
}

/// A specialized comic page item that provides:
/// 1. Smooth animated double-tap zoom to focal point (using cubic ease-out curve).
/// 2. Double-tap to reset when already zoomed.
/// 3. Scale guard that isolates horizontal scrolling during pan.
/// 4. 3-Zone tap navigation (Left 25%, Center 50%, Right 25%) when unzoomed.
/// 5. Single tap safety guard (ignores edge page turns when zoomed).
/// 6. Programmatic zoom controls via [ComicPageController].
class ComicPageItem extends StatefulWidget {
  final ComicPage page;
  final ComicFitMode fitMode;
  final ValueChanged<double>? onZoomChanged;
  final VoidCallback? onLeftTap;
  final VoidCallback? onCenterTap;
  final VoidCallback? onRightTap;
  final ValueChanged<ComicPageController>? onControllerCreated;
  final VoidCallback? onControllerDisposed;
  final double doubleTapZoomScale;

  const ComicPageItem({
    super.key,
    required this.page,
    this.fitMode = ComicFitMode.fitWidth,
    this.onZoomChanged,
    this.onLeftTap,
    this.onCenterTap,
    this.onRightTap,
    this.onControllerCreated,
    this.onControllerDisposed,
    this.doubleTapZoomScale = 2.5,
  });

  @override
  State<ComicPageItem> createState() => _ComicPageItemState();
}

class _ComicPageItemState extends State<ComicPageItem> with SingleTickerProviderStateMixin {
  late final TransformationController _transformController;
  late final AnimationController _animController;
  Animation<Matrix4>? _matrixAnimation;

  TapDownDetails? _doubleTapDetails;
  bool _panEnabled = false;
  double _currentScale = 1.0;

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController();
    _transformController.addListener(_onTransformChanged);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _animController.addListener(_onAnimationTick);

    widget.onControllerCreated?.call(
      ComicPageController(
        zoomIn: zoomIn,
        zoomOut: zoomOut,
        resetZoom: resetZoom,
        getScale: () => _currentScale,
      ),
    );
  }

  @override
  void dispose() {
    widget.onControllerDisposed?.call();
    _animController.removeListener(_onAnimationTick);
    _animController.dispose();
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    super.dispose();
  }

  void _onAnimationTick() {
    if (_matrixAnimation != null) {
      _transformController.value = _matrixAnimation!.value;
    }
  }

  void _onTransformChanged() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    _currentScale = scale;
    final shouldEnablePan = scale > 1.05;
    if (shouldEnablePan != _panEnabled) {
      setState(() {
        _panEnabled = shouldEnablePan;
      });
    }
    widget.onZoomChanged?.call(scale);
  }

  void _animateToMatrix(Matrix4 targetMatrix) {
    _matrixAnimation = Matrix4Tween(
      begin: _transformController.value,
      end: targetMatrix,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ),
    );
    _animController.forward(from: 0.0);
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    if (_animController.isAnimating) return;

    if (_currentScale > 1.05) {
      // Zoom out smoothly to 1.0x
      _animateToMatrix(Matrix4.identity());
    } else {
      // Zoom in to focal point
      final targetScale = widget.doubleTapZoomScale;
      final size = context.size ?? Size.zero;
      final pos = _doubleTapDetails?.localPosition ?? Offset(size.width / 2, size.height / 2);

      final rawDx = pos.dx * (1 - targetScale);
      final rawDy = pos.dy * (1 - targetScale);

      final minDx = size.width * (1 - targetScale);
      final minDy = size.height * (1 - targetScale);

      final clampedDx = rawDx.clamp(minDx, 0.0);
      final clampedDy = rawDy.clamp(minDy, 0.0);

      final targetMatrix = Matrix4.identity();
      targetMatrix.setEntry(0, 0, targetScale);
      targetMatrix.setEntry(1, 1, targetScale);
      targetMatrix.setEntry(0, 3, clampedDx);
      targetMatrix.setEntry(1, 3, clampedDy);

      _animateToMatrix(targetMatrix);
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (_animController.isAnimating) return;

    final size = context.size;
    if (size == null || size.width == 0) return;

    // When zoomed in, tapping on edge should NOT flip pages.
    // Tapping anywhere simply toggles controls.
    if (_currentScale > 1.05) {
      widget.onCenterTap?.call();
      return;
    }

    // 3-Zone Tap Navigation (Unzoomed):
    // Left: 0% - 25%
    // Center: 25% - 75%
    // Right: 75% - 100%
    final xRatio = details.localPosition.dx / size.width;
    if (xRatio < 0.25) {
      widget.onLeftTap?.call();
    } else if (xRatio > 0.75) {
      widget.onRightTap?.call();
    } else {
      widget.onCenterTap?.call();
    }
  }

  void zoomIn() {
    if (_animController.isAnimating) return;
    final newScale = (_currentScale + 0.5).clamp(1.0, 4.0);
    _zoomToScaleCentered(newScale);
  }

  void zoomOut() {
    if (_animController.isAnimating) return;
    final newScale = (_currentScale - 0.5).clamp(1.0, 4.0);
    if (newScale <= 1.05) {
      resetZoom();
    } else {
      _zoomToScaleCentered(newScale);
    }
  }

  void resetZoom() {
    if (_transformController.value != Matrix4.identity()) {
      if (mounted && _animController.isAnimating) {
        _animController.stop();
      }
      if (mounted) {
        _animateToMatrix(Matrix4.identity());
      } else {
        _transformController.value = Matrix4.identity();
      }
    }
  }

  void _zoomToScaleCentered(double targetScale) {
    if (targetScale <= 1.05) {
      _animateToMatrix(Matrix4.identity());
      return;
    }
    final size = context.size ?? Size.zero;
    final center = Offset(size.width / 2, size.height / 2);
    final rawDx = center.dx * (1 - targetScale);
    final rawDy = center.dy * (1 - targetScale);
    final minDx = size.width * (1 - targetScale);
    final minDy = size.height * (1 - targetScale);

    final targetMatrix = Matrix4.identity();
    targetMatrix.setEntry(0, 0, targetScale);
    targetMatrix.setEntry(1, 1, targetScale);
    targetMatrix.setEntry(0, 3, rawDx.clamp(minDx, 0.0));
    targetMatrix.setEntry(1, 3, rawDy.clamp(minDy, 0.0));

    _animateToMatrix(targetMatrix);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTapDown: _handleDoubleTapDown,
      onDoubleTap: _handleDoubleTap,
      onTapUp: _handleTapUp,
      child: InteractiveViewer(
        transformationController: _transformController,
        panEnabled: _panEnabled,
        scaleEnabled: true,
        minScale: 1.0,
        maxScale: 4.0,
        boundaryMargin: const EdgeInsets.all(40.0),
        child: Center(
          child: Image.memory(
            widget.page.bytes,
            fit: widget.fitMode.boxFit,
            errorBuilder: (ctx, err, stack) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text(
                    'Error loading page ${widget.page.pageIndex + 1}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
