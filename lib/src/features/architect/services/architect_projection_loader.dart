import 'dart:async';

/// One active calculation and one latest pending request. Obsolete workers
/// cannot publish geometry into another view or overwrite a newer model.
class ArchitectProjectionLoader<T> {
  final void Function() onChanged;
  Object? _source, _key;
  Future<T> Function()? _pending;
  var _revision = 0;
  var _running = false;
  var _disposed = false;
  T? data;
  bool loading = false, failed = false;
  ArchitectProjectionLoader(this.onChanged);

  void ensure(Object source, Object key, Future<T> Function() calculate) {
    if (_disposed || identical(source, _source) && key == _key) return;
    if (key != _key) data = null;
    _source = source;
    _key = key;
    _revision++;
    loading = true;
    failed = false;
    _pending = calculate;
    if (!_running) {
      _running = true;
      unawaited(_drain());
    }
  }

  Future<void> _drain() async {
    await Future<void>.delayed(Duration.zero);
    while (!_disposed && _pending != null) {
      final calculate = _pending!, revision = _revision;
      _pending = null;
      try {
        final result = await calculate();
        if (!_disposed && revision == _revision) {
          data = result;
          loading = false;
          failed = false;
          onChanged();
        }
      } catch (_) {
        if (!_disposed && revision == _revision) {
          loading = false;
          failed = true;
          onChanged();
        }
      }
    }
    _running = false;
  }

  void invalidate() {
    _source = null;
    _revision++;
    _pending = null;
    loading = false;
    failed = false;
  }

  void dispose() {
    _disposed = true;
    _revision++;
    _pending = null;
  }
}
