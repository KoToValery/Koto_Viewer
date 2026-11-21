import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

enum DxfViewportMotion { idle, overview, detail }

/// Vector recordings in the viewer's untransformed scene coordinates.
/// The viewport owns their lifetime. The caller supplies a content revision
/// whenever it changes mutable drawing data, such as layer visibility.
class DxfViewportPictureCache {
  static const minOverviewEntities = 4000;
  static const _maxRegions = 8;
  static const _maxEstimatedBytes = 16 * 1024 * 1024;
  final _regions = <DxfViewportPicture>[];
  Object? _content;
  int _estimatedBytes = 0;
  Timer? _overviewTimer;
  Image? _overview;
  Object? _overviewRequest;
  bool _overviewAttempted = false;
  bool _rasterizing = false;
  int recordings = 0;
  bool get hasOverview => _overview != null;

  Image? overviewFor(Object content) => content == _content ? _overview : null;

  /// Prepare one temporary texture of the complete drawing while idle.
  /// It uses the same scene coordinates as the vector layer.
  void prepareOverview({
    required DxfViewportPicture drawing,
    required Size size,
    required bool Function() isMoving,
  }) {
    if (_overviewAttempted ||
        _overviewTimer != null ||
        _rasterizing ||
        isMoving())
      return;
    _overviewTimer = Timer(const Duration(milliseconds: 350), () {
      _overviewTimer = null;
      if (isMoving() || !_regions.contains(drawing)) return;
      _overviewAttempted = true;
      unawaited(_rasterizeOverview(drawing.picture, size));
    });
  }

  Future<void> _rasterizeOverview(Picture drawing, Size size) async {
    final request = Object();
    _overviewRequest = request;
    _rasterizing = true;
    final scale = math.min(1.0, 1440 / size.longestSide);
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder)..scale(scale);
    canvas.drawPicture(drawing);
    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(
        (size.width * scale).ceil(),
        (size.height * scale).ceil(),
      );
      if (identical(request, _overviewRequest)) {
        _overview = image;
      } else {
        image.dispose();
      }
    } catch (_) {
      // Continue using the vector recording if the engine cannot rasterize it.
    } finally {
      if (identical(request, _overviewRequest)) _overviewRequest = null;
      _rasterizing = false;
      picture.dispose();
    }
  }

  static double recordingScale(double scale) {
    final clamped = scale.clamp(0.001, 10000.0);
    final band = (8 * math.log(clamped) / math.ln2).round();
    final representative = math.pow(2, band / 8).toDouble();
    // Keep the full-drawing hatch preview transition at its existing zoom.
    return clamped < 1.25
        ? math.min(representative, 1.249)
        : math.max(representative, 1.25);
  }

  DxfViewportPicture obtain({
    required Object content,
    required Rect viewport,
    required Rect drawingBounds,
    required double scale,
    required void Function(Canvas canvas, Rect region, double scale) record,
  }) {
    if (_content != content) {
      dispose();
      _content = content;
    }
    final band = recordingScale(scale);
    for (var i = _regions.length - 1; i >= 0; i--) {
      final entry = _regions[i];
      if (entry.covers(viewport, band)) {
        _regions.removeAt(i);
        _regions.add(entry);
        return entry;
      }
    }

    final drawingExtent = drawingBounds.inflate(
      drawingBounds.longestSide * 0.05 + 10,
    );
    // Reuse part of the painter's existing overscan. Expanding the recording
    // rectangle itself would duplicate that margin and make a cache miss
    // process more geometry, including hatches outside the actual viewport.
    var region = viewport.inflate(viewport.longestSide * 0.04);
    if (viewport.intersect(drawingExtent) == viewport) {
      region = region.intersect(drawingExtent);
    }
    final recorder = PictureRecorder();
    try {
      record(Canvas(recorder), viewport, band);
      final entry = DxfViewportPicture._(recorder.endRecording(), region, band);
      _regions.add(entry);
      _estimatedBytes += entry._bytes;
      recordings++;
      while (_regions.length > 1 &&
          (_regions.length > _maxRegions ||
              _estimatedBytes > _maxEstimatedBytes)) {
        final evicted = _regions.removeAt(0);
        _estimatedBytes -= evicted._bytes;
        evicted.picture.dispose();
      }
      return entry;
    } finally {
      if (recorder.isRecording) recorder.endRecording().dispose();
    }
  }

  void dispose() {
    _overviewTimer?.cancel();
    _overviewTimer = null;
    _overviewRequest = null;
    _overviewAttempted = false;
    _overview?.dispose();
    _overview = null;
    for (final entry in _regions) {
      entry.picture.dispose();
    }
    _regions.clear();
    _estimatedBytes = 0;
    _content = null;
  }
}

class DxfViewportPicture {
  DxfViewportPicture._(this.picture, this.region, this.scale)
    : _bytes = picture.approximateBytesUsed;

  final Picture picture;
  final Rect region;
  final double scale;
  final int _bytes;

  bool covers(Rect viewport, double band) =>
      scale == band && region.intersect(viewport) == viewport;
}
