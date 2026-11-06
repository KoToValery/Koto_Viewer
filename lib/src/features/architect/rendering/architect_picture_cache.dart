import 'dart:ui' as ui;

import 'architect_vector_scene.dart';

/// Display-list cache owned by a viewport, never by the publication model.
/// Active entries remain alive throughout paint; only inactive LRU entries count
/// towards the budget. Pictures keep paths and glyphs vector at every zoom.
class ArchitectPictureCache {
  ArchitectPictureCache({this.maxInactiveBytes = 32 * 1024 * 1024});

  final int maxInactiveBytes;
  final _entries = <Object, ArchitectCachedPicture>{};
  final _active = <Object>{};
  bool _disposed = false;
  int recordings = 0, evictions = 0;

  int get length => _entries.length;
  int get inactiveBytes => _entries.entries
      .where((entry) => !_active.contains(entry.key))
      .fold(0, (bytes, entry) => bytes + entry.value.bytes);
  int get totalBytes =>
      _entries.values.fold(0, (sum, entry) => sum + entry.bytes);

  void beginFrame() {
    if (_disposed) throw StateError('Picture cache is disposed');
    _active.clear();
  }

  ArchitectCachedPicture obtain(
    Object key,
    ArchitectVectorScene Function() build,
  ) {
    if (_disposed) throw StateError('Picture cache is disposed');
    final cached = _entries.remove(key);
    if (cached != null) {
      _entries[key] = cached;
      _active.add(key);
      return cached;
    }
    final scene = build();
    final bounds = scene.bounds;
    final recorder = ui.PictureRecorder();
    try {
      scene.paint(ui.Canvas(recorder));
      final picture = recorder.endRecording();
      final entry = ArchitectCachedPicture(picture, bounds);
      _entries[key] = entry;
      _active.add(key);
      recordings++;
      return entry;
    } finally {
      // Layout information stays on immutable ops; native paragraph resources
      // are no longer needed once the picture owns their recorded glyphs.
      scene.releaseTextPainters();
      if (recorder.isRecording) recorder.endRecording().dispose();
    }
  }

  void endFrame() {
    var remaining = inactiveBytes;
    if (remaining <= maxInactiveBytes) return;
    for (final key in _entries.keys.toList()) {
      if (_active.contains(key)) continue;
      final entry = _entries.remove(key)!;
      remaining -= entry.bytes;
      entry.dispose();
      evictions++;
      if (remaining <= maxInactiveBytes) break;
    }
  }

  void clear() {
    for (final entry in _entries.values) {
      entry.dispose();
    }
    _entries.clear();
    _active.clear();
  }

  void dispose() {
    if (_disposed) return;
    clear();
    _disposed = true;
  }
}

class ArchitectCachedPicture {
  ArchitectCachedPicture(this.picture, this.bounds)
    : bytes = picture.approximateBytesUsed;

  final ui.Picture picture;
  final ui.Rect bounds;
  final int bytes;
  bool _disposed = false;
  bool get isDisposed => _disposed;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    picture.dispose();
  }
}
