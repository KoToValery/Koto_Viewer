import 'dart:ui';

enum ArchitectGutterProfile { halfRound, box }

enum ArchitectDrainageMaterial { galvanizedSteel, aluminium, pvc, copper }

class ArchitectDownpipe {
  final String id;

  /// Metres from the start of the effective low eaves, retained on roof edits.
  final double offset;
  final double diameter, wallClearance, bendAngle, outletElevation;
  final String? facadeWallId;
  final bool visible;

  /// Optional intermediate points: inward distance from outlet / world Z.
  final List<Offset> waypoints;
  const ArchitectDownpipe({
    required this.id,
    this.offset = .3,
    this.diameter = .10,
    this.wallClearance = .05,
    this.bendAngle = 45,
    this.outletElevation = .15,
    this.facadeWallId,
    this.visible = true,
    this.waypoints = const [],
  });
  ArchitectDownpipe copyWith({
    double? offset,
    double? diameter,
    double? wallClearance,
    double? bendAngle,
    double? outletElevation,
    String? facadeWallId,
    bool clearFacade = false,
    bool? visible,
    List<Offset>? waypoints,
  }) => ArchitectDownpipe(
    id: id,
    offset: offset ?? this.offset,
    diameter: diameter ?? this.diameter,
    wallClearance: wallClearance ?? this.wallClearance,
    bendAngle: bendAngle ?? this.bendAngle,
    outletElevation: outletElevation ?? this.outletElevation,
    facadeWallId: clearFacade ? null : facadeWallId ?? this.facadeWallId,
    visible: visible ?? this.visible,
    waypoints: waypoints ?? this.waypoints,
  );
  void validate() {
    if (id.trim().isEmpty ||
        !offset.isFinite ||
        offset < 0 ||
        !diameter.isFinite ||
        diameter < .04 ||
        diameter > .4 ||
        !wallClearance.isFinite ||
        wallClearance < .01 ||
        wallClearance > 1 ||
        ![45.0, 67.5].contains(bendAngle) ||
        !outletElevation.isFinite ||
        waypoints.any((p) => !p.dx.isFinite || !p.dy.isFinite)) {
      throw ArgumentError('Invalid downpipe');
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'offset': offset,
    'diameter': diameter,
    'wallClearance': wallClearance,
    'bendAngle': bendAngle,
    'outletElevation': outletElevation,
    'facadeWallId': facadeWallId,
    'visible': visible,
    'waypoints': [
      for (final p in waypoints) [p.dx, p.dy],
    ],
  };
  factory ArchitectDownpipe.fromJson(Map json) => ArchitectDownpipe(
    id: json['id'] as String,
    offset: _number(json['offset'], .3),
    diameter: _number(json['diameter'], .1),
    wallClearance: _number(json['wallClearance'], .05),
    bendAngle: _number(json['bendAngle'], 45),
    outletElevation: _number(json['outletElevation'], .15),
    facadeWallId: json['facadeWallId'] as String?,
    visible: json['visible'] != false,
    waypoints: [
      for (final p in json['waypoints'] as List? ?? [])
        Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
    ],
  );
}

class ArchitectRoofDrainage {
  final bool showGutter, showDownpipes;
  final ArchitectGutterProfile profile;
  final ArchitectDrainageMaterial material;
  final double gutterWidth, gutterDepth;
  final List<ArchitectDownpipe> downpipes;
  const ArchitectRoofDrainage({
    this.showGutter = false,
    this.showDownpipes = true,
    this.profile = ArchitectGutterProfile.halfRound,
    this.material = ArchitectDrainageMaterial.galvanizedSteel,
    this.gutterWidth = .15,
    this.gutterDepth = .09,
    this.downpipes = const [],
  });
  ArchitectRoofDrainage copyWith({
    bool? showGutter,
    bool? showDownpipes,
    ArchitectGutterProfile? profile,
    ArchitectDrainageMaterial? material,
    double? gutterWidth,
    double? gutterDepth,
    List<ArchitectDownpipe>? downpipes,
  }) => ArchitectRoofDrainage(
    showGutter: showGutter ?? this.showGutter,
    showDownpipes: showDownpipes ?? this.showDownpipes,
    profile: profile ?? this.profile,
    material: material ?? this.material,
    gutterWidth: gutterWidth ?? this.gutterWidth,
    gutterDepth: gutterDepth ?? this.gutterDepth,
    downpipes: downpipes ?? this.downpipes,
  );
  void validate() {
    if (!gutterWidth.isFinite ||
        gutterWidth < .08 ||
        gutterWidth > .5 ||
        !gutterDepth.isFinite ||
        gutterDepth < .04 ||
        gutterDepth > .3 ||
        downpipes.map((p) => p.id).toSet().length != downpipes.length) {
      throw ArgumentError('Invalid roof drainage');
    }
    for (final pipe in downpipes) {
      pipe.validate();
    }
  }

  Map<String, dynamic> toJson() => {
    'showGutter': showGutter,
    'showDownpipes': showDownpipes,
    'profile': profile.name,
    'material': material.name,
    'gutterWidth': gutterWidth,
    'gutterDepth': gutterDepth,
    'downpipes': [for (final p in downpipes) p.toJson()],
  };
  factory ArchitectRoofDrainage.fromJson(Map json) => ArchitectRoofDrainage(
    showGutter: json['showGutter'] == true,
    showDownpipes: json['showDownpipes'] != false,
    profile:
        ArchitectGutterProfile.values
            .where((v) => v.name == json['profile'])
            .firstOrNull ??
        ArchitectGutterProfile.halfRound,
    material:
        ArchitectDrainageMaterial.values
            .where((v) => v.name == json['material'])
            .firstOrNull ??
        ArchitectDrainageMaterial.galvanizedSteel,
    gutterWidth: _number(json['gutterWidth'], .15),
    gutterDepth: _number(json['gutterDepth'], .09),
    downpipes: [
      for (final p in json['downpipes'] as List? ?? [])
        ArchitectDownpipe.fromJson(p as Map),
    ],
  );
}

double _number(Object? value, double fallback) =>
    value is num && value.isFinite ? value.toDouble() : fallback;
