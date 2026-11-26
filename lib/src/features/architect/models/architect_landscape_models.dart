// === SECTION: ARCHITECT LANDSCAPING, TERRAIN, PATHWAYS, VEGETATION & SITE FENCE MODELS ===

import 'dart:math' as math;
import 'dart:ui';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../bim_editing/properties/bim_distance_unit.dart';
import '../services/architect_spline_geometry.dart';
import '../services/architect_terrain_tin.dart';
import 'architect_underlay_models.dart';

/// Elevation and contour-interval display unit for terrain:
/// uses meters for all metric projects (m/cm/mm) and feet for imperial projects (ft/in).
BimDistanceUnit terrainElevationUnit(
  BimDistanceUnit projectUnits, [
  BimDistanceUnit? levelUnits,
]) =>
    ((levelUnits?.isImperial ?? false) || projectUnits.isImperial)
        ? BimDistanceUnit.feet
        : BimDistanceUnit.meters;

/// State of the terrain surface: natural existing grade vs. graded proposed design.
enum ArchitectTerrainState {
  existing,
  proposed;

  String label(AppLocalizations l) => switch (this) {
    existing => l.architectTerrainStateExisting,
    proposed => l.architectTerrainStateProposed,
  };

  String fullLabel(AppLocalizations l) => switch (this) {
    existing => l.architectTerrainStateExistingFull,
    proposed => l.architectTerrainStateProposedFull,
  };
}

/// Sub-mode when drafting or editing terrain in 2D Plan.
enum ArchitectTerrainDraftMode {
  boundary,
  boundaryRect,
  pickContour,
  contour,
  spot,
  pad,
  hole;

  String label(AppLocalizations l) => switch (this) {
    boundary => l.architectTerrainModeBoundary,
    boundaryRect => l.architectTerrainModeBoundaryRect,
    pickContour => l.architectTerrainModePickContour,
    contour => l.architectTerrainModeContour,
    spot => l.architectTerrainModeSpot,
    pad => l.architectTerrainModePad,
    hole => l.architectTerrainModeHole,
  };
}

/// How the outer perimeter of a proposed terrain zone or flat grading pad joins
/// the surrounding existing terrain surface.
enum ArchitectTerrainEdgeTransition {
  /// Boundary perimeter automatically inherits exact elevation from existing terrain.
  matchExisting,

  /// Sloped embankment/cut batter (1:H horizontal:vertical) out to daylight on existing terrain.
  slope,

  /// Vertical retaining step/wall between proposed and existing elevations along the perimeter.
  retainingWall;

  String label(AppLocalizations l) => switch (this) {
    matchExisting => l.architectTerrainEdgeMatchExisting,
    slope => l.architectTerrainEdgeSlope,
    retainingWall => l.architectTerrainEdgeRetainingWall,
  };
}

/// Closed boundary, cutout hole, or flat grading pad polygon in a 2.5D terrain surface.
class ArchitectTerrainBoundary {
  final String id;
  final List<Offset> polygon;
  final double elevation;
  final List<double>? vertexElevations;
  final bool isFlatPad;
  final bool isHole;
  final bool autoInterpolateElevation;
  final ArchitectTerrainEdgeTransition? edgeTransition;
  final double slopeRatio;
  final String? hostBoundaryId;

  const ArchitectTerrainBoundary({
    required this.id,
    required this.polygon,
    this.elevation = 0.0,
    this.vertexElevations,
    bool isFlatPad = false,
    bool? isCutoutPad,
    this.isHole = false,
    this.autoInterpolateElevation = false,
    this.edgeTransition,
    this.slopeRatio = 1.5,
    this.hostBoundaryId,
  }) : isFlatPad = isCutoutPad ?? isFlatPad;

  bool get isCutoutPad => isHole || isFlatPad;

  /// Effective edge transition: Flat pads and explicit-elevation boundaries
  /// default to vertical retaining step (with option to switch to batter slope),
  /// while auto-interpolated outer boundaries match existing terrain.
  ArchitectTerrainEdgeTransition get effectiveEdgeTransition =>
      edgeTransition ??
      ((isFlatPad || !autoInterpolateElevation)
          ? ArchitectTerrainEdgeTransition.retainingWall
          : ArchitectTerrainEdgeTransition.matchExisting);

  double vertexElevationAt(int index) {
    if (vertexElevations != null &&
        index >= 0 &&
        index < vertexElevations!.length) {
      return vertexElevations![index];
    }
    return elevation;
  }

  Rect get bounds {
    if (polygon.isEmpty) return Rect.zero;
    var minX = polygon.first.dx, maxX = polygon.first.dx;
    var minY = polygon.first.dy, maxY = polygon.first.dy;
    for (final p in polygon.skip(1)) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  bool containsPoint(Offset point) {
    if (polygon.length < 3 || !bounds.inflate(0.05).contains(point)) {
      return false;
    }
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final pi = polygon[i], pj = polygon[j];
      if (((pi.dy > point.dy) != (pj.dy > point.dy)) &&
          (point.dx <
              (pj.dx - pi.dx) * (point.dy - pi.dy) / (pj.dy - pi.dy + 1e-12) +
                  pi.dx)) {
        inside = !inside;
      }
    }
    return inside;
  }

  ArchitectTerrainBoundary copyWith({
    String? id,
    List<Offset>? polygon,
    double? elevation,
    List<double>? vertexElevations,
    bool? isFlatPad,
    bool? isHole,
    bool? autoInterpolateElevation,
    ArchitectTerrainEdgeTransition? edgeTransition,
    double? slopeRatio,
    String? hostBoundaryId,
  }) => ArchitectTerrainBoundary(
    id: id ?? this.id,
    polygon: polygon ?? this.polygon,
    elevation: elevation ?? this.elevation,
    vertexElevations: vertexElevations ?? this.vertexElevations,
    isFlatPad: isFlatPad ?? this.isFlatPad,
    isHole: isHole ?? this.isHole,
    autoInterpolateElevation:
        autoInterpolateElevation ?? this.autoInterpolateElevation,
    edgeTransition: edgeTransition ?? this.edgeTransition,
    slopeRatio: slopeRatio ?? this.slopeRatio,
    hostBoundaryId: hostBoundaryId ?? this.hostBoundaryId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'polygon': [
      for (final p in polygon) {'x': p.dx, 'y': p.dy},
    ],
    'elevation': elevation,
    if (vertexElevations != null) 'vertexElevations': vertexElevations,
    if (isFlatPad) 'isFlatPad': true,
    if (isHole) 'isHole': true,
    if (autoInterpolateElevation) 'autoInterpolateElevation': true,
    if (edgeTransition != null) 'edgeTransition': edgeTransition!.name,
    if ((slopeRatio - 1.5).abs() > 1e-4) 'slopeRatio': slopeRatio,
    if (hostBoundaryId != null) 'hostBoundaryId': hostBoundaryId,
  };

  factory ArchitectTerrainBoundary.fromJson(Map<String, dynamic> json) =>
      ArchitectTerrainBoundary(
        id: json['id'] as String? ?? 'terr_bnd_0',
        polygon: [
          for (final p in json['polygon'] as List? ?? const [])
            if (p is Map)
              Offset(
                (p['x'] as num?)?.toDouble() ?? 0.0,
                (p['y'] as num?)?.toDouble() ?? 0.0,
              ),
        ],
        elevation: (json['elevation'] as num?)?.toDouble() ?? 0.0,
        vertexElevations: (json['vertexElevations'] as List?)
            ?.map((e) => (e as num).toDouble())
            .toList(),
        isFlatPad: json['isFlatPad'] == true,
        isHole: json['isHole'] == true,
        autoInterpolateElevation: json['autoInterpolateElevation'] == true,
        edgeTransition: json['edgeTransition'] is String
            ? ArchitectTerrainEdgeTransition.values
                .where((e) => e.name == json['edgeTransition'])
                .firstOrNull
            : null,
        slopeRatio: ((json['slopeRatio'] as num?)?.toDouble() ?? 1.5).clamp(
          0.1,
          20.0,
        ),
        hostBoundaryId: json['hostBoundaryId'] as String?,
      );
}

/// Topographic contour line (хоризонтал) with a constant elevation Z.
class ArchitectTerrainContour {
  final String id;
  final List<Offset> points;
  final double elevation;
  final double? rawAbsoluteElevation;
  final bool closed;
  final bool isMajor;
  final bool isSpline;
  final String? hostBoundaryId;

  const ArchitectTerrainContour({
    required this.id,
    required this.points,
    required this.elevation,
    this.rawAbsoluteElevation,
    this.closed = false,
    this.isMajor = false,
    this.isSpline = false,
    this.hostBoundaryId,
  });

  /// Returns exact 1:1 points for CAD-extracted contours, or sampled Catmull-Rom
  /// spline points for manually drafted contours.
  List<Offset> resolvedPolyline({int samplesPerSpan = 10}) =>
      isSpline && points.length >= 3
      ? ArchitectSplineGeometry.samplePoints(
          points,
          closed: closed,
          samplesPerSpan: samplesPerSpan,
        )
      : points;

  double effectiveAbsolute(double datum) =>
      rawAbsoluteElevation ?? (elevation + datum);

