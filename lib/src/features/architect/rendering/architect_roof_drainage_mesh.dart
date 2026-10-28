import 'dart:math' as math;
import 'dart:ui';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../../bim_editing/geometry/bim_line_geometry.dart';
import '../models/architect_project.dart';
import '../services/architect_roof_drainage_geometry.dart';
import 'architect_path_solid.dart';

class ArchitectRoofDrainageMesh {
  static final _cache = Expando<Map<(ArchitectRoofPlane, bool, bool, bool), List<Triangle3D>>>();
  static const thickness = .0015;
  static Color color(ArchitectDrainageMaterial material) => switch (material) {
    ArchitectDrainageMaterial.galvanizedSteel => const Color(0xff87969d),
    ArchitectDrainageMaterial.aluminium => const Color(0xffaab4ba),
    ArchitectDrainageMaterial.pvc => const Color(0xff5e6970),
    ArchitectDrainageMaterial.copper => const Color(0xffb77548),
  };

  static List<Triangle3D> build(
    ArchitectProject project,
    ArchitectStorey storey,
    ArchitectRoofPlane roof, {
    bool includeGutters = true,
    bool includeDownpipes = true,
    bool details = true,
  }) => (_cache[project] ??= {}).putIfAbsent((roof, includeGutters, includeDownpipes, details),
    () => List.unmodifiable(_build(project, storey, roof,
      includeGutters: includeGutters, includeDownpipes: includeDownpipes, details: details)));

