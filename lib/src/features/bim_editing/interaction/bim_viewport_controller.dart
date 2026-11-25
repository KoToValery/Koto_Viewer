import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'bim_viewport_navigation.dart';

/// Camera in logical pixels. Model geometry never changes during navigation.
class BimViewportController extends ChangeNotifier
    implements BimViewportNavigation {
  double _scale = 40;
  Offset _translation = const Offset(200, 300);
  double _rotation = 0;
  Size _size = Size.zero;
  static const minScale = .5;
  static const maxScale = 20000.0;
  double get scale => _scale;
  Offset get translation => _translation;
  /// Clockwise view rotation in radians (0 = orthogonal Project North).
  double get rotation => _rotation;
  @override
  Size get size => _size;

  static Offset _rotate(Offset p, double radians) {
    if (radians == 0) return p;
    final c = math.cos(radians);
    final s = math.sin(radians);
    return Offset(p.dx * c - p.dy * s, p.dx * s + p.dy * c);
  }

  /// Applies this camera's translation, rotation and scale to [canvas].
  void applyToCanvas(Canvas canvas) {
    canvas.translate(_translation.dx, _translation.dy);
    if (_rotation != 0) canvas.rotate(_rotation);
    canvas.scale(_scale);
  }

  Offset toModel(Offset screen) =>
      _rotate(screen - _translation, -_rotation) / _scale;

  Offset toScreen(Offset model) =>
      _rotate(model * _scale, _rotation) + _translation;

  Rect get visibleRect {
    final c0 = toModel(Offset.zero);
    final c1 = toModel(Offset(_size.width, 0));
    final c2 = toModel(Offset(_size.width, _size.height));
    final c3 = toModel(Offset(0, _size.height));
    final minX = math.min(math.min(c0.dx, c1.dx), math.min(c2.dx, c3.dx));
    final maxX = math.max(math.max(c0.dx, c1.dx), math.max(c2.dx, c3.dx));
    final minY = math.min(math.min(c0.dy, c1.dy), math.min(c2.dy, c3.dy));
    final maxY = math.max(math.max(c0.dy, c1.dy), math.max(c2.dy, c3.dy));
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Updates the camera rotation while keeping the model point under
  /// [screenAnchor] (defaults to viewport center) stationary on screen.
  void setRotation(double radians, {Offset? screenAnchor}) {
    final next = radians.isFinite ? radians : 0.0;
    if ((next - _rotation).abs() < 1e-10) return;
    final anchorScreen = screenAnchor ?? _size.center(Offset.zero);
    final anchorModel = toModel(anchorScreen);
    _rotation = next;
    _translation = anchorScreen - _rotate(anchorModel * _scale, _rotation);
    notifyListeners();
  }

  @override
  void resize(Size size) {
    if (size == _size || size.isEmpty) return;
    final center = toModel(_size.center(Offset.zero));
    final hadSize = !_size.isEmpty;
    _size = size;
    if (hadSize) {
      _translation =
          size.center(Offset.zero) - _rotate(center * _scale, _rotation);
    }
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
    _translation = focal - _rotate(anchor * _scale, _rotation);
    notifyListeners();
  }

  void fit(Rect bounds, {double padding = 48}) {
    if (_size.isEmpty || !bounds.isFinite) return;
    final corners = [
      _rotate(bounds.topLeft, _rotation),
      _rotate(bounds.topRight, _rotation),
      _rotate(bounds.bottomRight, _rotation),
      _rotate(bounds.bottomLeft, _rotation),
    ];
    final minX = corners.map((p) => p.dx).reduce(math.min);
    final maxX = corners.map((p) => p.dx).reduce(math.max);
    final minY = corners.map((p) => p.dy).reduce(math.min);
    final maxY = corners.map((p) => p.dy).reduce(math.max);
    final width = math.max(maxX - minX, 1.0);
    final height = math.max(maxY - minY, 1.0);
    _scale = math
        .min(
          math.max(1, _size.width - 2 * padding) / width,
          math.max(1, _size.height - 2 * padding) / height,
        )
        .clamp(minScale, maxScale);
    final rotatedCenter = Offset((minX + maxX) / 2, (minY + maxY) / 2);
    _translation = _size.center(Offset.zero) - rotatedCenter * _scale;
    notifyListeners();
  }
}
