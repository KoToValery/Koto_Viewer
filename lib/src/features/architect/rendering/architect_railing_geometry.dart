import 'dart:math' as math;
import 'dart:ui';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../models/architect_wall.dart';
import '../models/architect_railing_design.dart';
import 'architect_path_solid.dart';
import 'architect_mesh_boolean.dart';

class ArchitectRailingComponent {
  final String id;
  final Path plan;
  final List<Triangle3D> triangles;
  final bool occludesProjection;
  const ArchitectRailingComponent(
    this.id,
    this.plan,
    this.triangles, {
    this.occludesProjection = true,
  });
}

/// Actual components, shared by plan, sections, elevations and the 3D scene.
/// The masonry body is deliberately supplied by the ordinary wall solids.
class ArchitectRailingGeometry {
  static const metal = Color(0xFFAAB2B8);
  static const glass = Color(0x554FC3F7);
  static const coping = Color(0xFFCFD2D3);
  static double _offset(ArchitectWall wall) {
    final d = wall.railing!;
    final mounting =
        d.mounting == ArchitectRailingMount.side &&
            d.kind != ArchitectRailingKind.solidCap
        ? wall.thickness / 2 +
              (d.kind == ArchitectRailingKind.glassChannel
                      ? d.channelWidth
                      : d.postSize) /
                  2
        : 0.0;
    return wall.centerLineOffset + wall.exteriorSign * mounting;
  }

  static Offset _point(ArchitectWall wall, double ratio) =>
      wall.arc?.pointAt(ratio, leftOffset: _offset(wall)) ??
      wall.referencePointAt(ratio) + wall.normalAt(ratio) * _offset(wall);

  /// Intersect physical offset lines/circles, rather than the saved references.
  /// Parallel separated paths remain disconnected and keep their end posts.
  static ({Offset point, double ownRatio, double otherRatio})? _joint(
    ArchitectWall a,
    ArchitectWall b,
    Offset node,
  ) {
    final aa = (a.startPoint - node).distance < 1e-5 ? 0.0 : 1.0;
    final bb = (b.startPoint - node).distance < 1e-5 ? 0.0 : 1.0;
    final endA = _point(a, aa), endB = _point(b, bb);
    final candidates = <Offset>[];
    double cross(Offset u, Offset v) => u.dx * v.dy - u.dy * v.dx;
    double dot(Offset u, Offset v) => u.dx * v.dx + u.dy * v.dy;
    double radius(ArchitectWall w) =>
        w.arc!.radius - w.arc!.bulge.sign * _offset(w);
    void lineCircle(ArchitectWall line, ArchitectWall curve) {
      final p = _point(line, 0), u = line.unitVector;
      final f = p - curve.arc!.center, r = radius(curve);
      if (r <= .001) return;
      final along = dot(f, u), discriminant = along * along - dot(f, f) + r * r;
      if (discriminant < -1e-10) return;
      final root = math.sqrt(math.max(0, discriminant));
      candidates.addAll([p + u * (-along - root), p + u * (-along + root)]);
    }

    if (!a.isCurved && !b.isCurved) {
      final u = a.unitVector, v = b.unitVector, den = cross(u, v);
      if (den.abs() > 1e-10) {
        final p = _point(a, 0), q = _point(b, 0);
        candidates.add(p + u * (cross(q - p, v) / den));
      } else if ((endA - endB).distance < 1e-6) {
        candidates.add((endA + endB) / 2);
      }
    } else if (!a.isCurved) {
      lineCircle(a, b);
    } else if (!b.isCurved) {
      lineCircle(b, a);
    } else {
      final delta = b.arc!.center - a.arc!.center, distance = delta.distance;
      final ra = radius(a), rb = radius(b);
      if (distance < 1e-8) {
        if ((endA - endB).distance < 1e-6) candidates.add((endA + endB) / 2);
      } else if (ra > .001 &&
          rb > .001 &&
          distance <= ra + rb + 1e-8 &&
          distance >= (ra - rb).abs() - 1e-8) {
        final along =
            (ra * ra - rb * rb + distance * distance) / (2 * distance);
        final height = math.sqrt(math.max(0, ra * ra - along * along));
        final u = delta / distance, n = Offset(-u.dy, u.dx);
        final middle = a.arc!.center + u * along;
        candidates.addAll([middle + n * height, middle - n * height]);
      }
    }
    final reach = math.min(
      math.min(a.length, b.length) * .45,
      math.max(
        .15,
        4 * math.max(_offset(a).abs(), _offset(b).abs()) +
            2 * math.max(a.thickness, b.thickness),
      ),
    );
    candidates.removeWhere(
      (p) => (p - endA).distance > reach || (p - endB).distance > reach,
    );
    if (candidates.isEmpty) return null;
    candidates.sort(
      (p, q) => ((p - endA).distance + (p - endB).distance).compareTo(
        (q - endA).distance + (q - endB).distance,
      ),
    );
    final p = candidates.first;
    double parameter(ArchitectWall w) =>
        w.arc?.parameter(p) ?? dot(p - _point(w, 0), w.unitVector) / w.length;
    return (point: p, ownRatio: parameter(a), otherRatio: parameter(b));
  }

