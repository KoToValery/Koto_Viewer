// === SECTION: TABLE OF CONTENTS ===
// 1. IMPORTS & DEFINITIONS
// 2. TOOL CONTROLLER & STATE (ChangeNotifier)
// 3. HIT TESTING & SELECTION
// 4. DRAFTING STATE MACHINE (NEW AXIS)
// 5. HANDLE DRAGGING (EXTENT STRETCHING)
// 6. AXIS BODY TRANSLATION (MOVING)
// 7. AUTO-ALIGNMENT & AUTO-RESEQUENCING
// 8. OFFSET & DUPLICATION ENGINE
// 9. GEOMETRIC & NAMING HELPERS
// ===================================

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'architect_element_id.dart';
import '../../bim_editing/operations/bim_axis_operations.dart';
import '../../bim_editing/operations/bim_axis_naming.dart';

import '../models/architect_grid_axis.dart';
import '../models/architect_project.dart';
import '../models/architect_wall.dart';
import '../rendering/architect_snap_helper.dart';

// === SECTION: TOOL CONTROLLER & STATE ===

/// Unified interaction controller and state machine for dynamic architectural grid axes.
class ArchitectGridAxisTool extends ChangeNotifier {
  // Drafting State
  bool _isDrafting = false;
  Offset? _draftStart;
  Offset? _draftAnchor;
  Offset? _draftEnd;
  String? _draftSnapLabel;

  // Selection & Handle Dragging State
  String? _selectedAxisId;
  bool _isDraggingHandle = false;
  bool _isStartHandle = true;
  StructuralGridAxis? _draggedAxisSnapshot;
  StructuralGridAxis? _handleOriginalAxis;

  // Moving State (whole axis translation)
  bool _isMovingAxis = false;
  Offset? _moveStartPoint;
  StructuralGridAxis? _moveOriginalAxis;
  Offset? _moveCurrentDelta;

  // Offset / Duplication State
  bool _isOffsettingWithDrag = false;
  StructuralGridAxis? _axisBeingOffset;
  double _offsetDistanceMeters = 3.0;
  double _currentOffsetSign = 1.0;

  // Getters
  bool get isDrafting => _isDrafting;
  Offset? get draftStart => _draftStart;
  Offset? get draftEnd => _draftEnd;
  String? get draftSnapLabel => _draftSnapLabel;

  String? get selectedAxisId => _selectedAxisId;
  bool get isDraggingHandle => _isDraggingHandle;
  bool get isStartHandle => _isStartHandle;
  StructuralGridAxis? get draggedAxisSnapshot => _draggedAxisSnapshot;

  bool get isMovingAxis => _isMovingAxis;
  Offset? get moveCurrentDelta => _moveCurrentDelta;
  StructuralGridAxis? get moveOriginalAxis => _moveOriginalAxis;

  bool get isOffsettingWithDrag => _isOffsettingWithDrag;
  StructuralGridAxis? get axisBeingOffset => _axisBeingOffset;
  double get offsetDistanceMeters => _offsetDistanceMeters;
  double get currentOffsetSign => _currentOffsetSign;

  bool get isInteracting =>
      _isDrafting ||
      _isDraggingHandle ||
      _isMovingAxis ||
      _isOffsettingWithDrag;

  StructuralGridAxis? getSelectedAxis(ArchitectProject project) {
    if (_selectedAxisId == null) return null;
    return project.gridAxes.where((a) => a.id == _selectedAxisId).firstOrNull;
  }

  // === SECTION: HIT TESTING & SELECTION ===

  void selectAxis(String? id) {
    if (_selectedAxisId != id) {
      _selectedAxisId = id;
      notifyListeners();
    }
  }

  void deselect() {
    if (_selectedAxisId != null) {
      _selectedAxisId = null;
      notifyListeners();
    }
  }

  /// Hit tests all grid axes in [axes] at [modelPt] within [tolerance] in meters.
  StructuralGridAxis? hitTestAxis(
    Offset modelPt,
    List<StructuralGridAxis> axes, {
    double tolerance = 0.40,
  }) {
    for (final axis in axes.reversed) {
      // 1. Check endpoints / bubbles
      if ((modelPt - axis.start).distance <= tolerance * 1.5 ||
          (modelPt - axis.end).distance <= tolerance * 1.5) {
        return axis;
      }
      // 2. Check line segment
      final d = axis.distanceToSegment(modelPt);
      if (d <= tolerance) {
        return axis;
      }
    }
    return null;
  }

