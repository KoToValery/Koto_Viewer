import 'dart:math' as math;
import 'dart:ui';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../models/architect_project.dart';
import '../services/architect_roof_junctions.dart';
import 'architect_mesh_boolean.dart';
import 'architect_mesh_section.dart';
import 'architect_path_solid.dart';

class ArchitectPanelRoofComponent {
  final String id;
  final ArchitectRoofMaterial material;
  final bool structural;
  final List<Triangle3D> triangles;
  const ArchitectPanelRoofComponent(
    this.id,
    this.material,
    this.triangles, {
    this.structural = false,
  });
  Path section(Offset origin, Offset axis) =>
      ArchitectMeshSection.vertical(triangles, origin, axis);
}

/// One set of closed construction solids supplies every published view.
class ArchitectPanelRoofGeometry {
  static bool _onEdge(Offset q, Offset a, Offset b) {
    final v = b - a;
    if (v.distance < 1e-7) return false;
    final t =
        ((q - a).dx * v.dx + (q - a).dy * v.dy) / (v.dx * v.dx + v.dy * v.dy);
    return t >= -1e-5 &&
        t <= 1.00001 &&
        (q - a - v * t.clamp(0, 1)).distance < 1e-5;
  }

  static ArchitectRoofPlane? _neighbour(
    ArchitectStorey floor,
    ArchitectRoofPlane roof,
    Offset a,
    Offset b,
  ) => floor.roofs
      .where(
        (r) =>
            r.id != roof.id &&
            r.assembly.panels != null &&
            List.generate(r.points.length, (i) => i).any(
              (i) =>
                  _onEdge(
                    a,
                    r.points[i],
                    r.points[(i + 1) % r.points.length],
                  ) &&
                  _onEdge(b, r.points[i], r.points[(i + 1) % r.points.length]),
            ),
      )
      .firstOrNull;
  static bool isSharedEdge(
    ArchitectStorey floor,
    ArchitectRoofPlane roof,
    Offset a,
    Offset b,
  ) => _neighbour(floor, roof, a, b) != null;
  static bool _valley(
    ArchitectRoofPlane roof,
    ArchitectRoofPlane other,
    Offset a,
    Offset b,
  ) {
    final v = b - a, n = Offset(-v.dy, v.dx) / v.distance, mid = (a + b) / 2;
    bool rises(ArchitectRoofPlane r) {
      final plan = Path()..addPolygon(r.points, true),
          inside = plan.contains(mid + n * .05) ? n : -n;
      return r.topElevationAt(mid + inside * .05) >
          r.topElevationAt(mid) + 1e-5;
    }

    return rises(roof) && rises(other);
  }

  static final _cache =
      Expando<
        Map<
          (ArchitectStorey, ArchitectRoofPlane),
          List<ArchitectPanelRoofComponent>
        >
      >();
  static const internalInset = .05;
  static bool internal(ArchitectRoofPlane r) =>
      r.drainage.position == ArchitectGutterPosition.internal;
  static double channelEnd(ArchitectRoofPlane r) =>
      internalInset + r.drainage.gutterWidth;
  static double panelUnderside(ArchitectRoofPlane r, Offset p) =>
      r.undersideElevationAt(p) +
      (r.assembly.panels?.structureDepth ?? 0) / math.cos(r.slopeRadians);

  static Path panelFootprint(
    ArchitectStorey floor,
    ArchitectRoofPlane roof, {
    ArchitectProject? project,
  }) {
    var path = ArchitectRoofJunctions.of(
      floor,
      project: project,
    ).footprint(roof);
    if (internal(roof)) {
      final o = roof.eavesEdge.$1,
          v = roof.slopeDirection,
          u = Offset(v.dy, -v.dx),
          extent = roof.bounds.size.longestSide * 4 + 2;
      final channel = Path()
        ..addPolygon([
          o - u * extent - v * extent,
          o + u * extent - v * extent,
          o + u * extent + v * channelEnd(roof),
          o - u * extent + v * channelEnd(roof),
        ], true);
      path = ArchitectMeshSection.combine(
        PathOperation.difference,
        path,
        channel,
      );
    }
    for (var i = 0; i < roof.points.length; i++) {
      final a = roof.points[i],
          b = roof.points[(i + 1) % roof.points.length],
          other = _neighbour(floor, roof, a, b);
      if (other == null || !_valley(roof, other, a, b)) continue;
      final v = b - a, n = Offset(-v.dy, v.dx) / v.distance;
      path = ArchitectMeshSection.combine(
        PathOperation.difference,
        path,
        Path()..addPolygon([
          a + n * .15,
          b + n * .15,
          b - n * .15,
          a - n * .15,
        ], true),
      );
    }
    return path;
  }

