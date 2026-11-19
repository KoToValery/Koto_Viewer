import 'dart:math' as math;
import 'dart:ui';

/// Coordinates in the persisted CAD frame, expressed as local model metres.
/// Optionally maps CAD's Y-up axis to a Y-down drawing plane.
class BimCoordinateFrame {
  final Offset origin;
  final double unitsPerMeter;
  final bool invertY;

  const BimCoordinateFrame({
    this.origin = Offset.zero,
    this.unitsPerMeter = 1,
    this.invertY = false,
  }) : assert(unitsPerMeter > 0 && unitsPerMeter < double.infinity);

  Offset _orient(Offset point) => invertY ? Offset(point.dx, -point.dy) : point;
  Offset toModel(Offset cad) => _orient(cad - origin) / unitsPerMeter;
  Offset toCad(Offset model) => origin + _orient(model) * unitsPerMeter;

  BimCoordinateFrame placing(Offset cad, Offset model) => BimCoordinateFrame(
    origin: cad - _orient(model) * unitsPerMeter,
    unitsPerMeter: unitsPerMeter,
    invertY: invertY,
  );
  Rect rectToModel(Rect rect) =>
      Rect.fromPoints(toModel(rect.topLeft), toModel(rect.bottomRight));
  Rect rectToCad(Rect rect) =>
      Rect.fromPoints(toCad(rect.topLeft), toCad(rect.bottomRight));

  @override
  bool operator ==(Object other) =>
      other is BimCoordinateFrame &&
      other.origin == origin &&
      other.unitsPerMeter == unitsPerMeter &&
      other.invertY == invertY;
  @override
  int get hashCode => Object.hash(origin, unitsPerMeter, invertY);
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
