import 'dart:ui';
import 'dart:math' as math;
import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import '../models/architect_wall.dart';

class ArchitectDimensionEditPoint {
  final String id;
  final Offset point;
  final Set<int> anchorIndices;
  const ArchitectDimensionEditPoint({
    required this.id,
    required this.point,
    required this.anchorIndices,
  });
}

/// Associative dimension geometry, expressed exclusively in model metres.
class ArchitectDimensionChain {
  static double dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

  static ArchitectDimension build({
    required String id,
    required List<ArchitectDimensionAnchor> anchors,
    required Offset direction,
    double offset = .5,
    ArchitectDimensionStyle style = ArchitectDimensionStyle.exterior,
  }) {
    final u = direction / direction.distance;
    final origin = anchors.first.point;
    final sorted = List<ArchitectDimensionAnchor>.of(anchors)
      ..sort(
        (a, b) => dot(a.point - origin, u).compareTo(dot(b.point - origin, u)),
      );
    final provisional = ArchitectDimension(
      id: id,
      startPoint: sorted.first.point,
      endPoint: sorted.last.point,
      anchors: sorted,
      direction: u,
      style: style,
    );
    final measured = provisional.measuredAnchors;
    final base = (measured.isEmpty ? sorted : measured).first.point;
    final last = (measured.isEmpty ? sorted : measured).last.point;
    final projected = base + u * dot(last - base, u);
    return ArchitectDimension(
      id: id,
      anchors: List.unmodifiable(sorted),
      direction: u,
      startPoint: base,
      endPoint: (last - projected).distance < 1e-9 ? last : projected,
      offsetDistance: offset,
      style: style,
    );
  }

  /// Extend a placed row without moving it, including when its first wall changes.
  static ArchitectDimension addAnchors(
    ArchitectDimension dimension,
    List<ArchitectDimensionAnchor> additions,
  ) {
    final anchors = List<ArchitectDimensionAnchor>.of(dimension.anchors);
    for (final a in additions) {
      if (!anchors.any(
        (b) =>
            a.elementId == b.elementId &&
            a.feature == b.feature &&
            a.index == b.index &&
            a.side == b.side &&
            (a.feature == 'wallFace' || (a.point - b.point).distance < 1e-6),
      )) {
        anchors.add(a);
      }
    }
    final next = build(
      id: dimension.id,
      anchors: anchors,
      direction: dimension.unitVector,
      style: dimension.style,
    );
    return next.copyWith(
      offsetDistance: dot(dimension.lineStart - next.startPoint, next.normal),
      showOverall: dimension.showOverall,
      customText: dimension.customText,
    );
  }

  /// A wall/opening is one editable reference, even when it has two faces/jambs.
  static List<ArchitectDimensionEditPoint> editPoints(
    ArchitectDimension dimension,
  ) {
    final groups = <String, Set<int>>{};
    for (var i = 0; i < dimension.anchors.length; i++) {
      final anchor = dimension.anchors[i];
      final grouped =
          anchor.elementId != null &&
          (anchor.feature == 'wallFace' || anchor.feature == 'opening');
      final id = grouped
          ? '${anchor.feature}:${anchor.elementId}'
          : 'anchor:$i';
      groups.putIfAbsent(id, () => <int>{}).add(i);
    }
    final visible = dimension.measuredAnchors.toSet();
    final result = <ArchitectDimensionEditPoint>[];
    for (final group in groups.entries) {
      final all = group.value.map((i) => dimension.anchors[i]);
      final measured = all.where(visible.contains).toList();
      final points = measured.isEmpty ? all.toList() : measured;
      final center =
          points.map((a) => a.point).reduce((a, b) => a + b) /
          points.length.toDouble();
      result.add(
        ArchitectDimensionEditPoint(
          id: group.key,
          point:
              dimension.lineStart +
              dimension.unitVector *
                  dot(center - dimension.startPoint, dimension.unitVector),
          anchorIndices: Set.unmodifiable(group.value),
        ),
      );
    }
    return result;
  }

