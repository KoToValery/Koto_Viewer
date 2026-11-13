// === SECTION: ARCHITECT UNDERLAY & GEODETIC SURVEY MODELS ===

import 'dart:math' as math;
import 'dart:ui';

/// Alignment / deskew mode for 2-point raster calibration.
enum ArchitectRasterAlignMode { keepAngle, horizontal, vertical }

/// Persistent configuration for a storey's CAD (DWG/DXF) Xref underlay.
class ArchitectCadUnderlayConfig {
  final String storeyId;
  final String fileName;
  final String? externalSourcePath;
  final String internalCopyPath;
  final String? kcadCachePath;
  final bool autoReload;
  final bool lockOrigin;
  final int? lastModifiedMs;
  final double? lockedCadOriginX;
  final double? lockedCadOriginY;
  final double? unitsPerMeter;
  final Set<String> hiddenDxfLayers;
  final bool isGeodetic;
  final String? detectedCrsName;
  final double opacity;
  final bool useOriginalColors;
  final bool useOriginalLineweights;
  final bool visible;
  final List<Offset>? maskPolygon;
  final bool maskEnabled;

  const ArchitectCadUnderlayConfig({
    required this.storeyId,
    required this.fileName,
    this.externalSourcePath,
    required this.internalCopyPath,
    this.kcadCachePath,
    this.autoReload = false,
    this.lockOrigin = true,
    this.lastModifiedMs,
    this.lockedCadOriginX,
    this.lockedCadOriginY,
    this.unitsPerMeter,
    this.hiddenDxfLayers = const {},
    this.isGeodetic = false,
    this.detectedCrsName,
    this.opacity = 0.42,
    this.useOriginalColors = false,
    this.useOriginalLineweights = false,
    this.visible = true,
    this.maskPolygon,
    this.maskEnabled = true,
  });

  bool get hasLockedOrigin =>
      lockedCadOriginX != null &&
      lockedCadOriginY != null &&
      unitsPerMeter != null &&
      unitsPerMeter! > 0;

  bool get hasActiveMask =>
      maskEnabled && maskPolygon != null && maskPolygon!.length >= 3;

  ArchitectCadUnderlayConfig copyWith({
    String? storeyId,
    String? fileName,
    String? externalSourcePath,
    bool clearExternalSourcePath = false,
    String? internalCopyPath,
    String? kcadCachePath,
    bool? autoReload,
    bool? lockOrigin,
    int? lastModifiedMs,
    double? lockedCadOriginX,
    double? lockedCadOriginY,
    double? unitsPerMeter,
    Set<String>? hiddenDxfLayers,
    bool? isGeodetic,
    String? detectedCrsName,
    double? opacity,
    bool? useOriginalColors,
    bool? useOriginalLineweights,
    bool? visible,
    List<Offset>? maskPolygon,
    bool clearMask = false,
    bool? maskEnabled,
  }) => ArchitectCadUnderlayConfig(
    storeyId: storeyId ?? this.storeyId,
    fileName: fileName ?? this.fileName,
    externalSourcePath: clearExternalSourcePath
        ? null
        : (externalSourcePath ?? this.externalSourcePath),
    internalCopyPath: internalCopyPath ?? this.internalCopyPath,
    kcadCachePath: kcadCachePath ?? this.kcadCachePath,
    autoReload: false,
    lockOrigin: lockOrigin ?? this.lockOrigin,
    lastModifiedMs: lastModifiedMs ?? this.lastModifiedMs,
    lockedCadOriginX: lockedCadOriginX ?? this.lockedCadOriginX,
    lockedCadOriginY: lockedCadOriginY ?? this.lockedCadOriginY,
    unitsPerMeter: unitsPerMeter ?? this.unitsPerMeter,
    hiddenDxfLayers: hiddenDxfLayers ?? this.hiddenDxfLayers,
    isGeodetic: isGeodetic ?? this.isGeodetic,
    detectedCrsName: detectedCrsName ?? this.detectedCrsName,
    opacity: (opacity ?? this.opacity).clamp(0.05, 1.0),
    useOriginalColors: useOriginalColors ?? this.useOriginalColors,
    useOriginalLineweights:
        useOriginalLineweights ?? this.useOriginalLineweights,
    visible: visible ?? this.visible,
    maskPolygon: clearMask ? null : (maskPolygon ?? this.maskPolygon),
    maskEnabled: maskEnabled ?? this.maskEnabled,
  );

