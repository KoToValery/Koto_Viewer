// === SECTION: TABLE OF CONTENTS ===
// 1. Data Structures & Junction Models (CutWallJunctionSpan, SlabWallJunctionPlan)
// 2. Default Storey Slab Assembly Resolution (Ground / Basement 5cm XPS / Intermediate)
// 3. Cut Wall Span & Layer Anatomy Analyzer (Core, Exterior Insulation, Interior Finish)
// 4. Symbiotic Slab-Wall Trimming, Strip Foundations & Plinth XPS
// 5. Material-Specific Wall Base Details (RC, Brick Waterproofing, Log/Timber Sill, Stud Sole Plate, Panel Flashing)

import 'dart:math' as math;
import 'dart:ui';

import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import '../models/architect_section.dart';
import '../models/architect_slab_assembly.dart';
import '../models/architect_wall.dart';
import '../models/architect_wall_type.dart';
import '../rendering/architect_section_hatch.dart';
import 'architect_building_section.dart';
import 'architect_slab_assemblies.dart';
import 'architect_slab_geometry.dart';

// === SECTION: DATA STRUCTURES & JUNCTION MODELS ===

class CutWallJunctionSpan {
  final ArchitectStorey storey;
  final ArchitectWall wall;
  final double transverse;
  final bool isTransverseCut;
  final double exteriorDirectionS;
  final double zWallBot;
  final double zWallTop;
  final List<(double, double)> fullIntervals;
  final List<(double, double)> coreIntervals;
  final List<(double, double)> coreOpeningsFreeIntervals;
  final List<(double, double)> exteriorIntervals;
  final List<(double, double)> interiorIntervals;

  const CutWallJunctionSpan({
    required this.storey,
    required this.wall,
    required this.transverse,
    required this.isTransverseCut,
    required this.exteriorDirectionS,
    required this.zWallBot,
    required this.zWallTop,
    required this.fullIntervals,
    required this.coreIntervals,
    required this.coreOpeningsFreeIntervals,
    required this.exteriorIntervals,
    required this.interiorIntervals,
  });

  /// Whether this wall should generate a reinforced concrete strip foundation
  /// when resting on a ground-bearing slab.
  bool get isFoundationBearing =>
      !wall.isParapet &&
      (wall.isExterior ||
          wall.coreThickness >= 0.20 - 1e-4 ||
          wall.coreMaterial == WallCoreMaterial.concrete ||
          wall.system.isLog ||
          wall.system.isPanel);

  /// At a slab perimeter its footprint identifies the outside of the junction,
  /// even in older projects whose wall-side flag points into the building.
  CutWallJunctionSpan atSlab(List<(double, double)> spans) {
    if (!wall.isExterior || !isTransverseCut) return this;
    for (final (a, b) in spans) {
      for (final (w0, w1) in fullIntervals) {
        final atStart = (w0 - a).abs() <= .08;
        final atEnd = (w1 - b).abs() <= .08;
        if (atStart == atEnd) continue;
        return CutWallJunctionSpan(
          storey: storey,
          wall: wall,
          transverse: transverse,
          isTransverseCut: isTransverseCut,
          exteriorDirectionS: atStart ? -1 : 1,
          zWallBot: zWallBot,
          zWallTop: zWallTop,
          fullIntervals: fullIntervals,
          coreIntervals: coreIntervals,
          coreOpeningsFreeIntervals: coreOpeningsFreeIntervals,
          exteriorIntervals: exteriorIntervals,
          interiorIntervals: interiorIntervals,
        );
      }
    }
    return this;
  }
}

class SlabWallJunctionPlan {
  /// Slab & foundation section regions generated for all slabs in the project.
  final List<ArchitectSectionRegion> slabAndFoundationRegions;

  /// Structural slab core cutouts (plus base detail cutouts) that clip wall cores.
  final List<Path> wallCoreCutouts;

  /// Full slab thickness cutouts (above + core + below) that clip interior wall finishes.
  final List<Path> interiorFinishCutouts;

  /// Per-wall base detail cutouts (waterproofing under brick, sill plate under logs/studs, etc.).
  final Map<String, List<Path>> wallBaseDetailCutouts;

  /// Additional wall-associated detail regions (timber sill plates, sole plates, base flashings,
  /// and bridged facade insulation across intermediate slab edges).
  final List<ArchitectSectionRegion> wallDetailRegions;

  const SlabWallJunctionPlan({
    required this.slabAndFoundationRegions,
    required this.wallCoreCutouts,
    required this.interiorFinishCutouts,
    required this.wallBaseDetailCutouts,
    required this.wallDetailRegions,
  });
}

// === SECTION: DEFAULT STOREY SLAB ASSEMBLY RESOLUTION ===

