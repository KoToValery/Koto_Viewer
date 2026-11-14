import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../../../core/l10n/generated/app_localizations.dart';

import '../../dxf_3d_viewer/models/mesh_3d.dart';
import '../models/architect_column.dart';
import '../models/architect_elements.dart';
import '../models/architect_project.dart';
import '../models/architect_wall.dart';
import '../rendering/architect_floor_drain_mesh.dart';
import '../rendering/architect_3d_builder.dart';
import '../rendering/architect_panel_roof_geometry.dart';
import '../rendering/architect_path_solid.dart';
import '../rendering/architect_railing_geometry.dart';
import '../rendering/architect_roof_drainage_mesh.dart';
import '../rendering/architect_stair_mesh.dart';
import '../rendering/architect_wall_solids.dart';
import 'architect_export_job.dart';
import 'architect_ifc_step_writer.dart';
import 'architect_roof_junctions.dart';
import 'architect_section_junctions.dart';
import 'architect_service_geometry.dart';
import 'architect_slab_geometry.dart';
import 'architect_stair_floor_contact.dart';
import 'architect_stair_geometry.dart';
import 'component_geometry_cache.dart';
import 'component_library_service.dart';

export 'architect_export_job.dart';

enum ArchitectIfcSchema { ifc2x3, ifc4 }

class ArchitectIfcNotice {
  final String elementId;

  /// Stable machine code, localized by the caller.
  final String code;
  const ArchitectIfcNotice(this.elementId, this.code);
}

class ArchitectIfcExportResult {
  final Uint8List bytes;
  final List<ArchitectIfcNotice> notices;
  final int parametricCount, fallbackCount;
  const ArchitectIfcExportResult({
    required this.bytes,
    required this.notices,
    required this.parametricCount,
    required this.fallbackCount,
  });
}

/// IFC exchange of the physical model. Paper drawings, crops, scale and view
/// visibility are intentionally absent from the physical-model snapshot.
class ArchitectIfcExport {
  static Future<ArchitectIfcExportResult> exportProject(
    ArchitectProject project,
    AppLocalizations l, {
    ArchitectIfcSchema schema = ArchitectIfcSchema.ifc2x3,
    void Function(double)? onProgress,
    bool Function()? isCancelled,
  }) async {
    architectCheckExportCancelled(isCancelled);
    final snapshot = ArchitectProject.fromJson(project.toJson());
    final dto = await _IfcPreparation(
      snapshot,
      onProgress,
      isCancelled,
    ).prepare();
    dto['schema'] = schema.name;
    final raw = await _serialize(dto, onProgress, isCancelled);
    architectCheckExportCancelled(isCancelled);
    onProgress?.call(1);
    return ArchitectIfcExportResult(
      bytes: raw['bytes'] as Uint8List,
      notices: List.unmodifiable(
        (raw['notices'] as List).map(
          (n) =>
              ArchitectIfcNotice(n['elementId'] as String, n['code'] as String),
        ),
      ),
      parametricCount: raw['parametricCount'] as int,
      fallbackCount: raw['fallbackCount'] as int,
    );
  }

  static Future<Map<String, dynamic>> _serialize(
    Map<String, dynamic> dto,
    void Function(double)? progress,
    bool Function()? cancelled,
  ) async {
    architectCheckExportCancelled(cancelled);
    final receive = ReceivePort(), errors = ReceivePort();
    final done = Completer<Map<String, dynamic>>();
    Isolate? worker;
    final subscription = receive.listen((message) {
      final data = message as Map;
      if (data.containsKey('progress')) {
        progress?.call(.65 + .35 * (data['progress'] as double));
      } else if (data.containsKey('result') && !done.isCompleted) {
        done.complete(Map<String, dynamic>.from(data['result'] as Map));
      }
    });
    final errorSubscription = errors.listen((error) {
      if (!done.isCompleted) {
        done.completeError(StateError((error as List).first.toString()));
      }
    });
    final timer = Timer.periodic(const Duration(milliseconds: 25), (_) {
      if ((cancelled?.call() ?? false) && !done.isCompleted) {
        worker?.kill(priority: Isolate.immediate);
        done.completeError(const ArchitectExportCancelled());
      }
    });
    try {
      worker = await Isolate.spawn(
        _ifcWorker,
        [receive.sendPort, dto],
        onError: errors.sendPort,
        errorsAreFatal: true,
        debugName: 'architect-ifc-step',
      );
      return await done.future;
    } finally {
      timer.cancel();
      worker?.kill(priority: Isolate.immediate);
      await subscription.cancel();
      await errorSubscription.cancel();
      receive.close();
      errors.close();
    }
  }
}

void _ifcWorker(List<dynamic> args) {
  final port = args[0] as SendPort;
  final result = architectWriteIfc(
    args[1] as Map<String, dynamic>,
    onProgress: (p) => port.send({'progress': p}),
  );
  port.send({'result': result});
}

