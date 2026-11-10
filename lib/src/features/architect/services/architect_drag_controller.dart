import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../models/architect_elements.dart';

/// Phase of the interactive element drag workflow.
enum ArchitectDragPhase {
  idle,
  pickingBasePoint,
  draggingToTarget,
}

/// Manages interactive element drag:
/// 1. Pick reference base point on element (or default).
/// 2. Drag with rubber-band line & dynamic ghost preview.
/// 3. Snap target to architectural drawing elements.
/// 4. Commit updated position strictly to the architectural model.
class ArchitectDragController extends ChangeNotifier {
  ArchitectDragPhase _phase = ArchitectDragPhase.idle;

  List<ArchitectElement> _elementsToDrag = [];
  Offset? _basePoint;
  Offset? _currentPoint;
  
  // Snap state
  String? _currentSnapLabel;
  bool _isSnapped = false;

  ArchitectDragPhase get phase => _phase;
  bool get isIdle => _phase == ArchitectDragPhase.idle;
  bool get isPickingBasePoint => _phase == ArchitectDragPhase.pickingBasePoint;
  bool get isDraggingToTarget => _phase == ArchitectDragPhase.draggingToTarget;
  bool get isActive => !isIdle;

  List<ArchitectElement> get elementsToDrag => _elementsToDrag;
  Offset? get basePoint => _basePoint;
  Offset? get currentPoint => _currentPoint;
  bool get isSnapped => _isSnapped;
  String? get currentSnapLabel => _currentSnapLabel;

  void startDrag(List<ArchitectElement> elements) {
    _elementsToDrag = elements;
    _phase = ArchitectDragPhase.pickingBasePoint;
    notifyListeners();
  }

  void setBasePoint(Offset point) {
    _basePoint = point;
    _phase = ArchitectDragPhase.draggingToTarget;
    notifyListeners();
  }

  void updatePosition(Offset point, {bool isSnapped = false, String? snapLabel}) {
    _currentPoint = point;
    _isSnapped = isSnapped;
    _currentSnapLabel = snapLabel;
    notifyListeners();
  }

  void cancel() {
    _phase = ArchitectDragPhase.idle;
    _elementsToDrag = [];
    _basePoint = null;
    _currentPoint = null;
    notifyListeners();
  }
  
  void commit() {
    // Logic to commit changes to the elements in _elementsToDrag
    // ...
    cancel();
  }
}