class ArchitectSectionJunctions {
  /// Determines the default contextual [SlabUsage] for a slab on [storey] within [project]:
  /// - Lowest storey (no non-roof storey below it):
  ///   - `elevation < -0.50` -> [SlabUsage.foundation]
  ///   - otherwise -> [SlabUsage.ground] (slab on grade / върху земя)
  /// - Ground floor (`-0.15 <= elevation <= 0.60`) above an unheated basement (`elevation < -0.50`):
  ///   - -> [SlabUsage.basement] (with 5 cm XPS thermal insulation under the concrete slab)
  /// - Upper floor above a heated storey:
  ///   - -> [SlabUsage.intermediate] (with floor finishes above and ceiling plaster below)
  static SlabUsage defaultUsageForStorey(
    ArchitectProject project,
    ArchitectStorey storey,
  ) {
    final lowerStoreys =
        project.storeys
            .where(
              (s) =>
                  s.id != storey.id &&
                  !s.isRoof &&
                  s.elevation < storey.elevation - 1e-4,
            )
            .toList()
          ..sort((a, b) => a.elevation.compareTo(b.elevation));

    if (lowerStoreys.isEmpty) {
      return storey.elevation < -0.50 ? SlabUsage.foundation : SlabUsage.ground;
    }

    final immediatelyBelow = lowerStoreys.last;
    if (storey.elevation >= -0.15 &&
        storey.elevation <= 0.60 &&
        immediatelyBelow.elevation < -0.50) {
      return SlabUsage.basement;
    }

    return SlabUsage.intermediate;
  }

  /// Resolves the effective [ArchitectSlabAssembly] for [slab] on [storey].
  /// If [slab.assemblyId] is explicitly set, returns that project assembly.
  /// Otherwise, when the project has walls and [slab] sits at the floor datum
  /// (`coreTopOffset.abs() < 0.35`), automatically supplies the default contextual
  /// assembly for [storey] so sections render complete constructive junctions out of the box.
  static ArchitectSlabAssembly? resolveEffectiveSlabAssembly(
    ArchitectProject project,
    ArchitectStorey storey,
    ArchitectSlab slab, {
    bool? hasWallsOverride,
  }) {
    final explicit = ArchitectSlabAssemblies.of(project, slab);
    if (explicit != null) return explicit;
    final hasWalls =
        hasWallsOverride ?? project.storeys.any((s) => s.walls.isNotEmpty);
    if (!hasWalls || slab.coreTopOffset.abs() >= 0.35) {
      return null;
    }
    return ArchitectSlabCatalog.preset(defaultUsageForStorey(project, storey));
  }

  /// Checks whether [slab] on [storey] is a ground-bearing slab (resting on soil/sub-base).
  static bool isGroundBearingSlab(
    ArchitectProject project,
    ArchitectStorey storey,
    ArchitectSlab slab,
    ArchitectSlabAssembly? resolvedAssembly,
  ) {
    final usage = resolvedAssembly?.usage;
    if (usage == SlabUsage.ground || usage == SlabUsage.foundation) {
      return true;
    }
    if (usage != null &&
        const {
          SlabUsage.basement,
          SlabUsage.intermediate,
          SlabUsage.coldAttic,
          SlabUsage.insulatedCeiling,
          SlabUsage.warmRoof,
          SlabUsage.invertedRoof,
          SlabUsage.terrace,
        }.contains(usage)) {
      return false;
    }
    if (slab.coreTopOffset.abs() >= 0.35) return false;
    final hasLowerStorey = project.storeys.any(
      (s) =>
          s.id != storey.id &&
          !s.isRoof &&
          s.elevation < storey.elevation - 1e-4,
    );
    return !hasLowerStorey;
  }

  // === SECTION: CUT WALL SPAN & LAYER ANATOMY ANALYZER ===

  static List<CutWallJunctionSpan> analyzeCutWalls(
    ArchitectProject project,
    ArchitectSection cut,
  ) {
    final result = <CutWallJunctionSpan>[];
    final catalog = {
      for (final t in ArchitectWallType.standardCatalog(includeSpecial: true))
        t.id: t,
      for (final t in project.wallTypes) t.id: t,
    };

    for (final storey in project.storeys) {
      for (final wall in storey.walls) {
        final type = catalog[wall.wallTypeId];
        final insulation =
            (wall.insulationThicknessOverride ??
                    type?.insulationThickness ??
                    wall.insulationThickness)
                .clamp(0.0, math.max(0.0, wall.thickness - 0.001));
        final offset = wall.centerLineOffset;
        final outside = wall.layers.isEmpty ? insulation : wall.exteriorBuildUp;
        final inside = wall.layers.isEmpty ? 0.0 : wall.interiorBuildUp;

        final fullLow = offset - wall.thickness / 2.0;
        final fullHigh = offset + wall.thickness / 2.0;
        final coreLow = fullLow + (wall.exteriorSign < 0 ? outside : inside);
        final coreHigh = fullHigh - (wall.exteriorSign > 0 ? outside : inside);

        final fullPoly = wall.facePolygon(fullLow, fullHigh);
        final fullIntervals = _polygonIntervals(fullPoly, cut);
        if (fullIntervals.isEmpty) continue;

        final corePoly = wall.facePolygon(coreLow, coreHigh);
        final coreIntervals = _polygonIntervals(corePoly, cut);
        if (coreIntervals.isEmpty) continue;

        final exteriorIntervals = outside > 1e-4
            ? _polygonIntervals(
                wall.exteriorSign > 0
                    ? wall.facePolygon(coreHigh, fullHigh)
                    : wall.facePolygon(fullLow, coreLow),
                cut,
              )
            : const <(double, double)>[];

        final interiorIntervals = inside > 1e-4
            ? _polygonIntervals(
                wall.exteriorSign > 0
                    ? wall.facePolygon(fullLow, coreLow)
                    : wall.facePolygon(coreHigh, fullHigh),
                cut,
              )
            : const <(double, double)>[];

        final doorSpans = _baseDoorwayIntervals(wall, cut);
        final coreOpeningsFree = _subtractIntervals(coreIntervals, doorSpans);

        final transverse =
            (wall.normalVector.dx * cut.axis.dx +
                    wall.normalVector.dy * cut.axis.dy)
                .abs();
        final extDot =
            wall.exteriorNormal.dx * cut.axis.dx +
            wall.exteriorNormal.dy * cut.axis.dy;

        final zBot = storey.elevation + wall.baseOffset;
        final zTop = zBot + wall.effectiveHeight(storey.height);

        result.add(
          CutWallJunctionSpan(
            storey: storey,
            wall: wall,
            transverse: transverse,
            isTransverseCut: wall.isCurved || transverse >= 0.15,
            exteriorDirectionS: extDot >= 0 ? 1.0 : -1.0,
            zWallBot: zBot,
            zWallTop: zTop,
            fullIntervals: fullIntervals,
            coreIntervals: coreIntervals,
            coreOpeningsFreeIntervals: coreOpeningsFree,
            exteriorIntervals: exteriorIntervals,
            interiorIntervals: interiorIntervals,
          ),
        );
      }
    }
    return result;
  }

