import 'package:flutter/foundation.dart';

/// History for immutable native documents. The host supplies semantic equality
/// and keeps view state separate from model changes.
class BimEditHistory<T> {
  BimEditHistory({this.limit = 100, bool Function(T, T)? equivalent})
    : assert(limit > 0),
      equivalent = equivalent ?? identical;

  final int limit;
  final bool Function(T, T) equivalent;
  final List<T> _undo = [];
  final List<T> _redo = [];
  T? _staged;
  bool _hasStaged = false;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// Native hosts can stage a baseline before validation, then publish only
  /// after an accepted edit. Staging alone never changes Undo or Redo.
  void stage(T before) {
    if (_hasStaged) return;
    _staged = before;
    _hasStaged = true;
  }

  bool publish(T after) {
    if (!_hasStaged) return false;
    final before = _staged as T;
    cancelStaged();
    return record(before, after);
  }

  void cancelStaged() {
    _staged = null;
    _hasStaged = false;
  }

  /// Bridge for hosts that still checkpoint before mutating their document.
  void checkpoint(T before) {
    if (_undo.isEmpty || !equivalent(_undo.last, before)) _undo.add(before);
    if (_undo.length > limit) _undo.removeAt(0);
    _redo.clear();
  }

  bool record(T before, T after) {
    if (equivalent(before, after)) return false;
    checkpoint(before);
    return true;
  }

  T undo(T current) {
    cancelStaged();
    while (_undo.isNotEmpty && equivalent(_undo.last, current)) {
      _undo.removeLast();
    }
    if (_undo.isEmpty) return current;
    _redo.add(current);
    return _undo.removeLast();
  }

  T redo(T current) {
    cancelStaged();
    if (_redo.isEmpty) return current;
    _undo.add(current);
    return _redo.removeLast();
  }

  void clear() {
    cancelStaged();
    _undo.clear();
    _redo.clear();
  }
}

/// Publishes an entire batch only after every operation has succeeded.
class BimTransactionController<T> extends ChangeNotifier {
  BimTransactionController(
    this._value, {
    int historyLimit = 100,
    bool Function(T, T)? equivalent,
    this.restoreView,
  }) : history = BimEditHistory<T>(limit: historyLimit, equivalent: equivalent);

  T _value;
  final BimEditHistory<T> history;
  final T Function(T snapshot, T current)? restoreView;
  T get value => _value;
  bool get canUndo => history.canUndo;
  bool get canRedo => history.canRedo;

  void commit(T next) {
    if (!history.record(_value, next)) return;
    _value = next;
    notifyListeners();
  }

  T applyBatch(Iterable<T Function(T)> operations) {
    var next = _value;
    for (final operation in operations) {
      next = operation(next);
    }
    commit(next);
    return _value;
  }

  void replaceView(T next) {
    if (identical(next, _value)) return;
    _value = next;
    notifyListeners();
  }

  void restore(T next) {
    _value = next;
    history.clear();
    notifyListeners();
  }

  void undo() => _restoreHistory(history.undo(_value));
  void redo() => _restoreHistory(history.redo(_value));
  void _restoreHistory(T snapshot) {
    if (identical(snapshot, _value)) return;
    _value = restoreView?.call(snapshot, _value) ?? snapshot;
    notifyListeners();
  }
}

/// Native adapters may compare their serialization at commit boundaries.
/// Preview and rendering do not serialize the scene.
bool bimValuesEqual(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!bimValuesEqual(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || !bimValuesEqual(a[key], b[key])) return false;
    }
    return true;
  }
  return a == b;
}
