import 'dart:math' as math;
import 'dart:ui';

enum StairShape { straight, quarterTurn, halfTurn, spiral, spiralOverlap }

enum StairCode { bulgaria, geometryOnly }

enum StairUse { private, common, public, assembly, outdoorRoute }

enum StairEvacuation { unspecified, none, upTo15, from16To50, over50 }

/// All dimensions are clear finished dimensions, in metres. The inner radius
/// starts at the limiting inner edge / handrail projection, not a column axis.
/// A versioned rule set is stored with each design; UI text lives in ARB.
class ArchitectStairDesign {
  static const currentRules = 'BG-2025.1';
  static const spiralSlicesPerGoing = 8;
  final String rulesVersion;
  final StairShape shape;
  final StairCode code;
  final StairUse use;
  final StairEvacuation evacuation;
  final double rise;

  /// Finished starting level relative to the owning storey's elevation.
  final double startOffset;
  final bool followStoreys;
  final String? upperStoreyId;
  final int? manualRisers;
  final double? manualGoing;
  final double landingDepth;
  final double innerRadius;
  final double sweepDegrees;
  final bool winderSteps;
  final bool cornerRiser;
  final int? manualWinderSteps;
  final double? manualWinderRadius;
  final bool turnLeft;
  final bool isDraft;
  final bool showRailing;
  final bool showLabel;
  final double guardHeight;
  final double handrailHeight;
  final double concreteThickness;
  final double finishThickness;
  final double nosingProjection;

  const ArchitectStairDesign({
    this.rulesVersion = currentRules,
    this.shape = StairShape.halfTurn,
    this.code = StairCode.bulgaria,
    this.use = StairUse.common,
    this.evacuation = StairEvacuation.unspecified,
    this.rise = 2.8,
    this.startOffset = 0,
    this.followStoreys = true,
    this.upperStoreyId,
    this.manualRisers,
    this.manualGoing,
    this.landingDepth = 1.2,
    this.innerRadius = .6,
    double? sweepDegrees,
    this.winderSteps = false,
    this.cornerRiser = false,
    this.manualWinderSteps,
    this.manualWinderRadius,
    this.turnLeft = false,
    this.isDraft = false,
    this.showRailing = true,
    this.showLabel = true,
    this.guardHeight = 1.2,
    this.handrailHeight = .9,
    this.concreteThickness = .15,
    this.finishThickness = .02,
    this.nosingProjection = .03,
  }) : sweepDegrees =
           sweepDegrees ?? (shape == StairShape.spiralOverlap ? 375 : 270);

  bool get isSpiral =>
      shape == StairShape.spiral || shape == StairShape.spiralOverlap;
  bool get hasWinders =>
      winderSteps &&
      (shape == StairShape.quarterTurn || shape == StairShape.halfTurn);
  int get turnQuarters => shape == StairShape.halfTurn ? 2 : 1;

  /// A square outer corner and a clear, rounded inner well. Odd counts place
  /// a tread across the corner; even counts place a riser on its bisector.
  /// The automatic radius meets the 30 cm planning line without pointed ends.
  ({int perQuarter, double radius, double angle}) winderLayout(double width) {
    final maximum = (risers - 3) ~/ turnQuarters;
    final parity = cornerRiser ? 0 : 1;
    var count = manualWinderSteps ?? (cornerRiser ? 2 : 3);
    if (manualWinderSteps == null) {
      for (var n = count; n <= maximum; n += 2) {
        count = n;
        final factor = 2 * math.sin(math.pi / (4 * n));
        final radius =
            manualWinderRadius ??
            math.max(
              .05 / factor,
              math.max(going / factor - width / 2, .23 / factor - .30),
            );
        if ((radius + width / 2) * factor <= math.max(.35, going) + 1e-9) break;
      }
    }
    // Invalid manual counts are rejected by validate; automatic counts always
    // keep at least one straight going at each end of the turn.
    count = count.clamp(
      cornerRiser ? 2 : 1,
      math.max(cornerRiser ? 2 : 1, maximum),
    );
    if (manualWinderSteps == null && count % 2 != parity && count > 1) count--;
    final angle = math.pi / (2 * count);
    final factor = 2 * math.sin(angle / 2);
    final radius =
        manualWinderRadius ??
        math.max(
          .05 / factor,
          math.max(going / factor - width / 2, .23 / factor - .30),
        );
    return (perQuarter: count, radius: radius, angle: angle);
  }

  double winderGoingAt(double width, double offset) {
    final layout = winderLayout(width);
    return 2 * (layout.radius + offset) * math.sin(layout.angle / 2);
  }

