import 'dart:math' as math;
import 'dart:ui';
import '../../../cad_3d/models/mesh_3d.dart';
import '../../models/architect_component.dart';
import '../../models/architect_component_definition.dart';
import '../../rendering/architect_path_solid.dart';
import '../../rendering/architect_mesh_boolean.dart';

enum ServiceComponentKind {
  ventSingle,
  ventDouble,
  ventTransition,
  compactVent,
  compactTransition,
  combinedRiser,
  sewer,
  water,
  dryRiser,
  sleeve,
  chimney,
  vent,
  fireplace,
}

/// Nominal catalog envelopes; see docs/architect_services_2026_11_05.md.
/// Product names and explanations are supplied by ARB at the presentation layer.
class ServiceComponentDefinition extends ArchitectComponentDefinition {
  final ServiceComponentKind kind;
  ServiceComponentDefinition(this.kind);

  static const continuousIds = {
    'service_ventSingle',
    'service_ventDouble',
    'service_compactVent',
    'service_combinedRiser',
    'service_sewer',
    'service_vent',
    'service_chimney',
  };
  static bool hasRoofOutlet(String id) =>
      continuousIds.contains(id) || id == 'service_fireplace';
  static bool hasSmokeFlue(String id) =>
      id == 'service_chimney' || id == 'service_fireplace';
  static ServiceComponentDefinition? fromId(String id) {
    for (final kind in ServiceComponentKind.values) {
      if ('service_${kind.name}' == id) return ServiceComponentDefinition(kind);
    }
    return null;
  }

  static List<ServiceComponentDefinition> catalog() => [
    for (final kind in ServiceComponentKind.values)
      ServiceComponentDefinition(kind),
  ];

  @override
  String get id => 'service_${kind.name}';
  @override
  String get defaultName => id;
  @override
  ArchitectComponentCategory get category =>
      ArchitectComponentCategory.services;
  @override
  ComponentPlacementMode get placementMode =>
      ComponentPlacementMode.freeStanding;
  @override
  bool get defaultVisibleInSection => true;

  (double, double, double) get nominalSize => switch (kind) {
    ServiceComponentKind.ventSingle => (.30, .25, 2.80),
    ServiceComponentKind.ventDouble => (.50, .30, 2.80),
    ServiceComponentKind.ventTransition => (.50, .30, .40),
    ServiceComponentKind.compactVent => (.355, .22, 2.64),
    ServiceComponentKind.compactTransition => (.355, .22, .33),
    ServiceComponentKind.combinedRiser => (.50, .25, 2.80),
    ServiceComponentKind.sewer => (.11, .11, 2.80),
    ServiceComponentKind.water => (.032, .032, 2.80),
    ServiceComponentKind.dryRiser => (.1143, .1143, 2.80),
    ServiceComponentKind.sleeve => (.16, .16, .20),
    ServiceComponentKind.chimney => (.36, .36, 3.60),
    ServiceComponentKind.vent => (.11, .11, 2.80),
    ServiceComponentKind.fireplace => (.55, .60, 2.64),
  };

  (double, double) footprint([Map<String, dynamic>? params]) {
    final w = (params?['width'] as num?)?.toDouble() ?? nominalSize.$1;
    final d = (params?['depth'] as num?)?.toDouble() ?? nominalSize.$2;
    return (w, d);
  }

  @override
  List<ParametricFieldSchema> get schema => [
    for (final entry in {
      'width': nominalSize.$1,
      'depth': nominalSize.$2,
      'height': nominalSize.$3,
    }.entries)
      ParametricFieldSchema(
        key: entry.key,
        label: entry.key,
        defaultValue: entry.value,
        min: .02,
        max: entry.key == 'height' ? 100 : 5,
      ),
  ];