class _IfcPreparation {
  final ArchitectProject project;
  final void Function(double)? progress;
  final bool Function()? cancelled;
  int _finished = 0;
  late final int _total = project.storeys.fold<int>(
    0,
    (sum, s) =>
        sum +
        s.walls.length +
        s.slabs.length +
        s.roofs.length +
        s.columns.length +
        s.beams.length +
        s.stairs.length +
        s.zones.length +
        s.components.length +
        s.floorDrains.length,
  );

  _IfcPreparation(this.project, this.progress, this.cancelled);

  Future<void> _checkpoint() => architectExportCheckpoint(
    .65 * ++_finished / math.max(_total, 1),
    onProgress: progress,
    isCancelled: cancelled,
  );

  Future<Map<String, dynamic>> prepare() async {
    await architectExportCheckpoint(
      0,
      onProgress: progress,
      isCancelled: cancelled,
    );
    final sourceIds = <String>{};
    for (final s in project.storeys) {
      final ids = <String>[
        for (final w in s.walls) ...[
          w.id,
          ...w.doors.map((d) => d.id),
          ...w.windows.map((w) => w.id),
        ],
        ...s.slabs.map((e) => e.id),
        ...s.roofs.map((e) => e.id),
        ...s.columns.map((e) => e.id),
        ...s.beams.map((e) => e.id),
        ...s.stairs.map((e) => e.id),
        ...s.zones.map((e) => e.id),
        ...s.components.map((e) => e.id),
        ...s.floorDrains.map((e) => e.id),
        ...s.openings.map((e) => e.id),
      ];
      for (final id in ids) {
        if (id.isEmpty || !sourceIds.add(id)) {
          throw ArchitectExportElementError(id, 'duplicateSourceId');
        }
      }
    }
    final storeys = <Map<String, dynamic>>[];
    for (final storey in project.storeys) {
      final elements = <Map<String, dynamic>>[];
      final suppressed = {
        for (final w in storey.walls) ...[
          for (final d in w.doors) d.id,
          for (final w in w.windows) w.id,
        ],
      };
      // These are original closed volumes BEFORE visual hidden-face removal.
      // Hosted voids are suppressed here; IFC cuts each host exactly once.
      final solids = await ArchitectWallSolids.buildAsync(
        storey,
        project,
        suppressedOpeningIds: suppressed,
      );
      architectCheckExportCancelled(cancelled);
      for (final wall in storey.walls) {
        try {
          _wall(
            storey,
            wall,
            solids.where((s) => s.wall.id == wall.id).toList(),
            elements,
          );
        } catch (error) {
          if (error is ArchitectExportElementError) rethrow;
          throw ArchitectExportElementError(wall.id, 'invalidGeometry');
        }
        await _checkpoint();
      }
      for (final slab in storey.slabs) {
        _slab(storey, slab, elements);
        await _checkpoint();
      }
      for (final opening in storey.openings) {
        if (elements.any(
          (e) => e['kind'] == 'opening' && e['sourceId'] == opening.id,
        )) {
          continue;
        }
        // A storey cut without a physical host is a 2D modelling intent. Keep
        // it traceable without inventing a solid or emitting an orphan void.
        elements.add({
          'id': opening.id,
          'kind': 'proxy',
          'name': opening.label.isEmpty ? opening.id : opening.label,
          'notice': 'unhostedOpening',
          'properties': {
            'SourceCategory': 'unhostedOpening',
            'OpeningType': opening.type.name,
            'FootprintMetres': [
              for (final p in opening.boundary) [p.dx, -p.dy],
            ].toString(),
          },
        });
      }
      for (final roof in storey.roofs) {
        _roof(storey, roof, elements);
        await _checkpoint();
      }
      for (final col in storey.columns) {
        _validDepth(col.width, col.id);
        _validDepth(col.depth, col.id);
        final angle = -col.rotationDeg * math.pi / 180;
        final shape = col.shape == ColumnShape.circular
            ? <String, dynamic>{
                'type': 'extrusion',
                'radius': col.width / 2,
                'depth': col.height ?? storey.height,
              }
            : _extrusion(
                _rect(col.width, col.depth),
                col.height ?? storey.height,
              );
        _validDepth(shape['depth'] as double, col.id);
        elements.add({
          'id': col.id,
          'kind': 'column',
          'name': col.label,
          'origin': [col.position.dx, -col.position.dy, col.baseOffset],
          'ref': [math.cos(angle), math.sin(angle), 0],
          'shapes': [shape],
          'properties': {
            'Width': col.width,
            'Depth': col.depth,
            'Height': col.height ?? storey.height,
          },
          'layers': [_layer('concrete', col.width)],
          'typeId': '${col.shape.name}:${col.width}:${col.depth}',
        });
        await _checkpoint();
      }
      for (final beam in storey.beams) {
        _validDepth(beam.depth, beam.id);
        if (beam.length < 1e-8 || beam.width <= 0) {
          throw ArchitectExportElementError(beam.id, 'invalidGeometry');
        }
        // Axis + cross section along the beam is preferable to a vertical box:
        // the local longitudinal axis remains available to BIM importers.
        final u = beam.unitVector;
        elements.add({
          'id': beam.id,
          'kind': 'beam',
          'name': beam.label,
          'origin': [beam.startPoint.dx, -beam.startPoint.dy, beam.baseOffset],
          'axis': [u.dx, -u.dy, 0],
          'ref': [u.dy, u.dx, 0],
          'curve': [
            [0, 0, 0],
            [0, 0, beam.length],
          ],
          'shapes': [
            _extrusion([
              [-beam.width / 2, 0],
              [beam.width / 2, 0],
              [beam.width / 2, beam.depth],
              [-beam.width / 2, beam.depth],
            ], beam.length),
          ],
          'properties': {
            'Width': beam.width,
            'Depth': beam.depth,
            'Length': beam.length,
          },
          'typeId': '${beam.width}:${beam.depth}',
        });
        await _checkpoint();
      }
      for (final stair in storey.stairs) {
        _stair(storey, stair, elements);
        await _checkpoint();
      }
      for (final zone in storey.zones) {
        if (zone.isApartment) {
          // Apartments are spatial groups, not a second overlapping room body.
          elements.add({
            'id': zone.id,
            'kind': 'zone',
            'name': zone.name,
            'properties': {'Number': zone.number},
          });
        } else {
          _validPolygon(zone.polygon, zone.id);
          _validDepth(zone.clearHeight, zone.id);
          elements.add({
            'id': zone.id,
            'kind': 'space',
            'name': zone.number,
            'longName': zone.name,
            'shapes': [_extrusion(_polygon(zone.polygon), zone.clearHeight)],
            'properties': {
              'Category': zone.category.name,
              'FloorFinish': zone.floorFinish,
              'WallFinish': zone.wallFinish,
              'CeilingFinish': zone.ceilingFinish,
              'Height': zone.clearHeight,
              if (zone.apartmentId != null) 'ApartmentId': zone.apartmentId,
            },
          });
        }
        await _checkpoint();
      }
      for (final component in storey.components) {
        final definition = ComponentLibraryService.instance.findDefinition(
          component.definitionId,
        );
        final shapes = <Map<String, dynamic>>[];
        if (definition != null) {
          final geometry = ComponentGeometryCache.instance.getOrCompute(
            definition,
            ArchitectServiceGeometry.parameters(project, storey, component),
          );
          final z =
              ArchitectServiceGeometry.baseElevation(
                project,
                storey,
                component,
              ) -
              storey.elevation;
          final c = math.cos(component.rotation),
              s = math.sin(component.rotation);
          final triangles = <List<List<double>>>[];
          List<double> point(Vector3 p) => [
            component.position.dx + p.x * c - p.y * s,
            -(component.position.dy + p.x * s + p.y * c),
            z + p.z,
          ];
          for (final t in geometry.mesh3d.triangles) {
            triangles.add([point(t.v0), point(t.v2), point(t.v1)]);
          }
          if (triangles.isNotEmpty) {
            shapes.add({'type': 'mesh', 'triangles': triangles});
          }
          for (final additional in [
            ArchitectServiceGeometry.flashing(project, storey, component),
            ArchitectServiceGeometry.terminal(project, storey, component),
          ]) {
            if (additional.isNotEmpty) {
              shapes.add(_mesh(additional, storey.elevation));
            }
          }
        }
        elements.add({
          'id': component.id,
          'kind': 'proxy',
          'name': component.label.isEmpty ? component.id : component.label,
          'shapes': shapes,
          'properties': {
            'DefinitionId': component.definitionId,
            'Parameters': component.parameters.toString(),
            'Rotation': component.rotation,
          },
        });
        await _checkpoint();
      }
      for (final drain in storey.floorDrains) {
        final triangles = ArchitectFloorDrainMesh.build(project, storey, drain);
        if (triangles.isEmpty) {
          throw ArchitectExportElementError(drain.id, 'invalidGeometry');
        }
        elements.add({
          'id': drain.id,
          'kind': 'proxy',
          'name': drain.id,
          'shapes': [_mesh(triangles, storey.elevation)],
          'properties': {
            'SourceCategory': 'floorDrain',
            'SlopePercent': drain.slopePercent,
          },
        });
        await _checkpoint();
      }
      storeys.add({
        'id': storey.id,
        'name': storey.name,
        'elevation': storey.elevation,
        'height': storey.height,
        'elements': elements,
      });
    }
    return {
      'id': project.id,
      'name': project.name,
      'timestamp': project.updatedAt.toUtc().millisecondsSinceEpoch ~/ 1000,
      'storeys': storeys,
    };
  }

