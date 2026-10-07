/// User-specified surface weights for the preliminary seismic mass model only.
/// The participation factor is an input assumption, not an inferred code value.
class SeismicSlabLoad {
  final double permanentKnM2;
  final double variableKnM2;
  final double participation;
  const SeismicSlabLoad({
    required this.permanentKnM2,
    required this.variableKnM2,
    required this.participation,
  });
  bool get isValid =>
      permanentKnM2.isFinite &&
      permanentKnM2 >= 0 &&
      variableKnM2.isFinite &&
      variableKnM2 >= 0 &&
      participation.isFinite &&
      participation >= 0 &&
      participation <= 1;
  double weightKnM2(double thickness) =>
      25 * thickness + permanentKnM2 + participation * variableKnM2;
  Map<String, dynamic> toJson() => {
    'permanentKnM2': permanentKnM2,
    'variableKnM2': variableKnM2,
    'participation': participation,
  };
  factory SeismicSlabLoad.fromJson(
    Map<String, dynamic> json,
  ) => SeismicSlabLoad(
    permanentKnM2: (json['permanentKnM2'] as num?)?.toDouble() ?? double.nan,
    variableKnM2: (json['variableKnM2'] as num?)?.toDouble() ?? double.nan,
    participation: (json['participation'] as num?)?.toDouble() ?? double.nan,
  );
}
