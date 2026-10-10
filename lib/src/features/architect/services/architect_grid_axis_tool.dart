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

import '../models/architect_grid_axis.dart';
import '../models/architect_project.dart';
import '../rendering/architect_snap_helper.dart';

// === SECTION: TOOL CONTROLLER & STATE ===

/// Unified interaction controller and state machine for dynamic architectural grid axes.
class ArchitectGridAxisTool extends ChangeNotifier {
  // Drafting State
  bool _isDrafting = false;
  Offset? _draftStart;
  Offset? _draftEnd;
  String? _draftSnapLabel;

  // Selection & Handle Dragging State
  String? _selectedAxisId;
  bool _isDraggingHandle = false;
  bool _isStartHandle = true;
  StructuralGridAxis? _draggedAxisSnapshot;

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
    _draftEnd = point;
    _draftSnapLabel = null;
    _selectedAxisId = null;
    notifyListeners();
  }

  void updateDrafting(
    Offset rawModelPoint,
    ArchitectProject project,
    double scale,
  ) {
    if (!_isDrafting || _draftStart == null) return;

    final snap = ArchitectSnapHelper.snapWithAnchor(
      anchor: _draftStart!,
      rawPoint: rawModelPoint,
      project: project,
      tolerance: 14.0 / scale,
    );

    var candidate = snap.point;
    String? label = snap.snapLabel;

    // Check if we can align extents to an existing parallel axis in drafting
    final candidateDir = candidate - _draftStart!;
    if (candidateDir.distance > 0.3) {
      final isVert = candidateDir.dx.abs() <= candidateDir.dy.abs();
      for (final existing in project.gridAxes) {
        if (existing.isVertical == isVert) {
          // Snap extents along parallel direction
          if (isVert) {
            if ((candidate.dy - existing.end.dy).abs() < 16.0 / scale) {
              candidate = Offset(candidate.dx, existing.end.dy);
              label = 'Align';
            } else if ((candidate.dy - existing.start.dy).abs() < 16.0 / scale) {
              candidate = Offset(candidate.dx, existing.start.dy);
              label = 'Align';
            }
          } else {
            if ((candidate.dx - existing.end.dx).abs() < 16.0 / scale) {
              candidate = Offset(existing.end.dx, candidate.dy);
              label = 'Align';
            } else if ((candidate.dx - existing.start.dx).abs() < 16.0 / scale) {
              candidate = Offset(existing.start.dx, candidate.dy);
              label = 'Align';
            }
          }
        }
      }
    }

    _draftEnd = candidate;
    _draftSnapLabel = label;
    notifyListeners();
  }

  (ArchitectProject, StructuralGridAxis)? commitDrafting({
    required ArchitectProject project,
    required bool isBulgarian,
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

    final suggestedName = getSuggestedAxisName(p1, p2, project.gridAxes, isBulgarian);
    final rawAxis = StructuralGridAxis(
      id: 'axis_${DateTime.now().millisecondsSinceEpoch}',
      name: suggestedName,
      start: p1,
      end: p2,
      bubbleAtStart: true,
      bubbleAtEnd: true,
    );

    // Auto-align extents if a parallel axis exists
    final parallelAxis = project.gridAxes
        .where((a) => a.isParallelTo(rawAxis, toleranceRad: 0.10))
        .firstOrNull;
    final alignedAxis = parallelAxis != null ? rawAxis.alignWith(parallelAxis) : rawAxis;

    final updatedAxes = resequenceAxes([...project.gridAxes, alignedAxis], isBulgarian);
    final finalAxis = updatedAxes.firstWhere((a) => a.id == alignedAxis.id, orElse: () => alignedAxis);

    _isDrafting = false;
    _draftStart = null;
    _draftEnd = null;
    _draftSnapLabel = null;
    _selectedAxisId = finalAxis.id;
    notifyListeners();

    return (project.copyWithGridAxes(updatedAxes), finalAxis);
  }

  void cancelDrafting() {
    _isDrafting = false;
    _draftStart = null;
    _draftEnd = null;
    _draftSnapLabel = null;
    notifyListeners();
  }

  // === SECTION: HANDLE DRAGGING (EXTENT STRETCHING) ===

  void startHandleDrag(StructuralGridAxis axis, bool isStart) {
    _isDraggingHandle = true;
    _isStartHandle = isStart;
    _selectedAxisId = axis.id;
    _draggedAxisSnapshot = axis;
    notifyListeners();
  }

  void updateHandleDrag(
    Offset rawModelPoint,
    List<StructuralGridAxis> allAxes,
    double scale,
  ) {
    if (!_isDraggingHandle || _draggedAxisSnapshot == null) return;
    final axis = _draggedAxisSnapshot!;
    final proj = axis.projectPoint(rawModelPoint);

    var candidate = proj;

    // Magnetic snap to parallel axes extents (aligning bubbles)
    final u = axis.direction;
    for (final other in allAxes) {
      if (other.id == axis.id || !axis.isParallelTo(other, toleranceRad: 0.05)) continue;
      final otherExtent = _isStartHandle ? other.start : other.end;
      final alongOther = (otherExtent - axis.start).dx * u.dx + (otherExtent - axis.start).dy * u.dy;
      final extentTarget = axis.start + u * alongOther;
      if ((proj - extentTarget).distance <= 16.0 / scale) {
        candidate = extentTarget;
        break;
      }
    }

    _draggedAxisSnapshot = _isStartHandle
        ? axis.copyWith(start: candidate)
        : axis.copyWith(end: candidate);
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
    final newAxes = project.gridAxes.map((a) => a.id == updated.id ? updated : a).toList();
    _isDraggingHandle = false;
    _draggedAxisSnapshot = null;
    notifyListeners();
    return project.copyWithGridAxes(newAxes);
  }

  void cancelHandleDrag() {
    _isDraggingHandle = false;
    _draggedAxisSnapshot = null;
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
    if (!_isMovingAxis || _moveStartPoint == null || _moveOriginalAxis == null) return;
    final delta = rawModelPoint - _moveStartPoint!;
    final orig = _moveOriginalAxis!;

    var candidateDelta = delta;

    // Magnetic snap to other parallel axes spacing
    final normal = orig.normal;

    for (final other in allAxes) {
      if (other.id == orig.id || !orig.isParallelTo(other, toleranceRad: 0.05)) continue;
      final distToOther = ((orig.start + delta) - other.start).dx * normal.dx +
          ((orig.start + delta) - other.start).dy * normal.dy;
      if (distToOther.abs() <= 12.0 / scale) {
        // Snap perpendicular offset exactly to other axis position
        candidateDelta = delta - normal * distToOther;
        break;
      }
    }

    _moveCurrentDelta = candidateDelta;
    notifyListeners();
  }

  ArchitectProject? commitMoving(
    ArchitectProject project,
    bool isBulgarian,
  ) {
    if (!_isMovingAxis || _moveOriginalAxis == null || _moveCurrentDelta == null) {
      cancelMoving();
      return null;
    }
    final orig = _moveOriginalAxis!;
    final delta = _moveCurrentDelta!;
    final movedAxis = orig.copyWith(
      start: orig.start + delta,
      end: orig.end + delta,
    );

    final updatedAxes = project.gridAxes
        .map((a) => a.id == movedAxis.id ? movedAxis : a)
        .toList();
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
        .where((a) => a.id != selected.id && a.isParallelTo(selected, toleranceRad: 0.10))
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
  ArchitectProject alignAllAxes(
    ArchitectProject project,
    bool isBulgarian,
  ) {
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
    final axis = _axisBeingOffset!;
    final mid = (axis.start + axis.end) / 2.0;

    final double newSign;
    if (axis.isVertical) {
      newSign = (modelPt.dx >= mid.dx) ? 1.0 : -1.0;
    } else {
      newSign = (modelPt.dy >= mid.dy) ? 1.0 : -1.0;
    }

    if (newSign != _currentOffsetSign) {
      _currentOffsetSign = newSign;
      notifyListeners();
    }
  }

  StructuralGridAxis? getOffsetPreview(bool isBulgarian) {
    if (!_isOffsettingWithDrag || _axisBeingOffset == null) return null;
    final axis = _axisBeingOffset!;
    final offsetVec = axis.computeOffsetVector(_offsetDistanceMeters, _currentOffsetSign);
    return StructuralGridAxis(
      id: 'preview_offset',
      name: getNextAxisName(axis.name, isBulgarian),
      start: axis.start + offsetVec,
      end: axis.end + offsetVec,
      bubbleAtStart: axis.bubbleAtStart,
      bubbleAtEnd: axis.bubbleAtEnd,
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
    final offsetVec = originalAxis.computeOffsetVector(distanceMeters, directionSign);
    final nextName = getNextAxisName(originalAxis.name, isBulgarian);

    final newAxis = StructuralGridAxis(
      id: 'axis_${DateTime.now().millisecondsSinceEpoch}',
      name: nextName,
      start: originalAxis.start + offsetVec,
      end: originalAxis.end + offsetVec,
      bubbleAtStart: originalAxis.bubbleAtStart,
      bubbleAtEnd: originalAxis.bubbleAtEnd,
    );

    final updatedAxes = resequenceAxes([...project.gridAxes, newAxis], isBulgarian);
    final finalAxis = updatedAxes.firstWhere((a) => a.id == newAxis.id, orElse: () => newAxis);

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
    _draftEnd = null;
    _draftSnapLabel = null;
    _isDraggingHandle = false;
    _draggedAxisSnapshot = null;
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
    List<StructuralGridAxis> existingAxes,
    bool isBulgarian,
  ) {
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    final isVertical = (math.cos(angle).abs() <= math.sin(angle).abs());

    final sameDirAxes = existingAxes.where((a) => a.isVertical == isVertical).toList();

    const cyrillic = ['А', 'Б', 'В', 'Г', 'Д', 'Е', 'Ж', 'З', 'И', 'К', 'Л', 'М', 'Н', 'О', 'П', 'Р', 'С', 'Т', 'У', 'Ф', 'Х', 'Ц', 'Ч', 'Ш', 'Щ'];
    const latin = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K', 'L', 'M', 'N', 'P', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'];
    final letters = isBulgarian ? cyrillic : latin;

    if (sameDirAxes.isNotEmpty) {
      final hasNumbers = sameDirAxes.any((a) => int.tryParse(a.name) != null);
      if (hasNumbers) {
        int maxNum = 0;
        for (final a in sameDirAxes) {
          final val = int.tryParse(a.name);
          if (val != null && val > maxNum) maxNum = val;
        }
        return (maxNum + 1).toString();
      } else {
        int maxIdx = -1;
        for (final a in sameDirAxes) {
          final idx = letters.indexOf(a.name.toUpperCase());
          if (idx > maxIdx) maxIdx = idx;
        }
        if (maxIdx != -1 && maxIdx + 1 < letters.length) {
          return letters[maxIdx + 1];
        }
        return getNextAxisName(sameDirAxes.last.name, isBulgarian);
      }
    }

    final otherDirAxes = existingAxes.where((a) => a.isVertical != isVertical).toList();
    if (otherDirAxes.isNotEmpty) {
      final otherHasNumbers = otherDirAxes.any((a) => int.tryParse(a.name) != null);
      if (otherHasNumbers) {
        return letters.first;
      } else {
        return '1';
      }
    }

    return isVertical ? '1' : letters.first;
  }

  static String getNextAxisName(String current, bool isBulgarian) {
    final num = int.tryParse(current);
    if (num != null) {
      return (num + 1).toString();
    }
    const cyrillic = ['А', 'Б', 'В', 'Г', 'Д', 'Е', 'Ж', 'З', 'И', 'К', 'Л', 'М', 'Н', 'О', 'П', 'Р', 'С', 'Т', 'У', 'Ф', 'Х', 'Ц', 'Ч', 'Ш', 'Щ'];
    const latin = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K', 'L', 'M', 'N', 'P', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'];
    final letters = isBulgarian ? cyrillic : latin;
    final idx = letters.indexOf(current.toUpperCase());
    if (idx != -1 && idx + 1 < letters.length) {
      return letters[idx + 1];
    }
    return '${current}_1';
  }
}