  static List<ArchitectPanelRoofComponent> build(
    ArchitectStorey floor,
    ArchitectRoofPlane roof, {
    ArchitectProject? project,
  }) {
    if (roof.assembly.panels == null) return [];
    final key = (floor, roof);
    if (project != null) {
      final cached = _cache[project]?[key];
      if (cached != null) return cached;
    }
    final p = roof.assembly.panels!;
    p.validate(slope: roof.slopeDegrees, mansard: roof.isMansard);
    final o = roof.eavesEdge.$1,
        v = roof.slopeDirection,
        u = Offset(v.dy, -v.dx),
        cos = math.cos(roof.slopeRadians);
    double s(Offset a) => (a - o).dx * u.dx + (a - o).dy * u.dy;
    double d(Offset a) => (a - o).dx * v.dx + (a - o).dy * v.dy;
    final ss = roof.points.map(s), dd = roof.points.map(d);
    final minS = ss.reduce(math.min),
        maxS = ss.reduce(math.max),
        minD = dd.reduce(math.min),
        maxD = dd.reduce(math.max);
    final footprint = ArchitectRoofJunctions.of(
          floor,
          project: project,
        ).footprint(roof),
        panels = panelFootprint(floor, roof, project: project);
    final result = <ArchitectPanelRoofComponent>[];
    Color color(ArchitectRoofMaterial m) => switch (m) {
      ArchitectRoofMaterial.pir => const Color(0xffeee1b6),
      ArchitectRoofMaterial.waterproofing => const Color(0xff727a7e),
      _ => const Color(0xffabb4ba),
    };
    List<Triangle3D> clip(List<Triangle3D> mesh, Path mask) {
      if (mesh.isEmpty) return mesh;
      final bounds = BoundingBox3D.fromPoints([
        for (final t in mesh) ...[t.v0, t.v1, t.v2],
      ]);
      final rect = Rect.fromLTRB(
        bounds.min.x,
        bounds.min.y,
        bounds.max.x,
        bounds.max.y,
      ).inflate(.001);
      final outside = ArchitectMeshSection.combine(
        PathOperation.difference,
        Path()..addRect(rect),
        mask,
      );
      if (outside.getBounds().isEmpty) return mesh;
      return ArchitectMeshBoolean.subtract(
        mesh,
        ArchitectPathSolid.extrude(
          outside,
          bounds.min.z - 1,
          bounds.max.z + 1,
          color(ArchitectRoofMaterial.steel),
        ),
      );
    }

    void append(
      String id,
      ArchitectRoofMaterial material,
      List<Triangle3D> mesh, {
      bool structural = false,
    }) {
      if (mesh.isEmpty) return;
      result.add(
        ArchitectPanelRoofComponent(
          id,
          material,
          ArchitectMeshBoolean.simplify(mesh),
          structural: structural,
        ),
      );
    }

    List<Triangle3D> along(
      Path profile,
      double a,
      double b,
      ArchitectRoofMaterial material, {
      bool slope = true,
      Path? mask,
    }) {
      Vector3 map(Vector3 q) {
        final xy =
            o +
            u * (slope ? q.x : q.z) +
            v * (slope ? q.z : q.x * cos - q.y * math.sin(roof.slopeRadians));
        return Vector3(
          xy.dx,
          xy.dy,
          floor.elevation + roof.undersideElevationAt(xy) + q.y / cos,
        );
      }

      return clip([
        for (final t in ArchitectPathSolid.extrude(
          profile,
          a,
          b,
          color(material),
        ))
          Triangle3D(
            v0: map(t.v0),
            v1: map(slope ? t.v2 : t.v1),
            v2: map(slope ? t.v1 : t.v2),
            color: color(material),
          ),
      ], mask ?? footprint);
    }

    Path band(double a, double b, double low, double high) =>
        Path()..addRect(Rect.fromLTRB(a, low, b, high));
    final start = internal(roof) ? math.max(minD, channelEnd(roof)) : minD;
    // Each module keeps its full section. Only the core/liner are cut back at
    // a free eaves; the outer weather sheet continues to the drip edge.
    for (var a = minS; a < maxS - 1e-7; a += p.module) {
      final b = math.min(maxS, a + p.module), z = p.structureDepth;
      final knots = <double>{a, b};
      final ribPitch = p.module / 3;
      if (!p.membrane && p.ribHeight > 0) {
        for (var k = 0; k < 3; k++) {
          final center = a + (k + .5) * ribPitch;
          for (final dx in [-.22, -.08, .08, .22]) {
            final x = center + ribPitch * dx;
            if (x > a && x < b) knots.add(x);
          }
        }
      }
      final xs = knots.toList()..sort();
      double rib(double x) {
        if (p.membrane) return 0;
        final delta = (((x - a) / ribPitch) % 1 - .5).abs();
        return p.ribHeight * ((.22 - delta) / .14).clamp(0, 1);
      }

      final core = Path()
        ..addPolygon([
          Offset(a, z + p.skin),
          Offset(b, z + p.skin),
          for (final x in xs.reversed)
            Offset(x, z + p.thickness - p.skin + rib(x)),
        ], true);
      final outer = Path()
        ..addPolygon([
          for (final x in xs) Offset(x, z + p.thickness - p.skin + rib(x)),
          for (final x in xs.reversed) Offset(x, z + p.thickness + rib(x)),
        ], true);
      final setback = internal(roof) ? 0 : p.cutback * cos;
      append(
        'core_$a',
        ArchitectRoofMaterial.pir,
        along(
          core,
          start + setback + p.flashing,
          maxD,
          ArchitectRoofMaterial.pir,
          mask: panels,
        ),
      );
      append(
        'liner_$a',
        ArchitectRoofMaterial.steel,
        along(
          band(a, b, z, z + p.skin),
          start + setback,
          maxD,
          ArchitectRoofMaterial.steel,
          mask: panels,
        ),
      );
      append(
        'weather_$a',
        ArchitectRoofMaterial.steel,
        along(outer, start, maxD, ArchitectRoofMaterial.steel, mask: panels),
      );
      if (p.membrane) {
        append(
          'membrane_$a',
          ArchitectRoofMaterial.waterproofing,
          along(
            band(a, b, z + p.thickness, z + p.thickness + p.membraneThickness),
            start,
            maxD,
            ArchitectRoofMaterial.waterproofing,
            mask: panels,
          ),
        );
      }
      append(
        'end_closure_$a',
        ArchitectRoofMaterial.steel,
        along(
          core,
          start + setback,
          start + setback + p.flashing,
          ArchitectRoofMaterial.steel,
          mask: panels,
        ),
      );
    }
    // Primary I frames follow column IDs. Without selected columns the explicit
    // spacing provides a geometric layout, rather than inventing new columns.
    final supportFloors = project?.storeys ?? [floor];
    final columns = [
      for (final f in supportFloors)
        for (final c in f.columns)
          if (p.columnIds.contains(c.id)) c,
    ];
    final stations = <double>{};
    for (final c in columns) {
      final x = s(c.position);
      if (x >= minS - .001 && x <= maxS + .001) stations.add(x);
    }
    if (stations.isEmpty && p.columnIds.isEmpty) {
      final edge = math.min(roof.eavesOverhang, (maxS - minS) / 4);
      for (var x = minS + edge; x <= maxS - edge + .001; x += p.frameSpacing) {
        stations.add(x);
      }
      stations.add(maxS - edge);
    }
    final sorted = stations.toList()..sort();
    final unique = <double>[];
    for (final x in sorted) {
      if (unique.isEmpty || (x - unique.last).abs() > .001) unique.add(x);
    }
    final w = p.beamWidth / 2,
        web = p.beamWeb / 2,
        h = p.beamDepth,
        t = p.beamFlange;
    final iProfile = Path()
      ..addPolygon([
        Offset(-w, 0),
        Offset(w, 0),
        Offset(w, t),
        Offset(web, t),
        Offset(web, h - t),
        Offset(w, h - t),
        Offset(w, h),
        Offset(-w, h),
        Offset(-w, h - t),
        Offset(-web, h - t),
        Offset(-web, t),
        Offset(-w, t),
      ], true);
    final beamFrom = minD + (roof.manualSupportDistance ?? roof.eavesOverhang);
    for (final x in unique) {
      append(
        'frame_$x',
        ArchitectRoofMaterial.steel,
        along(
          iProfile.shift(Offset(x, 0)),
          beamFrom,
          maxD,
          ArchitectRoofMaterial.steel,
        ),
        structural: true,
      );
    }
    // A shorter selected column receives a hollow steel head up to the sloped
    // bearing plane. Existing column dimensions are never silently stretched.
    for (final source in supportFloors) {
      for (final c in source.columns.where((c) => p.columnIds.contains(c.id))) {
        final station = d(c.position);
        if (station < beamFrom - 1e-5 || station > maxD + 1e-5) continue;
        final bottom =
                source.elevation + c.baseOffset + (c.height ?? source.height),
            top = floor.elevation + roof.undersideElevationAt(c.position);
        if (top - bottom < .002) continue;
        final width = math.min(p.beamWidth, math.min(c.width, c.depth)),
            t = math.min(p.beamWeb, width / 5);
        final tube = Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(
            Rect.fromCenter(center: c.position, width: width, height: width),
          )
          ..addRect(
            Rect.fromCenter(
              center: c.position,
              width: width - 2 * t,
              height: width - 2 * t,
            ),
          );
        append(
          'column_head_${c.id}',
          ArchitectRoofMaterial.steel,
          ArchitectPathSolid.between(
            tube,
            (_) => bottom,
            (xy) => floor.elevation + roof.undersideElevationAt(xy),
            color(ArchitectRoofMaterial.steel),
          ),
          structural: true,
        );
      }
    }
    final pw = p.purlinWidth, pt = p.purlinMetal, ph = p.purlinDepth;
    final zProfile = Path()
      ..addPolygon([
        Offset(-pw, 0),
        Offset(pt / 2, 0),
        Offset(pt / 2, ph - pt),
        Offset(pw, ph - pt),
        Offset(pw, ph),
        Offset(-pt / 2, ph),
        Offset(-pt / 2, pt),
        Offset(-pw, pt),
      ], true);
    final rails = <double>{};
    for (var x = start + pw; x < maxD - pw; x += p.purlinSpacing * cos) {
      rails.add(x);
    }
    rails.add(maxD - pw);
    for (final x in rails) {
      append(
        'purlin_$x',
        ArchitectRoofMaterial.steel,
        along(
          zProfile.shift(
            Offset(
              (x + p.structureDepth * math.sin(roof.slopeRadians)) / cos,
              p.beamDepth,
            ),
          ),
          minS,
          maxS,
          ArchitectRoofMaterial.steel,
          slope: false,
        ),
        structural: true,
      );
    }
    // Reserve the actual internal gutter trough in every intersecting member.
    if (internal(roof)) {
      final a = o - u * (maxS.abs() + maxD.abs() + 10),
          b = o + u * (maxS.abs() + maxD.abs() + 10);
      final channel = Path()
        ..addPolygon([
          a + v * internalInset,
          b + v * internalInset,
          b + v * channelEnd(roof),
          a + v * channelEnd(roof),
        ], true);
      final cut = ArchitectPathSolid.between(
        channel,
        (xy) =>
            floor.elevation +
            panelUnderside(roof, xy) +
            p.thickness / cos -
            .02 -
            roof.drainage.gutterDepth -
            .006,
        (xy) => floor.elevation + roof.topElevationAt(xy) + 1,
        color(ArchitectRoofMaterial.steel),
      );
      for (var j = 0; j < result.length; j++) {
        final c = result[j];
        if (!c.structural) continue;
        result[j] = ArchitectPanelRoofComponent(
          c.id,
          c.material,
          ArchitectMeshBoolean.simplify(
            ArchitectMeshBoolean.subtract(c.triangles, cut),
          ),
          structural: true,
        );
      }
      // Insulated outer curb and a folded cap conceal the open box gutter.
      final low = p.structureDepth, high = p.totalDepth + p.upstand;
      append(
        'gutter_curb_core',
        ArchitectRoofMaterial.pir,
        along(
          band(minS, maxS, low, high),
          minD + p.flashing,
          minD + internalInset - p.flashing,
          ArchitectRoofMaterial.pir,
        ),
      );
      for (final edge in [minD, minD + internalInset - p.flashing]) {
        append(
          'curb_skin_$edge',
          ArchitectRoofMaterial.steel,
          along(
            band(minS, maxS, low, high),
            edge,
            edge + p.flashing,
            ArchitectRoofMaterial.steel,
          ),
        );
      }
      append(
        'curb_cap',
        ArchitectRoofMaterial.steel,
        along(
          band(minS, maxS, high, high + p.flashing),
          minD,
          minD + internalInset,
          ArchitectRoofMaterial.steel,
        ),
      );
    }
    // Thin metal verges close the ends of the panel sandwich; caps sit above
    // the ribs rather than filling their ventilation/closure geometry solid.
    for (var j = 0; j < roof.points.length; j++) {
      final a = roof.points[j],
          b = roof.points[(j + 1) % roof.points.length],
          delta = b - a;
      if (delta.distance < 1e-6) continue;
      final n = Offset(-delta.dy, delta.dx) / delta.distance;
      final mid = (a + b) / 2,
          inside = footprint.contains(mid + n * .01) ? n : -n;
      final neighbour = _neighbour(floor, roof, a, b);
      if (neighbour != null) {
        // One folded ridge/hip flashing owns both sides of a shared edge.
        // There is no solid verge plate buried between the two panel cores.
        if (roof.id.compareTo(neighbour.id) < 0) {
          final valley = _valley(roof, neighbour, a, b);
          final strip = Path()
            ..addPolygon([
              a + n * .15,
              b + n * .15,
              b - n * .15,
              a - n * .15,
            ], true);
          for (final adjacent in [roof, neighbour]) {
            final half = ArchitectMeshSection.combine(
              PathOperation.intersect,
              strip,
              valley
                  ? ArchitectRoofJunctions.of(
                      floor,
                      project: project,
                    ).footprint(adjacent)
                  : panelFootprint(floor, adjacent, project: project),
            );
            append(
              '${valley ? "valley" : "joint"}_${neighbour.id}_${adjacent.id}_$j',
              ArchitectRoofMaterial.steel,
              ArchitectPathSolid.between(
                half,
                (xy) =>
                    floor.elevation +
                    adjacent.topElevationAt(xy) -
                    (valley
                        ? adjacent.assembly.panels!.profileHeight /
                                  math.cos(adjacent.slopeRadians) +
                              .025
                        : 0),
                (xy) =>
                    floor.elevation +
                    adjacent.topElevationAt(xy) +
                    p.flashing -
                    (valley
                        ? adjacent.assembly.panels!.profileHeight /
                                  math.cos(adjacent.slopeRadians) +
                              .025
                        : 0),
                color(ArchitectRoofMaterial.steel),
              ),
            );
            if (valley) {
              final plane = Path()..addPolygon(adjacent.points, true),
                  side = plane.contains(mid + n * .05) ? n : -n;
              final closure = Path()
                ..addPolygon([
                  a + side * (.15 - p.flashing),
                  b + side * (.15 - p.flashing),
                  b + side * .15,
                  a + side * .15,
                ], true);
              append(
                'valley_closure_${adjacent.id}_$j',
                ArchitectRoofMaterial.steel,
                ArchitectPathSolid.between(
                  closure,
                  (xy) => floor.elevation + panelUnderside(adjacent, xy),
                  (xy) => floor.elevation + adjacent.topElevationAt(xy),
                  color(ArchitectRoofMaterial.steel),
                ),
              );
            }
          }
        }
        continue;
      }
      if (d(a).abs() < 1e-5 && d(b).abs() < 1e-5) continue;
      final edge = Path()
        ..addPolygon([
          a,
          b,
          b - inside * p.flashing,
          a - inside * p.flashing,
        ], true);
      append(
        'edge_$j',
        ArchitectRoofMaterial.steel,
        ArchitectPathSolid.between(
          edge,
          (xy) => floor.elevation + panelUnderside(roof, xy),
          (xy) => floor.elevation + roof.topElevationAt(xy),
          color(ArchitectRoofMaterial.steel),
        ),
      );
      final cap = ArchitectMeshSection.combine(
        PathOperation.intersect,
        Path()..addPolygon([a, b, b + inside * .12, a + inside * .12], true),
        panels,
      );
      append(
        'cap_$j',
        ArchitectRoofMaterial.steel,
        ArchitectPathSolid.between(
          cap,
          (xy) => floor.elevation + roof.topElevationAt(xy),
          (xy) => floor.elevation + roof.topElevationAt(xy) + p.flashing,
          color(ArchitectRoofMaterial.steel),
        ),
      );
    }
    // Resolve same-material overlaps at end closures and edge sheets. Large
    // cores and the disjoint frame zones are not repeatedly boolean-subtracted.
    final cleaned = <ArchitectPanelRoofComponent>[];
    for (final c in result) {
      var mesh = c.triangles;
      if (c.id.startsWith('edge_') ||
          c.id.startsWith('end_closure') ||
          c.id.startsWith('curb_')) {
        for (final previous in cleaned) {
          mesh = ArchitectMeshBoolean.subtract(mesh, previous.triangles);
        }
      }
      if (mesh.isNotEmpty) {
        cleaned.add(
          ArchitectPanelRoofComponent(
            c.id,
            c.material,
            mesh,
            structural: c.structural,
          ),
        );
      }
    }
    if (project != null) (_cache[project] ??= {})[key] = cleaned;
    return cleaned;
  }
}