  // === SECTION: SYMBIOTIC SLAB-WALL TRIMMING, STRIP FOUNDATIONS & PLINTH XPS ===

  static SlabWallJunctionPlan buildSlabAndFoundationJunctions({
    required ArchitectProject project,
    required ArchitectSection cut,
    required List<CutWallJunctionSpan> cutWalls,
  }) {
    final slabAndFoundationRegions = <ArchitectSectionRegion>[];
    final wallCoreCutouts = <Path>[];
    final interiorFinishCutouts = <Path>[];
    final wallBaseDetailCutouts = <String, List<Path>>{};
    final wallDetailRegions = <ArchitectSectionRegion>[];

    void addBaseCutout(String wallId, Path cutout) {
      (wallBaseDetailCutouts[wallId] ??= <Path>[]).add(cutout);
    }

    for (final floor in project.storeys) {
      for (final slab in floor.slabs) {
        final spans = ArchitectSlabGeometry.intervals(floor, slab, cut);
        if (spans.isEmpty) continue;

        final resolvedAssembly = resolveEffectiveSlabAssembly(
          project,
          floor,
          slab,
          hasWallsOverride: cutWalls.isNotEmpty,
        );
        final surfaces = ArchitectSlabGeometry.surfaces(
          project,
          floor,
          slab,
          assemblyOverride: resolvedAssembly,
        );
        if (surfaces.isEmpty) continue;

        final coreIdx = surfaces.indexWhere((s) => s.layer.id == 'core');
        if (coreIdx < 0) continue;
        final coreSurface = surfaces[coreIdx];
        final isGround = isGroundBearingSlab(
          project,
          floor,
          slab,
          resolvedAssembly,
        );

        // Identify walls resting ON this slab (wallsAbove) and walls supporting it from BELOW (wallsBelow)
        final wallsAbove = <CutWallJunctionSpan>[];
        final wallsBelow = <CutWallJunctionSpan>[];

        for (final cw in cutWalls) {
          final sampleS = cw.coreIntervals.first.$1;
          final pt = cut.pointAt(sampleS);
          final zCoreTop = coreSurface.topAt(pt);
          final zCoreBot = coreSurface.bottomAt(pt);
          final zTop = surfaces.first.topAt(pt);
          final zBot = surfaces.last.bottomAt(pt);

          final overlapsHorizontally = spans.any(
            (sp) => cw.fullIntervals.any(
              (wi) => math.min(sp.$2, wi.$2) - math.max(sp.$1, wi.$1) > -0.02,
            ),
          );
          if (!overlapsHorizontally) continue;

          if ((cw.zWallBot - zCoreTop).abs() <= 0.12 ||
              (cw.zWallBot >= zCoreBot - 0.02 && cw.zWallBot <= zTop + 0.05)) {
            wallsAbove.add(cw.atSlab(spans));
          } else if ((cw.zWallTop - zCoreTop).abs() <= 0.12 ||
              (cw.zWallTop >= zBot - 0.05 && cw.zWallTop <= zTop + 0.05)) {
            wallsBelow.add(cw.atSlab(spans));
          }
        }

        // 1. Build perimeter exterior insulation mask (where slab stops at an exterior wall without cantilevering)
        final perimeterExteriorMask = Path();
        for (final (spanA, spanB) in spans) {
          for (final cw in [...wallsAbove, ...wallsBelow]) {
            if (!cw.wall.isExterior || !cw.isTransverseCut) continue;
            for (var k = 0; k < cw.fullIntervals.length; k++) {
              final (wMin, wMax) = cw.fullIntervals[k];
              if (math.min(spanB, wMax) - math.max(spanA, wMin) < -0.02) {
                continue;
              }
              final coreSpan = k < cw.coreIntervals.length
                  ? cw.coreIntervals[k]
                  : cw.coreIntervals.first;
              final (cMin, cMax) = coreSpan;

              if (cw.exteriorDirectionS < 0) {
                // Exterior is towards -s (left of cMin)
                final cantileversLeft = spanA < wMin - 0.08;
                if (!cantileversLeft && spanA <= cMin + 0.02) {
                  final trimLeft = math.min(spanA, wMin) - 0.05;
                  if (cMin > trimLeft + 1e-4) {
                    perimeterExteriorMask.addRect(
                      Rect.fromLTRB(trimLeft, -1e4, cMin, 1e4),
                    );
                  }
                  // If intermediate/basement slab and perimeter wall has exterior layers, bridge facade insulation across slab core
                  if (!isGround && cw.exteriorIntervals.isNotEmpty) {
                    _addBridgedFacadeInsulation(
                      sourceId: slab.id,
                      cw: cw,
                      extSpan: (wMin, cMin),
                      coreSurface: coreSurface,
                      cut: cut,
                      outRegions: wallDetailRegions,
                    );
                  }
                }
              } else {
                // Exterior is towards +s (right of cMax)
                final cantileversRight = spanB > wMax + 0.08;
                if (!cantileversRight && spanB >= cMax - 0.02) {
                  final trimRight = math.max(spanB, wMax) + 0.05;
                  if (trimRight > cMax + 1e-4) {
                    perimeterExteriorMask.addRect(
                      Rect.fromLTRB(cMax, -1e4, trimRight, 1e4),
                    );
                  }
                  if (!isGround && cw.exteriorIntervals.isNotEmpty) {
                    _addBridgedFacadeInsulation(
                      sourceId: slab.id,
                      cw: cw,
                      extSpan: (cMax, wMax),
                      coreSurface: coreSurface,
                      cut: cut,
                      outRegions: wallDetailRegions,
                    );
                  }
                }
              }
            }
          }
        }

        // 2. Build Upper Floor Package cutout (wall cores above cut through finish/screed/floor insulation)
        final upperFloorWallCutout = Path();
        for (final cw in wallsAbove) {
          for (final (c0, c1) in cw.coreOpeningsFreeIntervals) {
            final pt0 = cut.pointAt(c0), pt1 = cut.pointAt(c1);
            final z0 = math.min(coreSurface.topAt(pt0), coreSurface.topAt(pt1));
            upperFloorWallCutout.addRect(
              Rect.fromLTRB(c0, z0 - 0.001, c1, z0 + 2.0),
            );
          }
        }

        // 3. Build Lower Ceiling Package cutout (wall cores below cut through ceiling plaster / basement XPS)
        final lowerCeilingWallCutout = Path();
        for (final cw in wallsBelow) {
          for (final (c0, c1) in cw.coreIntervals) {
            final pt0 = cut.pointAt(c0), pt1 = cut.pointAt(c1);
            final z0 = math.max(
              coreSurface.bottomAt(pt0),
              coreSurface.bottomAt(pt1),
            );
            lowerCeilingWallCutout.addRect(
              Rect.fromLTRB(c0, z0 - 2.0, c1, z0 + 0.001),
            );
          }
        }

        // 4. Build Ground Strip Foundations, Descending XPS Insulation & Sub-base Cutouts
        final groundSubBaseCutout = Path();
        if (isGround) {
          for (final cw in wallsAbove) {
            if (!cw.isTransverseCut || !cw.isFoundationBearing) continue;
            for (var k = 0; k < cw.coreIntervals.length; k++) {
              final (c0, c1) = cw.coreIntervals[k];
              final overlapsSlab = spans.any(
                (sp) => math.min(sp.$2, c1) - math.max(sp.$1, c0) > -0.05,
              );
              if (!overlapsSlab) continue;

              final sMid = (c0 + c1) * 0.5;
              final pMid = cut.pointAt(sMid);
              final zCoreTop = coreSurface.topAt(pMid);
              final zCoreBot = coreSurface.bottomAt(pMid);
              final zSubBaseBot = surfaces.last.bottomAt(pMid);
              final zFoundationBot = math.min(
                zCoreBot - 0.80,
                zSubBaseBot - 0.25,
              );

              // For sandwich panels, foundation stem matches full panel width (min 25 cm)
              var stemLeft = c0;
              var stemRight = c1;
              if (cw.wall.system.isPanel && (c1 - c0) < 0.24) {
                final scale = cw.wall.isCurved
                    ? 1.0
                    : 1.0 / math.max(0.25, cw.transverse);
                final targetW = math.max(0.25, cw.wall.thickness) * scale;
                if (cw.exteriorDirectionS < 0) {
                  stemRight = stemLeft + targetW;
                } else {
                  stemLeft = stemRight - targetW;
                }
              }

              // 4a. Concrete Strip Foundation Stem (merges monolithically with RC slab core)
              final stemRect = Rect.fromLTRB(
                stemLeft,
                zFoundationBot,
                stemRight,
                zCoreTop,
              );
              final stemPath = Path()..addRect(stemRect);
              slabAndFoundationRegions.add(
                ArchitectSectionRegion(
                  slab.id,
                  SlabMaterial.concrete,
                  stemPath,
                  slab: true,
                ),
              );
              groundSubBaseCutout.addRect(
                Rect.fromLTRB(
                  stemLeft,
                  zFoundationBot - 0.10,
                  stemRight,
                  zCoreTop + 0.10,
                ),
              );

              // 4b. Exterior Vertical Waterproofing + Descending Plinth/Foundation XPS Insulation
              var fndOuterLeft = stemLeft;
              var fndOuterRight = stemRight;
              if (cw.wall.isExterior) {
                final scale = cw.wall.isCurved
                    ? 1.0
                    : 1.0 / math.max(0.25, cw.transverse);
                double insSpanW = 0.0;
                if (cw.exteriorIntervals.isNotEmpty) {
                  final extSpan = k < cw.exteriorIntervals.length
                      ? cw.exteriorIntervals[k]
                      : cw.exteriorIntervals.first;
                  insSpanW = (extSpan.$2 - extSpan.$1).abs();
                } else if (cw.wall.hasInsulation ||
                    cw.wall.plinth.enabled ||
                    cw.wall.system.isLog ||
                    cw.wall.system.isPanel) {
                  insSpanW =
                      math.max(0.08, cw.wall.insulationThickness) * scale;
                }

                if (insSpanW > 1e-3) {
                  const wpThick = 0.008;
                  final isLeftExt = cw.exteriorDirectionS < 0;
                  final wpRect = isLeftExt
                      ? Rect.fromLTRB(
                          stemLeft - wpThick,
                          zFoundationBot,
                          stemLeft,
                          zCoreTop,
                        )
                      : Rect.fromLTRB(
                          stemRight,
                          zFoundationBot,
                          stemRight + wpThick,
                          zCoreTop,
                        );
                  final xpsWidth = math.max(0.02, insSpanW - wpThick);
                  final xpsRect = isLeftExt
                      ? Rect.fromLTRB(
                          wpRect.left - xpsWidth,
                          zFoundationBot,
                          wpRect.left,
                          zCoreTop,
                        )
                      : Rect.fromLTRB(
                          wpRect.right,
                          zFoundationBot,
                          wpRect.right + xpsWidth,
                          zCoreTop,
                        );

                  slabAndFoundationRegions.add(
                    ArchitectSectionRegion(
                      slab.id,
                      SlabMaterial.waterproofing,
                      Path()..addRect(wpRect),
                      slab: true,
                    ),
                  );
                  slabAndFoundationRegions.add(
                    ArchitectSectionRegion(
                      slab.id,
                      SlabMaterial.xps,
                      Path()..addRect(xpsRect),
                      slab: true,
                      hatchPattern: ArchitectSectionHatch.wall(
                        ArchitectMaterial.xps,
                      ),
                    ),
                  );

                  fndOuterLeft = math.min(stemLeft, xpsRect.left);
                  fndOuterRight = math.max(stemRight, xpsRect.right);

                  // Trim any sub-base layers protruding past the exterior foundation face
                  if (isLeftExt) {
                    groundSubBaseCutout.addRect(
                      Rect.fromLTRB(
                        math.min(fndOuterLeft, spans.first.$1) - .05,
                        zFoundationBot - 1.0,
                        stemRight,
                        zCoreTop + 0.5,
                      ),
                    );
                  } else {
                    groundSubBaseCutout.addRect(
                      Rect.fromLTRB(
                        stemLeft,
                        zFoundationBot - 1.0,
                        math.max(fndOuterRight, spans.last.$2) + .05,
                        zCoreTop + 0.5,
                      ),
                    );
                  }
                }
              }

              // 4c. 5 cm Blinding Concrete Pad under the Strip Foundation
              const blindingStep = 0.05;
              const blindingHeight = 0.05;
              final blindingRect = Rect.fromLTRB(
                fndOuterLeft - blindingStep,
                zFoundationBot - blindingHeight,
                fndOuterRight + blindingStep,
                zFoundationBot,
              );
              slabAndFoundationRegions.add(
                ArchitectSectionRegion(
                  slab.id,
                  SlabMaterial.blindingConcrete,
                  Path()..addRect(blindingRect),
                  slab: true,
                ),
              );
              groundSubBaseCutout.addRect(blindingRect);
            }
          }
        }

        // 5. Material-Specific Wall Base Details (Brick Waterproofing, Timber/Log Sill Plate, Stud Sole Plate, Panel Flashing)
        for (final cw in wallsAbove) {
          if (!cw.isTransverseCut || cw.wall.isParapet) continue;
          _buildWallBaseJunctionDetails(
            cw: cw,
            spans: spans,
            coreSurface: coreSurface,
            cut: cut,
            isGroundSlab: isGround,
            onAddRegion: wallDetailRegions.add,
            onAddWallCutout: (cutout) => addBaseCutout(cw.wall.id, cutout),
          );
        }

        // 6. Emit each Slab Layer Surface with its exact symbiotic boolean trimming
        var fullSlabEnvelope = Path();
        for (var sIdx = 0; sIdx < surfaces.length; sIdx++) {
          final surface = surfaces[sIdx];
          var rawPath = Path();
          for (final (a, b) in spans) {
            final pa = cut.pointAt(a), pb = cut.pointAt(b);
            rawPath.addPolygon([
              Offset(a, surface.topAt(pa)),
              Offset(b, surface.topAt(pb)),
              Offset(b, surface.bottomAt(pb)),
              Offset(a, surface.bottomAt(pa)),
            ], true);
          }
          if (rawPath.getBounds().isEmpty) continue;

          // All slab layers stop at the outer face of perimeter wall cores
          if (!perimeterExteriorMask.getBounds().isEmpty) {
            try {
              rawPath = Path.combine(
                PathOperation.difference,
                rawPath,
                perimeterExteriorMask,
              );
            } catch (_) {}
          }

          fullSlabEnvelope = Path.combine(
            PathOperation.union,
            fullSlabEnvelope,
            rawPath,
          );

          if (sIdx < coreIdx) {
            // Upper floor build-up (finish, screed, foil, floor/acoustic insulation):
            // Cut by wall structural cores resting on the slab!
            if (!upperFloorWallCutout.getBounds().isEmpty) {
              try {
                rawPath = Path.combine(
                  PathOperation.difference,
                  rawPath,
                  upperFloorWallCutout,
                );
              } catch (_) {}
            }
          } else if (sIdx == coreIdx) {
            // Structural Concrete Core:
            // Clips wall structural cores so walls never overlap the concrete slab core.
            if (!rawPath.getBounds().isEmpty) {
              wallCoreCutouts.add(rawPath);
            }
          } else {
            // Layers below concrete core:
            if (isGround) {
              // Sub-base layers (waterproofing, blinding, ballast, fill) stop at the strip foundations
              if (!groundSubBaseCutout.getBounds().isEmpty) {
                try {
                  rawPath = Path.combine(
                    PathOperation.difference,
                    rawPath,
                    groundSubBaseCutout,
                  );
                } catch (_) {}
              }
            } else {
              // Ceiling plaster / basement soffit XPS is cut by supporting wall cores below
              if (!lowerCeilingWallCutout.getBounds().isEmpty) {
                try {
                  rawPath = Path.combine(
                    PathOperation.difference,
                    rawPath,
                    lowerCeilingWallCutout,
                  );
                } catch (_) {}
              }
            }
          }

          if (!rawPath.getBounds().isEmpty) {
            slabAndFoundationRegions.add(
              ArchitectSectionRegion(
                slab.id,
                surface.layer.material,
                rawPath,
                slab: true,
              ),
            );
          }
        }

        if (!fullSlabEnvelope.getBounds().isEmpty) {
          interiorFinishCutouts.add(fullSlabEnvelope);
        }
      }
    }

    return SlabWallJunctionPlan(
      slabAndFoundationRegions: slabAndFoundationRegions,
      wallCoreCutouts: wallCoreCutouts,
      interiorFinishCutouts: interiorFinishCutouts,
      wallBaseDetailCutouts: wallBaseDetailCutouts,
      wallDetailRegions: wallDetailRegions,
    );
  }