  Map<String, dynamic> toJson() => {
    'storeyId': storeyId,
    'fileName': fileName,
    if (externalSourcePath != null) 'externalSourcePath': externalSourcePath,
    'internalCopyPath': internalCopyPath,
    if (kcadCachePath != null) 'kcadCachePath': kcadCachePath,
    'autoReload': false,
    'lockOrigin': lockOrigin,
    if (lastModifiedMs != null) 'lastModifiedMs': lastModifiedMs,
    if (lockedCadOriginX != null) 'lockedCadOriginX': lockedCadOriginX,
    if (lockedCadOriginY != null) 'lockedCadOriginY': lockedCadOriginY,
    if (unitsPerMeter != null) 'unitsPerMeter': unitsPerMeter,
    if (hiddenDxfLayers.isNotEmpty) 'hiddenDxfLayers': hiddenDxfLayers.toList(),
    if (isGeodetic) 'isGeodetic': true,
    if (detectedCrsName != null) 'detectedCrsName': detectedCrsName,
    'opacity': opacity,
    if (useOriginalColors) 'useOriginalColors': true,
    if (useOriginalLineweights) 'useOriginalLineweights': true,
    if (!visible) 'visible': false,
    if (maskPolygon != null && maskPolygon!.isNotEmpty)
      'maskPolygon': [
        for (final p in maskPolygon!) {'x': p.dx, 'y': p.dy},
      ],
    if (!maskEnabled) 'maskEnabled': false,
  };

  factory ArchitectCadUnderlayConfig.fromJson(Map<String, dynamic> json) =>
      ArchitectCadUnderlayConfig(
        storeyId: json['storeyId'] as String? ?? 'default',
        fileName: json['fileName'] as String? ?? '',
        useOriginalColors: json['useOriginalColors'] == true,
        useOriginalLineweights: json['useOriginalLineweights'] == true,
        externalSourcePath: json['externalSourcePath'] as String?,
        internalCopyPath: json['internalCopyPath'] as String? ?? '',
        kcadCachePath: json['kcadCachePath'] as String?,
        autoReload: false,
        lockOrigin: json['lockOrigin'] != false,
        lastModifiedMs: (json['lastModifiedMs'] as num?)?.toInt(),
        lockedCadOriginX: (json['lockedCadOriginX'] as num?)?.toDouble(),
        lockedCadOriginY: (json['lockedCadOriginY'] as num?)?.toDouble(),
        unitsPerMeter: (json['unitsPerMeter'] as num?)?.toDouble(),
        hiddenDxfLayers: {
          for (final l in json['hiddenDxfLayers'] as List? ?? const [])
            if (l is String) l,
        },
        isGeodetic: json['isGeodetic'] == true,
        detectedCrsName: json['detectedCrsName'] as String?,
        opacity: ((json['opacity'] as num?)?.toDouble() ?? 0.42).clamp(
          0.05,
          1.0,
        ),
        visible: json['visible'] != false,
        maskPolygon: json['maskPolygon'] is List
            ? [
                for (final item in json['maskPolygon'] as List)
                  if (item is Map)
                    Offset(
                      (item['x'] as num?)?.toDouble() ?? 0.0,
                      (item['y'] as num?)?.toDouble() ?? 0.0,
                    ),
              ]
            : null,
        maskEnabled: json['maskEnabled'] != false,
      );
}

/// Raster image / PDF page underlay attached to a storey with 2-point calibration.
class ArchitectRasterUnderlay {
  final String id;
  final String storeyId;
  final String fileName;
  final String internalImagePath;
  final String? sourcePdfPath;
  final int? pdfPageNumber;
  final int imageWidthPx;
  final int imageHeightPx;
  final Offset position; // Top-left corner in Architect local meters
  final double metersPerPixel;
  final double rotationRad;
  final double opacity;
  final bool locked;
  final bool visible;
  final List<Offset>? maskPolygon;
  final bool maskEnabled;

