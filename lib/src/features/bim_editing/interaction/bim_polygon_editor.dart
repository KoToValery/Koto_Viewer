// === SECTION: ARCHITECT POLYGON CONTROLLER & OFFSET HANDLES ===
import 'dart:ui';

import '../geometry/bim_polygon_geometry.dart';

/// Gesture controller for contours, rectangles, and volumetric slabs.
/// Supports direct handles and ergonomic offset leader handles (изнесена линия с точка).
class BimPolygonEditor<TSnap> {
  BimPolygonEditor({required this.pointOf, required this.isSnapped});
  final Offset Function(TSnap) pointOf;
  final bool Function(TSnap) isSnapped;
  String? elementId;
  List<Offset>? original, preview;
  int? index;
  bool edge = false, invalid = false;
  TSnap? activeSnap;
  Offset grabOffset = Offset.zero;

  // Offset handle leader state
  bool isOffsetHandle = false;
  Offset? leaderOrigin;
  Offset? leaderTarget;
  Offset? editedPoint;
  Offset _handleDisplacement = Offset.zero;
  BimPolygonEdgeMode edgeMode = BimPolygonEdgeMode.pull;

  bool get active => elementId != null;

  bool startVertex(String id, List<Offset> polygon, int vertex) {
    if (vertex < 0 ||
        vertex >= polygon.length ||
        !BimPolygonGeometry.valid(polygon)) {
      return false;
    }
    cancel();
    elementId = id;
    original = List.unmodifiable(polygon);
    preview = List.of(polygon);
    index = vertex;
    edge = false;
    grabOffset = Offset.zero;
    leaderOrigin = polygon[vertex];
    editedPoint = polygon[vertex];
    return true;
  }

  /// Live leader line connecting the actual moving contour point
  /// to the offset handle under the user's finger.
  (Offset, Offset)? get leaderLine {
    if (!active || preview == null || index == null || !isOffsetHandle) {
      return null;
    }
    final moving = editedPoint;
    if (moving == null) return null;
    return leaderTarget != null ? (moving, leaderTarget!) : null;
  }

  static Offset vertexNormal(List<Offset> polygon, int i) {
    final len = polygon.length;
    final prev = BimPolygonGeometry.normal(polygon, (i - 1 + len) % len);
    final curr = BimPolygonGeometry.normal(polygon, i);
    final bisector = prev + curr;
    if (bisector.distance > 1e-6) {
      return bisector / bisector.distance;
    }
    return curr;
  }

  static Offset offsetVertexHandle(List<Offset> polygon, int i, double scale) {
    final clearance = 30.0 / scale;
    return polygon[i] + vertexNormal(polygon, i) * clearance;
  }

  static Offset offsetEdgeHandle(List<Offset> polygon, int i, double scale) {
    final clearance = 30.0 / scale;
    final mid = (polygon[i] + polygon[(i + 1) % polygon.length]) / 2;
    return mid + BimPolygonGeometry.normal(polygon, i) * clearance;
  }

  bool startEdge(
    String id,
    List<Offset> polygon,
    int selectedEdge,
    Offset raw,
    double scale, {
    BimPolygonEdgeMode mode = BimPolygonEdgeMode.move,
  }) {
    if (selectedEdge < 0 || selectedEdge >= polygon.length) return false;
    final midpoint =
        (polygon[selectedEdge] + polygon[(selectedEdge + 1) % polygon.length]) /
        2;
    if (!start(id, polygon, midpoint, scale, mode: mode)) return false;
    index = selectedEdge;
    edge = true;
    isOffsetHandle = false;
    grabOffset = midpoint - raw;
    leaderOrigin = midpoint;
    editedPoint = midpoint;
    _handleDisplacement = Offset.zero;
    return true;
  }

