/// Dimensions of an insulated panel roof and its independent steel frame.
/// Metres and degrees; defaults describe geometry, not a load-rated product.
class ArchitectRoofPanelSpec {
  final bool membrane;
  final double thickness, skin, module, ribHeight, minimumSlope;
  final double purlinDepth, purlinWidth, purlinMetal, purlinSpacing;
  final double beamDepth, beamWidth, beamWeb, beamFlange, frameSpacing;
  final double cutback, flashing, upstand;
  final List<String> columnIds;
  const ArchitectRoofPanelSpec({
    this.membrane = false,
    this.thickness = .1,
    this.skin = .0005,
    this.module = 1,
    this.ribHeight = .035,
    this.minimumSlope = 4,
    this.purlinDepth = .2,
    this.purlinWidth = .07,
    this.purlinMetal = .0025,
    this.purlinSpacing = 1.5,
    this.beamDepth = .3,
    this.beamWidth = .15,
    this.beamWeb = .006,
    this.beamFlange = .01,
    this.frameSpacing = 3,
    this.cutback = .05,
    this.flashing = .0015,
    this.upstand = .25,
    this.columnIds = const [],
  });
  double get structureDepth => beamDepth + purlinDepth;
  double get profileHeight => membrane ? 0 : ribHeight;
  double get membraneThickness => membrane ? .0015 : 0;
  double get totalDepth =>
      structureDepth + thickness + profileHeight + membraneThickness;
  void validate({double? slope, bool mansard = false}) {
    final values = [
      thickness,
      skin,
      module,
      ribHeight,
      minimumSlope,
      purlinDepth,
      purlinWidth,
      purlinMetal,
      purlinSpacing,
      beamDepth,
      beamWidth,
      beamWeb,
      beamFlange,
      frameSpacing,
      cutback,
      flashing,
      upstand,
    ];
    if (values.any((v) => !v.isFinite) ||
        thickness < .02 ||
        skin < .0002 ||
        skin >= thickness / 4 ||
        module < .2 ||
        ribHeight < 0 ||
        ribHeight > module / 4 ||
        minimumSlope < .1 ||
        minimumSlope > 45 ||
        purlinDepth < .05 ||
        purlinWidth < .025 ||
        purlinMetal <= 0 ||
        purlinMetal >= purlinWidth / 4 ||
        purlinSpacing < .2 ||
        beamDepth < .1 ||
        beamWidth < .05 ||
        beamWeb <= 0 ||
        beamWeb >= beamWidth / 3 ||
        beamFlange <= 0 ||
        beamFlange >= beamDepth / 4 ||
        frameSpacing < .5 ||
        cutback < 0 ||
        cutback > .3 ||
        flashing <= 0 ||
        flashing > .01 ||
        upstand < .1 ||
        upstand > 1 ||
        columnIds.toSet().length != columnIds.length ||
        mansard ||
        (slope != null &&
            (!slope.isFinite || slope < minimumSlope || slope > 70))) {
      throw ArgumentError('Invalid panel roof geometry or slope');
    }
  }

  ArchitectRoofPanelSpec copyWith({
    bool? membrane,
    double? thickness,
    double? skin,
    double? module,
    double? ribHeight,
    double? minimumSlope,
    double? purlinDepth,
    double? purlinWidth,
    double? purlinMetal,
    double? purlinSpacing,
    double? beamDepth,
    double? beamWidth,
    double? beamWeb,
    double? beamFlange,
    double? frameSpacing,
    double? cutback,
    double? flashing,
    double? upstand,
    List<String>? columnIds,
  }) => ArchitectRoofPanelSpec(
    membrane: membrane ?? this.membrane,
    thickness: thickness ?? this.thickness,
    skin: skin ?? this.skin,
    module: module ?? this.module,
    ribHeight: ribHeight ?? this.ribHeight,
    minimumSlope: minimumSlope ?? this.minimumSlope,
    purlinDepth: purlinDepth ?? this.purlinDepth,
    purlinWidth: purlinWidth ?? this.purlinWidth,
    purlinMetal: purlinMetal ?? this.purlinMetal,
    purlinSpacing: purlinSpacing ?? this.purlinSpacing,
    beamDepth: beamDepth ?? this.beamDepth,
    beamWidth: beamWidth ?? this.beamWidth,
    beamWeb: beamWeb ?? this.beamWeb,
    beamFlange: beamFlange ?? this.beamFlange,
    frameSpacing: frameSpacing ?? this.frameSpacing,
    cutback: cutback ?? this.cutback,
    flashing: flashing ?? this.flashing,
    upstand: upstand ?? this.upstand,
    columnIds: columnIds ?? this.columnIds,
  );
  Map<String, dynamic> toJson() => {
    'membrane': membrane,
    'thickness': thickness,
    'skin': skin,
    'module': module,
    'ribHeight': ribHeight,
    'minimumSlope': minimumSlope,
    'purlinDepth': purlinDepth,
    'purlinWidth': purlinWidth,
    'purlinMetal': purlinMetal,
    'purlinSpacing': purlinSpacing,
    'beamDepth': beamDepth,
    'beamWidth': beamWidth,
    'beamWeb': beamWeb,
    'beamFlange': beamFlange,
    'frameSpacing': frameSpacing,
    'cutback': cutback,
    'flashing': flashing,
    'upstand': upstand,
    'columnIds': columnIds,
  };
  factory ArchitectRoofPanelSpec.fromJson(Map json) {
    double n(String k, double fallback) =>
        (json[k] as num?)?.toDouble() ?? fallback;
    return ArchitectRoofPanelSpec(
      membrane: json['membrane'] == true,
      thickness: n('thickness', .1),
      skin: n('skin', .0005),
      module: n('module', 1),
      ribHeight: n('ribHeight', .035),
      minimumSlope: n('minimumSlope', json['membrane'] == true ? 1.2 : 4),
      purlinDepth: n('purlinDepth', .2),
      purlinWidth: n('purlinWidth', .07),
      purlinMetal: n('purlinMetal', .0025),
      purlinSpacing: n('purlinSpacing', 1.5),
      beamDepth: n('beamDepth', .3),
      beamWidth: n('beamWidth', .15),
      beamWeb: n('beamWeb', .006),
      beamFlange: n('beamFlange', .01),
      frameSpacing: n('frameSpacing', 3),
      cutback: n('cutback', .05),
      flashing: n('flashing', .0015),
      upstand: n('upstand', .25),
      columnIds: List<String>.from(json['columnIds'] as List? ?? const []),
    );
  }
}
