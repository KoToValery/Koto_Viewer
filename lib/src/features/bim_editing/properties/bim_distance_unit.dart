/// Supported distance units for architectural project dimensions.
enum BimDistanceUnit {
  meters(1.0, 'm'),
  centimeters(0.01, 'cm'),
  millimeters(0.001, 'mm'),
  feet(0.3048, 'ft'),
  inches(0.0254, 'in');

  final double scaleToMeters;
  final String symbol;
  const BimDistanceUnit(this.scaleToMeters, this.symbol);

  bool get isImperial =>
      this == BimDistanceUnit.feet || this == BimDistanceUnit.inches;
  bool get isMetric => !isImperial;

  double toUnit(double meters) => meters / scaleToMeters;
  double fromUnit(double valueInUnit) => valueInUnit * scaleToMeters;

  String format(double meters, {int decimals = 2}) {
    final val = toUnit(meters);
    if (this == BimDistanceUnit.inches || this == BimDistanceUnit.feet) {
      final total = (meters.abs() / .0254 * 16).round();
      final sign = meters < 0 && total != 0 ? '-' : '';
      final feet = this == BimDistanceUnit.feet ? total ~/ 192 : 0;
      final remainder = this == BimDistanceUnit.feet ? total % 192 : total;
      final whole = remainder ~/ 16;
      var numerator = remainder % 16;
      var denominator = 16;
      while (numerator > 0 && numerator.isEven) {
        numerator ~/= 2;
        denominator ~/= 2;
      }
      final fraction = numerator == 0 ? '' : ' $numerator/$denominator';
      return this == BimDistanceUnit.feet
          ? '$sign$feet′ $whole$fraction″'
          : '$sign$whole$fraction in';
    } else if (this == BimDistanceUnit.millimeters) {
      return '${val.toStringAsFixed(0)} $symbol';
    } else if (this == BimDistanceUnit.centimeters) {
      return '${val.toStringAsFixed(0)} $symbol';
    } else {
      return '${val.toStringAsFixed(decimals)} $symbol';
    }
  }
}