  void _wall(
    ArchitectStorey storey,
    ArchitectWall wall,
    List<ArchitectWallSolid> solids,
    List<Map<String, dynamic>> out,
  ) {
    final shapes = <Map<String, dynamic>>[];
    final element = <String, dynamic>{
      'id': wall.id,
      'kind': 'wall',
      'name': wall.id,
      'typeId': wall.wallTypeId ?? wall.id,
      'shapes': shapes,
      'properties': {
        'Thickness': wall.thickness,
        'Height': wall.effectiveHeight(storey.height),
        'BaseOffset': wall.baseOffset,
        'System': wall.system.kind.name,
        'ReferenceLine': wall.referenceLine.name,
      },
    };
    final body = wall.hasSolidWallBody;
    if (body) {
      if (solids.isEmpty) {
        throw ArchitectExportElementError(wall.id, 'invalidGeometry');
      }
      final bottom = solids.map((s) => s.bottom).reduce(math.min);
      final top = solids.map((s) => s.top).reduce(math.max);
      var path = Path();
      for (final s in solids) {
        path = Path.combine(PathOperation.union, path, s.path);
      }
      final contours = ArchitectPathSolid.contours(path);
      var uniform =
          !wall.isCurved &&
          !wall.system.isSpecial &&
          contours.length == 1 &&
          solids.every(
            (s) => s.triangles.every(
              (t) => [t.v0, t.v1, t.v2].every(
                (p) =>
                    (p.z - s.bottom).abs() < 1e-6 || (p.z - s.top).abs() < 1e-6,
              ),
            ),
          );
      if (uniform) {
        // Other walls' height events can split an unchanged wall into several
        // z-bands. Merge them back only when every band has the same footprint.
        final levels = {
          for (final s in solids) ...[s.bottom, s.top],
        }.toList()..sort();
        for (var i = 0; i + 1 < levels.length && uniform; i++) {
          final mid = (levels[i] + levels[i + 1]) / 2;
          var band = Path();
          for (final s in solids.where((s) => s.bottom < mid && s.top > mid)) {
            band = Path.combine(PathOperation.union, band, s.path);
          }
          final difference = Path.combine(PathOperation.difference, path, band);
          uniform =
              ArchitectPathSolid.contours(
                difference,
              ).fold<double>(0, (sum, contour) => sum + _area(contour)) <
              1e-8;
        }
      }
      if (uniform) {
        final u = Offset(wall.unitVector.dx, -wall.unitVector.dy);
        final n = Offset(-u.dy, u.dx);
        final origin = Offset(wall.startPoint.dx, -wall.startPoint.dy);
        final polygon = [
          for (final p in contours.single)
            [
              (p.dx - origin.dx) * u.dx + (-p.dy - origin.dy) * u.dy,
              (p.dx - origin.dx) * n.dx + (-p.dy - origin.dy) * n.dy,
            ],
        ];
        element.addAll({
          'origin': [origin.dx, origin.dy, bottom - storey.elevation],
          'ref': [u.dx, u.dy, 0],
          'curve': [
            [0, 0],
            [wall.length, 0],
          ],
          'standard': true,
          'layerOffset': -wall.centerLineOffset - wall.thickness / 2,
        });
        shapes.add(_extrusion(polygon, top - bottom));
      } else {
        for (final s in solids) {
          if (s.triangles.isNotEmpty) {
            shapes.add(_mesh(s.triangles, storey.elevation));
          }
        }
      }
      final layers = wall.exteriorSign > 0
          ? wall.resolvedLayers
          : wall.resolvedLayers.reversed.toList();
      element['layers'] = [
        for (final l in layers)
          _layer(l.material.name, l.thickness, name: l.id),
      ];
      out.add(element);
    }
    if (wall.hasRailingDesign) {
      final components = ArchitectRailingGeometry.components(
        wall,
        storeyElevation: storey.elevation,
        walls: storey.walls,
      );
      if (components.isNotEmpty) {
        out.add({
          'id': body ? '${wall.id}:railing' : wall.id,
          'sourceId': wall.id,
          'kind': 'railing',
          'name': wall.id,
          'shapes': [
            for (final c in components)
              if (c.triangles.isNotEmpty) _mesh(c.triangles, storey.elevation),
          ],
          'properties': {'SourceCategory': 'railing'},
        });
      } else if (!body) {
        throw ArchitectExportElementError(wall.id, 'invalidGeometry');
      }
    }
    if (!body) return;
    for (final door in wall.doors) {
      final openingId = '${door.id}:opening';
      _hostedOpening(
        storey,
        wall,
        openingId,
        door.offsetRatio,
        door.width,
        door.height,
        door.sillHeight,
        out,
      );
      out.add({
        'id': door.id,
        'kind': 'door',
        'name': door.specId,
        'openingId': openingId,
        'height': door.height,
        'width': door.width,
        'typeId': door.styleId ?? door.specId,
        'operation': door.isLeftHand
            ? 'SINGLE_SWING_LEFT'
            : 'SINGLE_SWING_RIGHT',
        'shapes': [
          _mesh(
            door.build3D(
              wallStart: wall.centerStart,
              wallEnd: wall.centerEnd,
              wallThickness: wall.thickness,
              storeyElevation: storey.elevation + wall.baseOffset,
              exteriorSign: wall.exteriorSign,
            ),
            storey.elevation,
          ),
        ],
        'properties': {
          'HostId': wall.id,
          'SillHeight': door.sillHeight,
          'OpenAngle': door.openAngleDeg,
          'SourceUuid': door.uuid,
        },
      });
    }
    for (final window in wall.windows) {
      final openingId = '${window.id}:opening';
      _hostedOpening(
        storey,
        wall,
        openingId,
        window.offsetRatio,
        window.width,
        window.height,
        window.sillHeight,
        out,
      );
      out.add({
        'id': window.id,
        'kind': 'window',
        'name': window.specId,
        'openingId': openingId,
        'height': window.height,
        'width': window.width,
        'typeId': window.styleId ?? window.specId,
        'shapes': [
          _mesh(
            window.build3D(
              wallStart: wall.centerStart,
              wallEnd: wall.centerEnd,
              wallThickness: wall.thickness,
              storeyElevation: storey.elevation + wall.baseOffset,
              exteriorSign: wall.exteriorSign,
            ),
            storey.elevation,
          ),
        ],
        'properties': {
          'HostId': wall.id,
          'SillHeight': window.sillHeight,
          'SourceUuid': window.uuid,
        },
      });
    }
  }