  static final _cache =
      Expando<
        Map<(List<ArchitectWall>, double), List<ArchitectRailingComponent>>
      >();

  static List<Path> planPaths(
    ArchitectWall wall, {
    List<ArchitectWall> walls = const [],
  }) => [for (final part in components(wall, walls: walls)) part.plan];

  /// Connected metalwork has one published silhouette, without weld seams.
  static String metalGroupId(ArchitectWall wall, List<ArchitectWall> walls) {
    final connected = <String>{wall.id};
    final queue = <ArchitectWall>[wall];
    for (var i = 0; i < queue.length; i++) {
      final current = queue[i];
      for (final other in walls) {
        if (connected.contains(other.id) ||
            other.railing?.signature != wall.railing?.signature ||
            (other.height + other.baseOffset - wall.height - wall.baseOffset)
                    .abs() >
                1e-6) {
          continue;
        }
        if ([current.startPoint, current.endPoint].any(
          (p) =>
              current.connectsAt(p) &&
              other.connectsAt(p) &&
              ((other.startPoint - p).distance < 1e-5 ||
                  (other.endPoint - p).distance < 1e-5) &&
              _joint(current, other, p) != null,
        )) {
          connected.add(other.id);
          queue.add(other);
        }
      }
    }
    final ids = connected.toList()..sort();
    return 'construction:railing:${ids.first}:metal';
  }

  static List<ArchitectRailingComponent> components(
    ArchitectWall wall, {
    double storeyElevation = 0,
    List<ArchitectWall> walls = const [],
  }) {
    if (wall.railing == null) return const [];
    final cached = _cache[wall] ??= {};
    final value = cached.putIfAbsent(
      (walls, storeyElevation),
      () => List.unmodifiable(
        _buildComponents(wall, storeyElevation: storeyElevation, walls: walls),
      ),
    );
    // A wall can survive many immutable neighbour edits; retain only recent
    // plan/3D requests rather than every project snapshot for its lifetime.
    while (cached.length > 4) {
      cached.remove(cached.keys.first);
    }
    return value;
  }