  const ArchitectRasterUnderlay({
    required this.id,
    required this.storeyId,
    required this.fileName,
    required this.internalImagePath,
    this.sourcePdfPath,
    this.pdfPageNumber,
    required this.imageWidthPx,
    required this.imageHeightPx,
    this.position = Offset.zero,
    this.metersPerPixel = 0.01,
    this.rotationRad = 0.0,
    this.opacity = 0.55,
    this.locked = false,
    this.visible = true,
    this.maskPolygon,
    this.maskEnabled = true,
  });

  bool get hasActiveMask =>
      maskEnabled && maskPolygon != null && maskPolygon!.length >= 3;

  double get widthMeters => imageWidthPx * metersPerPixel;
  double get heightMeters => imageHeightPx * metersPerPixel;

  /// Converts image pixel coordinates `(px, py)` into Architect local meters.
  Offset pixelToLocal(Offset pixel) {
    final scaledX = pixel.dx * metersPerPixel;
    final scaledY = pixel.dy * metersPerPixel;
    final cosA = math.cos(rotationRad);
    final sinA = math.sin(rotationRad);
    return Offset(
      position.dx + scaledX * cosA - scaledY * sinA,
      position.dy + scaledX * sinA + scaledY * cosA,
    );
  }

  /// Converts Architect local meters `(mx, my)` into image pixel coordinates.
  Offset localToPixel(Offset local) {
    final dx = local.dx - position.dx;
    final dy = local.dy - position.dy;
    final cosA = math.cos(-rotationRad);
    final sinA = math.sin(-rotationRad);
    final unrotatedX = dx * cosA - dy * sinA;
    final unrotatedY = dx * sinA + dy * cosA;
    final safeScale = metersPerPixel > 1e-9 ? metersPerPixel : 1e-9;
    return Offset(unrotatedX / safeScale, unrotatedY / safeScale);
  }

  /// Returns the 4 corners of the raster underlay in Architect local meters.
  List<Offset> get localCorners => [
    pixelToLocal(Offset.zero),
    pixelToLocal(Offset(imageWidthPx.toDouble(), 0)),
    pixelToLocal(Offset(imageWidthPx.toDouble(), imageHeightPx.toDouble())),
    pixelToLocal(Offset(0, imageHeightPx.toDouble())),
  ];

