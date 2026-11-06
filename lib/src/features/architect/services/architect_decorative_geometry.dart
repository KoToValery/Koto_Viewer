// ============================================================================
// TABLE OF CONTENTS (grep: "=== SECTION:")
// 1. === SECTION: 2D CONTOUR & FRAME OFFSET BUILDERS ===
// 2. === SECTION: 3D SOLID EXTRUSION & 2-AXIS BOOLEAN INTERSECTION ===
// 3. === SECTION: HOST WALL & STOREY RESOLUTION (ELEVATION & SECTION) ===
// 4. === SECTION: PLAN FOOTPRINT & CLEARANCE HELPERS ===
// ============================================================================

import 'dart:math' as math;
import 'dart:ui';
import 'package:clipper2/clipper2.dart' as clip;
import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../models/architect_elevation.dart';
import '../models/architect_project.dart';
import '../models/architect_section.dart';
import '../models/architect_wall.dart';
import '../rendering/architect_mesh_boolean.dart';
import '../rendering/architect_path_solid.dart';
import 'architect_element_id.dart';

class ArchitectDecorativeGeometry {
  static final _localMeshCache = Expando<List<Triangle3D>>();

  // === SECTION: 2D CONTOUR & FRAME OFFSET BUILDERS ===

  /// Builds a boolean-clean 2D Path for the front silhouette `(u, z)`,
  /// including explicit holes and automatic frame inset if `frameWidth > 0`.
  static Path frontPath(ArchitectDecorativeElement element) {
    return _buildProfilePath(
      element.frontPolygon,
      element.frontHoles,
      frameInset: element.frameWidth,
    );
  }

  /// Builds a boolean-clean 2D Path for the side/section profile `(v, z)`.
  static Path sidePath(ArchitectDecorativeElement element) {
    return _buildProfilePath(element.sidePolygon, element.sideHoles);
  }

  static Path _buildProfilePath(
    List<Offset> outer,
    List<List<Offset>> holes, {
    double? frameInset,
  }) {
    if (outer.length < 3) return Path();
    final subjectLoop = [for (final p in outer) clip.PointD(p.dx, p.dy)];
    final normEngine = clip.ClipperD(roundingDecimalPrecision: 6)
      ..addSubject(subjectLoop);
    final normOuter = normEngine.executeClosed(
      clip.ClipType.union,
      clip.FillRule.nonZero,
    );
    if (normOuter == null || normOuter.isEmpty) return Path();

    final clipLoops = <List<clip.PointD>>[];
    for (final hole in holes) {
      if (hole.length >= 3) {
        clipLoops.add([for (final p in hole) clip.PointD(p.dx, p.dy)]);
      }
    }

    if (frameInset != null && frameInset > 1e-4 && clipLoops.isEmpty) {
      for (final outerLoop in normOuter) {
        final insetLoop = _insetLoop(outerLoop, frameInset);
        if (insetLoop != null && insetLoop.length >= 3) {
          clipLoops.add(insetLoop);
        }
      }
    }

    List<List<clip.PointD>> finalContours = normOuter;
    if (clipLoops.isNotEmpty) {
      final diffEngine = clip.ClipperD(roundingDecimalPrecision: 6)
        ..addSubjects(normOuter)
        ..addClips(clipLoops);
      final diff = diffEngine.executeClosed(
        clip.ClipType.difference,
        clip.FillRule.nonZero,
      );
      if (diff != null && diff.isNotEmpty) {
        finalContours = diff;
      }
    }

    final result = Path()..fillType = PathFillType.evenOdd;
    for (final loop in finalContours) {
      if (loop.length >= 3) {
        result.addPolygon([for (final p in loop) Offset(p.x, p.y)], true);
      }
    }
    return result;
  }