  void _hostedOpening(
    ArchitectStorey storey,
    ArchitectWall wall,
    String id,
    double ratio,
    double width,
    double height,
    double sill,
    List<Map<String, dynamic>> out,
  ) {
    _validDepth(width, id);
    _validDepth(height, id);
    final p = wall.centerPointAt(ratio), t = wall.tangentAt(ratio);
    if (wall.isCurved) {
      final half = width / wall.length / 2;
      final polygon = wall.facePolygon(
        wall.centerLineOffset - wall.thickness / 2 - .001,
        wall.centerLineOffset + wall.thickness / 2 + .001,
        from: ratio - half,
        to: ratio + half,
      );
      out.add({
        'id': id,
        'kind': 'opening',
        'name': id,
        'hostId': wall.id,
        'shapes': [
          _extrusion(
            _polygon(polygon),
            height,
            origin: [0, 0, wall.baseOffset + sill],
          ),
        ],
      });
      return;
    }
    out.add({
      'id': id,
      'kind': 'opening',
      'name': id,
      'hostId': wall.id,
      'origin': [p.dx, -p.dy, wall.baseOffset + sill],
      'ref': [t.dx, -t.dy, 0],
      'shapes': [_extrusion(_rect(width, wall.thickness + .002), height)],
    });
  }

