import 'dart:math' as math;
import 'dart:ui';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import '../models/architect_section.dart';
import '../models/architect_slab_assembly.dart';
import '../rendering/architect_stair_mesh.dart';
import 'architect_roof_geometry.dart';
import 'architect_slab_geometry.dart';
import 'architect_stair_section.dart';

class ArchitectSectionRegion {
  final String sourceId;
  String get slabId => sourceId;
  String get wallId => sourceId;
  final SlabMaterial material;
  final Path path;
  final bool slab;
  final bool roof;
  final List<Offset>? timberCrossSectionPolygon;
  final Color? customFillColor;

  const ArchitectSectionRegion(
    this.sourceId,
    this.material,
    this.path, {
    this.slab = false,
    this.roof = false,
    this.timberCrossSectionPolygon,
    this.customFillColor,
  });
}

class ArchitectBuildingSection {
  final List<ArchitectSectionRegion> regions;
  final Rect bounds;
  const ArchitectBuildingSection(this.regions, this.bounds);

  static SlabMaterial _mapRoofMaterial(ArchitectRoofMaterial? mat) =>
      switch (mat) {
        ArchitectRoofMaterial.clayTiles ||
        ArchitectRoofMaterial.concreteTiles ||
        ArchitectRoofMaterial.bitumenShingles ||
        ArchitectRoofMaterial.metalSeam => SlabMaterial.tile,
        ArchitectRoofMaterial.timberBoarding ||
        ArchitectRoofMaterial.osb => SlabMaterial.parquet,
        ArchitectRoofMaterial.breathableMembrane =>
          SlabMaterial.breathableMembrane,
        ArchitectRoofMaterial.vapourBarrier => SlabMaterial.vapourBarrier,
        ArchitectRoofMaterial.mineralWool => SlabMaterial.mineralWool,
        ArchitectRoofMaterial.xps => SlabMaterial.xps,
        ArchitectRoofMaterial.waterproofing => SlabMaterial.waterproofing,
        ArchitectRoofMaterial.slopeScreed => SlabMaterial.screed,
        ArchitectRoofMaterial.rcSlab => SlabMaterial.concrete,
        ArchitectRoofMaterial.plasterboard => SlabMaterial.plasterboard,
        null => SlabMaterial.parquet,
      };

  static Color? _roofMemberColor(ArchitectRoofSectionMember member) {
    if (member.kind == ArchitectRoofMemberKind.metalFlashing) {
      return const Color(0xFF37474F);
    }
    if (member.drawTimberDiagonals) {
      return const Color(0xFFD7A86E);
    }
    return switch (member.material) {
      ArchitectRoofMaterial.clayTiles => const Color(0xFFC85A32),
      ArchitectRoofMaterial.concreteTiles => const Color(0xFF7E848C),
      ArchitectRoofMaterial.metalSeam => const Color(0xFF607D8B),
      ArchitectRoofMaterial.bitumenShingles => const Color(0xFF5D4037),
      ArchitectRoofMaterial.timberBoarding ||
      ArchitectRoofMaterial.osb => const Color(0xFFCFA16B),
      ArchitectRoofMaterial.breathableMembrane => const Color(0xFF29B6F6),
      ArchitectRoofMaterial.vapourBarrier => const Color(0xFFFFB300),
      ArchitectRoofMaterial.mineralWool => const Color(0xFFAED581),
      ArchitectRoofMaterial.xps => const Color(0xFF80DEEA),
      ArchitectRoofMaterial.waterproofing => const Color(0xFF37474F),
      ArchitectRoofMaterial.slopeScreed => const Color(0xFFB0BEC5),
      ArchitectRoofMaterial.rcSlab => null,
      ArchitectRoofMaterial.plasterboard => const Color(0xFFECEFF1),
      null => null,
    };
  }