  double effectiveRelative(double datum) =>
      rawAbsoluteElevation != null ? (rawAbsoluteElevation! - datum) : elevation;

  ArchitectTerrainContour copyWith({
    String? id,
    List<Offset>? points,
    double? elevation,
    double? rawAbsoluteElevation,
    bool? closed,
    bool? isMajor,
    bool? isSpline,
    String? hostBoundaryId,
  }) => ArchitectTerrainContour(
    id: id ?? this.id,
    points: points ?? this.points,
    elevation: elevation ?? this.elevation,
    rawAbsoluteElevation: rawAbsoluteElevation ?? this.rawAbsoluteElevation,
    closed: closed ?? this.closed,
    isMajor: isMajor ?? this.isMajor,
    isSpline: isSpline ?? this.isSpline,
    hostBoundaryId: hostBoundaryId ?? this.hostBoundaryId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'points': [
      for (final p in points) {'x': p.dx, 'y': p.dy},
    ],
    'elevation': elevation,
    if (rawAbsoluteElevation != null)
      'rawAbsoluteElevation': rawAbsoluteElevation,
    if (closed) 'closed': true,
    if (isMajor) 'isMajor': true,
    if (isSpline) 'isSpline': true,
    if (hostBoundaryId != null) 'hostBoundaryId': hostBoundaryId,
  };

  factory ArchitectTerrainContour.fromJson(Map<String, dynamic> json) =>
      ArchitectTerrainContour(
        id: json['id'] as String? ?? 'terr_cnt_0',
        points: [
          for (final p in json['points'] as List? ?? const [])
            if (p is Map)
              Offset(
                (p['x'] as num?)?.toDouble() ?? 0.0,
                (p['y'] as num?)?.toDouble() ?? 0.0,
              ),
        ],
        elevation: (json['elevation'] as num?)?.toDouble() ?? 0.0,
        rawAbsoluteElevation:
            (json['rawAbsoluteElevation'] as num?)?.toDouble(),
        closed: json['closed'] == true,
        isMajor: json['isMajor'] == true,
        isSpline: json['isSpline'] == true,
        hostBoundaryId: json['hostBoundaryId'] as String?,
      );
}

/// Spot elevation point (височинна кота / пикет) at a specific 2D position.
class ArchitectTerrainSpot {
  final String id;
  final Offset position;
  final double elevation;
  final double? rawAbsoluteElevation;
  final String? hostBoundaryId;

  const ArchitectTerrainSpot({
    required this.id,
    required this.position,
    required this.elevation,
    this.rawAbsoluteElevation,
    this.hostBoundaryId,
  });

  double effectiveAbsolute(double datum) =>
      rawAbsoluteElevation ?? (elevation + datum);

  double effectiveRelative(double datum) =>
      rawAbsoluteElevation != null ? (rawAbsoluteElevation! - datum) : elevation;

  ArchitectTerrainSpot copyWith({
    String? id,
    Offset? position,
    double? elevation,
    double? rawAbsoluteElevation,
    String? hostBoundaryId,
  }) => ArchitectTerrainSpot(
    id: id ?? this.id,
    position: position ?? this.position,
    elevation: elevation ?? this.elevation,
    rawAbsoluteElevation: rawAbsoluteElevation ?? this.rawAbsoluteElevation,
    hostBoundaryId: hostBoundaryId ?? this.hostBoundaryId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'position': {'x': position.dx, 'y': position.dy},
    'elevation': elevation,
    if (rawAbsoluteElevation != null)
      'rawAbsoluteElevation': rawAbsoluteElevation,
    if (hostBoundaryId != null) 'hostBoundaryId': hostBoundaryId,
  };

  factory ArchitectTerrainSpot.fromJson(Map<String, dynamic> json) {
    final pos = json['position'] as Map<String, dynamic>?;
    return ArchitectTerrainSpot(
      id: json['id'] as String? ?? 'terr_spot_0',
      position: pos != null
          ? Offset(
              (pos['x'] as num?)?.toDouble() ?? 0.0,
              (pos['y'] as num?)?.toDouble() ?? 0.0,
            )
          : Offset.zero,
      elevation: (json['elevation'] as num?)?.toDouble() ?? 0.0,
      rawAbsoluteElevation:
          (json['rawAbsoluteElevation'] as num?)?.toDouble(),
      hostBoundaryId: json['hostBoundaryId'] as String?,
    );
  }
}

/// Lightweight 2.5D Parametric Topographic Surface for either Existing or Proposed terrain.
///
/// Designed for mobile-first performance:
/// - Evaluates elevation $Z(x,y)$ analytically without heavy 3D mesh raycasting.
/// - Slices 1D section/elevation profiles in $< 0.5\text{ ms}$.
class ArchitectTerrainSurface {
  final String id;
  final ArchitectTerrainState state;
  final double datumElevation;
  final double contourInterval;
  final bool contourIntervalManual;
  final List<ArchitectTerrainBoundary> boundaries;
  final List<ArchitectTerrainContour> contours;
  final List<ArchitectTerrainSpot> spots;

  const ArchitectTerrainSurface({
    this.id = 'terrain_surface',
    this.state = ArchitectTerrainState.existing,
    this.datumElevation = 0.0,
    this.contourInterval = 0.0,
    this.contourIntervalManual = false,
    this.boundaries = const [],
    this.contours = const [],
    this.spots = const [],
  });

  double toRelativeElevation(double absZ) => absZ - datumElevation;
  double toAbsoluteElevation(double relZ) => relZ + datumElevation;

  bool get isEmpty =>
      boundaries.isEmpty && contours.isEmpty && spots.isEmpty;

  bool get isNotEmpty => !isEmpty;

  bool get hasOuterBoundary => boundaries.any(
    (b) => b.polygon.length >= 3 && !b.isFlatPad && !b.isHole,
  );

  List<ArchitectTerrainBoundary> get outerBoundaries => [
    for (final b in boundaries)
      if (!b.isHole && !b.isFlatPad && b.polygon.length >= 3) b,
  ];

  /// Resolves the hosting outer terrain boundary ID for [point], returning the
  /// enclosing boundary (or sole outer boundary when only one exists).
  String? resolveHostBoundaryIdForPoint(Offset point) {
    final outers = outerBoundaries;
    for (final b in outers.reversed) {
      if (b.containsPoint(point)) return b.id;
    }
    return outers.length == 1 ? outers.single.id : null;
  }

  /// Resolves the hosting outer terrain boundary ID for a polyline/polygon chain.
  String? resolveHostBoundaryIdForPoints(List<Offset> points) {
    final outers = outerBoundaries;
    if (outers.isEmpty) return null;
    for (final b in outers.reversed) {
      for (var i = 0; i < points.length; i++) {
        if (b.containsPoint(points[i])) return b.id;
        if (i + 1 < points.length &&
            b.containsPoint((points[i] + points[i + 1]) * 0.5)) {
          return b.id;
        }
      }
    }
    return outers.length == 1 ? outers.single.id : null;
  }

  bool _belongsToOuter(
    String? explicitHostId,
    List<Offset> pts,
    ArchitectTerrainBoundary outer,
    List<ArchitectTerrainBoundary> outers,
  ) {
    if (explicitHostId != null) return explicitHostId == outer.id;
    if (outers.length == 1 && outers.single.id == outer.id) return true;
    return pts.any(outer.containsPoint);
  }

  /// Returns [boundaryId] plus all linked child members (contours, spots,
  /// flat pads, cutout holes) when [boundaryId] is a terrain boundary.
  Set<String> memberIdsForBoundary(String boundaryId) {
    final target = boundaries.where((b) => b.id == boundaryId).firstOrNull;
    if (target == null) return {boundaryId};
    if (target.isHole) {
      return {
        boundaryId,
        for (final s in spots)
          if (s.hostBoundaryId == boundaryId || s.id.startsWith('${boundaryId}_pt_'))
            s.id,
      };
    }
    if (target.isFlatPad) {
      return {
        boundaryId,
        for (final s in spots)
          if (s.hostBoundaryId == boundaryId) s.id,
      };
    }
    final outers = outerBoundaries;
    final childBoundaryIds = <String>{
      for (final b in boundaries)
        if (b.id != boundaryId &&
            (b.isHole || b.isFlatPad) &&
            _belongsToOuter(b.hostBoundaryId, b.polygon, target, outers))
          b.id,
    };
    return {
      boundaryId,
      ...childBoundaryIds,
      for (final c in contours)
        if (_belongsToOuter(c.hostBoundaryId, c.points, target, outers)) c.id,
      for (final s in spots)
        if (_belongsToOuter(s.hostBoundaryId, [s.position], target, outers) ||
            childBoundaryIds.contains(s.hostBoundaryId) ||
            childBoundaryIds.any((hid) => s.id.startsWith('${hid}_pt_')))
          s.id,
    };
  }

  /// Expands any terrain boundary IDs in [ids] into their full linked assemblies.
  Set<String> expandMemberIds(Iterable<String> ids) {
    final result = <String>{};
    for (final id in ids) {
      if (boundaries.any((b) => b.id == id)) {
        result.addAll(memberIdsForBoundary(id));
      } else {
        result.add(id);
      }
    }
    return result;
  }

