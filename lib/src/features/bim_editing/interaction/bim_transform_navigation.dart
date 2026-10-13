import 'package:flutter/widgets.dart';
import 'bim_viewport_navigation.dart';

/// Navigation for hosts whose painter uses a fitted scene and a matrix.
/// CAD axis orientation and unit conversion remain in the native adapter.
class BimTransformNavigation implements BimViewportNavigation {
  BimTransformNavigation({
    required this.controller,
    required this.readSize,
    required this.onResize,
    this.minScale = .001,
    this.maxScale = 1000,
  });
  final TransformationController controller;
  final Size Function() readSize;
  final ValueChanged<Size> onResize;
  final double minScale, maxScale;
  @override
  Size get size => readSize();
  @override
  void resize(Size size) => onResize(size);
  @override
  void panBy(Offset pixels) =>
      navigate(previousFocal: Offset.zero, focal: pixels);
  @override
  void navigate({
    required Offset previousFocal,
    required Offset focal,
    double scaleFactor = 1,
  }) {
    if (!scaleFactor.isFinite || scaleFactor <= 0) return;
    final original = controller.value;
    final scale = original.getMaxScaleOnAxis();
    if (!scale.isFinite || scale <= 0) return;
    final targetScale = (scale * scaleFactor).clamp(minScale, maxScale);
    final anchor = controller.toScene(previousFocal);
    final next = original.clone();
    next.scaleByDouble(targetScale / scale, targetScale / scale, 1, 1);
    final projected = MatrixUtils.transformPoint(next, anchor);
    next.setTranslationRaw(
      next.storage[12] + focal.dx - projected.dx,
      next.storage[13] + focal.dy - projected.dy,
      next.storage[14],
    );
    controller.value = next;
  }
}
