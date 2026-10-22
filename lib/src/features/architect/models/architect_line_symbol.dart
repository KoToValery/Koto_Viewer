import 'dart:ui';

enum ArchitectLineSymbolShape {
  none,
  lightning,
  circle,
  square,
  triangle,
  diamond,
  cross,
  arrow,
  chevron,
  custom,
}

/// Vector strokes in a normalized unit square, placed in paper millimetres.
class ArchitectLineSymbol {
  final ArchitectLineSymbolShape shape;
  final double sizeMm, spacingMm, angleDeg;
  final bool followLine, clearLine;
  final List<List<Offset>> strokes;
  const ArchitectLineSymbol({
    this.shape = ArchitectLineSymbolShape.lightning,
    this.sizeMm = 3,
    this.spacingMm = 12,
    this.angleDeg = 0,
    this.followLine = true,
    this.clearLine = true,
    this.strokes = const [],
  });

  void validate() {
    if (shape == ArchitectLineSymbolShape.none ||
        !sizeMm.isFinite ||
        sizeMm < .5 ||
        sizeMm > 20 ||
        !spacingMm.isFinite ||
        spacingMm < sizeMm * 1.5 ||
        spacingMm > 100 ||
        !angleDeg.isFinite ||
        angleDeg.abs() > 180 ||
        (shape == ArchitectLineSymbolShape.custom && strokes.isEmpty) ||
        strokes.length > 16 ||
        strokes.fold(0, (n, s) => n + s.length) > 512 ||
        strokes.any(
          (s) =>
              s.length < 2 ||
              s.every((p) => (p - s.first).distance < .0001) ||
              s.any(
                (p) =>
                    !p.dx.isFinite ||
                    !p.dy.isFinite ||
                    p.dx.abs() > .5 ||
                    p.dy.abs() > .5,
              ),
        )) {
      throw ArgumentError('Invalid repeated line symbol');
    }
  }

  ArchitectLineSymbol copyWith({
    ArchitectLineSymbolShape? shape,
    double? sizeMm,
    double? spacingMm,
    double? angleDeg,
    bool? followLine,
    bool? clearLine,
    List<List<Offset>>? strokes,
  }) => ArchitectLineSymbol(
    shape: shape ?? this.shape,
    sizeMm: sizeMm ?? this.sizeMm,
    spacingMm: spacingMm ?? this.spacingMm,
    angleDeg: angleDeg ?? this.angleDeg,
    followLine: followLine ?? this.followLine,
    clearLine: clearLine ?? this.clearLine,
    strokes: strokes ?? this.strokes,
  );

  Map<String, dynamic> toJson() => {
    'shape': shape.name,
    'sizeMm': sizeMm,
    'spacingMm': spacingMm,
    'angleDeg': angleDeg,
    'followLine': followLine,
    'clearLine': clearLine,
    if (shape == ArchitectLineSymbolShape.custom)
      'strokes': [
        for (final s in strokes)
          [
            for (final p in s) [p.dx, p.dy],
          ],
      ],
  };
  factory ArchitectLineSymbol.fromJson(Map<String, dynamic> j) {
    final result = ArchitectLineSymbol(
      shape: ArchitectLineSymbolShape.values.firstWhere(
        (s) => s.name == j['shape'],
        orElse: () => throw ArgumentError('Unknown line symbol'),
      ),
      sizeMm: (j['sizeMm'] as num? ?? 3).toDouble(),
      spacingMm: (j['spacingMm'] as num? ?? 12).toDouble(),
      angleDeg: (j['angleDeg'] as num? ?? 0).toDouble(),
      followLine: j['followLine'] as bool? ?? true,
      clearLine: j['clearLine'] as bool? ?? true,
      strokes: List.unmodifiable(
        (j['strokes'] as List? ?? []).map(
          (s) => List<Offset>.unmodifiable(
            (s as List).map(
              (p) => Offset(
                ((p as List)[0] as num).toDouble(),
                (p[1] as num).toDouble(),
              ),
            ),
          ),
        ),
      ),
    );
    result.validate();
    return result;
  }

  @override
  bool operator ==(Object other) =>
      other is ArchitectLineSymbol &&
      shape == other.shape &&
      sizeMm == other.sizeMm &&
      spacingMm == other.spacingMm &&
      angleDeg == other.angleDeg &&
      followLine == other.followLine &&
      clearLine == other.clearLine &&
      strokes.length == other.strokes.length &&
      List.generate(
        strokes.length,
        (i) =>
            strokes[i].length == other.strokes[i].length &&
            List.generate(
              strokes[i].length,
              (k) => strokes[i][k] == other.strokes[i][k],
            ).every((v) => v),
      ).every((v) => v);
  @override
  int get hashCode => Object.hash(
    shape,
    sizeMm,
    spacingMm,
    angleDeg,
    followLine,
    clearLine,
    Object.hashAll(strokes.map(Object.hashAll)),
  );
}
