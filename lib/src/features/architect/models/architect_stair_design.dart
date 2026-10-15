import 'dart:math' as math;
import 'dart:ui';

enum StairShape { straight, quarterTurn, halfTurn, spiral }

enum StairCode { bulgaria, geometryOnly }

enum StairUse { private, common, public, assembly, outdoorRoute }

enum StairEvacuation { unspecified, none, upTo15, from16To50, over50 }

/// All dimensions are clear finished dimensions, in metres. The inner radius
/// starts at the limiting inner edge / handrail projection, not a column axis.
/// A versioned rule set is stored with each design; UI text lives in ARB.
class ArchitectStairDesign {
  static const currentRules = 'BG-2025.1';
  final String rulesVersion;
  final StairShape shape;
  final StairCode code;
  final StairUse use;
  final StairEvacuation evacuation;
  final double rise;
  final bool followStoreys;
  final String? upperStoreyId;
  final int? manualRisers;
  final double? manualGoing;
  final double landingDepth;
  final double innerRadius;
  final double sweepDegrees;
  final bool turnLeft;
  final bool isDraft;

  const ArchitectStairDesign({
    this.rulesVersion = currentRules,
    this.shape = StairShape.halfTurn,
    this.code = StairCode.bulgaria,
    this.use = StairUse.common,
    this.evacuation = StairEvacuation.unspecified,
    this.rise = 2.8,
    this.followStoreys = true,
    this.upperStoreyId,
    this.manualRisers,
    this.manualGoing,
    this.landingDepth = 1.2,
    this.innerRadius = .6,
    this.sweepDegrees = 270,
    this.turnLeft = false,
    this.isDraft = false,
  });

  bool get accessible => code == StairCode.bulgaria && use != StairUse.private;
  bool get isEvacuation =>
      evacuation != StairEvacuation.none &&
      evacuation != StairEvacuation.unspecified;
  double get preferredMaxRiser =>
      accessible ? (use == StairUse.outdoorRoute ? .15 : .17) : .18;
  int get risers =>
      manualRisers ?? math.max(
        (isEvacuation ? 3 : 2) *
            (shape == StairShape.quarterTurn || shape == StairShape.halfTurn ? 2 : 1),
        (rise / preferredMaxRiser - 1e-9).ceil());
  double get riser => rise / risers;
  double get going =>
      manualGoing ??
      (.63 - 2 * riser).clamp(
        accessible && use == StairUse.outdoorRoute ? .32 : .28,
        .35,
      );
  double get maximumFlightRise =>
      use == StairUse.outdoorRoute && accessible ? 1.2 : 2.5;
  int get flightCount => shape == StairShape.spiral
      ? 1
      : shape != StairShape.straight ? 2 : !accessible ? 1 : math.max(
          1,
          (risers / math.max(2, (maximumFlightRise / riser + 1e-9).floor()))
              .ceil(),
        );
  List<int> get flightRisers => [
    for (var i = 0; i < flightCount; i++)
      risers ~/ flightCount + (i < risers % flightCount ? 1 : 0),
  ];
  double get anglePerGoing => sweepDegrees * math.pi / 180 / (risers - 1);
  // Chord is conservative relative to arc length and measures the clear
  // straight distance between consecutive nosings on a radial tread.
  double goingAtRadius(double radius) =>
      2 * radius * math.sin(anglePerGoing / 2);
  double get innerGoing => goingAtRadius(innerRadius);
  double get goingAt30 => goingAtRadius(innerRadius + .30);
  double walkingGoing(double width) => shape == StairShape.spiral
      ? goingAtRadius(innerRadius + width / 2)
      : going;

  void validate() {
    for (final value in [
      rise,
      landingDepth,
      innerRadius,
      sweepDegrees,
      ?manualGoing,
    ]) {
      if (!value.isFinite || value <= 0) {
        throw ArgumentError('Invalid stair dimension');
      }
    }
    if (rise > 30 ||
        risers < 2 ||
        risers > 500 ||
        sweepDegrees < 30 ||
        sweepDegrees > 360 ||
        flightRisers.any((n) => n < 2)) {
      throw ArgumentError('Unsupported stair geometry');
    }
  }

