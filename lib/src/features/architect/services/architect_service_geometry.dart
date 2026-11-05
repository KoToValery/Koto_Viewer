import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import '../components/definitions/service_components.dart';
import '../models/architect_project.dart';
import '../models/architect_contour.dart';
import '../rendering/architect_path_solid.dart';
import '../rendering/architect_vertical_clip.dart';
import '../../cad_3d/models/mesh_3d.dart';

typedef ArchitectRoofPenetration = ({
  ArchitectStorey owner,
  ArchitectComponentInstance component,
  ArchitectComponentInstance profile,
  Path footprint,
  Path opening,
  double base,
  double top,
});

/// One persisted source supplies every plan, penetration and construction view.
class ArchitectServiceGeometry {
  static final _resolved =
      Expando<Map<ArchitectComponentInstance, Map<String, dynamic>>>();

  static bool hasRoofOutlet(ArchitectComponentInstance c) =>
      ServiceComponentDefinition.hasRoofOutlet(c.definitionId);

  static Map<String, dynamic> _native(ArchitectComponentInstance c) => {
    'width': c.width,
    'depth': c.depth,
    'height': c.height,
    ...?ServiceComponentDefinition.fromId(c.definitionId)?.defaultParameters,
    ...c.parameters,
  };

  static double baseElevation(
    ArchitectProject project,
    ArchitectStorey owner,
    ArchitectComponentInstance c,
  ) {
    var datum = owner.elevation;
    if (ServiceComponentDefinition.continuousIds.contains(c.definitionId) &&
        _native(c)['allStoreys'] != false) {
      for (final floor in project.storeys.where((s) => !s.isRoof)) {
        datum = math.min(datum, floor.elevation);
      }
    }
    return datum + c.elevationOffset;
  }

  static Map<String, dynamic> parameters(
    ArchitectProject project,
    ArchitectStorey owner,
    ArchitectComponentInstance c,
  ) => (_resolved[project] ??= {})[c] ??= _parameters(project, owner, c);

  static Map<String, dynamic> _parameters(
    ArchitectProject project,
    ArchitectStorey owner,
    ArchitectComponentInstance c,
  ) {
    final params = _native(c);
    if (!hasRoofOutlet(c) || params['autoHeight'] == false) return params;
    final base = baseElevation(project, owner, c);
    final clearance = (params['aboveRoof'] as num?)?.toDouble() ?? .50;
    double? roofTop;
    final path = footprint(c, stack: c.definitionId == 'service_fireplace');
    for (final floor in project.storeys) {
      for (final roof in floor.roofs) {
        final overlap = Path.combine(
          PathOperation.intersect,
          Path()..addPolygon(roof.points, true),
          path,
        );
        for (final point in ArchitectPathSolid.contours(
          overlap,
        ).expand((p) => p)) {
          final top = floor.elevation + roof.topElevationAt(point);
          if (top >= base && (roofTop == null || top > roofTop)) roofTop = top;
        }
      }
    }
    // Before a roof is drawn, continue through the highest occupied floor.
    final fallback = project.storeys
        .where((s) => !s.isRoof)
        .fold<double>(
          owner.elevation + owner.height,
          (top, floor) => math.max(top, floor.elevation + floor.height),
        );
    final height = math.max(.02, (roofTop ?? fallback) + clearance - base);
    if (c.definitionId == 'service_fireplace') {
      params['stackHeight'] = math.max(0, height - (params['height'] as num));
    } else {
      params['height'] = height;
      if (c.definitionId == 'service_combinedRiser') {
        params['waterHeight'] = math.max(
          .02,
          (roofTop ?? fallback) - base - .20,
        );
      }
    }
    return params;
  }

  static double topElevation(
    ArchitectProject project,
    ArchitectStorey owner,
    ArchitectComponentInstance c,
  ) {
    final params = parameters(project, owner, c);
    return baseElevation(project, owner, c) +
        (params['height'] as num).toDouble() +
        (c.definitionId == 'service_fireplace'
            ? (params['stackHeight'] as num).toDouble()
            : 0);
  }

  static Float64List transform(ArchitectComponentInstance c) {
    final a = math.cos(c.rotation), b = math.sin(c.rotation);
    return Float64List.fromList([
      a,
      b,
      0,
      0,
      -b,
      a,
      0,
      0,
      0,
      0,
      1,
      0,
      c.position.dx,
      c.position.dy,
      0,
      1,
    ]);
  }