  /// Hit tests the endpoint handles of the selected axis or any other axis.
  (StructuralGridAxis, bool)? hitTestAxisHandle(
    Offset modelPt,
    List<StructuralGridAxis> axes, {
    double tolerance = 0.50,
  }) {
    // Priority: selected axis handles first
    if (_selectedAxisId != null) {
      final selected = axes.where((a) => a.id == _selectedAxisId).firstOrNull;
      if (selected != null) {
        if ((modelPt - selected.start).distance <= tolerance) {
          return (selected, true);
        }
        if ((modelPt - selected.end).distance <= tolerance) {
          return (selected, false);
        }
      }
    }

    // Other axes handles
    for (final axis in axes.reversed) {
      if (axis.id == _selectedAxisId) continue;
      if ((modelPt - axis.start).distance <= tolerance) {
        return (axis, true);
      }
      if ((modelPt - axis.end).distance <= tolerance) {
        return (axis, false);
      }
    }

    return null;
  }

  // === SECTION: DRAFTING STATE MACHINE ===

  void startDrafting(Offset point) {
    _isDrafting = true;
    _draftStart = point;
    _draftAnchor = point;
    _draftEnd = point;
    _draftSnapLabel = null;
    _selectedAxisId = null;
    notifyListeners();
  }

  void updateDrafting(
    Offset rawModelPoint,
    ArchitectProject project,
    double scale, {
    bool magnetic = true,
    ArchitectSnapResult Function(Offset anchor)? snapper,
  }) {
    if (!_isDrafting || _draftAnchor == null) return;

    final snap =
        snapper?.call(_draftAnchor!) ??
        ArchitectSnapHelper.snapWithAnchor(
          magnetic: magnetic,
          anchor: _draftAnchor!,
          rawPoint: rawModelPoint,
          project: project,
          tolerance: 14.0 / scale,
        );

    var candidate = snap.point;
    String? label = snap.snapLabel;

    // Explicit geometry targets win. Optional extent alignment is chosen by
    // total correction from the pointer, with a bounded radius and stable order.
    final candidateDir = candidate - _draftAnchor!;
    if (magnetic &&
        candidateDir.distance > .001 &&
        (!snap.isSnapped || snap.angleDeg != null)) {
      final vertical = candidateDir.dx.abs() <= candidateDir.dy.abs();
      var best = math.min(14.0 / scale, .20) + 1e-9;
      final axes = project.gridAxes.toList()
        ..sort((a, b) => a.id.compareTo(b.id));
      for (final axis in axes) {
        if (axis.isVertical != vertical) continue;
        for (final extent in [axis.start, axis.end]) {
          final point = vertical
              ? Offset(snap.point.dx, extent.dy)
              : Offset(extent.dx, snap.point.dy);
          final correction = (point - rawModelPoint).distance;
          if (correction < best) {
            best = correction;
            candidate = point;
            label = 'Align';
          }
        }
      }
    }

    final raw = StructuralGridAxis(
      id: 'preview',
      name: '',
      start: _draftAnchor!,
      end: candidate,
    );
    final aligned = alignNewAxis(raw, project.gridAxes);
    _draftStart = aligned.start;
    _draftEnd = aligned.end;
    _draftSnapLabel = label;
    notifyListeners();
  }

  (ArchitectProject, StructuralGridAxis)? commitDrafting({
    required ArchitectProject project,
    required bool isBulgarian,
    double parallelToleranceRad = .01,
  }) {
    if (!_isDrafting || _draftStart == null || _draftEnd == null) {
      cancelDrafting();
      return null;
    }

    final p1 = _draftStart!;
    final p2 = _draftEnd!;
    final len = (p2 - p1).distance;
    if (len < 0.30) {
      // Ignore accidental micro-taps
      cancelDrafting();
      return null;
    }

    final suggestedName = getSuggestedAxisName(
      p1,
      p2,
      project.gridAxes,
      isBulgarian,
    );
    final rawAxis = StructuralGridAxis(
      id: ArchitectElementId.next('axis'),
      name: suggestedName,
      start: p1,
      end: p2,
      bubbleAtStart: true,
      bubbleAtEnd: true,
    );

    // Auto-align extents if a parallel axis exists
    final alignedAxis = alignNewAxis(
      rawAxis,
      project.gridAxes,
      toleranceRad: parallelToleranceRad,
    );

    final updatedAxes = resequenceAxes([
      ...project.gridAxes,
      alignedAxis,
    ], isBulgarian);
    final finalAxis = updatedAxes.firstWhere(
      (a) => a.id == alignedAxis.id,
      orElse: () => alignedAxis,
    );

    _isDrafting = false;
    _draftStart = null;
    _draftAnchor = null;
    _draftEnd = null;
    _draftSnapLabel = null;
    _selectedAxisId = finalAxis.id;
    notifyListeners();

    return (project.copyWithGridAxes(updatedAxes), finalAxis);
  }

