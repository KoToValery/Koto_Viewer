import 'dart:math' as math;

/// Construction behaviour is independent of material, location and bearing role.
enum ArchitectWallSystemKind { layered, roundLogs, studFrame, sandwichPanels }

enum ArchitectPanelMount { inFront, betweenColumns }

/// Persistent construction parameters. Dimensions are metres; angles are not
/// encoded in names or catalogue IDs. The wall's thickness supplies log diameter.
class ArchitectWallSystem {
  final ArchitectWallSystemKind kind;
  final double overlapPercent, tailFactor;
  final double studSpacing, studWidth, metalThickness, insulationDepth;
  final double supportDepth, panelModule;
  final ArchitectPanelMount panelMount;
  final bool horizontalPanels;
  final bool openingCasing;
  final double casingWidth, settlementAllowance;

  const ArchitectWallSystem({
    this.kind = ArchitectWallSystemKind.layered,
    this.overlapPercent = 10,
    this.tailFactor = 1,
    this.studSpacing = .6,
    this.studWidth = .05,
    this.metalThickness = .0006,
    this.insulationDepth = .05,
    this.supportDepth = .1,
    this.panelModule = 1,
    this.panelMount = ArchitectPanelMount.inFront,
    this.horizontalPanels = false,
    this.openingCasing = true,
    this.casingWidth = .05,
    this.settlementAllowance = 0,
  });

  bool get isSpecial => kind != ArchitectWallSystemKind.layered;
  bool get isLog => kind == ArchitectWallSystemKind.roundLogs;
  bool get isFrame => kind == ArchitectWallSystemKind.studFrame;
  bool get isPanel => kind == ArchitectWallSystemKind.sandwichPanels;
  double pitch(double diameter) => diameter * (1 - overlapPercent / 100);
  double get additionalDepth => isPanel ? supportDepth : 0;

  void validate(double thickness) {
    if (!isSpecial) return;
    final values = [
      thickness,
      overlapPercent,
      tailFactor,
      studSpacing,
      studWidth,
      metalThickness,
      insulationDepth,
      supportDepth,
      panelModule,
      casingWidth,
      settlementAllowance,
    ];
    if (values.any((v) => !v.isFinite) ||
        thickness <= .001 ||
        overlapPercent < 0 ||
        overlapPercent > 40 ||
        tailFactor < 0 ||
        tailFactor > 5 ||
        studSpacing < .05 ||
        studWidth < .01 ||
        metalThickness <= 0 ||
        metalThickness >= studWidth / 2 ||
        insulationDepth < 0 ||
        supportDepth < 0 ||
        panelModule < .05 ||
        casingWidth <= 0 ||
        settlementAllowance < 0 ||
        (isPanel && supportDepth >= thickness)) {
      throw ArgumentError('Invalid wall construction parameters');
    }
  }

