// === SECTION: ARCHITECTURAL WALL TYPE MODELS ===
import 'dart:ui';
import '../../../core/l10n/generated/app_localizations.dart';

enum WallCoreMaterial { brick, concrete, timber, panel }

enum WallInsulationMaterial { xps, eps, stoneWool }

/// Semantic usage and classification of an architectural wall.
enum WallUsage {
  /// Exterior façade wall (e.g. 25 cm brick + thermal insulation EPS).
  exterior,

  /// Interior partition wall (e.g. 12 cm single brick).
  interior,

  /// Reinforced concrete shear wall or load-bearing wall.
  bearing,

  /// Balcony or terrace parapet / balustrade edge.
  parapet,
}

/// Finishing style for balcony parapets.
enum ParapetFinish {
  /// Solid parapet topped with protective coping cap.
  cap,

  /// Parapet topped with steel handrail pipe on posts in the top 15 cm.
  handrailPipes,
}

/// Parametric definition of an architectural wall type.
class ArchitectWallType {
  final String id;
  final String name;
  final WallUsage usage;
  final double totalThickness; // in meters (e.g. 0.37 m)
  final double brickThickness; // in meters (e.g. 0.25 m or 0.12 m)
  final double insulationThickness; // in meters (e.g. 0.12 m EPS or 0.0)
  final double? customHeight; // used for parapets (e.g. 1.05 m or 1.20 m)
  final ParapetFinish? parapetFinish;
  final int colorValue;

  const ArchitectWallType({
    required this.id,
    required this.name,
    required this.usage,
    required this.totalThickness,
    this.brickThickness = 0.25,
    this.insulationThickness = 0.0,
    this.customHeight,
    this.parapetFinish,
    this.colorValue = 0xFF78909C,
  });

  bool get isParapet => usage == WallUsage.parapet;
  bool get hasInsulation => insulationThickness > 0.001;

  Color get color => Color(colorValue);

  /// Resolves the compliant parapet height in meters according to Bulgarian building codes
  /// (Наредба № 7 / Наредба № РД-02-20-2):
  /// - 1.05 m for buildings up to 5 storeys or elevation < 20.0 m.
  /// - 1.20 m for buildings above 5 storeys or fall elevation >= 20.0 m.
  static double resolveParapetHeight({
    required double storeyElevation,
    required int storeyIndex,
  }) {
    if (storeyIndex >= 5 || storeyElevation >= 19.99) {
      return 1.20;
    }
    return 1.05;
  }

  /// Default starter catalog of standard architectural wall types.
  static List<ArchitectWallType> standardCatalog({
    double parapetHeight = 1.05,
    ParapetFinish parapetFinish = ParapetFinish.cap,
    AppLocalizations? l10n,
  }) {
    final extName = l10n != null ? '${l10n.architectWallExterior} 25+12 EPS' : 'Exterior 25+12 EPS';
    final intName = l10n != null ? '${l10n.architectWallPartition} 12 cm' : 'Partition 12 cm';
    final brickName = l10n != null ? '${l10n.architectWallBrick} 25 cm' : 'Brick 25 cm';
    final concName = l10n != null ? '${l10n.architectWallConcrete} 25 cm' : 'Concrete 25 cm';
    final parapetName = l10n != null
        ? (parapetFinish == ParapetFinish.handrailPipes
            ? l10n.architectWallParapetPipe(12, parapetHeight.toStringAsFixed(2))
            : l10n.architectWallParapetCap(12, parapetHeight.toStringAsFixed(2)))
        : (parapetFinish == ParapetFinish.handrailPipes
            ? 'Parapet 12 cm (pipe h=${parapetHeight.toStringAsFixed(2)}m)'
            : 'Parapet 12 cm (cap h=${parapetHeight.toStringAsFixed(2)}m)');

    return [
      ArchitectWallType(
        id: 'ext_25_12_eps',
        name: extName,
        usage: WallUsage.exterior,
        totalThickness: 0.37,
        brickThickness: 0.25,
        insulationThickness: 0.12,
        colorValue: 0xFFEF5350,
      ),
      ArchitectWallType(
        id: 'int_12_partition',
        name: intName,
        usage: WallUsage.interior,
        totalThickness: 0.12,
        brickThickness: 0.12,
        insulationThickness: 0.0,
        colorValue: 0xFFFFA726,
      ),
      ArchitectWallType(
        id: 'ext_25_brick',
        name: brickName,
        usage: WallUsage.exterior,
        totalThickness: 0.25,
        brickThickness: 0.25,
        insulationThickness: 0.0,
        colorValue: 0xFFFF7043,
      ),
      ArchitectWallType(
        id: 'bearing_25_concrete',
        name: concName,
        usage: WallUsage.bearing,
        totalThickness: 0.25,
        brickThickness: 0.25,
        insulationThickness: 0.0,
        colorValue: 0xFF78909C,
      ),
      ArchitectWallType(
        id: 'parapet_12',
        name: parapetName,
        usage: WallUsage.parapet,
        totalThickness: 0.12,
        brickThickness: 0.12,
        insulationThickness: 0.0,
        customHeight: parapetHeight,
        parapetFinish: parapetFinish,
        colorValue: 0xFF26A69A,
      ),
    ];
  }


  ArchitectWallType copyWith({
    String? id,
    String? name,
    WallUsage? usage,
    double? totalThickness,
    double? brickThickness,
    double? insulationThickness,
    double? customHeight,
    ParapetFinish? parapetFinish,
    int? colorValue,
  }) =>
      ArchitectWallType(
        id: id ?? this.id,
        name: name ?? this.name,
        usage: usage ?? this.usage,
        totalThickness: totalThickness ?? this.totalThickness,
        brickThickness: brickThickness ?? this.brickThickness,
        insulationThickness: insulationThickness ?? this.insulationThickness,
        customHeight: customHeight ?? this.customHeight,
        parapetFinish: parapetFinish ?? this.parapetFinish,
        colorValue: colorValue ?? this.colorValue,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'usage': usage.name,
    'totalThickness': totalThickness,
    'brickThickness': brickThickness,
    'insulationThickness': insulationThickness,
    'customHeight': customHeight,
    'parapetFinish': parapetFinish?.name,
    'colorValue': colorValue,
  };

  factory ArchitectWallType.fromJson(Map<String, dynamic> json) =>
      ArchitectWallType(
        id: json['id'] as String,
        name: json['name'] as String,
        usage: WallUsage.values.firstWhere(
          (u) => u.name == json['usage'],
          orElse: () => WallUsage.exterior,
        ),
        totalThickness: (json['totalThickness'] as num).toDouble(),
        brickThickness: (json['brickThickness'] as num?)?.toDouble() ?? 0.25,
        insulationThickness:
            (json['insulationThickness'] as num?)?.toDouble() ?? 0.0,
        customHeight: (json['customHeight'] as num?)?.toDouble(),
        parapetFinish: json['parapetFinish'] != null
            ? ParapetFinish.values.firstWhere(
                (p) => p.name == json['parapetFinish'],
                orElse: () => ParapetFinish.cap,
              )
            : null,
        colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFF78909C,
      );
}
