import 'dart:ui';
import 'dart:math' as math;
import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import '../models/architect_wall.dart';

/// Associative dimension geometry, expressed exclusively in model metres.
class ArchitectDimensionChain {
  static double dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

  static ArchitectDimension build({
    required String id,
    required List<ArchitectDimensionAnchor> anchors,
    required Offset direction,
    double offset = .5,
  }) {
    final u = direction / direction.distance;
    final origin = anchors.first.point;
    final sorted = List<ArchitectDimensionAnchor>.of(anchors)
      ..sort(
        (a, b) => dot(a.point - origin, u).compareTo(dot(b.point - origin, u)),
      );
    final base = sorted.first.point;
    final last = sorted.last.point;
    final projected = base + u * dot(last - base, u);
    return ArchitectDimension(
      id: id,
      anchors: List.unmodifiable(sorted),
      direction: u,
      startPoint: base,
      endPoint: (last - projected).distance < 1e-9 ? last : projected,
      offsetDistance: offset,
    );
  }

  /// Selecting a wall includes both physical faces, including insulation.
  static List<ArchitectDimensionAnchor> wallFaces(
    ArchitectWall wall,
    Offset pick,
  ) {
    final ratio = (dot(pick - wall.centerStart, wall.unitVector) / wall.length)
        .clamp(0.0, 1.0);
    return [
      for (final side in [-.5, .5])
        ArchitectDimensionAnchor(
          point:
              wall.centerStart +
              (wall.centerEnd - wall.centerStart) * ratio +
              wall.normalVector * (wall.thickness * side),
          elementId: wall.id,
          feature: 'wallFace',
          ratio: ratio,
          side: side,
        ),
    ];
  }

  static Iterable<Map<String, dynamic>> _records(
    ArchitectProject project,
    ArchitectStorey storey,
  ) sync* {
    for (final a in project.gridAxes) {
      yield a.toJson();
    }
    for (final list in storey.toJson().values.whereType<List>()) {
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
      if (anchor.feature == 'wallFace' && wall.id == anchor.elementId) {
        return wall.centerStart +
            (wall.centerEnd - wall.centerStart) * anchor.ratio +
            wall.normalVector * (wall.thickness * anchor.side);
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
