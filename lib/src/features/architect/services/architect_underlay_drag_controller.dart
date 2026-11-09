import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';

import '../../bim_projects/models/bim_coordinate_frame.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../../dxf_viewer/rendering/dxf_snap_helper.dart';
import '../models/architect_project.dart';
import '../rendering/architect_snap_helper.dart';

/// Phase of the interactive 2-point underlay snap & drag workflow.
enum ArchitectUnderlayDragPhase {
  idle,
  pickingBasePoint,
  draggingToTarget,
}

/// Manages interactive 2-point underlay move:
/// 1. Pick reference base point on underlay (snaps to CAD/raster geometry).
/// 2. Drag with rubber-band line & dynamic ghost preview.
/// 3. Snap target to architectural drawing elements (axes, intersections, walls, columns).
/// 4. Commit updated origin/position strictly to the architectural model.
class ArchitectUnderlayDragController extends ChangeNotifier {
  ArchitectUnderlayDragPhase _phase = ArchitectUnderlayDragPhase.idle;
  bool _isCad = true;
  String? _rasterId;
  String _underlayName = '';
  String _storeyId = '';
  double _unitsPerMeter = 1.0;

  Offset? _originalCadOrigin;
  Offset? _originalRasterPosition;

  Offset? _basePointModel;
  Offset? _basePointCad;
  Offset? _currentPointModel;
  String? _currentSnapLabel;
  bool _isSnapped = false;
  List<(Offset, Offset)> _magneticGuides = const [];

  ArchitectUnderlayDragPhase get phase => _phase;
  bool get isIdle => _phase == ArchitectUnderlayDragPhase.idle;
  bool get isPickingBasePoint => _phase == ArchitectUnderlayDragPhase.pickingBasePoint;
  bool get isDraggingToTarget => _phase == ArchitectUnderlayDragPhase.draggingToTarget;
  bool get isActive => !isIdle;

  bool get isCad => _isCad;
  String? get rasterId => _rasterId;
  String get underlayName => _underlayName;
  String get storeyId => _storeyId;
  double get unitsPerMeter => _unitsPerMeter;

  Offset? get basePointModel => _basePointModel;
  Offset? get basePointCad => _basePointCad;
  Offset? get currentPointModel => _currentPointModel;
  String? get currentSnapLabel => _currentSnapLabel;
  bool get isSnapped => _isSnapped;
  List<(Offset, Offset)> get magneticGuides => _magneticGuides;

  Offset? get deltaModel {
    if (!isDraggingToTarget || _basePointModel == null || _currentPointModel == null) {
      return null;
    }
    return _currentPointModel! - _basePointModel!;
  }

  double get distanceMeters => deltaModel?.distance ?? 0.0;

  double get angleDeg {
    final d = deltaModel;
    if (d == null || d.distance < 1e-7) return 0.0;
    final deg = math.atan2(d.dy, d.dx) * 180.0 / math.pi;
    return deg < 0 ? deg + 360.0 : deg;
  }

  /// Real-time ghost coordinate frame for CAD underlay while dragging.
  BimCoordinateFrame? get ghostCadFrame {
    if (!isDraggingToTarget || !_isCad || _basePointCad == null || _currentPointModel == null) {
      return null;
    }
    final scale = _unitsPerMeter > 0 ? _unitsPerMeter : 1.0;
    final newOrigin = _basePointCad! - _currentPointModel! * scale;
    return BimCoordinateFrame(origin: newOrigin, unitsPerMeter: scale);
  }

  /// Real-time ghost top-left position for raster underlay while dragging.
  Offset? get ghostRasterPosition {
    if (!isDraggingToTarget || _isCad || _originalRasterPosition == null) {
      return null;
    }
    final d = deltaModel ?? Offset.zero;
    return _originalRasterPosition! + d;
  }

  /// Starts the 2-point drag session.
  void startDrag({
    required bool isCad,
    String? rasterId,
    required String underlayName,
    required String storeyId,
    required double unitsPerMeter,
    Offset? originalCadOrigin,
    Offset? originalRasterPosition,
  }) {
    _phase = ArchitectUnderlayDragPhase.pickingBasePoint;
    _isCad = isCad;
    _rasterId = rasterId;
    _underlayName = underlayName;
    _storeyId = storeyId;
    _unitsPerMeter = unitsPerMeter > 0 ? unitsPerMeter : 1.0;
    _originalCadOrigin = originalCadOrigin;
    _originalRasterPosition = originalRasterPosition;
    _basePointModel = null;
    _basePointCad = null;
    _currentPointModel = null;
    _currentSnapLabel = null;
    _isSnapped = false;
    _magneticGuides = const [];
    notifyListeners();
  }

  /// Updates pointer hover position and resolves snapping:
  /// - In [pickingBasePoint]: Snaps to underlay entities (CAD or raster).
  /// - In [draggingToTarget]: Snaps to architectural geometry (axes, walls, columns).
  void updateHover(
    Offset rawModelPoint, {
    required ArchitectProject project,
    DxfDocument? dxfDoc,
    BimCoordinateFrame? frame,
    ArchitectRasterUnderlay? raster,
    double scale = 1.0,
  }) {
    if (isIdle) return;

    if (isPickingBasePoint) {
      _resolveBasePointSnap(
        rawModelPoint,
        dxfDoc: dxfDoc,
        frame: frame ?? const BimCoordinateFrame(),
        raster: raster,
        scale: scale,
      );
    } else if (isDraggingToTarget) {
      _resolveTargetPointSnap(
        rawModelPoint,
        project: project,
        scale: scale,
      );
    }
    notifyListeners();
  }

