import 'dart:ui';
import '../../../core/l10n/generated/app_localizations.dart';
import 'architect_contour.dart';

/// Suspended ceiling system type.
enum SuspendedCeilingType {
  armstrong,
  gypsumBoard;

  String localizedName(AppLocalizations l) => switch (this) {
    SuspendedCeilingType.armstrong => l.architectCeilingArmstrong,
    SuspendedCeilingType.gypsumBoard => l.architectCeilingGypsum,
  };
}

/// Grid profile type for Armstrong / modular suspended ceilings.
enum ArmstrongProfileType {
  t24,
  t15,
  concealed;

  String localizedName(AppLocalizations l) => switch (this) {
    ArmstrongProfileType.t24 => l.architectCeilingProfileT24,
    ArmstrongProfileType.t15 => l.architectCeilingProfileT15,
    ArmstrongProfileType.concealed => l.architectCeilingProfileConcealed,
  };
}

/// Gypsum board variant for monolithic suspended ceilings.
enum GypsumBoardVariant {
  standard,
  moistureResistant,
  fireResistant,
  acoustic;

  String localizedName(AppLocalizations l) => switch (this) {
    GypsumBoardVariant.standard => l.architectCeilingGypsumStandard,
    GypsumBoardVariant.moistureResistant => l.architectCeilingGypsumMoisture,
    GypsumBoardVariant.fireResistant => l.architectCeilingGypsumFire,
    GypsumBoardVariant.acoustic => l.architectCeilingGypsumAcoustic,
  };
}

/// How the suspended ceiling elevation is anchored vertically.
enum CeilingElevationAnchor {
  /// Measured down (`dropFromUpperSlab`) from the overhead slab underside.
  fromUpperSlab,

  /// Measured up (`clearHeight`) from the current storey's finished floor.
  clearHeight;

  String localizedName(AppLocalizations l) => switch (this) {
    CeilingElevationAnchor.fromUpperSlab => l.architectCeilingAnchorUpperSlab,
    CeilingElevationAnchor.clearHeight => l.architectCeilingAnchorClearHeight,
  };
}

/// Suspended ceiling entity anchored below the upper structural slab underside
/// or at a fixed clear height above the finished floor (e.g. directly under a
/// sloped roof or in a free/atrium space).
class ArchitectSuspendedCeiling {
  final String id;
  final SuspendedCeilingType type;
  final List<Offset> polygon;
  final List<double>? bulges;
  final List<List<Offset>> holes;

  /// Vertical anchor mode: below overhead slab underside or above finished floor.
  final CeilingElevationAnchor elevationAnchor;

  /// Vertical drop in metres from the underside of the upper structural slab
  /// to the visible bottom face of the suspended ceiling (default 0.25 m).
  final double dropFromUpperSlab;

  /// Clear height in metres from the current storey's finished floor up to the
  /// visible bottom face of the suspended ceiling when [elevationAnchor] is
  /// [CeilingElevationAnchor.clearHeight] (default 2.55 m).
  final double clearHeight;

  /// Single panel/board thickness in metres (e.g. 0.015 m Armstrong, 0.0125 m GK).
  final double panelThickness;

  /// Carrier grid / CD+UD suspension profile height above the panel in metres.
  final double gridSystemHeight;

  /// Whether mineral/acoustic insulation is placed above the ceiling.
  final bool hasInsulation;

  /// Insulation thickness in metres when [hasInsulation] is true.
  final double insulationThickness;

  // --- Armstrong modular grid parameters ---
  final double tileWidth;
  final double tileLength;
  final Offset? gridOrigin;
  final double gridAngle;
  final bool gridCentered;
  final ArmstrongProfileType armstrongProfile;

  // --- Gypsum board parameters ---
  final GypsumBoardVariant gypsumVariant;
  final bool doubleBoard;

  // --- Annotation & auto-boundary metadata ---
  final String label;
  final bool showLabel;
  final bool showElevationMarker;
  final Offset? seedPoint;
  final bool isAutoBoundary;

  const ArchitectSuspendedCeiling({
    required this.id,
    this.type = SuspendedCeilingType.gypsumBoard,
    required this.polygon,
    this.bulges,
    this.holes = const [],
    this.elevationAnchor = CeilingElevationAnchor.fromUpperSlab,
    this.dropFromUpperSlab = 0.25,
    this.clearHeight = 2.55,
    double? panelThickness,
    this.gridSystemHeight = 0.04,
    this.hasInsulation = false,
    this.insulationThickness = 0.05,
    this.tileWidth = 0.60,
    this.tileLength = 0.60,
    this.gridOrigin,
    this.gridAngle = 0.0,
    this.gridCentered = true,
    this.armstrongProfile = ArmstrongProfileType.t24,
    this.gypsumVariant = GypsumBoardVariant.standard,
    this.doubleBoard = false,
    this.label = '',
    this.showLabel = true,
    this.showElevationMarker = true,
    this.seedPoint,
    this.isAutoBoundary = false,
  }) : panelThickness =
           panelThickness ??
           (type == SuspendedCeilingType.armstrong ? 0.015 : 0.0125);