  /// Links unowned contours, spots, pads, and holes enclosed by a newly added
  /// [outerBoundary] (or all unowned items if it is the sole outer boundary).
  ArchitectTerrainSurface adoptingUnlinkedMembersFor(
    ArchitectTerrainBoundary outerBoundary,
  ) {
    final outers = outerBoundaries;
    final isSoleOuter =
        outers.length == 1 && outers.single.id == outerBoundary.id;
    bool adoptsPoints(List<Offset> pts) =>
        isSoleOuter || pts.any(outerBoundary.containsPoint);
    return copyWith(
      boundaries: [
        for (final b in boundaries)
          if (b.id != outerBoundary.id &&
              b.hostBoundaryId == null &&
              (b.isHole || b.isFlatPad) &&
              adoptsPoints(b.polygon))
            b.copyWith(hostBoundaryId: outerBoundary.id)
          else
            b,
      ],
      contours: [
        for (final c in contours)
          if (c.hostBoundaryId == null && adoptsPoints(c.points))
            c.copyWith(hostBoundaryId: outerBoundary.id)
          else
            c,
      ],
      spots: [
        for (final s in spots)
          if (s.hostBoundaryId == null && adoptsPoints([s.position]))
            s.copyWith(hostBoundaryId: outerBoundary.id)
          else
            s,
      ],
    );
  }

  /// Translates every boundary, contour, and spot matching [ids] by [delta].
  ArchitectTerrainSurface translatedMembers(Set<String> ids, Offset delta) {
    if (ids.isEmpty || delta == Offset.zero) return this;
    return copyWith(
      boundaries: [
        for (final b in boundaries)
          ids.contains(b.id)
              ? b.copyWith(polygon: [for (final p in b.polygon) p + delta])
              : b,
      ],
      contours: [
        for (final c in contours)
          ids.contains(c.id)
              ? c.copyWith(points: [for (final p in c.points) p + delta])
              : c,
      ],
      spots: [
        for (final s in spots)
          ids.contains(s.id) ? s.copyWith(position: s.position + delta) : s,
      ],
    );
  }

  /// Updates the building ±0.00 datum (in absolute survey meters) and
  /// recalculates relative elevations of all contours and spots.
  ArchitectTerrainSurface withDatumElevation(double newDatum) {
    return copyWith(
      datumElevation: newDatum,
      contours: [
        for (final c in contours)
          () {
            final absZ = c.effectiveAbsolute(datumElevation);
            return c.copyWith(
              rawAbsoluteElevation: absZ,
              elevation: double.parse((absZ - newDatum).toStringAsFixed(4)),
            );
          }(),
      ],
      spots: [
        for (final s in spots)
          () {
            final absZ = s.effectiveAbsolute(datumElevation);
            return s.copyWith(
              rawAbsoluteElevation: absZ,
              elevation: double.parse((absZ - newDatum).toStringAsFixed(4)),
            );
          }(),
      ],
    );
  }

  /// Clones this surface as a Proposed terrain with independent element IDs,
  /// preserving parent-child [hostBoundaryId] references.
  ArchitectTerrainSurface cloneAsProposed() {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final bndRemap = <String, String>{
      for (var i = 0; i < boundaries.length; i++)
        boundaries[i].id: 'prop_bnd_${stamp}_$i',
    };
    return ArchitectTerrainSurface(
      id: 'terrain_proposed',
      state: ArchitectTerrainState.proposed,
      datumElevation: datumElevation,
      contourInterval: contourInterval,
      contourIntervalManual: contourIntervalManual,
      boundaries: [
        for (var i = 0; i < boundaries.length; i++)
          boundaries[i].copyWith(
            id: bndRemap[boundaries[i].id],
            hostBoundaryId: boundaries[i].hostBoundaryId == null
                ? null
                : (bndRemap[boundaries[i].hostBoundaryId] ??
                      boundaries[i].hostBoundaryId),
          ),
      ],
      contours: [
        for (var i = 0; i < contours.length; i++)
          contours[i].copyWith(
            id: 'prop_cnt_${stamp}_$i',
            hostBoundaryId: contours[i].hostBoundaryId == null
                ? null
                : (bndRemap[contours[i].hostBoundaryId] ??
                      contours[i].hostBoundaryId),
          ),
      ],
      spots: [
        for (var i = 0; i < spots.length; i++)
          spots[i].copyWith(
            id: 'prop_spot_${stamp}_$i',
            hostBoundaryId: spots[i].hostBoundaryId == null
                ? null
                : (bndRemap[spots[i].hostBoundaryId] ??
                      spots[i].hostBoundaryId),
          ),
      ],
    );
  }

