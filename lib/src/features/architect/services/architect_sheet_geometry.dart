import 'dart:math' as math;
import 'dart:ui';

import '../../bim_editing/geometry/bim_polygon_geometry.dart';
import '../models/architect_document.dart';

/// Shared paper-space geometry for sheet preview, interaction and publication.
abstract final class ArchitectSheetGeometry {
  static Offset _rotate(Offset point, double radians) => Offset(
    point.dx * math.cos(radians) - point.dy * math.sin(radians),
    point.dx * math.sin(radians) + point.dy * math.cos(radians),
  );

  static List<Offset> localContour(ArchitectDrawingPlacement place) =>
      place.crop ??
      [
        Offset.zero,
        Offset(place.frame.width, 0),
        Offset(place.frame.width, place.frame.height),
        Offset(0, place.frame.height),
      ];

  static List<Offset> contour(ArchitectDrawingPlacement place) => [
    for (final point in localContour(place)) point + place.frame.topLeft,
  ];

  static Path clipPath(ArchitectDrawingPlacement place) {
    final points = contour(place);
    final path = Path();
    if (points.length >= 3 &&
        points.every((p) => p.dx.isFinite && p.dy.isFinite)) {
      path.addPolygon(points, true);
    }
    return path;
  }

  static bool valid(ArchitectDrawingPlacement place) {
    if (!place.frame.isFinite ||
        place.frame.isEmpty ||
        place.scale <= 0 ||
        !place.rotation.isFinite ||
        !place.anchor.dx.isFinite ||
        !place.anchor.dy.isFinite) {
      return false;
    }
    final points = localContour(place);
    return BimPolygonGeometry.valid(points) &&
        points.every(
          (point) =>
              point.dx >= -.001 &&
              point.dy >= -.001 &&
              point.dx <= place.frame.width + .001 &&
              point.dy <= place.frame.height + .001,
        );
  }

  static Offset sourceToPaper(ArchitectDrawingPlacement place, Offset metres) =>
      place.frame.topLeft +
      _rotate(
        (metres - place.anchor) * (1000 / place.scale),
        place.rotation * math.pi / 180,
      );

  static Offset paperToSource(ArchitectDrawingPlacement place, Offset paper) =>
      place.anchor +
      _rotate(paper - place.frame.topLeft, -place.rotation * math.pi / 180) *
          (place.scale / 1000);

  /// Rebase a changed boundary without moving any of the source drawing.
  static ArchitectDrawingPlacement withContour(
    ArchitectDrawingPlacement place,
    List<Offset> absolutePaper, {
    bool rectangle = false,
  }) {
    if (!BimPolygonGeometry.valid(absolutePaper)) {
      throw ArgumentError.value(absolutePaper, 'absolutePaper', 'Invalid crop');
    }
    final bounds = (Path()..addPolygon(absolutePaper, true)).getBounds();
    final delta = bounds.topLeft - place.frame.topLeft;
    return place.copyWith(
      frame: bounds,
      anchor:
          place.anchor +
          _rotate(delta, -place.rotation * math.pi / 180) *
              (place.scale / 1000),
      crop: rectangle
          ? null
          : [for (final point in absolutePaper) point - bounds.topLeft],
      clearCrop: rectangle,
    );
  }

  /// Change drawing scale and its paper footprint, preserving the source crop.
  static ArchitectDrawingPlacement changeScale(
    ArchitectDrawingPlacement place,
    int denominator,
  ) {
    if (denominator <= 0 || place.scale <= 0) {
      throw ArgumentError.value(denominator, 'denominator');
    }
    final factor = place.scale / denominator;
    return place.copyWith(
      scale: denominator,
      frame: Rect.fromLTWH(
        place.frame.left,
        place.frame.top,
        place.frame.width * factor,
        place.frame.height * factor,
      ),
      crop: place.crop?.map((point) => point * factor).toList(),
    );
  }

  /// Numeric frame sizing changes the crop, never the drawing's scale.
  static ArchitectDrawingPlacement resizeFrame(
    ArchitectDrawingPlacement place,
    Rect frame,
  ) {
    if (!frame.isFinite || frame.isEmpty || place.frame.isEmpty) {
      throw ArgumentError.value(frame, 'frame');
    }
    if (frame.size == place.frame.size) {
      return place.copyWith(frame: frame);
    }
    return place.copyWith(
      frame: frame,
      crop: place.crop == null
          ? null
          : [
              for (final point in place.crop!)
                Offset(
                  point.dx * frame.width / place.frame.width,
                  point.dy * frame.height / place.frame.height,
                ),
            ],
    );
  }
}
