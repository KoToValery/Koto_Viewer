import 'dart:math' as math;

enum ArchitectRailingKind {
  solidCap,
  solidStainless,
  glassChannel,
  glassPosts,
  verticalBars,
  verticalSlats,
}

enum ArchitectRailingMount { top, side }

/// Construction dimensions in metres. The owning wall supplies total height.
/// A missing design deliberately retains legacy parapet geometry.
class ArchitectRailingDesign {
  final ArchitectRailingKind kind;
  final ArchitectRailingMount mounting;
  final double? solidHeight;
  final double handrailDiameter, postSize, postSpacing;
  final double glassThickness, panelWidth, panelGap, bottomGap;
  final double infillSpacing, infillWidth, infillDepth;
  final double copingThickness, channelWidth, channelHeight;

  const ArchitectRailingDesign({
    this.kind = ArchitectRailingKind.solidCap,
    this.mounting = ArchitectRailingMount.top,
    this.solidHeight,
    this.handrailDiameter = .042,
    this.postSize = .04,
    this.postSpacing = 1,
    this.glassThickness = .02,
    this.panelWidth = 1,
    this.panelGap = .01,
    this.bottomGap = .05,
    this.infillSpacing = .10,
    this.infillWidth = .012,
    this.infillDepth = .012,
    this.copingThickness = .03,
    this.channelWidth = .06,
    this.channelHeight = .12,
  });

  factory ArchitectRailingDesign.preset(ArchitectRailingKind kind) =>
      kind == ArchitectRailingKind.verticalSlats
      ? ArchitectRailingDesign(
          kind: kind,
          infillWidth: .02,
          infillDepth: .06,
          infillSpacing: .08,
        )
      : ArchitectRailingDesign(kind: kind);

  bool get hasSolidBody =>
      kind == ArchitectRailingKind.solidCap ||
      kind == ArchitectRailingKind.solidStainless;
  bool get isGlass =>
      kind == ArchitectRailingKind.glassChannel ||
      kind == ArchitectRailingKind.glassPosts;
  double solidHeightAt(double totalHeight) => !hasSolidBody
      ? 0
      : solidHeight ??
            math.max(
              0,
              totalHeight -
                  (kind == ArchitectRailingKind.solidCap
                      ? copingThickness
                      : .15),
            );

  void validate(double totalHeight) {
    final cap = kind == ArchitectRailingKind.solidCap;
    final channel = kind == ArchitectRailingKind.glassChannel;
    final infill =
        kind == ArchitectRailingKind.verticalBars ||
        kind == ArchitectRailingKind.verticalSlats;
    final positive = [
      totalHeight,
      if (!cap) handrailDiameter,
      if (!cap && !channel) ...[postSize, postSpacing],
      if (isGlass) ...[glassThickness, panelWidth],
      if (infill) ...[infillSpacing, infillWidth, infillDepth],
      if (cap) copingThickness,
      if (channel) ...[channelWidth, channelHeight],
    ];
    if (positive.any((v) => !v.isFinite || v <= 0) ||
        (isGlass &&
            (!panelGap.isFinite || panelGap < 0 || panelGap >= panelWidth)) ||
        (infill && infillWidth >= infillSpacing) ||
        (!cap && handrailDiameter >= totalHeight) ||
        ((infill || kind == ArchitectRailingKind.glassPosts) &&
            (!bottomGap.isFinite ||
                bottomGap < 0 ||
                bottomGap + handrailDiameter >= totalHeight)) ||
        (hasSolidBody &&
            solidHeight != null &&
            (!solidHeight!.isFinite || solidHeight! < 0)) ||
        (hasSolidBody &&
            (solidHeightAt(totalHeight) <= 0 ||
                solidHeightAt(totalHeight) >= totalHeight)) ||
        (kind == ArchitectRailingKind.solidStainless &&
            solidHeightAt(totalHeight) + handrailDiameter >= totalHeight) ||
        (channel &&
            (channelHeight + handrailDiameter >= totalHeight ||
                glassThickness >= channelWidth))) {
      throw ArgumentError('Invalid railing dimensions');
    }
  }