  bool start(
    String id,
    List<Offset> polygon,
    Offset raw,
    double scale, {
    BimPolygonEdgeMode mode = BimPolygonEdgeMode.pull,
  }) {
    if (!BimPolygonGeometry.valid(polygon)) return false;
    final directRadius = 18.0 / scale;
    final offsetRadius = 24.0 / scale;
    final proximityRadius = 48.0 / scale;

    int? hit;
    var best = directRadius;
    var hitIsEdge = false;
    var hitIsOffset = false;
    Offset? chosenHandle;

    // 1. Direct vertex check
    for (var i = 0; i < polygon.length; i++) {
      final d = (raw - polygon[i]).distance;
      if (d < best) {
        hit = i;
        best = d;
        hitIsEdge = false;
        hitIsOffset = false;
        chosenHandle = polygon[i];
      }
    }

    // 2. Direct edge midpoint check
    for (var i = 0; i < polygon.length; i++) {
      final p = (polygon[i] + polygon[(i + 1) % polygon.length]) / 2;
      final d = (raw - p).distance;
      if (d < best - 1e-9) {
        hit = i;
        best = d;
        hitIsEdge = true;
        hitIsOffset = false;
        chosenHandle = p;
      }
    }

    // 3. Offset vertex handle check (outward leader handles)
    for (var i = 0; i < polygon.length; i++) {
      final h = offsetVertexHandle(polygon, i, scale);
      final d = (raw - h).distance;
      if (d < offsetRadius && d < best) {
        hit = i;
        best = d;
        hitIsEdge = false;
        hitIsOffset = true;
        chosenHandle = h;
      }
    }

    // 4. Offset edge midpoint handle check (outward edge pull handles)
    for (var i = 0; i < polygon.length; i++) {
      final h = offsetEdgeHandle(polygon, i, scale);
      final d = (raw - h).distance;
      if (d < offsetRadius && d < best) {
        hit = i;
        best = d;
        hitIsEdge = true;
        hitIsOffset = true;
        chosenHandle = h;
      }
    }

    // 5. Proximity outside tap fallback (tap near contour to activate closest handle)
    if (hit == null) {
      var proximityBest = proximityRadius;
      for (var i = 0; i < polygon.length; i++) {
        final hv = offsetVertexHandle(polygon, i, scale);
        final dv = (raw - hv).distance;
        if (dv < proximityBest) {
          hit = i;
          proximityBest = dv;
          hitIsEdge = false;
          hitIsOffset = true;
          chosenHandle = hv;
        }

        final he = offsetEdgeHandle(polygon, i, scale);
        final de = (raw - he).distance;
        if (de < proximityBest) {
          hit = i;
          proximityBest = de;
          hitIsEdge = true;
          hitIsOffset = true;
          chosenHandle = he;
        }
      }
    }

    if (hit == null || chosenHandle == null) return false;

    elementId = id;
    original = List.of(polygon);
    preview = List.of(polygon);
    index = hit;
    edge = hitIsEdge;
    edgeMode = mode;
    isOffsetHandle = hitIsOffset;
    grabOffset = chosenHandle - raw;
    leaderOrigin = edge
        ? (polygon[hit] + polygon[(hit + 1) % polygon.length]) / 2
        : polygon[hit];
    editedPoint = leaderOrigin;
    _handleDisplacement = chosenHandle - leaderOrigin!;
    leaderTarget = raw + grabOffset;
    invalid = false;
    return true;
  }

  void update(Offset raw, TSnap Function(Offset) snap, double mergeRadius) {
    if (!active) return;
    final polygon = original!, i = index!;
    final target = raw + grabOffset - _handleDisplacement;
    leaderTarget = raw + grabOffset;
    List<Offset>? next;
    Offset? movingPoint;
    if (edge) {
      final n = BimPolygonGeometry.normal(polygon, i);
      final midpoint = (polygon[i] + polygon[(i + 1) % polygon.length]) / 2;
      final distance = BimPolygonGeometry.dot(target - midpoint, n);
      var correctionDistance = 0.0;
      activeSnap = null;
      var best = double.infinity;
      for (final p in [
        polygon[i],
        polygon[(i + 1) % polygon.length],
        midpoint,
      ]) {
        final moving = p + n * distance;
        final result = snap(moving);
        if (!isSnapped(result)) continue;
        final correction = pointOf(result) - moving;
        final along = BimPolygonGeometry.dot(correction, n);
        if ((correction - n * along).distance > 1e-7 || along.abs() >= best) {
          continue;
        }
        best = along.abs();
        correctionDistance = along;
        activeSnap = result;
      }
      next = BimPolygonGeometry.offsetEdge(
        polygon,
        i,
        distance + correctionDistance,
        mode: edgeMode,
      );
      movingPoint = midpoint + n * (distance + correctionDistance);
    } else {
      activeSnap = snap(target);
      var point = pointOf(activeSnap as TSnap);
      for (final neighbor in [
        (i - 1 + polygon.length) % polygon.length,
        (i + 1) % polygon.length,
      ]) {
        if ((target - polygon[neighbor]).distance <= mergeRadius) {
          point = polygon[neighbor];
        }
      }
      next = BimPolygonGeometry.moveVertex(polygon, i, point);
      movingPoint = point;
    }
    invalid = next == null;
    if (invalid) activeSnap = null;
    if (next != null) {
      preview = next;
      editedPoint = movingPoint;
    }
  }

  void cancel() {
    elementId = null;
    original = null;
    preview = null;
    index = null;
    invalid = false;
    activeSnap = null;
    isOffsetHandle = false;
    leaderOrigin = null;
    leaderTarget = null;
    editedPoint = null;
    _handleDisplacement = Offset.zero;
  }
}
