import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';

import '../../bim_projects/models/bim_coordinate_frame.dart';
import '../../bim_editing/geometry/bim_line_geometry.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../../dxf_viewer/rendering/dxf_snap_helper.dart';
import '../models/architect_project.dart';
import '../rendering/architect_snap_helper.dart';

/// Phase of the interactive 2-point snap Drag workflow.
enum ArchitectDragPhase { idle, pickingBasePoint, draggingToTarget }

/// Manages interactive 2-point snap & drag workflow for any architectural element:
/// - Walls, furniture/components, slabs, columns, beams, roofs, zones, openings, CAD primitives
/// - CAD underlays and Raster underlays
///
/// Interaction lifecycle:
/// 1. Phase [pickingBasePoint]:
///    - Shows default offset leader handle with grip dot ("изнесена линия с точка").
///    - Aims anywhere on or outside the selected element(s), without moving them.
///    - Release locks the base; a separate gesture places the target.
/// 2. Phase [draggingToTarget]:
///    - Base point is locked. Rubber-band leader line connects base point to target.
///    - Distance and angle badge (`L=...m  ...°`) and magnetic guides.
///    - Snaps to all other elements in the project (`excludedIds: selectedElementIds`).
///    - Live ghost preview updates in real-time.
/// 3. Commit:
///    - Commits the displacement strictly to the architectural model via CommandController / Underlay config.
class ArchitectDragController extends ChangeNotifier {
  ArchitectDragPhase _phase = ArchitectDragPhase.idle;

  Set<String> _elementIds = {};
  bool _isUnderlay = false;
  bool _isCadUnderlay = false;
  String? _rasterId;
  String _underlayName = '';
  String _storeyId = '';
  double _unitsPerMeter = 1.0;

  Offset? _originalCadOrigin;
  Offset? _originalRasterPosition;

  Offset? _defaultHandleAnchor;
  Offset? _defaultHandleGrip;
  bool _showBaseHandle = true;

  Offset? _basePointModel;
  Offset? _basePointCad;
  Offset? _currentPointModel;
  String? _currentSnapLabel;
  bool _isSnapped = false;
  List<(Offset, Offset)> _magneticGuides = const [];

  ArchitectDragPhase get phase => _phase;
  bool get isIdle => _phase == ArchitectDragPhase.idle;
  bool get isPickingBasePoint => _phase == ArchitectDragPhase.pickingBasePoint;
  bool get isDraggingToTarget => _phase == ArchitectDragPhase.draggingToTarget;
  bool get isActive => !isIdle;

  Set<String> get elementIds => _elementIds;
  bool get isUnderlay => _isUnderlay;
  bool get isCadUnderlay => _isCadUnderlay;
  String? get rasterId => _rasterId;
  String get underlayName => _underlayName;
  String get storeyId => _storeyId;
  double get unitsPerMeter => _unitsPerMeter;

  Offset? get defaultHandleAnchor => _defaultHandleAnchor;
  Offset? get defaultHandleGrip => _defaultHandleGrip;
  bool get showBaseHandle => _showBaseHandle;

  Offset? get basePointModel => _basePointModel;
  Offset? get basePointCad => _basePointCad;
  Offset? get currentPointModel => _currentPointModel;
  String? get currentSnapLabel => _currentSnapLabel;
  bool get isSnapped => _isSnapped;
  List<(Offset, Offset)> get magneticGuides => _magneticGuides;

