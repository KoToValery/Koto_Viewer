import 'dart:math' as math;
import 'dart:ui';

/// Coordinates in the persisted CAD frame, expressed as local model metres.
/// This adapter never rounds source geometry or changes its orientation.
class BimCoordinateFrame {
  final Offset origin;
  final double unitsPerMeter;

  const BimCoordinateFrame({this.origin = Offset.zero, this.unitsPerMeter = 1})
    : assert(unitsPerMeter > 0 && unitsPerMeter < double.infinity);

  Offset toModel(Offset cad) => (cad - origin) / unitsPerMeter;
  Offset toCad(Offset model) => origin + model * unitsPerMeter;
  Rect rectToModel(Rect rect) =>
      Rect.fromPoints(toModel(rect.topLeft), toModel(rect.bottomRight));
  Rect rectToCad(Rect rect) =>
      Rect.fromPoints(toCad(rect.topLeft), toCad(rect.bottomRight));

  @override
  bool operator ==(Object other) =>
      other is BimCoordinateFrame &&
      other.origin == origin &&
      other.unitsPerMeter == unitsPerMeter;
  @override
  int get hashCode => Object.hash(origin, unitsPerMeter);
}

/// Input increments are independent from solver precision and capture radii.
class BimPrecisionPolicy {
  static const metric = BimPrecisionPolicy(inputStepMeters: .001);
  static const imperial = BimPrecisionPolicy(inputStepMeters: .0254 / 16);
  static const numericalEpsilonMeters = 1e-9;
  final double inputStepMeters;

  const BimPrecisionPolicy({required this.inputStepMeters})
    : assert(inputStepMeters > 0 && inputStepMeters < double.infinity);

  double inputValue(double value) =>
      (value / inputStepMeters).round() * inputStepMeters;
  Offset inputPoint(Offset point) =>
      Offset(inputValue(point.dx), inputValue(point.dy));

  static double captureTolerance({
    required double pixelsPerUnit,
    double unitsPerMeter = 1,
    double pixels = 12,
    double maximumMeters = .20,
  }) => math.min(pixels / pixelsPerUnit, maximumMeters * unitsPerMeter);

  static double removeNumericalNoise(double metres) =>
      metres.isFinite ? (metres * 1e9).round() / 1e9 : metres;
}