  /// Creates editable spot elevations ([ArchitectTerrainSpot]) at each vertex
  /// of a newly cut terrain opening so every corner exposes and controls `h`.
  List<ArchitectTerrainSpot> withHoleVertexSpots({
    required String holeId,
    required List<Offset> points,
    double fallbackRelativeElevation = 0.0,
  }) {
    final existingIds = <String>{for (final s in spots) s.id};
    final out = List<ArchitectTerrainSpot>.of(spots);
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final alreadyHasSpot = out.any(
        (s) => (s.position - p).distanceSquared < 0.02 * 0.02,
      );
      if (alreadyHasSpot) continue;
      final evaluated = evaluateElevationAt(p);
      final rel = double.parse(
        (evaluated ?? fallbackRelativeElevation).toStringAsFixed(4),
      );
      final abs = double.parse((rel + datumElevation).toStringAsFixed(4));
      var spotId = '${holeId}_pt_$i';
      var suffix = 1;
      while (existingIds.contains(spotId)) {
        spotId = '${holeId}_pt_${i}_$suffix';
        suffix++;
      }
      existingIds.add(spotId);
      out.add(
        ArchitectTerrainSpot(
          id: spotId,
          position: p,
          elevation: rel,
          rawAbsoluteElevation: abs,
          hostBoundaryId: holeId,
        ),
      );
    }
    return out;
  }

  /// Moves existing vertex spots along with their edited opening polygon corners.
  List<ArchitectTerrainSpot> syncHoleVertexSpots({
    required List<Offset> oldPolygon,
    required List<Offset> newPolygon,
  }) {
    if (oldPolygon.length != newPolygon.length) return spots;
    final movedIndices = <int>[
      for (var i = 0; i < oldPolygon.length; i++)
        if ((oldPolygon[i] - newPolygon[i]).distanceSquared > 1e-10) i,
    ];
    if (movedIndices.isEmpty) return spots;
    return [
      for (final s in spots)
        () {
          for (final i in movedIndices) {
            if ((s.position - oldPolygon[i]).distanceSquared < 0.02 * 0.02) {
              return s.copyWith(position: newPolygon[i]);
            }
          }
          return s;
        }(),
    ];
  }

  /// Appends a single editable spot for an inserted vertex on a terrain hole.
  List<ArchitectTerrainSpot> appendSpotForInsertedPoint({
    required String spotId,
    required Offset insertion,
    double fallbackRelativeElevation = 0.0,
    String? hostBoundaryId,
  }) {
    if (spots.any((s) => (s.position - insertion).distanceSquared < 0.02 * 0.02)) {
      return spots;
    }
    final evaluated = evaluateElevationAt(insertion);
    final rel = double.parse(
      (evaluated ?? fallbackRelativeElevation).toStringAsFixed(4),
    );
    final abs = double.parse((rel + datumElevation).toStringAsFixed(4));
    final existingIds = {for (final s in spots) s.id};
    var resolvedId = spotId;
    var suffix = 1;
    while (existingIds.contains(resolvedId)) {
      resolvedId = '${spotId}_$suffix';
      suffix++;
    }
    return [
      ...spots,
      ArchitectTerrainSpot(
        id: resolvedId,
        position: insertion,
        elevation: rel,
        rawAbsoluteElevation: abs,
        hostBoundaryId: hostBoundaryId,
      ),
    ];
  }

  Rect? get bounds {
    Rect? result;
    void include(Offset p) {
      final r = Rect.fromPoints(p, p);
      result = result?.expandToInclude(r) ?? r;
    }

    for (final b in boundaries) {
      for (final p in b.polygon) {
        include(p);
      }
    }
    for (final c in contours) {
      for (final p in c.points) {
        include(p);
      }
    }
    for (final s in spots) {
      include(s.position);
    }
    return result;
  }

  /// Creates an [ArchitectTerrainSurface] from an imported [ArchitectGeodeticSurvey] (`G-TOPO`).
  /// Automatically normalizes absolute sea-level elevations (e.g. 542.50 m) relative to
  /// [survey.buildingZeroElevation] (or median survey elevation if building zero is not set)
  /// so the terrain aligns naturally with the building's ±0.00 datum.
  factory ArchitectTerrainSurface.fromGeodeticSurvey(
    ArchitectGeodeticSurvey survey, {
    ArchitectTerrainState state = ArchitectTerrainState.existing,
  }) {
    if (survey.contours.isEmpty && survey.spotElevations.isEmpty) {
      return ArchitectTerrainSurface(
        id: state == ArchitectTerrainState.existing
            ? 'terrain_existing'
            : 'terrain_proposed',
        state: state,
      );
    }
    final allZ = <double>[
      for (final c in survey.contours) c.elevation,
      for (final p in survey.spotElevations) p.elevation,
    ]..sort();
    final medianZ = allZ[allZ.length ~/ 2];
    final datumZ =
        survey.buildingZeroElevation ?? (medianZ.abs() > 25.0 ? medianZ : 0.0);

    return ArchitectTerrainSurface(
      id: state == ArchitectTerrainState.existing
          ? 'terrain_existing'
          : 'terrain_proposed',
      state: state,
      datumElevation: datumZ,
      contours: [
        for (final c in survey.contours)
          if (c.points.length >= 2)
            ArchitectTerrainContour(
              id: 'terr_${c.id}',
              points: c.points,
              elevation: double.parse((c.elevation - datumZ).toStringAsFixed(3)),
              rawAbsoluteElevation: c.elevation,
              closed: c.closed,
              isMajor: c.isMajor,
            ),
      ],
      spots: [
        for (final p in survey.spotElevations)
          ArchitectTerrainSpot(
            id: 'terr_${p.id}',
            position: p.position,
            elevation: double.parse((p.elevation - datumZ).toStringAsFixed(3)),
            rawAbsoluteElevation: p.elevation,
          ),
      ],
    );
  }

  /// Evaluates the terrain elevation Z at [point] in model coordinates.
  /// Returns `null` if no terrain data (nor [fallbackSurvey]) exists.
  double? evaluateElevationAt(
    Offset point, {
    ArchitectGeodeticSurvey? fallbackSurvey,
  }) {
    final effective = isEmpty && fallbackSurvey != null
        ? ArchitectTerrainSurface.fromGeodeticSurvey(fallbackSurvey)
        : this;
    if (effective.isEmpty) return null;

    // 0. Check cutout holes first: point is in an excavation hole
    for (final hole in effective.boundaries.reversed) {
      if (hole.isHole && hole.containsPoint(point)) {
        return null;
      }
    }

    // 1. Check flat grading pads first (highest priority override)
    for (final pad in effective.boundaries.reversed) {
      if (pad.isFlatPad && pad.containsPoint(point)) {
        return pad.elevation;
      }
    }

    // 2. Constrained TIN barycentric interpolation (exact contours, spots & slopes)
    final tin = ArchitectTerrainTin.of(effective);
    final tinElevation = tin?.evaluateElevationAt(point);
    if (tinElevation != null) {
      return tinElevation;
    }

    // 3. Fallback IDW interpolation outside TIN or when surface has < 3 non-collinear points
    var weightedSum = 0.0;
    var weightTotal = 0.0;

    void addSample(Offset samplePos, double z, {double weightBoost = 1.0}) {
      final dSq = (point - samplePos).distanceSquared;
      if (dSq < 1e-6) {
        weightedSum = z * 1e9;
        weightTotal = 1e9;
        return;
      }
      final w = weightBoost / (dSq + 0.04);
      weightedSum += z * w;
      weightTotal += w;
    }

    for (final s in effective.spots) {
      addSample(s.position, s.effectiveRelative(effective.datumElevation), weightBoost: 2.0);
      if (weightTotal >= 1e8) return weightedSum / weightTotal;
    }

    for (final c in effective.contours) {
      final pts = c.resolvedPolyline(samplesPerSpan: 8);
      if (pts.isEmpty) continue;
      final relZ = c.effectiveRelative(effective.datumElevation);
      if (pts.length == 1) {
        addSample(pts.first, relZ, weightBoost: 1.5);
        continue;
      }
      final count = c.closed ? pts.length : pts.length - 1;
      for (var i = 0; i < count; i++) {
        final a = pts[i];
        final b = pts[(i + 1) % pts.length];
        final closest = _closestPointOnSegment(point, a, b);
        addSample(closest, relZ, weightBoost: 2.5);
        if (weightTotal >= 1e8) return weightedSum / weightTotal;
      }
    }

    final hasTopography =
        effective.contours.isNotEmpty || effective.spots.isNotEmpty;
    for (final bnd in effective.boundaries) {
      if (bnd.polygon.isEmpty) continue;
      if (hasTopography &&
          !bnd.isFlatPad &&
          !bnd.isHole &&
          bnd.autoInterpolateElevation) {
        continue;
      }
      for (var i = 0; i < bnd.polygon.length; i++) {
        final j = (i + 1) % bnd.polygon.length;
        final a = bnd.polygon[i];
        final b = bnd.polygon[j];
        final zA = bnd.vertexElevationAt(i);
        final zB = bnd.vertexElevationAt(j);
        final ab = b - a;
        final lenSq = ab.distanceSquared;
        final t = lenSq > 1e-9
            ? (((point.dx - a.dx) * ab.dx + (point.dy - a.dy) * ab.dy) / lenSq)
                  .clamp(0.0, 1.0)
            : 0.0;
        final closest = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
        final z = zA + (zB - zA) * t;
        addSample(
          closest,
          z,
          weightBoost: bnd.containsPoint(point) ? 1.5 : 0.8,
        );
        if (weightTotal >= 1e8) return weightedSum / weightTotal;
      }
    }

    if (weightTotal <= 1e-12) return null;
    return weightedSum / weightTotal;
  }

  /// Slices this 2.5D terrain along the ray from [start] to [end].
  ///
  /// - When [excludedIntervals] is empty (e.g. **Existing Terrain** in a Section, or an Elevation),
  ///   returns a single continuous polyline across the active terrain span.
  /// - When [excludedIntervals] is provided (e.g. **Proposed Terrain** in a Section where the
  ///   building footprint / underground walls & slabs occupy `[s0, s1]`), the terrain profile
  ///   terminates cleanly at the building exterior faces and resumes on the other side!
  List<List<Offset>> sliceProfileSegments(
    Offset start,
    Offset end, {
    ArchitectGeodeticSurvey? fallbackSurvey,
    List<(double, double)> excludedIntervals = const [],
    double stationShift = 0.0,
  }) {
    final effective = isEmpty && fallbackSurvey != null
        ? ArchitectTerrainSurface.fromGeodeticSurvey(fallbackSurvey)
        : this;
    if (effective.isEmpty) return const [];

    final totalLen = (end - start).distance;
    if (totalLen < 0.05) return const [];
    final dir = (end - start) / totalLen;

    // Collect station values [0, totalLen]: regular samples + exact contour/boundary intersections
    final stations = <double>{0.0, totalLen};
    final step = (totalLen / 32.0).clamp(0.25, 1.0);
    for (var s = step; s < totalLen; s += step) {
      stations.add(s);
    }

    void intersectSegment(Offset a, Offset b) {
      final hitS = _raySegmentIntersectionStation(start, dir, totalLen, a, b);
      if (hitS != null) stations.add(hitS);
    }

    for (final c in effective.contours) {
      final pts = c.resolvedPolyline(samplesPerSpan: 6);
      final count = c.closed ? pts.length : pts.length - 1;
      for (var i = 0; i < count; i++) {
        intersectSegment(pts[i], pts[(i + 1) % pts.length]);
      }
    }
    for (final b in effective.boundaries) {
      for (var i = 0; i < b.polygon.length; i++) {
        intersectSegment(b.polygon[i], b.polygon[(i + 1) % b.polygon.length]);
      }
    }
    final tinHits = ArchitectTerrainTin.of(effective)?.intersectionStations(
      start,
      end,
    );
    if (tinHits != null) {
      for (final hitPt in tinHits) {
        final s =
            (hitPt.dx - start.dx) * dir.dx + (hitPt.dy - start.dy) * dir.dy;
        if (s >= 0.0 && s <= totalLen) {
          stations.add(s);
        }
      }
    }

    // Collect combined excluded intervals: explicit building footprint + terrain cutout holes
    final combinedExcluded = <(double, double)>[...excludedIntervals];
    for (final b in effective.boundaries) {
      if (b.isHole && b.polygon.length >= 3) {
        final hitStations = <double>[];
        for (var i = 0; i < b.polygon.length; i++) {
          final hit = _raySegmentIntersectionStation(
            start,
            dir,
            totalLen,
            b.polygon[i],
            b.polygon[(i + 1) % b.polygon.length],
          );
          if (hit != null) hitStations.add(hit);
        }
        if (hitStations.length >= 2) {
          hitStations.sort();
          combinedExcluded.add((hitStations.first, hitStations.last));
        }
      }
    }

    // Add exact boundary stations of excluded intervals
    for (final iv in combinedExcluded) {
      if (iv.$1 > 0.0 && iv.$1 < totalLen) stations.add(iv.$1);
      if (iv.$2 > 0.0 && iv.$2 < totalLen) stations.add(iv.$2);
    }

    // Compute allowed intervals [a, b] after subtracting combinedExcluded
    var allowed = <(double, double)>[(0.0, totalLen)];
    for (final cut in combinedExcluded) {
      final c0 = math.max(0.0, cut.$1);
      final c1 = math.min(totalLen, cut.$2);
      if (c1 <= c0 + 1e-4) continue;
      final next = <(double, double)>[];
      for (final iv in allowed) {
        if (c1 <= iv.$1 + 1e-4 || c0 >= iv.$2 - 1e-4) {
          next.add(iv);
        } else {
          if (c0 > iv.$1 + 1e-4) next.add((iv.$1, c0));
          if (c1 < iv.$2 - 1e-4) next.add((c1, iv.$2));
        }
      }
      allowed = next;
    }

    final sortedStations = stations.toList()..sort();
    final segments = <List<Offset>>[];

    for (final span in allowed) {
      if (span.$2 - span.$1 < 0.02) continue;
      final pts = <Offset>[];
      for (final s in sortedStations) {
        if (s < span.$1 - 1e-5 || s > span.$2 + 1e-5) continue;
        final clampedS = s.clamp(span.$1, span.$2);
        if (pts.isNotEmpty &&
            (clampedS + stationShift - pts.last.dx).abs() < 1e-4) {
          continue;
        }
        final evalS = (clampedS >= span.$2 - 1e-5 && span.$2 > span.$1)
            ? (span.$2 - 1e-4)
            : ((clampedS <= span.$1 + 1e-5 && span.$1 < span.$2)
                ? (span.$1 + 1e-4)
                : clampedS);
        final worldPt = start + dir * evalS;
        final z = effective.evaluateElevationAt(worldPt);
        if (z != null) {
          pts.add(Offset(clampedS + stationShift, z));
        }
      }
      if (pts.length >= 2) {
        segments.add(pts);
      }
    }
    return segments;
  }

  static Offset _closestPointOnSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lenSq = ab.distanceSquared;
    if (lenSq < 1e-10) return a;
    final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / lenSq).clamp(
      0.0,
      1.0,
    );
    return Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
  }

  static double? _raySegmentIntersectionStation(
    Offset origin,
    Offset dir,
    double maxLen,
    Offset a,
    Offset b,
  ) {
    final v1 = origin - a;
    final v2 = b - a;
    final v3 = Offset(-dir.dy, dir.dx);
    final dot = v2.dx * v3.dx + v2.dy * v3.dy;
    if (dot.abs() < 1e-9) return null;
    final t1 = (v2.dx * v1.dy - v2.dy * v1.dx) / dot;
    final t2 = (v1.dx * v3.dx + v1.dy * v3.dy) / dot;
    if (t1 >= 0.0 && t1 <= maxLen && t2 >= 0.0 && t2 <= 1.0) {
      return t1;
    }
    return null;
  }

  ArchitectTerrainSurface copyWith({
    String? id,
    ArchitectTerrainState? state,
    double? datumElevation,
    double? contourInterval,
    bool? contourIntervalManual,
    List<ArchitectTerrainBoundary>? boundaries,
    List<ArchitectTerrainContour>? contours,
    List<ArchitectTerrainSpot>? spots,
  }) => ArchitectTerrainSurface(
    id: id ?? this.id,
    state: state ?? this.state,
    datumElevation: datumElevation ?? this.datumElevation,
    contourInterval: contourInterval ?? this.contourInterval,
    contourIntervalManual:
        contourIntervalManual ?? this.contourIntervalManual,
    boundaries: boundaries ?? this.boundaries,
    contours: contours ?? this.contours,
    spots: spots ?? this.spots,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'state': state.name,
    if (datumElevation.abs() > 1e-4) 'datumElevation': datumElevation,
    if (contourInterval > 1e-4) 'contourInterval': contourInterval,
    if (contourIntervalManual) 'contourIntervalManual': true,
    if (boundaries.isNotEmpty)
      'boundaries': boundaries.map((b) => b.toJson()).toList(),
    if (contours.isNotEmpty)
      'contours': contours.map((c) => c.toJson()).toList(),
    if (spots.isNotEmpty) 'spots': spots.map((s) => s.toJson()).toList(),
  };

  factory ArchitectTerrainSurface.fromJson(Map<String, dynamic> json) =>
      ArchitectTerrainSurface(
        id: json['id'] as String? ?? 'terrain_surface',
        state: ArchitectTerrainState.values.firstWhere(
          (s) => s.name == json['state'],
          orElse: () => ArchitectTerrainState.existing,
        ),
        datumElevation: (json['datumElevation'] as num?)?.toDouble() ?? 0.0,
        contourInterval:
            (json['contourInterval'] as num?)?.toDouble() ?? 0.0,
        contourIntervalManual: json['contourIntervalManual'] == true,
        boundaries: [
          for (final b in json['boundaries'] as List? ?? const [])
            if (b is Map)
              ArchitectTerrainBoundary.fromJson(Map<String, dynamic>.from(b)),
        ],
        contours: [
          for (final c in json['contours'] as List? ?? const [])
            if (c is Map)
              ArchitectTerrainContour.fromJson(Map<String, dynamic>.from(c)),
        ],
        spots: [
          for (final s in json['spots'] as List? ?? const [])
            if (s is Map)
              ArchitectTerrainSpot.fromJson(Map<String, dynamic>.from(s)),
        ],
      );
}