  /// Computes an inward offset polygon loop by [inset] metres.
  static List<clip.PointD>? _insetLoop(List<clip.PointD> loop, double inset) {
    final n = loop.length;
    if (n < 3 || inset <= 1e-5) return null;
    var signedArea2 = 0.0;
    var minX = loop.first.x, maxX = loop.first.x;
    var minY = loop.first.y, maxY = loop.first.y;
    for (var i = 0; i < n; i++) {
      final a = loop[i];
      final b = loop[(i + 1) % n];
      signedArea2 += a.x * b.y - b.x * a.y;
      if (a.x < minX) minX = a.x;
      if (a.x > maxX) maxX = a.x;
      if (a.y < minY) minY = a.y;
      if (a.y > maxY) maxY = a.y;
    }
    if ((maxX - minX) <= inset * 2.02 ||
        (maxY - minY) <= inset * 2.02 ||
        signedArea2.abs() < 1e-6) {
      return null;
    }
    final sign = signedArea2 >= 0 ? 1.0 : -1.0;
    final dirs = <Offset>[];
    final shiftedPts = <Offset>[];
    for (var i = 0; i < n; i++) {
      final a = Offset(loop[i].x, loop[i].y);
      final b = Offset(loop[(i + 1) % n].x, loop[(i + 1) % n].y);
      final ab = b - a;
      final len = ab.distance;
      final d = len > 1e-8 ? ab / len : const Offset(1, 0);
      final inNormal = Offset(-d.dy * sign, d.dx * sign);
      dirs.add(d);
      shiftedPts.add(a + inNormal * inset);
    }

    final result = <clip.PointD>[];
    for (var i = 0; i < n; i++) {
      final prev = (i - 1 + n) % n;
      final p1 = shiftedPts[prev];
      final d1 = dirs[prev];
      final p2 = shiftedPts[i];
      final d2 = dirs[i];
      final cross = d1.dx * d2.dy - d1.dy * d2.dx;
      Offset pt;
      if (cross.abs() > 1e-5) {
        final delta = p2 - p1;
        final t = (delta.dx * d2.dy - delta.dy * d2.dx) / cross;
        pt = p1 + d1 * t;
        final orig = Offset(loop[i].x, loop[i].y);
        if ((pt - orig).distance > inset * 3.0) {
          pt = orig + (pt - orig) / (pt - orig).distance * (inset * 3.0);
        }
      } else {
        pt = p2;
      }
      result.add(clip.PointD(pt.dx, pt.dy));
    }
    return result;
  }

  static bool _isSimpleRectangle(
    List<Offset> poly,
    List<List<Offset>> holes,
    double? frameWidth,
  ) {
    if (holes.isNotEmpty || (frameWidth != null && frameWidth > 1e-4)) {
      return false;
    }
    if (poly.length != 4) return false;
    var minX = poly.first.dx, maxX = poly.first.dx;
    var minY = poly.first.dy, maxY = poly.first.dy;
    for (final p in poly) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    for (final p in poly) {
      final onX = (p.dx - minX).abs() < 1e-4 || (p.dx - maxX).abs() < 1e-4;
      final onY = (p.dy - minY).abs() < 1e-4 || (p.dy - maxY).abs() < 1e-4;
      if (!onX || !onY) return false;
    }
    return true;
  }

  // === SECTION: 3D SOLID EXTRUSION & 2-AXIS BOOLEAN INTERSECTION ===

