import 'dart:ui';
import '../geometry/bim_coordinate_frame.dart';

/// Identity is scoped to a native document; the two BIM models stay independent.
class BimElementRef {
  final String documentId, storeyId, elementId;
  final String? partId;
  const BimElementRef({
    required this.documentId,
    required this.storeyId,
    required this.elementId,
    this.partId,
  });
  @override
  bool operator ==(Object other) =>
      other is BimElementRef &&
      other.documentId == documentId &&
      other.storeyId == storeyId &&
      other.elementId == elementId &&
      other.partId == partId;
  @override
  int get hashCode => Object.hash(documentId, storeyId, elementId, partId);
}

enum BimEditingCapability {
  translate,
  duplicate,
  rotate,
  mirror,
  endpoints,
  contour,
  offset,
}

enum BimEditingGeometryKind { profile, line, contour }

class BimEditingCircle {
  final Offset center;
  final double radius;
  const BimEditingCircle(this.center, this.radius);
}

/// Transient geometry in metres. Native model fields and persistence stay in adapters.
class BimElementSnapshot {
  final BimElementRef reference;
  final BimEditingGeometryKind kind;
  final Offset anchor;
  final List<Offset> outline;
  final List<List<Offset>> holes;
  final List<(Offset, Offset)> referenceLines;
  final List<BimEditingCircle> circles;
  final Set<BimEditingCapability> capabilities;
  final Object? revision;
  final bool readOnly;

  BimElementSnapshot({
    required this.reference,
    required this.kind,
    required this.anchor,
    Iterable<Offset> outline = const [],
    Iterable<Iterable<Offset>> holes = const [],
    Iterable<(Offset, Offset)> referenceLines = const [],
    Iterable<BimEditingCircle> circles = const [],
    Iterable<BimEditingCapability> capabilities = const [],
    this.revision,
    this.readOnly = false,
  }) : outline = List.unmodifiable(outline),
       holes = List.unmodifiable(
         holes.map((h) => List<Offset>.unmodifiable(h)),
       ),
       referenceLines = List.unmodifiable(referenceLines),
       circles = List.unmodifiable(circles),
       capabilities = Set.unmodifiable(
         readOnly ? <BimEditingCapability>[] : capabilities,
       );
}

/// A small typed boundary. It never rebuilds native objects with default fields.
abstract class BimElementAdapter<T> {
  final BimCoordinateFrame frame;
  const BimElementAdapter({this.frame = const BimCoordinateFrame()});
  BimElementSnapshot describe(
    T source,
    BimElementRef reference, {
    Object? revision,
    bool readOnly = false,
  });
  T translate(T source, Offset deltaMetres);

  Offset translatedPoint(Offset nativePoint, Offset deltaMetres) {
    if (!deltaMetres.dx.isFinite || !deltaMetres.dy.isFinite) {
      throw ArgumentError.value(deltaMetres, 'deltaMetres');
    }
    // Translate vectors without a large-origin round trip or re-quantization.
    return nativePoint + deltaMetres * frame.unitsPerMeter;
  }

  List<Offset> translatedContour(Iterable<Offset> points, Offset deltaMetres) =>
      points.map((p) => translatedPoint(p, deltaMetres)).toList();
}