// ===========================================================================
// 2. PATHWAY WITH AUTOMATIC CURB (АЛЕЯ С АВТОМАТИЧЕН БОРДЮР)
// ===========================================================================

enum ArchitectPathwayCurbMode {
  both,
  left,
  right,
  none;

  bool get hasLeft => this == both || this == left;
  bool get hasRight => this == both || this == right;

  String label(AppLocalizations l) => switch (this) {
    both => l.architectPathwayCurbBoth,
    left => l.architectPathwayCurbLeft,
    right => l.architectPathwayCurbRight,
    none => l.architectPathwayCurbNone,
  };
}

enum ArchitectPavingMaterial {
  stoneSlabs,
  cobblePavers,
  timberDecking,
  gravel,
  asphalt,
  grassGrid;

  String label(AppLocalizations l) => switch (this) {
    stoneSlabs => l.architectPathwayMatStoneSlabs,
    cobblePavers => l.architectPathwayMatCobblePavers,
    timberDecking => l.architectPathwayMatTimberDecking,
    gravel => l.architectPathwayMatGravel,
    asphalt => l.architectPathwayMatAsphalt,
    grassGrid => l.architectPathwayMatGrassGrid,
  };

  String get hatchPatternId => switch (this) {
    stoneSlabs => 'cross',
    cobblePavers => 'brick',
    timberDecking => 'wood',
    gravel => 'gravel',
    asphalt => 'dots',
    grassGrid => 'grass',
  };
}

/// Garden / site pathway or paved plaza with automatic geometric left/right curbs.
class ArchitectPathway {
  final String id;
  final List<Offset> points;
  final bool closed;
  final double width;
  final ArchitectPathwayCurbMode curbMode;
  final double curbWidth;
  final double curbHeight;
  final double thickness;
  final double elevationOffset;
  final ArchitectPavingMaterial material;

  const ArchitectPathway({
    required this.id,
    required this.points,
    this.closed = false,
    this.width = 1.40,
    this.curbMode = ArchitectPathwayCurbMode.both,
    this.curbWidth = 0.10,
    this.curbHeight = 0.08,
    this.thickness = 0.12,
    this.elevationOffset = 0.02,
    this.material = ArchitectPavingMaterial.stoneSlabs,
  });

  /// Computes the offset polyline at signed perpendicular distance [offset]
  /// (positive = left of travel direction, negative = right of travel direction).
  static List<Offset> offsetChain(
    List<Offset> points,
    double offset, {
    bool closed = false,
  }) {
    if (points.length < 2) return List.of(points);
    if (offset.abs() < 1e-6) return List.of(points);

    final n = points.length;
    final result = <Offset>[];
    for (var i = 0; i < n; i++) {
      Offset? nPrev;
      Offset? nNext;

      if (i > 0 || closed) {
        final prev = points[(i - 1 + n) % n];
        final d = points[i] - prev;
        final len = d.distance;
        if (len > 1e-6) nPrev = Offset(-d.dy / len, d.dx / len);
      }
      if (i < n - 1 || closed) {
        final next = points[(i + 1) % n];
        final d = next - points[i];
        final len = d.distance;
        if (len > 1e-6) nNext = Offset(-d.dy / len, d.dx / len);
      }

      final Offset miter;
      if (nPrev != null && nNext != null) {
        final sum = nPrev + nNext;
        final sumLen = sum.distance;
        if (sumLen < 1e-4) {
          miter = nNext;
        } else {
          final bisector = sum / sumLen;
          final cosHalf = (bisector.dx * nNext.dx + bisector.dy * nNext.dy)
              .clamp(0.35, 1.0);
          miter = bisector / cosHalf;
        }
      } else {
        miter = nNext ?? nPrev ?? const Offset(0, 1);
      }
      result.add(points[i] + miter * offset);
    }
    return result;
  }

  /// Polygon of the inner paving surface.
  List<Offset> get pavingPolygon {
    if (closed) return points;
    if (points.length < 2) return const [];
    final halfW = width / 2.0;
    final left = offsetChain(points, halfW, closed: closed);
    final right = offsetChain(points, -halfW, closed: closed);
    return [...left, ...right.reversed];
  }

  /// Polygon of the left curb strip (or outer perimeter curb when [closed] is true).
  List<Offset> get leftCurbPolygon {
    if (!curbMode.hasLeft || curbWidth <= 1e-4 || points.length < 2) {
      return const [];
    }
    if (closed) {
      final outer = offsetChain(points, curbWidth, closed: true);
      return [...outer, ...points.reversed];
    }
    final innerLeft = offsetChain(points, width / 2.0);
    final outerLeft = offsetChain(points, width / 2.0 + curbWidth);
    return [...outerLeft, ...innerLeft.reversed];
  }