  ArchitectRailingDesign copyWith({
    ArchitectRailingKind? kind,
    ArchitectRailingMount? mounting,
    double? solidHeight,
    bool clearSolidHeight = false,
    double? handrailDiameter,
    double? postSize,
    double? postSpacing,
    double? glassThickness,
    double? panelWidth,
    double? panelGap,
    double? bottomGap,
    double? infillSpacing,
    double? infillWidth,
    double? infillDepth,
    double? copingThickness,
    double? channelWidth,
    double? channelHeight,
  }) => ArchitectRailingDesign(
    kind: kind ?? this.kind,
    mounting: mounting ?? this.mounting,
    solidHeight: clearSolidHeight ? null : solidHeight ?? this.solidHeight,
    handrailDiameter: handrailDiameter ?? this.handrailDiameter,
    postSize: postSize ?? this.postSize,
    postSpacing: postSpacing ?? this.postSpacing,
    glassThickness: glassThickness ?? this.glassThickness,
    panelWidth: panelWidth ?? this.panelWidth,
    panelGap: panelGap ?? this.panelGap,
    bottomGap: bottomGap ?? this.bottomGap,
    infillSpacing: infillSpacing ?? this.infillSpacing,
    infillWidth: infillWidth ?? this.infillWidth,
    infillDepth: infillDepth ?? this.infillDepth,
    copingThickness: copingThickness ?? this.copingThickness,
    channelWidth: channelWidth ?? this.channelWidth,
    channelHeight: channelHeight ?? this.channelHeight,
  );

  Map<String, dynamic> toJson() => {
    'version': 1,
    'kind': kind.name,
    'mounting': mounting.name,
    if (solidHeight != null) 'solidHeight': solidHeight,
    'handrailDiameter': handrailDiameter,
    'postSize': postSize,
    'postSpacing': postSpacing,
    'glassThickness': glassThickness,
    'panelWidth': panelWidth,
    'panelGap': panelGap,
    'bottomGap': bottomGap,
    'infillSpacing': infillSpacing,
    'infillWidth': infillWidth,
    'infillDepth': infillDepth,
    'copingThickness': copingThickness,
    'channelWidth': channelWidth,
    'channelHeight': channelHeight,
  };

  factory ArchitectRailingDesign.fromJson(Map<String, dynamic> json) {
    final kind = ArchitectRailingKind.values.byName(json['kind'] as String);
    final defaults = ArchitectRailingDesign.preset(kind);
    double number(String key, double fallback) =>
        (json[key] as num?)?.toDouble() ?? fallback;
    return defaults.copyWith(
      mounting:
          ArchitectRailingMount.values
              .where((v) => v.name == json['mounting'])
              .firstOrNull ??
          ArchitectRailingMount.top,
      solidHeight: (json['solidHeight'] as num?)?.toDouble(),
      handrailDiameter: number('handrailDiameter', defaults.handrailDiameter),
      postSize: number('postSize', defaults.postSize),
      postSpacing: number('postSpacing', defaults.postSpacing),
      glassThickness: number('glassThickness', defaults.glassThickness),
      panelWidth: number('panelWidth', defaults.panelWidth),
      panelGap: number('panelGap', defaults.panelGap),
      bottomGap: number('bottomGap', defaults.bottomGap),
      infillSpacing: number('infillSpacing', defaults.infillSpacing),
      infillWidth: number('infillWidth', defaults.infillWidth),
      infillDepth: number('infillDepth', defaults.infillDepth),
      copingThickness: number('copingThickness', defaults.copingThickness),
      channelWidth: number('channelWidth', defaults.channelWidth),
      channelHeight: number('channelHeight', defaults.channelHeight),
    );
  }
  String get signature => [
    kind.name,
    if (kind != ArchitectRailingKind.solidCap) ...[
      mounting.name,
      handrailDiameter,
    ],
    if (hasSolidBody) solidHeight,
    if (kind == ArchitectRailingKind.solidCap) copingThickness,
    if (kind != ArchitectRailingKind.solidCap &&
        kind != ArchitectRailingKind.glassChannel) ...[
      postSize,
      postSpacing,
    ],
    if (isGlass) ...[glassThickness, panelWidth, panelGap],
    if (kind == ArchitectRailingKind.glassChannel) ...[
      channelWidth,
      channelHeight,
    ],
    if (kind == ArchitectRailingKind.glassPosts ||
        kind == ArchitectRailingKind.verticalBars ||
        kind == ArchitectRailingKind.verticalSlats)
      bottomGap,
    if (kind == ArchitectRailingKind.verticalBars ||
        kind == ArchitectRailingKind.verticalSlats) ...[
      infillWidth,
      infillDepth,
      infillSpacing,
    ],
  ].join('/');
}
