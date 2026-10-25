import 'dart:math' as math;
import 'dart:ui';
import '../../bim_editing/geometry/bim_line_geometry.dart';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../models/architect_project.dart';
import '../models/architect_column.dart';
import 'architect_roof_junctions.dart';
import 'architect_slab_geometry.dart';
import '../rendering/architect_path_solid.dart';

enum ArchitectDownpipeStatus { ready, noFacade, blocked, outsideEaves }

class ArchitectDownpipeRoute {
  final ArchitectDownpipe pipe;
  final ArchitectDownpipeStatus status;
  final List<Vector3> points;
  final Offset inward;
  const ArchitectDownpipeRoute(
    this.pipe,
    this.status,
    this.points,
    this.inward,
  );
  List<double> get angles => [
    for (var i = 1; i + 1 < points.length; i++)
      math.acos(
            ((points[i] - points[i - 1]).normalized().dot(
              (points[i + 1] - points[i]).normalized(),
            )).clamp(-1.0, 1.0),
          ) *
          180 /
          math.pi,
  ];
}

class ArchitectGutterRun {
  final Offset start, end;
  final double elevation;
  const ArchitectGutterRun(this.start, this.end, this.elevation);
}

class ArchitectRoofDrainageGeometry {
  static final _cache =
      Expando<Map<ArchitectRoofPlane, ArchitectRoofDrainageGeometry>>();
  final List<ArchitectGutterRun> gutters;
  final List<ArchitectDownpipeRoute> routes;
  const ArchitectRoofDrainageGeometry(this.gutters, this.routes);

  /// Keep the rolled back lip outside the fascia, with the drip apron above
  /// the open channel. The fascia must never pass through the gutter wall.
  static double gutterOffset(ArchitectRoofPlane roof) =>
      roof.drainage.gutterWidth / 2 +
      (roof.assembly.timber.hasFasciaBoard
          ? roof.assembly.timber.fasciaThickness
          : 0) +
      .005;

  /// The channel catches water at the covering, above the rafter/fascia foot.
  /// Keep a small drop below the drip edge, shared by the channel and outlet.
  static double gutterElevation(
    ArchitectStorey floor,
    ArchitectRoofPlane roof,
    Offset onEaves,
  ) {
    final covering =
        roof.assembly.layers
            .where((l) => l.role == ArchitectRoofLayerRole.covering)
            .firstOrNull
            ?.thickness ??
        .04;
    final verticalCovering =
        covering / math.cos(roof.slopeRadians).clamp(.1, 1);
    return floor.elevation +
        roof.topElevationAt(onEaves) -
        verticalCovering -
        .02;
  }

  Path planPath(double gutterWidth, {double tolerance = 0}) {
    var result = Path();
    void stroke(Offset a, Offset b, double radius) {
      if ((b - a).distance < 1e-8) {
        result = Path.combine(
          PathOperation.union,
          result,
          Path()..addOval(Rect.fromCircle(center: a, radius: radius)),
        );
        return;
      }
      final d = b - a, side = Offset(-d.dy, d.dx) / d.distance * radius;
      result = Path.combine(
        PathOperation.union,
        result,
        Path()..addPolygon([a + side, b + side, b - side, a - side], true),
      );
    }

    for (final run in gutters) {
      stroke(run.start, run.end, gutterWidth / 2 + tolerance);
    }
    for (final route in routes) {
      if (route.status != ArchitectDownpipeStatus.ready) continue;
      for (var i = 0; i + 1 < route.points.length; i++) {
        final a = route.points[i], b = route.points[i + 1];
        stroke(
          Offset(a.x, a.y),
          Offset(b.x, b.y),
          route.pipe.diameter / 2 + tolerance,
        );
      }
    }
    return result;
  }

  static (Offset, Offset) eaves(ArchitectRoofPlane roof) {
    var result = roof.eavesEdge, longest = 0.0;
    for (var i = 0; i < roof.points.length; i++) {
      final a = roof.points[i], b = roof.points[(i + 1) % roof.points.length];
      if (roof.signedDistanceFromEaves(a).abs() < 1e-6 &&
          roof.signedDistanceFromEaves(b).abs() < 1e-6 &&
          (b - a).distance > longest) {
        result = (a, b);
        longest = (b - a).distance;
      }
    }
    return result;
  }

