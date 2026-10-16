import 'dart:math' as math;
import 'dart:ui';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import '../services/architect_stair_geometry.dart';
import '../services/architect_stair_railings.dart';

enum StairSolidMaterial { concrete, finish, metal }

class StairSolid {
  final StairSolidMaterial material;
  final List<Triangle3D> triangles;
  const StairSolid(this.material, this.triangles);
}

/// A continuous concrete waist, separate thin finish and smart metal guards.
/// Thicknesses are drawing parameters, not a structural design calculation.
/// All returned solids use elevations relative to the owning floor, including
/// the stair's start offset. The scene adds the storey elevation exactly once.
class ArchitectStairMesh {
  static const concreteColor = Color(0xFF90A4AE);
  static const finishColor = Color(0xFFE8DCC5);
  static const metalColor = Color(0xFF455A64);
  static final _bodyCache = Expando<List<StairSolid>>();

  static List<StairSolid> body(ArchitectStair stair) =>
      _bodyCache[stair] ??= _body(stair);
  static List<StairSolid> _body(ArchitectStair stair) {
    final d = stair.design;
    if (d == null) return [];
    final geometry = ArchitectStairGeometry.of(stair), result = <StairSolid>[];
    final f = d.finishThickness, thickness = d.concreteThickness;
    if (d.hasWinders) {
      for (final surface in stair.plan.surfaces) {
        final p = surface.polygon, base = surface.slopeBase!;
        result.add(
          hexahedron(
            [
              for (var i = 0; i < p.length; i++)
                Vector3(p[i].dx, p[i].dy, base[i] - f - thickness),
            ],
            [for (final q in p) Vector3(q.dx, q.dy, surface.elevation - f)],
            StairSolidMaterial.concrete,
          ),
        );
        if (f > 1e-8) {
          final points = List<Offset>.of(p);
          if (surface.startsTread) {
            final delta = (p[2] + p[3] - p[0] - p[1]) / 2;
            final back = delta / delta.distance * d.nosingProjection;
            points[0] -= back;
            points[1] -= back;
          }
          result.add(
            verticalPrism(
              points,
              surface.elevation - f,
              surface.elevation,
              StairSolidMaterial.finish,
            ),
          );
        }
      }
      final (a, b) = stair.plan.nosings.last;
      final previous = stair.plan.nosings[stair.plan.nosings.length - 2];
      final delta = a + b - previous.$1 - previous.$2;
      final u = delta / delta.distance;
      result.add(
        hexahedron(
          [
            Vector3(a.dx, a.dy, d.rise - d.riser - f - thickness),
            Vector3(b.dx, b.dy, d.rise - d.riser - f - thickness),
            Vector3(
              b.dx + u.dx * thickness,
              b.dy + u.dy * thickness,
              d.rise - f - thickness,
            ),
            Vector3(
              a.dx + u.dx * thickness,
              a.dy + u.dy * thickness,
              d.rise - f - thickness,
            ),
          ],
          [
            for (final p in [a, b, b + u * thickness, a + u * thickness])
              Vector3(p.dx, p.dy, d.rise - f),
          ],
          StairSolidMaterial.concrete,
        ),
      );
    } else if (!d.isSpiral) {
      for (final flight in geometry.flights) {
        final profile = <Offset>[Offset(0, flight.base - f)];
        for (var i = 0; i < flight.count; i++) {
          final z = flight.base + (i + 1) * d.riser - f;
          profile.add(Offset(i * d.going, z));
          if (i < flight.count - 1) profile.add(Offset((i + 1) * d.going, z));
        }
        // A short landing tie closes the final rise as a real volume. It also
        // joins the waist to intermediate landings without a zero-width face.
        // This is a connection detail in 3D/sections, not an extra going in plan.
        profile.addAll([
          Offset(flight.run + thickness, flight.top - f),
          Offset(flight.run + thickness, flight.top - f - thickness),
          Offset(flight.run, flight.top - d.riser - f - thickness),
          Offset(0, flight.base - f - thickness),
        ]);
        result.add(profilePrism(profile, flight, StairSolidMaterial.concrete));
        if (f > 1e-8) {
          for (var i = 0; i < flight.count - 1; i++) {
            final a = i * d.going - d.nosingProjection, b = (i + 1) * d.going;
            final z = flight.base + (i + 1) * d.riser;
            result.add(
              verticalPrism(
                [
                  flight.point(a, -flight.width / 2),
                  flight.point(b, -flight.width / 2),
                  flight.point(b, flight.width / 2),
                  flight.point(a, flight.width / 2),
                ],
                z - f,
                z,
                StairSolidMaterial.finish,
              ),
            );
          }
        }
      }
      for (final landing in geometry.landings) {
        result.add(
          verticalPrism(
            landing.polygon,
            landing.elevation - f - thickness,
            landing.elevation - f,
            StairSolidMaterial.concrete,
          ),
        );
        if (f > 1e-8) {
          result.add(
            verticalPrism(
              landing.polygon,
              landing.elevation - f,
              landing.elevation,
              StairSolidMaterial.finish,
            ),
          );
        }
      }
    } else {
      const slices = ArchitectStairDesign.spiralSlicesPerGoing;
      for (var i = 0; i < stair.plan.surfaces.length; i++) {
        final surface = stair.plan.surfaces[i],
            step = i ~/ slices,
            slice = i % slices;
        final p = surface.polygon;
        final lowA = (step + slice / slices) * d.riser - f - thickness;
        final lowB = lowA + d.riser / slices;
        final top = surface.elevation - f;
        result.add(
          hexahedron(
            [
              Vector3(p[0].dx, p[0].dy, lowA),
              Vector3(p[1].dx, p[1].dy, lowA),
              Vector3(p[2].dx, p[2].dy, lowB),
              Vector3(p[3].dx, p[3].dy, lowB),
            ],
            [for (final v in p) Vector3(v.dx, v.dy, top)],
            StairSolidMaterial.concrete,
          ),
        );
        if (f > 1e-8) {
          final points = List<Offset>.of(p);
          if (slice == 0) {
            final direction = ((p[2] + p[3]) - (p[0] + p[1]));
            final u = direction / direction.distance;
            points[0] -= u * d.nosingProjection;
            points[1] -= u * d.nosingProjection;
          }
          result.add(
            verticalPrism(
              points,
              top,
              surface.elevation,
              StairSolidMaterial.finish,
            ),
          );
        }
      }
      // The final rise joins the upper floor; it is not an extra going.
      final (a, b) = stair.plan.nosings.last;
      final previous = stair.plan.nosings[stair.plan.nosings.length - 2];
      final delta = (a + b - previous.$1 - previous.$2) / 2;
      final u = delta / delta.distance;
      result.add(
        hexahedron(
          [
            Vector3(a.dx, a.dy, d.rise - d.riser - f - thickness),
            Vector3(b.dx, b.dy, d.rise - d.riser - f - thickness),
            Vector3(
              b.dx + u.dx * thickness,
              b.dy + u.dy * thickness,
              d.rise - f - thickness,
            ),
            Vector3(
              a.dx + u.dx * thickness,
              a.dy + u.dy * thickness,
              d.rise - f - thickness,
            ),
          ],
          [
            for (final p in [a, b, b + u * thickness, a + u * thickness])
              Vector3(p.dx, p.dy, d.rise - f),
          ],
          StairSolidMaterial.concrete,
        ),
      );
    }
    if (f > 1e-8) {
      for (var i = 0; i < stair.plan.nosings.length; i++) {
        final (a, b) = stair.plan.nosings[i];
        Offset u;
        if (d.isSpiral || d.hasWinders) {
          final other = stair.plan.nosings[i == d.risers - 1 ? i - 1 : i + 1];
          final delta = i == d.risers - 1
              ? a + b - other.$1 - other.$2
              : other.$1 + other.$2 - a - b;
          u = delta / delta.distance;
        } else {
          u = geometry.flights
              .firstWhere(
                (flight) =>
                    i >= flight.firstRiser &&
                    i < flight.firstRiser + flight.count,
              )
              .axis;
        }
        final low = i * d.riser, high = (i + 1) * d.riser;
        if (high - f > low + 1e-8) {
          final coating = math.min(f, math.max(.001, d.nosingProjection));
          result.add(
            verticalPrism(
              [
                a - u * coating,
                b - u * coating,
                b + u * .00001,
                a + u * .00001,
              ],
              low,
              high - f,
              StairSolidMaterial.finish,
            ),
          );
        }
        // Finish on the top landing edge closes the final riser at H exactly.
        if (i == d.risers - 1) {
          result.add(
            verticalPrism(
              [
                a - u * d.nosingProjection,
                b - u * d.nosingProjection,
                b + u * thickness,
                a + u * thickness,
              ],
              high - f,
              high,
              StairSolidMaterial.finish,
            ),
          );
        }
      }
    }
    if (d.startOffset == 0) return result;
    Vector3 shifted(Vector3 p) => Vector3(p.x, p.y, p.z + d.startOffset);
    return [
      for (final solid in result)
        StairSolid(solid.material, [
          for (final t in solid.triangles)
            Triangle3D(
              v0: shifted(t.v0),
              v1: shifted(t.v1),
              v2: shifted(t.v2),
              normal: t.normal,
              color: t.color,
              isDoubleSided: t.isDoubleSided,
            ),
        ]),
    ];
  }