  /// Conservative clearance to the triangulated waist one revolution above.
  /// Round down to its angular slice's lowest reference height: an interior
  /// point of a non-planar quad must never overstate available headroom.
  double get overlapHeadroom =>
      (((2 * math.pi / anglePerGoing * spiralSlicesPerGoing + 1e-9).floor() /
                  spiralSlicesPerGoing) -
              1) *
          riser -
      concreteThickness -
      finishThickness;

  bool get accessible => code == StairCode.bulgaria && use != StairUse.private;
  bool get isEvacuation =>
      evacuation != StairEvacuation.none &&
      evacuation != StairEvacuation.unspecified;
  double get preferredMaxRiser =>
      accessible ? (use == StairUse.outdoorRoute ? .15 : .17) : .18;
  int get risers {
    if (manualRisers != null) return manualRisers!;
    var count = math.max(
      hasWinders ? turnQuarters * (cornerRiser ? 2 : 3) + 3 : 2,
      math.max(
        (isEvacuation ? 3 : 2) *
            (shape == StairShape.quarterTurn || shape == StairShape.halfTurn
                ? 2
                : 1),
        (rise / preferredMaxRiser - 1e-9).ceil(),
      ),
    );
    if (accessible && !isSpiral) {
      final flights = shape == StairShape.straight
          ? math.max(1, (rise / maximumFlightRise - 1e-9).ceil())
          : hasWinders
          ? 1
          : 2;
      if (rise <= flights * maximumFlightRise + 1e-9) {
        // Balance integer counts, rather than rejecting a feasible stair.
        // E.g. 4.90 m / 29 gives a 2.534 m flight; 30 gives two at 2.45 m.
        while (count <= 500 &&
            (count / flights).ceil() * rise / count >
                maximumFlightRise + 1e-9) {
          count++;
        }
      }
    }
    return count;
  }

