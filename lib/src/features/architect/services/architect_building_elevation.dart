import 'package:flutter/foundation.dart' show compute;
import '../rendering/architect_projection_visibility.dart';
import '../rendering/architect_mesh_section.dart';
import 'dart:math' as math;
import 'dart:ui';
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../models/architect_elements.dart';
import '../models/architect_elevation.dart';
import '../models/architect_project.dart';
import '../models/architect_section_visibility.dart';
import '../rendering/architect_3d_builder.dart';
import 'architect_elevation_symbols.dart';

/// Vector hidden-surface removal, independent of screen resolution. Coplanar
/// triangles (including separate wall segments/storeys) are united before any
/// outlines are drawn, eliminating tessellation and boolean-cut seams.
class ArchitectBuildingElevation {
  final List<Path> faces;
  final Rect bounds;
  final Map<String, Path> elementPaths;
  final List<({Path lines, Path clip})> operations;
  final List<ArchitectElevationSlope> slopes;
  final List<Offset> terrain;
  const ArchitectBuildingElevation(
    this.faces,
    this.bounds, {
    this.elementPaths = const {},
    this.operations = const [],
    this.slopes = const [],
    this.terrain = const [],
  });

  static ArchitectBuildingElevation build(
    ArchitectProject project,
    ArchitectElevation view, {
    List<List<Offset>> occlusionMasks = const [],
    Set<String> suppressedOpeningIds = const {},
    Map<String, FenestrationElevationDetail> openingDetailLevels = const {},
    ArchitectSectionVisibility? sectionVisibility,
    Set<String> cutOpeningIds = const {},
  }) {
    final classification = _classifyOpenings(
      project,
      view,
      cutOpeningIds: {...cutOpeningIds, ...suppressedOpeningIds},
      presetDetailLevels: openingDetailLevels,
      occlusionMasks: occlusionMasks,
    );
    final sources = <Triangle3D, String>{};
    final silhouetteGroups = <Triangle3D, String>{};
    final mesh = Architect3dBuilder.buildProjectMesh(
      project,
      previewGeometry: false,
      sources: sources,
      cleanDrainage: true,
      silhouetteGroups: silhouetteGroups,
      sectionVisibility: sectionVisibility,
      suppressedOpeningIds: classification.suppressedOpeningIds,
      openingDetailLevels: classification.openingDetailLevels,
    );
    return withTerrain(
      _fromTriangles(
        mesh.triangles,
        view,
        sources: sources,
        silhouetteGroups: silhouetteGroups,
        project: project,
        occlusionMasks: occlusionMasks,
        suppressedOpeningIds: classification.suppressedOpeningIds,
        openingDetailLevels: classification.openingDetailLevels,
      ),
      view,
    );
  }