  @override
  Map<String, dynamic> get defaultParameters => {
    ...super.defaultParameters,
    'visibleInSection': true,
    if (hasRoofOutlet(id)) ...{
      'allStoreys': continuousIds.contains(id),
      'aboveRoof': hasSmokeFlue(id) ? .80 : .50,
      'roofClearance': hasSmokeFlue(id) ? .05 : .02,
      'autoHeight': true,
    },
    if (hasSmokeFlue(id)) ...{'flueDiameter': .18, 'capType': 1},
    if (kind == ServiceComponentKind.fireplace) 'stackHeight': 0.0,
  };

  /// Service dimensions are native parameters: resizing must preserve wall and
  /// pipe thicknesses, circular bores and the independently selected roof head.
  @override
  CachedComponentGeometry resolveGeometry(Map<String, dynamic> params) =>
      generateGeometry({...defaultParameters, ...params});

  static Path circle(Offset center, double radius, {int segments = 32}) =>
      Path()..addPolygon([
        for (var i = 0; i < segments; i++)
          center +
              Offset(
                    math.cos(i * 2 * math.pi / segments),
                    math.sin(i * 2 * math.pi / segments),
                  ) *
                  radius,
      ], true);

  @override
  CachedComponentGeometry generateGeometry(Map<String, dynamic> params) {
    final p = {...defaultParameters, ...params};
    double value(String key) => (p[key] as num).toDouble();
    final w = value('width'), d = value('depth'), h = value('height');
    if ([w, d, h].any((n) => !n.isFinite || n < .02) ||
        h > 100 ||
        w > 5 ||
        d > 5) {
      throw const FormatException('Invalid service dimensions');
    }
    const concrete = Color(0xffd6d4cf), steel = Color(0xffafb7bc);
    final rect = Rect.fromLTRB(-w / 2, 0, w / 2, d);
    final outer = Path()..addRect(rect);
    final center = Offset(0, d / 2);
    final triangles = <Triangle3D>[], details = <Path>[];
    final openings = <Path>[];
    Path outline = outer, mask = outer;
    void solid(Path path, double bottom, double top, Color color) {
      triangles.addAll(
        ArchitectPathSolid.extrude(
          path,
          bottom,
          top,
          color,
          contourTolerance: math.min(.0001, math.min(w, d) * .001),
        ),
      );
    }

    Path minus(Path a, Path b) => Path.combine(PathOperation.difference, a, b);
    void pipe(
      Offset at,
      double diameter,
      double thickness,
      Color color, {
      double bottom = 0,
      double? top,
      bool planVisible = true,
    }) {
      final outside = circle(at, diameter / 2);
      final inside = circle(at, diameter / 2 - thickness);
      solid(minus(outside, inside), bottom, top ?? h, color);
      if (planVisible) {
        details.addAll([outside, inside]);
        openings.add(inside);
      }
    }

    switch (kind) {
      case ServiceComponentKind.ventSingle:
      case ServiceComponentKind.ventDouble:
      case ServiceComponentKind.ventTransition:
      case ServiceComponentKind.compactVent:
      case ServiceComponentKind.compactTransition:
        final compact =
            kind == ServiceComponentKind.compactVent ||
            kind == ServiceComponentKind.compactTransition;
        final transition =
            kind == ServiceComponentKind.ventTransition ||
            kind == ServiceComponentKind.compactTransition;
        final single = kind == ServiceComponentKind.ventSingle;
        final wall = compact ? .025 : .04;
        if (w <= wall * (single ? 2 : 3) + .04 || d <= wall * 2 + .04) {
          throw const FormatException('Ventilation body is too small');
        }
        final inner = rect.deflate(wall);
        final shell = minus(outer, Path()..addRect(inner));
        if (single) {
          solid(shell, 0, h, concrete);
          details.add(Path()..addRect(inner));
          openings.add(Path()..addRect(inner));
        } else {
          // LS 1: 200×170 main channel + 90×170 branch in 355×220.
          final web = compact ? .015 : wall;
          final dividerX = compact
              ? inner.left + (inner.width - web) * (20 / 29) + web / 2
              : 0.0;
          final divider = Rect.fromLTRB(
            dividerX - web / 2,
            inner.top,
            dividerX + web / 2,
            inner.bottom,
          );
          final body = Path.combine(
            PathOperation.union,
            shell,
            Path()..addRect(divider),
          );
          if (transition) {
            // Two complementary transition courses keep the main channel open
            // while the branch rises across the separating web. No solid plug.
            final openingBottom = h * .25, openingTop = h * .75;
            solid(body, 0, openingBottom, concrete);
            solid(shell, openingBottom, openingTop, concrete);
            solid(body, openingTop, h, concrete);
          } else {
            solid(body, 0, h, concrete);
          }
          details.addAll([
            Path()..addRect(
              Rect.fromLTRB(inner.left, inner.top, divider.left, inner.bottom),
            ),
            Path()..addRect(
              Rect.fromLTRB(
                divider.right,
                inner.top,
                inner.right,
                inner.bottom,
              ),
            ),
            if (transition)
              Path()
                ..moveTo(divider.left - wall, center.dy - wall)
                ..lineTo(divider.left - wall, center.dy + wall)
                ..lineTo(divider.right + wall, center.dy + wall),
          ]);
          openings.addAll([
            Path()..addRect(
              Rect.fromLTRB(inner.left, inner.top, divider.left, inner.bottom),
            ),
            Path()..addRect(
              Rect.fromLTRB(
                divider.right,
                inner.top,
                inner.right,
                inner.bottom,
              ),
            ),
          ]);
        }
      case ServiceComponentKind.combinedRiser:
        if (w < .40 || d < .20) {
          throw const FormatException('Combined riser is too small');
        }
        final inner = rect.deflate(.025);
        var shaftVoid = Path()..addRect(inner);
        shaftVoid = minus(shaftVoid, circle(Offset(-w * .27, d * .5), .055));
        shaftVoid = minus(shaftVoid, circle(Offset(w * .03, d * .5), .025));
        for (final y in [d * .30, d * .70]) {
          shaftVoid = minus(shaftVoid, circle(Offset(w * .31, y), .026));
        }
        openings.add(shaftVoid);
        solid(
          minus(outer, Path()..addRect(inner)),
          0,
          h,
          const Color(0xffecebe5),
        );
        details.add(Path()..addRect(inner));
        pipe(Offset(-w * .27, d * .5), .11, .003, const Color(0xff999c9c));
        pipe(Offset(w * .03, d * .5), .05, .002, const Color(0xff999c9c));
        final waterHeight = (p['waterHeight'] as num?)?.toDouble() ?? h;
        final showWater =
            ((p['planHeight'] as num?)?.toDouble() ?? 0) < waterHeight;
        for (final y in [d * .30, d * .70]) {
          final at = Offset(w * .31, y);
          // Water insulation and pipe remain distinguishable in monochrome.
          final insulation = minus(circle(at, .026), circle(at, .016));
          solid(insulation, 0, waterHeight, const Color(0xffdedbd0));
          if (showWater) details.add(circle(at, .026));
          pipe(
            at,
            .032,
            .004,
            const Color(0xffc1b19a),
            top: waterHeight,
            planVisible: showWater,
          );
        }
        // Inspection cover: two thin parallel rules on the front casing.
        details.add(
          Path()
            ..moveTo(-w * .28, d - .009)
            ..lineTo(w * .28, d - .009),
        );
      case ServiceComponentKind.sewer:
      case ServiceComponentKind.vent:
      case ServiceComponentKind.water:
      case ServiceComponentKind.dryRiser:
      case ServiceComponentKind.sleeve:
        final diameter = math.min(w, d);
        final thickness = switch (kind) {
          ServiceComponentKind.water => math.min(.004, diameter * .12),
          ServiceComponentKind.dryRiser => math.min(.0045, diameter * .10),
          ServiceComponentKind.sleeve => math.min(.006, diameter * .08),
          _ => math.min(.003, diameter * .10),
        };
        outline = mask = circle(center, diameter / 2);
        pipe(center, diameter, thickness, steel);
        if (kind == ServiceComponentKind.dryRiser) {
          // Opposed unlettered ticks distinguish the fire service in plan.
          for (final sign in [-1, 1]) {
            details.add(
              Path()
                ..moveTo(sign * diameter * .2, center.dy - diameter * .18)
                ..lineTo(sign * diameter * .2, center.dy + diameter * .18),
            );
          }
        }
      case ServiceComponentKind.fireplace:
        if (w < .45 || d < .45 || h < 1.8) {
          throw const FormatException('Fireplace enclosure is too small');
        }
        final flue = value('flueDiameter');
        if (!flue.isFinite || flue < .08 || flue > .22) {
          throw const FormatException('Invalid fireplace flue');
        }
        final flueCenter = Offset(0, d * .30);
        final baseTop = h * .10, fireTop = h * .57;
        final chamber = Rect.fromLTRB(-w * .36, d * .15, w * .36, d);
        solid(outer, 0, baseTop, concrete);
        solid(
          minus(outer, Path()..addRect(chamber)),
          baseTop,
          fireTop,
          concrete,
        );
        solid(minus(outer, circle(flueCenter, flue / 2)), fireTop, h, concrete);
        // Recessed glazed fire door and a thin metal frame. The combustion
        // chamber remains a genuine cavity in both model and sections.
        final frame = .018;
        for (final x in [chamber.left, chamber.right - frame]) {
          solid(
            Path()..addRect(Rect.fromLTWH(x, d - .025, frame, .025)),
            baseTop,
            fireTop,
            steel,
          );
        }
        final front = Path()
          ..addRect(Rect.fromLTRB(chamber.left, d - .025, chamber.right, d));
        solid(front, baseTop, baseTop + frame, steel);
        solid(front, fireTop - frame, fireTop, steel);
        solid(
          Path()..addRect(
            Rect.fromLTRB(
              chamber.left + frame,
              d - .018,
              chamber.right - frame,
              d - .014,
            ),
          ),
          baseTop + frame,
          fireTop - frame,
          const Color(0xffd8dfe0),
        );
        for (var i = 0; i < 5; i++) {
          final x = chamber.left + .04 + (chamber.width - .08) * i / 4;
          solid(
            Path()..addRect(Rect.fromLTWH(x, d * .25, .012, d * .50)),
            baseTop + .015,
            baseTop + .035,
            steel,
          );
        }
        details.addAll([
          Path()..addRect(chamber),
          circle(flueCenter, flue / 2),
          Path()
            ..moveTo(chamber.left, d - .018)
            ..lineTo(chamber.right, d - .018),
        ]);
        final stackHeight = (p['stackHeight'] as num?)?.toDouble() ?? 0;
        if (stackHeight > .001) {
          final stack = ServiceComponentDefinition(ServiceComponentKind.chimney)
              .resolveGeometry({
                'width': .36,
                'depth': .36,
                'height': stackHeight,
                'flueDiameter': flue,
                'capType': p['capType'],
              });
          final shift = Vector3(0, flueCenter.dy - .18, h);
          final chimneyMesh = [
            for (final t in stack.mesh3d.triangles)
              Triangle3D(
                v0: t.v0 + shift,
                v1: t.v1 + shift,
                v2: t.v2 + shift,
                color: t.color,
                material: t.material,
              ),
          ];
          final joined = ArchitectMeshBoolean.exposedSurfaces([
            triangles,
            chimneyMesh,
          ]);
          triangles.clear();
          triangles.addAll(joined.expand((part) => part));
        }
      case ServiceComponentKind.chimney:
        final flue = value('flueDiameter');
        if (!flue.isFinite || flue < .08 || flue + .12 > math.min(w, d)) {
          throw const FormatException('Flue does not fit chimney envelope');
        }
        final ceramicOuter = flue / 2 + .015;
        final insulationOuter = ceramicOuter + .025;
        final insulation = circle(center, insulationOuter);
        solid(minus(outer, insulation), 0, h, concrete);
        solid(
          minus(insulation, circle(center, ceramicOuter)),
          0,
          h,
          const Color(0xffe3dfcc),
        );
        pipe(center, flue + .03, .015, const Color(0xffbfa58c));
        details.add(insulation);
        final cap = (p['capType'] as num).toInt();
        if (cap < 0 || cap > 3) throw const FormatException('Invalid cap');
        if (cap != 0) {
          // Coping drains outwards, without sealing the smoke path.
          final coping = rect.inflate(.035);
          solid(
            minus(Path()..addRect(coping), circle(center, flue / 2)),
            h,
            h + .035,
            concrete,
          );
          final z = h + .22;
          final head = rect.inflate(.065);
          final hoodRadius = math.sqrt(w * w + d * d) / 2 + .025;
          for (final x in [-w / 2 + .025, w / 2 - .025]) {
            for (final y in [.025, d - .025]) {
              final postTop = switch (cap) {
                2 => z + .005 + .14 * (1 - x.abs() / (head.width / 2)),
                3 =>
                  z +
                      .152 -
                      .16 * Offset(x, y - center.dy).distance / hoodRadius,
                _ => z,
              };
              solid(
                Path()..addRect(
                  Rect.fromCenter(
                    center: Offset(x, y),
                    width: .016,
                    height: .016,
                  ),
                ),
                h + .035,
                postTop,
                steel,
              );
            }
          }
          if (cap == 1) {
            solid(Path()..addRect(head), z, z + .045, concrete);
          } else if (cap == 2) {
            double top(Offset q) =>
                z + .04 + .14 * (1 - q.dx.abs() / (head.width / 2));
            for (final half in [
              Rect.fromLTRB(head.left, head.top, 0, head.bottom),
              Rect.fromLTRB(0, head.top, head.right, head.bottom),
            ]) {
              triangles.addAll(
                ArchitectPathSolid.between(
                  Path()..addRect(half),
                  (q) => top(q) - .035,
                  top,
                  steel,
                ),
              );
            }
          } else {
            // Thin conical rain hood with a ventilated perimeter.
            final radius = hoodRadius;
            for (var i = 0; i < 32; i++) {
              final a = i * 2 * math.pi / 32;
              final b = (i + 1) * 2 * math.pi / 32;
              Vector3 rim(double angle, double dz) => Vector3(
                math.cos(angle) * radius,
                center.dy + math.sin(angle) * radius,
                z + dz,
              );
              triangles.addAll([
                Triangle3D(
                  v0: rim(a, 0),
                  v1: rim(b, 0),
                  v2: Vector3(0, center.dy, z + .16),
                  color: steel,
                ),
                Triangle3D(
                  v0: rim(b, -.008),
                  v1: rim(a, -.008),
                  v2: Vector3(0, center.dy, z + .152),
                  color: steel,
                ),
                Triangle3D(
                  v0: rim(a, -.008),
                  v1: rim(b, -.008),
                  v2: rim(b, 0),
                  color: steel,
                ),
                Triangle3D(
                  v0: rim(a, -.008),
                  v1: rim(b, 0),
                  v2: rim(a, 0),
                  color: steel,
                ),
              ]);
            }
          }
        }
    }
    return CachedComponentGeometry(
      mesh3d: Mesh3D(name: id, triangles: triangles),
      block2d: ArchitectComponentBlock2D(
        boundsMask: mask,
        outline: outline,
        detailPaths: details,
        openingPaths: openings,
        bounds: rect,
      ),
    );
  }
}