  ArchitectWallSystem copyWith({
    ArchitectWallSystemKind? kind,
    double? overlapPercent,
    double? tailFactor,
    double? studSpacing,
    double? studWidth,
    double? metalThickness,
    double? insulationDepth,
    double? supportDepth,
    double? panelModule,
    ArchitectPanelMount? panelMount,
    bool? horizontalPanels,
    bool? openingCasing,
    double? casingWidth,
    double? settlementAllowance,
  }) => ArchitectWallSystem(
    kind: kind ?? this.kind,
    overlapPercent: overlapPercent ?? this.overlapPercent,
    tailFactor: tailFactor ?? this.tailFactor,
    studSpacing: studSpacing ?? this.studSpacing,
    studWidth: studWidth ?? this.studWidth,
    metalThickness: metalThickness ?? this.metalThickness,
    insulationDepth: insulationDepth ?? this.insulationDepth,
    supportDepth: supportDepth ?? this.supportDepth,
    panelModule: panelModule ?? this.panelModule,
    panelMount: panelMount ?? this.panelMount,
    horizontalPanels: horizontalPanels ?? this.horizontalPanels,
    openingCasing: openingCasing ?? this.openingCasing,
    casingWidth: casingWidth ?? this.casingWidth,
    settlementAllowance: settlementAllowance ?? this.settlementAllowance,
  );

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'overlapPercent': overlapPercent,
    'tailFactor': tailFactor,
    'studSpacing': studSpacing,
    'studWidth': studWidth,
    'metalThickness': metalThickness,
    'insulationDepth': insulationDepth,
    'supportDepth': supportDepth,
    'panelModule': panelModule,
    'panelMount': panelMount.name,
    'horizontalPanels': horizontalPanels,
    'openingCasing': openingCasing,
    'casingWidth': casingWidth,
    'settlementAllowance': settlementAllowance,
  };

  factory ArchitectWallSystem.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ArchitectWallSystem();
    double number(String key, double fallback) =>
        (json[key] as num?)?.toDouble() ?? fallback;
    return ArchitectWallSystem(
      kind:
          ArchitectWallSystemKind.values
              .where((k) => k.name == json['kind'])
              .firstOrNull ??
          ArchitectWallSystemKind.layered,
      overlapPercent: number('overlapPercent', 10),
      tailFactor: number('tailFactor', 1),
      studSpacing: number('studSpacing', .6),
      studWidth: number('studWidth', .05),
      metalThickness: number('metalThickness', .0006),
      insulationDepth: number('insulationDepth', .05),
      supportDepth: number('supportDepth', .1),
      panelModule: number('panelModule', 1),
      panelMount:
          ArchitectPanelMount.values
              .where((k) => k.name == json['panelMount'])
              .firstOrNull ??
          ArchitectPanelMount.inFront,
      horizontalPanels: json['horizontalPanels'] as bool? ?? false,
      openingCasing: json['openingCasing'] as bool? ?? true,
      casingWidth: number('casingWidth', .05),
      settlementAllowance: number('settlementAllowance', 0),
    );
  }

  /// No translated strings participate in physical grouping.
  String get signature => toJson().values.join('/');
}

/// Stable placement data belongs to the instance rather than its catalogue type.
class ArchitectWallSystemPlacement {
  final double? coursePhase;
  final double? startTail, endTail;
  final List<String> columnIds;
  final double mountingOffset;
  const ArchitectWallSystemPlacement({
    this.coursePhase,
    this.startTail,
    this.endTail,
    this.columnIds = const [],
    this.mountingOffset = 0,
  });

  ArchitectWallSystemPlacement copyWith({
    double? coursePhase,
    double? startTail,
    double? endTail,
    List<String>? columnIds,
    double? mountingOffset,
  }) => ArchitectWallSystemPlacement(
    coursePhase: coursePhase ?? this.coursePhase,
    startTail: startTail ?? this.startTail,
    endTail: endTail ?? this.endTail,
    columnIds: columnIds ?? this.columnIds,
    mountingOffset: mountingOffset ?? this.mountingOffset,
  );

  Map<String, dynamic> toJson() => {
    if (coursePhase != null) 'coursePhase': coursePhase,
    if (startTail != null) 'startTail': startTail,
    if (endTail != null) 'endTail': endTail,
    'columnIds': columnIds,
    'mountingOffset': mountingOffset,
  };
  factory ArchitectWallSystemPlacement.fromJson(Map<String, dynamic>? json) =>
      json == null
      ? const ArchitectWallSystemPlacement()
      : ArchitectWallSystemPlacement(
          coursePhase: (json['coursePhase'] as num?)?.toDouble(),
          startTail: (json['startTail'] as num?)?.toDouble(),
          endTail: (json['endTail'] as num?)?.toDouble(),
          columnIds: List<String>.from(json['columnIds'] as List? ?? const []),
          mountingOffset: (json['mountingOffset'] as num?)?.toDouble() ?? 0,
        );

  void validate() {
    if ([
          coursePhase,
          startTail,
          endTail,
          mountingOffset,
        ].whereType<double>().any((v) => !v.isFinite) ||
        (coursePhase != null && (coursePhase! < 0 || coursePhase! >= 1)) ||
        math.min(startTail ?? 0, endTail ?? 0) < 0) {
      throw ArgumentError('Invalid wall system placement');
    }
  }
}