  static List<(Offset, Offset)> visibleEaves(
    ArchitectProject project,
    ArchitectStorey floor,
    ArchitectRoofPlane roof,
  ) => [
    for (final contour in ArchitectPathSolid.contours(
      ArchitectRoofJunctions.of(floor, project: project).footprint(roof),
    ))
      for (var i = 0; i < contour.length; i++)
        if (roof.signedDistanceFromEaves(contour[i]).abs() < 1e-5 &&
            roof
                    .signedDistanceFromEaves(contour[(i + 1) % contour.length])
                    .abs() <
                1e-5)
          (contour[i], contour[(i + 1) % contour.length]),
  ];

  static ArchitectRoofDrainageGeometry build(
    ArchitectProject project,
    ArchitectStorey floor,
    ArchitectRoofPlane roof,
  ) => (_cache[project] ??= {})[roof] ??= _build(project, floor, roof);

  static ArchitectRoofDrainageGeometry _build(
    ArchitectProject project,
    ArchitectStorey floor,
    ArchitectRoofPlane roof,
  ) {
    final d = roof.drainage, n = roof.slopeDirection;
    final shift = n * -gutterOffset(roof);
    return ArchitectRoofDrainageGeometry(
      [
        if (d.showGutter)
          for (final (a, b) in visibleEaves(project, floor, roof))
            ArchitectGutterRun(
              a + shift,
              b + shift,
              gutterElevation(floor, roof, a),
            ),
      ],
      [
        if (d.showDownpipes)
          for (final pipe in d.downpipes)
            if (pipe.visible) route(project, floor, roof, pipe),
      ],
    );
  }

  static ArchitectDownpipeRoute route(
    ArchitectProject project,
    ArchitectStorey floor,
    ArchitectRoofPlane roof,
    ArchitectDownpipe pipe,
  ) {
    final direct = _route(project, floor, roof, pipe);
    if (direct.status == ArchitectDownpipeStatus.ready ||
        direct.status == ArchitectDownpipeStatus.outsideEaves ||
        pipe.facadeWallId != null ||
        pipe.waypoints.isNotEmpty) {
      return direct;
    }
    // At a verge corner the upslope ray can miss every wall. Try the nearest
    // facade faces/corners as well, retaining the same physical gutter outlet.
    final (a, b) = eaves(roof);
    final length = (b - a).distance;
    if (length < 1e-6) return direct;
    final origin =
        a +
        (b - a) * (pipe.offset / length) -
        roof.slopeDirection * gutterOffset(roof);
    final candidates = <(double, Offset, String)>[];
    for (final storey in project.storeys) {
      for (final wall in storey.walls) {
        final bottom = storey.elevation + wall.baseOffset;
        final top = bottom + wall.effectiveHeight(storey.height);
        if (top < pipe.outletElevation ||
            bottom > gutterElevation(floor, roof, origin)) {
          continue;
        }
        final corners = wall.polygonCorners;
        final targets =
            [
              for (var i = 0; i < corners.length; i++)
                BimLineGeometry.closest(
                  origin,
                  corners[i],
                  corners[(i + 1) % corners.length],
                ),
            ]..sort(
              (a, b) => (a - origin).distance.compareTo((b - origin).distance),
            );
        final delta = targets.first - origin;
        if (delta.distance < 1e-5 ||
            delta.dx * roof.slopeDirection.dx +
                    delta.dy * roof.slopeDirection.dy <
                -1e-5) {
          continue;
        }
        candidates.add((delta.distance, delta / delta.distance, wall.id));
      }
    }
    candidates.sort((a, b) => a.$1.compareTo(b.$1));
    for (final candidate in candidates) {
      final alternative = _route(
        project,
        floor,
        roof,
        pipe,
        direction: candidate.$2,
        targetWallId: candidate.$3,
      );
      if (alternative.status == ArchitectDownpipeStatus.ready) {
        return alternative;
      }
    }
    return direct;
  }

