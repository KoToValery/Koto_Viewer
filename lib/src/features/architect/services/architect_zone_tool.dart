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
//      * rotatePolygon, translatePolygon, offsetPolygon, rayIntersection
//      * alignPolygonToNearest2D (GPS_Mapping 90°/5° squarify algorithm)
//      * extrudeEdge (edge midpoint step/niche extrusion)
//      * calculateOrthoSnap
//
// 3. === SECTION: ZONE_TOOL_CONTROLLER ===
//    - ArchitectZoneTool (ChangeNotifier):
//      * Drafting State & Methods (zero-lag point-by-point, quick rectangle)
//      * Edge Extrusion State & Methods
//      * GPS_Mapping-style Zone Edit & Transform Mode:
//        - autoAlignZone (90° squarify) & undoAutoAlignZone
//        - rotation slider & ±15°/±90° steps
//        - move whole zone mode
//        - offset boundary expand/shrink
//        - full undo/redo stack
// =============================================================================

// === SECTION: ORTHO_GUIDES_AND_STATUS_ENUMS ===

/// Orthogonal guide orientation for vector-style alignment.
typedef ArchitectOrthoType = BimContourOrthoType;
typedef ArchitectOrthoSnapResult = BimContourOrthoSnapResult;

/// Status of candidate point during point-by-point drawing.
enum ZoneDraftingPointStatus { valid, closeTarget, selfIntersects, tooClose }