  static List<StairSolid> railings(
    ArchitectStair stair, {
    required ArchitectStorey storey,
    ArchitectProject? project,
  }) {
    final d = stair.design;
    if (d == null || !d.showRailing) return [];
    final result = <StairSolid>[];
    for (final path in ArchitectStairRailings.build(
      stair,
      storey: storey,
      project: project,
    )) {
      final points = simplify(path.base);
      Vector3 at(Vector3 p, double z) => Vector3(p.x, p.y, p.z + z);
      if (path.wallMounted) {
        for (var i = 0; i < points.length - 1; i++) {
          result.add(
            cylinder(
              at(points[i], d.handrailHeight),
              at(points[i + 1], d.handrailHeight),
              .022,
            ),
          );
        }
      } else {
        for (var i = 0; i < points.length - 1; i++) {
          final a = points[i], b = points[i + 1];
          result.add(
            cylinder(at(a, d.guardHeight), at(b, d.guardHeight), .024),
          );
          result.add(
            cylinder(at(a, d.handrailHeight), at(b, d.handrailHeight), .02),
          );
        }
      }
      var distance = 0.0, nextPost = 0.0;
      for (var i = 0; i < points.length - 1; i++) {
        final a = points[i], b = points[i + 1];
        final length = math.sqrt(
          math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2),
        );
        if (length < 1e-8) continue;
        while (nextPost <= distance + length + 1e-8) {
          final t = ((nextPost - distance) / length).clamp(0.0, 1.0);
          final p = a + (b - a) * t;
          if (!path.wallMounted) {
            result.add(cylinder(p, at(p, d.guardHeight), .012));
          } else {
            var nearest = Offset.zero, nearestDistance = double.infinity;
            for (final (a, b) in stair.plan.nosings) {
              final mid = (a + b) / 2,
                  distance = (mid - Offset(p.x, p.y)).distance;
              if (distance < nearestDistance) {
                nearestDistance = distance;
                nearest = mid;
              }
            }
            final away = Offset(p.x, p.y) - nearest;
            if (away.distance > .001) {
              final q =
                  p +
                  Vector3(
                    away.dx / away.distance * .045,
                    away.dy / away.distance * .045,
                    0,
                  );
              result.add(
                cylinder(
                  at(p, d.handrailHeight),
                  at(q, d.handrailHeight),
                  .007,
                ),
              );
            }
          }
          nextPost += path.wallMounted ? .9 : .1;
        }
        distance += length;
      }
      if (!path.wallMounted) {
        result.add(
          cylinder(points.first, at(points.first, d.guardHeight), .02),
        );
        result.add(cylinder(points.last, at(points.last, d.guardHeight), .02));
      }
    }
    return result;
  }

  static List<Vector3> simplify(List<Vector3> points) {
    final result = <Vector3>[];
    for (final p in points) {
      if (result.isNotEmpty && p.distanceTo(result.last) < 1e-8) continue;
      while (result.length > 1) {
        final a = result[result.length - 2], b = result.last;
        if ((b - a).normalized().dot((p - b).normalized()) < .99999) break;
        result.removeLast();
      }
      result.add(p);
    }
    return result;
  }

  static Color color(StairSolidMaterial material) => switch (material) {
    StairSolidMaterial.concrete => concreteColor,
    StairSolidMaterial.finish => finishColor,
    StairSolidMaterial.metal => metalColor,
  };
  static List<(int, int, int)> triangulate(List<Offset> input) {
    final ids = List<int>.generate(input.length, (i) => i);
    double area = 0;
    for (var i = 0; i < input.length; i++) {
      area += ArchitectStairGeometry.cross(
        input[i],
        input[(i + 1) % input.length],
      );
    }
    if (area < 0) ids.setAll(0, ids.reversed.toList());
    final result = <(int, int, int)>[];
    var attempts = 0;
    while (ids.length > 3 && attempts++ < input.length * input.length) {
      var found = false;
      for (var j = 0; j < ids.length; j++) {
        final a = ids[(j + ids.length - 1) % ids.length],
            b = ids[j],
            c = ids[(j + 1) % ids.length];
        if (ArchitectStairGeometry.cross(
              input[b] - input[a],
              input[c] - input[b],
            ) <=
            1e-10) {
          continue;
        }
        bool inside(Offset p) =>
            ArchitectStairGeometry.cross(input[b] - input[a], p - input[a]) >=
                -1e-10 &&
            ArchitectStairGeometry.cross(input[c] - input[b], p - input[b]) >=
                -1e-10 &&
            ArchitectStairGeometry.cross(input[a] - input[c], p - input[c]) >=
                -1e-10;
        if (ids.any(
          (id) => id != a && id != b && id != c && inside(input[id]),
        )) {
          continue;
        }
        result.add((a, b, c));
        ids.removeAt(j);
        found = true;
        break;
      }
      if (!found) throw StateError('Invalid stair solid profile');
    }
    if (ids.length == 3 &&
        ArchitectStairGeometry.cross(
              input[ids[1]] - input[ids[0]],
              input[ids[2]] - input[ids[0]],
            ).abs() >
            1e-12) {
      result.add((ids[0], ids[1], ids[2]));
    }
    return result;
  }

  static StairSolid profilePrism(
    List<Offset> profile,
    StairFlightGeometry flight,
    StairSolidMaterial material,
  ) {
    final cap = triangulate(profile), triangles = <Triangle3D>[];
    Vector3 point(int i, double side) {
      final p = flight.point(profile[i].dx, side);
      return Vector3(p.dx, p.dy, profile[i].dy);
    }

    void face(Vector3 a, Vector3 b, Vector3 c) => triangles.add(
      Triangle3D(
        v0: a,
        v1: b,
        v2: c,
        color: color(material),
        isDoubleSided: true,
      ),
    );
    for (final (a, b, c) in cap) {
      face(
        point(a, -flight.width / 2),
        point(c, -flight.width / 2),
        point(b, -flight.width / 2),
      );
      face(
        point(a, flight.width / 2),
        point(b, flight.width / 2),
        point(c, flight.width / 2),
      );
    }
    for (var i = 0; i < profile.length; i++) {
      final j = (i + 1) % profile.length;
      face(
        point(i, -flight.width / 2),
        point(j, -flight.width / 2),
        point(j, flight.width / 2),
      );
      face(
        point(i, -flight.width / 2),
        point(j, flight.width / 2),
        point(i, flight.width / 2),
      );
    }
    return StairSolid(material, triangles);
  }

  static StairSolid verticalPrism(
    List<Offset> polygon,
    double bottom,
    double top,
    StairSolidMaterial material,
  ) {
    final cap = triangulate(polygon), triangles = <Triangle3D>[];
    Vector3 p(int i, double z) => Vector3(polygon[i].dx, polygon[i].dy, z);
    void face(Vector3 a, Vector3 b, Vector3 c) => triangles.add(
      Triangle3D(
        v0: a,
        v1: b,
        v2: c,
        color: color(material),
        isDoubleSided: true,
      ),
    );
    for (final (a, b, c) in cap) {
      face(p(a, top), p(b, top), p(c, top));
      face(p(a, bottom), p(c, bottom), p(b, bottom));
    }
    for (var i = 0; i < polygon.length; i++) {
      final j = (i + 1) % polygon.length;
      face(p(i, bottom), p(j, bottom), p(j, top));
      face(p(i, bottom), p(j, top), p(i, top));
    }
    return StairSolid(material, triangles);
  }

  static StairSolid hexahedron(
    List<Vector3> bottom,
    List<Vector3> top,
    StairSolidMaterial material,
  ) {
    final triangles = <Triangle3D>[];
    void face(Vector3 a, Vector3 b, Vector3 c) => triangles.add(
      Triangle3D(
        v0: a,
        v1: b,
        v2: c,
        color: color(material),
        isDoubleSided: true,
      ),
    );
    face(top[0], top[1], top[2]);
    face(top[0], top[2], top[3]);
    face(bottom[0], bottom[2], bottom[1]);
    face(bottom[0], bottom[3], bottom[2]);
    for (var i = 0; i < 4; i++) {
      final j = (i + 1) % 4;
      face(bottom[i], bottom[j], top[j]);
      face(bottom[i], top[j], top[i]);
    }
    return StairSolid(material, triangles);
  }

  static StairSolid cylinder(Vector3 a, Vector3 b, double radius) {
    final axis = (b - a).normalized();
    final ref = axis.z.abs() < .9
        ? const Vector3(0, 0, 1)
        : const Vector3(1, 0, 0);
    final u = axis.cross(ref).normalized() * radius,
        v = axis.cross(u).normalized() * radius;
    const count = 6;
    final triangles = <Triangle3D>[];
    Vector3 ring(Vector3 centre, int i) =>
        centre +
        u * math.cos(2 * math.pi * i / count) +
        v * math.sin(2 * math.pi * i / count);
    void face(Vector3 p, Vector3 q, Vector3 r) => triangles.add(
      Triangle3D(v0: p, v1: q, v2: r, color: metalColor, isDoubleSided: true),
    );
    for (var i = 0; i < count; i++) {
      final j = (i + 1) % count;
      face(ring(a, i), ring(a, j), ring(b, j));
      face(ring(a, i), ring(b, j), ring(b, i));
      face(a, ring(a, j), ring(a, i));
      face(b, ring(b, i), ring(b, j));
    }
    return StairSolid(StairSolidMaterial.metal, triangles);
  }
}