  void cancelDrafting() {
    _isDrafting = false;
    _draftStart = null;
    _draftAnchor = null;
    _draftEnd = null;
    _draftSnapLabel = null;
    notifyListeners();
  }

  // === SECTION: HANDLE DRAGGING (EXTENT STRETCHING) ===

  static StructuralGridAxis alignNewAxis(
    StructuralGridAxis axis,
    List<StructuralGridAxis> axes, {
    double toleranceRad = .01,
  }) {
    return BimAxisOperations.alignNew(axis, axes, toleranceRad: toleranceRad);
  }

  static List<StructuralGridAxis> alignParallelAxes(
    List<StructuralGridAxis> axes,
    StructuralGridAxis reference,
  ) => BimAxisOperations.alignParallel(axes, reference);

  List<StructuralGridAxis> previewAxes(List<StructuralGridAxis> axes) {
    final reference = _isDraggingHandle
        ? _draggedAxisSnapshot
        : _isMovingAxis &&
              _moveOriginalAxis != null &&
              _moveCurrentDelta != null
        ? _moveOriginalAxis!.copyWith(
            start: _moveOriginalAxis!.start + _moveCurrentDelta!,
            end: _moveOriginalAxis!.end + _moveCurrentDelta!,
          )
        : null;
    return reference == null ? axes : alignParallelAxes(axes, reference);
  }

  (ArchitectProject, StructuralGridAxis)? placeOnWall({
    required ArchitectProject project,
    required ArchitectWall wall,
    required bool isBulgarian,
  }) {
    final raw = StructuralGridAxis(
      id: ArchitectElementId.next('axis'),
      name: '',
      start: wall.coreCenterStart,
      end: wall.coreCenterEnd,
    );
    final existing = project.gridAxes
        .where(
          (a) =>
              a.length >= .001 &&
              a.isParallelTo(raw, toleranceRad: 1e-6) &&
              (a.projectPoint(raw.start) - raw.start).distance < 1e-6,
        )
        .firstOrNull;
    if (existing != null) {
      selectAxis(existing.id);
      return (project, existing);
    }
    startDrafting(raw.start);
    _draftEnd = raw.end;
    return commitDrafting(
      project: project,
      isBulgarian: isBulgarian,
      parallelToleranceRad: 1e-8,
    );
  }

  void startHandleDrag(StructuralGridAxis axis, bool isStart) {
    _isDraggingHandle = true;
    _isStartHandle = isStart;
    _selectedAxisId = axis.id;
    _draggedAxisSnapshot = axis;
    _handleOriginalAxis = axis;
    notifyListeners();
  }

  void updateHandleDrag(
    Offset rawModelPoint,
    List<StructuralGridAxis> allAxes,
    double scale,
  ) {
    if (!_isDraggingHandle || _draggedAxisSnapshot == null) return;
    _draggedAxisSnapshot = BimAxisOperations.handlePreview(
      original: _handleOriginalAxis!,
      startHandle: _isStartHandle,
      point: rawModelPoint,
      axes: allAxes,
      captureRadius: math.min(16 / scale, .20),
    );
    notifyListeners();
  }

  ArchitectProject? commitHandleDrag(
    ArchitectProject project,
    bool isBulgarian,
  ) {
    if (!_isDraggingHandle || _draggedAxisSnapshot == null) {
      cancelHandleDrag();
      return null;
    }
    final updated = _draggedAxisSnapshot!;
    if (updated.length < .30) {
      cancelHandleDrag();
      return null;
    }
    final newAxes = alignParallelAxes(project.gridAxes, updated);
    _isDraggingHandle = false;
    _draggedAxisSnapshot = null;
    _handleOriginalAxis = null;
    notifyListeners();
    return project.copyWithGridAxes(newAxes);
  }

  void cancelHandleDrag() {
    _isDraggingHandle = false;
    _draggedAxisSnapshot = null;
    _handleOriginalAxis = null;
    notifyListeners();
  }

  // === SECTION: AXIS BODY TRANSLATION (MOVING) ===

  void startMoving(StructuralGridAxis axis, Offset startPoint) {
    _isMovingAxis = true;
    _moveStartPoint = startPoint;
    _moveOriginalAxis = axis;
    _moveCurrentDelta = Offset.zero;
    _selectedAxisId = axis.id;
    notifyListeners();
  }