  static List<Triangle3D> _build(
    ArchitectProject project,
    ArchitectStorey storey,
    ArchitectRoofPlane roof, {
    required bool includeGutters,
    required bool includeDownpipes,
    required bool details,
  }) {
    if (!includeGutters && !includeDownpipes) return [];
    final geometry = ArchitectRoofDrainageGeometry.build(project, storey, roof);
    final d = roof.drainage, ink = color(d.material);
    final box=d.position==ArchitectGutterPosition.internal||d.profile==ArchitectGutterProfile.box;
    final result = <Triangle3D>[];
    final ready = geometry.routes
        .where((r) => r.status == ArchitectDownpipeStatus.ready)
        .toList();
    final angles = {
      for (final route in ready) route.pipe.id: _angles(roof, route),
    };
    // Keep the full routing geometry for physical outlet cuts even when a
    // drawing omits the pipes. Visibility must not alter the gutter itself.
    for (final gutter
        in includeGutters ? geometry.gutters : <ArchitectGutterRun>[]) {
      final delta = gutter.end - gutter.start;
      if (delta.distance < 1e-5) continue;
      final axis = delta / delta.distance;
      final profile = box
          ? [
              Offset(-d.gutterWidth / 2, 0),
              Offset(-d.gutterWidth / 2, -d.gutterDepth),
              Offset(d.gutterWidth / 2, -d.gutterDepth),
              Offset(d.gutterWidth / 2, 0),
              Offset(d.gutterWidth / 2 - thickness, 0),
              Offset(d.gutterWidth / 2 - thickness, -d.gutterDepth + thickness),
              Offset(
                -d.gutterWidth / 2 + thickness,
                -d.gutterDepth + thickness,
              ),
              Offset(-d.gutterWidth / 2 + thickness, 0),
            ]
          : [
              for (var i = 0; i <= 16; i++)
                Offset(
                  d.gutterWidth / 2 * math.cos(i * math.pi / 16),
                  -d.gutterDepth * math.sin(i * math.pi / 16),
                ),
              for (var i = 16; i >= 0; i--)
                Offset(
                  (d.gutterWidth / 2 - thickness) * math.cos(i * math.pi / 16),
                  -(d.gutterDepth - thickness) * math.sin(i * math.pi / 16),
                ),
            ];
      Vector3 world(Vector3 p) => Vector3(
        gutter.start.dx - axis.dy * p.x + axis.dx * p.z,
        gutter.start.dy + axis.dx * p.x + axis.dy * p.z,
        gutter.elevation + p.y,
      );
      var channel = Path()..addPolygon(profile, true);
      // Rolled edges stiffen both lips and make the open channel legible in 3D.
      for (final side in details ? [-1.0, 1.0] : <double>[]) {
        channel = Path.combine(
          PathOperation.union,
          channel,
          Path()..addOval(
            Rect.fromCircle(
              center: Offset(side * (d.gutterWidth / 2 - thickness / 2), 0),
              radius: .0035,
            ),
          ),
        );
      }
      final triangles = [
        for (final t in ArchitectPathSolid.extrude(
          channel,
          0,
          delta.distance,
          ink,
        ))
          Triangle3D(
            v0: world(t.v0),
            v1: world(t.v1),
            v2: world(t.v2),
            color: ink,
          ),
      ];
      for (final triangle in triangles) {
        // Punch separate inner/outer outlet rims, rather than leaving a closed
        // gutter bottom over the pipe bore. Vertical lips cannot meet the hole.
        if (triangle.normal.z.abs() < 1e-8) {
          result.add(triangle);
          continue;
        }
        var projected = Path()
          ..addPolygon([
            for (final p in [triangle.v0, triangle.v1, triangle.v2])
              Offset(p.x, p.y),
          ], true);
        var punched = false;
        for (final route in ready) {
          final p = Offset(route.points.first.x, route.points.first.y);
          final r =
              route.pipe.diameter / 2 - (triangle.normal.z > 0 ? thickness : 0);
          if (!projected.getBounds().overlaps(
            Rect.fromCircle(center: p, radius: r),
          )) {
            continue;
          }
          final side = Offset(-route.inward.dy, route.inward.dx);
          projected = Path.combine(
            PathOperation.difference,
            projected,
            Path()..addPolygon([
              for (final angle in angles[route.pipe.id]!)
                p +
                    side * (r * math.cos(angle)) +
                    route.inward * (r * math.sin(angle)),
            ], true),
          );
          punched = true;
        }
        if (!punched) {
          result.add(triangle);
          continue;
        }
        final n = triangle.normal, origin = triangle.v0;
        Vector3 lift(Vector3 p) => Vector3(
          p.x,
          p.y,
          origin.z - (n.x * (p.x - origin.x) + n.y * (p.y - origin.y)) / n.z,
        );
        for (final t in ArchitectPathSolid.extrude(
          projected,
          0,
          1,
          ink,
        ).where((t) => t.normal.z > .5)) {
          result.add(
            Triangle3D(
              v0: lift(t.v0),
              v1: lift(triangle.normal.z > 0 ? t.v1 : t.v2),
              v2: lift(triangle.normal.z > 0 ? t.v2 : t.v1),
              color: ink,
            ),
          );
        }
      }
      void fitting(Path section, double start, double end) {
        for (final t in ArchitectPathSolid.extrude(section, start, end, ink)) {
          result.add(
            Triangle3D(
              v0: world(t.v0),
              v1: world(t.v1),
              v2: world(t.v2),
              color: ink,
            ),
          );
        }
      }

      // Close only the channel ends; the mouth and punched outlets stay open.
      final cavity = box
          ? [
              Offset(-d.gutterWidth / 2 + thickness, 0),
              Offset(
                -d.gutterWidth / 2 + thickness,
                -d.gutterDepth + thickness,
              ),
              Offset(d.gutterWidth / 2 - thickness, -d.gutterDepth + thickness),
              Offset(d.gutterWidth / 2 - thickness, 0),
            ]
          : [
              for (var i = 0; i <= 16; i++)
                Offset(
                  (d.gutterWidth / 2 - thickness) * math.cos(i * math.pi / 16),
                  -(d.gutterDepth - thickness) * math.sin(i * math.pi / 16),
                ),
            ];
      final cap = Path()..addPolygon(cavity, true);
      fitting(cap, 0, thickness);
      fitting(cap, delta.distance - thickness, delta.distance);
      // Strap hangers sit on the outside of the sheet at regular centres.
      final strap = box
          ? [
              Offset(-d.gutterWidth / 2 - .003, -.015),
              Offset(-d.gutterWidth / 2 - .003, -d.gutterDepth - .003),
              Offset(d.gutterWidth / 2 + .003, -d.gutterDepth - .003),
              Offset(d.gutterWidth / 2 + .003, -.015),
              Offset(d.gutterWidth / 2, -.015),
              Offset(d.gutterWidth / 2, -d.gutterDepth),
              Offset(-d.gutterWidth / 2, -d.gutterDepth),
              Offset(-d.gutterWidth / 2, -.015),
            ]
          : [
              for (var i = 0; i <= 16; i++)
                Offset(
                  (d.gutterWidth / 2 + .003) * math.cos(i * math.pi / 16),
                  -(d.gutterDepth + .003) * math.sin(i * math.pi / 16),
                ),
              for (var i = 16; i >= 0; i--)
                Offset(
                  d.gutterWidth / 2 * math.cos(i * math.pi / 16),
                  -d.gutterDepth * math.sin(i * math.pi / 16),
                ),
            ];
      final hangerCount = details
          ? math.max(1, (delta.distance / .6).ceil())
          : 0;
      for (var i = 0; i < hangerCount; i++) {
        final position = delta.distance * (i + .5) / hangerCount;
        if (ready.any(
          (route) =>
              (Offset(route.points.first.x, route.points.first.y) -
                      (gutter.start + axis * position))
                  .distance <
              route.pipe.diameter,
        )) {
          continue;
        }
        fitting(
          Path()..addPolygon(strap, true),
          position - .009,
          position + .009,
        );
      }
    }
    for (final route in ready) {
      final rings = _pipeRings(route, details: details);
      final points = [for (final ring in rings) ring.$1];
      final r = route.pipe.diameter / 2;
      final samples = angles[route.pipe.id]!;
      final u = Vector3(-route.inward.dy, route.inward.dx, 0);
      final outer = <List<Vector3>>[], inner = <List<Vector3>>[];
      for (var i = 0; i < points.length; i++) {
        final previous = i == 0
            ? (points[1] - points[0]).normalized()
            : (points[i] - points[i - 1]).normalized();
        final next = i + 1 == points.length
            ? previous
            : (points[i + 1] - points[i]).normalized();
        final tangent = (previous + next).normalized(),
            v = tangent.cross(u).normalized();
        final factor = math.max(.25, tangent.dot(previous));
        List<Vector3> ring(double radius, bool inside) => [
          for (final angle in samples)
            () {
              final p =
                  points[i] +
                  u * (radius * math.cos(angle)) +
                  v * (radius * math.sin(angle) / factor);
              if (i != 0 || !d.showGutter) return p;
              // The pipe meets the curved gutter rims, without a flat cap or gap.
              final eavesAxis =
                  (ArchitectRoofDrainageGeometry.eaves(roof).$2 -
                  ArchitectRoofDrainageGeometry.eaves(roof).$1);
              final side =
                  Offset(-eavesAxis.dy, eavesAxis.dx) / eavesAxis.distance;
              final across =
                  (p.x - points.first.x) * side.dx +
                  (p.y - points.first.y) * side.dy;
              final width = d.gutterWidth / 2 - (inside ? thickness : 0),
                  depth = d.gutterDepth - (inside ? thickness : 0);
              var z = -depth;
              if (d.profile == ArchitectGutterProfile.halfRound) {
                // Match the actual faceted channel, including the vertices
                // inserted where the outlet crosses a profile facet.
                for (var k = 0; k < 16; k++) {
                  final x0 = width * math.cos(k * math.pi / 16);
                  final x1 = width * math.cos((k + 1) * math.pi / 16);
                  if (across > x0 + 1e-8 || across < x1 - 1e-8) continue;
                  final y0 = -depth * math.sin(k * math.pi / 16);
                  final y1 = -depth * math.sin((k + 1) * math.pi / 16);
                  z = y0 + (y1 - y0) * ((across - x0) / (x1 - x0));
                  break;
                }
              }
              return Vector3(p.x, p.y, points.first.z + d.gutterDepth + z);
            }(),
        ];
        outer.add(ring(r + rings[i].$2, false));
        inner.add(ring(r - thickness, true));
      }
      void triangle(Vector3 a, Vector3 b, Vector3 c) =>
          result.add(Triangle3D(v0: a, v1: b, v2: c, color: ink));
      if (!includeDownpipes) {
        // Gutter and pipe normally share an open mesh interface. Close the
        // retained sheet edge at that interface when the drawing omits the
        // pipe, so a real section can still trace the gutter's material.
        if (d.showGutter) {
          for (var j = 0; j < samples.length; j++) {
            final k = (j + 1) % samples.length;
            triangle(outer.first[j], outer.first[k], inner.first[k]);
            triangle(outer.first[j], inner.first[k], inner.first[j]);
          }
        }
        continue;
      }
      for (var i = 0; i + 1 < points.length; i++) {
        for (var j = 0; j < samples.length; j++) {
          final k = (j + 1) % samples.length;
          triangle(outer[i][j], outer[i][k], outer[i + 1][k]);
          triangle(outer[i][j], outer[i + 1][k], outer[i + 1][j]);
          triangle(inner[i][j], inner[i + 1][k], inner[i][k]);
          triangle(inner[i][j], inner[i + 1][j], inner[i + 1][k]);
        }
      }
      for (var j = 0; j < samples.length; j++) {
        final k = (j + 1) % samples.length;
        if (!d.showGutter || !includeGutters) {
          triangle(outer.first[j], inner.first[j], inner.first[k]);
          triangle(outer.first[j], inner.first[k], outer.first[k]);
        }
        triangle(outer.last[j], outer.last[k], inner.last[k]);
        triangle(outer.last[j], inner.last[k], inner.last[j]);
      }
      for (var i = 0; i + 1 < rings.length; i++) {
        if (rings[i].$2 !=
                ArchitectRoofDrainageGeometry.maximumFittingExtraRadius ||
            rings[i + 1].$2 !=
                ArchitectRoofDrainageGeometry.maximumFittingExtraRadius) {
          continue;
        }
        final center = (rings[i].$1 + rings[i + 1].$1) / 2;
        final plan = Offset(center.x, center.y);
        Offset? anchor;
        var distance = route.pipe.wallClearance + route.pipe.diameter * 1.5;
        for (final floor in project.storeys) {
          for (final wall in floor.walls) {
            final bottom = floor.elevation + wall.baseOffset;
            if (center.z < bottom + .03 ||
                center.z > bottom + wall.effectiveHeight(floor.height) - .03) {
              continue;
            }
            final corners = wall.polygonCorners;
            for (var j = 0; j < corners.length; j++) {
              final p = BimLineGeometry.closest(
                plan,
                corners[j],
                corners[(j + 1) % corners.length],
              );
              final delta = p - plan;
              if (delta.dx * route.inward.dx + delta.dy * route.inward.dy <=
                      0 ||
                  delta.distance <= r + .012 ||
                  delta.distance >= distance) {
                continue;
              }
              anchor = p;
              distance = delta.distance;
            }
          }
        }
        if (anchor == null || distance < 1e-5) continue;
        final direction = (anchor - plan) / distance;
        final side = Offset(-direction.dy, direction.dx);
        void mountingBar(Offset a, Offset b, double width, double height) {
          result.addAll(
            ArchitectPathSolid.extrude(
              Path()..addPolygon([
                a + side * width / 2,
                b + side * width / 2,
                b - side * width / 2,
                a - side * width / 2,
              ], true),
              center.z - height / 2,
              center.z + height / 2,
              ink,
            ),
          );
        }

        mountingBar(
          plan + direction * (r + .007),
          anchor - direction * .004,
          .012,
          .018,
        );
        mountingBar(anchor - direction * .004, anchor, .04, .045);
      }
    }
    return result;
  }

