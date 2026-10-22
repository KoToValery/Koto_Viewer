import 'dart:ui';
import 'architect_line_style.dart';
import 'architect_line_symbol.dart';

/// A family of parallel strokes or a row of vector motifs, in paper mm.
class ArchitectHatchLayer {
  final double angleDeg, spacingMm, phaseMm, shiftMm;
  final ArchitectLineStyle lineStyle;
  final bool symbolsOnly;
  const ArchitectHatchLayer({
    this.angleDeg = 45,
    this.spacingMm = 3,
    this.phaseMm = 0,
    this.shiftMm = 0,
    this.lineStyle = ArchitectLineStyle.solid,
    this.symbolsOnly = false,
  });
  ArchitectHatchLayer copyWith({
    double? angleDeg,
    double? spacingMm,
    double? phaseMm,
    double? shiftMm,
    ArchitectLineStyle? lineStyle,
    bool? symbolsOnly,
  }) => ArchitectHatchLayer(
    angleDeg: angleDeg ?? this.angleDeg,
    spacingMm: spacingMm ?? this.spacingMm,
    phaseMm: phaseMm ?? this.phaseMm,
    shiftMm: shiftMm ?? this.shiftMm,
    lineStyle: lineStyle ?? this.lineStyle,
    symbolsOnly: symbolsOnly ?? this.symbolsOnly,
  );
  void validate() {
    if (!angleDeg.isFinite ||
        angleDeg.abs() > 180 ||
        !spacingMm.isFinite ||
        spacingMm < .5 ||
        spacingMm > 100 ||
        !phaseMm.isFinite ||
        phaseMm.abs() > 100 ||
        !shiftMm.isFinite ||
        shiftMm.abs() > 100 ||
        (symbolsOnly && lineStyle.symbol == null)) {
      throw ArgumentError('Invalid hatch layer');
    }
    lineStyle.validate();
  }

  Map<String, dynamic> toJson() => {
    'angleDeg': angleDeg,
    'spacingMm': spacingMm,
    'phaseMm': phaseMm,
    'shiftMm': shiftMm,
    'lineStyle': lineStyle.toJson(),
    'symbolsOnly': symbolsOnly,
  };
  factory ArchitectHatchLayer.fromJson(Map<String, dynamic> j) {
    final layer = ArchitectHatchLayer(
      angleDeg: (j['angleDeg'] as num? ?? 45).toDouble(),
      spacingMm: (j['spacingMm'] as num? ?? 3).toDouble(),
      phaseMm: (j['phaseMm'] as num? ?? 0).toDouble(),
      shiftMm: (j['shiftMm'] as num? ?? 0).toDouble(),
      symbolsOnly: j['symbolsOnly'] as bool? ?? false,
      lineStyle: j['lineStyle'] is Map
          ? ArchitectLineStyle.fromJson(
              Map<String, dynamic>.from(j['lineStyle'] as Map),
            )
          : ArchitectLineStyle.solid,
    );
    layer.validate();
    return layer;
  }
  @override
  bool operator ==(Object other) =>
      other is ArchitectHatchLayer &&
      angleDeg == other.angleDeg &&
      spacingMm == other.spacingMm &&
      phaseMm == other.phaseMm &&
      shiftMm == other.shiftMm &&
      lineStyle == other.lineStyle &&
      symbolsOnly == other.symbolsOnly;
  @override
  int get hashCode => Object.hash(
    angleDeg,
    spacingMm,
    phaseMm,
    shiftMm,
    lineStyle,
    symbolsOnly,
  );
}