  /// Interactive views perform hidden-surface removal on a worker isolate.
  /// Special wall booleans and contact surfaces also run on worker isolates;
  /// native path preparation and final Flutter paths stay on the UI isolate.
  static Future<ArchitectBuildingElevation> buildAsync(
    ArchitectProject project,
    ArchitectElevation view, {
    List<List<Offset>> occlusionMasks = const [],
    ArchitectSectionVisibility? sectionVisibility,
    Set<String> cutOpeningIds = const {},
  }) async {
    final classification = _classifyOpenings(
      project,
      view,
      cutOpeningIds: cutOpeningIds,
      occlusionMasks: occlusionMasks,
    );
    final sources = <Triangle3D, String>{}, groups = <Triangle3D, String>{};
    final mesh = await Architect3dBuilder.buildProjectMeshAsync(
      project,
      previewGeometry: false,
      sources: sources,
      silhouetteGroups: groups,
      cleanDrainage: true,
      sectionVisibility: sectionVisibility,
      suppressedOpeningIds: classification.suppressedOpeningIds,
      openingDetailLevels: classification.openingDetailLevels,
    );
    Future<ArchitectBuildingElevation> solve(ArchitectElevation local) async {
      final prepared = _prepareProjection(
        mesh.triangles,
        local,
        sources: sources,
        silhouetteGroups: groups,
        project: project,
        occlusionMasks: occlusionMasks,
        suppressedOpeningIds: classification.suppressedOpeningIds,
      );
      final contours = await compute(
        solveArchitectProjection,
        prepared.request,
        debugLabel: 'architectural-visibility',
      );
      return _fromContours(
        contours,
        local,
        project: project,
        symbols: prepared.symbols,
        openingDetailLevels: classification.openingDetailLevels,
      );
    }

    if (view.steps.isEmpty) return withTerrain(await solve(view), view);
    final faces = <Path>[], paths = <String, List<Path>>{};
    final operations = <({Path lines, Path clip})>[];
    final slopes = <ArchitectElevationSlope>[];
    Rect? bounds;
    for (final segment in view.segments) {
      final depth = view.viewDepth == null
          ? null
          : view.viewDepth! - segment.offset;
      if (depth != null && depth <= 0) continue;
      final part = await solve(
        view.copyWith(
          start: segment.start,
          end: segment.end,
          steps: const [],
          viewDepth: depth,
        ),
      );
      final delta = (segment.start + segment.end) / 2 - view.centre;
      final shift = Offset(
        delta.dx * view.right.dx + delta.dy * view.right.dy,
        0,
      );
      faces.addAll(part.faces.map((p) => p.shift(shift)));
      for (final entry in part.elementPaths.entries) {
        (paths[entry.key] ??= []).add(entry.value.shift(shift));
      }
      operations.addAll([
        for (final op in part.operations)
          (lines: op.lines.shift(shift), clip: op.clip.shift(shift)),
      ]);
      slopes.addAll([
        for (final slope in part.slopes)
          ArchitectElevationSlope(
            slope.id,
            slope.start + shift,
            slope.end + shift,
            slope.percent,
          ),
      ]);
      bounds =
          bounds?.expandToInclude(part.bounds.shift(shift)) ??
          part.bounds.shift(shift);
    }
    return withTerrain(
      ArchitectBuildingElevation(
        faces,
        bounds ?? Rect.fromLTWH(-view.length / 2, 0, view.length, 3),
        elementPaths: {
          for (final e in paths.entries)
            e.key: ArchitectMeshSection.unionPaths(e.value),
        },
        operations: operations,
        slopes: slopes,
      ),
      view,
    );
  }