  static List<ArchitectRailingComponent> _buildComponents(
    ArchitectWall wall, {
    required double storeyElevation,
    required List<ArchitectWall> walls,
  }) {
    final d = wall.railing;
    if (d == null || wall.length < .001) return const [];
    d.validate(wall.height);
    final result = <ArchitectRailingComponent>[];
    final base = storeyElevation + wall.baseOffset, top = base + wall.height;
    ArchitectWall? neighbour(bool start) {
      final end = start ? wall.startPoint : wall.endPoint;
      if (!wall.connectsAt(end)) return null;
      final choices =
          walls
              .where(
                (other) =>
                    other.id != wall.id &&
                    other.railing?.signature == d.signature &&
                    other.connectsAt(end) &&
                    (other.height +
                                other.baseOffset -
                                wall.height -
                                wall.baseOffset)
                            .abs() <
                        1e-6 &&
                    ((other.startPoint - end).distance < 1e-5 ||
                        (other.endPoint - end).distance < 1e-5) &&
                    _joint(wall, other, end) != null,
              )
              .toList()
            ..sort((a, b) => a.id.compareTo(b.id));
      return choices.firstOrNull;
    }

    final startNeighbour = neighbour(true), endNeighbour = neighbour(false);
    final startJoint = startNeighbour == null
        ? null
        : _joint(wall, startNeighbour, wall.startPoint);
    final endJoint = endNeighbour == null
        ? null
        : _joint(wall, endNeighbour, wall.endPoint);
    final firstRatio = startJoint?.ownRatio ?? 0.0;
    final lastRatio = endJoint?.ownRatio ?? 1.0;
    double parameter(double ratio) =>
        firstRatio + (lastRatio - firstRatio) * ratio;
    Offset tangent(double ratio) => wall.tangentAt(parameter(ratio));
    Offset at(double ratio) => ratio < 1e-8 && startJoint != null
        ? startJoint.point
        : ratio > 1 - 1e-8 && endJoint != null
        ? endJoint.point
        : _point(wall, parameter(ratio));
    final pathLength = wall.arc == null
        ? (at(1) - at(0)).distance
        : (wall.arc!.radius - wall.arc!.bulge.sign * _offset(wall)) *
              wall.arc!.sweep.abs() *
              (lastRatio - firstRatio).abs();
    final samples = wall.isCurved ? math.max(2, (pathLength / .08).ceil()) : 1;
    Offset endTangent(bool start) {
      final own = tangent(start ? 0 : 1),
          other = start ? startNeighbour : endNeighbour;
      if (other == null) return own;
      final end = start ? wall.startPoint : wall.endPoint;
      final otherAtStart = (other.startPoint - end).distance < 1e-5;
      final joint = start ? startJoint! : endJoint!;
      final away = other.tangentAt(joint.otherRatio) * (otherAtStart ? 1 : -1);
      final adjacent = away * (start ? -1 : 1);
      final sum = own + adjacent;
      return sum.distance < .01 ? own : sum / sum.distance;
    }

    final startTangent = endTangent(true);
    final endTangentValue = endTangent(false);
    final points = [for (var i = 0; i <= samples; i++) at(i / samples)];
    Path band(double width, {double from = 0, double to = 1}) {
      final n = math.max(1, (samples * (to - from)).ceil());
      final centre = [
        for (var i = 0; i <= n; i++) at(from + (to - from) * i / n),
      ];

      final normals = [
        for (var i = 0; i <= n; i++)
          () {
            final ratio = from + (to - from) * i / n;
            final own = tangent(ratio);
            final t = ratio < 1e-8
                ? startTangent
                : ratio > 1 - 1e-8
                ? endTangentValue
                : own;
            final dot = (t.dx * own.dx + t.dy * own.dy).abs().clamp(.25, 1.0);
            return Offset(-t.dy, t.dx) * (width / 2 / dot);
          }(),
      ];
      return Path()..addPolygon([
        for (var i = 0; i <= n; i++) centre[i] + normals[i],
        for (var i = n; i >= 0; i--) centre[i] - normals[i],
      ], true);
    }

    void prism(
      String suffix,
      Path path,
      double bottom,
      double upper, {
      Color color = metal,
      bool occludes = true,
      List<Triangle3D>? trimAgainst,
    }) {
      if (upper <= bottom) return;
      final solid = ArchitectPathSolid.extrude(path, bottom, upper, color);
      result.add(
        ArchitectRailingComponent(
          '${wall.id}:railing:$suffix',
          path,
          trimAgainst == null
              ? solid
              : ArchitectMeshBoolean.subtract(solid, trimAgainst),
          occludesProjection: occludes,
        ),
      );
    }

    Path square(Offset p, Offset u, double width, double depth) {
      final across = Offset(-u.dy, u.dx);
      return Path()..addPolygon([
        p - u * width / 2 - across * depth / 2,
        p + u * width / 2 - across * depth / 2,
        p + u * width / 2 + across * depth / 2,
        p - u * width / 2 + across * depth / 2,
      ], true);
    }

    bool ownsEnd(bool start) {
      final other = start ? startNeighbour : endNeighbour;
      return other == null || wall.id.compareTo(other.id) < 0;
    }

    if (d.kind == ArchitectRailingKind.solidCap) {
      prism(
        'coping',
        band(wall.thickness + .02),
        base + d.solidHeightAt(wall.height),
        top,
        color: coping,
      );
      return result;
    }
    final railRadius = d.handrailDiameter / 2;
    // The uppermost rail surface is exactly the requested total height.
    final rail = _tube(
      points,
      top - railRadius,
      railRadius,
      startTangent: startTangent,
      endTangent: endTangentValue,
      startDirection: tangent(0),
      endDirection: tangent(1),
    );
    result.add(
      ArchitectRailingComponent(
        '${wall.id}:railing:handrail',
        band(d.handrailDiameter),
        rail,
      ),
    );
    final railBottom = top - d.handrailDiameter;
    final solidTop = base + d.solidHeightAt(wall.height);
    if (d.kind == ArchitectRailingKind.glassChannel) {
      final channelBottom =
          base -
          (d.mounting == ArchitectRailingMount.side ? d.channelHeight : 0);
      prism(
        'channel',
        band(d.channelWidth),
        channelBottom,
        channelBottom + d.channelHeight,
      );
    }
    final hasPosts = d.kind != ArchitectRailingKind.glassChannel;
    final bays = !hasPosts
        ? 1
        : math.max(
            1,
            (pathLength /
                    (d.isGlass
                        ? math.min(d.postSpacing, d.panelWidth)
                        : d.postSpacing))
                .ceil(),
          );
    if (hasPosts) {
      for (var i = 0; i <= bays; i++) {
        if (i == 0 && !ownsEnd(true) || i == bays && !ownsEnd(false)) continue;
        final ratio = i / bays;
        final foot = d.hasSolidBody
            ? solidTop - (d.mounting == ArchitectRailingMount.side ? .12 : 0)
            : base - (d.mounting == ArchitectRailingMount.side ? .12 : 0);
        prism(
          'post:$i',
          square(at(ratio), tangent(ratio), d.postSize, d.postSize),
          foot,
          top - railRadius,
          trimAgainst: rail,
        );
      }
    }
    if (d.kind == ArchitectRailingKind.solidStainless) return result;
    if (d.isGlass) {
      final count = d.kind == ArchitectRailingKind.glassPosts
          ? bays
          : math.max(1, (pathLength / d.panelWidth).ceil());
      for (var i = 0; i < count; i++) {
        final clearance = d.kind == ArchitectRailingKind.glassPosts
            ? d.postSize / 2 + d.panelGap / 2
            : d.panelGap / 2;
        final from = (i / count + clearance / pathLength).clamp(0.0, 1.0);
        final to = ((i + 1) / count - clearance / pathLength).clamp(0.0, 1.0);
        if (to <= from) continue;
        final bottom = d.kind == ArchitectRailingKind.glassChannel
            ? base +
                  (d.mounting == ArchitectRailingMount.top
                      ? d.channelHeight
                      : .01)
            : base + d.bottomGap;
        prism(
          'glass:$i',
          band(d.glassThickness, from: from, to: to),
          bottom,
          railBottom,
          color: glass,
          occludes: false,
        );
      }
      return result;
    }
    // Equal modules within each post bay; endpoints belong to the posts.
    for (var bay = 0; bay < bays; bay++) {
      final span = pathLength / bays;
      final count = math.max(1, (span / d.infillSpacing).ceil());
      for (var i = 1; i < count; i++) {
        final along = span * i / count;
        if (math.min(along, span - along) <
            (d.postSize + d.infillWidth) / 2 + .002) {
          continue;
        }
        final ratio = (bay + i / count) / bays;
        prism(
          'infill:$bay:$i',
          d.kind == ArchitectRailingKind.verticalBars
              ? _circle(at(ratio), d.infillWidth / 2)
              : square(at(ratio), tangent(ratio), d.infillWidth, d.infillDepth),
          base + d.bottomGap,
          railBottom,
        );
      }
    }
    return result;
  }