/// Immutable snapshots on elements; named custom definitions live in the project.
class ArchitectHatchPattern {
  final String id, name;
  final List<ArchitectHatchLayer> layers;
  const ArchitectHatchPattern({
    required this.id,
    this.name = '',
    required this.layers,
  });
  static const diagonal = ArchitectHatchPattern(
    id: 'diagonal',
    layers: [ArchitectHatchLayer()],
  );
  static const presets = [
    diagonal,
    ArchitectHatchPattern(
      id: 'reverseDiagonal',
      layers: [ArchitectHatchLayer(angleDeg: -45)],
    ),
    ArchitectHatchPattern(
      id: 'horizontal',
      layers: [ArchitectHatchLayer(angleDeg: 0)],
    ),
    ArchitectHatchPattern(
      id: 'vertical',
      layers: [ArchitectHatchLayer(angleDeg: 90)],
    ),
    ArchitectHatchPattern(
      id: 'cross',
      layers: [
        ArchitectHatchLayer(angleDeg: 0),
        ArchitectHatchLayer(angleDeg: 90),
      ],
    ),
    ArchitectHatchPattern(
      id: 'diagonalCross',
      layers: [ArchitectHatchLayer(), ArchitectHatchLayer(angleDeg: -45)],
    ),
    ArchitectHatchPattern(
      id: 'brick',
      layers: [
        ArchitectHatchLayer(angleDeg: 0),
        ArchitectHatchLayer(
          angleDeg: 90,
          spacingMm: 3,
          shiftMm: 3,
          lineStyle: ArchitectLineStyle(
            id: 'hatchBrickJoint',
            name: '_',
            segmentsMm: [3, 3],
          ),
        ),
      ],
    ),
    ArchitectHatchPattern(
      id: 'concrete',
      layers: [
        ArchitectHatchLayer(
          angleDeg: 0,
          spacingMm: 6,
          shiftMm: 4,
          symbolsOnly: true,
          lineStyle: ArchitectLineStyle(
            id: 'hatchAggregate',
            name: '_',
            segmentsMm: [],
            symbol: ArchitectLineSymbol(
              shape: ArchitectLineSymbolShape.triangle,
              sizeMm: 1.2,
              spacingMm: 9,
              angleDeg: 20,
            ),
          ),
        ),
        ArchitectHatchLayer(
          angleDeg: 30,
          spacingMm: 4,
          shiftMm: 2,
          lineStyle: ArchitectLineStyle(
            id: 'hatchGrain',
            name: '_',
            segmentsMm: [.4, 5.5],
          ),
        ),
      ],
    ),
    ArchitectHatchPattern(
      id: 'dots',
      layers: [
        ArchitectHatchLayer(
          angleDeg: 0,
          spacingMm: 3,
          shiftMm: 1.5,
          symbolsOnly: true,
          lineStyle: ArchitectLineStyle(
            id: 'hatchDots',
            name: '_',
            segmentsMm: [],
            symbol: ArchitectLineSymbol(
              shape: ArchitectLineSymbolShape.circle,
              sizeMm: .5,
              spacingMm: 3,
            ),
          ),
        ),
      ],
    ),
    ArchitectHatchPattern(
      id: 'earth',
      layers: [
        ArchitectHatchLayer(
          angleDeg: 0,
          spacingMm: 5,
          shiftMm: 3,
          symbolsOnly: true,
          lineStyle: ArchitectLineStyle(
            id: 'hatchEarth',
            name: '_',
            segmentsMm: [],
            symbol: ArchitectLineSymbol(
              shape: ArchitectLineSymbolShape.custom,
              sizeMm: 3,
              spacingMm: 7,
              strokes: [
                [Offset(-.5, .2), Offset(-.1, -.2)],
                [Offset(-.2, .2), Offset(.2, -.2)],
                [Offset(.1, .2), Offset(.5, -.2)],
              ],
            ),
          ),
        ),
      ],
    ),
  ];
  bool get isPreset => presets.any((p) => p.id == id);
  void validate() {
    if (id.isEmpty ||
        layers.isEmpty ||
        layers.length > 8 ||
        (isPreset && this != presets.firstWhere((p) => p.id == id)) ||
        (!isPreset && name.trim().isEmpty)) {
      throw ArgumentError('Invalid hatch pattern');
    }
    for (final layer in layers) {
      layer.validate();
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (!isPreset) 'name': name,
    if (!isPreset) 'layers': layers.map((l) => l.toJson()).toList(),
  };
  factory ArchitectHatchPattern.fromJson(Map<String, dynamic> j) {
    final preset = presets.where((p) => p.id == j['id']).firstOrNull;
    if (preset != null) return preset;
    final pattern = ArchitectHatchPattern(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      layers: List.unmodifiable(
        (j['layers'] as List? ?? []).map(
          (l) =>
              ArchitectHatchLayer.fromJson(Map<String, dynamic>.from(l as Map)),
        ),
      ),
    );
    pattern.validate();
    return pattern;
  }
  @override
  bool operator ==(Object other) =>
      other is ArchitectHatchPattern &&
      id == other.id &&
      name == other.name &&
      layers.length == other.layers.length &&
      List.generate(
        layers.length,
        (i) => layers[i] == other.layers[i],
      ).every((e) => e);
  @override
  int get hashCode => Object.hash(id, name, Object.hashAll(layers));
}
