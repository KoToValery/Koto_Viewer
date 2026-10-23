import 'dart:math' as math;
import 'dart:ui';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../models/architect_project.dart';
import '../services/architect_roof_drainage_geometry.dart';
import 'architect_path_solid.dart';

class ArchitectRoofDrainageMesh {
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
    ArchitectRoofPlane roof,
  ) {
    final geometry = ArchitectRoofDrainageGeometry.build(project, storey, roof);
    final d = roof.drainage, ink = color(d.material);
    final result = <Triangle3D>[];
    final ready = geometry.routes
        .where((r) => r.status == ArchitectDownpipeStatus.ready)
        .toList();
    final angles = {
      for (final route in ready) route.pipe.id: _angles(roof, route),
    };
    for (final gutter in geometry.gutters) {
      final delta = gutter.end - gutter.start, axis = delta / delta.distance;
      if (delta.distance < 1e-6) continue;
      final profile = d.profile == ArchitectGutterProfile.box
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
      final triangles = [
        for (final t in ArchitectPathSolid.extrude(
          Path()..addPolygon(profile, true),
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
    }
    for (final route in ready) {
      final points = route.points, r = route.pipe.diameter / 2;
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
        outer.add(ring(r, false));
        inner.add(ring(r - thickness, true));
      }
      void triangle(Vector3 a, Vector3 b, Vector3 c) =>
          result.add(Triangle3D(v0: a, v1: b, v2: c, color: ink));
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
        if (!d.showGutter) {
          triangle(outer.first[j], inner.first[j], inner.first[k]);
          triangle(outer.first[j], inner.first[k], outer.first[k]);
        }
        triangle(outer.last[j], outer.last[k], inner.last[k]);
        triangle(outer.last[j], inner.last[k], inner.last[j]);
      }
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