  /// Remove a reference and merge neighboring spans, keeping the placed line fixed.
  /// An unusable chain must be deleted explicitly rather than by removing its last point.
  static ArchitectDimension? removeAnchors(
    ArchitectDimension dimension,
    Set<int> indices,
  ) {
    final anchors = [
      for (var i = 0; i < dimension.anchors.length; i++)
        if (!indices.contains(i)) dimension.anchors[i],
    ];
    if (anchors.length < 2) return null;
    if (dimension.style == ArchitectDimensionStyle.interior &&
        dimension.anchors
                .where((a) => a.feature == 'wallFace')
                .map((a) => a.elementId)
                .toSet()
                .length >=
            2 &&
        anchors
                .where((a) => a.feature == 'wallFace')
                .map((a) => a.elementId)
                .toSet()
                .length <
            2) {
      return null;
    }
    final next = build(
      id: dimension.id,
      anchors: anchors,
      direction: dimension.unitVector,
      style: dimension.style,
    );
    if (next.length < .001 || next.dimensionPoints.length < 2) return null;
    return next.copyWith(
      offsetDistance: dot(dimension.lineStart - next.startPoint, next.normal),
      showOverall: dimension.showOverall,
      customText: dimension.customText,
    );
  }

  /// Selecting a wall dimensions its structural core (without insulation).
  static List<ArchitectDimensionAnchor> wallFaces(
    ArchitectWall wall,
    Offset pick,
  ) {
    final ratio =
        (dot(pick - wall.coreCenterStart, wall.unitVector) / wall.length).clamp(
          0.0,
          1.0,
        );
    return [
      for (final side in [-.5, .5])
        ArchitectDimensionAnchor(
          point:
              wall.coreCenterStart +
              (wall.coreCenterEnd - wall.coreCenterStart) * ratio +
              wall.normalVector * (wall.coreThickness * side),
          elementId: wall.id,
          feature: 'wallFace',
          ratio: ratio,
          side: side,
        ),
    ];
  }

  /// Selecting a single face of a wall closer to the user pick (e.g. inner face of a step or recess).
  static ArchitectDimensionAnchor wallFaceAt(
    ArchitectWall wall,
    Offset pick,
  ) {
    final ratio =
        (dot(pick - wall.coreCenterStart, wall.unitVector) / wall.length).clamp(
          0.0,
          1.0,
        );
    final side =
        dot(pick - wall.coreCenterStart, wall.normalVector) < 0 ? -.5 : .5;
    return ArchitectDimensionAnchor(
      point:
          wall.coreCenterStart +
          (wall.coreCenterEnd - wall.coreCenterStart) * ratio +
          wall.normalVector * (wall.coreThickness * side),
      elementId: wall.id,
      feature: 'wallFace',
      ratio: ratio,
      side: side,
    );
  }

  /// Selecting an opening (door/window) provides anchors for both jambs.
  static List<ArchitectDimensionAnchor> openingAnchors(
    ArchitectWall wall,
    String openingId,
  ) {
    for (final o in [
      ...wall.doors.map((d) => (d.id, d.offsetRatio, d.width)),
      ...wall.windows.map((w) => (w.id, w.offsetRatio, w.width)),
    ]) {
      if (o.$1 != openingId) continue;
      final center = wall.centerStart + wall.unitVector * (o.$2 * wall.length);
      return [
        for (final side in [-.5, .5])
          ArchitectDimensionAnchor(
            point: center + wall.unitVector * (o.$3 * side),
            elementId: openingId,
            feature: 'opening',
            side: side,
          ),
      ];
    }
    return [];
  }

  static Iterable<Map<String, dynamic>> _records(
    ArchitectProject project,
    ArchitectStorey storey,
  ) sync* {
    for (final a in project.gridAxes) {
      yield a.toJson();
    }
    for (final entry in storey.toJson().entries) {
      if (entry.key == 'groups' || entry.value is! List) continue;
      final list = entry.value as List;
      for (final e in list.cast<Map<String, dynamic>>()) {
        yield e;
      }
    }
  }

  static Offset _point(dynamic p) => Offset(
    ((p['x'] ?? p['dx']) as num).toDouble(),
    ((p['y'] ?? p['dy']) as num).toDouble(),
  );

