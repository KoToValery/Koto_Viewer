import 'dart:math' as math;
import 'dart:ui';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import '../services/architect_stair_geometry.dart';
import '../services/architect_stair_railings.dart';

enum StairSolidMaterial { concrete, finish, metal, timber }

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
    if (d.construction != StairConstruction.concrete) return _framed(stair);
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

  /// Open risers on timber cut stringers or continuous steel stringers with
  /// discrete tread seats. These are drawing details, not sized connections.
  /// The same solids drive 3D, elevations and cuts.
  static List<StairSolid> _framed(ArchitectStair stair) {
    final d = stair.design!;
    final material = d.construction == StairConstruction.steel
        ? StairSolidMaterial.metal
        : StairSolidMaterial.timber;
    final result = <StairSolid>[];
    final geometry = ArchitectStairGeometry.of(stair);
    for (final surface in stair.plan.surfaces) {
      final polygon = List<Offset>.of(surface.polygon);
      final step = (surface.elevation / d.riser).round() - 1;
      final (a, b) = stair.plan.nosings[step];
      // Only the leading patch of a curved tread gets a nosing. Landings use
      // their actual incoming edge, rather than the next flight's direction.
      final front = <int>[
        for (var i = 0; i < polygon.length; i++)
          if ((polygon[i] - a).distance < 1e-7 ||
              (polygon[i] - b).distance < 1e-7)
            i,
      ];
      if (front.length == 2 && d.nosingProjection > 0) {
        final edge = b - a;
        var inward = Offset(-edge.dy, edge.dx) / edge.distance;
        final centre =
            polygon.reduce((p, q) => p + q) / polygon.length.toDouble();
        if (ArchitectStairGeometry.dot(centre - (a + b) / 2, inward) < 0) {
          inward = -inward;
        }
        for (final i in front) {
          polygon[i] -= inward * d.nosingProjection;
        }
      }
      result.add(
        verticalPrism(
          polygon,
          surface.elevation + d.startOffset - d.treadThickness,
          surface.elevation + d.startOffset,
          material,
        ),
      );
    }
    if (geometry.flights.isNotEmpty) {
      for (final flight in geometry.flights) {
        for (final side in [-1.0, 1.0]) {
          final across = side * (flight.width - d.stringerWidth) / 2;
          final z = flight.base + d.startOffset - d.treadThickness;
          final support = StairFlightGeometry(
            flight.point(0, across),
            flight.axis,
            d.stringerWidth,
            d.going,
            d.riser,
            flight.count,
            flight.firstRiser,
          );
          if (d.construction == StairConstruction.steel) {
            // The inclined beam stays below every tread. Thin vertical seats
            // bridge to the tread underside without a solid sawtooth web.
            result.add(
              profilePrism(
                [
                  Offset(0, z),
                  Offset(flight.run, z + (flight.count - 1) * d.riser),
                  Offset(
                    flight.run,
                    z + (flight.count - 1) * d.riser - d.stringerDepth,
                  ),
                  Offset(0, z - d.stringerDepth),
                ],
                support,
                material,
              ),
            );
            for (var i = 0; i < flight.count - 1; i++) {
              final x = i * d.going, bottom = z + i * d.riser;
              final length = d.going * .65;
              result.add(
                profilePrism(
                  [
                    Offset(x, bottom),
                    Offset(x, bottom + d.riser),
                    Offset(x + length, bottom + d.riser),
                    Offset(x + length, bottom + d.riser * .65),
                  ],
                  StairFlightGeometry(
                    support.origin,
                    support.axis,
                    math.min(.012, d.stringerWidth / 3),
                    d.going,
                    d.riser,
                    flight.count,
                    flight.firstRiser,
                  ),
                  material,
                ),
              );
            }
            continue;
          }
          // Notched upper edge bears directly under each tread. A straight
          // rising top would otherwise project through the next tread surface.
          final profile = <Offset>[];
          for (var i = 0; i < flight.count - 1; i++) {
            final z =
                flight.base +
                d.startOffset +
                (i + 1) * d.riser -
                d.treadThickness;
            profile.addAll([
              Offset(i * d.going, z),
              Offset((i + 1) * d.going, z),
            ]);
          }
          profile.addAll([
            Offset(
              flight.run,
              flight.top +
                  d.startOffset -
                  d.riser -
                  d.treadThickness -
                  d.stringerDepth,
            ),
            Offset(
              0,
              flight.base +
                  d.startOffset +
                  d.riser -
                  d.treadThickness -
                  d.stringerDepth,
            ),
          ]);
          result.add(profilePrism(profile, support, material));
        }
      }
      for (final landing in geometry.landings) {
        final p = landing.polygon;
        final centre = p.reduce((a, b) => a + b) / p.length.toDouble();
        for (var i = 0; i < p.length; i++) {
          final a = p[i], b = p[(i + 1) % p.length], edge = b - a;
          var inward = Offset(-edge.dy, edge.dx) / edge.distance;
          if (ArchitectStairGeometry.dot(centre - (a + b) / 2, inward) < 0) {
            inward = -inward;
          }
          // Perimeter beams remain inside the landing footprint.
          final inset = inward * d.stringerWidth;
          final top = landing.elevation + d.startOffset - d.treadThickness;
          result.add(
            verticalPrism(
              [a, b, b + inset, a + inset],
              top - d.stringerDepth,
              top,
              material,
            ),
          );
        }
      }
    } else {
      // Side strips follow the actual curved/winding tread patches. Their
      // flat tops touch tread undersides and stay inside the stair footprint.
      final surfaces = stair.plan.surfaces;
      for (var i = 0; i < surfaces.length; i++) {
        final surface = surfaces[i], p = surface.polygon;
        if (p.length != 4) continue;
        final near = p[1] - p[0], far = p[2] - p[3];
        final a = near / near.distance * d.stringerWidth;
        final b = far / far.distance * d.stringerWidth;
        final sliced = d.isSpiral && !d.hasWinders;
        final lowA =
            surface.slopeBase?.first ??
            (sliced
                ? (i ~/ ArchitectStairDesign.spiralSlicesPerGoing +
                          (i % ArchitectStairDesign.spiralSlicesPerGoing) /
                              ArchitectStairDesign.spiralSlicesPerGoing) *
                      d.riser
                : surface.elevation - d.riser);
        final lowB =
            surface.slopeBase?.last ??
            (sliced
                ? lowA + d.riser / ArchitectStairDesign.spiralSlicesPerGoing
                : surface.elevation);
        final top = surface.elevation + d.startOffset - d.treadThickness;
        for (final polygon in [
          [p[0], p[0] + a, p[3] + b, p[3]],
          [p[1] - a, p[1], p[2], p[2] - b],
        ]) {
          final bottom = [
            for (var j = 0; j < 4; j++)
              Vector3(
                polygon[j].dx,
                polygon[j].dy,
                (j < 2 ? lowA : lowB) +
                    d.startOffset -
                    d.treadThickness -
                    d.stringerDepth,
              ),
          ];
          final steel = d.construction == StairConstruction.steel;
          result.add(
            hexahedron(bottom, [
              for (var j = 0; j < 4; j++)
                Vector3(
                  polygon[j].dx,
                  polygon[j].dy,
                  steel ? bottom[j].z + d.stringerDepth : top,
                ),
            ], material),
          );
          if (steel) {
            // Seats occupy the leading portion of each tread, including its
            // straight lead/tail patches and either mirrored winder layout.
            final fraction = (lowA - (surface.elevation - d.riser)) / d.riser;
            if (fraction < .65 - 1e-8) {
              final span = (lowB - lowA) / d.riser;
              final t = span > 1e-8
                  ? ((.65 - fraction) / span).clamp(0.0, 1.0)
                  : 1.0;
              final ratio =
                  math.min(.012, d.stringerWidth / 3) / d.stringerWidth;
              final nearMid = (polygon[0] + polygon[1]) / 2;
              final farMid = (polygon[2] + polygon[3]) / 2;
              final seat = [
                nearMid + (polygon[0] - nearMid) * ratio,
                nearMid + (polygon[1] - nearMid) * ratio,
                farMid + (polygon[2] - farMid) * ratio,
                farMid + (polygon[3] - farMid) * ratio,
              ];
              seat[2] = seat[1] + (seat[2] - seat[1]) * t;
              seat[3] = seat[0] + (seat[3] - seat[0]) * t;
              result.add(
                hexahedron(
                  [
                    for (var j = 0; j < 4; j++)
                      Vector3(
                        seat[j].dx,
                        seat[j].dy,
                        (j < 2 ? lowA : lowA + (lowB - lowA) * t) +
                            d.startOffset -
                            d.treadThickness,
                      ),
                  ],
                  [for (final q in seat) Vector3(q.dx, q.dy, top)],
                  material,
                ),
              );
            }
          }
        }
      }
    }
    return result;
  }

  static List<StairSolid> railings(
    ArchitectStair stair, {
    required ArchitectStorey storey,
    ArchitectProject? project,
  }) {
    final d = stair.design;
    if (d == null || !d.showRailing) return [];
    final result = <StairSolid>[];
    final sweep = d.sweepDegrees * math.pi / 180;
    final guardChordDeviation = d.isSpiral
        ? [d.innerRadius, d.innerRadius + stair.width]
              .map((radius) {
                final segments = math.max(8, (sweep * radius / .12).ceil());
                return radius * (1 - math.cos(sweep / (2 * segments)));
              })
              .reduce(math.max)
        : 0.0;
    // The guard follows the dense plan outline; curved treads use coarser
    // chords. Admit only their maximum arc/chord deviation when finding a foot.
    final footTolerance = d.isSpiral
        ? (d.innerRadius + stair.width) *
                  (1 -
                      math.cos(
                        d.anglePerGoing /
                            (2 * ArchitectStairDesign.spiralSlicesPerGoing),
                      )) +
              guardChordDeviation +
              1e-6
        : d.hasWinders
        ? (d.winderLayout(stair.width).radius + stair.width) *
                  (1 - math.cos(d.winderLayout(stair.width).angle / 16)) +
              1e-6
        : 1e-6;
    Vector3 postFoot(Vector3 p) {
      final point = Offset(p.x, p.y);
      final last = stair.plan.nosings.last;
      // The terminal post bears on the upper floor, which is not an extra
      // generated stair tread. Intermediate posts bear on actual level treads.
      if ((p.z - d.startOffset - d.rise).abs() < 1e-7 &&
          ArchitectStairGeometry.pointSegmentDistance(point, last.$1, last.$2) <
              1e-6) {
        return p;
      }
      double? level;
      for (final surface in stair.plan.surfaces) {
        final z = surface.elevation + d.startOffset;
        // A landing corner can interpolate just below the next tread. Choose
        // the nearest actual bearing level, also distinguishing stacked turns.
        if ((level == null || (z - p.z).abs() < (level - p.z).abs()) &&
            ArchitectStairGeometry.inside(
              point,
              surface.polygon,
              tolerance: footTolerance,
            )) {
          level = z;
        }
      }
      return Vector3(p.x, p.y, level ?? p.z);
    }

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
            result.add(cylinder(postFoot(p), at(p, d.guardHeight), .012));
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
          cylinder(
            postFoot(points.first),
            at(points.first, d.guardHeight),
            .02,
          ),
        );
        result.add(
          cylinder(postFoot(points.last), at(points.last, d.guardHeight), .02),
        );
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
    StairSolidMaterial.timber => const Color(0xFFB58A59),
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