  void _resolveBasePointSnap(
    Offset rawModelPoint, {
    DxfDocument? dxfDoc,
    required BimCoordinateFrame frame,
    ArchitectRasterUnderlay? raster,
    required double scale,
  }) {
    if (_isCad && dxfDoc != null) {
      final cadPoint = frame.toCad(rawModelPoint);
      final tolCad = (22.0 / math.max(scale, 1e-4)) * frame.unitsPerMeter;
      final snap = DxfSnapHelper.findSnapPoint(
        document: dxfDoc,
        cadPoint: cadPoint,
        toleranceCad: tolCad,
        includeIntersections: true,
      );

      if (snap != null) {
        _currentPointModel = frame.toModel(snap.point);
        _currentSnapLabel = snap.type.label;
        _isSnapped = true;
        _magneticGuides = const [];
        return;
      }
    } else if (!_isCad && raster != null) {
      final tolModel = 22.0 / math.max(scale, 1e-4);
      final corners = [
        raster.position,
        raster.position + Offset(raster.widthMeters, 0),
        raster.position + Offset(raster.widthMeters, raster.heightMeters),
        raster.position + Offset(0, raster.heightMeters),
        raster.position + Offset(raster.widthMeters / 2, raster.heightMeters / 2),
      ];
      final labels = ['Corner', 'Corner', 'Corner', 'Corner', 'Center'];

      for (var i = 0; i < corners.length; i++) {
        if ((rawModelPoint - corners[i]).distance <= tolModel) {
          _currentPointModel = corners[i];
          _currentSnapLabel = labels[i];
          _isSnapped = true;
          _magneticGuides = const [];
          return;
        }
      }
    }

    _currentPointModel = rawModelPoint;
    _currentSnapLabel = null;
    _isSnapped = false;
    _magneticGuides = const [];
  }

  void _resolveTargetPointSnap(
    Offset rawModelPoint, {
    required ArchitectProject project,
    required double scale,
  }) {
    final tol = (24.0 / math.max(scale, 1e-4)).clamp(0.05, 0.60);
    final snap = ArchitectSnapHelper.snapFree(
      rawPoint: rawModelPoint,
      project: project,
      tolerance: tol,
      preferIntersections: true,
    );

    if (snap.isSnapped) {
      _currentPointModel = snap.point;
      _currentSnapLabel = snap.snapLabel;
      _isSnapped = true;
      _magneticGuides = snap.magneticGuides;
    } else {
      _currentPointModel = snap.point;
      _currentSnapLabel = null;
      _isSnapped = false;
      _magneticGuides = const [];
    }
  }

  /// Confirms the picked base point and shifts phase to [draggingToTarget].
  bool confirmBasePoint({BimCoordinateFrame? frame}) {
    if (!isPickingBasePoint || _currentPointModel == null) return false;
    _basePointModel = _currentPointModel;
    final f = frame ?? BimCoordinateFrame(origin: _originalCadOrigin ?? Offset.zero, unitsPerMeter: _unitsPerMeter);
    _basePointCad = f.toCad(_basePointModel!);
    _phase = ArchitectUnderlayDragPhase.draggingToTarget;
    notifyListeners();
    return true;
  }

  /// Calculates the new CAD origin and translated mask.
  ({double newOriginX, double newOriginY, List<Offset>? translatedMask}) computeCadPlacement({
    required Offset targetPointModel,
    List<Offset>? existingMask,
  }) {
    final scale = _unitsPerMeter > 0 ? _unitsPerMeter : 1.0;
    final baseCad = _basePointCad ?? (_originalCadOrigin ?? Offset.zero);
    final newOriginX = baseCad.dx - targetPointModel.dx * scale;
    final newOriginY = baseCad.dy - targetPointModel.dy * scale;

    List<Offset>? translatedMask;
    final d = targetPointModel - (_basePointModel ?? targetPointModel);
    if (existingMask != null && existingMask.isNotEmpty) {
      translatedMask = [
        for (final pt in existingMask) pt + d,
      ];
    }

    return (
      newOriginX: newOriginX,
      newOriginY: newOriginY,
      translatedMask: translatedMask,
    );
  }

  /// Calculates the new Raster position and translated mask.
  ({Offset newPosition, List<Offset>? translatedMask}) computeRasterPlacement({
    required Offset targetPointModel,
    List<Offset>? existingMask,
  }) {
    final orig = _originalRasterPosition ?? Offset.zero;
    final d = targetPointModel - (_basePointModel ?? targetPointModel);
    final newPos = orig + d;

    List<Offset>? translatedMask;
    if (existingMask != null && existingMask.isNotEmpty) {
      translatedMask = [
        for (final pt in existingMask) pt + d,
      ];
    }

    return (
      newPosition: newPos,
      translatedMask: translatedMask,
    );
  }

  /// Cancels drag and resets controller to idle.
  void cancel() {
    _phase = ArchitectUnderlayDragPhase.idle;
    _basePointModel = null;
    _basePointCad = null;
    _currentPointModel = null;
    _currentSnapLabel = null;
    _isSnapped = false;
    _magneticGuides = const [];
    notifyListeners();
  }
}