  /// Builds the 3D mesh in local `(u, v, z)` right-handed coordinates where:
  /// - `x = u` in `[0, width]`
  /// - `y = v` in `[0, depth]`
  /// - `z = z` in `[0, height]`
  static List<Triangle3D> buildLocalMesh(ArchitectDecorativeElement element) {
    final cached = _localMeshCache[element];
    if (cached != null) return cached;

    final color = element.effectiveColor;
    final frontSimple = _isSimpleRectangle(
      element.frontPolygon,
      element.frontHoles,
      element.frameWidth,
    );
    final sideSimple = _isSimpleRectangle(
      element.sidePolygon,
      element.sideHoles,
      null,
    );

    List<Triangle3D> buildFrontExtrusion() {
      final fPath = frontPath(element);
      if (fPath.getBounds().isEmpty) return const [];
      final d = element.effectiveDepth;
      // Extrude fPath(u, z) along w in [0, d].
      // Map (x_p = u, y_p = z, z_p = v) -> local (u, v, z):
      // Det of (u, z, v) -> (u, v, z) is -1, so swap v1 and v2 for outward normals.
      final raw = ArchitectPathSolid.extrude(fPath, 0, d, color);
      Vector3 mapPt(Vector3 p) => Vector3(p.x, p.z, p.y);
      return [
        for (final t in raw)
          Triangle3D(
            v0: mapPt(t.v0),
            v1: mapPt(t.v2),
            v2: mapPt(t.v1),
            color: color,
          ),
      ];
    }

    List<Triangle3D> buildSideExtrusion() {
      final sPath = sidePath(element);
      if (sPath.getBounds().isEmpty) return const [];
      final w = element.width;
      // Extrude sPath(v, z) along w in [0, width].
      // Map (x_p = v, y_p = z, z_p = u) -> local (u, v, z):
      // Det of [ (0,1,0), (0,0,1), (1,0,0) ] is +1, so keep winding!
      final raw = ArchitectPathSolid.extrude(sPath, 0, w, color);
      Vector3 mapPt(Vector3 p) => Vector3(p.z, p.x, p.y);
      return [
        for (final t in raw)
          Triangle3D(
            v0: mapPt(t.v0),
            v1: mapPt(t.v1),
            v2: mapPt(t.v2),
            color: color,
          ),
      ];
    }

    final List<Triangle3D> result;
    if (sideSimple && !frontSimple) {
      result = buildFrontExtrusion();
    } else if (frontSimple && !sideSimple) {
      result = buildSideExtrusion();
    } else if (frontSimple && sideSimple) {
      result = buildFrontExtrusion();
    } else {
      // Both front and side profiles have custom shapes/holes:
      // Compute exact 3D boolean intersection of the two orthogonal extrusions!
      final a = buildFrontExtrusion();
      final b = buildSideExtrusion();
      if (a.isEmpty) {
        result = b;
      } else if (b.isEmpty) {
        result = a;
      } else {
        final intersected = ArchitectMeshBoolean.intersect(a, b);
        result = intersected.isNotEmpty ? intersected : a;
      }
    }

    return _localMeshCache[element] = List.unmodifiable(result);
  }

  /// Builds the world-space 3D mesh for [element] on [storey].
  static List<Triangle3D> buildWorldMesh(
    ArchitectProject project,
    ArchitectStorey storey,
    ArchitectDecorativeElement element,
  ) {
    final local = buildLocalMesh(element);
    if (local.isEmpty) return const [];

    final tLen = element.tangent.distance;
    final nLen = element.normal.distance;
    final t = tLen > 1e-6 ? element.tangent / tLen : const Offset(1, 0);
    final n = nLen > 1e-6 ? element.normal / nLen : Offset(-t.dy, t.dx);
    final zBase = storey.elevation + element.baseOffset;
    final vShift = element.normalOffset;

    // Basis determinant in XY: t.dx * n.dy - t.dy * n.dx
    final flipWinding = (t.dx * n.dy - t.dy * n.dx) < 0;
    final color = element.effectiveColor;

    Vector3 toWorld(Vector3 p) {
      final u = p.x;
      final v = p.y + vShift;
      return Vector3(
        element.origin.dx + u * t.dx + v * n.dx,
        element.origin.dy + u * t.dy + v * n.dy,
        zBase + p.z,
      );
    }

    return [
      for (final tri in local)
        Triangle3D(
          v0: toWorld(tri.v0),
          v1: toWorld(flipWinding ? tri.v2 : tri.v1),
          v2: toWorld(flipWinding ? tri.v1 : tri.v2),
          color: color,
        ),
    ];
  }

  // === SECTION: HOST WALL & STOREY RESOLUTION (ELEVATION & SECTION) ===

  /// Resolves the best parent storey for a vertical elevation `z` (in metres).
  static ArchitectStorey resolveStoreyForElevation(
    ArchitectProject project,
    double z,
  ) {
    final normalStoreys = project.storeys.where((s) => !s.isRoof).toList()
      ..sort((a, b) => a.elevation.compareTo(b.elevation));
    if (normalStoreys.isEmpty) return project.activeStorey;
    for (var i = normalStoreys.length - 1; i >= 0; i--) {
      if (z >= normalStoreys[i].elevation - 0.15) {
        return normalStoreys[i];
      }
    }
    return normalStoreys.first;
  }