  // === SECTION: MATERIAL-SPECIFIC WALL BASE DETAILS ===

  static void _buildWallBaseJunctionDetails({
    required CutWallJunctionSpan cw,
    required List<(double, double)> spans,
    required SlabLayerSurface coreSurface,
    required ArchitectSection cut,
    required bool isGroundSlab,
    required void Function(ArchitectSectionRegion) onAddRegion,
    required void Function(Path) onAddWallCutout,
  }) {
    final wall = cw.wall;
    final isLogOrTimber =
        wall.system.isLog || wall.coreMaterial == WallCoreMaterial.timber;
    final isStudFrame = wall.system.isFrame;
    final isSandwichPanel = wall.system.isPanel;
    final isBrick =
        !wall.system.isSpecial &&
        {WallCoreMaterial.brick, WallCoreMaterial.aeratedConcrete}.contains(wall.coreMaterial);

    if (isSandwichPanel) {
      for (final (f0, f1) in cw.fullIntervals) {
        final overlaps = spans.any(
          (sp) => math.min(sp.$2, f1) - math.max(sp.$1, f0) > -0.05,
        );
        if (!overlaps) continue;
        final zBase = coreSurface.topAt(cut.pointAt((f0 + f1) * 0.5));
        final isLeftExt = cw.exteriorDirectionS < 0;
        const flashH = 0.016;
        const dripLip = 0.018;
        final poly = isLeftExt
            ? <Offset>[
                Offset(f0 - dripLip, zBase),
                Offset(f0, zBase + flashH),
                Offset(f1, zBase + flashH),
                Offset(f1, zBase),
              ]
            : <Offset>[
                Offset(f0, zBase),
                Offset(f0, zBase + flashH),
                Offset(f1, zBase + flashH),
                Offset(f1 + dripLip, zBase),
              ];
        final flashPath = Path()..addPolygon(poly, true);
        onAddRegion(
          ArchitectSectionRegion(
            wall.id,
            SlabMaterial.custom,
            flashPath,
            customFillColor: const Color(0xFF37474F),
          ),
        );
        onAddWallCutout(
          Path()..addRect(
            Rect.fromLTRB(f0 - 0.01, zBase - 0.05, f1 + 0.01, zBase + flashH),
          ),
        );
      }
      return;
    }

    for (final (c0, c1) in cw.coreOpeningsFreeIntervals) {
      final overlaps = spans.any(
        (sp) => math.min(sp.$2, c1) - math.max(sp.$1, c0) > -0.05,
      );
      if (!overlaps) continue;
      final spanW = c1 - c0;
      if (spanW < 0.02) continue;
      final zBase = coreSurface.topAt(cut.pointAt((c0 + c1) * 0.5));

      if (isLogOrTimber) {
        // 1. Horizontal waterproofing membrane (1.0 cm)
        const wpH = 0.010;
        const sillH = 0.060;
        final wpRect = Rect.fromLTRB(c0, zBase, c1, zBase + wpH);
        onAddRegion(
          ArchitectSectionRegion(
            wall.id,
            SlabMaterial.waterproofing,
            Path()..addRect(wpRect),
            slab: true,
          ),
        );

        // 2. Impregnated Timber Sill Plate (подложна греда / праг с диагонали)
        final sillW = (spanW * 0.85).clamp(math.min(0.12, spanW), spanW);
        final sMid = (c0 + c1) * 0.5;
        final sa = sMid - sillW * 0.5;
        final sb = sMid + sillW * 0.5;
        final zSillTop = zBase + wpH + sillH;
        final sillPoly = <Offset>[
          Offset(sa, zSillTop),
          Offset(sb, zSillTop),
          Offset(sb, zBase + wpH),
          Offset(sa, zBase + wpH),
        ];
        onAddRegion(
          ArchitectSectionRegion(
            wall.id,
            SlabMaterial.parquet,
            Path()..addPolygon(sillPoly, true),
            slab: true,
            timberCrossSectionPolygon: sillPoly,
            customFillColor: const Color(0xFFD7A86E),
          ),
        );

        // 3. Exterior metal drip flashing (капелник) for exterior log/timber walls
        if (wall.isExterior) {
          final isLeftExt = cw.exteriorDirectionS < 0;
          const dripW = 0.025;
          final dripPoly = isLeftExt
              ? <Offset>[
                  Offset(c0 - dripW, zBase),
                  Offset(c0, zBase + wpH),
                  Offset(sa, zBase + wpH),
                  Offset(sa, zBase),
                ]
              : <Offset>[
                  Offset(sb, zBase),
                  Offset(sb, zBase + wpH),
                  Offset(c1, zBase + wpH),
                  Offset(c1 + dripW, zBase),
                ];
          onAddRegion(
            ArchitectSectionRegion(
              wall.id,
              SlabMaterial.custom,
              Path()..addPolygon(dripPoly, true),
              customFillColor: const Color(0xFF37474F),
            ),
          );
        }

        // Trim bottom log course cleanly at top of the timber sill plate
        onAddWallCutout(
          Path()..addRect(
            Rect.fromLTRB(c0 - 0.02, zBase - 0.20, c1 + 0.02, zSillTop),
          ),
        );
      } else if (isStudFrame) {
        // Stud-Frame Wall: optional ground waterproofing + Bottom Sole Plate (долен праг с диагонали)
        final wpH = isGroundSlab ? 0.010 : 0.0;
        const plateH = 0.045;
        if (wpH > 0) {
          onAddRegion(
            ArchitectSectionRegion(
              wall.id,
              SlabMaterial.waterproofing,
              Path()..addRect(Rect.fromLTRB(c0, zBase, c1, zBase + wpH)),
              slab: true,
            ),
          );
        }
        final zPlateTop = zBase + wpH + plateH;
        final platePoly = <Offset>[
          Offset(c0, zPlateTop),
          Offset(c1, zPlateTop),
          Offset(c1, zBase + wpH),
          Offset(c0, zBase + wpH),
        ];
        onAddRegion(
          ArchitectSectionRegion(
            wall.id,
            SlabMaterial.parquet,
            Path()..addPolygon(platePoly, true),
            slab: true,
            timberCrossSectionPolygon: platePoly,
            customFillColor: const Color(0xFFD7A86E),
          ),
        );
        onAddWallCutout(
          Path()..addRect(Rect.fromLTRB(c0, zBase - 0.10, c1, zPlateTop)),
        );
      } else if (isBrick && isGroundSlab) {
        // Brick / Masonry Wall on Ground Slab: Horizontal capillary-break waterproofing membrane
        const wpH = 0.012;
        final wpRect = Rect.fromLTRB(c0, zBase, c1, zBase + wpH);
        onAddRegion(
          ArchitectSectionRegion(
            wall.id,
            SlabMaterial.waterproofing,
            Path()..addRect(wpRect),
            slab: true,
          ),
        );
        onAddWallCutout(
          Path()..addRect(Rect.fromLTRB(c0, zBase - 0.10, c1, zBase + wpH)),
        );
      }
    }
  }

