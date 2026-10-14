import 'dart:ui';
import 'bim_element_adapter.dart';

/// Typed native callbacks describe the fields; all point/contour translation
/// follows one implementation and never reconstructs a native object.
class BimPathEditingAdapter<T> extends BimElementAdapter<T> {
  const BimPathEditingAdapter({
    required this.points,
    required this.withPoints,
    this.closed = false,
    super.frame,
  });
  final List<Offset> Function(T) points;
  final T Function(T, List<Offset>) withPoints;
  final bool closed;
  @override
  T translate(T source, Offset deltaMetres) => deltaMetres == Offset.zero
      ? source
      : withPoints(source, translatedContour(points(source), deltaMetres));
  @override
  BimElementSnapshot describe(
    T source,
    BimElementRef reference, {
    Object? revision,
    bool readOnly = false,
  }) {
    final path = points(source).map(frame.toModel).toList();
    final anchor = path.isEmpty
        ? Offset.zero
        : path.first +
              path.fold(Offset.zero, (sum, p) => sum + (p - path.first)) /
                  path.length.toDouble();
    return BimElementSnapshot(
      reference: reference,
      kind: closed
          ? BimEditingGeometryKind.contour
          : BimEditingGeometryKind.line,
      anchor: anchor,
      outline: path,
      referenceLines: [
        for (var i = 0; i + 1 < path.length; i++) (path[i], path[i + 1]),
      ],
      capabilities: {
        BimEditingCapability.translate,
        if (closed) BimEditingCapability.contour,
      },
      revision: revision,
      readOnly: readOnly,
    );
  }
}
