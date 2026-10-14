import 'dart:ui';
import 'bim_edit_session.dart';

/// Shared move/Drag+ lifecycle in model metres. For Drag+, the host clones once
/// before construction; the draft identity and properties remain stable.
class BimDragSession<T> {
  BimDragSession({
    required Object context,
    required T original,
    required this.anchor,
    required this.translate,
  }) : _state = BimEditSession(context: context, original: original),
       _target = anchor;
  final BimEditSession<T> _state;
  final Offset anchor;
  final T Function(T original, Offset deltaMetres) translate;
  Offset _target;
  Offset _grabOffset = Offset.zero;
  T get original => _state.original;
  T get preview => _state.preview;
  Offset get target => _target;
  Offset get delta => _target - anchor;
  bool get isActive => _state.isActive;
  void grabAt(Offset pointer) => _grabOffset = anchor - pointer;
  Offset targetForPointer(Offset pointer) => pointer + _grabOffset;
  bool updateTarget(Object context, Offset target) {
    if (!target.dx.isFinite || !target.dy.isFinite) return false;
    if (!_state.update(
      context,
      (original) => translate(original, target - anchor),
    )) {
      return false;
    }
    _target = target;
    return true;
  }

  T? finish(Object context) =>
      _state.finish(context, changed: delta.distance > 1e-9);
  void cancel() {
    _state.cancel();
    _target = anchor;
    _grabOffset = Offset.zero;
  }
}