  static ({
    Set<String> suppressedOpeningIds,
    Map<String, FenestrationElevationDetail> openingDetailLevels,
  })
  _classifyOpenings(
    ArchitectProject project,
    ArchitectElevation view, {
    Set<String> cutOpeningIds = const {},
    Map<String, FenestrationElevationDetail> presetDetailLevels = const {},
    List<List<Offset>> occlusionMasks = const [],
  }) {
    final suppressed = <String>{...cutOpeningIds};
    final detailLevels = <String, FenestrationElevationDetail>{
      ...presetDetailLevels,
      for (final id in cutOpeningIds) id: FenestrationElevationDetail.hidden,
    };

    final viewSegments = view.steps.isEmpty
        ? [view]
        : [
            for (final s in view.segments)
              if (view.viewDepth == null || view.viewDepth! - s.offset > 0)
                view.copyWith(
                  start: s.start,
                  end: s.end,
                  steps: const [],
                  viewDepth: view.viewDepth == null
                      ? null
                      : view.viewDepth! - s.offset,
                ),
          ];
    if (viewSegments.isEmpty) {
      return (
        suppressedOpeningIds: suppressed,
        openingDetailLevels: detailLevels,
      );
    }

    for (final storey in project.storeys) {
      for (final wall in storey.walls) {
        final allOpenings = [
          for (final d in wall.doors)
            (
              id: d.id,
              ratio: d.offsetRatio,
              width: d.width,
              height: d.height,
              sill: d.sillHeight,
            ),
          for (final w in wall.windows)
            (
              id: w.id,
              ratio: w.offsetRatio,
              width: w.width,
              height: w.height,
              sill: w.sillHeight,
            ),
        ];
        for (final op in allOpenings) {
          if (suppressed.contains(op.id) || detailLevels.containsKey(op.id)) {
            if (detailLevels[op.id] == FenestrationElevationDetail.hidden) {
              suppressed.add(op.id);
            }
            continue;
          }
          final axis = wall.openingAxis(op.ratio);
          final wallVec = axis.$2 - axis.$1;
          final wallLen = wallVec.distance;
          if (wallLen < 1e-4) continue;
          final u = wallVec / wallLen;
          final center2D = axis.$1 + u * (op.ratio * wallLen);
          final pA = center2D - u * (op.width / 2.0);
          final pB = center2D + u * (op.width / 2.0);
          final zBottom = storey.elevation + wall.baseOffset + op.sill;
          final zTop = zBottom + op.height;
          final yMid = (zBottom + zTop) / 2.0;

          var maxVisibleWidth = 0.0;
          var isObliqueOrClipped = false;
          var inFrontOfView = false;

          for (final segView in viewSegments) {
            final right = segView.right;
            final forward = segView.viewDirection;
            final centre = segView.centre;
            Vector3 proj(Offset p) {
              final d = p - centre;
              return Vector3(
                d.dx * right.dx + d.dy * right.dy,
                yMid,
                d.dx * forward.dx + d.dy * forward.dy,
              );
            }

            final vA = proj(pA);
            final vB = proj(pB);
            if (math.max(vA.z, vB.z) < -1e-4) continue;
            inFrontOfView = true;

            final cosAngle = (u.dx * right.dx + u.dy * right.dy).abs();
            if (cosAngle < 0.999) {
              isObliqueOrClipped = true;
            }

            var seg = _clip3([vA, vB], (p) => p.z + 1e-4);
            if (segView.viewDepth != null) {
              seg = _clip3(seg, (p) => segView.viewDepth! + 1e-4 - p.z);
            }
            seg = _clip3(seg, (p) => p.x + segView.length / 2 + 1e-4);
            seg = _clip3(seg, (p) => segView.length / 2 + 1e-4 - p.x);
            if (seg.length < 2) {
              isObliqueOrClipped = true;
              continue;
            }
            final x0 = math.min(seg.first.x, seg.last.x);
            final x1 = math.max(seg.first.x, seg.last.x);
            final zMid = (seg.first.z + seg.last.z) / 2.0;
            if ((x1 - x0) < op.width - 1e-3) {
              isObliqueOrClipped = true;
            }

            var intervals = <(double, double)>[(x0, x1)];
            void subtractInterval(double cut0, double cut1) {
              if (cut1 <= cut0 + 1e-6) return;
              final next = <(double, double)>[];
              for (final iv in intervals) {
                if (cut1 <= iv.$1 || cut0 >= iv.$2) {
                  next.add(iv);
                } else {
                  isObliqueOrClipped = true;
                  if (cut0 > iv.$1 + 1e-6) next.add((iv.$1, cut0));
                  if (cut1 < iv.$2 - 1e-6) next.add((cut1, iv.$2));
                }
              }
              intervals = next;
            }

            for (final mask in occlusionMasks) {
              if (!_hasArea(mask)) continue;
              final mb = _bounds2(mask);
              if (yMid > mb.top + 1e-3 && yMid < mb.bottom - 1e-3) {
                subtractInterval(mb.left, mb.right);
              }
            }

            for (final other in storey.walls) {
              if (other.id == wall.id) continue;
              final owBottom = storey.elevation + other.baseOffset;
              final owTop = owBottom + other.effectiveHeight(storey.height);
              if (yMid <= owBottom + 1e-3 || yMid >= owTop - 1e-3) continue;
              final corners = [for (final c in other.polygonCorners) proj(c)];
              final clipped = _clip3(corners, (p) => p.z + 1e-4);
              if (clipped.length < 2) continue;
              var oxMin = double.infinity;
              var oxMax = double.negativeInfinity;
              var ozMin = double.infinity;
              for (final cp in clipped) {
                oxMin = math.min(oxMin, cp.x);
                oxMax = math.max(oxMax, cp.x);
                ozMin = math.min(ozMin, cp.z);
              }
              if (ozMin < zMid - wall.thickness / 2 - 0.01) {
                subtractInterval(oxMin, oxMax);
              }
            }

            var visW = 0.0;
            for (final iv in intervals) {
              visW += (iv.$2 - iv.$1);
            }
            maxVisibleWidth = math.max(maxVisibleWidth, visW);
          }

          if (!inFrontOfView) {
            detailLevels[op.id] = FenestrationElevationDetail.clean2D;
            continue;
          }

          if (isObliqueOrClipped) {
            if (maxVisibleWidth < 0.10) {
              suppressed.add(op.id);
              detailLevels[op.id] = FenestrationElevationDetail.hidden;
            } else if (maxVisibleWidth < 0.40) {
              detailLevels[op.id] =
                  FenestrationElevationDetail.outerContourOnly;
            } else {
              detailLevels[op.id] = FenestrationElevationDetail.clean2D;
            }
          } else {
            detailLevels[op.id] = FenestrationElevationDetail.clean2D;
          }
        }
      }
    }

    return (
      suppressedOpeningIds: suppressed,
      openingDetailLevels: detailLevels,
    );
  }