  /// Creates an [ArchitectDecorativeElement] from a 2D contour drawn in an
  /// Elevation (Facade) view, snapping automatically to the underlying wall's
  /// outer surface if present.
  static ({
    ArchitectStorey storey,
    String storeyId,
    ArchitectDecorativeElement element,
  })
  createFromElevation({
    required ArchitectProject project,
    ArchitectElevation? view,
    Offset? viewOrigin,
    Offset? viewRight,
    Offset? viewInward,
    required List<Offset> viewContour,
    List<List<Offset>> viewHoles = const [],
    double depth = 0.05,
    double? frameWidth,
    double normalOffset = 0.0,
    ArchitectDecorativeMaterial material = ArchitectDecorativeMaterial.eps,
    bool showOnPlan = false,
    String? id,
    String name = '',
  }) {
    var minX = viewContour.first.dx, maxX = viewContour.first.dx;
    var minZ = viewContour.first.dy, maxZ = viewContour.first.dy;
    for (final p in viewContour) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minZ) minZ = p.dy;
      if (p.dy > maxZ) maxZ = p.dy;
    }
    final midX = (minX + maxX) / 2;
    final midZ = (minZ + maxZ) / 2;
    final storey = resolveStoreyForElevation(project, midZ);

    final originRef = view?.centre ?? viewOrigin ?? Offset.zero;
    final right = view?.right ?? viewRight ?? const Offset(1, 0);
    final inward =
        view?.viewDirection ?? viewInward ?? Offset(-right.dy, right.dx);
    // Outward normal facing the elevation viewer (opposite to inward viewDirection)
    final outNormal = -inward;

    // Find the closest visible wall facing this elevation near (midX, midZ)
    ArchitectWall? bestWall;
    double? bestDepthAlongView;
    Offset bestWallOutNormal = outNormal;
    for (final st in [
      storey,
      ...project.storeys.where((s) => s.id != storey.id),
    ]) {
      for (final wall in st.walls) {
        final zBottom = st.elevation + wall.baseOffset;
        final zTop = zBottom + wall.effectiveHeight(st.height);
        if (midZ < zBottom - 0.5 || midZ > zTop + 1.0) continue;

        final align =
            (wall.unitVector.dx * right.dx + wall.unitVector.dy * right.dy)
                .abs();
        if (align < 0.75) continue;

        final xStart =
            (wall.centerStart - originRef).dx * right.dx +
            (wall.centerStart - originRef).dy * right.dy;
        final xEnd =
            (wall.centerEnd - originRef).dx * right.dx +
            (wall.centerEnd - originRef).dy * right.dy;
        final wLeft = math.min(xStart, xEnd) - 0.30;
        final wRight = math.max(xStart, xEnd) + 0.30;
        if (midX < wLeft || midX > wRight) continue;

        final wallMid = (wall.centerStart + wall.centerEnd) / 2;
        final distIntoView =
            (wallMid - originRef).dx * inward.dx +
            (wallMid - originRef).dy * inward.dy;
        if (distIntoView < -0.5) continue;
        if (view?.viewDepth != null && distIntoView > view!.viewDepth! + 0.5) {
          continue;
        }
        if (bestDepthAlongView == null || distIntoView < bestDepthAlongView) {
          bestDepthAlongView = distIntoView;
          bestWall = wall;
          final dotN =
              wall.normalVector.dx * outNormal.dx +
              wall.normalVector.dy * outNormal.dy;
          bestWallOutNormal = dotN >= 0
              ? wall.normalVector
              : -wall.normalVector;
        }
      }
      if (bestWall != null) break;
    }

    Offset originPlan;
    Offset tangent = right;
    Offset normal = outNormal;
    int hostSide = 1;

    if (bestWall != null) {
      // Align tangent with elevation right along the wall, and place origin
      // directly on the outer surface of the wall facing the viewer.
      final wallDir = bestWall.unitVector;
      final dotRight = wallDir.dx * right.dx + wallDir.dy * right.dy;
      tangent = dotRight >= 0 ? wallDir : -wallDir;
      normal = bestWallOutNormal;
      hostSide =
          (bestWall.normalVector.dx * normal.dx +
                  bestWall.normalVector.dy * normal.dy) >=
              0
          ? 1
          : -1;
      final centerAtMinX =
          originRef + right * minX + inward * (bestDepthAlongView ?? 0.0);
      // Project centerAtMinX onto the wall's centerline, then offset to outer face
      final alongWall =
          (centerAtMinX - bestWall.centerStart).dx * bestWall.unitVector.dx +
          (centerAtMinX - bestWall.centerStart).dy * bestWall.unitVector.dy;
      final onCenterline =
          bestWall.centerStart + bestWall.unitVector * alongWall;
      final outerOffset = _wallOuterOffsetToward(bestWall, normal);
      originPlan = onCenterline + normal * outerOffset;
    } else {
      originPlan = originRef + right * minX;
    }

    final localContour = [
      for (final p in viewContour) Offset(p.dx - minX, p.dy - minZ),
    ];
    final localHoles = [
      for (final hole in viewHoles)
        [for (final p in hole) Offset(p.dx - minX, p.dy - minZ)],
    ];

    final element = ArchitectDecorativeElement.fromFacadeContour(
      id: id ?? ArchitectElementId.next('decor'),
      name: name,
      contour: localContour,
      holes: localHoles,
      origin: originPlan,
      tangent: tangent,
      normal: normal,
      baseOffset: minZ - storey.elevation,
      normalOffset: normalOffset,
      depth: depth,
      frameWidth: frameWidth,
      hostWallId: bestWall?.id,
      hostWallSide: hostSide,
      material: material,
      showOnPlan: showOnPlan,
    );
    return (storey: storey, storeyId: storey.id, element: element);
  }

  /// Creates an [ArchitectDecorativeElement] from a 2D cross-section profile
  /// drawn in a Section view, snapping to the nearest sliced wall/eave.
  static ({
    ArchitectStorey storey,
    String storeyId,
    ArchitectDecorativeElement element,
  })
  createFromSection({
    required ArchitectProject project,
    ArchitectSection? cut,
    Offset? sectionOrigin,
    Offset? sectionRight,
    List<Offset>? sectionProfile,
    List<Offset>? viewProfile,
    List<List<Offset>> sectionHoles = const [],
    double spanLength = 1.0,
    double? frameWidth,
    double normalOffset = 0.0,
    ArchitectDecorativeMaterial material = ArchitectDecorativeMaterial.eps,
    bool showOnPlan = false,
    String? id,
    String name = '',
  }) {
    final profilePts = sectionProfile ?? viewProfile ?? const <Offset>[];
    var minS = profilePts.first.dx, maxS = profilePts.first.dx;
    var minZ = profilePts.first.dy, maxZ = profilePts.first.dy;
    for (final p in profilePts) {
      if (p.dx < minS) minS = p.dx;
      if (p.dx > maxS) maxS = p.dx;
      if (p.dy < minZ) minZ = p.dy;
      if (p.dy > maxZ) maxZ = p.dy;
    }
    final midS = (minS + maxS) / 2;
    final midZ = (minZ + maxZ) / 2;
    final storey = resolveStoreyForElevation(project, midZ);

    // Section view horizontal axis is cut.drawingRight (from cut.drawingOrigin)
    final secOrigin = cut?.drawingOrigin ?? sectionOrigin ?? Offset.zero;
    final secRight = cut?.drawingRight ?? sectionRight ?? const Offset(1, 0);
    final pointOnCut = secOrigin + secRight * minS;

    // Look for a wall intersected by the section near midS
    ArchitectWall? bestWall;
    var bestDist = 1.20;
    final midPointOnCut = secOrigin + secRight * midS;
    for (final st in [
      storey,
      ...project.storeys.where((s) => s.id != storey.id),
    ]) {
      for (final wall in st.walls) {
        final d = _distPointToSegment(
          midPointOnCut,
          wall.centerStart,
          wall.centerEnd,
        );
        if (d < bestDist) {
          bestDist = d;
          bestWall = wall;
        }
      }
    }

    // In a section view, the drawn profile lies in the section plane:
    // +V (normal) is along secRight, and +U (tangent / extrusion length) is
    // perpendicular to the section plane so it runs along the intersected facade!
    Offset normal = secRight;
    Offset tangent = Offset(secRight.dy, -secRight.dx);
    int hostSide = 1;

    if (bestWall != null) {
      final dotWall =
          bestWall.unitVector.dx * tangent.dx +
          bestWall.unitVector.dy * tangent.dy;
      if (dotWall.abs() > 0.5) {
        tangent = dotWall >= 0 ? bestWall.unitVector : -bestWall.unitVector;
      }
      hostSide =
          (bestWall.normalVector.dx * normal.dx +
                  bestWall.normalVector.dy * normal.dy) >=
              0
          ? 1
          : -1;
    }

    // Center the initial extrusion span across the section cut line so the
    // element is immediately cut by the section AND visible on the facade!
    final originPlan = pointOnCut - tangent * (spanLength / 2.0);
    final localProfile = [
      for (final p in profilePts) Offset(p.dx - minS, p.dy - minZ),
    ];
    final localHoles = [
      for (final hole in sectionHoles)
        [for (final p in hole) Offset(p.dx - minS, p.dy - minZ)],
    ];

    final element = ArchitectDecorativeElement.fromSectionProfile(
      id: id ?? ArchitectElementId.next('decor'),
      name: name,
      profile: localProfile,
      holes: localHoles,
      origin: originPlan,
      tangent: tangent,
      normal: normal,
      baseOffset: minZ - storey.elevation,
      normalOffset: normalOffset,
      spanLength: spanLength,
      hostWallId: bestWall?.id,
      hostWallSide: hostSide,
      material: material,
      showOnPlan: showOnPlan,
    ).copyWith(frameWidth: frameWidth);
    return (storey: storey, storeyId: storey.id, element: element);
  }

  static double _wallOuterOffsetToward(ArchitectWall wall, Offset outNormal) {
    final resolved = wall.resolvedLayers;
    if (resolved.isEmpty) return wall.thickness / 2.0;
    final total = resolved.fold<double>(0.0, (a, l) => a + l.thickness);
    return math.max(wall.thickness, total) / 2.0;
  }

  static double _distPointToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 < 1e-10) return (p - a).distance;
    final t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2;
    final proj = a + ab * t.clamp(0.0, 1.0);
    return (p - proj).distance;
  }

  // === SECTION: PLAN FOOTPRINT & CLEARANCE HELPERS ===

  /// Returns the 2D quadrilateral footprint of [element] in Plan coordinates `(X, Y)`.
  static List<Offset> planFootprint(ArchitectDecorativeElement element) {
    final tLen = element.tangent.distance;
    final nLen = element.normal.distance;
    final t = tLen > 1e-6 ? element.tangent / tLen : const Offset(1, 0);
    final n = nLen > 1e-6 ? element.normal / nLen : Offset(-t.dy, t.dx);
    final fb = element.frontBounds;
    final sb = element.sideBounds;
    final u0 = fb.left, u1 = fb.right;
    final v0 = element.normalOffset + sb.left;
    final v1 = element.normalOffset + sb.right;
    Offset pt(double u, double v) => element.origin + t * u + n * v;
    return [pt(u0, v0), pt(u1, v0), pt(u1, v1), pt(u0, v1)];
  }

  /// Returns the 2D closed [Path] footprint of [element] in Plan coordinates `(X, Y)`.
  static Path planFootprintPath(ArchitectDecorativeElement element) {
    final pts = planFootprint(element);
    if (pts.length < 3) return Path();
    return Path()..addPolygon(pts, true);
  }

  /// Projects [element]'s bounding box into a view defined by `(origin, right)`.
  static Rect viewBounds(
    ArchitectStorey storey,
    ArchitectDecorativeElement element,
    Offset viewOrigin,
    Offset viewRight,
  ) {
    final corners = planFootprint(element);
    var minX = double.infinity, maxX = -double.infinity;
    for (final c in corners) {
      final d = c - viewOrigin;
      final x = d.dx * viewRight.dx + d.dy * viewRight.dy;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
    }
    final zBottom =
        storey.elevation + element.baseOffset + element.frontBounds.top;
    final zTop = zBottom + element.height;
    return Rect.fromLTRB(minX, zBottom, maxX, zTop);
  }
}