  double get riser => rise / risers;
  double get going =>
      manualGoing ??
      (.63 - 2 * riser).clamp(
        accessible && use == StairUse.outdoorRoute ? .32 : .28,
        .35,
      );
  double get maximumFlightRise =>
      use == StairUse.outdoorRoute && accessible ? 1.2 : 2.5;
  int get flightCount => isSpiral || hasWinders
      ? 1
      : shape != StairShape.straight
      ? 2
      : !accessible
      ? 1
      : math.max(
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
  double walkingGoing(double width) =>
      isSpiral ? goingAtRadius(innerRadius + width / 2) : going;

  void validate() {
    if (!startOffset.isFinite || startOffset.abs() > 100) {
      throw ArgumentError('Invalid stair start offset');
    }
    for (final value in [
      rise,
      landingDepth,
      innerRadius,
      sweepDegrees,
      ?manualGoing,
      ?manualWinderRadius,
      guardHeight,
      handrailHeight,
      concreteThickness,
    ]) {
      if (!value.isFinite || value <= 0) {
        throw ArgumentError('Invalid stair dimension');
      }
    }
    if (!finishThickness.isFinite ||
        !nosingProjection.isFinite ||
        finishThickness < 0 ||
        finishThickness > .15 ||
        nosingProjection < 0 ||
        nosingProjection > .1 ||
        concreteThickness > 1 ||
        guardHeight > 2 ||
        handrailHeight > guardHeight) {
      throw ArgumentError('Invalid stair detailing');
    }
    if (rise > 30 ||
        risers < 2 ||
        risers > 500 ||
        sweepDegrees < (shape == StairShape.spiralOverlap ? 360.001 : 30) ||
        sweepDegrees > (shape == StairShape.spiralOverlap ? 1080 : 360) ||
        (isSpiral && anglePerGoing >= math.pi) ||
        (manualWinderSteps != null &&
            (manualWinderSteps! < 1 ||
                manualWinderSteps! > 24 ||
                manualWinderSteps! % 2 != (cornerRiser ? 0 : 1))) ||
        (hasWinders &&
            (risers < turnQuarters * (cornerRiser ? 2 : 3) + 3 ||
                (manualWinderSteps != null &&
                    manualWinderSteps! * turnQuarters > risers - 3))) ||
        flightRisers.any((n) => n < 2)) {
      throw ArgumentError('Unsupported stair geometry');
    }
  }

  ArchitectStairDesign copyWith({
    String? rulesVersion,
    StairShape? shape,
    StairCode? code,
    StairUse? use,
    StairEvacuation? evacuation,
    double? rise,
    double? startOffset,
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
    bool? winderSteps,
    bool? cornerRiser,
    int? manualWinderSteps,
    bool autoWinderSteps = false,
    double? manualWinderRadius,
    bool autoWinderRadius = false,
    bool? turnLeft,
    bool? isDraft,
    bool? showRailing,
    bool? showLabel,
    double? guardHeight,
    double? handrailHeight,
    double? concreteThickness,
    double? finishThickness,
    double? nosingProjection,
  }) => ArchitectStairDesign(
    rulesVersion: rulesVersion ?? this.rulesVersion,
    shape: shape ?? this.shape,
    code: code ?? this.code,
    use: use ?? this.use,
    evacuation: evacuation ?? this.evacuation,
    rise: rise ?? this.rise,
    startOffset: startOffset ?? this.startOffset,
    followStoreys: followStoreys ?? this.followStoreys,
    upperStoreyId: clearUpperStorey
        ? null
        : upperStoreyId ?? this.upperStoreyId,
    manualRisers: autoRisers ? null : manualRisers ?? this.manualRisers,
    manualGoing: autoGoing ? null : manualGoing ?? this.manualGoing,
    landingDepth: landingDepth ?? this.landingDepth,
    innerRadius: innerRadius ?? this.innerRadius,
    sweepDegrees:
        sweepDegrees ??
        (shape == StairShape.spiralOverlap && this.sweepDegrees <= 360
            ? 375
            : shape != null &&
                  shape != StairShape.spiralOverlap &&
                  this.sweepDegrees > 360
            ? 270
            : this.sweepDegrees),
    winderSteps: winderSteps ?? this.winderSteps,
    cornerRiser: cornerRiser ?? this.cornerRiser,
    manualWinderSteps: autoWinderSteps
        ? null
        : manualWinderSteps ?? this.manualWinderSteps,
    manualWinderRadius: autoWinderRadius
        ? null
        : manualWinderRadius ?? this.manualWinderRadius,
    turnLeft: turnLeft ?? this.turnLeft,
    isDraft: isDraft ?? this.isDraft,
    showRailing: showRailing ?? this.showRailing,
    showLabel: showLabel ?? this.showLabel,
    guardHeight: guardHeight ?? this.guardHeight,
    handrailHeight: handrailHeight ?? this.handrailHeight,
    concreteThickness: concreteThickness ?? this.concreteThickness,
    finishThickness: finishThickness ?? this.finishThickness,
    nosingProjection: nosingProjection ?? this.nosingProjection,
  );

  Map<String, dynamic> toJson() => {
    'rulesVersion': rulesVersion,
    'shape': shape.name,
    'code': code.name,
    'use': use.name,
    'evacuation': evacuation.name,
    'rise': rise,
    'startOffset': startOffset,
    'followStoreys': followStoreys,
    'upperStoreyId': upperStoreyId,
    'manualRisers': manualRisers,
    'manualGoing': manualGoing,
    'landingDepth': landingDepth,
    'innerRadius': innerRadius,
    'sweepDegrees': sweepDegrees,
    'winderSteps': winderSteps,
    'cornerRiser': cornerRiser,
    'manualWinderSteps': manualWinderSteps,
    'manualWinderRadius': manualWinderRadius,
    'turnLeft': turnLeft,
    'isDraft': isDraft,
    'showRailing': showRailing,
    'showLabel': showLabel,
    'guardHeight': guardHeight,
    'handrailHeight': handrailHeight,
    'concreteThickness': concreteThickness,
    'finishThickness': finishThickness,
    'nosingProjection': nosingProjection,
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
      startOffset: (json['startOffset'] as num?)?.toDouble() ?? 0,
      followStoreys: json['followStoreys'] as bool? ?? true,
      upperStoreyId: json['upperStoreyId'] as String?,
      manualRisers: (json['manualRisers'] as num?)?.toInt(),
      manualGoing: (json['manualGoing'] as num?)?.toDouble(),
      landingDepth: (json['landingDepth'] as num?)?.toDouble() ?? 1.2,
      innerRadius: (json['innerRadius'] as num?)?.toDouble() ?? .6,
      sweepDegrees: (json['sweepDegrees'] as num?)?.toDouble(),
      winderSteps: json['winderSteps'] as bool? ?? false,
      cornerRiser: json['cornerRiser'] as bool? ?? false,
      manualWinderSteps: (json['manualWinderSteps'] as num?)?.toInt(),
      manualWinderRadius: (json['manualWinderRadius'] as num?)?.toDouble(),
      turnLeft: json['turnLeft'] as bool? ?? false,
      isDraft: json['isDraft'] as bool? ?? false,
      showRailing: json['showRailing'] as bool? ?? true,
      showLabel: json['showLabel'] as bool? ?? true,
      guardHeight: (json['guardHeight'] as num?)?.toDouble() ?? 1.2,
      handrailHeight: (json['handrailHeight'] as num?)?.toDouble() ?? .9,
      concreteThickness: (json['concreteThickness'] as num?)?.toDouble() ?? .15,
      finishThickness: (json['finishThickness'] as num?)?.toDouble() ?? .02,
      nosingProjection: (json['nosingProjection'] as num?)?.toDouble() ?? .03,
    );
    result.validate();
    return result;
  }
}

