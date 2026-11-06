import '../../bim_editing/properties/bim_distance_unit.dart';

/// Elevations deliberately keep their sign and trailing zeroes, independently
/// of the units and precision used for linear dimensions.
String formatArchitectLevel(
  double metres, {
  BimDistanceUnit units = BimDistanceUnit.meters,
  int decimals = 2,
}) {
  final digits = decimals.clamp(0, 4);
  final value = units.toUnit(metres);
  final absolute = value.abs().toStringAsFixed(digits);
  final zero = double.parse(absolute) == 0;
  return '${zero
      ? '±'
      : value < 0
      ? '−'
      : '+'}$absolute';
}

enum ArchitectLevelSymbol { automatic, plan, elevation }