  ArchitectStairDesign copyWith({
    StairShape? shape,
    StairCode? code,
    StairUse? use,
    StairEvacuation? evacuation,
    double? rise,
    bool? followStoreys,
    String? upperStoreyId,
    bool clearUpperStorey = false,
    int? manualRisers,
    bool autoRisers = false,
    double? manualGoing,
    bool autoGoing = false,
    double? landingDepth,
    double? innerRadius,
    double? sweepDegrees,
    bool? turnLeft,
    bool? isDraft,
  }) => ArchitectStairDesign(
    rulesVersion: rulesVersion,
    shape: shape ?? this.shape,
    code: code ?? this.code,
    use: use ?? this.use,
    evacuation: evacuation ?? this.evacuation,
    rise: rise ?? this.rise,
    followStoreys: followStoreys ?? this.followStoreys,
    upperStoreyId: clearUpperStorey
        ? null
        : upperStoreyId ?? this.upperStoreyId,
    manualRisers: autoRisers ? null : manualRisers ?? this.manualRisers,
    manualGoing: autoGoing ? null : manualGoing ?? this.manualGoing,
    landingDepth: landingDepth ?? this.landingDepth,
    innerRadius: innerRadius ?? this.innerRadius,
    sweepDegrees: sweepDegrees ?? this.sweepDegrees,
    turnLeft: turnLeft ?? this.turnLeft,
    isDraft: isDraft ?? this.isDraft,
  );

  Map<String, dynamic> toJson() => {
    'rulesVersion': rulesVersion,
    'shape': shape.name,
    'code': code.name,
    'use': use.name,
    'evacuation': evacuation.name,
    'rise': rise,
    'followStoreys': followStoreys,
    'upperStoreyId': upperStoreyId,
    'manualRisers': manualRisers,
    'manualGoing': manualGoing,
    'landingDepth': landingDepth,
    'innerRadius': innerRadius,
    'sweepDegrees': sweepDegrees,
    'turnLeft': turnLeft,
    'isDraft': isDraft,
  };
  factory ArchitectStairDesign.fromJson(Map<String, dynamic> json) {
    T readEnum<T extends Enum>(List<T> values, String key, T fallback) =>
        values.where((v) => v.name == json[key]).firstOrNull ?? fallback;
    final result = ArchitectStairDesign(
      rulesVersion: json['rulesVersion'] as String? ?? currentRules,
      shape: readEnum(StairShape.values, 'shape', StairShape.halfTurn),
      code: readEnum(StairCode.values, 'code', StairCode.bulgaria),
      use: readEnum(StairUse.values, 'use', StairUse.common),
      evacuation: readEnum(
        StairEvacuation.values,
        'evacuation',
        StairEvacuation.unspecified,
      ),
      rise: (json['rise'] as num?)?.toDouble() ?? 2.8,
      followStoreys: json['followStoreys'] as bool? ?? true,
      upperStoreyId: json['upperStoreyId'] as String?,
      manualRisers: (json['manualRisers'] as num?)?.toInt(),
      manualGoing: (json['manualGoing'] as num?)?.toDouble(),
      landingDepth: (json['landingDepth'] as num?)?.toDouble() ?? 1.2,
      innerRadius: (json['innerRadius'] as num?)?.toDouble() ?? .6,
      sweepDegrees: (json['sweepDegrees'] as num?)?.toDouble() ?? 270,
      turnLeft: json['turnLeft'] as bool? ?? false,
      isDraft: json['isDraft'] as bool? ?? false,
    );
    result.validate();
    return result;
  }
}

/// Shared by committed drawing, preview, picking, snapping and selection.
class ArchitectStairSurface {
  final List<Offset> polygon;
  final double elevation;
  const ArchitectStairSurface(this.polygon, this.elevation);
}

class ArchitectStairPlan {
  final List<List<Offset>> footprints;
  final List<(Offset, Offset)> nosings;
  final List<Offset> walkingLine;
  final List<ArchitectStairSurface> surfaces;
  ArchitectStairPlan(this.footprints, this.nosings, this.walkingLine,
      [this.surfaces = const []]);
  late final Path path = _path();
  Path _path() {
    var result = Path();
    for (final polygon in footprints) {
      result = Path.combine(
        PathOperation.union,
        result,
        Path()..addPolygon(polygon, true),
      );
    }
    return result;
  }

  late final Rect bounds = _bounds();
  Rect _bounds() {
    final points = footprints.expand((p) => p).toList();
    return Rect.fromLTRB(points.map((p) => p.dx).reduce(math.min),
      points.map((p) => p.dy).reduce(math.min),
      points.map((p) => p.dx).reduce(math.max),
      points.map((p) => p.dy).reduce(math.max));
  }
  bool contains(Offset point, double tolerance) {
    if (path.contains(point)) return true;
    for (final polygon in footprints) {
      for (var i = 0; i < polygon.length; i++) {
        final a = polygon[i], b = polygon[(i + 1) % polygon.length];
        final d = b - a, p = point - a;
        final t = d.distanceSquared < 1e-12
            ? 0.0
            : ((p.dx * d.dx + p.dy * d.dy) / d.distanceSquared).clamp(0.0, 1.0);
        if ((point - a - d * t).distance <= tolerance) return true;
      }
    }
    return false;
  }

