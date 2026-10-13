/// A preview belongs to the document revision, floor and tool that started it.
/// Context is supplied by the host; it never includes a camera transform.
class BimEditSession<T> {
  BimEditSession({required this.context, required this.original})
    : _preview = original;

  final Object context;
  final T original;
  T _preview;
  bool _closed = false;
  T get preview => _preview;
  bool get isActive => !_closed;

  bool update(Object currentContext, T Function(T original) operation) {
    if (_closed) return false;
    if (context != currentContext) {
      cancel();
      return false;
    }
    // Always derive from the baseline, avoiding accumulated rounding/drift.
    _preview = operation(original);
    return true;
  }

  T? finish(Object currentContext, {required bool changed}) {
    if (_closed) return null;
    _closed = true;
    return context == currentContext && changed ? _preview : null;
  }

  void cancel() {
    _closed = true;
    _preview = original;
  }
}
