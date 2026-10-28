import 'package:clipper2/clipper2.dart' as clip;
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
              ? Path.combine(PathOperation.union, paths[e.key]!, e.value)
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
    final groups = <String, _ElevationPlane>{};
    final cutMasks = [
      for (final mask in occlusionMasks)
        if (_hasArea(mask)) (mask, _bounds2(mask)),
    ];
    final right = view.right, forward = view.viewDirection;
    Vector3 projectVector(Vector3 v) {
      final p = Offset(v.x, v.y) - view.centre;
      return Vector3(
        p.dx * right.dx + p.dy * right.dy,
        v.z,
        p.dx * forward.dx + p.dy * forward.dy,
      );
    }

    for (final triangle in triangles) {
      final a = projectVector(triangle.v0),
          b = projectVector(triangle.v1),
          c = projectVector(triangle.v2);
      final normal = (b - a).cross(c - a);
      // Edge-on faces have no projected area.
      if (normal.z.abs() < 1e-10) continue;
      final u = -normal.x / normal.z, v = -normal.y / normal.z;
      final w = a.z - u * a.x - v * a.y;
      var polygon = _clip3([a, b, c], (p) => p.z);
      if (view.viewDepth != null) {
        polygon = _clip3(polygon, (p) => view.viewDepth! - p.z);
      }
      polygon = _clip3(polygon, (p) => p.x + view.length / 2);
      polygon = _clip3(polygon, (p) => view.length / 2 - p.x);
      if (polygon.length < 3) continue;
      final path = Path()
        ..addPolygon([for (final p in polygon) Offset(p.x, p.y)], true);
      if (path.getBounds().isEmpty) continue;
      // Keep material boundaries (e.g. a flush window frame) while removing
      // triangle edges and construction seams within one finish.
      final key =
          '${(u * 1e6).round()}:${(v * 1e6).round()}:${(w * 1e6).round()}:${triangle.color?.toARGB32()}:${silhouetteGroups[triangle] ?? ''}';
      final plane = groups[key];
      if (plane == null) {
        groups[key] = _ElevationPlane(
          u,
          v,
          w,
          path,
          silhouette: silhouetteGroups[triangle],
        );
      } else {
        plane.path = Path()
          ..addPath(plane.path, Offset.zero)
          ..addPath(path, Offset.zero);
      }
      final id = sources[triangle];
      groups[key]!.pieces.add((
        points: [for (final p in polygon) Offset(p.x, p.y)],
        source: id,
      ));
      if (id != null) {
        final group = groups[key]!;
        group.sources[id] = group.sources.containsKey(id)
            ? (Path()
                ..addPath(group.sources[id]!, Offset.zero)
                ..addPath(path, Offset.zero))
            : path;
      }
    }
    // Curved drainage creates many small surface planes. Query projected
    // neighbours instead of comparing every tube facet with the whole model.
    final occluders = _ElevationOcclusionIndex(groups.values.toList());
    final faces = <Path>[];
    final silhouettes = <String, List<List<clip.PointD>>>{};
    Rect? bounds;
    final elementPaths = <String, Path>{};
    Path visiblePart(
      _ElevationPlane face, {
      String? ignoreSource,
      String? onlySource,
      List<List<clip.PointD>>? contoursOut,
    }) {
      final subjects = [
        for (final p in face.pieces)
          if (onlySource == null || p.source == onlySource) p.points,
      ];
      if (subjects.isEmpty) return Path();
      final box = face.path.getBounds();
      final masks = <List<Offset>>[];
      for (final other in occluders.overlapping(box)) {
        if (identical(face, other) || !box.overlaps(other.path.getBounds())) {
          continue;
        }
        // A closed component's projected union already is its silhouette.
        // Masking its own coplanar BSP fragments only creates numerical seams.
        if (face.silhouette != null && face.silhouette == other.silhouette) {
          continue;
        }
        for (final piece in other.pieces) {
          if (ignoreSource != null && piece.source == ignoreSource) continue;
          final mask = _clip2(
            piece.points,
            (p) => face.depth(p.dx, p.dy) - other.depth(p.dx, p.dy) - 1e-7,
          );
          if (_hasArea(mask) && box.overlaps(_bounds2(mask))) masks.add(mask);
        }
      }
      for (final (mask, bounds) in cutMasks) {
        if (box.overlaps(bounds)) masks.add(mask);
      }
      // Perform the complete union/difference before encoding any Flutter Path.
      // Clipper uses integer coordinates internally (10 nm in model metres),
      // so nearly coincident roof edges cannot corrupt intermediate contours.
      List<clip.PointD> points(List<Offset> p) => [
        for (final v in _area2(p) < 0 ? p.reversed : p) clip.PointD(v.dx, v.dy),
      ];
      final engine = clip.ClipperD(roundingDecimalPrecision: 8)
        ..preserveCollinear = false
        ..addSubjects([
          for (final p in subjects)
            if (_hasArea(p)) points(p),
        ])
        ..addClips([for (final p in masks) points(p)]);
      final contours = engine.executeClosed(
        clip.ClipType.difference,
        clip.FillRule.nonZero,
      );
      if (contours == null) {
        throw StateError('Architectural visibility clipping failed');
      }
      contoursOut?.addAll(contours);
      final path = Path();
      for (final contour in contours) {
        path.addPolygon([for (final p in contour) Offset(p.x, p.y)], true);
      }
      return path;
    }

    for (final face in groups.values) {
      final contours = face.silhouette == null
          ? null
          : (silhouettes[face.silhouette!] ??= <List<clip.PointD>>[]);
      final visible = visiblePart(face, contoursOut: contours);
      if (visible.getBounds().isEmpty) continue;
      if (face.silhouette == null) faces.add(visible);
      for (final entry in face.sources.entries) {
        final hit = face.sources.length == 1
            ? visible
            : visiblePart(face, onlySource: entry.key);
        if (hit.getBounds().isEmpty) continue;
        elementPaths[entry.key] = elementPaths.containsKey(entry.key)
            ? (Path()
                ..addPath(elementPaths[entry.key]!, Offset.zero)
                ..addPath(hit, Offset.zero))
            : hit;
      }
      bounds =
          bounds?.expandToInclude(visible.getBounds()) ?? visible.getBounds();
    }
    // A drawing needs the visible silhouette, not every longitudinal facet,
    // socket, or inner wall of the 3D tube. Keep depth clipping/occlusion above,
    // then unite the visible material before encoding the published contour.
    for (final entry in silhouettes.entries) {
      final contours = entry.value;
      if (contours.isEmpty) continue;
      final engine = clip.ClipperD(roundingDecimalPrecision: 8)
        ..preserveCollinear = false
        ..addSubjects(contours);
      var united = engine.executeClosed(
        clip.ClipType.union,
        clip.FillRule.nonZero,
      );
      if (united == null) throw StateError('Drainage silhouette union failed');
      if (entry.key.startsWith('construction:')) {
        // Weld projection seams below 0.01 mm. This is far below drawing
        // precision and preserves the explicit courses and opening contours.
        united = clip.Clipper.inflatePathsD(
          paths: united,
          delta: .00001,
          joinType: clip.JoinType.miter,
          endType: clip.EndType.polygon,
          precision: 7,
        );
        united = clip.Clipper.inflatePathsD(
          paths: united,
          delta: -.00001,
          joinType: clip.JoinType.miter,
          endType: clip.EndType.polygon,
          precision: 7,
        );
      }
      final outline = Path();
      for (final polygon in united) {
        outline.addPolygon([for (final p in polygon) Offset(p.x, p.y)], true);
      }
      if (!outline.getBounds().isEmpty) faces.add(outline);
    }
    final operations = <({Path lines, Path clip})>[];
    if (project != null) {
      for (final operation in ArchitectElevationOperation.build(
        project,
        view,
        excludedOpeningIds: suppressedOpeningIds,
      )) {
        final a = operation.aperture[0], b = operation.aperture[1];
        if ((b.x - a.x).abs() < 1e-6) continue;
        final u = (b.z - a.z) / (b.x - a.x);
        var polygon = _clip3(operation.aperture, (p) => p.z);
        if (view.viewDepth != null) {
          polygon = _clip3(polygon, (p) => view.viewDepth! - p.z);
        }
        polygon = _clip3(polygon, (p) => p.x + view.length / 2);
        polygon = _clip3(polygon, (p) => view.length / 2 - p.x);
        if (polygon.length < 3) continue;
        final plane = _ElevationPlane(
          u,
          0,
          a.z - u * a.x,
          Path()..addPolygon([for (final p in polygon) Offset(p.x, p.y)], true),
        );
        plane.pieces.add((
          points: [for (final p in polygon) Offset(p.x, p.y)],
          source: operation.id,
        ));
        final visible = visiblePart(plane, ignoreSource: operation.id);
        if (!visible.getBounds().isEmpty) {
          final detailLevel =
              openingDetailLevels[operation.id] ??
              FenestrationElevationDetail.clean2D;
          if (detailLevel != FenestrationElevationDetail.outerContourOnly &&
              detailLevel != FenestrationElevationDetail.hidden) {
            operations.add((lines: operation.lines, clip: visible));
          }
          // Empty apertures of open doors remain selectable, but a foreground
          // solid still masks them just like the operation indication.
          elementPaths[operation.id] = elementPaths.containsKey(operation.id)
              ? (Path()
                  ..addPath(elementPaths[operation.id]!, Offset.zero)
                  ..addPath(visible, Offset.zero))
              : visible;
        }
      }
    }
    final slopes = project == null
        ? <ArchitectElevationSlope>[]
        : ArchitectElevationSlope.build(project, view, elementPaths);
    for (final slope in slopes) {
      final arrowBounds = Rect.fromPoints(slope.start, slope.end).inflate(.25);
      bounds = bounds?.expandToInclude(arrowBounds) ?? arrowBounds;
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

  static List<Offset> _clip2(
    List<Offset> input,
    double Function(Offset) distance,
  ) {
    if (input.isEmpty) return [];
    final result = <Offset>[];
    var previous = input.last, dp = distance(input.last);
    for (final current in input) {
      final dc = distance(current);
      if ((dp >= 0) != (dc >= 0)) {
        result.add(previous + (current - previous) * (dp / (dp - dc)));
      }
      if (dc >= 0) result.add(current);
      previous = current;
      dp = dc;
    }
    return result;
  }

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

class _ElevationPlane {
  final double u, v, w;
  final String? silhouette;
  Path path;
  final sources = <String, Path>{};
  final pieces = <({List<Offset> points, String? source})>[];
  _ElevationPlane(this.u, this.v, this.w, this.path, {this.silhouette});
  double depth(double x, double z) => u * x + v * z + w;
}

class _ElevationOcclusionIndex {
  late final Rect bounds;
  late final List<_ElevationPlane> leaves;
  _ElevationOcclusionIndex? left, right;
  _ElevationOcclusionIndex(List<_ElevationPlane> faces) {
    final boxes = {for (final face in faces) face: face.path.getBounds()};
    bounds = boxes.values.fold<Rect?>(null, (a, b) => a?.expandToInclude(b) ?? b) ?? Rect.zero;
    if (faces.length <= 8) {
      leaves = faces;
      return;
    }
    leaves = const [];
    final horizontal = bounds.width >= bounds.height;
    faces.sort((a, b) => (horizontal ? boxes[a]!.center.dx : boxes[a]!.center.dy)
      .compareTo(horizontal ? boxes[b]!.center.dx : boxes[b]!.center.dy));
    final mid = faces.length ~/ 2;
    left = _ElevationOcclusionIndex(faces.sublist(0, mid));
    right = _ElevationOcclusionIndex(faces.sublist(mid));
  }
  Iterable<_ElevationPlane> overlapping(Rect box) sync* {
    if (!bounds.overlaps(box)) return;
    for (final face in leaves) {
      if (face.path.getBounds().overlaps(box)) yield face;
    }
    if (left != null) yield* left!.overlapping(box);
    if (right != null) yield* right!.overlapping(box);
  }
}