  static List<Offset> vertices(Map<String, dynamic> record) {
    final polygon = record['polygon'] ?? record['boundary'];
    if (polygon is List && polygon.isNotEmpty) {
      return polygon.map(_point).toList();
    }
    if (record['position'] != null) {
      final center = _point(record['position']);
      if (record['width'] is num &&
          record['depth'] is num &&
          record['shape'] != 'circular') {
        final angle =
            (record['rotationDeg'] as num? ?? 0).toDouble() * math.pi / 180;
        final w = (record['width'] as num).toDouble() / 2;
        final d = (record['depth'] as num).toDouble() / 2;
        return [
          center,
          for (final p in [
            Offset(-w, -d),
            Offset(w, -d),
            Offset(w, d),
            Offset(-w, d),
          ])
            center +
                Offset(
                  p.dx * math.cos(angle) - p.dy * math.sin(angle),
                  p.dx * math.sin(angle) + p.dy * math.cos(angle),
                ),
        ];
      }
      return [center];
    }
    if (record['startPoint'] != null || record['start'] != null) {
      final a = _point(record['startPoint'] ?? record['start']);
      final b = _point(record['endPoint'] ?? record['end']);
      if (record['type'] == 'rect') {
        return [a, Offset(b.dx, a.dy), b, Offset(a.dx, b.dy)];
      }
      return [a, b];
    }
    return [];
  }

  /// Pick the nearest persisted endpoint/vertex (or hosted opening jamb).
  static ArchitectDimensionAnchor? pickElement(
    ArchitectProject project,
    String id,
    Offset pick,
  ) {
    final storey = project.activeStorey;
    for (final wall in storey.walls) {
      for (final o in [
        ...wall.doors.map((d) => (d.id, d.offsetRatio, d.width)),
        ...wall.windows.map((w) => (w.id, w.offsetRatio, w.width)),
      ]) {
        if (o.$1 != id) continue;
        final center =
            wall.centerStart + wall.unitVector * (o.$2 * wall.length);
        final side = dot(pick - center, wall.unitVector) < 0 ? -.5 : .5;
        return ArchitectDimensionAnchor(
          point: center + wall.unitVector * (o.$3 * side),
          elementId: id,
          feature: 'opening',
          side: side,
        );
      }
    }
    final record = _records(
      project,
      storey,
    ).where((e) => e['id'] == id).firstOrNull;
    if (record == null || storey.dimensions.any((d) => d.id == id)) return null;
    final points = vertices(record);
    if (points.isEmpty) return null;
    if (points.length == 2 && record['type'] != 'circle') {
      final delta = points[1] - points[0];
      final ratio = delta.distanceSquared < 1e-12
          ? 0.0
          : (dot(pick - points[0], delta) / delta.distanceSquared).clamp(
              0.0,
              1.0,
            );
      return ArchitectDimensionAnchor(
        point: points[0] + delta * ratio,
        elementId: id,
        feature: 'linePoint',
        ratio: ratio,
      );
    }
    var index = 0;
    for (var i = 1; i < points.length; i++) {
      if ((points[i] - pick).distance < (points[index] - pick).distance) {
        index = i;
      }
    }
    // A snapped point along a polygon edge must retain that position instead
    // of jumping to the nearest corner. Preserve the edge association on edits.
    final polygon = record['polygon'] ?? record['boundary'];
    if (polygon is List || record['type'] == 'rect') {
      var nearest = points[index];
      var edgeIndex = -1;
      var edgeRatio = 0.0;
      for (var i = 0; i < points.length; i++) {
        final delta = points[(i + 1) % points.length] - points[i];
        if (delta.distanceSquared < 1e-12) continue;
        final ratio = (dot(pick - points[i], delta) / delta.distanceSquared)
            .clamp(0.0, 1.0);
        final projected = points[i] + delta * ratio;
        if ((projected - pick).distance + 1e-9 < (nearest - pick).distance) {
          nearest = projected;
          edgeIndex = i;
          edgeRatio = ratio;
        }
      }
      if (edgeIndex >= 0) {
        return ArchitectDimensionAnchor(
          point: nearest,
          elementId: id,
          feature: 'edgePoint',
          index: edgeIndex,
          ratio: edgeRatio,
        );
      }
    }
    return ArchitectDimensionAnchor(
      point: points[index],
      elementId: id,
      feature: 'vertex',
      index: index,
    );
  }