  static ArchitectBuildingElevation fromTriangles(
    List<Triangle3D> triangles,
    ArchitectElevation view, {
    Map<Triangle3D, String> sources = const {},
  }) => withTerrain(_fromTriangles(triangles, view, sources: sources), view);

  static void validateTerrain(List<Offset> points) {
    if (points.isNotEmpty && points.length < 2) {
      throw ArgumentError('Terrain needs two points');
    }
    for (var i = 0; i < points.length; i++) {
      if (!points[i].dx.isFinite ||
          !points[i].dy.isFinite ||
          (i > 0 && points[i].dx - points[i - 1].dx < .001)) {
        throw ArgumentError('Terrain must run from left to right');
      }
    }
  }

  static ArchitectBuildingElevation withTerrain(
    ArchitectBuildingElevation geometry,
    ArchitectElevation view,
  ) {
    final points = view.terrain;
    if (points.isEmpty) return geometry;
    validateTerrain(points);
    final left =
        math.min(
          -view.length / 2,
          math.min(geometry.bounds.left, points.first.dx),
        ) -
        .5;
    final right =
        math.max(
          view.length / 2,
          math.max(geometry.bounds.right, points.last.dx),
        ) +
        .5;
    final bottom =
        math.min(
          geometry.bounds.top,
          points.map((p) => p.dy).reduce(math.min),
        ) -
        10;
    final ground = [
      Offset(left, points.first.dy),
      ...points,
      Offset(right, points.last.dy),
    ];
    final mask = Path()
      ..addPolygon([
        ...ground,
        Offset(right, bottom),
        Offset(left, bottom),
      ], true);
    Path visible(Path p) => Path.combine(PathOperation.difference, p, mask);
    final faces = [
      for (final p in geometry.faces) visible(p),
    ].where((p) => !p.getBounds().isEmpty).toList();
    final paths = {
      for (final e in geometry.elementPaths.entries) e.key: visible(e.value),
    };
    paths.removeWhere((id, p) => p.getBounds().isEmpty);
    final bounds = Rect.fromLTRB(
      left,
      ground.map((p) => p.dy).reduce(math.min) - .4,
      right,
      math.max(
        geometry.bounds.bottom,
        ground.map((p) => p.dy).reduce(math.max),
      ),
    );
    return ArchitectBuildingElevation(
      faces,
      bounds,
      elementPaths: paths,
      operations: [
        for (final op in geometry.operations)
          (lines: op.lines, clip: visible(op.clip)),
      ],
      slopes: [
        for (final slope in geometry.slopes)
          if (!mask.contains(slope.start) && !mask.contains(slope.end)) slope,
      ],
      terrain: ground,
    );
  }

