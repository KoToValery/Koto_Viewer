import 'dart:ui';

import '../models/dxf_models.dart';
import 'dxf_math.dart';

typedef _BlockPathKey = (Path, double, double, double, double, double, double);

/// Compiled block paths after placement in the viewer's scene coordinates.
/// Stroke widths and the camera transform are applied by the caller.
class DxfViewportBlockPaths {
  static const _maxEstimatedBytes = 6 * 1024 * 1024;
  static const _maxPathBytes = 256 * 1024;
  final _paths = <_BlockPathKey, Path>{};
  int _estimatedBytes = 0;

  Path obtain(DxfCompiledSubpath source, DxfAffineMatrix placement) {
    final path = source.path;
    final estimatedBytes = 320 + source.pointCount * 16;
    if (source.pointCount < 8 || estimatedBytes > _maxPathBytes) {
      return path.transform(placement.toFloat64List());
    }

    final key = (
      path,
      placement.m00,
      placement.m01,
      placement.m02,
      placement.m10,
      placement.m11,
      placement.m12,
    );
    final cached = _paths[key];
    if (cached != null) return cached;

    final transformed = path.transform(placement.toFloat64List());
    // Keep the retained paths when a fit-to-screen pass exceeds the budget.
    // Evicting them in draw order would repeat the cost on the next zoom band.
    if (_estimatedBytes + estimatedBytes <= _maxEstimatedBytes) {
      _paths[key] = transformed;
      _estimatedBytes += estimatedBytes;
    }
    return transformed;
  }

  void clear() {
    _paths.clear();
    _estimatedBytes = 0;
  }
}