  /// Polygon of the right curb strip.
  List<Offset> get rightCurbPolygon {
    if (closed || !curbMode.hasRight || curbWidth <= 1e-4 || points.length < 2) {
      return const [];
    }
    final innerRight = offsetChain(points, -width / 2.0);
    final outerRight = offsetChain(points, -(width / 2.0 + curbWidth));
    return [...innerRight, ...outerRight.reversed];
  }

  double get totalHalfWidth =>
      width / 2.0 + (curbMode != ArchitectPathwayCurbMode.none ? curbWidth : 0.0);

  double get totalWidth =>
      width +
      (curbMode.hasLeft ? curbWidth : 0.0) +
      (curbMode.hasRight ? curbWidth : 0.0);

  bool containsPoint(Offset point, {double tolerance = 0.08}) {
    if (points.length < 2) return false;
    if (closed && points.length >= 3) {
      final path = Path()..addPolygon(points, true);
      if (path.contains(point)) return true;
    }
    final maxDist = (closed ? curbWidth : totalHalfWidth) + tolerance;
    final segCount = closed ? points.length : points.length - 1;
    for (var i = 0; i < segCount; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      final closest = ArchitectTerrainSurface._closestPointOnSegment(
        point,
        a,
        b,
      );
      if ((point - closest).distance <= maxDist) return true;
    }
    return false;
  }

  ArchitectPathway copyWith({
    String? id,
    List<Offset>? points,
    bool? closed,
    double? width,
    ArchitectPathwayCurbMode? curbMode,
    double? curbWidth,
    double? curbHeight,
    double? thickness,
    double? elevationOffset,
    ArchitectPavingMaterial? material,
  }) => ArchitectPathway(
    id: id ?? this.id,
    points: points ?? this.points,
    closed: closed ?? this.closed,
    width: width ?? this.width,
    curbMode: curbMode ?? this.curbMode,
    curbWidth: curbWidth ?? this.curbWidth,
    curbHeight: curbHeight ?? this.curbHeight,
    thickness: thickness ?? this.thickness,
    elevationOffset: elevationOffset ?? this.elevationOffset,
    material: material ?? this.material,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'points': [
      for (final p in points) {'x': p.dx, 'y': p.dy},
    ],
    if (closed) 'closed': true,
    'width': width,
    'curbMode': curbMode.name,
    'curbWidth': curbWidth,
    'curbHeight': curbHeight,
    'thickness': thickness,
    'elevationOffset': elevationOffset,
    'material': material.name,
  };

  factory ArchitectPathway.fromJson(Map<String, dynamic> json) =>
      ArchitectPathway(
        id: json['id'] as String? ?? 'path_0',
        points: [
          for (final p in json['points'] as List? ?? const [])
            if (p is Map)
              Offset(
                (p['x'] as num?)?.toDouble() ?? 0.0,
                (p['y'] as num?)?.toDouble() ?? 0.0,
              ),
        ],
        closed: json['closed'] == true,
        width: (json['width'] as num?)?.toDouble() ?? 1.40,
        curbMode: ArchitectPathwayCurbMode.values.firstWhere(
          (m) => m.name == json['curbMode'],
          orElse: () => ArchitectPathwayCurbMode.both,
        ),
        curbWidth: (json['curbWidth'] as num?)?.toDouble() ?? 0.10,
        curbHeight: (json['curbHeight'] as num?)?.toDouble() ?? 0.08,
        thickness: (json['thickness'] as num?)?.toDouble() ?? 0.12,
        elevationOffset: (json['elevationOffset'] as num?)?.toDouble() ?? 0.02,
        material: ArchitectPavingMaterial.values.firstWhere(
          (m) => m.name == json['material'],
          orElse: () => ArchitectPavingMaterial.stoneSlabs,
        ),
      );
}

// ===========================================================================
// 3. VEGETATION / PLANTING (ОЗЕЛЕНЯВАНЕ С 2D ПЛАН И ФАСАДНИ СИЛУЕТИ)
// ===========================================================================

enum ArchitectPlantSpecies {
  deciduousCanopy,
  deciduousMinimal,
  coniferPine,
  columnarCypress,
  ornamentalPalm,
  shrubCluster,
  trimmedHedge,
  artisticLowPoly;

  String label(AppLocalizations l) => switch (this) {
    deciduousCanopy => l.architectPlantDeciduousCanopy,
    deciduousMinimal => l.architectPlantDeciduousMinimal,
    coniferPine => l.architectPlantConiferPine,
    columnarCypress => l.architectPlantColumnarCypress,
    ornamentalPalm => l.architectPlantOrnamentalPalm,
    shrubCluster => l.architectPlantShrubCluster,
    trimmedHedge => l.architectPlantTrimmedHedge,
    artisticLowPoly => l.architectPlantArtisticLowPoly,
  };

  double get defaultCrownDiameter => switch (this) {
    deciduousCanopy => 3.60,
    deciduousMinimal => 3.20,
    coniferPine => 2.80,
    columnarCypress => 0.90,
    ornamentalPalm => 2.60,
    shrubCluster => 1.40,
    trimmedHedge => 0.55,
    artisticLowPoly => 3.80,
  };

  double get defaultHeight => switch (this) {
    deciduousCanopy => 5.20,
    deciduousMinimal => 4.80,
    coniferPine => 6.00,
    columnarCypress => 3.60,
    ornamentalPalm => 4.50,
    shrubCluster => 1.10,
    trimmedHedge => 1.40,
    artisticLowPoly => 5.60,
  };
}

enum ArchitectVegetationPlacementMode {
  single,
  row,
  hedge;

  String label(AppLocalizations l) => switch (this) {
    single => l.architectVegetationModeSingle,
    row => l.architectVegetationModeRow,
    hedge => l.architectVegetationModeHedge,
  };
}

/// Architectural plant / tree / shrub / hedge instance with crisp 2D plan and facade representations.
class ArchitectVegetationItem {
  final String id;
  final ArchitectPlantSpecies species;
  final Offset position;
  final double crownDiameter;
  final double height;
  final double rotation;
  final List<Offset> hedgePoints;
  final double hedgeWidth;
  final double elevationOffset;

  const ArchitectVegetationItem({
    required this.id,
    this.species = ArchitectPlantSpecies.deciduousCanopy,
    required this.position,
    this.crownDiameter = 3.60,
    this.height = 5.20,
    this.rotation = 0.0,
    List<Offset> hedgePoints = const [],
    List<Offset>? points,
    this.hedgeWidth = 0.55,
    this.elevationOffset = 0.0,
  }) : hedgePoints = points ?? hedgePoints;

  List<Offset> get points => hedgePoints;
  double get rotationRad => rotation;

  bool get isHedge =>
      species == ArchitectPlantSpecies.trimmedHedge && hedgePoints.length >= 2;

  bool containsPoint(Offset point, {double tolerance = 0.10}) {
    if (isHedge) {
      final halfW = hedgeWidth / 2.0 + tolerance;
      for (var i = 0; i < hedgePoints.length - 1; i++) {
        final closest = ArchitectTerrainSurface._closestPointOnSegment(
          point,
          hedgePoints[i],
          hedgePoints[i + 1],
        );
        if ((point - closest).distance <= halfW) return true;
      }
      return false;
    }
    return (point - position).distance <= (crownDiameter / 2.0 + tolerance);
  }

  ArchitectVegetationItem copyWith({
    String? id,
    ArchitectPlantSpecies? species,
    Offset? position,
    double? crownDiameter,
    double? height,
    double? rotation,
    List<Offset>? hedgePoints,
    List<Offset>? points,
    double? hedgeWidth,
    double? elevationOffset,
  }) => ArchitectVegetationItem(
    id: id ?? this.id,
    species: species ?? this.species,
    position: position ?? this.position,
    crownDiameter: crownDiameter ?? this.crownDiameter,
    height: height ?? this.height,
    rotation: rotation ?? this.rotation,
    hedgePoints: points ?? hedgePoints ?? this.hedgePoints,
    hedgeWidth: hedgeWidth ?? this.hedgeWidth,
    elevationOffset: elevationOffset ?? this.elevationOffset,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'species': species.name,
    'position': {'x': position.dx, 'y': position.dy},
    'crownDiameter': crownDiameter,
    'height': height,
    if (rotation.abs() > 1e-6) 'rotation': rotation,
    if (hedgePoints.isNotEmpty)
      'hedgePoints': [
        for (final p in hedgePoints) {'x': p.dx, 'y': p.dy},
      ],
    'hedgeWidth': hedgeWidth,
    if (elevationOffset.abs() > 1e-6) 'elevationOffset': elevationOffset,
  };

