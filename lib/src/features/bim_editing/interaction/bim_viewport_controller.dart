import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'bim_viewport_navigation.dart';

/// Camera in logical pixels. Model geometry never changes during navigation.
class BimViewportController extends ChangeNotifier
    implements BimViewportNavigation {
  double _scale = 40;
  Offset _translation = const Offset(200, 300);
  Size _size = Size.zero;
  static const minScale = .5;
  static const maxScale = 20000.0;
  double get scale => _scale;
  Offset get translation => _translation;
  @override
  Size get size => _size;
  Offset toModel(Offset screen) => (screen - _translation) / _scale;
  Offset toScreen(Offset model) => model * _scale + _translation;
  Rect get visibleRect => Rect.fromPoints(
    toModel(Offset.zero),
    toModel(Offset(_size.width, _size.height)),
  );

  @override
  void resize(Size size) {
    if (size == _size || size.isEmpty) return;
    final center = toModel(_size.center(Offset.zero));
    final hadSize = !_size.isEmpty;
    _size = size;
    if (hadSize) _translation = size.center(Offset.zero) - center * _scale;
    notifyListeners();
  }

  @override
  void panBy(Offset pixels) {
    if (pixels == Offset.zero) return;
    _translation += pixels;
    notifyListeners();
  }

  /// Pinch and scroll retain the model point under the gesture focal point.
  @override
  void navigate({
    required Offset previousFocal,
    required Offset focal,
    double scaleFactor = 1,
  }) {
    if (!scaleFactor.isFinite || scaleFactor <= 0) return;
    final anchor = toModel(previousFocal);
    _scale = (_scale * scaleFactor).clamp(minScale, maxScale);
    _translation = focal - anchor * _scale;
    notifyListeners();
  }

  void fit(Rect bounds, {double padding = 48}) {
    if (_size.isEmpty || !bounds.isFinite) return;
    final width = math.max(bounds.width, 1.0);
    final height = math.max(bounds.height, 1.0);
    _scale = math
        .min(
          math.max(1, _size.width - 2 * padding) / width,
          math.max(1, _size.height - 2 * padding) / height,
        )
        .clamp(minScale, maxScale);
    _translation = _size.center(Offset.zero) - bounds.center * _scale;
    notifyListeners();
  }
}