  void updateMoving(
    Offset rawModelPoint,
    List<StructuralGridAxis> allAxes,
    double scale,
  ) {
    if (!_isMovingAxis ||
        _moveStartPoint == null ||
        _moveOriginalAxis == null) {
      return;
    }
    _moveCurrentDelta = BimAxisOperations.movingDelta(
      original: _moveOriginalAxis!,
      delta: rawModelPoint - _moveStartPoint!,
      axes: allAxes,
      captureRadius: math.min(12 / scale, .20),
    );
    notifyListeners();
  }

  ArchitectProject? commitMoving(ArchitectProject project, bool isBulgarian) {
    if (!_isMovingAxis ||
        _moveOriginalAxis == null ||
        _moveCurrentDelta == null) {
      cancelMoving();
      return null;
    }
    final orig = _moveOriginalAxis!;
    final delta = _moveCurrentDelta!;
    final movedAxis = orig.copyWith(
      start: orig.start + delta,
      end: orig.end + delta,
    );

    final updatedAxes = alignParallelAxes(project.gridAxes, movedAxis);
    final resequenced = resequenceAxes(updatedAxes, isBulgarian);

    _isMovingAxis = false;
    _moveStartPoint = null;
    _moveOriginalAxis = null;
    _moveCurrentDelta = null;
    _selectedAxisId = movedAxis.id;
    notifyListeners();

    return project.copyWithGridAxes(resequenced);
  }

  void cancelMoving() {
    _isMovingAxis = false;
    _moveStartPoint = null;
    _moveOriginalAxis = null;
    _moveCurrentDelta = null;
    notifyListeners();
  }

  // === SECTION: AUTO-ALIGNMENT & AUTO-RESEQUENCING ===

  /// Aligns extents of [axis] to parallel reference axes.
  ArchitectProject alignSelectedAxis(
    ArchitectProject project,
    bool isBulgarian,
  ) {
    final selected = getSelectedAxis(project);
    if (selected == null) return project;

    final parallel = project.gridAxes
        .where(
          (a) =>
              a.id != selected.id &&
              a.isParallelTo(selected, toleranceRad: 0.10),
        )
        .firstOrNull;

    if (parallel == null) return project;

    final aligned = selected.alignWith(parallel);
    final updatedAxes = project.gridAxes
        .map((a) => a.id == aligned.id ? aligned : a)
        .toList();
    _selectedAxisId = aligned.id;
    notifyListeners();

    return project.copyWithGridAxes(updatedAxes);
  }

  /// Aligns extents of all parallel groups across the project.
  ArchitectProject alignAllAxes(ArchitectProject project, bool isBulgarian) {
    final aligned = ProjectGridAxes.alignExtents(project.gridAxes);
    final resequenced = resequenceAxes(aligned, isBulgarian);
    notifyListeners();
    return project.copyWithGridAxes(resequenced);
  }

  /// Automatically re-sequences (auto-numbers/letters) all axes according to their geometric position.
  ArchitectProject resequenceAllAxes(
    ArchitectProject project,
    bool isBulgarian,
  ) {
    final resequenced = resequenceAxes(project.gridAxes, isBulgarian);
    notifyListeners();
    return project.copyWithGridAxes(resequenced);
  }

  /// Renames the selected axis to the next available sequential name.
  ArchitectProject? renameSelectedAxis(
    ArchitectProject project,
    bool isBulgarian,
  ) {
    final selected = getSelectedAxis(project);
    if (selected == null) return null;

    var nextName = getNextAxisName(selected.name, isBulgarian);
    final used = project.gridAxes
        .where((a) => a.id != selected.id)
        .map((a) => a.name)
        .toSet();

    while (used.contains(nextName)) {
      nextName = getNextAxisName(nextName, isBulgarian);
    }

    final updated = selected.copyWith(name: nextName);
    final newAxes = project.gridAxes
        .map((a) => a.id == updated.id ? updated : a)
        .toList();

    _selectedAxisId = updated.id;
    notifyListeners();
    return project.copyWithGridAxes(newAxes);
  }

  /// Deletes the currently selected axis and re-sequences the remaining axes.
  ArchitectProject? deleteSelectedAxis(
    ArchitectProject project,
    bool isBulgarian,
  ) {
    if (_selectedAxisId == null) return null;
    final remaining = project.gridAxes
        .where((a) => a.id != _selectedAxisId)
        .toList();
    final resequenced = resequenceAxes(remaining, isBulgarian);
    _selectedAxisId = null;
    notifyListeners();
    return project.copyWithGridAxes(resequenced);
  }

