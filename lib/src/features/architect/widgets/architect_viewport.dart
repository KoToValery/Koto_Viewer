import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../bim_projects/controllers/bim_viewport_controller.dart';
import '../../structural_designer/analysis/structural_pointer_interaction.dart';

/// A single owner for tool input and camera navigation, without gesture arenas.
class ArchitectViewport extends StatefulWidget {
  final BimViewportController controller;
  final Widget child;
  final Object? interactionKey;
  final bool singlePointerPan;
  final bool touchHoldToPlace;
  final bool holdToEdit;
  final ValueChanged<Offset>? onToolHoldStart;
  final bool Function(Offset)? onSelectionHold;
  final bool Function() isDraggingHandle;
  final ValueChanged<PointerDownEvent> onToolDown;
  final ValueChanged<PointerMoveEvent> onToolMove;
  final ValueChanged<PointerHoverEvent> onToolHover;
  final ValueChanged<PointerUpEvent> onToolUp;
  final VoidCallback onToolCancel;
  final ValueChanged<Size>? onFirstLayout;

  const ArchitectViewport({
    super.key,
    required this.controller,
    required this.child,
    this.interactionKey,
    required this.singlePointerPan,
    this.touchHoldToPlace = false,
    this.holdToEdit = false,
    this.onToolHoldStart,
    this.onSelectionHold,
    required this.isDraggingHandle,
    required this.onToolDown,
    required this.onToolMove,
    required this.onToolHover,
    required this.onToolUp,
    required this.onToolCancel,
    this.onFirstLayout,
  });

  @override
  State<ArchitectViewport> createState() => _ArchitectViewportState();
}

class _ArchitectViewportState extends State<ArchitectViewport> {
  final Map<int, Offset> _pointers = {};
  bool _navigation = false;
  bool _suppressRelease = false;
  bool _canPan = false;
  Offset? _down;
  bool _laidOut = false;
  Timer? _holdTimer;
  bool _held = false;
  PointerDownEvent? _pendingEditDown;