  static Path _circle(Offset centre, double radius) => Path()
    ..addPolygon([
      for (var i = 0; i < 12; i++)
        centre +
            Offset(math.cos(i * math.pi / 6), math.sin(i * math.pi / 6)) *
                radius,
    ], true);

  static List<Triangle3D> _tube(
    List<Offset> path,
    double z,
    double radius, {
    required Offset startTangent,
    required Offset endTangent,
    required Offset startDirection,
    required Offset endDirection,
  }) {
    const sides = 12;
    final rings = <List<Vector3>>[];
    for (var i = 0; i < path.length; i++) {
      final own = i == 0
          ? startDirection
          : i == path.length - 1
          ? endDirection
          : path[i + 1] - path[i];
      final unit = own / own.distance;
      var t = i == 0
          ? startTangent
          : i == path.length - 1
          ? endTangent
          : (path[i + 1] - path[i - 1]);
      t = t / t.distance;
      final scale = (t.dx * unit.dx + t.dy * unit.dy).abs().clamp(.25, 1.0);
      final normal = Offset(-t.dy, t.dx) * (radius / scale);
      rings.add([
        for (var j = 0; j < sides; j++)
          Vector3(
            path[i].dx + normal.dx * math.cos(j * 2 * math.pi / sides),
            path[i].dy + normal.dy * math.cos(j * 2 * math.pi / sides),
            z + radius * math.sin(j * 2 * math.pi / sides),
          ),
      ]);
    }
    final tris = <Triangle3D>[];
    void face(Vector3 a, Vector3 b, Vector3 c) => tris.add(
      Triangle3D(v0: a, v1: b, v2: c, color: metal, isDoubleSided: true),
    );
    for (var i = 1; i < rings.length; i++) {
      for (var j = 0; j < sides; j++) {
        final k = (j + 1) % sides;
        face(rings[i - 1][j], rings[i - 1][k], rings[i][k]);
        face(rings[i - 1][j], rings[i][k], rings[i][j]);
      }
    }
    for (var j = 1; j < sides - 1; j++) {
      face(rings.first[0], rings.first[j + 1], rings.first[j]);
      face(rings.last[0], rings.last[j], rings.last[j + 1]);
    }
    return tris;
  }
}
