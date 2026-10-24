import '../models/architect_hatch_pattern.dart';
import '../rendering/architect_roof_drainage_mesh.dart';
import 'dart:math' as math;
import 'dart:ui';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../models/architect_elements.dart';
import '../models/architect_material_layer.dart';
import '../models/architect_project.dart';
import '../models/architect_section.dart';
import '../models/architect_section_visibility.dart';
import '../models/architect_elevation.dart';
import '../models/architect_slab_assembly.dart';
import '../rendering/architect_stair_mesh.dart';
import '../rendering/architect_path_solid.dart';
import '../rendering/architect_wall_solids.dart';
import 'architect_roof_geometry.dart';
import 'architect_slab_geometry.dart';
import 'architect_stair_section.dart';
import 'architect_building_elevation.dart';

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
  final ArchitectHatchPattern? hatchPattern;

  const ArchitectSectionRegion(
    this.sourceId,
    this.material,
    this.path, {
    this.slab = false,
    this.roof = false,
    this.timberCrossSectionPolygon,
    this.customFillColor,
    this.hatchPattern,
  });
}

class ArchitectBuildingSection {
  static final _drawingCache = Expando<List<ArchitectSectionRegion>>();
  final List<ArchitectSectionRegion> regions;
  final Rect bounds;
  final Map<String, Path> roofProfiles;

  /// Visible surfaces behind the cut, already masked by cut solids. These are
  /// projection lines only: they must never acquire section hatching.
  final ArchitectBuildingElevation? background;
  const ArchitectBuildingSection(
    this.regions,
    this.bounds, {
    this.roofProfiles = const {},
    this.background,
  });

  /// Ownership stays in [regions] for picking; equal materials share one
  /// published contour, including across vertical bands and wall junctions.
  List<ArchitectSectionRegion> get drawingRegions =>
      _drawingCache[this] ??= _mergeDrawingRegions();
  List<ArchitectSectionRegion> _mergeDrawingRegions() {
    final result = <ArchitectSectionRegion>[],
        indices = <(SlabMaterial, int?, bool, ArchitectHatchPattern?), int>{};
    for (final region in regions) {
      if (region.roof || region.timberCrossSectionPolygon != null) {
        result.add(region);
        continue;
      }
      final key = (
            region.material,
            region.customFillColor?.toARGB32(),
            region.slab,
            region.hatchPattern,
          ),
          index = indices[key];
      if (index == null) {
        indices[key] = result.length;
        result.add(region);
        continue;
      }
      final previous = result[index];
      result[index] = ArchitectSectionRegion(
        previous.sourceId,
        previous.material,
        Path.combine(PathOperation.union, previous.path, region.path),
        slab: previous.slab,
        customFillColor: previous.customFillColor,
        hatchPattern: previous.hatchPattern,
      );
    }
    return result;
  }

  Map<String, Path> get elementPaths {
    final result = <String, Path>{...?background?.elementPaths};
    for (final region in regions) {
      result[region.sourceId] = result.containsKey(region.sourceId)
          ? Path.combine(
              PathOperation.union,
              result[region.sourceId]!,
              region.path,
            )
          : region.path;
    }
    return result;
  }

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
    if (cut.steps.isNotEmpty) {
      final regions = <ArchitectSectionRegion>[];
      final profiles = <String, Path>{};
      final faces = <Path>[];
      final paths = <String, Path>{};
      final operations = <({Path lines, Path clip})>[];
      Rect? bounds;
      for (final s in cut.segments) {
        final depth = cut.viewDepth == null ? null : cut.viewDepth! - s.offset;
        if (depth != null && depth <= 0) continue;
        final part = build(
          project,
          cut.copyWith(
            start: s.start,
            end: s.end,
            steps: const [],
            details: const [],
            viewDepth: depth,
          ),
        );
        final shift = Offset(s.station, 0);
        for (final r in part.regions) {
          regions.add(
            ArchitectSectionRegion(
              r.sourceId,
              r.material,
              r.path.shift(shift),
              slab: r.slab,
              roof: r.roof,
              customFillColor: r.customFillColor,
              hatchPattern: r.hatchPattern,
              timberCrossSectionPolygon: r.timberCrossSectionPolygon
                  ?.map((p) => p + shift)
                  .toList(),
            ),
          );
        }
        void merge(Map<String, Path> target, Map<String, Path> source) {
          for (final e in source.entries) {
            final p = e.value.shift(shift);
            target[e.key] = target.containsKey(e.key)
                ? Path.combine(PathOperation.union, target[e.key]!, p)
                : p;
          }
        }

        merge(profiles, part.roofProfiles);
        merge(paths, part.background?.elementPaths ?? {});
        faces.addAll(part.background?.faces.map((p) => p.shift(shift)) ?? []);
        operations.addAll([
          for (final op
              in part.background?.operations ?? <({Path lines, Path clip})>[])
            (lines: op.lines.shift(shift), clip: op.clip.shift(shift)),
        ]);
        bounds =
            bounds?.expandToInclude(part.bounds.shift(shift)) ??
            part.bounds.shift(shift);
      }
      final box = bounds ?? Rect.fromLTWH(0, 0, cut.length, 3);
      return ArchitectBuildingSection(
        regions,
        box,
        roofProfiles: profiles,
        background: ArchitectBuildingElevation(
          faces,
          box,
          elementPaths: paths,
          operations: operations,
        ),
      );
    }
    final visibility = cut.visibility.resolved(project.sectionVisibility);
    final regions = <ArchitectSectionRegion>[];
    final highPriorityCutouts = <Path>[];
    final roofProfiles = <String, Path>{};

