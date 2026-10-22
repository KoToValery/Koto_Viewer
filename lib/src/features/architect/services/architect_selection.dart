import 'dart:ui';
import 'dart:math' as math;
import '../models/architect_column.dart';
import '../models/architect_project.dart';
import '../models/architect_elements.dart';
import '../models/architect_wall.dart';
import '../models/architect_door.dart';
import '../models/architect_wall_type.dart';
import '../rendering/architect_scene_geometry.dart';
import 'architect_command_controller.dart';
import 'architect_stair_rules.dart';
import '../../../core/l10n/l10n_extensions.dart';

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
    'baseOffset',
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
    if (e.containsKey('referenceLine') ||
        project.activeStorey.columns.any((c) => c.id == id) ||
        project.activeStorey.beams.any((b) => b.id == id)) {
      fields['baseOffset'] = (e['baseOffset'] as num?)?.toDouble() ?? 0.0;
    }
    if (e.containsKey('referenceLine')) {
      final wall = ArchitectWall.fromJson(e);
      if(wall.isCurved)fields['arcRadius']=wall.arc!.radius;
      fields['coreThickness'] = wall.coreThickness;
      fields['insulationThicknessOverride'] = wall.insulationThickness;
    }
    return fields;
  }

  static Rect? bounds(ArchitectProject project, String id) {
    final s = project.activeStorey;
    for (final component in s.components) {
      if (component.id == id) return component.worldBoundingRect;
    }
    for (final stair in s.stairs) {
      if (stair.id == id) return stair.plan.bounds;
    }
    for (final w in s.walls) {
      if (w.id == id) return ArchitectSceneGeometry.boundsOf(w.polygonCorners);
      for (final o in [
        ...w.doors.map((d) => (d.id, d.offsetRatio, d.width)),
        ...w.windows.map((e) => (e.id, e.offsetRatio, e.width)),
      ]) {
        if (o.$1 == id) {
          final center = w.centerPointAt(o.$2);
          return ArchitectSceneGeometry.boundsOf([
            center - w.tangentAt(o.$2) * o.$3 / 2 - w.normalAt(o.$2) * w.thickness / 2,
            center + w.tangentAt(o.$2) * o.$3 / 2 + w.normalAt(o.$2) * w.thickness / 2,
          ]);
        }
      }
    }
    for (final d in s.dimensions) {
      if (d.id == id) {
        return Rect.fromPoints(d.lineStart, d.lineEnd).inflate(.02);
      }
    }
    final e = record(project, id);
    Offset point(dynamic json) =>
        Offset((json['x'] as num).toDouble(), (json['y'] as num).toDouble());
    if (e['polygon'] is List || e['boundary'] is List || e['points'] is List) {
      return ArchitectSceneGeometry.boundsOf(
        (e['polygon'] ?? e['boundary'] ?? e['points'] as List)
            .cast<dynamic>()
            .map<Offset>(point),
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
    for (final component in s.components) {
      if (component.id == id) {
        return path..addPolygon(component.worldPolygonCorners, true);
      }
    }
    for (final d in s.dimensions) {
      if (d.id == id) {
        return path
          ..moveTo(d.lineStart.dx, d.lineStart.dy)
          ..lineTo(d.lineEnd.dx, d.lineEnd.dy);
      }
    }
    for (final w in s.walls) {
      if (w.id == id) return path..addPolygon(w.polygonCorners, true);
      for (final o in [
        ...w.doors.map((d) => (d.id, d.offsetRatio, d.width)),
        ...w.windows.map((e) => (e.id, e.offsetRatio, e.width)),
      ]) {
        if (o.$1 != id) continue;
        final p = w.centerPointAt(o.$2);
        final u = w.tangentAt(o.$2) * o.$3 / 2, n = w.normalAt(o.$2) * w.thickness / 2;
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
    for (final roof in s.roofs) {
      if (roof.id == id) return path..addPolygon(roof.points, true);
    }
    for (final zone in s.zones) {
      if (zone.id == id) return path..addPolygon(zone.polygon, true);
    }
    for (final opening in s.openings) {
      if (opening.id == id) return path..addPolygon(opening.boundary, true);
    }
    for (final stair in s.stairs) {
      if (stair.id == id) return stair.plan.path;
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

  static String summary(
    ArchitectProject project,
    Set<String> ids,
    AppLocalizations l, {
    bool compact = false,
  }) {
    if (ids.isEmpty) return '';
    final s = project.activeStorey;
    final wallCount = s.walls.where((w) => ids.contains(w.id)).length;
    final colCount = s.columns.where((c) => ids.contains(c.id)).length;
    final beamCount = s.beams.where((b) => ids.contains(b.id)).length;
    final slabCount = s.slabs.where((b) => ids.contains(b.id)).length;
    final roofCount = s.roofs.where((r) => ids.contains(r.id)).length;
    final zoneCount = s.zones.where((z) => ids.contains(z.id)).length;
    final doorCount = s.walls
        .expand((w) => w.doors)
        .where((d) => ids.contains(d.id))
        .length;
    final winCount = s.walls
        .expand((w) => w.windows)
        .where((win) => ids.contains(win.id))
        .length;
    final axisCount = project.gridAxes.where((a) => ids.contains(a.id)).length;
    final cadCount = s.cadPrimitives.where((c) => ids.contains(c.id)).length;

    final parts = <String>[];
    if (wallCount > 0) parts.add(l.architectSelectionWallsCount(wallCount));
    if (colCount > 0) parts.add(l.architectSelectionColumnsCount(colCount));
    if (beamCount > 0) parts.add(l.architectSelectionBeamsCount(beamCount));
    if (slabCount > 0) parts.add(l.architectSelectionSlabsCount(slabCount));
    if (roofCount > 0) parts.add('${l.architectRoofs}: $roofCount');
    if (doorCount > 0) parts.add(l.architectSelectionDoorsCount(doorCount));
    if (winCount > 0) parts.add(l.architectSelectionWindowsCount(winCount));
    if (zoneCount > 0) parts.add(l.architectSelectionZonesCount(zoneCount));
    if (axisCount > 0) parts.add(l.architectSelectionAxesCount(axisCount));
    if (cadCount > 0) parts.add(l.architectSelectionCadCount(cadCount));


    if (parts.length == 1) {
      return parts.first;
    }
    if (compact) return l.architectSelectionCount(ids.length);
    if (parts.length > 1) {
      return l.architectSelectionMixedSummary(ids.length, parts.join(', '));
    }
    return l.architectSelectionCount(ids.length);
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
      if (!{'rotationDeg', 'elevation', 'offsetDistance', 'baseOffset'}.contains(entry.key) &&
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
        if(value.key=='arcRadius') {
          final wall=ArchitectWall.fromJson(e),chord=(wall.endPoint-wall.startPoint).distance;
          if(value.value<chord/2)throw ArgumentError('Invalid arc radius');
          final root=math.sqrt(math.max(0,value.value*value.value-chord*chord/4));
          e['arcBulge']=wall.arcBulge.sign*(value.value+(wall.arcBulge.abs()>1?root:-root))/(chord/2);
          continue;
        }
        e[value.key] = value.key == 'stepCount' 
            ? value.value.toInt()
            : value.value;
        if (value.key == 'stepCount' && e['design'] is Map) {
          (e['design'] as Map)['manualRisers'] = value.value.toInt();
        }
      }
      for (final value in textValues.entries) {
        if ((!e.containsKey(value.key) && value.key != 'styleId' && value.key != 'cutDisplayMode') ||
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
              'cutDisplayMode',
              'isHingeLeft',
              'openInward',
            }.contains(value.key)) {
          throw ArgumentError('Unsupported property');
        }
        if (value.key == 'cutDisplayMode' &&
            !ArchitectCutDisplayMode.values.any((m) => m.name == value.value)) {
          throw ArgumentError('Invalid cut display mode');
        }
        if (value.key == 'isHingeLeft' || value.key == 'openInward') {
          if (!{'true', 'false'}.contains(value.value)) {
            throw ArgumentError('Invalid boolean value');
          }
          final boolVal = value.value == 'true';
          e[value.key] = boolVal;
          if (value.key == 'isHingeLeft' && !textValues.containsKey('specId')) {
            final currentSpec = e['specId'] as String?;
            if (currentSpec != null && currentSpec.isNotEmpty) {
              final base = ArchitectDoor.extractBaseNumber(currentSpec);
              if (base != null) {
                e['specId'] = ArchitectDoor.formatSpecId(baseNumber: base, isHingeLeft: boolVal);
              }
            }
          }
        } else if (value.key == 'followStoreyHeight') {
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
        if(old.layers.isNotEmpty && (values.containsKey('coreThickness') || values.containsKey('insulationThicknessOverride') || values.containsKey('thickness'))) {
          final list=[...old.layers];
          if(values.containsKey('thickness')&&!values.containsKey('coreThickness')&&list.length!=1)throw ArgumentError('Edit composition layers explicitly');
          for(final role in [ArchitectLayerRole.core,ArchitectLayerRole.insulation]) {
            final update=role==ArchitectLayerRole.core?values['coreThickness']??(list.length==1?values['thickness']:null):values['insulationThicknessOverride'];
            if(update==null)continue;
            final indices=[for(var i=0;i<list.length;i++)if(list[i].role==role)i];
            if(indices.length!=1)throw ArgumentError('Edit composition layers explicitly');
            if(update==0){list.removeAt(indices.single);}else{list[indices.single]=list[indices.single].copyWith(thickness:update);}
          }
          ArchitectMaterialLayer.validate(list);
          e['layers']=list.map((l)=>l.toJson()).toList();
          e['thickness']=list.fold(0.0,(v,l)=>v+l.thickness);
          e['insulationThicknessOverride']=list.where((l)=>l.role==ArchitectLayerRole.insulation).fold(0.0,(v,l)=>v+l.thickness);
        }
        e.remove('coreThickness');
      }
    }
    final next = ArchitectProject.fromJson(json);
    for (final stair in next.activeStorey.stairs.where((s) => elementIds.contains(s.id))) {
      if (stair.design != null && !stair.design!.isDraft &&
          ArchitectStairRules.check(stair).any((c) => c.state == StairCheckState.error)) {
        throw ArgumentError('Stair violates selected geometric rules');
      }
    }
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
      if (flipped && wall.isCurved) {
        updated=wall.copyWith(exteriorSide:old.exteriorSide).mirroredAroundCore();
      } else if (flipped) {
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