  static ArchitectComponentInstance stackInstance(
    ArchitectComponentInstance c,
  ) => c.copyWith(
    definitionId: 'service_chimney',
    parameters: {
      ...ServiceComponentDefinition(
        ServiceComponentKind.chimney,
      ).defaultParameters,
      ...c.parameters,
      'width': .36,
      'depth': .36,
    },
    position:
        c.position +
        Offset(-math.sin(c.rotation), math.cos(c.rotation)) *
            (c.depth * .30 - .18),
  );

  static Path footprint(
    ArchitectComponentInstance c, {
    double clearance = 0,
    bool stack = false,
  }) {
    if (stack && c.definitionId == 'service_fireplace') {
      return footprint(stackInstance(c), clearance: clearance);
    }
    final round = {
      'service_sewer',
      'service_vent',
      'service_water',
      'service_dryRiser',
      'service_sleeve',
    }.contains(c.definitionId);
    final local = round
        ? ServiceComponentDefinition.circle(
            Offset(0, c.depth / 2),
            math.min(c.width, c.depth) / 2 + clearance,
          )
        : (Path()..addRect(c.localBounds.inflate(clearance)));
    return local.transform(transform(c));
  }

  /// Projections are transient. They neither duplicate the source in project
  /// JSON nor emit another 3D solid on each floor.
  static Iterable<ArchitectComponentInstance> componentsOnLevel(
    ArchitectProject project,
    ArchitectStorey level,
  ) sync* {
    final emitted = <String>{};
    for (final owner in project.storeys) {
      for (final c in owner.components) {
        if (!c.isVisible || !c.isServiceComponent) continue;
        final base = baseElevation(project, owner, c);
        final top = topElevation(project, owner, c);
        var visible =
            base <= level.elevation + level.cutPlaneHeight + .001 &&
            top >= level.elevation - .001;
        if (level.isRoof && hasRoofOutlet(c)) {
          visible = project.storeys.any(
            (s) => s.roofs.any(
              (r) => penetrations(
                project,
                s,
                r,
              ).any((p) => p.component.id == c.id),
            ),
          );
        }
        if (!visible || !emitted.add(c.id)) continue;
        if (c.definitionId == 'service_fireplace' &&
            (level.isRoof || level.elevation >= base + c.height - .001)) {
          yield stackInstance(c);
        } else {
          yield c.copyWith(
            parameters: {
              ...parameters(project, owner, c),
              'planHeight': level.isRoof
                  ? top - base
                  : level.elevation + level.cutPlaneHeight - base,
            },
          );
        }
      }
    }
  }

  static List<ArchitectRoofPenetration> penetrations(
    ArchitectProject project,
    ArchitectStorey roofStorey,
    ArchitectRoofPlane roof,
  ) {
    final result = <ArchitectRoofPenetration>[];
    final roofPath = ArchitectContour.path(roof.points, roof.holes);
    for (final owner in project.storeys) {
      for (final c in owner.components) {
        if (!c.isVisible || !c.isServiceComponent) continue;
        final params = parameters(project, owner, c);
        final base = baseElevation(project, owner, c);
        final top = topElevation(project, owner, c);
        var profile = c;
        if (c.definitionId == 'service_fireplace') {
          final overlap = Path.combine(
            PathOperation.intersect,
            roofPath,
            footprint(c),
          );
          final underside = ArchitectPathSolid.contours(overlap)
              .expand((p) => p)
              .fold<double>(
                double.infinity,
                (low, p) => math.min(
                  low,
                  roofStorey.elevation + roof.undersideElevationAt(p),
                ),
              );
          if (underside >= base + c.height - .001) profile = stackInstance(c);
        }
        final body = footprint(profile);
        final clearance = (params['roofClearance'] as num?)?.toDouble() ?? 0;
        var cut = Path.combine(
          PathOperation.intersect,
          roofPath,
          footprint(profile, clearance: clearance),
        );
        cut = ArchitectVerticalClip.positive(
          cut,
          (p) => roofStorey.elevation + roof.topElevationAt(p) - base,
        );
        cut = ArchitectVerticalClip.positive(
          cut,
          (p) => top - roofStorey.elevation - roof.undersideElevationAt(p),
        );
        if (!cut.getBounds().isEmpty) {
          result.add((
            owner: owner,
            component: c,
            profile: profile,
            footprint: body,
            opening: cut,
            base: base,
            top: top,
          ));
        }
      }
    }
    return result;
  }