  static void _addBridgedFacadeInsulation({
    required String sourceId,
    required CutWallJunctionSpan cw,
    required (double, double) extSpan,
    required SlabLayerSurface coreSurface,
    required ArchitectSection cut,
    required List<ArchitectSectionRegion> outRegions,
  }) {
    final sA = math.min(extSpan.$1, extSpan.$2);
    final sB = math.max(extSpan.$1, extSpan.$2);
    if (sB - sA < 1e-4) return;

    final pMid = cut.pointAt((sA + sB) * 0.5);
    final zTop = coreSurface.topAt(pMid);
    final zBot = coreSurface.bottomAt(pMid);
    if (zTop <= zBot + 1e-4) return;

    final wall = cw.wall;
    final layers = wall.resolvedLayers;
    final coreIndex = layers.indexWhere(
      (l) => l.role == ArchitectLayerRole.core,
    );
    final extLayers = coreIndex > 0
        ? layers.sublist(0, coreIndex)
        : const <ArchitectMaterialLayer>[];
    if (extLayers.isEmpty) return;

    final totalExtThick = extLayers.fold<double>(
      0.0,
      (v, l) => v + l.thickness,
    );
    if (totalExtThick <= 1e-4) return;

    final spanW = sB - sA;
    final isLeftExt = cw.exteriorDirectionS < 0;
    var cursor = 0.0;

    for (final layer in extLayers) {
      final frac0 = cursor / totalExtThick;
      final frac1 = (cursor + layer.thickness) / totalExtThick;
      final lA = isLeftExt ? (sA + spanW * frac0) : (sB - spanW * frac1);
      final lB = isLeftExt ? (sA + spanW * frac1) : (sB - spanW * frac0);
      cursor += layer.thickness;

      if (lB <= lA + 1e-4) continue;
      final rect = Rect.fromLTRB(lA, zBot, lB, zTop);
      final material = switch (layer.material) {
        ArchitectMaterial.concrete => SlabMaterial.concrete,
        ArchitectMaterial.xps => SlabMaterial.xps,
        ArchitectMaterial.eps => SlabMaterial.floorInsulation,
        ArchitectMaterial.stoneWool => SlabMaterial.mineralWool,
        ArchitectMaterial.timber => SlabMaterial.parquet,
        ArchitectMaterial.tile || ArchitectMaterial.stone => SlabMaterial.tile,
        _ => SlabMaterial.plaster,
      };
      outRegions.add(
        ArchitectSectionRegion(
          sourceId,
          material,
          Path()..addRect(rect),
          customFillColor: layer.material.color,
          hatchPattern: ArchitectSectionHatch.wall(layer.material),
        ),
      );
    }
  }

