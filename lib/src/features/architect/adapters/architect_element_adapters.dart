import 'dart:math' as math;
import 'dart:ui';
import '../../bim_editing/scene/bim_element_adapter.dart';
import '../models/architect_column.dart';
import '../models/architect_elements.dart';
import '../models/architect_zone.dart';

class ArchitectColumnEditingAdapter extends BimElementAdapter<ArchitectColumn> {
  const ArchitectColumnEditingAdapter();
  @override
  ArchitectColumn translate(ArchitectColumn source, Offset deltaMetres) =>
      deltaMetres == Offset.zero
      ? source
      : source.copyWith(
          position: translatedPoint(source.position, deltaMetres),
        );
  @override
  BimElementSnapshot describe(
    ArchitectColumn source,
    BimElementRef reference, {
    Object? revision,
    bool readOnly = false,
  }) {
    final angle = source.rotationDeg * math.pi / 180;
    final u = Offset(math.cos(angle), math.sin(angle)) * source.width / 2;
    final v = Offset(-math.sin(angle), math.cos(angle)) * source.depth / 2;
    return BimElementSnapshot(
      reference: reference,
      kind: BimEditingGeometryKind.profile,
      anchor: source.position,
      outline: source.shape == ColumnShape.circular
          ? []
          : [
              source.position - u - v,
              source.position + u - v,
              source.position + u + v,
              source.position - u + v,
            ],
      circles: source.shape == ColumnShape.circular
          ? [BimEditingCircle(source.position, source.width / 2)]
          : [],
      capabilities: {
        BimEditingCapability.translate,
        BimEditingCapability.duplicate,
        BimEditingCapability.rotate,
      },
      revision: revision,
      readOnly: readOnly,
    );
  }
}

class ArchitectBeamEditingAdapter extends BimElementAdapter<ArchitectBeam> {
  const ArchitectBeamEditingAdapter();
  @override
  ArchitectBeam translate(ArchitectBeam source, Offset deltaMetres) =>
      deltaMetres == Offset.zero
      ? source
      : source.copyWith(
          startPoint: translatedPoint(source.startPoint, deltaMetres),
          endPoint: translatedPoint(source.endPoint, deltaMetres),
        );
  @override
  BimElementSnapshot describe(
    ArchitectBeam source,
    BimElementRef reference, {
    Object? revision,
    bool readOnly = false,
  }) => BimElementSnapshot(
    reference: reference,
    kind: BimEditingGeometryKind.line,
    anchor: (source.startPoint + source.endPoint) / 2,
    outline: source.polygonCorners,
    referenceLines: [(source.startPoint, source.endPoint)],
    capabilities: {
      BimEditingCapability.translate,
      BimEditingCapability.duplicate,
    },
    revision: revision,
    readOnly: readOnly,
  );
}

class ArchitectSlabEditingAdapter extends BimElementAdapter<ArchitectSlab> {
  const ArchitectSlabEditingAdapter();
  @override
  ArchitectSlab translate(ArchitectSlab source, Offset deltaMetres) =>
      deltaMetres == Offset.zero
      ? source
      : source.copyWith(
          polygon: translatedContour(source.polygon, deltaMetres),
        );
  @override
  BimElementSnapshot describe(
    ArchitectSlab source,
    BimElementRef reference, {
    Object? revision,
    bool readOnly = false,
  }) => BimElementSnapshot(
    reference: reference,
    kind: BimEditingGeometryKind.contour,
    anchor: source.centroid,
    outline: source.polygon,
    capabilities: {
      BimEditingCapability.translate,
      BimEditingCapability.contour,
    },
    revision: revision,
    readOnly: readOnly,
  );
}

class ArchitectZoneEditingAdapter extends BimElementAdapter<ArchitectZone> {
  const ArchitectZoneEditingAdapter();
  @override
  ArchitectZone translate(ArchitectZone source, Offset deltaMetres) =>
      deltaMetres == Offset.zero
      ? source
      : source.copyWith(
          polygon: translatedContour(source.polygon, deltaMetres),
        );
  @override
  BimElementSnapshot describe(
    ArchitectZone source,
    BimElementRef reference, {
    Object? revision,
    bool readOnly = false,
  }) => BimElementSnapshot(
    reference: reference,
    kind: BimEditingGeometryKind.contour,
    anchor: source.polygon.isEmpty ? Offset.zero : source.polygon.first,
    outline: source.polygon,
    capabilities: {
      BimEditingCapability.translate,
      BimEditingCapability.contour,
    },
    revision: revision,
    readOnly: readOnly,
  );
}