  static Offset? resolveAnchor(
    ArchitectDimensionAnchor anchor,
    ArchitectStorey storey,
    Map<String, Map<String, dynamic>> records,
  ) {
    if (anchor.elementId == null) return anchor.point;
    for (final wall in storey.walls) {
      if (wall.id == anchor.elementId) {
        if (anchor.feature == 'wallFace') {
          return wall.coreCenterStart +
              (wall.coreCenterEnd - wall.coreCenterStart) * anchor.ratio +
              wall.normalVector * (wall.coreThickness * anchor.side);
        }
        if (anchor.feature == 'vertex') {
          if ((anchor.point - wall.startPoint).distance < 1e-4) {
            return wall.startPoint;
          }
          if ((anchor.point - wall.endPoint).distance < 1e-4) {
            return wall.endPoint;
          }
          return anchor.point;
        }
      }
      if (anchor.feature == 'opening') {
        for (final o in [
          ...wall.doors.map((d) => (d.id, d.offsetRatio, d.width)),
          ...wall.windows.map((w) => (w.id, w.offsetRatio, w.width)),
        ]) {
          if (o.$1 == anchor.elementId) {
            return wall.centerStart +
                wall.unitVector * (o.$2 * wall.length + o.$3 * anchor.side);
          }
        }
      }
    }
    final record = records[anchor.elementId];
    if (record == null) return null;
    final points = vertices(record);
    if (anchor.feature == 'edgePoint' && anchor.index < points.length) {
      final start = points[anchor.index];
      return start +
          (points[(anchor.index + 1) % points.length] - start) * anchor.ratio;
    }
    if (anchor.feature == 'linePoint' && points.length == 2) {
      return points.first + (points.last - points.first) * anchor.ratio;
    }
    return anchor.index < points.length ? points[anchor.index] : null;
  }

  static ArchitectProject resolve(ArchitectProject project) {
    var changed = false;
    final storeys = <ArchitectStorey>[];
    for (final storey in project.storeys) {
      if (!storey.dimensions.any((d) => d.isChain)) {
        storeys.add(storey);
        continue;
      }
      final records = {
        for (final e in _records(project, storey)) e['id'] as String: e,
      };
      var floorChanged = false;
      final dimensions = <ArchitectDimension>[];
      for (final dim in storey.dimensions) {
        if (!dim.isChain) {
          dimensions.add(dim);
          continue;
        }
        final anchors = <ArchitectDimensionAnchor>[];
        for (final a in dim.anchors) {
          final point = resolveAnchor(a, storey, records);
          if (point != null) anchors.add(a.at(point));
        }
        if (anchors.length < 2) {
          floorChanged = true;
          continue;
        }
        var next = build(
          id: dim.id,
          anchors: anchors,
          direction: dim.unitVector,
          offset: dim.offsetDistance,
          style: dim.style,
        ).copyWith(customText: dim.customText, showOverall: dim.showOverall);
        // Removing the first witness must not move the already positioned line.
        if (anchors.length != dim.anchors.length) {
          next = next.copyWith(
            offsetDistance: dot(dim.lineStart - next.startPoint, dim.normal),
          );
        }
        if (next.length < 1e-6) {
          floorChanged = true;
          continue;
        }
        final same =
            anchors.length == dim.anchors.length &&
            next.startPoint == dim.startPoint &&
            next.endPoint == dim.endPoint &&
            List.generate(
              next.anchors.length,
              (i) => next.anchors[i].point == dim.anchors[i].point,
            ).every((v) => v);
        floorChanged |= !same;
        dimensions.add(same ? dim : next);
      }
      changed |= floorChanged;
      storeys.add(
        floorChanged ? storey.copyWith(dimensions: dimensions) : storey,
      );
    }
    return changed ? project.copyWith(storeys: storeys) : project;
  }
}