  static ArchitectBuildingElevation _fromTriangles(
    List<Triangle3D> triangles,
    ArchitectElevation view, {
    Map<Triangle3D, String> sources = const {},
    Map<Triangle3D, String> silhouetteGroups = const {},
    ArchitectProject? project,
    List<List<Offset>> occlusionMasks = const [],
    Set<String> suppressedOpeningIds = const {},
    Map<String, FenestrationElevationDetail> openingDetailLevels = const {},
  }) {
    if (view.steps.isNotEmpty) {
      final parts = <ArchitectBuildingElevation>[];
      for (final s in view.segments) {
        final depth = view.viewDepth == null
            ? null
            : view.viewDepth! - s.offset;
        if (depth != null && depth <= 0) continue;
        final local = _fromTriangles(
          triangles,
          view.copyWith(
            start: s.start,
            end: s.end,
            steps: const [],
            viewDepth: depth,
          ),
          sources: sources,
          silhouetteGroups: silhouetteGroups,
          project: project,
          suppressedOpeningIds: suppressedOpeningIds,
          openingDetailLevels: openingDetailLevels,
        );
        final delta = (s.start + s.end) / 2 - view.centre;
        final shift = Offset(
          delta.dx * view.right.dx + delta.dy * view.right.dy,
          0,
        );
        parts.add(
          ArchitectBuildingElevation(
            [for (final p in local.faces) p.shift(shift)],
            local.bounds.shift(shift),
            elementPaths: {
              for (final e in local.elementPaths.entries)
                e.key: e.value.shift(shift),
            },
            operations: [
              for (final op in local.operations)
                (lines: op.lines.shift(shift), clip: op.clip.shift(shift)),
            ],
            slopes: [
              for (final s in local.slopes)
                ArchitectElevationSlope(
                  s.id,
                  s.start + shift,
                  s.end + shift,
                  s.percent,
                ),
            ],
          ),
        );
      }
      final paths = <String, Path>{};
      for (final part in parts) {
        for (final e in part.elementPaths.entries) {
          paths[e.key] = paths.containsKey(e.key)
              ? ArchitectMeshSection.unionPaths([paths[e.key]!, e.value])
              : e.value;
        }
      }
      return ArchitectBuildingElevation(
        [for (final p in parts) ...p.faces],
        parts.isEmpty
            ? Rect.fromLTWH(-view.length / 2, 0, view.length, 3)
            : parts.map((p) => p.bounds).reduce((a, b) => a.expandToInclude(b)),
        elementPaths: paths,
        operations: [for (final p in parts) ...p.operations],
        slopes: [for (final p in parts) ...p.slopes],
      );
    }
    if (view.length < .01) {
      return const ArchitectBuildingElevation([], Rect.fromLTWH(-1, 0, 2, 3));
    }
    final prepared = _prepareProjection(
      triangles,
      view,
      sources: sources,
      silhouetteGroups: silhouetteGroups,
      project: project,
      occlusionMasks: occlusionMasks,
      suppressedOpeningIds: suppressedOpeningIds,
    );
    return _fromContours(
      solveArchitectProjection(prepared.request),
      view,
      project: project,
      symbols: prepared.symbols,
      openingDetailLevels: openingDetailLevels,
    );
  }