  Offset? get deltaModel {
    if (!isDraggingToTarget ||
        _basePointModel == null ||
        _currentPointModel == null) {
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

  /// Ghost CAD frame for CAD underlay during drag.
  BimCoordinateFrame? get ghostCadFrame {
    if (!isDraggingToTarget ||
        !_isUnderlay ||
        !_isCadUnderlay ||
        _basePointCad == null ||
        _currentPointModel == null) {
      return null;
    }
    final scale = _unitsPerMeter > 0 ? _unitsPerMeter : 1.0;
    final newOrigin = _basePointCad! - _currentPointModel! * scale;
    return BimCoordinateFrame(origin: newOrigin, unitsPerMeter: scale);
  }

  /// Ghost top-left position for raster underlay during drag.
  Offset? get ghostRasterPosition {
    if (!isDraggingToTarget ||
        !_isUnderlay ||
        _isCadUnderlay ||
        _originalRasterPosition == null) {
      return null;
    }
    final d = deltaModel ?? Offset.zero;
    return _originalRasterPosition! + d;
  }

  /// Starts the Drag session.
  void startDrag({
    Set<String> elementIds = const {},
    bool isUnderlay = false,
    bool isCadUnderlay = false,
    String? rasterId,
    String underlayName = '',
    String storeyId = '',
    double unitsPerMeter = 1.0,
    Offset? originalCadOrigin,
    Offset? originalRasterPosition,
    Offset? defaultAnchor,
    double handleOffsetLength = 50.0,
    double zoomScale = 1.0,
  }) {
    _phase = ArchitectDragPhase.pickingBasePoint;
    _elementIds = Set<String>.from(elementIds);
    _isUnderlay = isUnderlay;
    _isCadUnderlay = isCadUnderlay;
    _rasterId = rasterId;
    _underlayName = underlayName;
    _storeyId = storeyId;
    _unitsPerMeter = unitsPerMeter > 0 ? unitsPerMeter : 1.0;
    _originalCadOrigin = originalCadOrigin;
    _originalRasterPosition = originalRasterPosition;

    _defaultHandleAnchor = defaultAnchor;
    _showBaseHandle = true;
    if (defaultAnchor != null) {
      final length = handleOffsetLength > 0 ? handleOffsetLength : 48.0;
      final scale = math.max(zoomScale, 1e-4);
      // Offset upward-right by default (screen coordinates: negative Y, positive X)
      final offsetModel = Offset(
        length * 0.7071 / scale,
        -length * 0.7071 / scale,
      );
      _defaultHandleGrip = defaultAnchor + offsetModel;
    } else {
      _defaultHandleGrip = null;
    }

    _basePointModel = null;
    _basePointCad = null;
    _currentPointModel = null;
    _currentSnapLabel = null;
    _isSnapped = false;
    _magneticGuides = const [];
    notifyListeners();
  }

  /// Updates pointer hover while in [pickingBasePoint].
  /// Snaps to the element(s) being dragged (walls, furniture, underlays, etc.).
  void updateBaseHover(
    Offset rawModelPoint, {
    required ArchitectProject project,
    double scale = 1.0,
    DxfDocument? dxfDoc,
    BimCoordinateFrame? frame,
    ArchitectRasterUnderlay? raster,
    bool snapToDefaultGrip = true,
    bool relocateHandle = false,
    bool showHandle = true,
  }) {
    if (_phase != ArchitectDragPhase.pickingBasePoint) return;
    _showBaseHandle = showHandle;

    final tolerance = (22.0 / math.max(scale, 1e-4)).clamp(0.08, 0.60);
    if (snapToDefaultGrip &&
        _defaultHandleGrip != null &&
        (rawModelPoint - _defaultHandleGrip!).distance <= tolerance) {
      _currentPointModel = _defaultHandleAnchor ?? _defaultHandleGrip;
      _currentSnapLabel = 'Grip';
      _isSnapped = true;
      _magneticGuides = const [];
      notifyListeners();
      return;
    }

    if (_isUnderlay) {
      _resolveUnderlayBaseSnap(
        rawModelPoint,
        dxfDoc: dxfDoc,
        frame: frame ?? const BimCoordinateFrame(),
        raster: raster,
        scale: scale,
      );
    } else {
      _resolveElementBaseSnap(rawModelPoint, project: project, scale: scale);
    }
    // A base may also be an existing point elsewhere in the drawing.
    if (!_isSnapped) {
      final snap = ArchitectSnapHelper.snapFree(
        rawPoint: rawModelPoint,
        project: project,
        tolerance: tolerance,
        magnetic: true,
        underlay: _isCadUnderlay ? null : dxfDoc,
        frame: frame ?? const BimCoordinateFrame(),
      );
      _currentPointModel = snap.point;
      _currentSnapLabel = snap.snapLabel;
      _isSnapped = snap.isSnapped;
      _magneticGuides = snap.magneticGuides;
    }
    if (relocateHandle &&
        _defaultHandleAnchor != null &&
        _defaultHandleGrip != null &&
        _currentPointModel != null) {
      final offset = _defaultHandleGrip! - _defaultHandleAnchor!;
      _defaultHandleAnchor = _currentPointModel;
      _defaultHandleGrip = _currentPointModel! + offset;
    }
    notifyListeners();
  }

  void _resolveElementBaseSnap(
    Offset rawModelPoint, {
    required ArchitectProject project,
    required double scale,
  }) {
    final tolerance = (22.0 / math.max(scale, 1e-4)).clamp(0.08, 0.60);

    // Prefer features of the selected elements before other drawing geometry.
    if (_elementIds.isNotEmpty) {
      final snap = ArchitectSnapHelper.snapFree(
        rawPoint: rawModelPoint,
        project: project,
        tolerance: tolerance,
        magnetic: true,
        alignment: false,
        includedIds: _elementIds,
      );
      if (snap.isSnapped) {
        _currentPointModel = snap.point;
        _currentSnapLabel = snap.snapLabel;
        _isSnapped = true;
        _magneticGuides = const [];
        return;
      }
    }

    _currentPointModel = rawModelPoint;
    _currentSnapLabel = null;
    _isSnapped = false;
    _magneticGuides = const [];
  }

  void _resolveUnderlayBaseSnap(
    Offset rawModelPoint, {
    DxfDocument? dxfDoc,
    required BimCoordinateFrame frame,
    ArchitectRasterUnderlay? raster,
    required double scale,
  }) {
    final tolModel = (22.0 / math.max(scale, 1e-4)).clamp(0.08, 0.60);

    if (_isCadUnderlay && dxfDoc != null) {
      final originModel = frame.toModel(Offset.zero);
      if ((rawModelPoint - originModel).distance <= tolModel) {
        _currentPointModel = originModel;
        _currentSnapLabel = 'Origin (0,0)';
        _isSnapped = true;
        _magneticGuides = const [];
        return;
      }
      final centerModel = frame.toModel(dxfDoc.bounds.center);
      if ((rawModelPoint - centerModel).distance <= tolModel) {
        _currentPointModel = centerModel;
        _currentSnapLabel = 'Center';
        _isSnapped = true;
        _magneticGuides = const [];
        return;
      }
      final cadPoint = frame.toCad(rawModelPoint);
      final tolCad = tolModel * frame.unitsPerMeter;
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
    } else if (!_isCadUnderlay && raster != null) {
      final corners = [
        ...raster.localCorners,
        raster.pixelToLocal(
          Offset(raster.imageWidthPx / 2, raster.imageHeightPx / 2),
        ),
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
      for (var i = 0; i < 4; i++) {
        final a = corners[i], b = corners[(i + 1) % 4];
        final midpoint = (a + b) / 2;
        final nearest = BimLineGeometry.closest(rawModelPoint, a, b);
        final atMidpoint = (rawModelPoint - midpoint).distance <= tolModel;
        if (atMidpoint || (rawModelPoint - nearest).distance <= tolModel) {
          _currentPointModel = atMidpoint ? midpoint : nearest;
          _currentSnapLabel = atMidpoint ? 'Midpoint' : 'Edge';
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

  /// Locks in the chosen base point and transitions to [draggingToTarget].
  void grabBasePoint(Offset basePoint, {BimCoordinateFrame? frame}) {
    _basePointModel = basePoint;
    if (_isUnderlay && _isCadUnderlay && frame != null) {
      _basePointCad = frame.toCad(basePoint);
    }
    _currentPointModel = basePoint;
    _phase = ArchitectDragPhase.draggingToTarget;
    _isSnapped = false;
    _currentSnapLabel = null;
    _magneticGuides = const [];
    notifyListeners();
  }

  /// Updates pointer position and snaps target to all other architectural geometry.
  void updateTargetHover(
    Offset rawModelPoint, {
    required ArchitectProject project,
    double scale = 1.0,
    DxfDocument? dxfDoc,
    BimCoordinateFrame frame = const BimCoordinateFrame(),
    Map<String, bool> visibility = const {},
  }) {
    if (_phase != ArchitectDragPhase.draggingToTarget ||
        _basePointModel == null) {
      return;
    }

    final tolerance = (22.0 / math.max(scale, 1e-4)).clamp(0.08, 0.60);

    // Snap to the project excluding the element(s) being moved
    final snap = ArchitectSnapHelper.snapWithAnchor(
      anchor: _basePointModel!,
      rawPoint: rawModelPoint,
      project: project,
      tolerance: tolerance,
      magnetic: true,
      alignment: true,
      excludedIds: _elementIds,
      underlay: _isCadUnderlay ? null : dxfDoc,
      frame: frame,
      visibility: visibility,
    );

    _currentPointModel = snap.point;
    _isSnapped = snap.isSnapped;
    _currentSnapLabel = snap.snapLabel;
    _magneticGuides = snap.magneticGuides;
    notifyListeners();
  }

  /// Calculates the new CAD origin and translated mask.
  ({double newOriginX, double newOriginY, List<Offset>? translatedMask})
  computeCadPlacement({
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
      translatedMask = [for (final pt in existingMask) pt + d];
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
      translatedMask = [for (final pt in existingMask) pt + d];
    }

    return (newPosition: newPos, translatedMask: translatedMask);
  }

  /// Cancels the Drag session and resets state.
  void cancel() {
    _phase = ArchitectDragPhase.idle;
    _elementIds = {};
    _isUnderlay = false;
    _isCadUnderlay = false;
    _rasterId = null;
    _defaultHandleAnchor = null;
    _defaultHandleGrip = null;
    _basePointModel = null;
    _basePointCad = null;
    _currentPointModel = null;
    _currentSnapLabel = null;
    _isSnapped = false;
    _magneticGuides = const [];
    notifyListeners();
  }

  void reset() => cancel();
}