  static ArchitectDownpipeRoute _route(
    ArchitectProject project,
    ArchitectStorey floor,
    ArchitectRoofPlane roof,
    ArchitectDownpipe pipe, {
    Offset? direction,
    String? targetWallId,
  }) {
    final (a, b) = eaves(roof);
    final length = (b - a).distance;
    var inward = direction ?? roof.slopeDirection;
    ArchitectDownpipeRoute failure(ArchitectDownpipeStatus status) =>
        ArchitectDownpipeRoute(pipe, status, const [], inward);
    try {
      pipe.validate();
    } on ArgumentError {
      return failure(ArchitectDownpipeStatus.blocked);
    }
    if (length < 1e-6 || pipe.offset < 0 || pipe.offset > length + 1e-6) {
      return failure(ArchitectDownpipeStatus.outsideEaves);
    }
    final onEaves = a + (b - a) * (pipe.offset / length);
    if (!visibleEaves(project, floor, roof).any(
      (edge) =>
          (BimLineGeometry.closest(onEaves, edge.$1, edge.$2) - onEaves)
              .distance <
          1e-5,
    )) {
      return failure(ArchitectDownpipeStatus.outsideEaves);
    }
    if (roof.drainage.showGutter &&
        (pipe.diameter > roof.drainage.gutterWidth - .01 ||
            !visibleEaves(project, floor, roof).any(
              (e) =>
                  (onEaves - e.$1).distance > pipe.diameter / 2 + .01 &&
                  (onEaves - e.$2).distance > pipe.diameter / 2 + .01 &&
                  (BimLineGeometry.closest(onEaves, e.$1, e.$2) - onEaves)
                          .distance <
                      1e-5,
            ))) {
      return failure(ArchitectDownpipeStatus.blocked);
    }
    if (roof.drainage.downpipes.any(
      (other) =>
          other.id != pipe.id &&
          other.visible &&
          (other.offset - pipe.offset).abs() <
              (other.diameter + pipe.diameter) / 2 + .02,
    )) {
      return failure(ArchitectDownpipeStatus.blocked);
    }
    final origin = onEaves - roof.slopeDirection * gutterOffset(roof);
    final startZ =
        gutterElevation(floor, roof, onEaves) - roof.drainage.gutterDepth;
    if (pipe.facadeWallId != null) {
      final walls = project.storeys
          .expand((s) => s.walls)
          .where((w) => w.id == pipe.facadeWallId)
          .toList();
      if (walls.isEmpty) return failure(ArchitectDownpipeStatus.noFacade);
      final corners = walls.single.polygonCorners;
      final targets = [
        for (var i = 0; i < corners.length; i++)
          BimLineGeometry.closest(
            origin,
            corners[i],
            corners[(i + 1) % corners.length],
          ),
      ]..sort((a, b) => (a - origin).distance.compareTo((b - origin).distance));
      final delta = targets.first - origin;
      if (delta.distance > 1e-5) inward = delta / delta.distance;
    }
    final margin = pipe.diameter * .75 + pipe.wallClearance;
    final obstacles = <_Obstacle>[];
    final wallTargets = <_Obstacle>[];
    void obstacle(
      List<Offset> polygon,
      double bottom,
      double top, {
      String? wallId,
    }) {
      final range = _range(polygon, origin, inward, margin);
      if (range == null ||
          range.$2 < 0 ||
          top < pipe.outletElevation ||
          bottom > startZ + margin) {
        return;
      }
      final o = _Obstacle(range.$1 - margin, bottom - margin, top + margin);
      obstacles.add(o);
      final target = pipe.facadeWallId ?? targetWallId;
      if (wallId != null && (target == null || wallId == target)) {
        wallTargets.add(o);
      }
    }

    for (final storey in project.storeys) {
      for (final wall in storey.walls) {
        obstacle(
          wall.polygonCorners,
          storey.elevation + wall.baseOffset,
          storey.elevation +
              wall.baseOffset +
              wall.effectiveHeight(storey.height),
          wallId: wall.id,
        );
      }
      for (final beam in storey.beams) {
        obstacle(
          beam.polygonCorners,
          storey.elevation + beam.baseOffset,
          storey.elevation + beam.baseOffset + beam.depth,
        );
      }
      for (final column in storey.columns) {
        final rotation = column.rotationDeg * math.pi / 180;
        final local = column.shape == ColumnShape.circular
            ? [
                for (var i = 0; i < 32; i++)
                  Offset(
                        math.cos(i * math.pi / 16),
                        math.sin(i * math.pi / 16),
                      ) *
                      (column.width / 2),
              ]
            : [
                Offset(-column.width / 2, -column.depth / 2),
                Offset(column.width / 2, -column.depth / 2),
                Offset(column.width / 2, column.depth / 2),
                Offset(-column.width / 2, column.depth / 2),
              ];
        obstacle(
          [
            for (final p in local)
              column.position +
                  Offset(
                    p.dx * math.cos(rotation) - p.dy * math.sin(rotation),
                    p.dx * math.sin(rotation) + p.dy * math.cos(rotation),
                  ),
          ],
          storey.elevation + column.baseOffset,
          storey.elevation +
              column.baseOffset +
              (column.height ?? storey.height),
        );
      }
      for (final slab in storey.slabs) {
        final surfaces = ArchitectSlabGeometry.surfaces(project, storey, slab);
        final range = _range(slab.polygon, origin, inward, margin);
        if (range == null) continue;
        final samples = [
          origin + inward * range.$1,
          origin + inward * range.$2,
        ];
        obstacle(
          slab.polygon,
          samples.map(surfaces.last.bottomAt).reduce(math.min),
          samples.map(surfaces.first.topAt).reduce(math.max),
        );
      }
      for (final other in storey.roofs) {
        // The source outlet is below its lowest roof underside. Inflating that
        // roof as an obstacle would falsely block shallow gutters.
        if (other.id == roof.id) continue;
        for (final contour in ArchitectPathSolid.contours(
          ArchitectRoofJunctions.of(storey, project: project).footprint(other),
        )) {
          obstacle(
            contour,
            storey.elevation +
                contour.map(other.undersideElevationAt).reduce(math.min),
            storey.elevation +
                contour.map(other.topElevationAt).reduce(math.max),
          );
        }
      }
    }
    if (wallTargets.isEmpty) return failure(ArchitectDownpipeStatus.noFacade);
    if (startZ <= pipe.outletElevation + .1) {
      return failure(ArchitectDownpipeStatus.blocked);
    }
    // Prefer the facade closest to the outlet level, excluding back walls by
    // selecting the frontmost wall at that level.
    double verticalDistance(_Obstacle o) => pipe.outletElevation < o.bottom
        ? o.bottom - pipe.outletElevation
        : pipe.outletElevation > o.top
        ? pipe.outletElevation - o.top
        : 0;
    wallTargets.sort((a, b) {
      final z = verticalDistance(a).compareTo(verticalDistance(b));
      return z == 0 ? a.front.compareTo(b.front) : z;
    });
    final facade = wallTargets.first.front;
    final zEvents = <double>{
      startZ,
      pipe.outletElevation,
      for (final o in obstacles) ...[
        o.bottom.clamp(pipe.outletElevation, startZ),
        o.top.clamp(pipe.outletElevation, startZ),
      ],
    }.toList()..sort();
    final bands = <_Obstacle>[];
    for (var i = 0; i + 1 < zEvents.length; i++) {
      final bottom = zEvents[i], top = zEvents[i + 1], mid = (bottom + top) / 2;
      final active = obstacles
          .where((o) => mid > o.bottom && mid < o.top)
          .toList();
      bands.add(
        _Obstacle(
          active.isEmpty ? facade : active.map((o) => o.front).reduce(math.min),
          bottom,
          top,
        ),
      );
    }
    final neck = math.max(
      .1,
      pipe.diameter * math.tan(pipe.bendAngle * math.pi / 360) + .02,
    );
    if (startZ - pipe.outletElevation <= neck) {
      return failure(ArchitectDownpipeStatus.blocked);
    }
    // Do not tuck in past the final facade only to turn back out at its top.
    // This also avoids an unnecessary double-angle cusp beneath the eaves.
    bands.add(_Obstacle(math.max(0, facade), pipe.outletElevation, startZ));
    bands.add(_Obstacle(0, startZ - neck, startZ));
    final k = math.tan(pipe.bendAngle * math.pi / 180);
    double envelope(double z) => bands
        .map(
          (band) =>
              band.front +
              k *
                  (z < band.bottom
                      ? band.bottom - z
                      : z > band.top
                      ? z - band.top
                      : 0),
        )
        .reduce(math.min);
    // Greatest fixed-angle continuous profile below the outside envelope.
    // Looking both up and down anticipates projections before hitting them,
    // and follows a recessed facade only after clearing the bay underside.
    final breaks = <double>{...zEvents, startZ - neck};
    final intervals = breaks.toList()..sort();
    for (var i = 0; i + 1 < intervals.length; i++) {
      final bottom = intervals[i],
          top = intervals[i + 1],
          mid = (bottom + top) / 2;
      final lines = <(double, double)>[
        for (final band in bands)
          mid < band.bottom
              ? (-k, band.front + k * band.bottom)
              : mid > band.top
              ? (k, band.front - k * band.top)
              : (0, band.front),
      ];
      final bySlope = <double, double>{};
      for (final (m, c) in lines) {
        bySlope[m] = math.min(bySlope[m] ?? double.infinity, c);
      }
      final distinct = bySlope.entries.toList();
      for (var a = 0; a < distinct.length; a++) {
        for (final b in distinct.skip(a + 1)) {
          final z = (b.value - distinct[a].value) / (distinct[a].key - b.key);
          if (z > bottom + 1e-8 && z < top - 1e-8) breaks.add(z);
        }
      }
    }
    if (envelope(startZ).abs() > 1e-5) {
      return failure(ArchitectDownpipeStatus.blocked);
    }
    final ordered =
        breaks.where((z) => z >= pipe.outletElevation && z <= startZ).toList()
          ..sort((a, b) => b.compareTo(a));
    var profile = [for (final z in ordered) Offset(envelope(z), z)];
    if (pipe.waypoints.isNotEmpty) {
      profile = [
        Offset(0, startZ),
        Offset(0, startZ - neck),
        ...pipe.waypoints,
        Offset(envelope(pipe.outletElevation), pipe.outletElevation),
      ];
    }
    final clean = <Offset>[];
    for (final p in profile) {
      if (clean.isNotEmpty && p.dy >= clean.last.dy - 1e-8) {
        return failure(ArchitectDownpipeStatus.blocked);
      }
      clean.add(p);
      while (clean.length >= 3) {
        final a = clean[clean.length - 2] - clean[clean.length - 3],
            b = clean.last - clean[clean.length - 2];
        if ((a.dx * b.dy - a.dy * b.dx).abs() > 1e-8) break;
        clean.removeAt(clean.length - 2);
      }
    }
    for (var i = 0; i + 1 < clean.length; i++) {
      final a = clean[i], b = clean[i + 1];
      for (final band in bands.take(bands.length - 1)) {
        final high = math.min(a.dy, band.top),
            low = math.max(b.dy, band.bottom);
        if (high < low) continue;
        double x(double z) => a.dx + (b.dx - a.dx) * (a.dy - z) / (a.dy - b.dy);
        if (math.max(x(high), x(low)) > band.front + 1e-5) {
          return failure(ArchitectDownpipeStatus.blocked);
        }
      }
    }
    // Adjacent miter rings must not overlap on a short offset. A route that
    // clears its centerline can still be too short for its physical fittings.
    double setback(int i) {
      if (i <= 0 || i + 1 >= clean.length) return 0;
      final a = clean[i] - clean[i - 1], b = clean[i + 1] - clean[i];
      final cos = ((a.dx * b.dx + a.dy * b.dy) / (a.distance * b.distance))
          .clamp(-1.0, 1.0);
      return pipe.diameter / 2 * math.tan(math.acos(cos) / 2);
    }

    for (var i = 0; i + 1 < clean.length; i++) {
      if ((clean[i + 1] - clean[i]).distance <
          setback(i) + setback(i + 1) + .003) {
        return failure(ArchitectDownpipeStatus.blocked);
      }
    }
    return ArchitectDownpipeRoute(pipe, ArchitectDownpipeStatus.ready, [
      for (final p in clean)
        Vector3(
          origin.dx + inward.dx * p.dx,
          origin.dy + inward.dy * p.dx,
          p.dy,
        ),
    ], inward);
  }