  static ArchitectStairPlan build({
    required Offset start,
    required Offset direction,
    required double width,
    required ArchitectStairDesign design,
  }) {
    design.validate();
    if (!width.isFinite || width <= 0) {
      throw ArgumentError('Invalid stair width');
    }
    final u = direction.distance < 1e-9
        ? const Offset(1, 0)
        : direction / direction.distance;
    final v = Offset(-u.dy, u.dx) * (design.turnLeft ? -1 : 1);
    Offset world(Offset p) => start + u * p.dx + v * p.dy;
    final footprints = <List<Offset>>[],
        nosings = <(Offset, Offset)>[],
        walk = <Offset>[];
    final surfaces = <ArchitectStairSurface>[];
    void surface(List<Offset> points, double elevation) =>
      surfaces.add(ArchitectStairSurface(points.map(world).toList(), elevation));
    void polygon(List<Offset> points) =>
        footprints.add(points.map(world).toList());
    void line(Offset a, Offset b) => nosings.add((world(a), world(b)));
    if (design.shape == StairShape.spiral) {
      final inner = design.innerRadius,
          outer = inner + width,
          mid = inner + width / 2;
      Offset radial(double r, double angle) =>
          Offset(r * math.sin(angle), mid - r * math.cos(angle));
      final count = math.max(48, (design.sweepDegrees * 2).ceil());
      final sweep = design.sweepDegrees * math.pi / 180;
      polygon([
        for (var i = 0; i <= count; i++) radial(outer, sweep * i / count),
        for (var i = count; i >= 0; i--) radial(inner, sweep * i / count),
      ]);
      for (var i = 0; i < design.risers; i++) {
        line(
          radial(inner, design.anglePerGoing * i),
          radial(outer, design.anglePerGoing * i),
        );
        if (i < design.risers - 1) {
          // Small quads follow the curved edges in the 3D presentation.
          const slices = 8;
          for (var s = 0; s < slices; s++) {
            final a = design.anglePerGoing * (i + s / slices);
            final b = design.anglePerGoing * (i + (s + 1) / slices);
            surface([radial(inner, a), radial(outer, a),
              radial(outer, b), radial(inner, b)], (i + 1) * design.riser);
          }
        }
      }
      walk.addAll([
        for (var i = 0; i <= count; i++) world(radial(mid, sweep * i / count)),
      ]);
    } else {
      var origin = Offset.zero, axis = const Offset(1, 0);
      final flights = design.flightRisers;
      final d = math.max(width, design.landingDepth);
      var climbed = 0;
      void landing(List<Offset> points) {
        polygon(points);
        surface(points, climbed * design.riser);
      }
      for (var f = 0; f < flights.length; f++) {
        final normal = Offset(-axis.dy, axis.dx);
        final run = (flights[f] - 1) * design.going;
        final end = origin + axis * run;
        polygon([
          origin - normal * width / 2,
          end - normal * width / 2,
          end + normal * width / 2,
          origin + normal * width / 2,
        ]);
        for (var i = 0; i < flights[f]; i++) {
          final p = origin + axis * (i * design.going);
          line(p - normal * width / 2, p + normal * width / 2);
          if (i < flights[f] - 1) {
            final next = p + axis * design.going;
            surface([p - normal * width / 2, next - normal * width / 2,
              next + normal * width / 2, p + normal * width / 2],
              (climbed + i + 1) * design.riser);
          }
        }
        climbed += flights[f];
        walk.addAll([world(origin), world(end)]);
        if (f == flights.length - 1) continue;
        if (design.shape == StairShape.straight) {
          landing([
            end - normal * width / 2,
            end + axis * d - normal * width / 2,
            end + axis * d + normal * width / 2,
            end + normal * width / 2,
          ]);
          origin = end + axis * d;
        } else if (design.shape == StairShape.quarterTurn) {
          landing([
            end - normal * width / 2,
            end + axis * d - normal * width / 2,
            end + axis * d + normal * (d - width / 2),
            end + normal * (d - width / 2),
          ]);
          origin = end + axis * (d - width / 2) + normal * (d - width / 2);
          walk.add(world(end + axis * (d - width / 2)));
          axis = normal;
        } else {
          // A 10 cm clear well separates the two return flights.
          final side = f.isEven ? normal : -normal;
          landing([
            end - side * width / 2,
            end + axis * d - side * width / 2,
            end + axis * d + side * (1.5 * width + .1),
            end + side * (1.5 * width + .1),
          ]);
          origin = end + side * (width + .1);
          walk.addAll([
            world(end + axis * d / 2),
            world(origin + axis * d / 2),
          ]);
          axis = -axis;
        }
      }
    }
    return ArchitectStairPlan(footprints, nosings, walk, surfaces);
  }
}
