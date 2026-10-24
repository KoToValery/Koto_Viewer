/// Planning references identify the specification; ARGB is an editable display
/// approximation, never a certified RAL measurement or a licensed RAL library.
enum ArchitectColorPalette { general, bgOup, bgPup, dePlanZV }

enum ArchitectColorRole {
  black,
  white,
  gray,
  red,
  blue,
  green,
  yellow,
  orange,
  residential,
  publicServices,
  industrial,
  storage,
  greenSpace,
  arable,
  perennial,
  uncultivated,
  forest,
  recreationalForest,
  water,
  transport,
  utilities,
  housingLowHigh,
  housingMediumComplex,
  villas,
  specialPurpose,
  culturalLand,
  primaryRoad,
  secondaryRoad,
  collectingRoad,
  servingRoad,
  pedestrian,
  housingExisting,
  housingNew,
  publicExisting,
  publicNew,
  heritageBuilding,
  mixedUse,
  specialUse,
  railway,
  agriculture,
}

class ArchitectColorPreset {
  final String id, code, reference;
  final ArchitectColorPalette palette;
  final ArchitectColorRole role;
  final int argb;
  const ArchitectColorPreset(
    this.id,
    this.palette,
    this.role,
    this.argb,
    this.code,
    this.reference,
  );
}

class ArchitectDrawingColor {
  final int argb;
  final String? presetId;
  const ArchitectDrawingColor(this.argb, {this.presetId});
  static const ink = ArchitectDrawingColor(0xFF424242);
  ArchitectColorPreset? get preset => ArchitectDrawingColors.find(presetId);
  String get hex =>
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  int get opacityPercent => (((argb >> 24) & 255) * 100 / 255).round();
  ArchitectDrawingColor withOpacity(int percent) => ArchitectDrawingColor(
    ((percent.clamp(0, 100) * 255 / 100).round() << 24) | (argb & 0xFFFFFF),
    presetId: presetId,
  );
  void validate() {
    if (argb < 0 ||
        argb > 0xFFFFFFFF ||
        (presetId != null &&
            (preset == null ||
                (preset!.argb & 0xFFFFFF) != (argb & 0xFFFFFF)))) {
      throw ArgumentError('Invalid drawing color reference');
    }
  }

  Map<String, dynamic> toJson() => {
    'argb': argb,
    if (presetId != null) 'presetId': presetId,
  };
  factory ArchitectDrawingColor.fromJson(Map<String, dynamic> j) {
    final value = j['argb'];
    if (value is! int) throw ArgumentError('Invalid ARGB value');
    final result = ArchitectDrawingColor(
      value,
      presetId: j['presetId'] as String?,
    );
    result.validate();
    return result;
  }
  @override
  bool operator ==(Object other) =>
      other is ArchitectDrawingColor &&
      argb == other.argb &&
      presetId == other.presetId;
  @override
  int get hashCode => Object.hash(argb, presetId);
}

