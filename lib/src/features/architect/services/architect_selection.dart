import 'dart:ui';
import 'dart:math' as math;
import '../models/architect_column.dart';
import '../models/architect_project.dart';
import '../models/architect_elements.dart';
import '../models/architect_wall.dart';
import '../models/architect_wall_type.dart';
import '../rendering/architect_scene_geometry.dart';
import 'architect_command_controller.dart';

/// A shared property schema for all persisted architectural element kinds.
class ArchitectSelection {
  static const numericKeys = {
    'height',
    'thickness',
    'width',
    'depth',
    'rotationDeg',
    'stepCount',
    'sillHeight',
    'fontSize',
    'elevation',
    'offsetDistance',
    'strokeWidth',
  };
  static Iterable<Map<String, dynamic>> records(
    Map<String, dynamic> json,
    String storeyId,
  ) sync* {
    for (final axis in json['gridAxes'] as List) {
      yield axis as Map<String, dynamic>;
    }
    final storey = (json['storeys'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((s) => s['id'] == storeyId);
    for (final list in storey.values.whereType<List>()) {
      for (final e in list.cast<Map<String, dynamic>>()) {
        yield e;
        for (final key in ['doors', 'windows']) {
          for (final opening in (e[key] as List? ?? [])) {
            yield opening as Map<String, dynamic>;
          }
        }
      }
    }
  }

  static Map<String, dynamic> record(ArchitectProject project, String id) =>
      records(
        project.toJson(),
        project.activeStoreyId,
      ).firstWhere((e) => e['id'] == id);
  static Map<String, double> fields(ArchitectProject project, String id) {
    final e = record(project, id);
    final fields = <String, double>{
      for (final key in numericKeys)
        if (e[key] is num) key: (e[key] as num).toDouble(),
    };
    if (project.activeStorey.columns.any((c) => c.id == id)) {
      fields['height'] =
          (e['height'] as num?)?.toDouble() ?? project.activeStorey.height;
    }
    if (e.containsKey('referenceLine')) {
      final wall = ArchitectWall.fromJson(e);
      fields['coreThickness'] = wall.coreThickness;
      fields['insulationThicknessOverride'] = wall.insulationThickness;
    }
    return fields;
  }

  static Rect? bounds(ArchitectProject project, String id) {
    final s = project.activeStorey;
    for (final w in s.walls) {
      if (w.id == id) return ArchitectSceneGeometry.boundsOf(w.polygonCorners);
      for (final o in [
        ...w.doors.map((d) => (d.id, d.offsetRatio, d.width)),
        ...w.windows.map((e) => (e.id, e.offsetRatio, e.width)),
      ]) {
        if (o.$1 == id) {
          final center = w.centerStart + w.unitVector * (o.$2 * w.length);
          return ArchitectSceneGeometry.boundsOf([
            center - w.unitVector * o.$3 / 2 - w.normalVector * w.thickness / 2,
            center + w.unitVector * o.$3 / 2 + w.normalVector * w.thickness / 2,
          ]);
        }
      }
    }
    final e = record(project, id);
    Offset point(dynamic json) =>
        Offset((json['x'] as num).toDouble(), (json['y'] as num).toDouble());
    if (e['polygon'] is List || e['boundary'] is List) {
      return ArchitectSceneGeometry.boundsOf(
        (e['polygon'] ?? e['boundary'] as List).cast<dynamic>().map<Offset>(
          point,
        ),
      );
    }
    if (e['position'] != null) {
      final p = point(e['position']);
      final width = (e['width'] as num? ?? e['fontSize'] as num? ?? .2)
          .toDouble();
      final depth = (e['depth'] as num? ?? width).toDouble();
      return Rect.fromCenter(center: p, width: width, height: depth);
    }
    if (e['startPoint'] != null || e['start'] != null) {
      final a = point(e['startPoint'] ?? e['start']),
          b = point(e['endPoint'] ?? e['end']);
      if (e['type'] == 'circle') {
        return Rect.fromCircle(center: a, radius: (a - b).distance);
      }
      return Rect.fromPoints(
        a,
        b,
      ).inflate((e['width'] as num? ?? 0).toDouble() / 2);
    }
    return null;
  }

  static Path outline(ArchitectProject project, String id) {
    final s = project.activeStorey;
    final path = Path();
    for (final w in s.walls) {
      if (w.id == id) return path..addPolygon(w.polygonCorners, true);
      for (final o in [
        ...w.doors.map((d) => (d.id, d.offsetRatio, d.width)),
        ...w.windows.map((e) => (e.id, e.offsetRatio, e.width)),
      ]) {
        if (o.$1 != id) continue;
        final p = w.centerStart + w.unitVector * (o.$2 * w.length);
        final u = w.unitVector * o.$3 / 2, n = w.normalVector * w.thickness / 2;
        return path
          ..addPolygon([p - u - n, p + u - n, p + u + n, p - u + n], true);
      }
    }
    for (final c in s.columns) {
      if (c.id != id) continue;
      if (c.shape == ColumnShape.circular) {
        return path
          ..addOval(Rect.fromCircle(center: c.position, radius: c.width / 2));
      }
      final a = c.rotationDeg * math.pi / 180;
      Offset rotate(Offset p) =>
          c.position +
          Offset(
            p.dx * math.cos(a) - p.dy * math.sin(a),
            p.dx * math.sin(a) + p.dy * math.cos(a),
          );
      return path..addPolygon(
        [
          Offset(-c.width / 2, -c.depth / 2),
          Offset(c.width / 2, -c.depth / 2),
          Offset(c.width / 2, c.depth / 2),
          Offset(-c.width / 2, c.depth / 2),
        ].map(rotate).toList(),
        true,
      );
    }
    for (final b in s.beams) {
      if (b.id == id) return path..addPolygon(b.polygonCorners, true);
    }
    for (final slab in s.slabs) {
      if (slab.id == id) return path..addPolygon(slab.polygon, true);
    }
    for (final zone in s.zones) {
      if (zone.id == id) return path..addPolygon(zone.polygon, true);
    }
    for (final opening in s.openings) {
      if (opening.id == id) return path..addPolygon(opening.boundary, true);
    }
    for (final stair in s.stairs) {
      if (stair.id == id) return path..addPolygon(stair.polygonCorners, true);
    }
    for (final axis in project.gridAxes) {
      if (axis.id == id) {
        return path
          ..moveTo(axis.start.dx, axis.start.dy)
          ..lineTo(axis.end.dx, axis.end.dy);
      }
    }
    for (final p in s.cadPrimitives) {
      if (p.id == id && p.type == CadPrimitiveType.rect) {
        return path..addPolygon(p.polygonCorners, true);
      }
    }
    final rect = bounds(project, id);
    if (rect != null) path.addRect(rect.inflate(.015));
    return path;
  }
}

class SetArchitectElementProperties extends ArchitectModelCommand {
  final String storeyId;
  final Set<String> elementIds;
  final Map<String, double> values;
  final Map<String, String> textValues;
  const SetArchitectElementProperties({
    required this.storeyId,
    required this.elementIds,
    this.values = const {},
    this.textValues = const {},
  });
  @override
  ArchitectProject apply(ArchitectProject project) {
    for (final entry in values.entries) {
      final value = entry.value;
      if (!value.isFinite) throw ArgumentError('Invalid property');
      if (!{'rotationDeg', 'elevation', 'offsetDistance'}.contains(entry.key) &&
          value <
              (entry.key == 'sillHeight' ||
                      entry.key == 'insulationThicknessOverride'
                  ? 0
                  : .001)) {
        throw ArgumentError('Invalid dimension');
      }
      if (entry.key == 'stepCount' &&
          (value != value.roundToDouble() || value < 1 || value > 1000)) {
        throw ArgumentError('Invalid steps');
      }
    }
    final json = project.toJson();
    final entries = ArchitectSelection.records(
      json,
      storeyId,
    ).where((e) => elementIds.contains(e['id'])).toList();
    if (entries.length != elementIds.length) {
      throw ArgumentError('Unknown element');
    }
    for (final e in entries) {
      final fields = ArchitectSelection.fields(project, e['id'] as String);
      for (final value in values.entries) {
        if (!fields.containsKey(value.key)) {
          throw ArgumentError('Unsupported property');
        }
        e[value.key] = value.key == 'stepCount'
            ? value.value.toInt()
            : value.value;
      }
      for (final value in textValues.entries) {
        if ((!e.containsKey(value.key) && value.key != 'styleId') ||
            !{
              'text',
              'label',
              'name',
              'specId',
              'customText',
              'referenceLine',
              'exteriorSide',
              'styleId',
              'followStoreyHeight',
              'coreMaterial',
              'insulationMaterial',
            }.contains(value.key)) {
          throw ArgumentError('Unsupported property');
        }
        if (value.key == 'followStoreyHeight') {
          if (!{'true', 'false'}.contains(value.value)) {
            throw ArgumentError('Invalid height mode');
          }
          e[value.key] = value.value == 'true';
        } else {
          e[value.key] = value.value;
        }
        if (value.key == 'coreMaterial' &&
                !WallCoreMaterial.values.any((m) => m.name == value.value) ||
            value.key == 'insulationMaterial' &&
                !WallInsulationMaterial.values.any(
                  (m) => m.name == value.value,
                )) {
          throw ArgumentError('Invalid wall material');
        }
        if (value.key == 'referenceLine' &&
                !WallReferenceLine.values.any((r) => r.name == value.value) ||
            value.key == 'exteriorSide' &&
                !WallExteriorSide.values.any(
                  (side) => side.name == value.value,
                )) {
          throw ArgumentError('Invalid side or reference');
        }
      }
      if (e.containsKey('referenceLine')) {
        final old = project.activeStorey.walls.firstWhere(
          (w) => w.id == e['id'],
        );
        if (values.containsKey('height') &&
            !textValues.containsKey('followStoreyHeight')) {
          e['followStoreyHeight'] = false;
        }
        if (e['followStoreyHeight'] == true && !old.isParapet) {
          e['height'] = project.activeStorey.height;
        }
        final insulation =
            values['insulationThicknessOverride'] ?? old.insulationThickness;
        final core =
            values['coreThickness'] ??
            (values.containsKey('thickness')
                ? values['thickness']! - insulation
                : old.coreThickness);
        if (core < .001) throw ArgumentError('Core too thin');
        if (values.containsKey('coreThickness') ||
            values.containsKey('insulationThicknessOverride')) {
          e['thickness'] = core + insulation;
        }
        e.remove('coreThickness');
      }
    }
    final next = ArchitectProject.fromJson(json);
    for (final wall in next.activeStorey.walls) {
      if (wall.insulationThicknessOverride != null &&
          wall.thickness <= wall.insulationThicknessOverride!) {
        throw ArgumentError('Insulation too thick');
      }
      for (final o in [
        ...wall.doors.map((d) => (d.offsetRatio, d.width)),
        ...wall.windows.map((w) => (w.offsetRatio, w.width)),
      ]) {
        if (o.$1 * wall.length < o.$2 / 2 ||
            o.$1 * wall.length + o.$2 / 2 > wall.length) {
          throw ArgumentError('Opening outside host');
        }
      }
    }
    var result = project;
    for (final wall in next.activeStorey.walls.where(
      (w) => elementIds.contains(w.id),
    )) {
      final old = project.activeStorey.walls.firstWhere((w) => w.id == wall.id);
      var updated = wall;
      final flipped = old.exteriorSide != wall.exteriorSide;
      if (flipped) {
        final shift = old.coreCenterStart - wall.coreCenterStart;
        updated = wall.copyWith(
          startPoint: wall.startPoint + shift,
          endPoint: wall.endPoint + shift,
        );
      }
      result = UpdateArchitectWall(
        storeyId: storeyId,
        wall: updated,
        carryConnections: !flipped,
      ).apply(result);
    }
    // Non-wall fields come from the same validated transaction.
    return ArchitectModelCommand.replace(
      next,
      next.activeStorey.copyWith(
        walls: [
          for (final wall in result.activeStorey.walls)
            elementIds.contains(wall.id) ||
                    !wall.doors.any((d) => elementIds.contains(d.id)) &&
                        !wall.windows.any((e) => elementIds.contains(e.id))
                ? wall
                : next.activeStorey.walls.firstWhere((w) => w.id == wall.id),
        ],
      ),
    );
  }
}