  static ArchitectBuildingSection build(
    ArchitectProject project,
    ArchitectSection cut,
  ) {
    final regions = <ArchitectSectionRegion>[];
    final highPriorityCutouts = <Path>[];

    // 1. Pre-build roof section slices per storey
    final storeyRoofSlices = <String, List<ArchitectRoofSectionSlice>>{};
    for (var i = 0; i < project.storeys.length; i++) {
      final floor = project.storeys[i];
      final lowerFloor = i > 0 ? project.storeys[i - 1] : null;
      final slices = ArchitectRoofGeometry.buildSectionSlices(
        storey: floor,
        sectionLine: cut,
        lowerStorey: lowerFloor,
      );
      if (slices.isNotEmpty) {
        storeyRoofSlices[floor.id] = slices;
        for (final s in slices) {
          highPriorityCutouts.add(s.envelopePath);
        }
      }
    }

    // 2. Build Slab regions first and register their envelopes as high-priority cutouts for walls
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
            highPriorityCutouts.add(path);
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
    }

    Path? sliceMesh(List<Triangle3D> tris) {
      final section = ArchitectStairSection.build(
        [StairSolid(StairSolidMaterial.concrete, tris)],
        cut.start,
        cut.axis,
      );
      final path = section.regions[StairSolidMaterial.concrete];
      if (path == null) return null;
      final clipped = Path.combine(
        PathOperation.intersect,
        path,
        Path()..addRect(Rect.fromLTRB(0, -1e6, cut.length, 1e6)),
      );
      return clipped.getBounds().isEmpty ? null : clipped;
    }

    // 3. Build Walls, Columns, Beams, Stairs — trimming walls against roofs and slabs
    for (var fIdx = 0; fIdx < project.storeys.length; fIdx++) {
      final floor = project.storeys[fIdx];
      // Check if this floor has pitched roofs (or if a dedicated roof-only storey sits directly above it)
      var activeRoofSlices = storeyRoofSlices[floor.id] ?? const [];
      if (activeRoofSlices.isEmpty && fIdx + 1 < project.storeys.length) {
        final upper = project.storeys[fIdx + 1];
        if (upper.walls.isEmpty && upper.roofs.isNotEmpty) {
          activeRoofSlices = storeyRoofSlices[upper.id] ?? const [];
        }
      }

      // Compute max roof underside height on this floor so supporting and gable walls rise to meet the roof underside
      var maxRoofHeightAboveFloor = floor.height;
      for (final slice in activeRoofSlices) {
        for (final pt in slice.bottomProfile) {
          final h = pt.dy - floor.elevation;
          if (h > maxRoofHeightAboveFloor) {
            maxRoofHeightAboveFloor = h;
          }
        }
      }

      for (final wall in floor.walls) {
        final baseWallHeight = wall.effectiveHeight(floor.height);
        final canExtendToRoof = activeRoofSlices.isNotEmpty && !wall.isParapet;
        final prismHeight = canExtendToRoof
            ? math.max(baseWallHeight, maxRoofHeightAboveFloor)
            : baseWallHeight;

        var wallPath = sliceMesh(
          wall
              .copyWith(height: prismHeight)
              .build3D(storeyElevation: floor.elevation),
        );
        if (wallPath == null) continue;

        // If extended to meet a sloped roof, clip the wall top to the underside of the roof slices
        // (and to normal storey height outside the roof footprint)
        if (activeRoofSlices.isNotEmpty && !wall.isParapet) {
          final ceilingClip = Path();
          var cursor = 0.0;
          final normalTop = floor.elevation + baseWallHeight;
          for (final slice in activeRoofSlices) {
            if (slice.fromS > cursor + 1e-4) {
              ceilingClip.addRect(
                Rect.fromLTRB(
                  cursor,
                  floor.elevation - 1.0,
                  slice.fromS,
                  normalTop,
                ),
              );
            }
            final p0 = slice.bottomProfile.first;
            final p1 = slice.bottomProfile.last;
            ceilingClip.addPolygon([
              Offset(slice.fromS, floor.elevation - 1.0),
              Offset(slice.toS, floor.elevation - 1.0),
              Offset(p1.dx, p1.dy),
              Offset(p0.dx, p0.dy),
            ], true);
            cursor = math.max(cursor, slice.toS);
          }
          if (cursor < cut.length - 1e-4) {
            ceilingClip.addRect(
              Rect.fromLTRB(
                cursor,
                floor.elevation - 1.0,
                cut.length + 1.0,
                normalTop,
              ),
            );
          }
          try {
            wallPath = Path.combine(
              PathOperation.intersect,
              wallPath,
              ceilingClip,
            );
          } catch (_) {}
        }

        // Boolean-subtract overlapping roof envelopes (including Mauerlat & Ridge Purlin) and slabs
        // so zero redundant lines appear at wall-to-roof and wall-to-slab junctions!
        for (final cutout in highPriorityCutouts) {
          try {
            wallPath = Path.combine(
              PathOperation.difference,
              wallPath!,
              cutout,
            );
          } catch (_) {}
        }

        if (!wallPath!.getBounds().isEmpty) {
          regions.add(
            ArchitectSectionRegion(wall.id, SlabMaterial.plaster, wallPath),
          );
        }
      }

      for (final col in floor.columns) {
        final colPath = sliceMesh(
          col.build3D(
            storeyElevation: floor.elevation,
            storeyHeight: floor.height,
          ),
        );
        if (colPath != null) {
          regions.add(
            ArchitectSectionRegion(col.id, SlabMaterial.concrete, colPath),
          );
        }
      }

      for (final beam in floor.beams) {
        final beamPath = sliceMesh(
          ArchitectStairMesh.verticalPrism(
            beam.polygonCorners,
            floor.elevation + beam.baseOffset,
            floor.elevation + beam.baseOffset + beam.depth,
            StairSolidMaterial.concrete,
          ).triangles,
        );
        if (beamPath != null) {
          regions.add(
            ArchitectSectionRegion(beam.id, SlabMaterial.concrete, beamPath),
          );
        }
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
          final stairPath = sliceMesh([
            for (final t in solid.triangles)
              Triangle3D(
                v0: t.v0 + Vector3(0, 0, floor.elevation),
                v1: t.v1 + Vector3(0, 0, floor.elevation),
                v2: t.v2 + Vector3(0, 0, floor.elevation),
              ),
          ]);
          if (stairPath != null) {
            regions.add(
              ArchitectSectionRegion(
                stair.id,
                solid.material == StairSolidMaterial.concrete
                    ? SlabMaterial.concrete
                    : SlabMaterial.tile,
                stairPath,
              ),
            );
          }
        }
      }

