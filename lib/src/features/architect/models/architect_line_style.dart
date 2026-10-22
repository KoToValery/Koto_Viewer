import 'architect_line_symbol.dart';

/// Dash, gap and repeated symbol dimensions on the printed sheet.
/// Built-in IDs are stable; custom names are user-entered project data.
class ArchitectLineStyle {
  final String id;
  final String name;
  final List<double> segmentsMm;
  final ArchitectLineSymbol? symbol;
  const ArchitectLineStyle({
    required this.id,
    this.name = '',
    required this.segmentsMm,
    this.symbol,
  });

  static const solid = ArchitectLineStyle(id: 'solid', segmentsMm: []);
  static const presets = [
    solid,
    ArchitectLineStyle(id: 'dashed', segmentsMm: [3, 1.5]),
    ArchitectLineStyle(id: 'shortDashed', segmentsMm: [1.5, 1]),
    ArchitectLineStyle(id: 'longDashed', segmentsMm: [6, 2]),
    ArchitectLineStyle(id: 'dotted', segmentsMm: [.25, 1]),
    ArchitectLineStyle(id: 'sparseDotted', segmentsMm: [.25, 2]),
    ArchitectLineStyle(id: 'dashDot', segmentsMm: [5, 1, .25, 1]),
    ArchitectLineStyle(id: 'dashDoubleDot', segmentsMm: [5, 1, .25, 1, .25, 1]),
    ArchitectLineStyle(id: 'longDashDot', segmentsMm: [9, 1.5, .25, 1.5]),
    ArchitectLineStyle(id: 'longShortDash', segmentsMm: [7, 1.5, 2, 1.5]),
    ArchitectLineStyle(id: 'doubleDashDot', segmentsMm: [4, 1, 4, 1, .25, 1]),
  ];

  static const symbolPresets = [
    ArchitectLineStyle(
      id: 'powerLine',
      segmentsMm: [],
      symbol: ArchitectLineSymbol(shape: ArchitectLineSymbolShape.lightning),
    ),
  ];
  static Iterable<ArchitectLineStyle> get allPresets => [
    ...presets,
    ...symbolPresets,
  ];

  bool get isSolid => segmentsMm.isEmpty;
  bool get isPreset => allPresets.any((s) => s.id == id);

  void validate() {
    if (id.isEmpty ||
        (isPreset && this != allPresets.firstWhere((s) => s.id == id)) ||
        (!isPreset &&
            (name.trim().isEmpty || (segmentsMm.isEmpty && symbol == null))) ||
        segmentsMm.length.isOdd ||
        segmentsMm.length > 16 ||
        segmentsMm.any((v) => !v.isFinite || v < .1 || v > 100)) {
      throw ArgumentError('Invalid line pattern');
    }
    symbol?.validate();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (!isPreset) 'name': name,
    if (!isPreset) 'segmentsMm': segmentsMm,
    if (!isPreset && symbol != null) 'symbol': symbol!.toJson(),
  };

  factory ArchitectLineStyle.fromJson(Map<String, dynamic> json) {
    final preset = allPresets.where((s) => s.id == json['id']).firstOrNull;
    if (preset != null) return preset;
    final style = ArchitectLineStyle(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      segmentsMm: List.unmodifiable(
        (json['segmentsMm'] as List? ?? []).map((v) => (v as num).toDouble()),
      ),
      symbol: json['symbol'] is Map
          ? ArchitectLineSymbol.fromJson(
              Map<String, dynamic>.from(json['symbol'] as Map),
            )
          : null,
    );
    style.validate();
    return style;
  }

  @override
  bool operator ==(Object other) =>
      other is ArchitectLineStyle &&
      id == other.id &&
      name == other.name &&
      symbol == other.symbol &&
      segmentsMm.length == other.segmentsMm.length &&
      List.generate(
        segmentsMm.length,
        (i) => segmentsMm[i] == other.segmentsMm[i],
      ).every((v) => v);
  @override
  int get hashCode => Object.hash(id, name, symbol, Object.hashAll(segmentsMm));
}
