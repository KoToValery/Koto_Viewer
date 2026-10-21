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

  static String trimZeros(String s) {
    if (!s.contains('.')) return s;
    final trimmed = s.replaceAll(RegExp(r'\.?0+$'), '');
    return trimmed.isEmpty || trimmed == '-0' ? '0' : trimmed;
  }

  String format(double meters, {int? decimals}) {
    final val = toUnit(meters);
    if (isImperial && decimals == null) {
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
      final s = val.toStringAsFixed(decimals ?? 0);
      return '${decimals == null ? trimZeros(s) : s} $symbol';
    } else if (this == BimDistanceUnit.centimeters) {
      final s = val.toStringAsFixed(decimals ?? 0);
      return '${decimals == null ? trimZeros(s) : s} $symbol';
    } else {
      final s = val.toStringAsFixed(decimals ?? 2);
      return '${decimals == null ? trimZeros(s) : s} $symbol';
    }
  }

  String formatArea(double squareMeters, {int decimals = 2}) {
    if (isImperial) {
      final sqFt = squareMeters / (0.3048 * 0.3048);
      return '${trimZeros(sqFt.toStringAsFixed(decimals))} sq ft';
    }
    return '${trimZeros(squareMeters.toStringAsFixed(decimals))} m²';
  }
}