      // 4. Add all detailed roof members (layers, battens, counter-battens, rafters, Mauerlat, purlins, fascia)
      final floorSlices = storeyRoofSlices[floor.id] ?? const [];
      for (final slice in floorSlices) {
        for (final member in slice.members) {
          if (member.path.getBounds().isEmpty) continue;
          regions.add(
            ArchitectSectionRegion(
              member.roofId,
              _mapRoofMaterial(member.material),
              member.path,
              slab: true,
              roof: true,
              timberCrossSectionPolygon: member.drawTimberDiagonals
                  ? member.polygon
                  : null,
              customFillColor: _roofMemberColor(member),
            ),
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

  static ({ArchitectStorey storey, ArchitectRoofPlane roof})? roofSource(
    ArchitectProject project,
    ArchitectSection cut,
    ArchitectSlabDetail detail,
  ) {
    if (detail.station < 0 || detail.station > cut.length) return null;
    return findRoofById(project, detail.slabId);
  }

  static ({ArchitectStorey storey, ArchitectRoofPlane roof})? findRoofById(
    ArchitectProject project,
    String roofId,
  ) {
    for (final floor in project.storeys) {
      for (final roof in floor.roofs.where((r) => r.id == roofId)) {
        return (storey: floor, roof: roof);
      }
    }
    return null;
  }

  String? pickRoof(Offset point, double tolerance) {
    for (final r in regions.reversed.where((r) => r.roof)) {
      if (r.path.contains(point)) return r.sourceId;
    }
    for (final r in regions.reversed.where((r) => r.roof)) {
      if ([
        Offset(tolerance, 0),
        Offset(-tolerance, 0),
        Offset(0, tolerance),
        Offset(0, -tolerance),
        Offset(tolerance * 0.7, tolerance * 0.7),
        Offset(-tolerance * 0.7, -tolerance * 0.7),
      ].any((offset) => r.path.contains(point + offset))) {
        return r.sourceId;
      }
    }
    return null;
  }

  Rect? roofBounds(String roofId) {
    Rect? result;
    for (final r in regions.where((r) => r.roof && r.sourceId == roofId)) {
      final b = r.path.getBounds();
      if (!b.isEmpty) {
        result = result?.expandToInclude(b) ?? b;
      }
    }
    return result;
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
