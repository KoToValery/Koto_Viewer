import 'dart:math' as math;
import 'dart:ui';
import '../../bim_editing/geometry/bim_transform_2d.dart';
import '../../bim_editing/scene/bim_element_adapter.dart';
import '../models/architect_column.dart';
import '../models/architect_elements.dart';
import '../models/architect_roof.dart';
import '../models/architect_zone.dart';
import '../models/architect_wall.dart';
import '../../bim_editing/scene/bim_path_editing_adapter.dart';

class ArchitectColumnEditingAdapter extends BimElementAdapter<ArchitectColumn> {
  const ArchitectColumnEditingAdapter();
  @override
  ArchitectColumn translate(ArchitectColumn source, Offset deltaMetres) =>
      deltaMetres == Offset.zero
      ? source
      : source.copyWith(
          position: translatedPoint(source.position, deltaMetres),
        );
  ArchitectColumn rotate(ArchitectColumn source, double radians) => radians == 0
      ? source
      : source.copyWith(
          rotationDeg:
              BimTransform2D.angle(
                source.rotationDeg * math.pi / 180,
                radians,
              ) *
              180 /
              math.pi,
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
  ArchitectBeam rotate(ArchitectBeam source, double radians) {
    if (radians == 0) return source;
    final pivot = (source.startPoint + source.endPoint) / 2;
    return source.copyWith(
      startPoint: BimTransform2D.rotate(source.startPoint, pivot, radians),
      endPoint: BimTransform2D.rotate(source.endPoint, pivot, radians),
    );
  }

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
      BimEditingCapability.rotate,
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

class ArchitectRoofEditingAdapter
    extends BimElementAdapter<ArchitectRoofPlane> {
  const ArchitectRoofEditingAdapter();
  @override
  ArchitectRoofPlane translate(ArchitectRoofPlane source, Offset deltaMetres) =>
      deltaMetres == Offset.zero
      ? source
      : source.copyWith(
          points: translatedContour(source.points, deltaMetres),
        );
  @override
  BimElementSnapshot describe(
    ArchitectRoofPlane source,
    BimElementRef reference, {
    Object? revision,
    bool readOnly = false,
  }) => BimElementSnapshot(
    reference: reference,
    kind: BimEditingGeometryKind.contour,
    anchor: source.centroid,
    outline: source.points,
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

class ArchitectWallEditingAdapter extends BimElementAdapter<ArchitectWall> {
  const ArchitectWallEditingAdapter();
  @override
  ArchitectWall translate(ArchitectWall source, Offset deltaMetres) =>
      deltaMetres == Offset.zero
      ? source
      : source.copyWith(
          startPoint: translatedPoint(source.startPoint, deltaMetres),
          endPoint: translatedPoint(source.endPoint, deltaMetres),
        );
  ArchitectWall rotate(ArchitectWall source, double radians) {
    final pivot = (source.startPoint + source.endPoint) / 2;
    return source.copyWith(
      startPoint: BimTransform2D.rotate(source.startPoint, pivot, radians),
      endPoint: BimTransform2D.rotate(source.endPoint, pivot, radians),
    );
  }

  @override
  BimElementSnapshot describe(
    ArchitectWall source,
    BimElementRef reference, {
    Object? revision,
    bool readOnly = false,
  }) => BimElementSnapshot(
    reference: reference,
    kind: BimEditingGeometryKind.line,
    anchor: (source.startPoint + source.endPoint) / 2,
    outline: source.polygonCorners,
    referenceLines: [
      (source.startPoint, source.endPoint),
      (source.coreCenterStart, source.coreCenterEnd),
    ],
    capabilities: {
      BimEditingCapability.translate,
      BimEditingCapability.rotate,
      BimEditingCapability.duplicate,
      BimEditingCapability.endpoints,
    },
    revision: revision,
    readOnly: readOnly,
  );
}

class ArchitectOpeningEditingAdapter
    extends BimPathEditingAdapter<ArchitectOpening> {
  const ArchitectOpeningEditingAdapter()
    : super(points: _points, withPoints: _withPoints, closed: true);
  static List<Offset> _points(ArchitectOpening source) => source.boundary;
  static ArchitectOpening _withPoints(
    ArchitectOpening source,
    List<Offset> points,
  ) => source.copyWith(boundary: points);
}

class ArchitectStairEditingAdapter
    extends BimPathEditingAdapter<ArchitectStair> {
  const ArchitectStairEditingAdapter()
    : super(points: _points, withPoints: _withPoints);
  static List<Offset> _points(ArchitectStair source) => [
    source.startPoint,
    source.endPoint,
  ];
  static ArchitectStair _withPoints(
    ArchitectStair source,
    List<Offset> points,
  ) => source.copyWith(startPoint: points[0], endPoint: points[1]);
}

class ArchitectDimensionEditingAdapter
    extends BimPathEditingAdapter<ArchitectDimension> {
  const ArchitectDimensionEditingAdapter()
    : super(points: _points, withPoints: _withPoints);
  static List<Offset> _points(ArchitectDimension source) => [
    source.startPoint,
    source.endPoint,
  ];
  static ArchitectDimension _withPoints(
    ArchitectDimension source,
    List<Offset> points,
  ) {
    // Dimension dragging changes only its perpendicular line offset. Witness
    // points remain attached to the measured geometry, even for legacy lines.
    final delta = points[0] - source.startPoint;
    return source.copyWith(
      offsetDistance:
          source.offsetDistance +
          delta.dx * source.normal.dx +
          delta.dy * source.normal.dy,
    );
  }
}

class ArchitectAnnotationEditingAdapter
    extends BimPathEditingAdapter<ArchitectAnnotation> {
  const ArchitectAnnotationEditingAdapter()
    : super(points: _points, withPoints: _withPoints);
  static List<Offset> _points(ArchitectAnnotation source) => [source.position];
  static ArchitectAnnotation _withPoints(
    ArchitectAnnotation source,
    List<Offset> points,
  ) => source.copyWith(position: points[0]);
}

class ArchitectElevationEditingAdapter
    extends BimPathEditingAdapter<ArchitectElevationMarker> {
  const ArchitectElevationEditingAdapter()
    : super(points: _points, withPoints: _withPoints);
  static List<Offset> _points(ArchitectElevationMarker source) => [
    source.position,
  ];
  static ArchitectElevationMarker _withPoints(
    ArchitectElevationMarker source,
    List<Offset> points,
  ) => source.copyWith(position: points[0]);
}

class ArchitectCadEditingAdapter
    extends BimPathEditingAdapter<ArchitectCadPrimitive> {
  const ArchitectCadEditingAdapter()
    : super(points: _points, withPoints: _withPoints);
  static List<Offset> _points(ArchitectCadPrimitive source) => [
    source.startPoint,
    source.endPoint,
    ...?source.polygon,
  ];
  static ArchitectCadPrimitive _withPoints(
    ArchitectCadPrimitive source,
    List<Offset> points,
  ) => source.copyWith(
    startPoint: points[0],
    endPoint: points[1],
    polygon: source.polygon == null ? null : points.skip(2).toList(),
  );
}