  void _slab(
    ArchitectStorey storey,
    ArchitectSlab slab,
    List<Map<String, dynamic>> out,
  ) {
    _validPolygon(slab.polygon, slab.id);
    _validDepth(slab.thickness, slab.id);
    final assembly = ArchitectSectionJunctions.resolveEffectiveSlabAssembly(
      project,
      storey,
      slab,
    );
    final surfaces = ArchitectSlabGeometry.surfaces(
      project,
      storey,
      slab,
      assemblyOverride: assembly,
    );
    final p = slab.polygon.first;
    final bottom = surfaces.last.bottomAt(p), top = surfaces.first.topAt(p);
    final uniform = surfaces.every(
      (s) => slab.polygon.every(
        (q) =>
            (s.bottomAt(q) - s.bottomAt(p)).abs() < 1e-7 &&
            (s.topAt(q) - s.topAt(p)).abs() < 1e-7,
      ),
    );
    final path = Path()..addPolygon(slab.polygon, true);
    final shapes = uniform
        ? [
            _extrusion(
              _polygon(slab.polygon),
              top - bottom,
              origin: [0, 0, bottom - storey.elevation],
            ),
          ]
        : [
            for (final s in surfaces)
              _mesh(
                ArchitectPathSolid.between(
                  path,
                  s.bottomAt,
                  s.topAt,
                  const Color(0xffaaaaaa),
                ),
                storey.elevation,
              ),
          ];
    out.add({
      'id': slab.id,
      'kind': 'slab',
      'name': slab.label,
      'typeId': slab.assemblyId ?? slab.id,
      'shapes': shapes,
      'layerAxis': 'AXIS3',
      'layerOffset': bottom - storey.elevation,
      'layers': [
        for (final s in surfaces.reversed)
          _layer(s.layer.material.name, s.layer.thickness, name: s.layer.id),
      ],
      'properties': {
        'CoreThickness': slab.thickness,
        'CoreTopOffset': slab.coreTopOffset,
        'GrossArea': _area(slab.polygon),
      },
    });
    final holes = ArchitectSlabGeometry.holes(storey, slab, project: project);
    for (var i = 0; i < holes.length; i++) {
      final h = holes[i];
      if (h.length < 3) continue;
      final overlap = Path.combine(
        PathOperation.intersect,
        path,
        Path()..addPolygon(h, true),
      );
      if (overlap.computeMetrics().isEmpty) continue;
      final low = slab.polygon.map(surfaces.last.bottomAt).reduce(math.min);
      final high = slab.polygon.map(surfaces.first.topAt).reduce(math.max);
      final sourceIndex = i - slab.holes.length;
      final source = sourceIndex >= 0 && sourceIndex < storey.openings.length
          ? storey.openings[sourceIndex]
          : null;
      final sourceId = source?.id ?? 'contour:${_contourId(h)}';
      final openingId = '${slab.id}:opening:$sourceId';
      // Coincident legacy/service holes can repeat; one physical cut suffices.
      if (out.any((e) => e['id'] == openingId)) continue;
      out.add({
        'id': openingId,
        'sourceId': source?.id ?? slab.id,
        'kind': 'opening',
        'name': source?.label ?? openingId,
        'hostId': slab.id,
        'properties': {if (source != null) 'OpeningType': source.type.name},
        'shapes': [
          _extrusion(
            _polygon(h),
            high - low + .002,
            origin: [0, 0, low - storey.elevation - .001],
          ),
        ],
      });
    }
  }

