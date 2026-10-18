import '../../bim_editing/geometry/bim_contour_drafting_geometry.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'architect_element_id.dart';
import '../models/architect_project.dart';
import '../models/architect_zone.dart';
import '../rendering/architect_zone_snap.dart';
import '../../bim_projects/models/bim_coordinate_frame.dart';
import '../../dxf_viewer/models/dxf_models.dart';

// =============================================================================
// FILE INDEX / TABLE OF CONTENTS (Grep markers: === SECTION: <NAME> ===)
// =============================================================================
// 1. === SECTION: ORTHO_GUIDES_AND_STATUS_ENUMS ===
//    - ArchitectOrthoType
//    - ArchitectOrthoSnapResult
//    - ZoneDraftingPointStatus
//    - ArchitectZoneDraftMode (polyline, rectangle)
//
// 2. === SECTION: GEOMETRY_AND_MATH_ENGINE ===
//    - ArchitectZoneGeometry:
//      * linesIntersect, segmentIntersectsChain, calculateArea, calculateCentroid
//      * cleanPolygon (orphan/collinear point removal)
//      * extrudeEdge (edge midpoint step/niche extrusion)
//      * calculateOrthoSnap
//
// 3. === SECTION: ZONE_TOOL_CONTROLLER ===
//    - ArchitectZoneTool (ChangeNotifier):
//      * 1-Click Room Boundary Auto-Detection (raycasting & topological flood fill)
//      * Point-by-point manual drafting (like slab element)
//      * Edge midpoint niche extrusion
//      * Vertex handle dragging
//      * Dynamic boundary update & room merge on wall removal
// =============================================================================

// === SECTION: ORTHO_GUIDES_AND_STATUS_ENUMS ===

/// Orthogonal guide orientation for vector-style alignment.
typedef ArchitectOrthoType = BimContourOrthoType;
typedef ArchitectOrthoSnapResult = BimContourOrthoSnapResult;

/// Status of candidate point during point-by-point drawing.
enum ZoneDraftingPointStatus { valid, closeTarget, selfIntersects, tooClose }

/// Mode of zone creation: freeform point-by-point or 2-click rectangle.
enum ArchitectZoneDraftMode { polyline, rectangle }

/// High-level placement interaction mode:
/// - autoClick: 1-click room boundary detection and auto-fit (default)
/// - manualPoints: point-by-point manual contour placement like slab element
enum ArchitectZonePlacementMode { autoClick, manualPoints }

// === SECTION: GEOMETRY_AND_MATH_ENGINE ===

/// Mathematical & geometric operations for architectural functional zones:
/// orphan vertex reduction, self-intersection avoidance, edge extrusion,
/// and vector-style orthogonal straightening guides.
typedef ArchitectZoneGeometry = BimContourDraftingGeometry;

// === SECTION: ZONE_TOOL_CONTROLLER ===