  /// Effective thickness of the board/tile finish layer(s) in metres.
  double get effectivePanelThickness =>
      type == SuspendedCeilingType.gypsumBoard && doubleBoard
      ? panelThickness * 2
      : panelThickness;

  /// Total vertical thickness of the ceiling assembly (panel + carrier + wool).
  double get constructionThickness =>
      effectivePanelThickness +
      gridSystemHeight +
      (hasInsulation ? insulationThickness : 0.0);

  List<Offset> get tessellatedPolygon =>
      ArchitectContour.tessellate(polygon, bulges);

  double get area {
    final pts = tessellatedPolygon;
    if (pts.length < 3) return 0.0;
    double sum = 0.0;
    for (int i = 0; i < pts.length; i++) {
      final p1 = pts[i];
      final p2 = pts[(i + 1) % pts.length];
      sum += (p1.dx * p2.dy - p2.dx * p1.dy);
    }
    return (sum.abs() / 2.0) - ArchitectContour.area(holes);
  }

  Offset get centroid {
    if (polygon.isEmpty) return Offset.zero;
    double cx = 0, cy = 0;
    for (final p in polygon) {
      cx += p.dx;
      cy += p.dy;
    }
    return Offset(cx / polygon.length, cy / polygon.length);
  }

  bool containsPoint(Offset pt) {
    if (polygon.length < 3) return false;
    final path = ArchitectContour.path(polygon, holes, bulges: bulges);
    return path.contains(pt);
  }

  ArchitectSuspendedCeiling copyWith({
    String? id,
    SuspendedCeilingType? type,
    List<Offset>? polygon,
    List<double>? bulges,
    bool clearBulges = false,
    List<List<Offset>>? holes,
    CeilingElevationAnchor? elevationAnchor,
    double? dropFromUpperSlab,
    double? clearHeight,
    double? panelThickness,
    double? gridSystemHeight,
    bool? hasInsulation,
    double? insulationThickness,
    double? tileWidth,
    double? tileLength,
    Offset? gridOrigin,
    bool clearGridOrigin = false,
    double? gridAngle,
    bool? gridCentered,
    ArmstrongProfileType? armstrongProfile,
    GypsumBoardVariant? gypsumVariant,
    bool? doubleBoard,
    String? label,
    bool? showLabel,
    bool? showElevationMarker,
    Offset? seedPoint,
    bool clearSeedPoint = false,
    bool? isAutoBoundary,
  }) => ArchitectSuspendedCeiling(
    id: id ?? this.id,
    type: type ?? this.type,
    polygon: polygon ?? this.polygon,
    bulges: clearBulges ? null : (bulges ?? this.bulges),
    holes: holes ?? this.holes,
    elevationAnchor: elevationAnchor ?? this.elevationAnchor,
    dropFromUpperSlab: dropFromUpperSlab ?? this.dropFromUpperSlab,
    clearHeight: clearHeight ?? this.clearHeight,
    panelThickness: panelThickness ?? this.panelThickness,
    gridSystemHeight: gridSystemHeight ?? this.gridSystemHeight,
    hasInsulation: hasInsulation ?? this.hasInsulation,
    insulationThickness: insulationThickness ?? this.insulationThickness,
    tileWidth: tileWidth ?? this.tileWidth,
    tileLength: tileLength ?? this.tileLength,
    gridOrigin: clearGridOrigin ? null : (gridOrigin ?? this.gridOrigin),
    gridAngle: gridAngle ?? this.gridAngle,
    gridCentered: gridCentered ?? this.gridCentered,
    armstrongProfile: armstrongProfile ?? this.armstrongProfile,
    gypsumVariant: gypsumVariant ?? this.gypsumVariant,
    doubleBoard: doubleBoard ?? this.doubleBoard,
    label: label ?? this.label,
    showLabel: showLabel ?? this.showLabel,
    showElevationMarker: showElevationMarker ?? this.showElevationMarker,
    seedPoint: clearSeedPoint ? null : (seedPoint ?? this.seedPoint),
    isAutoBoundary: isAutoBoundary ?? this.isAutoBoundary,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'polygon': [
      for (final p in polygon) {'x': p.dx, 'y': p.dy},
    ],
    if (bulges != null && bulges!.any((b) => b.abs() > 1e-6)) 'bulges': bulges,
    if (holes.isNotEmpty) 'holes': ArchitectContour.write(holes),
    if (elevationAnchor != CeilingElevationAnchor.fromUpperSlab)
      'elevationAnchor': elevationAnchor.name,
    'dropFromUpperSlab': dropFromUpperSlab,
    if (elevationAnchor == CeilingElevationAnchor.clearHeight ||
        (clearHeight - 2.55).abs() > 1e-6)
      'clearHeight': clearHeight,
    'panelThickness': panelThickness,
    'gridSystemHeight': gridSystemHeight,
    if (hasInsulation) 'hasInsulation': true,
    if (hasInsulation) 'insulationThickness': insulationThickness,
    'tileWidth': tileWidth,
    'tileLength': tileLength,
    if (gridOrigin != null)
      'gridOrigin': {'x': gridOrigin!.dx, 'y': gridOrigin!.dy},
    if (gridAngle.abs() > 1e-6) 'gridAngle': gridAngle,
    'gridCentered': gridCentered,
    'armstrongProfile': armstrongProfile.name,
    'gypsumVariant': gypsumVariant.name,
    if (doubleBoard) 'doubleBoard': true,
    if (label.isNotEmpty) 'label': label,
    if (!showLabel) 'showLabel': false,
    if (!showElevationMarker) 'showElevationMarker': false,
    if (seedPoint != null)
      'seedPoint': {'x': seedPoint!.dx, 'y': seedPoint!.dy},
    if (isAutoBoundary) 'isAutoBoundary': true,
  };

