/// A property field declares its model bounds and display-unit conversion.
/// Native catalogs provide the localized label and the field setter.
class BimNumericRule {
  const BimNumericRule({
    this.minimum = -double.infinity,
    this.maximum = double.infinity,
    this.integer = false,
    this.unitToModel = 1,
  });
  final double minimum, maximum, unitToModel;
  final bool integer;
  bool accepts(double value) =>
      value.isFinite &&
      value >= minimum &&
      value <= maximum &&
      (!integer || value == value.roundToDouble());
  double? parse(String input) {
    final value = double.tryParse(input.trim().replaceAll(',', '.'));
    if (value == null || !unitToModel.isFinite || unitToModel <= 0) return null;
    final model = value * unitToModel;
    return accepts(model) ? model : null;
  }
}