  String _contourId(List<Offset> contour) {
    final points = _polygon(contour);
    var first = 0;
    for (var i = 1; i < points.length; i++) {
      if (points[i][0] < points[first][0] ||
          (points[i][0] == points[first][0] &&
              points[i][1] < points[first][1])) {
        first = i;
      }
    }
    final canonical = [
      for (var i = 0; i < points.length; i++)
        points[(first + i) % points.length]
            .map((v) => (v * 1e7).round())
            .join(','),
    ].join(';');
    return architectIfcGuid(project.id, canonical);
  }

  void _roof(
    ArchitectStorey storey,
    ArchitectRoofPlane roof,
    List<Map<String, dynamic>> out,
  ) {
    _validPolygon(roof.points, roof.id);
    final thickness = roof.assembly.totalThickness;
    _validDepth(thickness, roof.id);
    _validDepth(math.cos(roof.slopeRadians), roof.id);
    out.add({
      'id': roof.id,
      'kind': 'roof',
      'name': roof.id,
      'predefined': roof.slopeDegrees.abs() < 1e-6 ? 'FLAT_ROOF' : 'SHED_ROOF',
      'properties': {
        'SlopeDegrees': roof.slopeDegrees,
        'BaseElevationOffset': roof.baseElevationOffset,
        'AssemblyId': roof.assembly.id,
      },
    });
    final drainage = ArchitectRoofDrainageMesh.build(project, storey, roof);
    if (drainage.isNotEmpty) {
      out.add({
        'id': '${roof.id}:drainage',
        'sourceId': roof.id,
        'parentId': roof.id,
        'kind': 'drainage',
        'name': roof.id,
        'shapes': [_mesh(drainage, storey.elevation)],
        'properties': {'SourceCategory': 'roofDrainage'},
      });
    }
    if (roof.assembly.panels != null) {
      final components = ArchitectPanelRoofGeometry.build(
        storey,
        roof,
        project: project,
      );
      if (components.isEmpty) {
        throw ArchitectExportElementError(roof.id, 'invalidGeometry');
      }
      for (final c in components) {
        if (c.triangles.isEmpty) continue;
        out.add({
          'id': '${roof.id}:${c.id}',
          'sourceId': roof.id,
          'parentId': roof.id,
          'kind': c.structural ? 'beam' : 'slab',
          'predefined': c.structural ? 'BEAM' : 'ROOF',
          'name': c.id,
          'shapes': [_mesh(c.triangles, storey.elevation)],
          'properties': {'Material': c.material.name},
        });
      }
      return;
    }
    final path = ArchitectRoofJunctions.of(
      storey,
      project: project,
    ).footprint(roof);
    final contours = ArchitectPathSolid.contours(path);
    if (contours.isEmpty) {
      throw ArchitectExportElementError(roof.id, 'invalidGeometry');
    }
    final shapes = <Map<String, dynamic>>[];
    final placement = <String, dynamic>{};
    final detailed = roof.assembly.timber.hasRafters && roof.slopeDegrees >= 1;
    if (!roof.isMansard && !detailed && contours.length == 1) {
      // The underside profile lies in the actual sloped plane. Vertical
      // extrusion retains vertical eaves/ridge cuts and normal layer thickness.
      final u = roof.slopeDirection;
      final slope = roof.slopeRadians, c = math.cos(slope), s = math.sin(slope);
      if (c.abs() < 1e-6) {
        throw ArchitectExportElementError(roof.id, 'invalidGeometry');
      }
      final p = contours.single.first;
      final x = [u.dx * c, -u.dy * c, s];
      final z = [-u.dx * s, u.dy * s, c];
      final y = [u.dy, u.dx, 0.0];
      final polygon = [
        for (final q in contours.single)
          [
            ((q.dx - p.dx) * u.dx + (q.dy - p.dy) * u.dy) / c,
            (q.dx - p.dx) * y[0] - (q.dy - p.dy) * y[1],
          ],
      ];
      placement.addAll({
        'origin': [p.dx, -p.dy, roof.undersideElevationAt(p)],
        'axis': z,
        'ref': x,
      });
      shapes.add({
        'type': 'extrusion',
        'polygon': _ccw(polygon),
        'direction': [s, 0, c],
        'depth': thickness / c,
      });
    } else {
      final triangles = Architect3dBuilder.buildRoofBody(project, storey, roof);
      if (triangles.isEmpty) {
        throw ArchitectExportElementError(roof.id, 'invalidGeometry');
      }
      shapes.add(_mesh(triangles, storey.elevation));
    }
    out.add({
      'id': '${roof.id}:body',
      'sourceId': roof.id,
      'parentId': roof.id,
      'kind': 'slab',
      'predefined': 'ROOF',
      'name': roof.id,
      'shapes': shapes,
      ...placement,
      'typeId': roof.assembly.id.isEmpty ? roof.id : roof.assembly.id,
      'layerAxis': 'AXIS3',
      'layerOffset': 0.0,
      'layers': [
        for (final l in roof.assembly.layers.reversed)
          _layer(l.material.name, roof.assembly.layerDepth(l), name: l.id),
      ],
      'properties': {
        'SlopeDegrees': roof.slopeDegrees,
        'NormalThickness': thickness,
      },
    });
  }