class ArchitectDrawingColors {
  static const bgSource =
      'https://www.mrrb.bg/static/media/ups/articles/attachments/3d8c97afdd5ed98f9d3d4623e1e90dfa.pdf';
  static const deSource =
      'https://www.gesetze-im-internet.de/planzv_90/anlage.html';
  static const ralSource =
      'https://www.ral-farben.de/en/ral-digital-colour-library';
  // These swatches are authored RGB approximations. The normative references
  // below are transcribed from Annex 2, tables 1/2, and PlanZV's named tones.
  static const presets = <ArchitectColorPreset>[
    ArchitectColorPreset(
      'black',
      ArchitectColorPalette.general,
      ArchitectColorRole.black,
      0xFF202020,
      '#202020',
      '',
    ),
    ArchitectColorPreset(
      'white',
      ArchitectColorPalette.general,
      ArchitectColorRole.white,
      0xFFFFFFFF,
      '#FFFFFF',
      '',
    ),
    ArchitectColorPreset(
      'gray',
      ArchitectColorPalette.general,
      ArchitectColorRole.gray,
      0xFF909090,
      '#909090',
      '',
    ),
    ArchitectColorPreset(
      'red',
      ArchitectColorPalette.general,
      ArchitectColorRole.red,
      0xFFCC3333,
      '#CC3333',
      '',
    ),
    ArchitectColorPreset(
      'blue',
      ArchitectColorPalette.general,
      ArchitectColorRole.blue,
      0xFF2980B9,
      '#2980B9',
      '',
    ),
    ArchitectColorPreset(
      'green',
      ArchitectColorPalette.general,
      ArchitectColorRole.green,
      0xFF609B45,
      '#609B45',
      '',
    ),
    ArchitectColorPreset(
      'yellow',
      ArchitectColorPalette.general,
      ArchitectColorRole.yellow,
      0xFFF3D548,
      '#F3D548',
      '',
    ),
    ArchitectColorPreset(
      'orange',
      ArchitectColorPalette.general,
      ArchitectColorRole.orange,
      0xFFE79948,
      '#E79948',
      '',
    ),
    ArchitectColorPreset(
      'bgOupResidential',
      ArchitectColorPalette.bgOup,
      ArchitectColorRole.residential,
      0xFFA65E2E,
      'RAL 8023',
      'О.2.1 / О.4.1–О.4.4',
    ),
    ArchitectColorPreset(
      'bgOupPublic',
      ArchitectColorPalette.bgOup,
      ArchitectColorRole.publicServices,
      0xFFAF2B1E,
      'RAL 3000',
      'О.2.2 / О.4.11',
    ),
    ArchitectColorPreset(
      'bgOupIndustrial',
      ArchitectColorPalette.bgOup,
      ArchitectColorRole.industrial,
      0xFF83639D,
      'RAL 4005',
      'О.2.3 / О.4.5–О.4.7',
    ),
    ArchitectColorPreset(
      'bgOupStorage',
      ArchitectColorPalette.bgOup,
      ArchitectColorRole.storage,
      0xFFA18594,
      'RAL 4009',
      'О.2.4',
    ),
    ArchitectColorPreset(
      'bgOupGreen',
      ArchitectColorPalette.bgOup,
      ArchitectColorRole.greenSpace,
      0xFF587F40,
      'RAL 6017',
      'О.2.6 / О.4.8',
    ),
    ArchitectColorPreset(
      'bgOupArable',
      ArchitectColorPalette.bgOup,
      ArchitectColorRole.arable,
      0xFFF3DA0B,
      'RAL 1021',
      'О.2.9.1',
    ),
    ArchitectColorPreset(
      'bgOupPerennial',
      ArchitectColorPalette.bgOup,
      ArchitectColorRole.perennial,
      0xFFF1DD38,
      'RAL 1016',
      'О.2.9.2',
    ),
    ArchitectColorPreset(
      'bgOupUncultivated',
      ArchitectColorPalette.bgOup,
      ArchitectColorRole.uncultivated,
      0xFFC6A664,
      'RAL 1002',
      'О.2.9.3',
    ),
    ArchitectColorPreset(
      'bgOupForest',
      ArchitectColorPalette.bgOup,
      ArchitectColorRole.forest,
      0xFF57A639,
      'RAL 6018',
      'О.2.10.1',
    ),
    ArchitectColorPreset(
      'bgOupRecreationalForest',
      ArchitectColorPalette.bgOup,
      ArchitectColorRole.recreationalForest,
      0xFF35682D,
      'RAL 6010',
      'О.2.10.3',
    ),
    ArchitectColorPreset(
      'bgOupWater',
      ArchitectColorPalette.bgOup,
      ArchitectColorRole.water,
      0xFF2271B3,
      'RAL 5015',
      'О.2.11',
    ),
    ArchitectColorPreset(
      'bgOupTransport',
      ArchitectColorPalette.bgOup,
      ArchitectColorRole.transport,
      0xFF9E9E9E,
      'RAL 7004',
      'О.2.12',
    ),
    ArchitectColorPreset(
      'bgOupUtilities',
      ArchitectColorPalette.bgOup,
      ArchitectColorRole.utilities,
      0xFF6C7059,
      'RAL 7005',
      'О.2.13',
    ),
    ArchitectColorPreset(
      'bgPupHousingLowHigh',
      ArchitectColorPalette.bgPup,
      ArchitectColorRole.housingLowHigh,
      0xFFA48F7A,
      'RAL 1019',
      'П.2.1 / П.2.3',
    ),
    ArchitectColorPreset(
      'bgPupHousingMediumComplex',
      ArchitectColorPalette.bgPup,
      ArchitectColorRole.housingMediumComplex,
      0xFFD2C7BD,
      'RAL 1019+',
      'П.2.2 / П.2.4',
    ),
    ArchitectColorPreset(
      'bgPupIndustrial',
      ArchitectColorPalette.bgPup,
      ArchitectColorRole.industrial,
      0xFFA784A7,
      'RAL 4008+',
      'П.2.5–П.2.7',
    ),
    ArchitectColorPreset(
      'bgPupGreen',
      ArchitectColorPalette.bgPup,
      ArchitectColorRole.greenSpace,
      0xFFABD39C,
      'RAL 6018+',
      'П.2.8 / П.3.5',
    ),
    ArchitectColorPreset(
      'bgPupVillas',
      ArchitectColorPalette.bgPup,
      ArchitectColorRole.villas,
      0xFFF3DA0B,
      'RAL 1021',
      'П.2.10',
    ),
    ArchitectColorPreset(
      'bgPupPublic',
      ArchitectColorPalette.bgPup,
      ArchitectColorRole.publicServices,
      0xFFE0BAB0,
      'RAL 3012+',
      'П.2.11 / П.3.1',
    ),
    ArchitectColorPreset(
      'bgPupTransport',
      ArchitectColorPalette.bgPup,
      ArchitectColorRole.transport,
      0xFFCFCFCF,
      'RAL 7004+',
      'П.3.2',
    ),
    ArchitectColorPreset(
      'bgPupUtilities',
      ArchitectColorPalette.bgPup,
      ArchitectColorRole.utilities,
      0xFFB6B8AC,
      'RAL 7005+',
      'П.3.3',
    ),
    ArchitectColorPreset(
      'bgPupSpecial',
      ArchitectColorPalette.bgPup,
      ArchitectColorRole.specialPurpose,
      0xFFF4D3DA,
      'RAL 3015+',
      'П.3.4',
    ),
    ArchitectColorPreset(
      'bgPupCulturalLand',
      ArchitectColorPalette.bgPup,
      ArchitectColorRole.culturalLand,
      0xFFF9B183,
      'RAL 2008+',
      'П.3.6',
    ),
    ArchitectColorPreset(
      'bgPupWater',
      ArchitectColorPalette.bgPup,
      ArchitectColorRole.water,
      0xFF91B8D9,
      'RAL 5015+',
      'П.3.7',
    ),
    ArchitectColorPreset(
      'bgPupPrimaryRoad',
      ArchitectColorPalette.bgPup,
      ArchitectColorRole.primaryRoad,
      0xFF624A76,
      'RAL 4005-',
      'П.4.1',
    ),
    ArchitectColorPreset(
      'bgPupSecondaryRoad',
      ArchitectColorPalette.bgPup,
      ArchitectColorRole.secondaryRoad,
      0xFF83639D,
      'RAL 4005',
      'П.4.2',
    ),
    ArchitectColorPreset(
      'bgPupCollectingRoad',
      ArchitectColorPalette.bgPup,
      ArchitectColorRole.collectingRoad,
      0xFFC1B1CE,
      'RAL 4005+',
      'П.4.2.1',
    ),
    ArchitectColorPreset(
      'bgPupServingRoad',
      ArchitectColorPalette.bgPup,
      ArchitectColorRole.servingRoad,
      0xFFE0D8E6,
      'RAL 4005++',
      'П.4.2.2 / П.4.3',
    ),
    ArchitectColorPreset(
      'bgPupPedestrian',
      ArchitectColorPalette.bgPup,
      ArchitectColorRole.pedestrian,
      0xFFDBD2A6,
      'RAL 1012 / 1013',
      'П.4.4',
    ),
    ArchitectColorPreset(
      'bgPupHousingExisting',
      ArchitectColorPalette.bgPup,
      ArchitectColorRole.housingExisting,
      0xFF8E402A,
      'RAL 8004',
      'П.5.2',
    ),
    ArchitectColorPreset(
      'bgPupHousingNew',
      ArchitectColorPalette.bgPup,
      ArchitectColorRole.housingNew,
      0xFFA65E2E,
      'RAL 8023',
      'П.5.3',
    ),
    ArchitectColorPreset(
      'bgPupPublicExisting',
      ArchitectColorPalette.bgPup,
      ArchitectColorRole.publicExisting,
      0xFF781F19,
      'RAL 3011',
      'П.5.4',
    ),
    ArchitectColorPreset(
      'bgPupPublicNew',
      ArchitectColorPalette.bgPup,
      ArchitectColorRole.publicNew,
      0xFFD53032,
      'RAL 3018',
      'П.5.5',
    ),
    ArchitectColorPreset(
      'bgPupHeritageBuilding',
      ArchitectColorPalette.bgPup,
      ArchitectColorRole.heritageBuilding,
      0xFFD4652F,
      'RAL 2010',
      'П.5.6',
    ),
    ArchitectColorPreset(
      'deResidential',
      ArchitectColorPalette.dePlanZV,
      ArchitectColorRole.residential,
      0xFFF28C8C,
      '1.1 · W',
      '1.1–1.1.4',
    ),
    ArchitectColorPreset(
      'deMixed',
      ArchitectColorPalette.dePlanZV,
      ArchitectColorRole.mixedUse,
      0xFFC8A784,
      '1.2 · M',
      '1.2–1.2.5',
    ),
    ArchitectColorPreset(
      'deIndustrial',
      ArchitectColorPalette.dePlanZV,
      ArchitectColorRole.industrial,
      0xFFA6A6A6,
      '1.3 · G',
      '1.3–1.3.2',
    ),
    ArchitectColorPreset(
      'deSpecial',
      ArchitectColorPalette.dePlanZV,
      ArchitectColorRole.specialUse,
      0xFFF6BA76,
      '1.4 · S',
      '1.4–1.4.2',
    ),
    ArchitectColorPreset(
      'dePublic',
      ArchitectColorPalette.dePlanZV,
      ArchitectColorRole.publicServices,
      0xFFD56D89,
      '4.1',
      '4.1',
    ),
    ArchitectColorPreset(
      'deTransport',
      ArchitectColorPalette.dePlanZV,
      ArchitectColorRole.transport,
      0xFFE8BF64,
      '5.1 / 6.1',
      '5.1 / 6.1',
    ),
    ArchitectColorPreset(
      'deRailway',
      ArchitectColorPalette.dePlanZV,
      ArchitectColorRole.railway,
      0xFFB49BCB,
      '5.2.1',
      '5.2.1',
    ),
    ArchitectColorPreset(
      'deUtilities',
      ArchitectColorPalette.dePlanZV,
      ArchitectColorRole.utilities,
      0xFFFFF2A5,
      '7',
      '7',
    ),
    ArchitectColorPreset(
      'deGreen',
      ArchitectColorPalette.dePlanZV,
      ArchitectColorRole.greenSpace,
      0xFF93C978,
      '9',
      '9',
    ),
    ArchitectColorPreset(
      'deWater',
      ArchitectColorPalette.dePlanZV,
      ArchitectColorRole.water,
      0xFF8DCEF0,
      '10.1',
      '10.1',
    ),
    ArchitectColorPreset(
      'deAgriculture',
      ArchitectColorPalette.dePlanZV,
      ArchitectColorRole.agriculture,
      0xFFD6DF92,
      '12.1',
      '12.1',
    ),
    ArchitectColorPreset(
      'deForest',
      ArchitectColorPalette.dePlanZV,
      ArchitectColorRole.forest,
      0xFF5AAB9C,
      '12.2',
      '12.2',
    ),
  ];
  static ArchitectColorPreset? find(String? id) =>
      presets.where((p) => p.id == id).firstOrNull;
}
