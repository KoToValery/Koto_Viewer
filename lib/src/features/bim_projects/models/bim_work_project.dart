import 'dart:ui';

/// Represents an architectural floor underlay and its positioning
/// within a multi-storey BiM work project.
class BimStoreyUnderlay {
  final String storeyId;
  final String name;
  final double elevation;
  final double height;
  final String? sourceFileName;
  final String? underlayFileName;
  final Offset? controlPoint;
  final double unitScale;
  final Map<String, bool> layerVisibility;
  final bool wallsDetected;

  const BimStoreyUnderlay({
    required this.storeyId,
    required this.name,
    required this.elevation,
    this.height = 2.80,
    this.sourceFileName,
    this.underlayFileName,
    this.controlPoint,
    this.unitScale = 1.0,
    this.layerVisibility = const {},
    this.wallsDetected = false,
  });

  bool get hasUnderlay =>
      underlayFileName != null && underlayFileName!.trim().isNotEmpty;

  bool get isControlPointSet => controlPoint != null;

  BimStoreyUnderlay copyWith({
    String? storeyId,
    String? name,
    double? elevation,
    double? height,
    String? sourceFileName,
    String? underlayFileName,
    Offset? controlPoint,
    bool clearControlPoint = false,
    double? unitScale,
    Map<String, bool>? layerVisibility,
    bool? wallsDetected,
  }) {
    return BimStoreyUnderlay(
      storeyId: storeyId ?? this.storeyId,
      name: name ?? this.name,
      elevation: elevation ?? this.elevation,
      height: height ?? this.height,
      sourceFileName: sourceFileName ?? this.sourceFileName,
      underlayFileName: underlayFileName ?? this.underlayFileName,
      controlPoint: clearControlPoint ? null : (controlPoint ?? this.controlPoint),
      unitScale: unitScale ?? this.unitScale,
      layerVisibility: layerVisibility ?? Map<String, bool>.from(this.layerVisibility),
      wallsDetected: wallsDetected ?? this.wallsDetected,
    );
  }

  Map<String, dynamic> toJson() => {
    'storeyId': storeyId,
    'name': name,
    'elevation': elevation,
    'height': height,
    if (sourceFileName != null) 'sourceFileName': sourceFileName,
    if (underlayFileName != null) 'underlayFileName': underlayFileName,
    if (controlPoint != null)
      'controlPoint': [controlPoint!.dx, controlPoint!.dy],
    'unitScale': unitScale,
    'layerVisibility': layerVisibility,
    'wallsDetected': wallsDetected,
  };

  factory BimStoreyUnderlay.fromJson(Map<String, dynamic> json) {
    Offset? cp;
    final cpList = json['controlPoint'];
    if (cpList is List && cpList.length >= 2) {
      final x = (cpList[0] as num).toDouble();
      final y = (cpList[1] as num).toDouble();
      cp = Offset(x, y);
    }

    final lvRaw = json['layerVisibility'];
    final lv = <String, bool>{};
    if (lvRaw is Map) {
      for (final entry in lvRaw.entries) {
        lv[entry.key.toString()] = entry.value == true;
      }
    }

    return BimStoreyUnderlay(
      storeyId: json['storeyId'] as String? ?? 'storey_1',
      name: json['name'] as String? ?? 'Storey 1',
      elevation: (json['elevation'] as num?)?.toDouble() ?? 0.0,
      height: (json['height'] as num?)?.toDouble() ?? 2.80,
      sourceFileName: json['sourceFileName'] as String?,
      underlayFileName: json['underlayFileName'] as String?,
      controlPoint: cp,
      unitScale: (json['unitScale'] as num?)?.toDouble() ?? 1.0,
      layerVisibility: lv,
      wallsDetected: json['wallsDetected'] as bool? ?? false,
    );
  }
}

/// Represents a standalone BiM work project with multiple storeys,
/// floor underlays, and structural drawings.
class BimWorkProject {
  final String id;
  final String name;
  final String location;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<BimStoreyUnderlay> storeys;
  final bool alignmentConfirmed;
  final String? referenceStoreyId;

  const BimWorkProject({
    required this.id,
    required this.name,
    this.location = '',
    required this.createdAt,
    required this.updatedAt,
    this.storeys = const [],
    this.alignmentConfirmed = false,
    this.referenceStoreyId,
  });

  /// True when all storeys that have an underlay attached also have their control point set.
  bool get allControlPointsPlaced {
    final withUnderlays = storeys.where((s) => s.hasUnderlay).toList();
    if (withUnderlays.isEmpty) return false;
    return withUnderlays.every((s) => s.isControlPointSet);
  }

  /// Whether alignment has been confirmed by the user.
  bool get isAligned => alignmentConfirmed;

  bool get hasAnyUnderlay => storeys.any((s) => s.hasUnderlay);

  int get underlaysCount => storeys.where((s) => s.hasUnderlay).length;

  int get basementCount => storeys.where((s) => s.elevation < -0.01).length;

  int get aboveGroundCount => storeys.where((s) => s.elevation >= -0.01).length;

  /// Returns the reference storey (where cp_ref is sourced from).
  /// Falls back to the lowest non-basement storey with an underlay, or the first storey with an underlay.
  BimStoreyUnderlay? get referenceStorey {
    if (referenceStoreyId != null) {
      for (final s in storeys) {
        if (s.storeyId == referenceStoreyId && s.hasUnderlay) return s;
      }
    }
    // Prefer elevation near 0.00 with underlay
    for (final s in storeys) {
      if (s.elevation.abs() < 0.01 && s.hasUnderlay && s.isControlPointSet) return s;
    }
    // Next prefer any non-basement with underlay & control point
    for (final s in storeys) {
      if (s.elevation >= -0.01 && s.hasUnderlay && s.isControlPointSet) return s;
    }
    // Any with underlay & control point
    for (final s in storeys) {
      if (s.hasUnderlay && s.isControlPointSet) return s;
    }
    // Any with underlay
    for (final s in storeys) {
      if (s.hasUnderlay) return s;
    }
    return storeys.isNotEmpty ? storeys.first : null;
  }

  BimWorkProject copyWith({
    String? id,
    String? name,
    String? location,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<BimStoreyUnderlay>? storeys,
    bool? alignmentConfirmed,
    String? referenceStoreyId,
  }) {
    return BimWorkProject(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      storeys: storeys ?? List<BimStoreyUnderlay>.from(this.storeys),
      alignmentConfirmed: alignmentConfirmed ?? this.alignmentConfirmed,
      referenceStoreyId: referenceStoreyId ?? this.referenceStoreyId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'location': location,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'storeys': storeys.map((s) => s.toJson()).toList(),
    'alignmentConfirmed': alignmentConfirmed,
    if (referenceStoreyId != null) 'referenceStoreyId': referenceStoreyId,
  };

  factory BimWorkProject.fromJson(Map<String, dynamic> json) {
    final storeysRaw = json['storeys'] as List<dynamic>? ?? [];
    final storeysList = storeysRaw
        .map((s) => BimStoreyUnderlay.fromJson(s as Map<String, dynamic>))
        .toList();

    return BimWorkProject(
      id: json['id'] as String? ?? 'proj_${DateTime.now().millisecondsSinceEpoch}',
      name: json['name'] as String? ?? 'BiM Project',
      location: json['location'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      storeys: storeysList,
      alignmentConfirmed: json['alignmentConfirmed'] as bool? ?? false,
      referenceStoreyId: json['referenceStoreyId'] as String?,
    );
  }
}