  /// Tangential circular elbows and socket/clamp beads share one hollow shell.
  /// No capped cylinders or overlapping sleeves can seal the drainage bore.
  static List<(Vector3, double)> _pipeRings(
    ArchitectDownpipeRoute route, {
    bool details = true,
  }) {
    final source = route.points;
    final diameter = route.pipe.diameter;
    final smooth = <Vector3>[source.first];
    for (var i = 1; i + 1 < source.length; i++) {
      final a = source[i] - source[i - 1], b = source[i + 1] - source[i];
      final incoming = a.normalized(), outgoing = b.normalized();
      final angle = math.acos(incoming.dot(outgoing).clamp(-1.0, 1.0));
      if (angle < 1e-5 || angle > math.pi - 1e-5) {
        smooth.add(source[i]);
        continue;
      }
      final tangent = math.min(
        diameter * .75 * math.tan(angle / 2),
        math.min(a.length, b.length) * .4,
      );
      final radius = tangent / math.tan(angle / 2);
      final entry = source[i] - incoming * tangent;
      final towardCenter = (outgoing - incoming * incoming.dot(outgoing))
          .normalized();
      final center = entry + towardCenter * radius;
      final radial = entry - center;
      smooth.add(entry);
      final steps = math.max(4, (angle / (math.pi / 24)).ceil());
      for (var j = 1; j <= steps; j++) {
        final theta = angle * j / steps;
        smooth.add(
          center +
              radial * math.cos(theta) +
              incoming * (radius * math.sin(theta)),
        );
      }
    }
    smooth.add(source.last);
    if (!details) return [for (final point in smooth) (point, 0)];
    final result = <(Vector3, double)>[(smooth.first, 0)];
    for (var i = 0; i + 1 < smooth.length; i++) {
      final a = smooth[i], b = smooth[i + 1], delta = b - a;
      // Add sockets on straight lengths, and clamp bands on vertical drops.
      if (delta.length > diameter * 3) {
        final axis = delta.normalized();
        final positions = <(double, double)>[(diameter * .75, .004)];
        if ((b.x - a.x).abs() < 1e-6 && (b.y - a.y).abs() < 1e-6) {
          final count = math.max(1, (delta.length / 1.8).ceil());
          for (var j = 0; j < count; j++) {
            positions.add((
              delta.length * (j + .5) / count,
              ArchitectRoofDrainageGeometry.maximumFittingExtraRadius,
            ));
          }
        }
        positions.sort((a, b) => a.$1.compareTo(b.$1));
        var last = 0.0;
        for (final (position, bead) in positions) {
          const half = .012;
          if (position - half - .003 <= last ||
              position + half + .003 >= delta.length) {
            continue;
          }
          result.addAll([
            (a + axis * (position - half - .003), 0),
            (a + axis * (position - half), bead),
            (a + axis * (position + half), bead),
            (a + axis * (position + half + .003), 0),
          ]);
          last = position + half + .003;
        }
      }
      result.add((b, 0));
    }
    return result;
  }