  static List<Triangle3D> flashing(
    ArchitectProject project,
    ArchitectStorey owner,
    ArchitectComponentInstance c,
  ) {
    if (!hasRoofOutlet(c) || !c.isVisible) return const [];
    final params = parameters(project, owner, c);
    final clearance = (params['roofClearance'] as num?)?.toDouble() ?? .02;
    final result = <Triangle3D>[];
    for (final floor in project.storeys) {
      for (final roof in floor.roofs) {
        final penetration = penetrations(
          project,
          floor,
          roof,
        ).where((p) => p.component.id == c.id).firstOrNull;
        if (penetration == null) continue;
        final apron = Path.combine(
          PathOperation.difference,
          footprint(penetration.profile, clearance: clearance + .10),
          footprint(penetration.profile),
        );
        final path = Path.combine(
          PathOperation.intersect,
          apron,
          ArchitectContour.path(roof.points, roof.holes),
        );
        double level(Offset p) =>
            floor.elevation + roof.topElevationAt(p) + .004;
        result.addAll(
          ArchitectPathSolid.between(
            path,
            level,
            (p) => level(p) + .008,
            const Color(0xffa4aaac),
          ),
        );
        final upstand = Path.combine(
          PathOperation.intersect,
          path,
          footprint(penetration.profile, clearance: .008),
        );
        result.addAll(
          ArchitectPathSolid.between(
            upstand,
            (p) => level(p) + .008,
            (p) => level(p) + .15,
            const Color(0xffa4aaac),
          ),
        );
      }
    }
    return result;
  }

  /// Ventilation bodies end with a raised, open-sided rain hood. Sewer risers
  /// and separate vents retain their full open bore above the weather collar.
  static List<Triangle3D> terminal(
    ArchitectProject project,
    ArchitectStorey owner,
    ArchitectComponentInstance c,
  ) {
    if (!hasRoofOutlet(c) ||
        ServiceComponentDefinition.hasSmokeFlue(c.definitionId) ||
        parameters(project, owner, c)['autoHeight'] == false) {
      return const [];
    }
    if (c.definitionId == 'service_sewer' || c.definitionId == 'service_vent') {
      return const [];
    }
    final body = footprint(c, clearance: -.025);
    final head = footprint(c, clearance: .055);
    final top = topElevation(project, owner, c);
    final result = <Triangle3D>[];
    const steel = Color(0xffb7bdc0);
    result.addAll(
      ArchitectPathSolid.extrude(
        Path.combine(PathOperation.difference, head, body),
        top,
        top + .025,
        steel,
      ),
    );
    for (final corner in c.worldPolygonCorners) {
      final post = Path()
        ..addRect(Rect.fromCenter(center: corner, width: .018, height: .018));
      result.addAll(
        ArchitectPathSolid.extrude(post, top + .025, top + .18, steel),
      );
    }
    result.addAll(
      ArchitectPathSolid.extrude(head, top + .18, top + .205, steel),
    );
    return result;
  }

  static List<List<Offset>> slabHoles(
    ArchitectStorey storey, {
    ArchitectProject? project,
    double? bottom,
    double? top,
  }) {
    final result = <List<Offset>>[];
    for (final owner in project?.storeys ?? [storey]) {
      for (final c in owner.components) {
        if (!c.isServiceComponent || !c.isVisible) continue;
        final params = project == null
            ? _native(c)
            : parameters(project, owner, c);
        final datum = (project == null
            ? owner.elevation + c.elevationOffset
            : baseElevation(project, owner, c));
        final fireplace = c.definitionId == 'service_fireplace';
        final base = datum + (fireplace ? .0011 : 0);
        final end = project == null
            ? owner.elevation +
                  c.elevationOffset +
                  (params['height'] as num).toDouble() +
                  ((params['stackHeight'] as num?)?.toDouble() ?? 0)
            : topElevation(project, owner, c);
        if (bottom != null && end < bottom - .001 ||
            top != null && base > top + .001) {
          continue;
        }
        final stackOnly =
            !fireplace || bottom == null || bottom >= datum + c.height - .001;
        result.addAll(
          ArchitectPathSolid.contours(footprint(c, stack: stackOnly)),
        );
      }
    }
    return result;
  }
}
