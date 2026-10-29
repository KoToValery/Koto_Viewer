import '../models/architect_hatch_pattern.dart';
import '../models/architect_wall_type.dart';
import 'architect_section_junctions.dart';
import '../rendering/architect_roof_drainage_mesh.dart';
import '../rendering/architect_section_hatch.dart';
import 'dart:math' as math;
import 'dart:ui';
import '../rendering/architect_mesh_section.dart';
import 'dart:typed_data';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../models/architect_elements.dart';

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
import '../models/architect_wall.dart';
import 'architect_building_elevation.dart';
import 'component_geometry_cache.dart';
import 'component_library_service.dart';

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
  static final _elementPathCache = Expando<Map<String, Path>>();
  static final _projectionRequests =
      Expando<
        ({
          List<List<Offset>> masks,
          Set<String> openingIds,
          Map<String, Path> apertures,
        })
      >();
  final List<ArchitectSectionRegion> regions;
  final Rect bounds;
  final Map<String, Path> roofProfiles;
  final bool viewCoordinates;

  /// Visible surfaces behind the cut, already masked by cut solids. These are
  /// projection lines only: they must never acquire section hatching.
  final ArchitectBuildingElevation? background;
  const ArchitectBuildingSection(
    this.regions,
    this.bounds, {
    this.roofProfiles = const {},
    this.background,
    this.viewCoordinates = false,
  });

  /// The model keeps legacy station coordinates. Only the view is reflected,
  /// preserving arrows, saved cut locations and associations in existing files.
  ArchitectBuildingSection forView(ArchitectSection cut) {
    if (viewCoordinates) return this;
    Offset point(Offset p) => Offset(cut.length - p.dx, p.dy);
    Rect box(Rect b) => Rect.fromLTRB(
      cut.length - b.right,
      b.top,
      cut.length - b.left,
      b.bottom,
    );
    final matrix = Float64List.fromList([
      -1,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      1,
      0,
      cut.length,
      0,
      0,
      1,
    ]);
    Path path(Path p) => p.transform(matrix);
    final bg = background;
    return ArchitectBuildingSection(
      [
        for (final r in regions)
          ArchitectSectionRegion(
            r.sourceId,
            r.material,
            path(r.path),
            slab: r.slab,
            roof: r.roof,
            timberCrossSectionPolygon: r.timberCrossSectionPolygon
                ?.map(point)
                .toList(),
            customFillColor: r.customFillColor,
            hatchPattern: r.hatchPattern,
          ),
      ],
      box(bounds),
      viewCoordinates: true,
      roofProfiles: {
        for (final e in roofProfiles.entries) e.key: path(e.value),
      },
      background: bg == null
          ? null
          : ArchitectBuildingElevation(
              bg.faces.map(path).toList(),
              box(bg.bounds),
              elementPaths: {
                for (final e in bg.elementPaths.entries) e.key: path(e.value),
              },
              operations: [
                for (final op in bg.operations)
                  (lines: path(op.lines), clip: path(op.clip)),
              ],
            ),
    );
  }

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
      final isMonolithicShared =
          region.material == SlabMaterial.concrete ||
          region.material == SlabMaterial.xps;
      final effectiveHatch =
          region.hatchPattern ?? ArchitectSectionHatch.slab(region.material);
      final key = (
            region.material,
            isMonolithicShared ? null : region.customFillColor?.toARGB32(),
            isMonolithicShared ? true : region.slab,
            effectiveHatch,
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
        slab: previous.slab || region.slab,
        customFillColor: previous.customFillColor,
        hatchPattern: previous.hatchPattern ?? effectiveHatch,
      );
    }
    return result;
  }

  Map<String, Path> get elementPaths =>
      _elementPathCache[this] ??= _buildElementPaths();

  Map<String, Path> _buildElementPaths() {
    final operands = <String, List<Path>>{
      for (final entry
          in background?.elementPaths.entries ?? <MapEntry<String, Path>>[])
        entry.key: [entry.value],
    };
    for (final region in regions) {
      (operands[region.sourceId] ??= []).add(region.path);
    }
    return Map.unmodifiable({
      for (final entry in operands.entries)
        entry.key: ArchitectMeshSection.unionPaths(entry.value),
    });
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
        ArchitectRoofMaterial.steel => SlabMaterial.custom,
        ArchitectRoofMaterial.pir => SlabMaterial.roofInsulation,
        null => SlabMaterial.custom,
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
      ArchitectRoofMaterial.steel => const Color(0xffeeeeee),
      ArchitectRoofMaterial.pir => const Color(0xfffafafa),
      null => null,
    };
  }

  static ArchitectBuildingSection build(
    ArchitectProject project,
    ArchitectSection cut, {
    bool includeProjection = true,
  }) {
    if (cut.steps.isNotEmpty) {
      final regions = <ArchitectSectionRegion>[];
      final profiles = <String, List<Path>>{};
      final faces = <Path>[];
      final paths = <String, List<Path>>{};
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
        void merge(Map<String, List<Path>> target, Map<String, Path> source) {
          for (final e in source.entries) {
            (target[e.key] ??= []).add(e.value.shift(shift));
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
        roofProfiles: {
          for (final e in profiles.entries)
            e.key: ArchitectMeshSection.unionPaths(e.value),
        },
        background: ArchitectBuildingElevation(
          faces,
          box,
          elementPaths: {
            for (final e in paths.entries)
              e.key: ArchitectMeshSection.unionPaths(e.value),
          },
          operations: operations,
        ),
      );
    }
    final visibility = cut.visibility.resolved(project.sectionVisibility);
    final regions = <ArchitectSectionRegion>[];
    final highPriorityCutouts = <Path>[];
    final roofProfiles = <String, Path>{};
    final cutOpeningIds = <String>{};
    final cutOpeningAperturePaths = <String, Path>{};
    final extraCutMaskPaths = <Path>[];

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
          if (s.bottomProfile.length >= 2) {
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
    }

    // 2. Analyze Cut Walls & Build Symbiotic Slab + Foundation + Wall-Base Junctions
    final cutWalls = ArchitectSectionJunctions.analyzeCutWalls(project, cut);
    final junctionPlan =
        ArchitectSectionJunctions.buildSlabAndFoundationJunctions(
          project: project,
          cut: cut,
          cutWalls: cutWalls,
        );
    regions.addAll(junctionPlan.slabAndFoundationRegions);
    regions.addAll(junctionPlan.wallDetailRegions);
    /*
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

    */
    Path? sliceMesh(
      List<Triangle3D> tris, {
      double endpointTolerance = 1e-6,
      bool exact = false,
    }) {
      if (exact) {
        final path = ArchitectMeshSection.verticalClipped(
          tris,
          cut.start,
          cut.axis,
          cut.length,
        );
        return path.getBounds().isEmpty ? null : path;
      }
      final section = ArchitectStairSection.build(
        [StairSolid(StairSolidMaterial.concrete, tris)],
        cut.start,
        cut.axis,
        endpointTolerance: endpointTolerance,
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

      final wallCutOpeningsByWall = <String, List<_CutOpeningSpan>>{};
      final floorCutOpeningIds = <String>{};
      for (final wall in floor.walls) {
        final cutOps = _findCutOpeningsOnWall(wall, floor.elevation, cut);
        if (cutOps.isNotEmpty) {
          wallCutOpeningsByWall[wall.id] = cutOps;
          for (final op in cutOps) {
            floorCutOpeningIds.add(op.id);
            cutOpeningIds.add(op.id);
          }
        }
      }

      final useCompositions = floor.walls.any(
        (w) =>
            w.system.isSpecial ||
            w.layers.isNotEmpty ||
            w.hasInsulation ||
            w.plinth.enabled ||
            w.isCurved,
      );
      final sharedSolids = useCompositions
          ? ArchitectWallSolids.build(
              floor,
              project.wallTypes,
              project: project,
              suppressedOpeningIds: floorCutOpeningIds,
              specialSuppressedOpeningIds: const {},
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
              suppressedOpeningIds: floorCutOpeningIds,
            );
        // Each material/height band is a closed solid. Slicing their joined
        // triangle soup makes shared cap edges branch, so contour tracing can
        // discard all but the lowest band (for example a 0.85 m plinth).
        // Intersect the closed solids separately, then unite their 2D regions.
        final materialSections = <ArchitectWallSolid, Path>{};
        final specialSections = <Path>[];
        Path? accumulated;
        void addWallSection(Path? path) {
          if (path == null) return;
          if (wall.system.isSpecial) {
            specialSections.add(path);
            return;
          }
          accumulated = accumulated == null
              ? path
              : Path.combine(PathOperation.union, accumulated!, path);
        }

        if (useCompositions) {
          for (final solid in sharedSolids.where((s) => s.wall.id == wall.id)) {
            final path = sliceMesh(
              solid.triangles,
              exact: wall.system.isSpecial,
            );
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
        if (specialSections.isNotEmpty) {
          accumulated = ArchitectMeshSection.unionPaths(specialSections);
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
            if (slice.bottomProfile.length < 2) continue;
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
        for (final cutout in [
          ...highPriorityCutouts,
          if (!useCompositions || wall.system.isSpecial) ...[
            ...junctionPlan.wallCoreCutouts,
            ...?junctionPlan.wallBaseDetailCutouts[wall.id],
          ],
        ]) {
          try {
            wallPath = Path.combine(
              PathOperation.difference,
              wallPath!,
              cutout,
            );
          } catch (_) {}
        }

        for (final cutOp
            in wallCutOpeningsByWall[wall.id] ?? const <_CutOpeningSpan>[]) {
          final apertureRect = Rect.fromLTRB(
            cutOp.sMin,
            cutOp.zBottom,
            cutOp.sMax,
            cutOp.zTop,
          );
          final clippedAperture = wall.system.isSpecial
              ? (Path()..addRect(apertureRect))
              : Path.combine(
                  PathOperation.intersect,
                  Path()..addRect(apertureRect),
                  wallPath!,
                );
          if (clippedAperture.getBounds().isEmpty) continue;
          wallPath = Path.combine(
            PathOperation.difference,
            wallPath!,
            clippedAperture,
          );
          extraCutMaskPaths.add(clippedAperture);
          cutOpeningAperturePaths[cutOp.id] = clippedAperture;
          final cleanOpeningSection = _buildCleanOpeningSectionProfile(
            cutOp,
            clippedAperture,
          );
          if (!cleanOpeningSection.getBounds().isEmpty) {
            regions.add(
              ArchitectSectionRegion(
                cutOp.id,
                SlabMaterial.tile,
                cleanOpeningSection,
              ),
            );
          }
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
              // Log courses and casings already own disjoint 3D volumes after
              // their saddle/opening cuts. Repeatedly subtracting each course
              // from a growing 2D remainder retraces every other round profile.
              var region =
                  (wall.system.isSpecial
                  ? ArchitectMeshSection.combine
                  : Path.combine)(
                    PathOperation.intersect,
                    wall.system.isLog ? wallPath : remaining,
                    raw,
                  );
              if (!wall.system.isLog) {
                remaining =
                    (wall.system.isSpecial
                    ? ArchitectMeshSection.combine
                    : Path.combine)(
                      PathOperation.difference,
                      remaining,
                      region,
                    );
              }
              if (!wall.system.isSpecial) {
                final resolved = wall.resolvedLayers;
                final firstCoreIdx = resolved.indexWhere(
                  (l) => l.role == ArchitectLayerRole.core,
                );
                final layerIdx = resolved.indexWhere(
                  (l) => l.id == part.layer.id,
                );
                final isCore = part.layer.role == ArchitectLayerRole.core;
                final isInteriorFinish =
                    part.layer.role == ArchitectLayerRole.finish &&
                    (!wall.isExterior ||
                        (firstCoreIdx >= 0 && layerIdx > firstCoreIdx));
                if (isCore) {
                  for (final cutout in [
                    ...junctionPlan.wallCoreCutouts,
                    ...?junctionPlan.wallBaseDetailCutouts[wall.id],
                  ]) {
                    try {
                      region = Path.combine(
                        PathOperation.difference,
                        region,
                        cutout,
                      );
                    } catch (_) {}
                  }
                } else if (isInteriorFinish) {
                  for (final cutout in junctionPlan.interiorFinishCutouts) {
                    try {
                      region = Path.combine(
                        PathOperation.difference,
                        region,
                        cutout,
                      );
                    } catch (_) {}
                  }
                }
              } else {
                for (final cutout in [
                  ...junctionPlan.wallCoreCutouts,
                  ...?junctionPlan.wallBaseDetailCutouts[wall.id],
                ]) {
                  try {
                    region = ArchitectMeshSection.combine(
                      PathOperation.difference,
                      region,
                      cutout,
                    );
                  } catch (_) {}
                }
              }
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
                  hatchPattern: ArchitectSectionHatch.wall(part.layer.material),
                ),
              );
            }
          } else {
            regions.add(
              ArchitectSectionRegion(
                wall.id,
                wall.coreMaterial == WallCoreMaterial.concrete
                    ? SlabMaterial.concrete
                    : SlabMaterial.plaster,
                wallPath,
                hatchPattern: ArchitectSectionHatch.core(wall.coreMaterial),
              ),
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
            details: false,
          ),
          exact: true,
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
        final solids = [
          ...ArchitectStairMesh.body(stair),
          ...ArchitectStairMesh.railings(
            stair,
            storey: floor,
            project: project,
          ),
        ];
        final section = ArchitectStairSection.build(
          [
            for (final solid in solids)
              StairSolid(solid.material, [
                for (final t in solid.triangles)
                  Triangle3D(
                    v0: t.v0 + Vector3(0, 0, floor.elevation),
                    v1: t.v1 + Vector3(0, 0, floor.elevation),
                    v2: t.v2 + Vector3(0, 0, floor.elevation),
                  ),
              ]),
          ],
          cut.start,
          cut.axis,
        );
        for (final entry in section.regions.entries) {
          final stairPath = Path.combine(
            PathOperation.intersect,
            entry.value,
            Path()..addRect(Rect.fromLTRB(0, -1e6, cut.length, 1e6)),
          );
          if (!stairPath.getBounds().isEmpty) {
            regions.add(
              ArchitectSectionRegion(
                stair.id,
                entry.key == StairSolidMaterial.concrete
                    ? SlabMaterial.concrete
                    : entry.key == StairSolidMaterial.timber
                    ? SlabMaterial.parquet
                    : SlabMaterial.custom,
                stairPath,
                hatchPattern: ArchitectHatchPattern.presets.firstWhere(
                  (p) =>
                      p.id ==
                      switch (entry.key) {
                        StairSolidMaterial.concrete => 'concrete',
                        StairSolidMaterial.timber => 'wood',
                        StairSolidMaterial.metal => 'metal',
                        StairSolidMaterial.finish => 'diagonal',
                      },
                ),
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
              hatchPattern:
                  member.material == ArchitectRoofMaterial.metalSeam ||
                      member.material == ArchitectRoofMaterial.steel
                  ? ArchitectSectionHatch.preset('metal')
                  : null,
            ),
          );
        }
      }

      // 5. Cut Floor Drains & Components with visibleInSection == true
      void addDrainDetail(
        String drainId,
        double sCenter,
        double grateW,
        double zTop,
      ) {
        final drainSec = _buildFloorDrainSection(sCenter, grateW, zTop);
        for (var i = 0; i < regions.length; i++) {
          final r = regions[i];
          if (!r.slab || r.roof) continue;
          try {
            final trimmed = Path.combine(
              PathOperation.difference,
              r.path,
              drainSec.envelope,
            );
            regions[i] = ArchitectSectionRegion(
              r.sourceId,
              r.material,
              trimmed,
              slab: r.slab,
              roof: r.roof,
              timberCrossSectionPolygon: r.timberCrossSectionPolygon,
              customFillColor: r.customFillColor,
              hatchPattern: r.hatchPattern,
            );
          } catch (_) {}
        }
        regions.add(
          ArchitectSectionRegion(
            drainId,
            SlabMaterial.tile,
            drainSec.detailPath,
            customFillColor: const Color(0xFFB0BEC5),
          ),
        );
      }

      for (final drain in floor.floorDrains) {
        final sProj =
            (drain.position - cut.start).dx * cut.axis.dx +
            (drain.position - cut.start).dy * cut.axis.dy;
        final sClamped = sProj.clamp(0.0, cut.length);
        final ptOnCut = cut.pointAt(sClamped);
        final distToAxis = _distToSegment2D(
          ptOnCut,
          drain.axis.$1,
          drain.axis.$2,
        );
        if (sProj >= -drain.halfWidth &&
            sProj <= cut.length + drain.halfWidth &&
            (distToAxis <= drain.halfWidth + 0.08 ||
                drain.containsPoint(ptOnCut))) {
          final grateW = (drain.halfWidth * 2.0).clamp(0.08, 0.30);
          final sDrain = sProj
              .clamp(grateW / 2, math.max(grateW / 2, cut.length - grateW / 2))
              .toDouble();
          addDrainDetail(
            drain.id,
            sDrain,
            grateW,
            floor.elevation + floor.floorFinishThickness,
          );
        }
      }

      for (final comp in floor.components) {
        if (!comp.isVisible) continue;
        final def = ComponentLibraryService.instance.findDefinition(
          comp.definitionId,
        );
        final showInSec = comp.effectiveVisibleInSection(
          defaultFromDefinition: def?.defaultVisibleInSection ?? false,
        );
        if (!showInSec) continue;
        if (comp.isFloorDrainComponent) {
          final sProj =
              (comp.position - cut.start).dx * cut.axis.dx +
              (comp.position - cut.start).dy * cut.axis.dy;
          if (sProj < 0 || sProj > cut.length) continue;
          final ptOnCut = cut.pointAt(sProj);
          final wM =
              (comp.parameters['width'] as num?)?.toDouble() ??
              (comp.parameters['diameter'] as num?)?.toDouble() ??
              0.15;
          final dM =
              (comp.parameters['depth'] as num?)?.toDouble() ??
              (comp.parameters['diameter'] as num?)?.toDouble() ??
              0.15;
          final grateW = wM.clamp(0.08, 0.30);
          final reach = math.max(wM, dM) / 2.0 + 0.08;
          if ((ptOnCut - comp.position).distance <= reach) {
            addDrainDetail(
              comp.id,
              sProj,
              grateW,
              floor.elevation +
                  floor.floorFinishThickness +
                  comp.elevationOffset,
            );
          }
        } else if (def != null) {
          final geo = ComponentGeometryCache.instance.getOrCompute(
            def,
            comp.parameters,
          );
          final cosR = math.cos(comp.rotation);
          final sinR = math.sin(comp.rotation);
          final zBase = floor.elevation + comp.elevationOffset;
          Vector3 tr(Vector3 p) => Vector3(
            comp.position.dx + p.x * cosR - p.y * sinR,
            comp.position.dy + p.x * sinR + p.y * cosR,
            zBase + p.z,
          );
          final compPath = sliceMesh([
            for (final t in geo.mesh3d.triangles)
              Triangle3D(v0: tr(t.v0), v1: tr(t.v1), v2: tr(t.v2)),
          ]);
          if (compPath != null) {
            regions.add(
              ArchitectSectionRegion(
                comp.id,
                SlabMaterial.custom,
                compPath,
                customFillColor: const Color(0xFFCFD8DC),
              ),
            );
          }
        }
      }
    }

    // Project the same 3D solids as facades, with real hidden-surface removal.
    // A slice alone cannot show a return flight, landing, or wall behind it.
    final shift = Offset(cut.length / 2, 0);
    // Keep disconnected members separate while triangulating: decomposing one
    // large union creates artificial strips at every other member's X station.
    final cutMasks = [
      for (final maskPath in [
        for (final region in regions) region.path,
        ...extraCutMaskPaths,
      ])
        for (final t in ArchitectPathSolid.extrude(
          maskPath,
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
    if (!includeProjection) {
      final partial = _finishProjection(
        cut,
        regions,
        roofProfiles,
        cutOpeningAperturePaths,
        const ArchitectBuildingElevation([], Rect.zero),
      );
      _projectionRequests[partial] = (
        masks: cutMasks,
        openingIds: cutOpeningIds,
        apertures: cutOpeningAperturePaths,
      );
      return partial;
    }
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
      cutOpeningIds: cutOpeningIds,
    );
    return _finishProjection(
      cut,
      regions,
      roofProfiles,
      cutOpeningAperturePaths,
      projected,
    );
  }

  static Future<ArchitectBuildingSection> buildAsync(
    ArchitectProject project,
    ArchitectSection cut,
  ) async {
    // Give the view a frame to show its progress indicator before creating the
    // native cut paths. The expensive visibility solver runs in compute().
    await Future<void>.delayed(Duration.zero);
    if (cut.steps.isNotEmpty) {
      final regions = <ArchitectSectionRegion>[];
      final profiles = <String, List<Path>>{}, paths = <String, List<Path>>{};
      final faces = <Path>[], operations = <({Path lines, Path clip})>[];
      Rect? bounds;
      for (final segment in cut.segments) {
        final depth = cut.viewDepth == null
            ? null
            : cut.viewDepth! - segment.offset;
        if (depth != null && depth <= 0) continue;
        final part = await buildAsync(
          project,
          cut.copyWith(
            start: segment.start,
            end: segment.end,
            steps: const [],
            details: const [],
            viewDepth: depth,
          ),
        );
        final shift = Offset(segment.station, 0);
        regions.addAll([
          for (final r in part.regions)
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
        ]);
        for (final e in part.roofProfiles.entries) {
          (profiles[e.key] ??= []).add(e.value.shift(shift));
        }
        for (final e
            in part.background?.elementPaths.entries ??
                <MapEntry<String, Path>>[]) {
          (paths[e.key] ??= []).add(e.value.shift(shift));
        }
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
        roofProfiles: {
          for (final e in profiles.entries)
            e.key: ArchitectMeshSection.unionPaths(e.value),
        },
        background: ArchitectBuildingElevation(
          faces,
          box,
          elementPaths: {
            for (final e in paths.entries)
              e.key: ArchitectMeshSection.unionPaths(e.value),
          },
          operations: operations,
        ),
      );
    }
    for (final floor in project.storeys) {
      if (!floor.walls.any((w) => w.system.isSpecial)) continue;
      final openings = <String>{
        for (final wall in floor.walls)
          for (final op in _findCutOpeningsOnWall(wall, floor.elevation, cut))
            op.id,
      };
      final solids = await ArchitectWallSolids.buildAsync(
        floor,
        project,
        suppressedOpeningIds: openings,
        specialSuppressedOpeningIds: const {},
      );
      await ArchitectMeshSection.prepareVertical(
        solids.where((s) => s.componentId != null).map((s) => s.triangles),
        cut.start,
        cut.axis,
        cut.length,
      );
    }
    final partial = build(project, cut, includeProjection: false);
    final request = _projectionRequests[partial]!;
    final projected = await ArchitectBuildingElevation.buildAsync(
      project,
      ArchitectElevation(
        id: cut.id,
        start: cut.start,
        end: cut.end,
        viewDepth: cut.viewDepth,
      ),
      occlusionMasks: request.masks,
      cutOpeningIds: request.openingIds,
      sectionVisibility: cut.visibility.resolved(project.sectionVisibility),
    );
    return _finishProjection(
      cut,
      partial.regions,
      partial.roofProfiles,
      request.apertures,
      projected,
    );
  }

  static ArchitectBuildingSection _finishProjection(
    ArchitectSection cut,
    List<ArchitectSectionRegion> regions,
    Map<String, Path> roofProfiles,
    Map<String, Path> cutOpeningAperturePaths,
    ArchitectBuildingElevation projected,
  ) {
    final shift = Offset(
      cut.length / 2,
      0,
    ); // Cut fills participate in the same double-precision visibility pass;
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
    for (final aperturePath in cutOpeningAperturePaths.values) {
      if (aperturePath.getBounds().isEmpty) continue;
      backgroundFaces.add(aperturePath);
      bounds =
          bounds?.expandToInclude(aperturePath.getBounds()) ??
          aperturePath.getBounds();
    }
    final background = ArchitectBuildingElevation(
      backgroundFaces,
      bounds ?? Rect.zero,
      elementPaths: {
        for (final entry in projected.elementPaths.entries)
          if (!exposed(entry.value).getBounds().isEmpty)
            entry.key: exposed(entry.value),
        for (final entry in cutOpeningAperturePaths.entries)
          if (!entry.value.getBounds().isEmpty) entry.key: entry.value,
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

  static List<_CutOpeningSpan> _findCutOpeningsOnWall(
    ArchitectWall wall,
    double storeyElevation,
    ArchitectSection cut,
  ) {
    final result = <_CutOpeningSpan>[];
    final zBase = storeyElevation + wall.baseOffset;
    final openings = [
      for (final d in wall.doors)
        (
          id: d.id,
          ratio: d.offsetRatio,
          width: d.width,
          height: d.height,
          sill: d.sillHeight,
          frame: d.frameThickness,
          isWindow: false,
        ),
      for (final w in wall.windows)
        (
          id: w.id,
          ratio: w.offsetRatio,
          width: w.width,
          height: w.height,
          sill: w.sillHeight,
          frame: w.frameThickness,
          isWindow: true,
        ),
    ];

    (double, double)? clipLinearInterval(
      double s0,
      double s1,
      double valAt0,
      double deriv,
      double minVal,
      double maxVal,
    ) {
      if (deriv.abs() < 1e-9) {
        if (valAt0 < minVal || valAt0 > maxVal) return null;
        return (s0, s1);
      }
      final tA = (minVal - valAt0) / deriv;
      final tB = (maxVal - valAt0) / deriv;
      final lo = math.max(s0, math.min(tA, tB));
      final hi = math.min(s1, math.max(tA, tB));
      return hi > lo ? (lo, hi) : null;
    }

    for (final op in openings) {
      final axis = wall.openingAxis(op.ratio);
      final wallVec = axis.$2 - axis.$1;
      final wallLen = wallVec.distance;
      if (wallLen < 1e-4) continue;
      final u = wallVec / wallLen;
      final n = Offset(-u.dy, u.dx);
      final center = axis.$1 + u * (op.ratio * wallLen);
      final halfW = op.width / 2.0;
      final halfT = wall.thickness / 2.0;

      final d0 = cut.start - center;
      final u0 = d0.dx * u.dx + d0.dy * u.dy;
      final du = cut.axis.dx * u.dx + cut.axis.dy * u.dy;
      final n0 = d0.dx * n.dx + d0.dy * n.dy;
      final dn = cut.axis.dx * n.dx + cut.axis.dy * n.dy;

      final spanU = clipLinearInterval(
        0.0,
        cut.length,
        u0,
        du,
        -halfW - 1e-5,
        halfW + 1e-5,
      );
      if (spanU == null) continue;
      final spanOp = clipLinearInterval(
        spanU.$1,
        spanU.$2,
        n0,
        dn,
        -halfT - 1e-5,
        halfT + 1e-5,
      );
      if (spanOp == null || spanOp.$2 - spanOp.$1 <= 1e-4) continue;

      var sMin = spanOp.$1;
      var sMax = spanOp.$2;
      final isCrossWallCut = dn.abs() > 0.15;
      if (isCrossWallCut) {
        // Normalize the station span to the full cut wall thickness across the two wall faces
        // so diagonal cuts grazing a jamb never leave stepped wall notches.
        final wallU = clipLinearInterval(
          0.0,
          cut.length,
          (cut.start - axis.$1).dx * u.dx + (cut.start - axis.$1).dy * u.dy,
          du,
          0.0,
          wallLen,
        );
        final wallN = clipLinearInterval(
          wallU?.$1 ?? 0.0,
          wallU?.$2 ?? cut.length,
          n0,
          dn,
          -halfT,
          halfT,
        );
        if (wallN != null && wallN.$2 - wallN.$1 > 1e-4) {
          sMin = wallN.$1;
          sMax = wallN.$2;
        }
      }

      result.add(
        _CutOpeningSpan(
          id: op.id,
          sMin: sMin,
          sMax: sMax,
          zBottom: zBase + op.sill,
          zTop: zBase + op.sill + op.height,
          frameThickness: op.frame.clamp(0.03, 0.08),
          isWindow: op.isWindow,
          isCrossWallCut: isCrossWallCut,
        ),
      );
    }
    return result;
  }

  static Path _buildCleanOpeningSectionProfile(
    _CutOpeningSpan op,
    Path clippedAperture,
  ) {
    final sMin = op.sMin;
    final sMax = op.sMax;
    final zBottom = op.zBottom;
    final zTop = op.zTop;
    final spanW = sMax - sMin;
    final spanH = zTop - zBottom;
    if (spanW <= 1e-4 || spanH <= 1e-4) return Path();

    final frameFace = math.min(op.frameThickness, spanH * 0.25);
    final raw = Path();
    if (op.isCrossWallCut) {
      final sMid = (sMin + sMax) / 2.0;
      final frameDepth = math.min(0.07, spanW * 0.65);
      // Top head frame
      raw.addRect(
        Rect.fromLTRB(
          sMid - frameDepth / 2.0,
          zTop - frameFace,
          sMid + frameDepth / 2.0,
          zTop,
        ),
      );
      // Bottom sill frame for windows
      if (op.isWindow) {
        raw.addRect(
          Rect.fromLTRB(
            sMid - frameDepth / 2.0,
            zBottom,
            sMid + frameDepth / 2.0,
            zBottom + frameFace,
          ),
        );
      }
      // Central glazing or door leaf strip
      final leafHalf = math.min(op.isWindow ? 0.012 : 0.020, frameDepth * 0.35);
      final zLeafBottom = op.isWindow ? zBottom + frameFace : zBottom;
      final zLeafTop = zTop - frameFace;
      if (zLeafTop > zLeafBottom + 1e-4) {
        raw.addRect(
          Rect.fromLTRB(
            sMid - leafHalf,
            zLeafBottom,
            sMid + leafHalf,
            zLeafTop,
          ),
        );
      }
    } else {
      // Longitudinal cut along the wall
      final jambW = math.min(frameFace, spanW * 0.25);
      raw.addRect(Rect.fromLTRB(sMin, zBottom, sMin + jambW, zTop));
      raw.addRect(Rect.fromLTRB(sMax - jambW, zBottom, sMax, zTop));
      raw.addRect(Rect.fromLTRB(sMin, zTop - frameFace, sMax, zTop));
      if (op.isWindow) {
        raw.addRect(Rect.fromLTRB(sMin, zBottom, sMax, zBottom + frameFace));
      }
      final zLeafBottom = op.isWindow ? zBottom + frameFace : zBottom;
      final zLeafTop = zTop - frameFace;
      if (sMax - jambW > sMin + jambW && zLeafTop > zLeafBottom) {
        raw.addRect(
          Rect.fromLTRB(sMin + jambW, zLeafBottom, sMax - jambW, zLeafTop),
        );
      }
    }
    try {
      return Path.combine(PathOperation.intersect, raw, clippedAperture);
    } catch (_) {
      return raw;
    }
  }

  static ({Path detailPath, Path envelope}) _buildFloorDrainSection(
    double sCenter,
    double grateWidth,
    double zFinishedFloor,
  ) {
    final gHalf = grateWidth / 2.0;
    final bHalf = (grateWidth * 0.65).clamp(0.06, 0.14) / 2.0;
    const pHalf = 0.020; // DN40/50 outlet stub

    final grateRect = Rect.fromLTRB(
      sCenter - gHalf,
      zFinishedFloor - 0.012,
      sCenter + gHalf,
      zFinishedFloor,
    );
    final bodyRect = Rect.fromLTRB(
      sCenter - bHalf,
      zFinishedFloor - 0.075,
      sCenter + bHalf,
      zFinishedFloor - 0.012,
    );
    final pipeRect = Rect.fromLTRB(
      sCenter - pHalf,
      zFinishedFloor - 0.115,
      sCenter + pHalf,
      zFinishedFloor - 0.075,
    );

    var detail = Path()..addRect(grateRect);
    detail = Path.combine(
      PathOperation.union,
      detail,
      Path()..addRect(bodyRect),
    );
    detail = Path.combine(
      PathOperation.union,
      detail,
      Path()..addRect(pipeRect),
    );
    return (detailPath: detail, envelope: detail);
  }

  static double _distToSegment2D(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 < 1e-8) return (p - a).distance;
    final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2).clamp(
      0.0,
      1.0,
    );
    return (p - (a + ab * t)).distance;
  }
}

class _CutOpeningSpan {
  final String id;
  final double sMin;
  final double sMax;
  final double zBottom;
  final double zTop;
  final double frameThickness;
  final bool isWindow;
  final bool isCrossWallCut;

  const _CutOpeningSpan({
    required this.id,
    required this.sMin,
    required this.sMax,
    required this.zBottom,
    required this.zTop,
    required this.frameThickness,
    required this.isWindow,
    required this.isCrossWallCut,
  });
}