    // 1. Pre-build roof section slices per storey
    final storeyRoofSlices = <String, List<ArchitectRoofSectionSlice>>{};
    for (final floor in project.storeys) {
      final lowerFloor = ArchitectRoofGeometry.supportingWallStorey(
        project,
        floor,
      );
      final slices = ArchitectRoofGeometry.buildSectionSlices(
        project: project,
        storey: floor,
        sectionLine: cut,
        lowerStorey: lowerFloor,
      );
      if (slices.isNotEmpty) {
        storeyRoofSlices[floor.id] = slices;
        for (final s in slices) {
          highPriorityCutouts.add(s.envelopePath);
          final roof = floor.roofs.firstWhere((r) => r.id == s.roofId);
          final a = s.bottomProfile.first, b = s.bottomProfile.last;
          (roofProfiles[s.roofId] ??= Path()).addPolygon([
            a,
            b,
            Offset(
              b.dx,
              floor.elevation + roof.topElevationAt(cut.pointAt(b.dx)),
            ),
            Offset(
              a.dx,
              floor.elevation + roof.topElevationAt(cut.pointAt(a.dx)),
            ),
          ], true);
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
    for (final floor in project.storeys) {
      final activeRoofSlices = <ArchitectRoofSectionSlice>[
        ...?storeyRoofSlices[floor.id],
        for (final upper in project.storeys)
          if (upper.id != floor.id &&
              ArchitectRoofGeometry.supportingWallStorey(project, upper)?.id ==
                  floor.id)
            ...?storeyRoofSlices[upper.id],
      ]..sort((a, b) => a.fromS.compareTo(b.fromS));

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

      final useCompositions = floor.walls.any(
        (w) => w.layers.isNotEmpty || w.plinth.enabled || w.isCurved,
      );
      final sharedSolids = useCompositions
          ? ArchitectWallSolids.build(
              floor,
              project.wallTypes,
              project: project,
            )
          : const <ArchitectWallSolid>[];
      for (final wall in floor.walls) {
        final baseWallHeight = wall.effectiveHeight(floor.height);
        final canExtendToRoof = activeRoofSlices.isNotEmpty && !wall.isParapet;
        final prismHeight = canExtendToRoof
            ? math.max(baseWallHeight, maxRoofHeightAboveFloor)
            : baseWallHeight;

        final sources = <Triangle3D, String>{};
        final wallMesh = wall
            .copyWith(height: prismHeight)
            .build3D(
              storeyElevation: floor.elevation,
              sources: sources,
              includeSolid: !useCompositions,
              resolveComposition: !useCompositions,
            );
        // Each material/height band is a closed solid. Slicing their joined
        // triangle soup makes shared cap edges branch, so contour tracing can
        // discard all but the lowest band (for example a 0.85 m plinth).
        // Intersect the closed solids separately, then unite their 2D regions.
        final materialSections = <ArchitectWallSolid, Path>{};
        Path? accumulated;
        void addWallSection(Path? path) {
          if (path == null) return;
          accumulated = accumulated == null
              ? path
              : Path.combine(PathOperation.union, accumulated!, path);
        }

        if (useCompositions) {
          for (final solid in sharedSolids.where((s) => s.wall.id == wall.id)) {
            final path = sliceMesh(solid.triangles);
            if (path == null) continue;
            materialSections[solid] = path;
            addWallSection(path);
          }
          for (final id in sources.values.toSet()) {
            addWallSection(
              sliceMesh([
                for (final t in wallMesh)
                  if (sources[t] == id) t,
              ]),
            );
          }
        } else {
          accumulated = sliceMesh(wallMesh);
        }
        var wallPath = accumulated;
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

        for (final id in sources.values.toSet()) {
          final opening = sliceMesh([
            for (final t in wallMesh)
              if (sources[t] == id) t,
          ]);
          if (opening == null) continue;
          final clipped = Path.combine(
            PathOperation.intersect,
            opening,
            wallPath!,
          );
          if (clipped.getBounds().isEmpty) continue;
          wallPath = Path.combine(PathOperation.difference, wallPath, clipped);
          regions.add(ArchitectSectionRegion(id, SlabMaterial.tile, clipped));
        }
        if (!wallPath!.getBounds().isEmpty) {
          if (useCompositions) {
            var remaining = wallPath;
            for (final part in sharedSolids.where(
              (s) => s.wall.id == wall.id,
            )) {
              final raw = materialSections[part];
              if (raw == null) continue;
              final region = Path.combine(
                PathOperation.intersect,
                remaining,
                raw,
              );
              remaining = Path.combine(
                PathOperation.difference,
                remaining,
                region,
              );
              if (region.getBounds().isEmpty) continue;
              final material = switch (part.layer.material) {
                ArchitectMaterial.concrete => SlabMaterial.concrete,
                ArchitectMaterial.xps => SlabMaterial.xps,
                ArchitectMaterial.eps => SlabMaterial.floorInsulation,
                ArchitectMaterial.stoneWool => SlabMaterial.mineralWool,
                ArchitectMaterial.timber => SlabMaterial.parquet,
                ArchitectMaterial.tile ||
                ArchitectMaterial.stone => SlabMaterial.tile,
                _ => SlabMaterial.plaster,
              };
              regions.add(
                ArchitectSectionRegion(
                  wall.id,
                  material,
                  region,
                  customFillColor: part.layer.material.color,
                ),
              );
            }
          } else {
            regions.add(
              ArchitectSectionRegion(wall.id, SlabMaterial.plaster, wallPath),
            );
          }
        }
      }

      for (final roof in floor.roofs) {
        final path = sliceMesh(
          ArchitectRoofDrainageMesh.build(
            project,
            floor,
            roof,
            includeGutters: visibility
                .modeFor(ArchitectSectionCategory.gutters)
                .showsCut,
            includeDownpipes: visibility
                .modeFor(ArchitectSectionCategory.downpipes)
                .showsCut,
          ),
        );
        if (path != null) {
          regions.add(
            ArchitectSectionRegion(
              roof.id,
              SlabMaterial.custom,
              path,
              customFillColor: const Color(0xffeeeeee),
            ),
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
                solid.material == StairSolidMaterial.concrete ? SlabMaterial.concrete
                    : solid.material == StairSolidMaterial.timber ? SlabMaterial.parquet : SlabMaterial.custom,
                stairPath,
                hatchPattern: ArchitectHatchPattern.presets.firstWhere((p)=>p.id ==
                  switch(solid.material) {
                    StairSolidMaterial.concrete => 'concrete',
                    StairSolidMaterial.timber => 'wood',
                    StairSolidMaterial.metal => 'metal',
                    StairSolidMaterial.finish => 'diagonal',
                  }),
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

    // Project the same 3D solids as facades, with real hidden-surface removal.
    // A slice alone cannot show a return flight, landing, or wall behind it.
    final shift = Offset(cut.length / 2, 0);
    // Keep disconnected members separate while triangulating: decomposing one
    // large union creates artificial strips at every other member's X station.
    final cutMasks = [
      for (final region in regions)
        for (final t in ArchitectPathSolid.extrude(
          region.path,
          0,
          1,
          const Color(0xff000000),
          contourTolerance: .00001,
        ))
          if (t.normal.z > .5)
            [
              for (final p in [t.v0, t.v1, t.v2]) Offset(p.x, p.y) - shift,
            ],
    ];
    final projected = ArchitectBuildingElevation.build(
      project,
      ArchitectElevation(
        id: cut.id,
        start: cut.start,
        end: cut.end,
        viewDepth: cut.viewDepth,
      ),
      occlusionMasks: cutMasks,
      sectionVisibility: visibility,
    );
    // Cut fills participate in the same double-precision visibility pass;
    // never subtract them again from an already encoded float32 contour.
    Path exposed(Path path) => path.shift(shift);
    final backgroundFaces = <Path>[];
    Rect? bounds;
    for (final face in projected.faces) {
      final visible = exposed(face);
      if (visible.getBounds().isEmpty) continue;
      backgroundFaces.add(visible);
      bounds =
          bounds?.expandToInclude(visible.getBounds()) ?? visible.getBounds();
    }
    final background = ArchitectBuildingElevation(
      backgroundFaces,
      bounds ?? Rect.zero,
      elementPaths: {
        for (final entry in projected.elementPaths.entries)
          if (!exposed(entry.value).getBounds().isEmpty)
            entry.key: exposed(entry.value),
      },
      operations: [
        for (final op in projected.operations)
          if (!exposed(op.clip).getBounds().isEmpty)
            (lines: op.lines.shift(shift), clip: exposed(op.clip)),
      ],
    );
    for (final r in regions) {
      bounds =
          bounds?.expandToInclude(r.path.getBounds()) ?? r.path.getBounds();
    }
    final vertical = bounds ?? Rect.fromLTWH(0, -1, cut.length, 2);
    return ArchitectBuildingSection(
      regions,
      Rect.fromLTRB(0, vertical.top, cut.length, vertical.bottom),
      roofProfiles: roofProfiles,
      background: background,
    );
  }

  static ({ArchitectStorey storey, ArchitectSlab slab})? source(
    ArchitectProject project,
    ArchitectSection cut,
    ArchitectSlabDetail detail,
  ) {
    if (detail.station < 0 || detail.station > cut.length) return null;
    if (cut.steps.isNotEmpty) {
      final s = cut.segments.lastWhere((s) => s.station <= detail.station);
      return source(
        project,
        cut.copyWith(start: s.start, end: s.end, steps: const []),
        detail.copyWith(station: detail.station - s.station),
      );
    }
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