/// Unified state and operation manager for architectural functional zones.
/// Combines point-by-point polyline drafting, interactive edge midpoint extrusion,
/// and geometric safety validations into a cohesive, single tool unit.
class ArchitectZoneTool extends ChangeNotifier {
  // ---------------------------------------------------------------------------
  // Placement Mode (Auto 1-Click vs Manual Point-by-point)
  // ---------------------------------------------------------------------------
  ArchitectZonePlacementMode _placementMode =
      ArchitectZonePlacementMode.autoClick;
  ArchitectZonePlacementMode get placementMode => _placementMode;
  set placementMode(ArchitectZonePlacementMode mode) {
    if (_placementMode != mode) {
      _placementMode = mode;
      cancelDrafting();
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Drafting Mode & Fast Rectangle State
  // ---------------------------------------------------------------------------
  ArchitectZoneDraftMode _draftMode = ArchitectZoneDraftMode.polyline;
  ArchitectZoneDraftMode get draftMode => _draftMode;
  set draftMode(ArchitectZoneDraftMode mode) {
    if (_draftMode != mode) {
      _draftMode = mode;
      cancelDrafting();
    }
  }

  // ---------------------------------------------------------------------------
  // Drafting State (Point-by-point creation)
  // ---------------------------------------------------------------------------
  final List<Offset> _draftPoints = [];
  Offset? _candidatePoint;
  Offset? _snappedPoint;
  (Offset, Offset)? _orthoGuide;
  String? _orthoLabel;
  List<(Offset, Offset)> _magneticGuides = [];
  bool _isClosingSnap = false;
  ZoneDraftingPointStatus _pointStatus = ZoneDraftingPointStatus.valid;

  // ---------------------------------------------------------------------------
  // Zone Editing State
  // ---------------------------------------------------------------------------
  ArchitectZone? _editingZone;
  List<Offset>? _editingPolygon;

  // ---------------------------------------------------------------------------
  // Edge Extrusion State (Midpoint handle drag)
  // ---------------------------------------------------------------------------
  ArchitectZone? _extrudeTargetZone;
  int? _extrudeEdgeIndex;
  Offset? _extrudeV1;
  Offset? _extrudeV2;
  Offset? _extrudeMidInitial;
  Offset? _extrudeNormal;
  double _extrudeDistance = 0.0;
  List<Offset>? _extrudePreviewPolygon;
  bool _isExtrudeSelfIntersecting = false;

  // ---------------------------------------------------------------------------
  // Drafting Getters
  // ---------------------------------------------------------------------------
  List<Offset> get draftPoints => List.unmodifiable(_draftPoints);
  List<Offset> get points => List.unmodifiable(_draftPoints);
  int get draftPointCount => _draftPoints.length;
  int get pointCount => _draftPoints.length;
  bool get isDrafting => _draftPoints.isNotEmpty;
  bool get canCloseDraft {
    if (_draftMode == ArchitectZoneDraftMode.rectangle) {
      if (_draftPoints.length >= 3) return true;
      if (_draftPoints.length == 1 && candidatePoint != null) {
        final p0 = _draftPoints[0];
        final p2 = candidatePoint!;
        return (p2.dx - p0.dx).abs() >= 0.15 && (p2.dy - p0.dy).abs() >= 0.15;
      }
      return false;
    }
    return _draftPoints.length >= 3;
  }

  bool get canClose => canCloseDraft;
  Offset? get candidatePoint => _snappedPoint ?? _candidatePoint;
  Offset? get rawCandidatePoint => _candidatePoint;
  (Offset, Offset)? get orthoGuide => _orthoGuide;
  String? get orthoLabel => _orthoLabel;
  List<(Offset, Offset)> get magneticGuides => _magneticGuides;
  bool get isClosingSnap => _isClosingSnap;
  ZoneDraftingPointStatus get pointStatus => _pointStatus;

  List<Offset> get previewRectangle {
    if (_draftMode != ArchitectZoneDraftMode.rectangle ||
        _draftPoints.length != 1 ||
        candidatePoint == null) {
      return const [];
    }
    final p0 = _draftPoints[0];
    final p2 = candidatePoint!;
    final p1 = Offset(p2.dx, p0.dy);
    final p3 = Offset(p0.dx, p2.dy);
    return [p0, p1, p2, p3];
  }

  double? get activeSegmentLength {
    if (_draftPoints.isEmpty || candidatePoint == null) return null;
    return (candidatePoint! - _draftPoints.last).distance;
  }

  double? get activeSegmentAngleDeg {
    if (_draftPoints.isEmpty || candidatePoint == null) return null;
    final d = candidatePoint! - _draftPoints.last;
    if (d.distance < 1e-4) return 0.0;
    return math.atan2(d.dy, d.dx) * 180.0 / math.pi;
  }

  double get livePerimeter {
    if (_draftPoints.isEmpty) return 0.0;
    if (_draftMode == ArchitectZoneDraftMode.rectangle &&
        candidatePoint != null) {
      final p0 = _draftPoints[0];
      final p2 = candidatePoint!;
      return 2.0 * ((p2.dx - p0.dx).abs() + (p2.dy - p0.dy).abs());
    }
    double perim = 0.0;
    for (int i = 0; i < _draftPoints.length - 1; i++) {
      perim += (_draftPoints[i + 1] - _draftPoints[i]).distance;
    }
    if (candidatePoint != null) {
      perim += (candidatePoint! - _draftPoints.last).distance;
      if (_draftPoints.length >= 2) {
        perim += (candidatePoint! - _draftPoints.first).distance;
      }
    }
    return perim;
  }

  double get liveArea {
    if (_draftPoints.isEmpty || candidatePoint == null) return 0.0;
    if (_draftMode == ArchitectZoneDraftMode.rectangle) {
      final p0 = _draftPoints[0];
      final p2 = candidatePoint!;
      return (p2.dx - p0.dx).abs() * (p2.dy - p0.dy).abs();
    }
    if (_draftPoints.length < 2) return 0.0;
    final testPoly = [..._draftPoints, candidatePoint!];
    return ArchitectZoneGeometry.calculateArea(testPoly);
  }

  // ---------------------------------------------------------------------------
  // Extrusion Getters
  // ---------------------------------------------------------------------------
  bool get isExtruding =>
      _extrudeEdgeIndex != null && _extrudeTargetZone != null;
  int? get extrudeEdgeIndex => _extrudeEdgeIndex;
  double get extrudeDistance => _extrudeDistance;
  double get activeDistance => _extrudeDistance;
  List<Offset>? get extrudePreviewPolygon => _extrudePreviewPolygon;
  List<Offset>? get previewPolygon => _extrudePreviewPolygon;
  bool get isExtrudeSelfIntersecting => _isExtrudeSelfIntersecting;
  bool get isSelfIntersecting => _isExtrudeSelfIntersecting;
  Offset? get extrudeNormal => _extrudeNormal;
  Offset? get normal => _extrudeNormal;
  Offset? get extrudeV1 => _extrudeV1;
  Offset? get v1 => _extrudeV1;
  Offset? get extrudeV2 => _extrudeV2;
  Offset? get v2 => _extrudeV2;
  Offset? get extrudeMidInitial => _extrudeMidInitial;

  // ---------------------------------------------------------------------------
  // Zone Editing Getters
  // ---------------------------------------------------------------------------
  bool get isEditingZone => _editingZone != null;
  ArchitectZone? get editingZone => _editingZone;
  List<Offset>? get editingPolygon => _editingPolygon;

  /// General flag for whether tool has an active modal interaction.
  bool get isInteracting => isDrafting || isExtruding;

  // Convenient aliases
  void start(Offset startPoint) => startDrafting(startPoint);
  bool addPoint(Offset point) => addDraftingPoint(point);
  void undoLastPoint() => undoDraftingPoint();
  void cancel() => cancelDrafting();
  ArchitectZone? commit({
    required ArchitectZoneCategory category,
    required String defaultName,
  }) => commitDrafting(category: category, defaultName: defaultName);
  void updatePointer({
    required Offset rawModelPoint,
    required ArchitectProject project,
    required double currentScale,
  }) => updateDraftingPointer(
    rawModelPoint: rawModelPoint,
    project: project,
    currentScale: currentScale,
  );

  // ---------------------------------------------------------------------------
  // Drafting Methods
  // ---------------------------------------------------------------------------

  void startDrafting(Offset startPoint) {
    cancelExtrude();
    _draftPoints.clear();
    _draftPoints.add(startPoint);
    _candidatePoint = startPoint;
    _snappedPoint = startPoint;
    _orthoGuide = null;
    _orthoLabel = null;
    _magneticGuides = [];
    _isClosingSnap = false;
    _pointStatus = ZoneDraftingPointStatus.valid;
    notifyListeners();
  }

  void updateDraftingPointer({
    required Offset rawModelPoint,
    required ArchitectProject project,
    required double currentScale,
    bool magnetic = true,
    DxfDocument? underlay,
    BimCoordinateFrame frame = const BimCoordinateFrame(),
    Map<String, bool> visibility = const {},
  }) {
    if (!isDrafting) return;

    _candidatePoint = rawModelPoint;
    final lastPoint = _draftPoints.last;
    final snapTolerance = math.min(14.0 / currentScale, .20);

    // 1. Closing snap to first point
    if (_draftPoints.length >= 3) {
      final firstPoint = _draftPoints.first;
      if ((rawModelPoint - firstPoint).distance <= snapTolerance) {
        _snappedPoint = firstPoint;
        _isClosingSnap = true;
        _orthoGuide = null;
        _orthoLabel = null;
        _magneticGuides = [];
        _pointStatus = ZoneDraftingPointStatus.closeTarget;
        notifyListeners();
        return;
      }

      if (magnetic) {
        final closure =
            BimContourDraftingGeometry.calculatePolygonClosureOrthoSnap(
          points: _draftPoints,
          raw: rawModelPoint,
          tolerance: math.max(16.0 / currentScale, 0.30),
        );
        if (closure.isSnapped) {
          _snappedPoint = closure.point;
          _candidatePoint = closure.point;
          _isClosingSnap = false;
          _orthoGuide = null;
          _orthoLabel = closure.snapLabel;
          _magneticGuides = closure.magneticGuides;
          final isIntersecting = ArchitectZoneGeometry.segmentIntersectsChain(
            lastPoint,
            closure.point,
            _draftPoints,
          );
          _pointStatus = isIntersecting
              ? ZoneDraftingPointStatus.selfIntersects
              : ZoneDraftingPointStatus.valid;
          notifyListeners();
          return;
        }
      }
    }
    _isClosingSnap = false;

    // 2. Structural & zone magnetic snapping
    final zoneSnap = ArchitectZoneSnap.snap(
      raw: rawModelPoint,
      project: project,
      tolerance: snapTolerance,
      magnetic: magnetic,
      underlay: underlay,
      frame: frame,
      visibility: visibility,
    );

    Offset candidate = zoneSnap.point;
    _magneticGuides = zoneSnap.magneticGuides;

    // 3. Orthogonal straightening guide relative to previous point
    final orthoResult = ArchitectZoneGeometry.calculateOrthoSnap(
      anchor: lastPoint,
      raw: candidate,
      snapAngleToleranceDeg: 7.0,
    );

    if (magnetic &&
        !zoneSnap.isSnapped &&
        orthoResult.isSnapped &&
        (orthoResult.point - rawModelPoint).distance <= snapTolerance) {
      candidate = orthoResult.point;
      _orthoGuide = orthoResult.guideLine;
      _orthoLabel = orthoResult.type == ArchitectOrthoType.horizontal
          ? '0°'
          : '90°';
    } else {
      _orthoGuide = null;
      _orthoLabel = null;
    }

    _snappedPoint = candidate;

    // 4. Validate candidate against self-intersections
    final isIntersecting = ArchitectZoneGeometry.segmentIntersectsChain(
      lastPoint,
      candidate,
      _draftPoints,
    );

    if (isIntersecting) {
      _pointStatus = ZoneDraftingPointStatus.selfIntersects;
    } else if ((candidate - lastPoint).distance < 0.001) {
      _pointStatus = ZoneDraftingPointStatus.tooClose;
    } else {
      _pointStatus = ZoneDraftingPointStatus.valid;
    }

    notifyListeners();
  }

  bool addDraftingPoint(Offset point) {
    if (!isDrafting) {
      startDrafting(point);
      return true;
    }

    if (_draftMode == ArchitectZoneDraftMode.rectangle &&
        _draftPoints.length == 1) {
      final p0 = _draftPoints[0];
      final p2 = point;
      if ((p2.dx - p0.dx).abs() < 0.001 || (p2.dy - p0.dy).abs() < 0.001) {
        return false;
      }
      final p1 = Offset(p2.dx, p0.dy);
      final p3 = Offset(p0.dx, p2.dy);
      _draftPoints.clear();
      _draftPoints.addAll([p0, p1, p2, p3]);
      _candidatePoint = p2;
      _snappedPoint = p2;
      _pointStatus = ZoneDraftingPointStatus.valid;
      notifyListeners();
      return true;
    }

    if (_draftPoints.length >= 3) {
      final distToStart = (point - _draftPoints.first).distance;
      if (_isClosingSnap || distToStart <= 1e-9) {
        return true;
      }
    }

    if ((point - _draftPoints.last).distance < 0.001) {
      return false;
    }

    if (ArchitectZoneGeometry.segmentIntersectsChain(
      _draftPoints.last,
      point,
      _draftPoints,
    )) {
      _pointStatus = ZoneDraftingPointStatus.selfIntersects;
      notifyListeners();
      return false;
    }

    _draftPoints.add(point);
    _candidatePoint = point;
    _snappedPoint = point;
    _orthoGuide = null;
    _orthoLabel = null;
    _isClosingSnap = false;
    _pointStatus = ZoneDraftingPointStatus.valid;
    notifyListeners();
    return true;
  }

  void undoDraftingPoint() {
    if (_draftPoints.isEmpty) return;
    _draftPoints.removeLast();
    if (_draftPoints.isNotEmpty) {
      _candidatePoint = _draftPoints.last;
      _snappedPoint = _draftPoints.last;
    } else {
      cancelDrafting();
      return;
    }
    _orthoGuide = null;
    _orthoLabel = null;
    _isClosingSnap = false;
    _pointStatus = ZoneDraftingPointStatus.valid;
    notifyListeners();
  }

  void cancelDrafting() {
    _draftPoints.clear();
    _candidatePoint = null;
    _snappedPoint = null;
    _orthoGuide = null;
    _orthoLabel = null;
    _magneticGuides = [];
    _isClosingSnap = false;
    _pointStatus = ZoneDraftingPointStatus.valid;
    notifyListeners();
  }

  ArchitectZone? commitDrafting({
    required ArchitectZoneCategory category,
    required String defaultName,
    String? number,
  }) {
    if (_draftMode == ArchitectZoneDraftMode.rectangle &&
        _draftPoints.length == 1 &&
        candidatePoint != null) {
      final p0 = _draftPoints[0];
      final p2 = candidatePoint!;
      if ((p2.dx - p0.dx).abs() >= 0.1 && (p2.dy - p0.dy).abs() >= 0.1) {
        final p1 = Offset(p2.dx, p0.dy);
        final p3 = Offset(p0.dx, p2.dy);
        _draftPoints.clear();
        _draftPoints.addAll([p0, p1, p2, p3]);
      }
    }

    if (_draftPoints.length < 3) return null;

    if (ArchitectZoneGeometry.segmentIntersectsChain(
      _draftPoints.last,
      _draftPoints.first,
      _draftPoints,
      isClosing: true,
    )) {
      _pointStatus = ZoneDraftingPointStatus.selfIntersects;
      notifyListeners();
      return null;
    }

    final cleaned = ArchitectZoneGeometry.cleanPolygon(
      _draftPoints,
      minDistance: 1e-6,
      minCollinearDistance: 1e-7,
    );

    if (cleaned.length < 3) return null;

    if (ArchitectZoneGeometry.hasSelfIntersections(cleaned)) {
      _pointStatus = ZoneDraftingPointStatus.selfIntersects;
      notifyListeners();
      return null;
    }

    final now = ArchitectElementId.next('element');
    final newZone = ArchitectZone(
      id: 'zone_$now',
      number: number ?? '1',
      name: defaultName,
      category: category,
      polygon: cleaned,
      isAutoBoundary: _placementMode == ArchitectZonePlacementMode.autoClick,
      seedPoint: cleaned.isNotEmpty ? cleaned.first : null,
    );

    cancelDrafting();
    return newZone;
  }

  /// Factory for 1-click auto-detected room zones.
  ArchitectZone createAutoZone({
    required List<Offset> polygon,
    required Offset seedPoint,
    required ArchitectZoneCategory category,
    required String name,
    required String number,
    String floorFinish = '',
    String wallFinish = '',
    String ceilingFinish = '',
    double clearHeight = 2.60,
  }) {
    final now = ArchitectElementId.next('element');
    return ArchitectZone(
      id: 'zone_$now',
      number: number,
      name: name,
      category: category,
      polygon: polygon,
      floorFinish: floorFinish,
      wallFinish: wallFinish,
      ceilingFinish: ceilingFinish,
      clearHeight: clearHeight,
      isAutoBoundary: true,
      seedPoint: seedPoint,
    );
  }

  // ---------------------------------------------------------------------------
  // Extrusion Methods
  // ---------------------------------------------------------------------------

  bool startExtrude({
    required ArchitectZone zone,
    required int edgeIndex,
    required Offset pointerModel,
  }) {
    cancelDrafting();
    final poly = zone.polygon;
    final n = poly.length;
    if (edgeIndex < 0 || edgeIndex >= n) return false;

    _extrudeTargetZone = zone;
    _extrudeEdgeIndex = edgeIndex;
    _extrudeV1 = poly[edgeIndex];
    _extrudeV2 = poly[(edgeIndex + 1) % n];
    _extrudeMidInitial = (_extrudeV1! + _extrudeV2!) / 2.0;
    _extrudeNormal = ArchitectZoneGeometry.calculateOutwardNormal(
      poly,
      edgeIndex,
    );
    _extrudeDistance = 0.0;
    _extrudePreviewPolygon = List<Offset>.from(poly);
    _isExtrudeSelfIntersecting = false;
    notifyListeners();
    return true;
  }

  void updateExtrudePointer(Offset pointerModel) {
    if (!isExtruding || _extrudeNormal == null || _extrudeMidInitial == null) {
      return;
    }

    final delta = pointerModel - _extrudeMidInitial!;
    final dist = delta.dx * _extrudeNormal!.dx + delta.dy * _extrudeNormal!.dy;
    _extrudeDistance = dist;

    final poly = _extrudeTargetZone!.polygon;
    final n = poly.length;
    final vNew1 = _extrudeV1! + _extrudeNormal! * dist;
    final vNew2 = _extrudeV2! + _extrudeNormal! * dist;

    final testPts = <Offset>[];
    for (int i = 0; i < n; i++) {
      testPts.add(poly[i]);
      if (i == _extrudeEdgeIndex) {
        testPts.add(vNew1);
        testPts.add(vNew2);
      }
    }

    _isExtrudeSelfIntersecting = ArchitectZoneGeometry.hasSelfIntersections(
      testPts,
    );
    _extrudePreviewPolygon = testPts;
    notifyListeners();
  }

  (ArchitectZone, int cleanedCount)? commitExtrude() {
    if (!isExtruding ||
        _extrudeTargetZone == null ||
        _extrudeEdgeIndex == null) {
      cancelExtrude();
      return null;
    }

    if (_extrudeDistance.abs() < 0.001) {
      cancelExtrude();
      return null;
    }

    final poly = _extrudeTargetZone!.polygon;
    final rawCount = poly.length + 2;
    final extruded = ArchitectZoneGeometry.extrudeEdge(
      polygon: poly,
      edgeIndex: _extrudeEdgeIndex!,
      distance: _extrudeDistance,
      minDistance: 1e-6,
    );

    if (extruded == null) {
      cancelExtrude();
      return null;
    }

    final cleanedCount = rawCount - extruded.length;
    final updatedZone = _extrudeTargetZone!.copyWith(polygon: extruded);
    cancelExtrude();
    return (updatedZone, cleanedCount > 0 ? cleanedCount : 0);
  }

  void cancelExtrude() {
    _extrudeTargetZone = null;
    _extrudeEdgeIndex = null;
    _extrudeV1 = null;
    _extrudeV2 = null;
    _extrudeMidInitial = null;
    _extrudeNormal = null;
    _extrudeDistance = 0.0;
    _extrudePreviewPolygon = null;
    _isExtrudeSelfIntersecting = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Zone Editing Methods (Clean architectural workflow)
  // ---------------------------------------------------------------------------

  /// Initiates interactive edit mode for an existing zone.
  void startEditingZone(ArchitectZone zone) {
    cancelDrafting();
    cancelExtrude();
    _editingZone = zone;
    _editingPolygon = List<Offset>.from(zone.polygon);
    notifyListeners();
  }

  void dragEditingVertex(int index, Offset newPos) {
    if (_editingPolygon == null ||
        index < 0 ||
        index >= _editingPolygon!.length) {
      return;
    }
    _editingPolygon![index] = newPos;
    notifyListeners();
  }

  /// Finalizes edit mode and returns the updated zone with cleaned polygon.
  ArchitectZone? commitEditingZone() {
    if (_editingZone == null || _editingPolygon == null) return null;
    final cleaned = ArchitectZoneGeometry.cleanPolygon(
      _editingPolygon!,
      minDistance: 1e-6,
      minCollinearDistance: 1e-7,
    );
    if (cleaned.length < 3 ||
        ArchitectZoneGeometry.hasSelfIntersections(cleaned)) {
      return null;
    }
    final updated = _editingZone!.copyWith(polygon: cleaned);
    cancelEditingZone();
    return updated;
  }

  /// Cancels edit mode without saving changes.
  void cancelEditingZone() {
    _editingZone = null;
    _editingPolygon = null;
    notifyListeners();
  }

  /// Cancels drafting, extrusion, and edit operations.
  void cancelAll() {
    cancelDrafting();
    cancelExtrude();
    cancelEditingZone();
  }
}