  static ({
    ArchitectProjectionRequest request,
    List<ArchitectElevationOperation> symbols,
  })
  _prepareProjection(
    List<Triangle3D> triangles,
    ArchitectElevation view, {
    Map<Triangle3D, String> sources = const {},
    Map<Triangle3D, String> silhouetteGroups = const {},
    ArchitectProject? project,
    List<List<Offset>> occlusionMasks = const [],
    Set<String> suppressedOpeningIds = const {},
  }) {
    final symbols = project == null
        ? <ArchitectElevationOperation>[]
        : ArchitectElevationOperation.build(
            project,
            view,
            excludedOpeningIds: suppressedOpeningIds,
          );
    return (
      request: ArchitectProjectionRequest(
        triangles: [
          for (final t in triangles)
            (
              a: t.v0,
              b: t.v1,
              c: t.v2,
              color: t.color?.toARGB32(),
              source: sources[t],
              silhouette: silhouetteGroups[t],
            ),
        ],
        centre: view.centre,
        right: view.right,
        forward: view.viewDirection,
        length: view.length,
        depth: view.viewDepth,
        masks: occlusionMasks,
        apertures: [
          for (final symbol in symbols)
            (id: symbol.id, points: symbol.aperture),
        ],
      ),
      symbols: symbols,
    );
  }

  static ArchitectBuildingElevation _fromContours(
    ArchitectProjectionContours data,
    ArchitectElevation view, {
    ArchitectProject? project,
    List<ArchitectElevationOperation> symbols = const [],
    Map<String, FenestrationElevationDetail> openingDetailLevels = const {},
  }) {
    Path path(List<List<Offset>> contours) {
      final result = Path();
      for (final contour in contours) {
        result.addPolygon(contour, true);
      }
      return result;
    }

    final faces = data.faces.map(path).toList();
    final elementPaths = {
      for (final entry in data.elements.entries) entry.key: path(entry.value),
    };
    final operations = <({Path lines, Path clip})>[];
    for (var i = 0; i < symbols.length; i++) {
      final symbol = symbols[i], visible = path(data.apertures[i]);
      if (visible.getBounds().isEmpty) continue;
      final detail =
          openingDetailLevels[symbol.id] ?? FenestrationElevationDetail.clean2D;
      if (detail != FenestrationElevationDetail.outerContourOnly &&
          detail != FenestrationElevationDetail.hidden) {
        operations.add((lines: symbol.lines, clip: visible));
      }
      elementPaths[symbol.id] = ArchitectMeshSection.unionPaths([
        if (elementPaths[symbol.id] != null) elementPaths[symbol.id]!,
        visible,
      ]);
    }
    final slopes = project == null
        ? <ArchitectElevationSlope>[]
        : ArchitectElevationSlope.build(project, view, elementPaths);
    var bounds = data.bounds;
    for (final slope in slopes) {
      final box = Rect.fromPoints(slope.start, slope.end).inflate(.25);
      bounds = bounds?.expandToInclude(box) ?? box;
    }
    return ArchitectBuildingElevation(
      faces,
      bounds ??
          Rect.fromLTWH(-view.length / 2, 0, math.max(.01, view.length), 3),
      elementPaths: elementPaths,
      operations: operations,
      slopes: slopes,
    );
  }

  /// Sutherland–Hodgman clipping against an affine half-space.
  static Rect _bounds2(List<Offset> p) {
    var b = Rect.fromPoints(p.first, p.first);
    for (final v in p.skip(1)) {
      b = b.expandToInclude(Rect.fromPoints(v, v));
    }
    return b;
  }

  static double _area2(List<Offset> polygon) {
    var area = 0.0;
    final origin = polygon.first;
    for (var i = 1; i + 1 < polygon.length; i++) {
      final a = polygon[i] - origin, b = polygon[i + 1] - origin;
      area += a.dx * b.dy - a.dy * b.dx;
    }
    return area;
  }

  static bool _hasArea(List<Offset> p) =>
      p.length >= 3 && _area2(p).abs() > 1e-14;

  static List<Vector3> _clip3(
    List<Vector3> input,
    double Function(Vector3) distance,
  ) {
    final output = <Vector3>[];
    if (input.isEmpty) return output;
    var previous = input.last;
    var dp = distance(previous);
    for (final current in input) {
      final dc = distance(current);
      if ((dc >= 0) != (dp >= 0)) {
        output.add(previous + (current - previous) * (dp / (dp - dc)));
      }
      if (dc >= 0) output.add(current);
      previous = current;
      dp = dc;
    }
    return output;
  }
}
