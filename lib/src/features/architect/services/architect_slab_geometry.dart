import 'dart:math' as math;
import 'dart:ui';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import '../models/architect_section.dart';
import '../models/architect_slab_assembly.dart';
import '../rendering/architect_stair_mesh.dart';
import 'architect_slab_assemblies.dart';

double slabDot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

class SlabLayerSurface {
  final ArchitectSlabLayer layer;
  final double Function(Offset) topAt, bottomAt;
  const SlabLayerSurface(this.layer, this.topAt, this.bottomAt);
  double thicknessAt(Offset p) => topAt(p) - bottomAt(p);
}

class ArchitectSlabGeometry {
  static List<SlabLayerSurface> surfaces(
    ArchitectProject project,
    ArchitectStorey storey,
    ArchitectSlab slab,
  ) {
    final assembly = ArchitectSlabAssemblies.of(project, slab);
    final coreTop = storey.elevation + slab.coreTopOffset;
    final down = Offset(
      math.cos(slab.slopeDirection ?? 0),
      math.sin(slab.slopeDirection ?? 0),
    );
    final low = slab.polygon.isEmpty
        ? 0.0
        : slab.polygon.map((p) => slabDot(p, down)).reduce(math.max);
    double thickness(ArchitectSlabLayer layer, Offset p) =>
        layer.thickness +
        layer.slopePercent / 100 * math.max(0, low - slabDot(p, down));
    final upper = <SlabLayerSurface>[];
    double Function(Offset) top = (_) => coreTop;
    for (final layer in (assembly?.above ?? <ArchitectSlabLayer>[]).reversed) {
      final bottom = top;
      double next(Offset p) => bottom(p) + thickness(layer, p);
      upper.add(SlabLayerSurface(layer, next, bottom));
      top = next;
    }
    final result = [
      ...upper.reversed,
      SlabLayerSurface(
        ArchitectSlabLayer(
          id: 'core',
          material: SlabMaterial.concrete,
          role: SlabLayerRole.base,
          thickness: slab.thickness,
        ),
        (_) => coreTop,
        (_) => coreTop - slab.thickness,
      ),
    ];
    double Function(Offset) bottom = (_) => coreTop - slab.thickness;
    for (final layer in assembly?.below ?? <ArchitectSlabLayer>[]) {
      final prev = bottom;
      double next(Offset p) => prev(p) - layer.thickness;
      result.add(SlabLayerSurface(layer, prev, next));
      bottom = next;
    }
    return result;
  }

  static bool inside(List<Offset> polygon, Offset p) =>
      polygon.length >= 3 && (Path()..addPolygon(polygon, true)).contains(p);

  static bool contains(ArchitectStorey storey, ArchitectSlab slab, Offset p) =>
      inside(slab.polygon, p) &&
      !storey.openings.any((o) => inside(o.boundary, p));

  /// Partition at every contour crossing, then classify midpoints. Handles
  /// concave footprints, overlapping openings and cuts through vertices.
  static List<(double, double)> intervals(
    ArchitectStorey storey,
    ArchitectSlab slab,
    ArchitectSection section,
  ) {
    final breaks = <double>[0, section.length];
    final u = section.axis;
    double cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;
    for (final polygon in [
      slab.polygon,
      ...storey.openings.map((o) => o.boundary),
    ]) {
      for (var i = 0; i < polygon.length; i++) {
        final a = polygon[i], v = polygon[(i + 1) % polygon.length] - a;
        final d = cross(u, v);
        if (d.abs() < 1e-10) continue;
        final t = cross(a - section.start, v) / d;
        final q = cross(a - section.start, u) / d;
        if (t >= 0 && t <= section.length && q >= -1e-9 && q <= 1 + 1e-9) {
          breaks.add(t);
        }
      }
    }
    breaks.sort();
    final result = <(double, double)>[];
    for (var i = 0; i < breaks.length - 1; i++) {
      final a = breaks[i], b = breaks[i + 1];
      if (b - a < 1e-8 ||
          !contains(storey, slab, section.pointAt((a + b) / 2))) {
        continue;
      }
      if (result.isNotEmpty && (result.last.$2 - a).abs() < 1e-8) {
        final last = result.removeLast();
        result.add((last.$1, b));
      } else {
        result.add((a, b));
      }
    }
    return result;
  }