/// Mode of zone creation: freeform point-by-point or 2-click rectangle.
enum ArchitectZoneDraftMode { polyline, rectangle }

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
  // GPS_Mapping-style Zone Edit & Transform State
  // ---------------------------------------------------------------------------
  ArchitectZone? _editingZone;
  List<Offset>? _editingPolygon;
  List<Offset>? _preAlignBackupPolygon;
  final List<List<Offset>> _editUndoStack = [];
  final List<List<Offset>> _editRedoStack = [];
  double _editRotationSlider = 0.0;
  double _lastAppliedRotationSlider = 0.0;
  bool _isMoveWholeZoneMode = false;
  Offset? _moveStartPoint;
  List<Offset>? _moveStartPolygon;
  double _moveDistanceMeters = 0.0;

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
  // GPS_Mapping-style Edit & Transform Getters
  // ---------------------------------------------------------------------------
  bool get isEditingZone => _editingZone != null;
  ArchitectZone? get editingZone => _editingZone;
  List<Offset>? get editingPolygon => _editingPolygon;
  bool get canUndoAutoAlign => _preAlignBackupPolygon != null;
  bool get canUndoEdit => _editUndoStack.isNotEmpty;
  bool get canRedoEdit => _editRedoStack.isNotEmpty;
  double get editRotationSlider => _editRotationSlider;
  bool get isMoveWholeZoneMode => _isMoveWholeZoneMode;
  bool get isMovingZone => _moveStartPoint != null;
  double get moveDistanceMeters => _moveDistanceMeters;

  /// General flag for whether tool has an active modal interaction.
  bool get isInteracting =>
      isDrafting || isExtruding || isMoveWholeZoneMode || isMovingZone;

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
      name: defaultName,
      category: category,
      polygon: cleaned,
    );

    cancelDrafting();
    return newZone;
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
  // GPS_Mapping-style Zone Edit & Transform Methods
  // ---------------------------------------------------------------------------

  /// Initiates interactive edit mode for an existing zone.
  void startEditingZone(ArchitectZone zone) {
    cancelDrafting();
    cancelExtrude();
    _editingZone = zone;
    _editingPolygon = List<Offset>.from(zone.polygon);
    _preAlignBackupPolygon = null;
    _editUndoStack.clear();
    _editRedoStack.clear();
    _editRotationSlider = 0.0;
    _lastAppliedRotationSlider = 0.0;
    _isMoveWholeZoneMode = false;
    _moveStartPoint = null;
    _moveStartPolygon = null;
    _moveDistanceMeters = 0.0;
    notifyListeners();
  }

  void _pushEditUndo() {
    if (_editingPolygon == null) return;
    _editUndoStack.add(List<Offset>.from(_editingPolygon!));
    if (_editUndoStack.length > 25) {
      _editUndoStack.removeAt(0);
    }
    _editRedoStack.clear();
  }

  void undoEditAction() {
    if (_editUndoStack.isEmpty || _editingPolygon == null) return;
    _editRedoStack.add(List<Offset>.from(_editingPolygon!));
    _editingPolygon = _editUndoStack.removeLast();
    _editRotationSlider = 0.0;
    _lastAppliedRotationSlider = 0.0;
    notifyListeners();
  }

  void redoEditAction() {
    if (_editRedoStack.isEmpty || _editingPolygon == null) return;
    _editUndoStack.add(List<Offset>.from(_editingPolygon!));
    _editingPolygon = _editRedoStack.removeLast();
    _editRotationSlider = 0.0;
    _lastAppliedRotationSlider = 0.0;
    notifyListeners();
  }

  /// Automatically squares all corners of the editing polygon to 90° (and closes at 90°),
  /// preserving centroid and area scale (GPS_Mapping squarify algorithm).
  bool autoAlignZone() {
    if (_editingPolygon == null || _editingPolygon!.length < 3) return false;
    final aligned = ArchitectZoneGeometry.alignPolygonToNearest2D(
      _editingPolygon!,
    );
    if (aligned.length != _editingPolygon!.length) return false;

    bool changed = false;
    for (int i = 0; i < aligned.length; i++) {
      if ((aligned[i] - _editingPolygon![i]).distance > 0.005) {
        changed = true;
        break;
      }
    }
    if (!changed) return false;

    _pushEditUndo();
    _preAlignBackupPolygon = List<Offset>.from(_editingPolygon!);
    _editingPolygon = aligned;
    notifyListeners();
    return true;
  }

  /// Reverts the 90° straightening operation.
  bool undoAutoAlignZone() {
    if (_preAlignBackupPolygon == null || _editingPolygon == null) return false;
    _pushEditUndo();
    _editingPolygon = List<Offset>.from(_preAlignBackupPolygon!);
    _preAlignBackupPolygon = null;
    notifyListeners();
    return true;
  }

  /// Live updates polygon rotation using centroid-based rotation matrix.
  void setRotationSlider(double angleDeg) {
    if (_editingPolygon == null) return;
    final delta = angleDeg - _lastAppliedRotationSlider;
    _editRotationSlider = angleDeg;
    if (delta.abs() > 0.01) {
      final centroid = ArchitectZoneGeometry.calculateCentroid(
        _editingPolygon!,
      );
      _editingPolygon = ArchitectZoneGeometry.rotatePolygon(
        _editingPolygon!,
        delta,
        centroid,
      );
      _lastAppliedRotationSlider = angleDeg;
      notifyListeners();
    }
  }

  /// Finalizes rotation slider drag gesture and creates an undo restore point.
  void finishRotationSlider() {
    if (_editingPolygon == null) return;
    if (_lastAppliedRotationSlider.abs() > 0.1) {
      _pushEditUndo();
    }
    _editRotationSlider = 0.0;
    _lastAppliedRotationSlider = 0.0;
    notifyListeners();
  }

  /// Incremental rotation step (e.g. ±15°, ±90°).
  void applyRotationStep(double stepDeg) {
    if (_editingPolygon == null) return;
    _pushEditUndo();
    final centroid = ArchitectZoneGeometry.calculateCentroid(_editingPolygon!);
    _editingPolygon = ArchitectZoneGeometry.rotatePolygon(
      _editingPolygon!,
      stepDeg,
      centroid,
    );
    notifyListeners();
  }

  /// Boundary offset step (in meters, e.g. ±0.20m).
  void applyOffsetStep(double distanceMeters) {
    if (_editingPolygon == null) return;
    _pushEditUndo();
    _editingPolygon = ArchitectZoneGeometry.offsetPolygon(
      _editingPolygon!,
      distanceMeters,
    );
    notifyListeners();
  }

  /// Toggles whole zone translation drag mode.
  void toggleMoveWholeZoneMode() {
    _isMoveWholeZoneMode = !_isMoveWholeZoneMode;
    _moveStartPoint = null;
    _moveStartPolygon = null;
    _moveDistanceMeters = 0.0;
    notifyListeners();
  }

  void startMovingZone(Offset modelPoint) {
    if (!_isMoveWholeZoneMode || _editingPolygon == null) return;
    _moveStartPoint = modelPoint;
    _moveStartPolygon = List<Offset>.from(_editingPolygon!);
    _moveDistanceMeters = 0.0;
  }

  void updateMovingZone(Offset modelPoint) {
    if (!_isMoveWholeZoneMode ||
        _moveStartPoint == null ||
        _moveStartPolygon == null) {
      return;
    }
    final delta = modelPoint - _moveStartPoint!;
    _moveDistanceMeters = delta.distance;
    _editingPolygon = ArchitectZoneGeometry.translatePolygon(
      _moveStartPolygon!,
      delta,
    );
    notifyListeners();
  }

  void finishMovingZone() {
    if (_moveStartPolygon != null && _editingPolygon != null) {
      if (_moveDistanceMeters > 1e-9) {
        _editUndoStack.add(_moveStartPolygon!);
        _editRedoStack.clear();
      }
    }
    _moveStartPoint = null;
    _moveStartPolygon = null;
    _moveDistanceMeters = 0.0;
    notifyListeners();
  }

  /// Abandon a pointer gesture without applying it or adding an Undo step.
  void cancelMovingZone() {
    if (_moveStartPolygon != null) {
      _editingPolygon = List<Offset>.from(_moveStartPolygon!);
    }
    _moveStartPoint = null;
    _moveStartPolygon = null;
    _moveDistanceMeters = 0;
    notifyListeners();
  }

  void dragEditingVertex(int index, Offset newPos) {
    if (_editingPolygon == null ||
        index < 0 ||
        index >= _editingPolygon!.length) {
      return;
    }
    _pushEditUndo();
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
    _preAlignBackupPolygon = null;
    _editUndoStack.clear();
    _editRedoStack.clear();
    _editRotationSlider = 0.0;
    _lastAppliedRotationSlider = 0.0;
    _isMoveWholeZoneMode = false;
    _moveStartPoint = null;
    _moveStartPolygon = null;
    _moveDistanceMeters = 0.0;
    notifyListeners();
  }

  /// Cancels drafting, extrusion, and edit operations.
  void cancelAll() {
    cancelDrafting();
    cancelExtrude();
    cancelEditingZone();
  }
}