  /// Projection of a footprint intersecting the full pipe-width strip. A
  /// centerline-only test misses collisions beside wall and bay corners.
  static (double, double)? _range(
    List<Offset> polygon,
    Offset origin,
    Offset inward,
    double halfWidth,
  ) {
    if (polygon.length < 3) return null;
    final side = Offset(-inward.dy, inward.dx);
    var local = [
      for (final p in polygon)
        Offset(
          (p - origin).dx * side.dx + (p - origin).dy * side.dy,
          (p - origin).dx * inward.dx + (p - origin).dy * inward.dy,
        ),
    ];
    for (final sign in [-1.0, 1.0]) {
      final output = <Offset>[];
      for (var i = 0; i < local.length; i++) {
        final a = local[i], b = local[(i + 1) % local.length];
        final da = halfWidth - sign * a.dx, db = halfWidth - sign * b.dx;
        if (da >= 0) output.add(a);
        if ((da >= 0) != (db >= 0)) output.add(a + (b - a) * (da / (da - db)));
      }
      local = output;
      if (local.isEmpty) return null;
    }
    return (
      local.map((p) => p.dy).reduce(math.min),
      local.map((p) => p.dy).reduce(math.max),
    );
  }
}

class _Obstacle {
  final double front, bottom, top;
  const _Obstacle(this.front, this.bottom, this.top);
}
