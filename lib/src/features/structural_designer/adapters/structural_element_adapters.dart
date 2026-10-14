import 'dart:ui';
import '../../bim_editing/geometry/bim_transform_2d.dart';
import '../../bim_editing/scene/bim_element_adapter.dart';
import '../models/structural_element.dart';

const _transformCapabilities = {
  BimEditingCapability.translate,
  BimEditingCapability.duplicate,
  BimEditingCapability.rotate,
  BimEditingCapability.mirror,
};

class StructuralColumnEditingAdapter
    extends BimElementAdapter<StructuralColumn> {
  const StructuralColumnEditingAdapter({super.frame});
  @override
  StructuralColumn translate(StructuralColumn source, Offset deltaMetres) =>
      deltaMetres == Offset.zero
      ? source
      : source.copyWith(center: translatedPoint(source.center, deltaMetres));
  StructuralColumn rotate(StructuralColumn source, double radians) =>
      radians == 0
      ? source
      : source.copyWith(
          rotationRad: BimTransform2D.angle(source.rotationRad, radians),
        );
  @override
  BimElementSnapshot describe(
    StructuralColumn source,
    BimElementRef reference, {
    Object? revision,
    bool readOnly = false,
  }) => BimElementSnapshot(
    reference: reference,
    kind: BimEditingGeometryKind.profile,
    anchor: frame.toModel(source.center),
    outline: source.shape == ColumnShape.circular
        ? []
        : source.polygonVertices.map(frame.toModel),
    circles: source.shape == ColumnShape.circular
        ? [
            BimEditingCircle(
              frame.toModel(source.center),
              source.width / frame.unitsPerMeter / 2,
            ),
          ]
        : [],
    capabilities: {..._transformCapabilities, BimEditingCapability.offset},
    revision: revision,
    readOnly: readOnly,
  );
}

class StructuralWallEditingAdapter
    extends BimElementAdapter<StructuralShearWall> {
  const StructuralWallEditingAdapter({super.frame});
  @override
  StructuralShearWall translate(
    StructuralShearWall source,
    Offset deltaMetres,
  ) => deltaMetres == Offset.zero
      ? source
      : source.copyWith(
          start: translatedPoint(source.start, deltaMetres),
          end: translatedPoint(source.end, deltaMetres),
        );
  @override
  BimElementSnapshot describe(
    StructuralShearWall source,
    BimElementRef reference, {
    Object? revision,
    bool readOnly = false,
  }) => BimElementSnapshot(
    reference: reference,
    kind: BimEditingGeometryKind.line,
    anchor: frame.toModel(source.center),
    outline: source.polygonVertices.map(frame.toModel),
    referenceLines: [(frame.toModel(source.start), frame.toModel(source.end))],
    capabilities: _transformCapabilities,
    revision: revision,
    readOnly: readOnly,
  );
}

class StructuralBeamEditingAdapter extends BimElementAdapter<StructuralBeam> {
  const StructuralBeamEditingAdapter({super.frame});
  @override
  StructuralBeam translate(StructuralBeam source, Offset deltaMetres) =>
      deltaMetres == Offset.zero
      ? source
      : source.copyWith(
          start: translatedPoint(source.start, deltaMetres),
          end: translatedPoint(source.end, deltaMetres),
        );
  StructuralBeam rotate(StructuralBeam source, double radians) {
    if (radians == 0) return source;
    final pivot = (source.start + source.end) / 2;
    return source.copyWith(
      start: BimTransform2D.rotate(source.start, pivot, radians),
      end: BimTransform2D.rotate(source.end, pivot, radians),
    );
  }

  @override
  BimElementSnapshot describe(
    StructuralBeam source,
    BimElementRef reference, {
    Object? revision,
    bool readOnly = false,
  }) => BimElementSnapshot(
    reference: reference,
    kind: BimEditingGeometryKind.line,
    anchor: frame.toModel((source.start + source.end) / 2),
    outline: source.polygonVertices.map(frame.toModel),
    referenceLines: [(frame.toModel(source.start), frame.toModel(source.end))],
    capabilities: {
      BimEditingCapability.translate,
      BimEditingCapability.duplicate,
    },
    revision: revision,
    readOnly: readOnly,
  );
}

class StructuralAxisEditingAdapter
    extends BimElementAdapter<StructuralGridAxis> {
  const StructuralAxisEditingAdapter({super.frame});
  @override
  StructuralGridAxis translate(StructuralGridAxis source, Offset deltaMetres) =>
      deltaMetres == Offset.zero
      ? source
      : source.copyWith(
          start: translatedPoint(source.start, deltaMetres),
          end: translatedPoint(source.end, deltaMetres),
        );
  @override
  BimElementSnapshot describe(
    StructuralGridAxis source,
    BimElementRef reference, {
    Object? revision,
    bool readOnly = false,
  }) => BimElementSnapshot(
    reference: reference,
    kind: BimEditingGeometryKind.line,
    anchor: frame.toModel((source.start + source.end) / 2),
    referenceLines: [(frame.toModel(source.start), frame.toModel(source.end))],
    capabilities: {
      BimEditingCapability.translate,
      BimEditingCapability.endpoints,
      BimEditingCapability.offset,
    },
    revision: revision,
    readOnly: readOnly,
  );
}

class StructuralSlabEditingAdapter extends BimElementAdapter<StructuralSlab> {
  const StructuralSlabEditingAdapter({super.frame});
  @override
  StructuralSlab translate(StructuralSlab source, Offset deltaMetres) =>
      deltaMetres == Offset.zero
      ? source
      : source.copyWith(
          polygon: translatedContour(source.polygon, deltaMetres),
          openings: [
            for (final hole in source.openings)
              translatedContour(hole, deltaMetres),
          ],
        );
  @override
  BimElementSnapshot describe(
    StructuralSlab source,
    BimElementRef reference, {
    Object? revision,
    bool readOnly = false,
  }) => BimElementSnapshot(
    reference: reference,
    kind: BimEditingGeometryKind.contour,
    anchor: frame.toModel(
      source.polygon.isEmpty ? Offset.zero : source.polygon.first,
    ),
    outline: source.polygon.map(frame.toModel),
    holes: source.openings.map((h) => h.map(frame.toModel)),
    capabilities: {
      BimEditingCapability.translate,
      BimEditingCapability.contour,
    },
    revision: revision,
    readOnly: readOnly,
  );
}
