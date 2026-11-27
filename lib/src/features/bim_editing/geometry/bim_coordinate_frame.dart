import 'dart:math' as math;
import 'dart:ui';

import 'bim_transform_2d.dart';

/// Coordinates in the persisted CAD frame, expressed as local model metres.
/// Optionally maps CAD's Y-up axis to a Y-down drawing plane and rotates it.
class BimCoordinateFrame {
  final Offset origin;
  final double unitsPerMeter;
  final bool invertY;
  final double rotationRadians;

  const BimCoordinateFrame({
    this.origin = Offset.zero,
    this.unitsPerMeter = 1,
    this.invertY = false,
    this.rotationRadians = 0,
  }) : assert(unitsPerMeter > 0 && unitsPerMeter < double.infinity);

  Offset _orient(Offset point) => invertY ? Offset(point.dx, -point.dy) : point;
  Offset toUnrotatedModel(Offset cad) => _orient(cad - origin) / unitsPerMeter;
  Offset toModel(Offset cad) =>
      BimTransform2D.rotate(toUnrotatedModel(cad), Offset.zero, rotationRadians);
  Offset _cadDelta(Offset model) =>
      _orient(BimTransform2D.rotate(model, Offset.zero, -rotationRadians)) *
      unitsPerMeter;
  Offset toCadDelta(Offset model) => _cadDelta(model);
  Offset toCad(Offset model) => origin + _cadDelta(model);

  BimCoordinateFrame placing(Offset cad, Offset model) => BimCoordinateFrame(
    origin: cad - _cadDelta(model),
    unitsPerMeter: unitsPerMeter,
    invertY: invertY,
    rotationRadians: rotationRadians,
  );

  BimCoordinateFrame rotatingAround(Offset pivot, double radians) =>
      BimCoordinateFrame(
        unitsPerMeter: unitsPerMeter,
        invertY: invertY,
        rotationRadians: BimTransform2D.angle(rotationRadians, radians),
      ).placing(toCad(pivot), pivot);

  List<Offset> cornersToModel(Rect rect) => [
    toModel(rect.topLeft),
    toModel(rect.topRight),
    toModel(rect.bottomRight),
    toModel(rect.bottomLeft),
  ];

  Rect rectToModel(Rect rect) => _rectBounds(rect, toModel);
  Rect rectToCad(Rect rect) => _rectBounds(rect, toCad);

  Rect _rectBounds(Rect rect, Offset Function(Offset) map) {
    final diagonal = Rect.fromPoints(map(rect.topLeft), map(rect.bottomRight));
    if (rotationRadians == 0) return diagonal;
    return diagonal.expandToInclude(
      Rect.fromPoints(map(rect.topRight), map(rect.bottomLeft)),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BimCoordinateFrame &&
      other.origin == origin &&
      other.unitsPerMeter == unitsPerMeter &&
      other.invertY == invertY &&
      other.rotationRadians == rotationRadians;
  @override
  int get hashCode => Object.hash(origin, unitsPerMeter, invertY, rotationRadians);
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