  void _stair(
    ArchitectStorey storey,
    ArchitectStair stair,
    List<Map<String, dynamic>> out,
  ) {
    final d = stair.design;
    final body = ArchitectStairMesh.body(
      stair,
      firstRiserBottom: ArchitectStairFloorContact.firstRiserBottom(
        project,
        storey,
        stair,
      ),
    );
    final type = d == null
        ? 'STRAIGHT_RUN_STAIR'
        : switch (d.shape) {
            StairShape.straight => 'STRAIGHT_RUN_STAIR',
            StairShape.quarterTurn => 'QUARTER_TURN_STAIR',
            StairShape.halfTurn => 'HALF_TURN_STAIR',
            StairShape.spiral || StairShape.spiralOverlap => 'SPIRAL_STAIR',
          };
    final shapes = [
      for (final solid in body)
        if (solid.triangles.isNotEmpty) _mesh(solid.triangles, 0),
    ];
    final parent = <String, dynamic>{
      'id': stair.id,
      'kind': 'stair',
      'name': stair.id,
      'predefined': type,
      'shapes': shapes,
      'properties': {
        'Width': stair.width,
        'Rise': d?.rise ?? storey.height,
        'StartOffset': d?.startOffset ?? 0,
      },
    };
    out.add(parent);
    if (d == null) {
      // Legacy straight stairs have a footprint and count rather than a rich
      // construction design. Preserve those source parameters as a flight.
      if (stair.stepCount < 2 || stair.length <= 0 || stair.width <= 0) {
        throw ArchitectExportElementError(stair.id, 'invalidGeometry');
      }
      final rise = storey.height, count = stair.stepCount;
      final going = stair.length / count, riser = rise / count;
      final side = <List<double>>[
        [0, 0],
        [stair.length, 0],
        [stair.length, rise],
      ];
      for (var i = count - 1; i >= 0; i--) {
        side.addAll([
          [i * going, (i + 1) * riser],
          [i * going, i * riser],
        ]);
      }
      final u = stair.unitVector;
      final n = stair.normalVector;
      final start = stair.startPoint - n * stair.width / 2;
      out.add({
        'id': '${stair.id}:flight:0',
        'parentId': stair.id,
        'sourceId': stair.id,
        'kind': 'flight',
        'name': stair.id,
        'origin': [start.dx, -start.dy, 0],
        'axis': [n.dx, -n.dy, 0],
        'ref': [u.dx, -u.dy, 0],
        'shapes': [_extrusion(side, stair.width)],
        'risers': count,
        'treads': count,
        'riser': riser,
        'going': going,
      });
    } else {
      if (shapes.isEmpty) {
        throw ArchitectExportElementError(stair.id, 'invalidGeometry');
      }
      final geometry = ArchitectStairGeometry.of(stair);
      final flightBodies = [
        for (final _ in geometry.flights) <Map<String, dynamic>>[],
      ];
      final landingBodies = [
        for (final _ in geometry.landings) <Map<String, dynamic>>[],
      ];
      if (geometry.flights.isNotEmpty) {
        // Move each original closed construction solid intact onto its physical
        // flight/landing. Never cut a mesh at a display boundary or duplicate
        // the complete stair on every child.
        shapes.clear();
        parent['metadataOnly'] = true;
        for (final solid in body) {
          if (solid.triangles.isEmpty) continue;
          var x = 0.0, y = 0.0, z = 0.0;
          var count = 0;
          for (final t in solid.triangles) {
            for (final p in [t.v0, t.v1, t.v2]) {
              x += p.x;
              y += p.y;
              z += p.z;
              count++;
            }
          }
          final center = Offset(x / count, y / count);
          final height = z / count;
          var landingIndex = -1;
          for (var i = 0; i < geometry.landings.length; i++) {
            final l = geometry.landings[i];
            if ((Path()..addPolygon(l.polygon, true)).contains(center) &&
                (height - (l.elevation + d.startOffset)).abs() <=
                    d.concreteThickness + d.finishThickness + d.stringerDepth) {
              landingIndex = i;
              break;
            }
          }
          if (landingIndex >= 0) {
            landingBodies[landingIndex].add(_mesh(solid.triangles, 0));
          } else {
            var nearest = 0, distance = double.infinity;
            for (var i = 0; i < geometry.flights.length; i++) {
              final f = geometry.flights[i];
              final delta = center - f.origin;
              final along = (delta.dx * f.axis.dx + delta.dy * f.axis.dy).clamp(
                0.0,
                f.run,
              );
              final onAxis = f.origin + f.axis * along;
              final dz =
                  height -
                  (f.base +
                      d.startOffset +
                      (f.run <= 1e-8 ? 0 : along / f.run * (f.top - f.base)));
              final distanceToFlight =
                  (center - onAxis).distanceSquared + dz * dz;
              if (distanceToFlight < distance) {
                distance = distanceToFlight;
                nearest = i;
              }
            }
            flightBodies[nearest].add(_mesh(solid.triangles, 0));
          }
        }
      }
      for (var i = 0; i < geometry.flights.length; i++) {
        final f = geometry.flights[i];
        out.add({
          'id': '${stair.id}:flight:$i',
          'sourceId': stair.id,
          'parentId': stair.id,
          'kind': 'flight',
          'name': '${stair.id}:$i',
          'shapes': flightBodies[i],
          'metadataOnly': flightBodies[i].isEmpty,
          'risers': f.count,
          'treads': f.count - 1,
          'riser': f.riser,
          'going': f.going,
          'properties': {'FirstRiser': f.firstRiser, 'Width': f.width},
        });
      }
      for (var i = 0; i < geometry.landings.length; i++) {
        final landing = geometry.landings[i];
        out.add({
          'id': '${stair.id}:landing:$i',
          'sourceId': stair.id,
          'parentId': stair.id,
          'kind': 'slab',
          'predefined': 'LANDING',
          'name': '${stair.id}:$i',
          'shapes': landingBodies[i],
          'metadataOnly': landingBodies[i].isEmpty,
          'properties': {
            'Elevation': landing.elevation + d.startOffset,
            'Area': _area(landing.polygon),
          },
        });
      }
    }
    final railings = ArchitectStairMesh.railings(
      stair,
      storey: storey,
      project: project,
    );
    if (railings.isNotEmpty) {
      out.add({
        'id': '${stair.id}:railing',
        'sourceId': stair.id,
        'kind': 'railing',
        'name': stair.id,
        'shapes': [for (final r in railings) _mesh(r.triangles, 0)],
      });
    }
  }
}