  // === SECTION: 1D INTERVAL GEOMETRY HELPERS ===

  static List<(double, double)> _polygonIntervals(
    List<Offset> polygon,
    ArchitectSection section,
  ) {
    if (polygon.length < 3) return const [];
    final breaks = <double>[0.0, section.length];
    final u = section.axis;
    double cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;

    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i];
      final v = polygon[(i + 1) % polygon.length] - a;
      final d = cross(u, v);
      if (d.abs() < 1e-10) continue;
      final t = cross(a - section.start, v) / d;
      final q = cross(a - section.start, u) / d;
      if (t >= 0.0 && t <= section.length && q >= -1e-7 && q <= 1.0 + 1e-7) {
        breaks.add(t);
      }
    }
    breaks.sort();

    final result = <(double, double)>[];
    for (var i = 0; i < breaks.length - 1; i++) {
      final a = breaks[i], b = breaks[i + 1];
      if (b - a < 1e-5) continue;
      final mid = section.pointAt((a + b) * 0.5);
      if (!ArchitectSlabGeometry.inside(polygon, mid)) continue;
      if (result.isNotEmpty && (result.last.$2 - a).abs() < 1e-5) {
        final last = result.removeLast();
        result.add((last.$1, b));
      } else {
        result.add((a, b));
      }
    }
    return result;
  }

  static List<(double, double)> _baseDoorwayIntervals(
    ArchitectWall wall,
    ArchitectSection cut,
  ) {
    final result = <(double, double)>[];
    for (final d in wall.doors) {
      if (d.sillHeight > 0.03) continue;
      final ratio = d.offsetRatio;
      final halfRatio =
          (wall.openingArcSpan(d.width) / 2.0) / math.max(0.01, wall.length);
      final from = (ratio - halfRatio).clamp(0.0, 1.0);
      final to = (ratio + halfRatio).clamp(0.0, 1.0);
      if (to <= from + 1e-5) continue;
      final offset = wall.centerLineOffset;
      final doorPoly = wall.facePolygon(
        offset - wall.thickness,
        offset + wall.thickness,
        from: from,
        to: to,
      );
      result.addAll(_polygonIntervals(doorPoly, cut));
    }
    return result;
  }

  static List<(double, double)> _subtractIntervals(
    List<(double, double)> base,
    List<(double, double)> cutouts,
  ) {
    if (cutouts.isEmpty) return base;
    var current = List<(double, double)>.from(base);
    for (final (cA, cB) in cutouts) {
      final next = <(double, double)>[];
      for (final (a, b) in current) {
        if (cB <= a + 1e-5 || cA >= b - 1e-5) {
          next.add((a, b));
        } else {
          if (cA > a + 1e-5) next.add((a, cA));
          if (cB < b - 1e-5) next.add((cB, b));
        }
      }
      current = next;
    }
    return current;
  }
}