  static List<double> _angles(
    ArchitectRoofPlane roof,
    ArchitectDownpipeRoute route,
  ) {
    final result = <double>[for (var i = 0; i < 16; i++) i * math.pi / 8];
    if (!roof.drainage.showGutter ||
        roof.drainage.profile == ArchitectGutterProfile.box) {
      return result;
    }
    final (a, b) = ArchitectRoofDrainageGeometry.eaves(roof);
    final d = b - a;
    if (d.distance < 1e-5) return result;
    final side = Offset(-d.dy, d.dx) / d.distance;
    final u = Offset(-route.inward.dy, route.inward.dx), v = route.inward;
    final phase = math.atan2(
      v.dx * side.dx + v.dy * side.dy,
      u.dx * side.dx + u.dy * side.dy,
    );
    for (final radius in [
      route.pipe.diameter / 2,
      route.pipe.diameter / 2 - thickness,
    ]) {
      for (final width in [
        roof.drainage.gutterWidth / 2,
        roof.drainage.gutterWidth / 2 - thickness,
      ]) {
        for (var i = 1; i < 16; i++) {
          final x = width * math.cos(i * math.pi / 16);
          if (x.abs() >= radius - 1e-8) continue;
          final alpha = math.acos(x / radius);
          for (final angle in [phase + alpha, phase - alpha]) {
            var normalized = angle % (2 * math.pi);
            if (normalized > 2 * math.pi - 1e-7) normalized = 0;
            if (!result.any((a) => (a - normalized).abs() < 1e-7)) {
              result.add(normalized);
            }
          }
        }
      }
    }
    return result..sort();
  }
}