  /// Deletes a specific axis by id and re-sequences the remaining axes.
  ArchitectProject deleteAxisById(
    ArchitectProject project,
    String axisId,
    bool isBulgarian,
  ) {
    final remaining = project.gridAxes.where((a) => a.id != axisId).toList();
    final resequenced = resequenceAxes(remaining, isBulgarian);
    if (_selectedAxisId == axisId) {
      _selectedAxisId = null;
    }
    notifyListeners();
    return project.copyWithGridAxes(resequenced);
  }

  // === SECTION: OFFSET & DUPLICATION ENGINE ===

  void startOffsetDrag(StructuralGridAxis axis, double distanceMeters) {
    _isOffsettingWithDrag = true;
    _axisBeingOffset = axis;
    _offsetDistanceMeters = distanceMeters;
    _currentOffsetSign = 1.0;
    notifyListeners();
  }

  void updateOffsetDrag(Offset modelPt) {
    if (!_isOffsettingWithDrag || _axisBeingOffset == null) return;
    final newSign = BimAxisOperations.offsetSign(
      _axisBeingOffset!,
      modelPt,
      previous: _currentOffsetSign,
    );

    if (newSign != _currentOffsetSign) {
      _currentOffsetSign = newSign;
      notifyListeners();
    }
  }

  StructuralGridAxis? getOffsetPreview(bool isBulgarian) {
    if (!_isOffsettingWithDrag || _axisBeingOffset == null) return null;
    final axis = _axisBeingOffset!;
    final offsetVec = axis.computeOffsetVector(
      _offsetDistanceMeters,
      _currentOffsetSign,
    );
    return axis.copyWith(
      id: 'preview_offset',
      name: getNextAxisName(axis.name, isBulgarian),
      start: axis.start + offsetVec,
      end: axis.end + offsetVec,
    );
  }

  (ArchitectProject, StructuralGridAxis) applyOffset({
    required ArchitectProject project,
    required StructuralGridAxis originalAxis,
    required double distanceMeters,
    required double directionSign,
    required bool isBulgarian,
  }) {
    _offsetDistanceMeters = distanceMeters;
    final offsetVec = originalAxis.computeOffsetVector(
      distanceMeters,
      directionSign,
    );
    final nextName = getNextAxisName(originalAxis.name, isBulgarian);

    final newAxis = originalAxis.copyWith(
      id: ArchitectElementId.next('axis'),
      name: nextName,
      start: originalAxis.start + offsetVec,
      end: originalAxis.end + offsetVec,
    );

    final updatedAxes = resequenceAxes([
      ...project.gridAxes,
      newAxis,
    ], isBulgarian);
    final finalAxis = updatedAxes.firstWhere(
      (a) => a.id == newAxis.id,
      orElse: () => newAxis,
    );

    _isOffsettingWithDrag = false;
    _axisBeingOffset = null;
    _selectedAxisId = finalAxis.id;
    notifyListeners();

    return (project.copyWithGridAxes(updatedAxes), finalAxis);
  }

  void cancelOffsetDrag() {
    _isOffsettingWithDrag = false;
    _axisBeingOffset = null;
    notifyListeners();
  }

  void cancelAll() {
    _isDrafting = false;
    _draftStart = null;
    _draftAnchor = null;
    _draftEnd = null;
    _draftSnapLabel = null;
    _isDraggingHandle = false;
    _draggedAxisSnapshot = null;
    _handleOriginalAxis = null;
    _isMovingAxis = false;
    _moveStartPoint = null;
    _moveOriginalAxis = null;
    _moveCurrentDelta = null;
    _isOffsettingWithDrag = false;
    _axisBeingOffset = null;
    notifyListeners();
  }

  // === SECTION: GEOMETRIC & NAMING HELPERS ===

  static List<StructuralGridAxis> resequenceAxes(
    List<StructuralGridAxis> axes,
    bool isBulgarian,
  ) {
    return resequenceGridAxes(axes, isBulgarian: isBulgarian);
  }

  static String getSuggestedAxisName(
    Offset start,
    Offset end,
    List<StructuralGridAxis> axes,
    bool isBulgarian,
  ) => BimAxisNaming.getSuggestedAxisName(start, end, axes, isBulgarian);
  static String getNextAxisName(String current, bool isBulgarian) =>
      BimAxisNaming.getNextAxisName(current, isBulgarian);
}