  factory ArchitectVegetationItem.fromJson(Map<String, dynamic> json) {
    final pos = json['position'] as Map<String, dynamic>?;
    return ArchitectVegetationItem(
      id: json['id'] as String? ?? 'veg_0',
      species: ArchitectPlantSpecies.values.firstWhere(
        (s) => s.name == json['species'],
        orElse: () => ArchitectPlantSpecies.deciduousCanopy,
      ),
      position: pos != null
          ? Offset(
              (pos['x'] as num?)?.toDouble() ?? 0.0,
              (pos['y'] as num?)?.toDouble() ?? 0.0,
            )
          : Offset.zero,
      crownDiameter: (json['crownDiameter'] as num?)?.toDouble() ?? 3.60,
      height: (json['height'] as num?)?.toDouble() ?? 5.20,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      hedgePoints: [
        for (final p in json['hedgePoints'] as List? ?? const [])
          if (p is Map)
            Offset(
              (p['x'] as num?)?.toDouble() ?? 0.0,
              (p['y'] as num?)?.toDouble() ?? 0.0,
            ),
      ],
      hedgeWidth: (json['hedgeWidth'] as num?)?.toDouble() ?? 0.55,
      elevationOffset: (json['elevationOffset'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// ===========================================================================
// 4. SITE FENCE & RETAINING WALLS (ДВОРНИ ОГРАДИ И ГАБИОННИ/ПОДПОРНИ СТЕНИ)
// ===========================================================================

enum ArchitectSiteFencePreset {
  piersAndSlats,
  gabionFence,
  gabionRetaining,
  modernLouvers,
  classicIron,
  rcRetaining;

  String label(AppLocalizations l) => switch (this) {
    piersAndSlats => l.architectFencePresetPiersAndSlats,
    gabionFence => l.architectFencePresetGabionFence,
    gabionRetaining => l.architectFencePresetGabionRetaining,
    modernLouvers => l.architectFencePresetModernLouvers,
    classicIron => l.architectFencePresetClassicIron,
    rcRetaining => l.architectFencePresetRcRetaining,
  };

  double get defaultHeight => switch (this) {
    piersAndSlats => 1.90,
    gabionFence => 1.80,
    gabionRetaining => 1.20,
    modernLouvers => 1.85,
    classicIron => 1.95,
    rcRetaining => 1.50,
  };

  double get defaultThickness => switch (this) {
    piersAndSlats => 0.25,
    gabionFence => 0.35,
    gabionRetaining => 0.55,
    modernLouvers => 0.22,
    classicIron => 0.25,
    rcRetaining => 0.25,
  };

  double get defaultPierSize => switch (this) {
    piersAndSlats => 0.40,
    gabionFence => 0.35,
    gabionRetaining => 0.55,
    modernLouvers => 0.12,
    classicIron => 0.45,
    rcRetaining => 0.25,
  };

  double get defaultPierSpacing => switch (this) {
    piersAndSlats => 2.20,
    gabionFence => 2.50,
    gabionRetaining => 2.50,
    modernLouvers => 2.40,
    classicIron => 2.40,
    rcRetaining => 3.00,
  };

  bool get hasMasonryPiers =>
      this == piersAndSlats || this == classicIron || this == modernLouvers;

  bool get isGabion => this == gabionFence || this == gabionRetaining;

  bool get isRetaining => this == gabionRetaining || this == rcRetaining;
}

/// How a site fence or retaining wall adapts to sloped or asymmetric terrain.
enum ArchitectFenceSlopeMode {
  /// Terraced horizontal bays that step cleanly at piers/modules.
  stepped,

  /// Panels/profiles rake continuously along the terrain slope.
  sloped;

  String label(AppLocalizations l) => switch (this) {
    stepped => l.architectFenceSlopeStepped,
    sloped => l.architectFenceSlopeSloped,
  };
}

/// Architectural site fence or retaining wall (Gabion, Masonry Piers + Horizontal Boards,
/// Modern Louvers, Classic Wrought Iron, or RC Retaining Wall).
class ArchitectSiteFence {
  final String id;
  final List<Offset> points;
  final bool closed;
  final ArchitectSiteFencePreset preset;
  final double height;
  final double thickness;
  final double plinthHeight;
  final double pierSize;
  final double pierSpacing;
  final double elevationOffset;
  final ArchitectFenceSlopeMode slopeMode;

  const ArchitectSiteFence({
    required this.id,
    required this.points,
    this.closed = false,
    this.preset = ArchitectSiteFencePreset.piersAndSlats,
    this.height = 1.90,
    this.thickness = 0.25,
    this.plinthHeight = 0.45,
    this.pierSize = 0.40,
    this.pierSpacing = 2.20,
    this.elevationOffset = 0.0,
    this.slopeMode = ArchitectFenceSlopeMode.stepped,
  });

  List<Offset> get postPositions => [for (final p in pierPositions) p.$1];

  /// Computes the positions and tangent angles `(Offset center, double angleRad)`
  /// of all piers/posts along the fence chain.
  List<(Offset, double)> get pierPositions {
    if (points.length < 2) return const [];
    final result = <(Offset, double)>[];
    final safeSpacing = math.max(0.80, pierSpacing);

    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final seg = b - a;
      final len = seg.distance;
      if (len < 1e-4) continue;
      final angle = math.atan2(seg.dy, seg.dx);
      final bays = math.max(1, (len / safeSpacing).round());
      for (var k = 0; k < bays; k++) {
        if (i > 0 && k == 0) continue; // avoid duplicate corner pier
        final t = k / bays;
        result.add((Offset.lerp(a, b, t)!, angle));
      }
      if (i == points.length - 2) {
        result.add((b, angle));
      }
    }
    return result;
  }

  bool containsPoint(Offset point, {double tolerance = 0.10}) {
    if (points.length < 2) return false;
    final halfW = math.max(thickness, pierSize) / 2.0 + tolerance;
    for (var i = 0; i < points.length - 1; i++) {
      final closest = ArchitectTerrainSurface._closestPointOnSegment(
        point,
        points[i],
        points[i + 1],
      );
      if ((point - closest).distance <= halfW) return true;
    }
    return false;
  }

  ArchitectSiteFence copyWith({
    String? id,
    List<Offset>? points,
    bool? closed,
    ArchitectSiteFencePreset? preset,
    double? height,
    double? thickness,
    double? plinthHeight,
    double? pierSize,
    double? pierSpacing,
    double? elevationOffset,
    ArchitectFenceSlopeMode? slopeMode,
  }) => ArchitectSiteFence(
    id: id ?? this.id,
    points: points ?? this.points,
    closed: closed ?? this.closed,
    preset: preset ?? this.preset,
    height: height ?? this.height,
    thickness: thickness ?? this.thickness,
    plinthHeight: plinthHeight ?? this.plinthHeight,
    pierSize: pierSize ?? this.pierSize,
    pierSpacing: pierSpacing ?? this.pierSpacing,
    elevationOffset: elevationOffset ?? this.elevationOffset,
    slopeMode: slopeMode ?? this.slopeMode,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'points': [
      for (final p in points) {'x': p.dx, 'y': p.dy},
    ],
    if (closed) 'closed': true,
    'preset': preset.name,
    'height': height,
    'thickness': thickness,
    'plinthHeight': plinthHeight,
    'pierSize': pierSize,
    'pierSpacing': pierSpacing,
    if (elevationOffset.abs() > 1e-6) 'elevationOffset': elevationOffset,
    if (slopeMode != ArchitectFenceSlopeMode.stepped)
      'slopeMode': slopeMode.name,
  };

  factory ArchitectSiteFence.fromJson(Map<String, dynamic> json) =>
      ArchitectSiteFence(
        id: json['id'] as String? ?? 'fence_0',
        points: [
          for (final p in json['points'] as List? ?? const [])
            if (p is Map)
              Offset(
                (p['x'] as num?)?.toDouble() ?? 0.0,
                (p['y'] as num?)?.toDouble() ?? 0.0,
              ),
        ],
        closed: json['closed'] == true,
        preset: ArchitectSiteFencePreset.values.firstWhere(
          (p) => p.name == json['preset'],
          orElse: () => ArchitectSiteFencePreset.piersAndSlats,
        ),
        height: (json['height'] as num?)?.toDouble() ?? 1.90,
        thickness: (json['thickness'] as num?)?.toDouble() ?? 0.25,
        plinthHeight: (json['plinthHeight'] as num?)?.toDouble() ?? 0.45,
        pierSize: (json['pierSize'] as num?)?.toDouble() ?? 0.40,
        pierSpacing: (json['pierSpacing'] as num?)?.toDouble() ?? 2.20,
        elevationOffset: (json['elevationOffset'] as num?)?.toDouble() ?? 0.0,
        slopeMode: ArchitectFenceSlopeMode.values.firstWhere(
          (m) => m.name == json['slopeMode'],
          orElse: () => ArchitectFenceSlopeMode.stepped,
        ),
      );
}

// ===========================================================================
// 5. STREET / ROAD WITH SIDEWALKS & MARKINGS (УЛИЦА С МАРКИРОВКА И ТРОТОАРИ)
// ===========================================================================

enum ArchitectRoadMarkingStyle {
  dashed,
  solid,
  doubleSolid,
  none;

  String label(AppLocalizations l) => switch (this) {
    dashed => l.architectStreetMarkingDashed,
    solid => l.architectStreetMarkingSolid,
    doubleSolid => l.architectStreetMarkingDoubleSolid,
    none => l.architectStreetMarkingNone,
  };
}

/// Street / Roadway element with asphalt carriageway, road markings, left/right curbs and sidewalks.
class ArchitectStreet {
  final String id;
  final List<Offset> points;
  final bool closed;
  final double roadWidth;
  final double curbWidth;
  final double curbHeight;
  final bool hasLeftSidewalk;
  final double leftSidewalkWidth;
  final bool hasRightSidewalk;
  final double rightSidewalkWidth;
  final ArchitectRoadMarkingStyle markingStyle;
  final double markingWidth;
  final ArchitectPavingMaterial roadMaterial;
  final ArchitectPavingMaterial sidewalkMaterial;
  final double elevationOffset;

  const ArchitectStreet({
    required this.id,
    required this.points,
    this.closed = false,
    this.roadWidth = 6.00,
    this.curbWidth = 0.15,
    this.curbHeight = 0.12,
    this.hasLeftSidewalk = true,
    this.leftSidewalkWidth = 1.50,
    this.hasRightSidewalk = true,
    this.rightSidewalkWidth = 1.50,
    this.markingStyle = ArchitectRoadMarkingStyle.dashed,
    this.markingWidth = 0.12,
    this.roadMaterial = ArchitectPavingMaterial.asphalt,
    this.sidewalkMaterial = ArchitectPavingMaterial.cobblePavers,
    this.elevationOffset = 0.02,
  });

  /// Polygon of the asphalt carriageway surface.
  List<Offset> get roadwayPolygon {
    if (points.length < 2) return const [];
    final halfW = roadWidth / 2.0;
    final left = ArchitectPathway.offsetChain(points, halfW, closed: closed);
    final right = ArchitectPathway.offsetChain(points, -halfW, closed: closed);
    return [...left, ...right.reversed];
  }

  /// Polygon of the left curb strip separating roadway and left sidewalk.
  List<Offset> get leftCurbPolygon {
    if (curbWidth <= 1e-4 || points.length < 2) return const [];
    final inner = ArchitectPathway.offsetChain(
      points,
      roadWidth / 2.0,
      closed: closed,
    );
    final outer = ArchitectPathway.offsetChain(
      points,
      roadWidth / 2.0 + curbWidth,
      closed: closed,
    );
    return [...outer, ...inner.reversed];
  }

  /// Polygon of the right curb strip separating roadway and right sidewalk.
  List<Offset> get rightCurbPolygon {
    if (curbWidth <= 1e-4 || points.length < 2) return const [];
    final inner = ArchitectPathway.offsetChain(
      points,
      -roadWidth / 2.0,
      closed: closed,
    );
    final outer = ArchitectPathway.offsetChain(
      points,
      -(roadWidth / 2.0 + curbWidth),
      closed: closed,
    );
    return [...inner, ...outer.reversed];
  }

  /// Polygon of the left sidewalk paving strip.
  List<Offset> get leftSidewalkPolygon {
    if (!hasLeftSidewalk || leftSidewalkWidth <= 1e-4 || points.length < 2) {
      return const [];
    }
    final inner = ArchitectPathway.offsetChain(
      points,
      roadWidth / 2.0 + curbWidth,
      closed: closed,
    );
    final outer = ArchitectPathway.offsetChain(
      points,
      roadWidth / 2.0 + curbWidth + leftSidewalkWidth,
      closed: closed,
    );
    return [...outer, ...inner.reversed];
  }

  /// Polygon of the right sidewalk paving strip.
  List<Offset> get rightSidewalkPolygon {
    if (!hasRightSidewalk || rightSidewalkWidth <= 1e-4 || points.length < 2) {
      return const [];
    }
    final inner = ArchitectPathway.offsetChain(
      points,
      -(roadWidth / 2.0 + curbWidth),
      closed: closed,
    );
    final outer = ArchitectPathway.offsetChain(
      points,
      -(roadWidth / 2.0 + curbWidth + rightSidewalkWidth),
      closed: closed,
    );
    return [...inner, ...outer.reversed];
  }

  double get totalLeftWidth =>
      roadWidth / 2.0 +
      curbWidth +
      (hasLeftSidewalk ? leftSidewalkWidth : 0.0);

  double get totalRightWidth =>
      roadWidth / 2.0 +
      curbWidth +
      (hasRightSidewalk ? rightSidewalkWidth : 0.0);

  double get totalWidth => totalLeftWidth + totalRightWidth;

  bool containsPoint(Offset point, {double tolerance = 0.10}) {
    if (points.length < 2) return false;
    if (closed && points.length >= 3) {
      final path = Path()..addPolygon(points, true);
      if (path.contains(point)) return true;
    }
    final maxDist =
        (totalLeftWidth > totalRightWidth ? totalLeftWidth : totalRightWidth) +
        tolerance;
    final segCount = closed ? points.length : points.length - 1;
    for (var i = 0; i < segCount; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      final closest = ArchitectTerrainSurface._closestPointOnSegment(
        point,
        a,
        b,
      );
      if ((point - closest).distance <= maxDist) return true;
    }
    return false;
  }

  ArchitectStreet copyWith({
    String? id,
    List<Offset>? points,
    bool? closed,
    double? roadWidth,
    double? curbWidth,
    double? curbHeight,
    bool? hasLeftSidewalk,
    double? leftSidewalkWidth,
    bool? hasRightSidewalk,
    double? rightSidewalkWidth,
    ArchitectRoadMarkingStyle? markingStyle,
    double? markingWidth,
    ArchitectPavingMaterial? roadMaterial,
    ArchitectPavingMaterial? sidewalkMaterial,
    double? elevationOffset,
  }) => ArchitectStreet(
    id: id ?? this.id,
    points: points ?? this.points,
    closed: closed ?? this.closed,
    roadWidth: roadWidth ?? this.roadWidth,
    curbWidth: curbWidth ?? this.curbWidth,
    curbHeight: curbHeight ?? this.curbHeight,
    hasLeftSidewalk: hasLeftSidewalk ?? this.hasLeftSidewalk,
    leftSidewalkWidth: leftSidewalkWidth ?? this.leftSidewalkWidth,
    hasRightSidewalk: hasRightSidewalk ?? this.hasRightSidewalk,
    rightSidewalkWidth: rightSidewalkWidth ?? this.rightSidewalkWidth,
    markingStyle: markingStyle ?? this.markingStyle,
    markingWidth: markingWidth ?? this.markingWidth,
    roadMaterial: roadMaterial ?? this.roadMaterial,
    sidewalkMaterial: sidewalkMaterial ?? this.sidewalkMaterial,
    elevationOffset: elevationOffset ?? this.elevationOffset,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'points': [
      for (final p in points) {'x': p.dx, 'y': p.dy},
    ],
    if (closed) 'closed': true,
    'roadWidth': roadWidth,
    'curbWidth': curbWidth,
    'curbHeight': curbHeight,
    'hasLeftSidewalk': hasLeftSidewalk,
    'leftSidewalkWidth': leftSidewalkWidth,
    'hasRightSidewalk': hasRightSidewalk,
    'rightSidewalkWidth': rightSidewalkWidth,
    'markingStyle': markingStyle.name,
    'markingWidth': markingWidth,
    'roadMaterial': roadMaterial.name,
    'sidewalkMaterial': sidewalkMaterial.name,
    if (elevationOffset.abs() > 1e-6) 'elevationOffset': elevationOffset,
  };

  factory ArchitectStreet.fromJson(Map<String, dynamic> json) =>
      ArchitectStreet(
        id: json['id'] as String? ?? 'street_0',
        points: [
          for (final p in json['points'] as List? ?? const [])
            if (p is Map)
              Offset(
                (p['x'] as num?)?.toDouble() ?? 0.0,
                (p['y'] as num?)?.toDouble() ?? 0.0,
              ),
        ],
        closed: json['closed'] == true,
        roadWidth: (json['roadWidth'] as num?)?.toDouble() ?? 6.00,
        curbWidth: (json['curbWidth'] as num?)?.toDouble() ?? 0.15,
        curbHeight: (json['curbHeight'] as num?)?.toDouble() ?? 0.12,
        hasLeftSidewalk: json['hasLeftSidewalk'] != false,
        leftSidewalkWidth:
            (json['leftSidewalkWidth'] as num?)?.toDouble() ?? 1.50,
        hasRightSidewalk: json['hasRightSidewalk'] != false,
        rightSidewalkWidth:
            (json['rightSidewalkWidth'] as num?)?.toDouble() ?? 1.50,
        markingStyle: ArchitectRoadMarkingStyle.values.firstWhere(
          (m) => m.name == json['markingStyle'],
          orElse: () => ArchitectRoadMarkingStyle.dashed,
        ),
        markingWidth: (json['markingWidth'] as num?)?.toDouble() ?? 0.12,
        roadMaterial: ArchitectPavingMaterial.values.firstWhere(
          (m) => m.name == json['roadMaterial'],
          orElse: () => ArchitectPavingMaterial.asphalt,
        ),
        sidewalkMaterial: ArchitectPavingMaterial.values.firstWhere(
          (m) => m.name == json['sidewalkMaterial'],
          orElse: () => ArchitectPavingMaterial.cobblePavers,
        ),
        elevationOffset:
            (json['elevationOffset'] as num?)?.toDouble() ?? 0.02,
      );
}