/// Shared by committed drawing, preview, picking, snapping and selection.
class ArchitectStairSurface {
  final List<Offset> polygon;
  final double elevation;

  /// Unfinished sloping reference heights, before subtracting finish/waist.
  final List<double>? slopeBase;
  final bool startsTread;
  const ArchitectStairSurface(
    this.polygon,
    this.elevation, {
    this.slopeBase,
    this.startsTread = false,
  });
}

class ArchitectStairPlan {
  final List<List<Offset>> footprints;
  final List<(Offset, Offset)> nosings;
  final List<Offset> walkingLine;
  final List<ArchitectStairSurface> surfaces;
  ArchitectStairPlan(
    this.footprints,
    this.nosings,
    this.walkingLine, [
    this.surfaces = const [],
  ]);
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
    return Rect.fromLTRB(
      points.map((p) => p.dx).reduce(math.min),
      points.map((p) => p.dy).reduce(math.min),
      points.map((p) => p.dx).reduce(math.max),
      points.map((p) => p.dy).reduce(math.max),
    );
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
    if (design.hasWinders) return _winders(width, design, world);
    final footprints = <List<Offset>>[],
        nosings = <(Offset, Offset)>[],
        walk = <Offset>[];
    final surfaces = <ArchitectStairSurface>[];
    void surface(List<Offset> points, double elevation) => surfaces.add(
      ArchitectStairSurface(points.map(world).toList(), elevation),
    );
    void polygon(List<Offset> points) =>
        footprints.add(points.map(world).toList());
    void line(Offset a, Offset b) => nosings.add((world(a), world(b)));
    if (design.isSpiral) {
      final inner = design.innerRadius,
          outer = inner + width,
          mid = inner + width / 2;
      Offset radial(double r, double angle) =>
          Offset(r * math.sin(angle), mid - r * math.cos(angle));
      final count = math.max(48, (design.sweepDegrees * 2).ceil());
      final sweep = design.sweepDegrees * math.pi / 180;
      // A plan footprint is an annulus once the stair exceeds one turn; an
      // endlessly wound polygon would cancel itself through its fill rule.
      final footprintSweep = math.min(2 * math.pi, sweep);
      polygon([
        for (var i = 0; i <= count; i++)
          radial(outer, footprintSweep * i / count),
        for (var i = count; i >= 0; i--)
          radial(inner, footprintSweep * i / count),
      ]);
      for (var i = 0; i < design.risers; i++) {
        line(
          radial(inner, design.anglePerGoing * i),
          radial(outer, design.anglePerGoing * i),
        );
        if (i < design.risers - 1) {
          // Small quads follow the curved edges in the 3D presentation.
          const slices = ArchitectStairDesign.spiralSlicesPerGoing;
          for (var s = 0; s < slices; s++) {
            final a = design.anglePerGoing * (i + s / slices);
            final b = design.anglePerGoing * (i + (s + 1) / slices);
            surface([
              radial(inner, a),
              radial(outer, a),
              radial(outer, b),
              radial(inner, b),
            ], (i + 1) * design.riser);
          }
        }
      }
      final symbolSweep = design.shape == StairShape.spiralOverlap
          ? 5 * math.pi / 3
          : sweep;
      walk.addAll([
        for (var i = 0; i <= count; i++)
          world(radial(mid, symbolSweep * i / count)),
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
            surface([
              p - normal * width / 2,
              next - normal * width / 2,
              next + normal * width / 2,
              p + normal * width / 2,
            ], (climbed + i + 1) * design.riser);
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

  static ArchitectStairPlan _winders(
    double width,
    ArchitectStairDesign d,
    Offset Function(Offset) world,
  ) {
    final layout = d.winderLayout(width), r = layout.radius;
    final count = layout.perQuarter * d.turnQuarters;
    final straight = d.risers - 1 - count;
    final lead = straight ~/ 2, tail = straight - lead;
    final run = lead * d.going, mid = r + width / 2;
    final sweep = d.turnQuarters * math.pi / 2;
    final footprints = <List<Offset>>[],
        surfaces = <ArchitectStairSurface>[],
        nosings = <(Offset, Offset)>[],
        walking = <Offset>[];
    Offset inner(double angle) =>
        Offset(run + r * math.sin(angle), mid - r * math.cos(angle));
    Offset outer(double angle) {
      final radius =
          (r + width) / math.max(math.sin(angle).abs(), math.cos(angle).abs());
      return Offset(
        run + radius * math.sin(angle),
        mid - radius * math.cos(angle),
      );
    }

    void line(Offset a, Offset b) => nosings.add((world(a), world(b)));
    void polygon(List<Offset> p) => footprints.add(p.map(world).toList());
    void patch(List<Offset> p, int step, double a, double b, bool first) {
      surfaces.add(
        ArchitectStairSurface(
          p.map(world).toList(),
          (step + 1) * d.riser,
          slopeBase: [a * d.riser, a * d.riser, b * d.riser, b * d.riser],
          startsTread: first,
        ),
      );
    }

    polygon([
      Offset(0, -width / 2),
      Offset(run, -width / 2),
      Offset(run, width / 2),
      Offset(0, width / 2),
    ]);
    for (var i = 0; i <= lead; i++) {
      final x = i * d.going;
      line(Offset(x, width / 2), Offset(x, -width / 2));
      if (i < lead) {
        patch(
          [
            Offset(x, width / 2),
            Offset(x, -width / 2),
            Offset(x + d.going, -width / 2),
            Offset(x + d.going, width / 2),
          ],
          i,
          i.toDouble(),
          i + 1.0,
          true,
        );
      }
    }
    // Include the exact square outer corners in the tessellation. The middle
    // tread crosses them by default, rather than splitting at the corner.
    List<double> angles(double a, double b) {
      final values = <double>[a, b];
      for (var i = 1; i < 8; i++) {
        values.add(a + (b - a) * i / 8);
      }
      for (final corner in [math.pi / 4, 3 * math.pi / 4]) {
        if (corner > a + 1e-9 && corner < b - 1e-9) values.add(corner);
      }
      values.sort();
      return [
        for (var i = 0; i < values.length; i++)
          if (i == 0 || values[i] - values[i - 1] > 1e-9) values[i],
      ];
    }

    final outline = angles(0, sweep);
    // Dense inner arc; square outer faces are exact between their corners.
    final allAngles = <double>{
      ...outline,
      for (var i = 0; i <= count * 8; i++) sweep * i / (count * 8),
    }.toList()..sort();
    polygon([
      for (final a in allAngles) outer(a),
      for (final a in allAngles.reversed) inner(a),
    ]);
    walking.addAll([world(Offset.zero), world(Offset(run, 0))]);
    for (var j = 0; j < count; j++) {
      final from = j * layout.angle, to = (j + 1) * layout.angle;
      final slices = angles(from, to);
      for (var k = 0; k < slices.length - 1; k++) {
        final a = slices[k], b = slices[k + 1];
        patch(
          [inner(a), outer(a), outer(b), inner(b)],
          lead + j,
          lead + a / layout.angle,
          lead + b / layout.angle,
          k == 0,
        );
      }
      line(inner(to), outer(to));
    }
    walking.addAll([
      for (final angle in allAngles.skip(1))
        world(Offset(run + mid * math.sin(angle), mid - mid * math.cos(angle))),
    ]);
    final end = Offset(
      run + mid * math.sin(sweep),
      mid - mid * math.cos(sweep),
    );
    final axis = Offset(math.cos(sweep), math.sin(sweep));
    final normal = Offset(-axis.dy, axis.dx);
    Offset at(double t, double side) => end + axis * t + normal * side;
    polygon([
      at(0, width / 2),
      at(0, -width / 2),
      at(tail * d.going, -width / 2),
      at(tail * d.going, width / 2),
    ]);
    for (var j = 0; j < tail; j++) {
      final step = lead + count + j;
      patch(
        [
          at(j * d.going, width / 2),
          at(j * d.going, -width / 2),
          at((j + 1) * d.going, -width / 2),
          at((j + 1) * d.going, width / 2),
        ],
        step,
        step.toDouble(),
        step + 1.0,
        true,
      );
      line(at((j + 1) * d.going, width / 2), at((j + 1) * d.going, -width / 2));
    }
    walking.add(world(end + axis * (tail * d.going)));
    return ArchitectStairPlan(footprints, nosings, walking, surfaces);
  }
}