  Rect get localBounds {
    final corners = localCorners;
    var minX = corners.first.dx;
    var maxX = corners.first.dx;
    var minY = corners.first.dy;
    var maxY = corners.first.dy;
    for (final c in corners.skip(1)) {
      if (c.dx < minX) minX = c.dx;
      if (c.dx > maxX) maxX = c.dx;
      if (c.dy < minY) minY = c.dy;
      if (c.dy > maxY) maxY = c.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  bool containsLocalPoint(Offset local) {
    final px = localToPixel(local);
    return px.dx >= 0 &&
        px.dx <= imageWidthPx &&
        px.dy >= 0 &&
        px.dy <= imageHeightPx;
  }

  /// Calibrates scale and optional orientation from two reference points in local space,
  /// keeping [localP1] anchored at its exact position in the drawing.
  ArchitectRasterUnderlay calibrateTwoPoint({
    required Offset localP1,
    required Offset localP2,
    required double realDistanceMeters,
    ArchitectRasterAlignMode alignMode = ArchitectRasterAlignMode.keepAngle,
  }) {
    if (realDistanceMeters <= 1e-4) return this;
    final px1 = localToPixel(localP1);
    final px2 = localToPixel(localP2);
    final dPx = (px2 - px1).distance;
    if (dPx <= 1e-3) return this;

    final newMetersPerPixel = (realDistanceMeters / dPx).clamp(1e-6, 100.0);
    final thetaPx = math.atan2(px2.dy - px1.dy, px2.dx - px1.dx);
    final currentWorldAngle = thetaPx + rotationRad;

    double newRotationRad = rotationRad;
    switch (alignMode) {
      case ArchitectRasterAlignMode.keepAngle:
        newRotationRad = rotationRad;
      case ArchitectRasterAlignMode.horizontal:
        final targetAngle = math.cos(currentWorldAngle) >= 0 ? 0.0 : math.pi;
        newRotationRad = targetAngle - thetaPx;
      case ArchitectRasterAlignMode.vertical:
        final targetAngle = math.sin(currentWorldAngle) >= 0
            ? (math.pi / 2)
            : (-math.pi / 2);
        newRotationRad = targetAngle - thetaPx;
    }

    // Anchor localP1 so it remains at the exact world position after scaling & rotation.
    final scaledPx1X = px1.dx * newMetersPerPixel;
    final scaledPx1Y = px1.dy * newMetersPerPixel;
    final cosA = math.cos(newRotationRad);
    final sinA = math.sin(newRotationRad);
    final rotatedPx1 = Offset(
      scaledPx1X * cosA - scaledPx1Y * sinA,
      scaledPx1X * sinA + scaledPx1Y * cosA,
    );
    final newPosition = localP1 - rotatedPx1;

    return copyWith(
      position: newPosition,
      metersPerPixel: newMetersPerPixel,
      rotationRad: newRotationRad,
    );
  }

  ArchitectRasterUnderlay copyWith({
    String? id,
    String? storeyId,
    String? fileName,
    String? internalImagePath,
    String? sourcePdfPath,
    int? pdfPageNumber,
    int? imageWidthPx,
    int? imageHeightPx,
    Offset? position,
    double? metersPerPixel,
    double? rotationRad,
    double? opacity,
    bool? locked,
    bool? visible,
    List<Offset>? maskPolygon,
    bool clearMask = false,
    bool? maskEnabled,
  }) => ArchitectRasterUnderlay(
    id: id ?? this.id,
    storeyId: storeyId ?? this.storeyId,
    fileName: fileName ?? this.fileName,
    internalImagePath: internalImagePath ?? this.internalImagePath,
    sourcePdfPath: sourcePdfPath ?? this.sourcePdfPath,
    pdfPageNumber: pdfPageNumber ?? this.pdfPageNumber,
    imageWidthPx: imageWidthPx ?? this.imageWidthPx,
    imageHeightPx: imageHeightPx ?? this.imageHeightPx,
    position: position ?? this.position,
    metersPerPixel: metersPerPixel ?? this.metersPerPixel,
    rotationRad: rotationRad ?? this.rotationRad,
    opacity: (opacity ?? this.opacity).clamp(0.05, 1.0),
    locked: locked ?? this.locked,
    visible: visible ?? this.visible,
    maskPolygon: clearMask ? null : (maskPolygon ?? this.maskPolygon),
    maskEnabled: maskEnabled ?? this.maskEnabled,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'storeyId': storeyId,
    'fileName': fileName,
    'internalImagePath': internalImagePath,
    if (sourcePdfPath != null) 'sourcePdfPath': sourcePdfPath,
    if (pdfPageNumber != null) 'pdfPageNumber': pdfPageNumber,
    'imageWidthPx': imageWidthPx,
    'imageHeightPx': imageHeightPx,
    'position': {'x': position.dx, 'y': position.dy},
    'metersPerPixel': metersPerPixel,
    if (rotationRad.abs() > 1e-7) 'rotationRad': rotationRad,
    'opacity': opacity,
    if (locked) 'locked': true,
    if (!visible) 'visible': false,
    if (maskPolygon != null && maskPolygon!.isNotEmpty)
      'maskPolygon': [
        for (final p in maskPolygon!) {'x': p.dx, 'y': p.dy},
      ],
    if (!maskEnabled) 'maskEnabled': false,
  };

  factory ArchitectRasterUnderlay.fromJson(Map<String, dynamic> json) {
    final posMap = json['position'] as Map<String, dynamic>?;
    return ArchitectRasterUnderlay(
      id: json['id'] as String? ?? 'raster_0',
      storeyId: json['storeyId'] as String? ?? 'default',
      fileName: json['fileName'] as String? ?? '',
      internalImagePath: json['internalImagePath'] as String? ?? '',
      sourcePdfPath: json['sourcePdfPath'] as String?,
      pdfPageNumber: (json['pdfPageNumber'] as num?)?.toInt(),
      imageWidthPx: (json['imageWidthPx'] as num?)?.toInt() ?? 1000,
      imageHeightPx: (json['imageHeightPx'] as num?)?.toInt() ?? 1000,
      position: posMap != null
          ? Offset(
              (posMap['x'] as num?)?.toDouble() ?? 0.0,
              (posMap['y'] as num?)?.toDouble() ?? 0.0,
            )
          : Offset.zero,
      metersPerPixel: (json['metersPerPixel'] as num?)?.toDouble() ?? 0.01,
      rotationRad: (json['rotationRad'] as num?)?.toDouble() ?? 0.0,
      opacity: ((json['opacity'] as num?)?.toDouble() ?? 0.55).clamp(0.05, 1.0),
      locked: json['locked'] == true,
      visible: json['visible'] != false,
      maskPolygon: json['maskPolygon'] is List
          ? [
              for (final item in json['maskPolygon'] as List)
                if (item is Map)
                  Offset(
                    (item['x'] as num?)?.toDouble() ?? 0.0,
                    (item['y'] as num?)?.toDouble() ?? 0.0,
                  ),
            ]
          : null,
      maskEnabled: json['maskEnabled'] != false,
    );
  }
}

/// Geodetic contour line (хоризонтал) extracted into layer `G-TOPO`.
/// Prepared as the foundation for automatic terrain profiles in Sections & 3D Terrain.
class ArchitectGeodeticContour {
  final String id;
  final String storeyId;
  final List<Offset> points; // In Architect local meters
  final double elevation; // Absolute / geodetic elevation Z (e.g. 542.50 m)
  final bool isMajor; // Major index contour (главен хоризонтал)
  final bool closed;
  final String sourceLayer;

  const ArchitectGeodeticContour({
    required this.id,
    required this.storeyId,
    required this.points,
    required this.elevation,
    this.isMajor = false,
    this.closed = false,
    this.sourceLayer = '0',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'storeyId': storeyId,
    'points': [
      for (final p in points) {'x': p.dx, 'y': p.dy},
    ],
    'elevation': elevation,
    if (isMajor) 'isMajor': true,
    if (closed) 'closed': true,
    'sourceLayer': sourceLayer,
  };

  factory ArchitectGeodeticContour.fromJson(Map<String, dynamic> json) =>
      ArchitectGeodeticContour(
        id: json['id'] as String? ?? '',
        storeyId: json['storeyId'] as String? ?? 'default',
        points: [
          for (final p in json['points'] as List? ?? const [])
            if (p is Map)
              Offset(
                (p['x'] as num?)?.toDouble() ?? 0.0,
                (p['y'] as num?)?.toDouble() ?? 0.0,
              ),
        ],
        elevation: (json['elevation'] as num?)?.toDouble() ?? 0.0,
        isMajor: json['isMajor'] == true,
        closed: json['closed'] == true,
        sourceLayer: json['sourceLayer'] as String? ?? '0',
      );
}

/// Geodetic spot elevation point (височинна кота / пикет) extracted into `G-TOPO`.
class ArchitectGeodeticPoint {
  final String id;
  final String storeyId;
  final Offset position; // In Architect local meters
  final double geodeticX; // Original Easting / X
  final double geodeticY; // Original Northing / Y
  final double elevation; // Extracted Z elevation in meters
  final String sourceLayer;

  const ArchitectGeodeticPoint({
    required this.id,
    required this.storeyId,
    required this.position,
    required this.geodeticX,
    required this.geodeticY,
    required this.elevation,
    this.sourceLayer = '0',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'storeyId': storeyId,
    'position': {'x': position.dx, 'y': position.dy},
    'geodeticX': geodeticX,
    'geodeticY': geodeticY,
    'elevation': elevation,
    'sourceLayer': sourceLayer,
  };

  factory ArchitectGeodeticPoint.fromJson(Map<String, dynamic> json) {
    final pos = json['position'] as Map<String, dynamic>?;
    return ArchitectGeodeticPoint(
      id: json['id'] as String? ?? '',
      storeyId: json['storeyId'] as String? ?? 'default',
      position: pos != null
          ? Offset(
              (pos['x'] as num?)?.toDouble() ?? 0.0,
              (pos['y'] as num?)?.toDouble() ?? 0.0,
            )
          : Offset.zero,
      geodeticX: (json['geodeticX'] as num?)?.toDouble() ?? 0.0,
      geodeticY: (json['geodeticY'] as num?)?.toDouble() ?? 0.0,
      elevation: (json['elevation'] as num?)?.toDouble() ?? 0.0,
      sourceLayer: json['sourceLayer'] as String? ?? '0',
    );
  }
}

/// Project-level Geodetic Survey container storing the locked geodetic origin
/// and per-storey contours/spot elevations on layer `G-TOPO`.
class ArchitectGeodeticSurvey {
  final String coordinateSystemId;
  final double geodeticOriginX;
  final double geodeticOriginY;
  final double unitsPerMeter;
  final double? buildingZeroElevation;
  final List<ArchitectGeodeticContour> contours;
  final List<ArchitectGeodeticPoint> spotElevations;

  const ArchitectGeodeticSurvey({
    required this.coordinateSystemId,
    required this.geodeticOriginX,
    required this.geodeticOriginY,
    this.unitsPerMeter = 1.0,
    this.buildingZeroElevation,
    this.contours = const [],
    this.spotElevations = const [],
  });

  List<ArchitectGeodeticContour> contoursForStorey(String storeyId) =>
      contours.where((c) => c.storeyId == storeyId).toList();

  List<ArchitectGeodeticPoint> pointsForStorey(String storeyId) =>
      spotElevations.where((p) => p.storeyId == storeyId).toList();

  bool hasDataForStorey(String storeyId) =>
      contours.any((c) => c.storeyId == storeyId) ||
      spotElevations.any((p) => p.storeyId == storeyId);

  /// Replaces contours and spot elevations for [storeyId] while preserving
  /// the project's geodetic coordinate anchor and other storeys' data.
  ArchitectGeodeticSurvey withStoreyData({
    required String storeyId,
    required List<ArchitectGeodeticContour> storeyContours,
    required List<ArchitectGeodeticPoint> storeyPoints,
    String? coordinateSystemId,
    double? geodeticOriginX,
    double? geodeticOriginY,
    double? unitsPerMeter,
  }) => ArchitectGeodeticSurvey(
    coordinateSystemId: coordinateSystemId ?? this.coordinateSystemId,
    geodeticOriginX: geodeticOriginX ?? this.geodeticOriginX,
    geodeticOriginY: geodeticOriginY ?? this.geodeticOriginY,
    unitsPerMeter: unitsPerMeter ?? this.unitsPerMeter,
    buildingZeroElevation: buildingZeroElevation,
    contours: [
      for (final c in contours)
        if (c.storeyId != storeyId) c,
      ...storeyContours,
    ],
    spotElevations: [
      for (final p in spotElevations)
        if (p.storeyId != storeyId) p,
      ...storeyPoints,
    ],
  );

  ArchitectGeodeticSurvey removeStoreyData(String storeyId) =>
      ArchitectGeodeticSurvey(
        coordinateSystemId: coordinateSystemId,
        geodeticOriginX: geodeticOriginX,
        geodeticOriginY: geodeticOriginY,
        unitsPerMeter: unitsPerMeter,
        buildingZeroElevation: buildingZeroElevation,
        contours: contours.where((c) => c.storeyId != storeyId).toList(),
        spotElevations: spotElevations
            .where((p) => p.storeyId != storeyId)
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'coordinateSystemId': coordinateSystemId,
    'geodeticOriginX': geodeticOriginX,
    'geodeticOriginY': geodeticOriginY,
    'unitsPerMeter': unitsPerMeter,
    if (buildingZeroElevation != null)
      'buildingZeroElevation': buildingZeroElevation,
    if (contours.isNotEmpty)
      'contours': contours.map((c) => c.toJson()).toList(),
    if (spotElevations.isNotEmpty)
      'spotElevations': spotElevations.map((p) => p.toJson()).toList(),
  };

  factory ArchitectGeodeticSurvey.fromJson(Map<String, dynamic> json) =>
      ArchitectGeodeticSurvey(
        coordinateSystemId:
            json['coordinateSystemId'] as String? ?? 'localCartesian',
        geodeticOriginX: (json['geodeticOriginX'] as num?)?.toDouble() ?? 0.0,
        geodeticOriginY: (json['geodeticOriginY'] as num?)?.toDouble() ?? 0.0,
        unitsPerMeter: (json['unitsPerMeter'] as num?)?.toDouble() ?? 1.0,
        buildingZeroElevation: (json['buildingZeroElevation'] as num?)
            ?.toDouble(),
        contours: [
          for (final c in json['contours'] as List? ?? const [])
            if (c is Map)
              ArchitectGeodeticContour.fromJson(Map<String, dynamic>.from(c)),
        ],
        spotElevations: [
          for (final p in json['spotElevations'] as List? ?? const [])
            if (p is Map)
              ArchitectGeodeticPoint.fromJson(Map<String, dynamic>.from(p)),
        ],
      );
}