  factory ArchitectSuspendedCeiling.fromJson(Map<String, dynamic> json) {
    final parsedType = SuspendedCeilingType.values.firstWhere(
      (t) => t.name == json['type'],
      orElse: () => SuspendedCeilingType.gypsumBoard,
    );
    return ArchitectSuspendedCeiling(
      id: json['id'] as String,
      type: parsedType,
      polygon:
          (json['polygon'] as List<dynamic>?)
              ?.map(
                (p) => Offset(
                  (p['x'] as num).toDouble(),
                  (p['y'] as num).toDouble(),
                ),
              )
              .toList() ??
          const [],
      bulges: (json['bulges'] as List<dynamic>?)
          ?.map((b) => (b as num).toDouble())
          .toList(),
      holes: ArchitectContour.read(json['holes']),
      elevationAnchor: CeilingElevationAnchor.values.firstWhere(
        (a) => a.name == json['elevationAnchor'],
        orElse: () => CeilingElevationAnchor.fromUpperSlab,
      ),
      dropFromUpperSlab:
          (json['dropFromUpperSlab'] as num?)?.toDouble() ?? 0.25,
      clearHeight: (json['clearHeight'] as num?)?.toDouble() ?? 2.55,
      panelThickness: (json['panelThickness'] as num?)?.toDouble(),
      gridSystemHeight: (json['gridSystemHeight'] as num?)?.toDouble() ?? 0.04,
      hasInsulation: json['hasInsulation'] as bool? ?? false,
      insulationThickness:
          (json['insulationThickness'] as num?)?.toDouble() ?? 0.05,
      tileWidth: (json['tileWidth'] as num?)?.toDouble() ?? 0.60,
      tileLength: (json['tileLength'] as num?)?.toDouble() ?? 0.60,
      gridOrigin: json['gridOrigin'] is Map
          ? Offset(
              (json['gridOrigin']['x'] as num).toDouble(),
              (json['gridOrigin']['y'] as num).toDouble(),
            )
          : null,
      gridAngle: (json['gridAngle'] as num?)?.toDouble() ?? 0.0,
      gridCentered: json['gridCentered'] as bool? ?? true,
      armstrongProfile: ArmstrongProfileType.values.firstWhere(
        (p) => p.name == json['armstrongProfile'],
        orElse: () => ArmstrongProfileType.t24,
      ),
      gypsumVariant: GypsumBoardVariant.values.firstWhere(
        (v) => v.name == json['gypsumVariant'],
        orElse: () => GypsumBoardVariant.standard,
      ),
      doubleBoard: json['doubleBoard'] as bool? ?? false,
      label: json['label'] as String? ?? '',
      showLabel: json['showLabel'] as bool? ?? true,
      showElevationMarker: json['showElevationMarker'] as bool? ?? true,
      seedPoint: json['seedPoint'] is Map
          ? Offset(
              (json['seedPoint']['x'] as num).toDouble(),
              (json['seedPoint']['y'] as num).toDouble(),
            )
          : null,
      isAutoBoundary: json['isAutoBoundary'] as bool? ?? false,
    );
  }
}