Map<String, dynamic> _mesh(List<Triangle3D> triangles, double zBase) {
  List<double> point(Vector3 p) => [p.x, -p.y, p.z - zBase];
  return {
    'type': 'mesh',
    'triangles': [
      for (final t in triangles) [point(t.v0), point(t.v2), point(t.v1)],
    ],
  };
}

Map<String, dynamic> _extrusion(
  List<List<double>> polygon,
  double depth, {
  List<double>? origin,
}) => {
  'type': 'extrusion',
  'polygon': _ccw(polygon),
  'depth': depth,
  'origin': ?origin,
};

Map<String, dynamic> _layer(
  String material,
  double thickness, {
  String? name,
}) => {'material': material, 'thickness': thickness, 'name': name ?? material};

List<List<double>> _polygon(List<Offset> polygon) => _ccw([
  for (final p in polygon) [p.dx, -p.dy],
]);

List<List<double>> _rect(double width, double depth) => [
  [-width / 2, -depth / 2],
  [width / 2, -depth / 2],
  [width / 2, depth / 2],
  [-width / 2, depth / 2],
];

List<List<double>> _ccw(List<List<double>> polygon) {
  final result = <List<double>>[];
  for (final p in polygon) {
    if (result.isEmpty ||
        (p[0] - result.last[0]).abs() + (p[1] - result.last[1]).abs() > 1e-9) {
      result.add(p);
    }
  }
  if (result.length > 2 &&
      (result.first[0] - result.last[0]).abs() +
              (result.first[1] - result.last[1]).abs() <
          1e-9) {
    result.removeLast();
  }
  var area = 0.0;
  for (var i = 0; i < result.length; i++) {
    final p = result[i], q = result[(i + 1) % result.length];
    area += p[0] * q[1] - p[1] * q[0];
  }
  return area < 0 ? result.reversed.toList() : result;
}

double _area(List<Offset> points) {
  var area = 0.0;
  for (var i = 0; i < points.length; i++) {
    final p = points[i], q = points[(i + 1) % points.length];
    area += p.dx * q.dy - p.dy * q.dx;
  }
  return area.abs() / 2;
}

void _validPolygon(List<Offset> polygon, String id) {
  if (polygon.length < 3 ||
      _area(polygon) < 1e-10 ||
      polygon.any((p) => !p.dx.isFinite || !p.dy.isFinite)) {
    throw ArchitectExportElementError(id, 'invalidGeometry');
  }
}

void _validDepth(double depth, String id) {
  if (!depth.isFinite || depth <= 1e-8) {
    throw ArchitectExportElementError(id, 'invalidGeometry');
  }
}