  /// Convex fragments allow the very same holed footprint in 3D as in sections.
  static List<List<Offset>> footprint(
    ArchitectStorey storey,
    ArchitectSlab slab,
  ) {
    var pieces = [
      for (final (a, b, c) in ArchitectStairMesh.triangulate(slab.polygon))
        [slab.polygon[a], slab.polygon[b], slab.polygon[c]],
    ];
    for (final opening in storey.openings) {
      for (final (a, b, c) in ArchitectStairMesh.triangulate(
        opening.boundary,
      )) {
        final clip = [
          opening.boundary[a],
          opening.boundary[b],
          opening.boundary[c],
        ];
        if (_cross(clip[1] - clip[0], clip[2] - clip[0]) < 0) {
          final temp = clip[1];
          clip[1] = clip[2];
          clip[2] = temp;
        }
        pieces = [for (final polygon in pieces) ..._subtract(polygon, clip)];
      }
    }
    return pieces;
  }

  static double _cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;
  static List<Offset> _half(List<Offset> p, Offset a, Offset b, bool inside) {
    final result = <Offset>[];
    double side(Offset q) => _cross(b - a, q - a) * (inside ? 1 : -1);
    for (var i = 0; i < p.length; i++) {
      final x = p[i], y = p[(i + 1) % p.length], dx = side(x), dy = side(y);
      if (dx >= -1e-10) result.add(x);
      if ((dx > 1e-10 && dy < -1e-10) || (dx < -1e-10 && dy > 1e-10)) {
        result.add(x + (y - x) * (dx / (dx - dy)));
      }
    }
    return result;
  }

  static List<List<Offset>> _subtract(List<Offset> polygon, List<Offset> clip) {
    var remaining = polygon;
    final out = <List<Offset>>[];
    for (var i = 0; i < clip.length && remaining.length >= 3; i++) {
      final a = clip[i], b = clip[(i + 1) % clip.length];
      final outside = _half(remaining, a, b, false);
      if (outside.length >= 3) out.add(outside);
      remaining = _half(remaining, a, b, true);
    }
    return out;
  }

  static List<Triangle3D> mesh(
    ArchitectProject project,
    ArchitectStorey storey,
    ArchitectSlab slab,
  ) {
    final result = <Triangle3D>[];
    final pieces = footprint(storey, slab);
    for (final surface in surfaces(project, storey, slab)) {
      final color = materialColor(surface.layer.material);
      for (final p in pieces) {
        Vector3 v(int i, bool top) => Vector3(
          p[i].dx,
          p[i].dy,
          top ? surface.topAt(p[i]) : surface.bottomAt(p[i]),
        );
        void face(Vector3 a, Vector3 b, Vector3 c) => result.add(
          Triangle3D(v0: a, v1: b, v2: c, color: color, isDoubleSided: true),
        );
        for (var i = 1; i < p.length - 1; i++) {
          face(v(0, true), v(i, true), v(i + 1, true));
          face(v(0, false), v(i + 1, false), v(i, false));
        }
        for (var i = 0; i < p.length; i++) {
          final j = (i + 1) % p.length;
          face(v(i, false), v(j, false), v(j, true));
          face(v(i, false), v(j, true), v(i, true));
        }
      }
    }
    return result;
  }

  static Color materialColor(SlabMaterial m) => switch (m) {
    SlabMaterial.concrete ||
    SlabMaterial.blindingConcrete => const Color(0xFF90A4AE),
    SlabMaterial.xps ||
    SlabMaterial.floorInsulation ||
    SlabMaterial.roofInsulation => const Color(0xFFF3C4C9),
    SlabMaterial.mineralWool ||
    SlabMaterial.acousticWool => const Color(0xFFDDD295),
    SlabMaterial.waterproofing ||
    SlabMaterial.vapourBarrier => const Color(0xFF555865),
    SlabMaterial.parquet => const Color(0xFFC59D72),
    SlabMaterial.ballast ||
    SlabMaterial.gravel ||
    SlabMaterial.compactedFill => const Color(0xFFB5A693),
    _ => const Color(0xFFE0D8C8),
  };
}
