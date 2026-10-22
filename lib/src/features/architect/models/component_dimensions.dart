/// Resizes dimensions in metres without accumulating rounding in the other axes.
Map<String, dynamic> resizeComponentDimensions(
  Map<String, dynamic> parameters,
  String axis,
  double value, {
  required bool lockRatio,
}) {
  const axes = ['width', 'depth', 'height'];
  if (!axes.contains(axis) || !value.isFinite || value < .001 || value > 100) {
    throw const FormatException('Invalid component dimension');
  }
  final result = Map<String, dynamic>.of(parameters);
  for (final key in axes) {
    result.putIfAbsent('_base_$key', () => parameters[key]);
  }
  final old = (parameters[axis] as num).toDouble();
  if (lockRatio) {
    if (!old.isFinite || old <= 0) {
      throw const FormatException('Invalid aspect ratio');
    }
    for (final key in axes) {
      final size = (parameters[key] as num).toDouble() * value / old;
      if (!size.isFinite || size < .001 || size > 100) {
        throw const FormatException('Invalid proportional dimension');
      }
      result[key] = size;
    }
  }
  result[axis] = value;
  return result;
}
