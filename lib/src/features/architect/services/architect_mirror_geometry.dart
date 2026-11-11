import 'dart:math' as math;
import 'dart:ui';

import '../../bim_editing/geometry/bim_transform_2d.dart';
import '../models/architect_contour.dart';
import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import 'architect_dimension_chain.dart';

/// Reflection of local curve data as well as its model-space control points.
class ArchitectMirrorGeometry {
  const ArchitectMirrorGeometry._();

  /// Reflection changes the sign of a bulge. Reversing the contour changes it
  /// back, and associates it with the edge ending at the old vertex.
  static List<double>? reversedBulges(List<double>? bulges, int count) {
    if (bulges == null || count == 0) return bulges;
    return [
      for (var i = 0; i < count; i++)
        (count - 2 - i) % count < bulges.length
            ? bulges[(count - 2 - i) % count]
            : 0,
    ];
  }

  static ArchitectCadPrimitive cad(
    ArchitectCadPrimitive source, {
    required String id,
    required Offset origin,
    required Offset direction,
  }) {
    Offset point(Offset p) => BimTransform2D.mirror(p, origin, direction);
    double angle(double degrees) {
      final radians = degrees * math.pi / 180;
      final vector = BimTransform2D.mirror(
        Offset(math.cos(radians), math.sin(radians)),
        Offset.zero,
        direction,
      );
      return math.atan2(vector.dy, vector.dx) * 180 / math.pi;
    }

    // A spline's endpoint tangents depend on fit-point order. Mask/polyline
    // bulges also belong to ordered edges. Retain that order on reflection.
    final ordered = switch (source.type) {
      CadPrimitiveType.polyline ||
      CadPrimitiveType.mask ||
      CadPrimitiveType.spline => true,
      _ => false,
    };
    final polygon = ordered
        ? source.polygon?.map(point).toList()
        : source.isPolygon || source.polygon != null
        ? (source.isPolygon ? source.polygonCorners : source.polygon!)
              .map(point)
              .toList()
              .reversed
              .toList()
        : null;
    final ellipse = source.type == CadPrimitiveType.ellipse;
    return source.copyWith(
      id: id,
      startPoint: point(source.startPoint),
      endPoint: point(source.endPoint),
      polygon: polygon,
      holes: ArchitectContour.transform(source.holes, point),
      hatchAngle: angle(source.hatchAngle),
      arcBulge: source.arcBulge == null ? null : -source.arcBulge!,
      bulges: ordered
          ? source.bulges?.map((b) => -b).toList()
          : reversedBulges(source.bulges, polygon?.length ?? 0),
      rotationDeg: ellipse ? angle(source.rotationDeg ?? 0) : null,
      // The reflected local Y axis is reversed. Exchange the ends to retain
      // the renderer's positive sweep while reflecting the same partial arc.
      startAngleDeg: ellipse && source.isArc == true
          ? -(source.endAngleDeg ?? 360)
          : null,
      endAngleDeg: ellipse && source.isArc == true
          ? -(source.startAngleDeg ?? 0)
          : null,
    );
  }

  /// Keep copied dimensions attached to copied hosts. A dimension reflected on
  /// its own becomes a free witness rather than snapping back to the old host.
  static ArchitectStorey dimensionReferences(
    ArchitectStorey source,
    ArchitectStorey result, {
    required Map<String, String> mirroredIds,
    required bool duplicate,
    required Offset origin,
    required Offset direction,
  }) {
    if (source.dimensions.every((d) => !d.isChain)) return result;
    Offset reflect(Offset p) => BimTransform2D.mirror(p, origin, direction);
    final hosts = Map<String, String>.of(mirroredIds);
    for (final wall in source.walls) {
      final target = mirroredIds[wall.id];
      if (target == null) continue;
      for (final door in wall.doors) {
        hosts[door.id] = duplicate ? '${target}_door_${door.id}' : door.id;
      }
      for (final window in wall.windows) {
        hosts[window.id] = duplicate
            ? '${target}_window_${window.id}'
            : window.id;
      }
    }
    final records = <String, Map<String, dynamic>>{
      for (final entry in result.toJson().entries)
        if (entry.value is List && entry.key != 'groups')
          for (final value in entry.value as List)
            if (value is Map<String, dynamic> && value['id'] is String)
              value['id'] as String: value,
    };
    final sourceDimensions = {for (final d in source.dimensions) d.id: d};
    final originals = {for (final e in mirroredIds.entries) e.value: e.key};
    return result.copyWith(
      dimensions: [
        for (final dim in result.dimensions)
          () {
            final originalId = originals[dim.id];
            final reflected =
                originalId != null && (!duplicate || originalId != dim.id);
            final before = sourceDimensions[reflected ? originalId : dim.id];
            if (before == null ||
                !before.isChain ||
                (duplicate && !reflected)) {
              return dim;
            }
            return dim.copyWith(
              anchors: [
                for (final anchor in before.anchors)
                  () {
                    final host = hosts[anchor.elementId];
                    final movedHost = host != null;
                    if (!reflected && !movedHost) return anchor;
                    final point = reflect(anchor.point);
                    if (!movedHost) {
                      return ArchitectDimensionAnchor(point: point);
                    }
                    var index = anchor.index;
                    var ratio = anchor.ratio;
                    final record = records[host];
                    if (record != null &&
                        (anchor.feature == 'vertex' ||
                            anchor.feature == 'edgePoint')) {
                      final vertices = ArchitectDimensionChain.vertices(record);
                      var best = double.infinity;
                      for (var i = 0; i < vertices.length; i++) {
                        final start = vertices[i];
                        var t = 0.0;
                        if (anchor.feature == 'edgePoint') {
                          final edge =
                              vertices[(i + 1) % vertices.length] - start;
                          if (edge.distanceSquared > 1e-16) {
                            final d = point - start;
                            t =
                                ((d.dx * edge.dx + d.dy * edge.dy) /
                                        edge.distanceSquared)
                                    .clamp(0.0, 1.0);
                          }
                        }
                        final candidate = anchor.feature == 'edgePoint'
                            ? start +
                                  (vertices[(i + 1) % vertices.length] -
                                          start) *
                                      t
                            : start;
                        final distance = (point - candidate).distanceSquared;
                        if (distance < best) {
                          best = distance;
                          index = i;
                          if (anchor.feature == 'edgePoint') ratio = t;
                        }
                      }
                    }
                    return ArchitectDimensionAnchor(
                      point: point,
                      elementId: host,
                      feature: anchor.feature,
                      index: index,
                      ratio: ratio,
                      side: anchor.feature == 'wallFace'
                          ? -anchor.side
                          : anchor.side,
                    );
                  }(),
              ],
            );
          }(),
      ],
    );
  }
}