  @override
  void didUpdateWidget(covariant ArchitectViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.interactionKey != widget.interactionKey ||
        (!_held &&
            (oldWidget.touchHoldToPlace != widget.touchHoldToPlace ||
                oldWidget.holdToEdit != widget.holdToEdit))) {
      _holdTimer?.cancel();
      _held = false;
      _pendingEditDown = null;
      // A release from an earlier tool/floor can never execute the new tool.
      _suppressRelease = _pointers.isNotEmpty;
      _navigation = false;
      _canPan = false;
      _down = null;
    }
  }

  Offset get _focal =>
      _pointers.values.fold(Offset.zero, (a, b) => a + b) /
      _pointers.length.toDouble();
  double get _span => _pointers.length < 2
      ? 0
      : (_pointers.values.elementAt(0) - _pointers.values.elementAt(1))
            .distance;

  void _downEvent(PointerDownEvent event) {
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length > 1) {
      _holdTimer?.cancel();
      _held = false;
      widget.onToolCancel();
      _navigation = true;
      _suppressRelease = true;
      return;
    }
    _down = event.localPosition;
    _navigation =
        (event.buttons & (kMiddleMouseButton | kSecondaryMouseButton)) != 0;
    _suppressRelease = _navigation;
    final deferredEdit =
        !_navigation &&
        widget.holdToEdit &&
        event.kind == PointerDeviceKind.touch;
    _pendingEditDown = deferredEdit ? event : null;
    if (!_navigation && !deferredEdit) widget.onToolDown(event);
    _canPan =
        _navigation ||
        (widget.singlePointerPan &&
            !widget.isDraggingHandle() &&
            !(widget.touchHoldToPlace &&
                event.kind != PointerDeviceKind.touch));
    if (!_navigation &&
        (deferredEdit ||
            widget.onSelectionHold != null ||
            widget.touchHoldToPlace &&
                event.kind == PointerDeviceKind.touch &&
                !widget.isDraggingHandle())) {
      _holdTimer?.cancel();
      _holdTimer = Timer(
        deferredEdit
            ? const Duration(milliseconds: 280)
            : widget.touchHoldToPlace && !widget.isDraggingHandle()
            ? StructuralPointerInteraction.placementHoldDuration
            : const Duration(milliseconds: 450),
        () {
          if (!mounted ||
              _pointers.length != 1 ||
              _navigation ||
              _suppressRelease) {
            return;
          }
          if (_pendingEditDown != null) {
            final down = _pendingEditDown!;
            _pendingEditDown = null;
            widget.onToolDown(down);
            if (widget.isDraggingHandle()) {
              _held = true;
              _canPan = false;
              return;
            }
          }
          if (widget.onSelectionHold?.call(_focal) == true) {
            _held = true;
            _canPan = false;
            _suppressRelease = true;
          } else if (widget.touchHoldToPlace && !widget.isDraggingHandle()) {
            _held = true;
            _canPan = false;
            widget.onToolHoldStart?.call(_focal);
          }
        },
      );
    }
  }

  void _moveEvent(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    final previousFocal = _focal;
    final previousSpan = _span;
    _pointers[event.pointer] = event.localPosition;
    if (!_held &&
        _down != null &&
        (event.localPosition - _down!).distance > 8) {
      _holdTimer?.cancel();
    }
    if (_pointers.length > 1) {
      widget.controller.navigate(
        previousFocal: previousFocal,
        focal: _focal,
        scaleFactor: previousSpan > 1 ? _span / previousSpan : 1,
      );
      return;
    }
    if (_canPan &&
        !_navigation &&
        _down != null &&
        (event.localPosition - _down!).distance >
            (widget.touchHoldToPlace ? kTouchSlop : 8)) {
      _holdTimer?.cancel();
      _navigation = true;
      _suppressRelease = true;
      widget.onToolCancel();
      widget.controller.panBy(event.localPosition - _down!);
      return;
    }
    if (_navigation) {
      widget.controller.panBy(_focal - previousFocal);
    } else if (!_suppressRelease &&
        (!widget.touchHoldToPlace ||
            _held ||
            event.kind != PointerDeviceKind.touch)) {
      widget.onToolMove(event);
    }
  }

  void _upEvent(PointerUpEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _holdTimer?.cancel();
    if (_pendingEditDown == null &&
        !_suppressRelease &&
        !_navigation &&
        _pointers.length == 1) {
      widget.onToolUp(event);
    }
    _pointers.remove(event.pointer);
    if (_pointers.isEmpty) _reset();
  }

  void _reset() {
    _holdTimer?.cancel();
    _pendingEditDown = null;
    _held = false;
    _navigation = false;
    _suppressRelease = false;
    _canPan = false;
    _down = null;
  }

  void _cancel(PointerCancelEvent event) {
    _holdTimer?.cancel();
    _pointers.remove(event.pointer);
    _suppressRelease = true;
    widget.onToolCancel();
    if (_pointers.isEmpty) _reset();
  }

  void _signal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      final scroll = resolved as PointerScrollEvent;
      if (_pointers.isNotEmpty) {
        _holdTimer?.cancel();
        _suppressRelease = true;
        widget.onToolCancel();
      }
      widget.controller.navigate(
        previousFocal: scroll.localPosition,
        focal: scroll.localPosition,
        scaleFactor: math.exp(-scroll.scrollDelta.dy / 240),
      );
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      if (widget.controller.size != size) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          widget.controller.resize(size);
          if (!_laidOut) {
            _laidOut = true;
            widget.onFirstLayout?.call(size);
          }
        });
      }
      return ClipRect(
        child: Listener(
          key: const ValueKey('architect-viewport-input'),
          behavior: HitTestBehavior.opaque,
          onPointerDown: _downEvent,
          onPointerMove: _moveEvent,
          onPointerUp: _upEvent,
          onPointerCancel: _cancel,
          onPointerHover: widget.onToolHover,
          onPointerSignal: _signal,
          onPointerPanZoomStart: (_) {
            _holdTimer?.cancel();
            widget.onToolCancel();
            _suppressRelease = true;
            _lastTrackpadScale = 1;
          },
          onPointerPanZoomUpdate: (event) {
            widget.controller.navigate(
              previousFocal: event.localPosition + event.pan - event.panDelta,
              focal: event.localPosition + event.pan,
              scaleFactor: event.scale / _lastTrackpadScale,
            );
            _lastTrackpadScale = event.scale;
          },
          onPointerPanZoomEnd: (_) {
            _lastTrackpadScale = 1;
            if (_pointers.isEmpty) _reset();
          },
          child: SizedBox.expand(child: widget.child),
        ),
      );
    },
  );

  double _lastTrackpadScale = 1;

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }
}
