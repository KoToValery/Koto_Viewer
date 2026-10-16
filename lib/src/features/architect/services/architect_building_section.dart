import 'dart:ui';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import '../models/architect_section.dart';
import '../models/architect_slab_assembly.dart';
import '../rendering/architect_stair_mesh.dart';
import 'architect_slab_geometry.dart';
import 'architect_stair_section.dart';

class ArchitectSectionRegion {
  final String sourceId;
  final SlabMaterial material;
  final Path path;
  final bool slab;
  const ArchitectSectionRegion(
    this.sourceId,
    this.material,
    this.path, {
    this.slab = false,
  });
}

class ArchitectBuildingSection {
  final List<ArchitectSectionRegion> regions;
  final Rect bounds;
  const ArchitectBuildingSection(this.regions, this.bounds);

  static ArchitectBuildingSection build(
    ArchitectProject project,
    ArchitectSection cut,
  ) {
    final regions = <ArchitectSectionRegion>[];
    void mesh(String id, List<Triangle3D> tris, SlabMaterial material) {
      final section = ArchitectStairSection.build(
        [StairSolid(StairSolidMaterial.concrete, tris)],
        cut.start,
        cut.axis,
      );
      final path = section.regions[StairSolidMaterial.concrete];
      if (path == null) return;
      final clipped = Path.combine(
        PathOperation.intersect,
        path,
        Path()..addRect(Rect.fromLTRB(0, -1e6, cut.length, 1e6)),
      );
      if (!clipped.getBounds().isEmpty) {
        regions.add(ArchitectSectionRegion(id, material, clipped));
      }
    }

    for (final floor in project.storeys) {
      for (final slab in floor.slabs) {
        final spans = ArchitectSlabGeometry.intervals(floor, slab, cut);
        for (final surface in ArchitectSlabGeometry.surfaces(
          project,
          floor,
          slab,
        )) {
          final path = Path();
          for (final (a, b) in spans) {
            final pa = cut.pointAt(a), pb = cut.pointAt(b);
            path.addPolygon([
              Offset(a, surface.topAt(pa)),
              Offset(b, surface.topAt(pb)),
              Offset(b, surface.bottomAt(pb)),
              Offset(a, surface.bottomAt(pa)),
            ], true);
          }
          if (spans.isNotEmpty) {
            regions.add(
              ArchitectSectionRegion(
                slab.id,
                surface.layer.material,
                path,
                slab: true,
              ),
            );
          }
        }
      }
      for (final wall in floor.walls) {
        mesh(
          wall.id,
          wall
              .copyWith(height: wall.effectiveHeight(floor.height))
              .build3D(storeyElevation: floor.elevation),
          SlabMaterial.plaster,
        );
      }
      for (final col in floor.columns) {
        mesh(
          col.id,
          col.build3D(
            storeyElevation: floor.elevation,
            storeyHeight: floor.height,
          ),
          SlabMaterial.concrete,
        );
      }
      for (final beam in floor.beams) {
        mesh(
          beam.id,
          ArchitectStairMesh.verticalPrism(
            beam.polygonCorners,
            floor.elevation + beam.baseOffset,
            floor.elevation + beam.baseOffset + beam.depth,
            StairSolidMaterial.concrete,
          ).triangles,
          SlabMaterial.concrete,
        );
      }
      for (final stair in floor.stairs) {
        for (final solid in [
          ...ArchitectStairMesh.body(stair),
          ...ArchitectStairMesh.railings(
            stair,
            storey: floor,
            project: project,
          ),
        ]) {
          mesh(
            stair.id,
            [
              for (final t in solid.triangles)
                Triangle3D(
                  v0: t.v0 + Vector3(0, 0, floor.elevation),
                  v1: t.v1 + Vector3(0, 0, floor.elevation),
                  v2: t.v2 + Vector3(0, 0, floor.elevation),
                ),
            ],
            solid.material == StairSolidMaterial.concrete
                ? SlabMaterial.concrete
                : SlabMaterial.tile,
          );
        }
      }
    }
    Rect? bounds;
    for (final r in regions) {
      bounds =
          bounds?.expandToInclude(r.path.getBounds()) ?? r.path.getBounds();
    }
    final vertical = bounds ?? Rect.fromLTWH(0, -1, cut.length, 2);
    return ArchitectBuildingSection(
      regions,
      Rect.fromLTRB(0, vertical.top, cut.length, vertical.bottom),
    );
  }

  static ({ArchitectStorey storey, ArchitectSlab slab})? source(
    ArchitectProject project,
    ArchitectSection cut,
    ArchitectSlabDetail detail,
  ) {
    if (detail.station < 0 || detail.station > cut.length) return null;
    for (final floor in project.storeys) {
      for (final slab in floor.slabs.where((s) => s.id == detail.slabId)) {
        if (ArchitectSlabGeometry.intervals(floor, slab, cut).any(
          (s) => detail.station >= s.$1 - 1e-8 && detail.station <= s.$2 + 1e-8,
        )) {
          return (storey: floor, slab: slab);
        }
      }
    }
    return null;
  }

  String? pickSlab(Offset point, double tolerance) {
    for (final r in regions.reversed.where((r) => r.slab)) {
      if (r.path.contains(point)) return r.sourceId;
    }
    for (final r in regions.reversed.where((r) => r.slab)) {
      if ([
        Offset(tolerance, 0),
        Offset(-tolerance, 0),
        Offset(0, tolerance),
        Offset(0, -tolerance),
      ].any((offset) => r.path.contains(point + offset))) {
        return r.sourceId;
      }
    }
    return null;
  }
}
