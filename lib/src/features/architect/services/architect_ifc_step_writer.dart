// This module deliberately has no dart:ui dependency: STEP serialization and
// topology validation run on the export isolate, never on the drawing isolate.
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Stable IFC compressed UUID, independent of traversal order and export time.
String architectIfcGuid(String projectId, String sourceId) {
  final hash = sha256.convert(utf8.encode('$projectId\u0000$sourceId')).bytes;
  var value = BigInt.zero;
  for (final b in hash.take(16)) {
    value = (value << 8) | BigInt.from(b);
  }
  const alphabet =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_\$';
  var result = '';
  for (var i = 0; i < 22; i++) {
    result = alphabet[(value & BigInt.from(63)).toInt()] + result;
    value >>= 6;
  }
  return result;
}

/// Plain-data entry point. All coordinates are right handed, metres, Z up.
Map<String, dynamic> architectWriteIfc(
  Map<String, dynamic> document, {
  void Function(double)? onProgress,
}) => _IfcStepWriter(document, onProgress).write();

class _IfcStepWriter {
  final Map<String, dynamic> document;
  final void Function(double)? onProgress;
  final _lines = <String>[];
  final _notices = <Map<String, String>>[];
  final _materials = <String, String>{};
  final _types = <String, String>{};
  final _typeAssignments = <String, List<String>>{};
  final _brepShells = <String, String>{};
  late final String _owner, _context;
  late final bool _ifc4 = document['schema'] == 'ifc4';
  late final String _projectId = document['id'] as String;
  int _parametricCount = 0, _fallbackCount = 0;

  _IfcStepWriter(this.document, this.onProgress);

  String _add(String type, String args) {
    final reference = '#${_lines.length + 1}';
    _lines.add('$reference=$type($args);');
    return reference;
  }

  String _guid(String id) => _s(architectIfcGuid(_projectId, id));
  String _root(String id, String name) => '${_guid(id)},$_owner,${_s(name)},\$';
  String _point(List<dynamic> p) =>
      _add('IFCCARTESIANPOINT', '(${p.map((v) => _n(v as num)).join(',')})');
  String _direction(List<dynamic> p) =>
      _add('IFCDIRECTION', '(${p.map((v) => _n(v as num)).join(',')})');
  String _axis(List<dynamic> p, [List<dynamic>? z, List<dynamic>? x]) => _add(
    'IFCAXIS2PLACEMENT3D',
    '${_point(p)},${z == null && x == null ? '\$' : _direction(z ?? [0, 0, 1])},${z == null && x == null ? '\$' : _direction(x ?? [1, 0, 0])}',
  );
  String _placement(
    String? relative,
    List<dynamic> p, [
    List<dynamic>? z,
    List<dynamic>? x,
  ]) => _add('IFCLOCALPLACEMENT', '${relative ?? '\$'},${_axis(p, z, x)}');

  Map<String, dynamic> write() {
    final person = _add('IFCPERSON', '\$,\'KoToViewer\',\$,\$,\$,\$,\$,\$');
    final org = _add('IFCORGANIZATION', '\$,\'KoToViewer\',\$,\$,\$');
    final user = _add('IFCPERSONANDORGANIZATION', '$person,$org,\$');
    final app = _add(
      'IFCAPPLICATION',
      '$org,\'1.0\',\'KoToViewer\',\'KoToViewer\'',
    );
    final timestamp = document['timestamp'] as int;
    _owner = _add(
      'IFCOWNERHISTORY',
      '$user,$app,\$,.ADDED.,$timestamp,$user,$app,$timestamp',
    );
    _context = _add(
      'IFCGEOMETRICREPRESENTATIONCONTEXT',
      '\$,\'Model\',3,0.000001,${_axis([0, 0, 0])},\$',
    );
    final units = _add(
      'IFCUNITASSIGNMENT',
      '(${[_add('IFCSIUNIT', '*,.LENGTHUNIT.,\$,.METRE.'), _add('IFCSIUNIT', '*,.AREAUNIT.,\$,.SQUARE_METRE.'), _add('IFCSIUNIT', '*,.VOLUMEUNIT.,\$,.CUBIC_METRE.'), _add('IFCSIUNIT', '*,.PLANEANGLEUNIT.,\$,.RADIAN.')].join(',')})',
    );
    final project = _add(
      'IFCPROJECT',
      '${_root('project', document['name'] as String)},\$,\$,\$,($_context),$units',
    );
    final sitePlacement = _placement(null, [0, 0, 0]);
    final site = _add(
      'IFCSITE',
      '${_root('site', document['name'] as String)},\$,$sitePlacement,\$,\$,.ELEMENT.,\$,\$,\$,\$,\$',
    );
    final buildingPlacement = _placement(sitePlacement, [0, 0, 0]);
    final building = _add(
      'IFCBUILDING',
      '${_root('building', document['name'] as String)},\$,$buildingPlacement,\$,\$,.ELEMENT.,\$,\$,\$',
    );
    _aggregate('project-site', project, [site]);
    _aggregate('site-building', site, [building]);
    final storeys = document['storeys'] as List<dynamic>;
    final storeyRefs = <String>[];
    var finished = 0;
    final total = storeys.fold<int>(
      0,
      (n, s) => n + ((s as Map)['elements'] as List).length,
    );
    for (final raw in storeys) {
      final storey = raw as Map<String, dynamic>;
      final storeyId = storey['id'] as String;
      final placement = _placement(buildingPlacement, [
        0,
        0,
        storey['elevation'],
      ]);
      final storeyRef = _add(
        'IFCBUILDINGSTOREY',
        '${_root('storey:$storeyId', storey['name'] as String)},\$,$placement,\$,\$,.ELEMENT.,${_n(storey['elevation'] as num)}',
      );
      storeyRefs.add(storeyRef);
      _properties(storeyRef, 'storey:$storeyId', {
        'SourceId': storeyId,
        'Height': storey['height'],
      });
      final references = <String, String>{};
      final elements = storey['elements'] as List<dynamic>;
      final contained = <String>[];
      final spaces = <String>[];
      for (final e in elements) {
        final element = e as Map<String, dynamic>;
        final ref = _element(element, placement, storeyId);
        references[element['id'] as String] = ref;
        if (element['kind'] == 'space') {
          spaces.add(ref);
        } else if (element['kind'] != 'opening' &&
            element['kind'] != 'zone' &&
            element['parentId'] == null) {
          contained.add(ref);
        }
        finished++;
        if (finished % 8 == 0 || finished == total) {
          onProgress?.call(finished / math.max(total, 1));
        }
      }
      if (contained.isNotEmpty) {
        _add(
          'IFCRELCONTAINEDINSPATIALSTRUCTURE',
          '${_root('contained:$storeyId', '')},(${contained.join(',')}),$storeyRef',
        );
      }
      if (spaces.isNotEmpty) _aggregate('spaces:$storeyId', storeyRef, spaces);
      final children = <String, List<String>>{};
      for (final rawElement in elements) {
        final e = rawElement as Map<String, dynamic>;
        final id = e['id'] as String, ref = references[id]!;
        final hostId = e['hostId'];
        if (hostId != null && references[hostId] != null) {
          _add(
            'IFCRELVOIDSELEMENT',
            '${_root('void:$storeyId:$id', '')},${references[hostId]},$ref',
          );
        }
        final openingId = e['openingId'];
        if (openingId != null && references[openingId] != null) {
          _add(
            'IFCRELFILLSELEMENT',
            '${_root('fill:$storeyId:$id', '')},${references[openingId]},$ref',
          );
        }
        final parentId = e['parentId'] as String?;
        if (parentId != null && references[parentId] != null) {
          (children[parentId] ??= []).add(ref);
        }
      }
      for (final entry in children.entries) {
        _aggregate(
          'children:$storeyId:${entry.key}',
          references[entry.key]!,
          entry.value,
        );
      }
      for (final rawZone in elements.where(
        (e) => (e as Map)['kind'] == 'zone',
      )) {
        final zone = rawZone as Map<String, dynamic>;
        final members = [
          for (final raw in elements)
            if ((raw as Map)['kind'] == 'space' &&
                (raw['properties'] as Map?)?['ApartmentId'] == zone['id'])
              references[raw['id']]!,
        ];
        if (members.isNotEmpty) {
          _add(
            'IFCRELASSIGNSTOGROUP',
            '${_root('zone:$storeyId:${zone['id']}', '')},(${members.join(',')}),\$,${references[zone['id']]}',
          );
        }
      }
    }
    if (storeyRefs.isNotEmpty) {
      _aggregate('building-storeys', building, storeyRefs);
    }
    for (final entry in _typeAssignments.entries) {
      _add(
        'IFCRELDEFINESBYTYPE',
        '${_root('type-assignment:${entry.key}', '')},(${entry.value.join(',')}),${_types[entry.key]}',
      );
    }
    final text = StringBuffer('ISO-10303-21;\nHEADER;\n')
      ..writeln("FILE_DESCRIPTION(('KoToViewer architectural model'),'2;1');")
      ..writeln(
        'FILE_NAME(${_s('${document['name']}.ifc')},${_s(DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true).toIso8601String())},(\'\'),(\'\'),\'KoToViewer\',\'KoToViewer\',\'\');',
      )
      ..writeln("FILE_SCHEMA(('${_ifc4 ? 'IFC4' : 'IFC2X3'}'));")
      ..writeln('ENDSEC;\nDATA;');
    for (final line in _lines) {
      text.writeln(line);
    }
    text.writeln('ENDSEC;\nEND-ISO-10303-21;');
    return {
      'bytes': Uint8List.fromList(utf8.encode(text.toString())),
      'notices': _notices,
      'parametricCount': _parametricCount,
      'fallbackCount': _fallbackCount,
    };
  }

  String _element(
    Map<String, dynamic> e,
    String storeyPlacement,
    String storeyId,
  ) {
    final id = e['id'] as String, kind = e['kind'] as String;
    final key = 'element:$id';
    final placement = _placement(
      storeyPlacement,
      e['origin'] as List<dynamic>? ?? [0, 0, 0],
      e['axis'] as List<dynamic>?,
      e['ref'] as List<dynamic>?,
    );
    final bodies = <String, List<String>>{};
    var mesh = false, surface = false;
    for (final raw in e['shapes'] as List<dynamic>? ?? []) {
      final shape = raw as Map<String, dynamic>;
      if (shape['type'] == 'mesh') {
        mesh = true;
        for (final item in _mesh(shape['triangles'] as List<dynamic>)) {
          (bodies[item.$1] ??= []).add(item.$2);
          surface = surface || item.$1 == 'SurfaceModel';
        }
      } else {
        final solid = _extrusion(shape);
        (bodies['SweptSolid'] ??= []).add(solid);
      }
    }
    final reps = <String>[];
    if (e['curve'] != null) {
      reps.add(
        _add(
          'IFCSHAPEREPRESENTATION',
          '$_context,\'Axis\',\'${((e['curve'] as List).first as List).length == 3 ? 'Curve3D' : 'Curve2D'}\',(${_polyline(e['curve'] as List<dynamic>, closed: false)})',
        ),
      );
    }
    if (bodies.isNotEmpty) {
      reps.add(_bodyRepresentation(bodies));
    }
    final shape = reps.isEmpty
        ? '\$'
        : _add('IFCPRODUCTDEFINITIONSHAPE', '\$,\$,(${reps.join(',')})');
    final base =
        '${_root('element:$id', e['name'] as String? ?? id)},\$,$placement,$shape,${_s(id)}';
    final pre = e['predefined'] as String?;
    final entity = switch (kind) {
      'wall' => _add(
        !_ifc4 && e['standard'] == true ? 'IFCWALLSTANDARDCASE' : 'IFCWALL',
        '$base${_ifc4 ? ',.NOTDEFINED.' : ''}',
      ),
      'slab' => _add('IFCSLAB', '$base,.${pre ?? 'FLOOR'}.'),
      'roof' => _add('IFCROOF', '$base,.${pre ?? 'NOTDEFINED'}.'),
      'column' => _add('IFCCOLUMN', '$base${_ifc4 ? ',.COLUMN.' : ''}'),
      'beam' => _add('IFCBEAM', '$base${_ifc4 ? ',.BEAM.' : ''}'),
      'door' => _add(
        'IFCDOOR',
        '$base,${_n(e['height'] as num)},${_n(e['width'] as num)}${_ifc4 ? ',.DOOR.,.${e['operation'] ?? 'NOTDEFINED'}.,\$' : ''}',
      ),
      'window' => _add(
        'IFCWINDOW',
        '$base,${_n(e['height'] as num)},${_n(e['width'] as num)}${_ifc4 ? ',.WINDOW.,.NOTDEFINED.,\$' : ''}',
      ),
      'opening' => _add(
        'IFCOPENINGELEMENT',
        '$base${_ifc4 ? ',.OPENING.' : ''}',
      ),
      'stair' => _add('IFCSTAIR', '$base,.${pre ?? 'NOTDEFINED'}.'),
      'flight' => _add(
        'IFCSTAIRFLIGHT',
        '$base,${e['risers'] ?? '\$'},${e['treads'] ?? '\$'},${_nullableNumber(e['riser'])},${_nullableNumber(e['going'])}${_ifc4 ? ',.STRAIGHT.' : ''}',
      ),
      'railing' => _add('IFCRAILING', '$base,.GUARDRAIL.'),
      'drainage' => _add('IFCFLOWSEGMENT', base),
      'space' => _add(
        'IFCSPACE',
        '${_root('element:$id', e['name'] as String? ?? id)},\$,$placement,$shape,${_s(e['longName'] as String? ?? '')},.ELEMENT.,.INTERNAL.,\$',
      ),
      'zone' => _add(
        'IFCZONE',
        '${_root('element:$id', e['name'] as String? ?? id)},\$${_ifc4 ? ',\$' : ''}',
      ),
      _ => _add(
        'IFCBUILDINGELEMENTPROXY',
        '$base,.${_ifc4 ? 'NOTDEFINED' : 'ELEMENT'}.',
      ),
    };
    if (kind != 'opening' &&
        kind != 'roof' &&
        kind != 'zone' &&
        e['metadataOnly'] != true) {
      if (mesh || e['fallback'] == true) {
        _fallbackCount++;
        _notices.add({'elementId': id, 'code': 'geometryFallback'});
      } else if (bodies.isNotEmpty) {
        _parametricCount++;
      }
    }
    if (surface) _notices.add({'elementId': id, 'code': 'surfaceFallback'});
    if (kind == 'proxy') {
      _notices.add({
        'elementId': id,
        'code': e['notice'] as String? ?? 'proxy',
      });
      if (bodies.isEmpty && e['notice'] == null) {
        _notices.add({'elementId': id, 'code': 'missingGeometry'});
      }
    }
    _properties(entity, key, {
      'SourceId': e['sourceId'] ?? id,
      'SourceCategory': kind,
      ...?e['properties'] as Map<String, dynamic>?,
    });
    _material(entity, key, e);
    _type(entity, key, e);
    return entity;
  }

  String _bodyRepresentation(Map<String, List<String>> bodies) {
    // Body representations are alternatives, not additive layers. Emit one
    // representation containing every component; otherwise importers may pick
    // just the first representation and silently discard door leaves/frames.
    var items = bodies.values.expand((v) => v).toList();
    String type;
    if (bodies.length == 1) {
      type = bodies.keys.single;
    } else if (!bodies.containsKey('SurfaceModel')) {
      type = 'SolidModel';
    } else if (_ifc4) {
      type = 'SurfaceOrSolidModel';
    } else if (!bodies.containsKey('SweptSolid')) {
      type = 'SurfaceModel';
      items = [
        for (final item in items)
          if (_brepShells[item] case final shell?)
            _add('IFCSHELLBASEDSURFACEMODEL', '($shell)')
          else
            item,
      ];
    } else {
      // IFC2x3 has no SurfaceOrSolidModel. Mapped representations preserve a
      // future hybrid of analytic swept solids and mesh surfaces without
      // approximating the swept profile or emitting multiple product Bodies.
      type = 'MappedRepresentation';
      final target = _add(
        'IFCCARTESIANTRANSFORMATIONOPERATOR3D',
        '\$,\$,${_point([0, 0, 0])},1.,\$',
      );
      items = [
        for (final group in bodies.entries)
          _add(
            'IFCMAPPEDITEM',
            '${_add('IFCREPRESENTATIONMAP', '${_axis([0, 0, 0])},${_add('IFCSHAPEREPRESENTATION', '$_context,\$,${_s(group.key)},(${group.value.join(',')})')}')},$target',
          ),
      ];
    }
    return _add(
      'IFCSHAPEREPRESENTATION',
      '$_context,\'Body\',${_s(type)},(${items.join(',')})',
    );
  }

  void _aggregate(String id, String parent, List<String> children) {
    _add(
      'IFCRELAGGREGATES',
      '${_root(id, '')},$parent,(${children.join(',')})',
    );
  }

  String _polyline(List<dynamic> polygon, {bool closed = true}) {
    final points = polygon.map((p) => _point(p as List<dynamic>)).toList();
    if (closed) points.add(points.first);
    return _add('IFCPOLYLINE', '(${points.join(',')})');
  }

  String _extrusion(Map<String, dynamic> s) {
    final polygon = s['polygon'] as List<dynamic>?;
    final String profile;
    if (s['radius'] != null) {
      final p = _add('IFCAXIS2PLACEMENT2D', '${_point([0, 0])},\$');
      profile = _add(
        'IFCCIRCLEPROFILEDEF',
        '.AREA.,\$,$p,${_n(s['radius'] as num)}',
      );
    } else {
      final outer = _polyline(polygon!);
      final holes = s['holes'] as List<dynamic>? ?? [];
      profile = holes.isEmpty
          ? _add('IFCARBITRARYCLOSEDPROFILEDEF', '.AREA.,\$,$outer')
          : _add(
              'IFCARBITRARYPROFILEDEFWITHVOIDS',
              '.AREA.,\$,$outer,(${holes.map((h) => _polyline(h as List<dynamic>)).join(',')})',
            );
    }
    return _add(
      'IFCEXTRUDEDAREASOLID',
      '$profile,${_axis(s['origin'] as List<dynamic>? ?? [0, 0, 0], s['axis'] as List<dynamic>?, s['ref'] as List<dynamic>?)},${_direction(s['direction'] as List<dynamic>? ?? [0, 0, 1])},${_n(s['depth'] as num)}',
    );
  }

  /// Weld each body, split connected shells, and test edge incidence before
  /// declaring a ClosedShell. Open source geometry stays an honest surface.
  List<(String, String)> _mesh(List<dynamic> triangles) {
    final vertices = <List<dynamic>>[];
    final vertexIds = <String, int>{};
    int vertex(dynamic raw) {
      final p = raw as List<dynamic>;
      final key = p.map((v) => ((v as num) * 1e7).round()).join(':');
      return vertexIds.putIfAbsent(key, () {
        vertices.add(p);
        return vertices.length - 1;
      });
    }

    final faces = <List<int>>[];
    final edgeFaces = <String, List<int>>{};
    final duplicateFaces = <String>{};
    for (final raw in triangles) {
      final f = (raw as List<dynamic>).map(vertex).toList();
      if (f.toSet().length < 3) continue;
      final key = (List<int>.of(f)..sort()).join(':');
      if (!duplicateFaces.add(key)) continue;
      final index = faces.length;
      faces.add(f);
      for (var i = 0; i < 3; i++) {
        final a = f[i], b = f[(i + 1) % 3];
        (edgeFaces[a < b ? '$a:$b' : '$b:$a'] ??= []).add(index);
      }
    }
    // A triangulated cap may end one long edge where its side face has two
    // shorter edges. Split only at existing collinear vertices: this repairs
    // the topology without changing a single source coordinate or surface.
    final boundaryVertices = <int>{};
    for (final entry in edgeFaces.entries.where((e) => e.value.length == 1)) {
      boundaryVertices.addAll(entry.key.split(':').map(int.parse));
    }
    if (boundaryVertices.isNotEmpty) {
      var candidateChecks = 0;
      // Bound pathological imported meshes. An unfinished repair keeps the
      // exact source surfaces and an explicit surface-fallback notice.
      repair:
      for (var fi = 0; fi < faces.length; fi++) {
        final face = faces[fi], refined = <int>[];
        for (var i = 0; i < face.length; i++) {
          final ai = face[i], bi = face[(i + 1) % face.length];
          refined.add(ai);
          if (edgeFaces[ai < bi ? '$ai:$bi' : '$bi:$ai']!.length != 1) continue;
          final a = vertices[ai], b = vertices[bi];
          final delta = [
            for (var k = 0; k < 3; k++) (b[k] as num) - (a[k] as num),
          ];
          final length2 = delta.fold<double>(0, (sum, v) => sum + v * v);
          if (length2 < 1e-18) continue;
          final insertions = <(double, int)>[];
          for (final vi in boundaryVertices) {
            if (++candidateChecks > 2000000) break repair;
            if (vi == ai || vi == bi) continue;
            final p = vertices[vi];
            if (const [0, 1, 2].any(
              (k) =>
                  (p[k] as num) < math.min(a[k] as num, b[k] as num) - 1e-7 ||
                  (p[k] as num) > math.max(a[k] as num, b[k] as num) + 1e-7,
            )) {
              continue;
            }
            var dot = 0.0;
            for (var k = 0; k < 3; k++) {
              dot += ((p[k] as num) - (a[k] as num)) * delta[k];
            }
            final t = dot / length2;
            if (t <= 1e-8 || t >= 1 - 1e-8) continue;
            var distance2 = 0.0;
            for (var k = 0; k < 3; k++) {
              final e = (p[k] as num) - (a[k] as num) - t * delta[k];
              distance2 += e * e;
            }
            if (distance2 <= 1e-14) insertions.add((t, vi));
          }
          insertions.sort((a, b) => a.$1.compareTo(b.$1));
          refined.addAll(insertions.map((p) => p.$2));
        }
        faces[fi] = refined;
      }
      edgeFaces.clear();
      for (var fi = 0; fi < faces.length; fi++) {
        final face = faces[fi];
        for (var i = 0; i < face.length; i++) {
          final a = face[i], b = face[(i + 1) % face.length];
          (edgeFaces[a < b ? '$a:$b' : '$b:$a'] ??= []).add(fi);
        }
      }
    }
    final neighbors = List.generate(faces.length, (_) => <(int, bool)>[]);
    for (final touching in edgeFaces.values) {
      if (touching.length < 2) continue;
      for (final a in touching) {
        for (final b in touching) {
          if (a != b) {
            final fa = faces[a], fb = faces[b];
            bool sameDirection = false;
            for (var i = 0; i < fa.length; i++) {
              final u = fa[i], v = fa[(i + 1) % fa.length];
              final j = fb.indexOf(u);
              if (j >= 0 && fb[(j + 1) % fb.length] == v) sameDirection = true;
            }
            neighbors[a].add((b, sameDirection));
          }
        }
      }
    }
    final unseen = {for (var i = 0; i < faces.length; i++) i};
    final pointRefs = <int, String>{};
    final result = <(String, String)>[];
    final flips = List<bool?>.filled(faces.length, null);
    while (unseen.isNotEmpty) {
      final component = <int>[], queue = [unseen.first];
      unseen.remove(queue.first);
      flips[queue.first] = false;
      var closed = true;
      while (queue.isNotEmpty) {
        final index = queue.removeLast();
        component.add(index);
        for (final (other, sameDirection) in neighbors[index]) {
          final flip = flips[index]! ^ sameDirection;
          if (unseen.remove(other)) {
            flips[other] = flip;
            queue.add(other);
          } else if (flips[other] != flip) {
            closed = false;
          }
        }
      }
      var volume = 0.0;
      for (final index in component) {
        final f = flips[index]! ? faces[index].reversed.toList() : faces[index];
        faces[index] = f;
        final a = vertices[f[0]];
        for (var triangle = 1; triangle + 1 < f.length; triangle++) {
          final b = vertices[f[triangle]], c = vertices[f[triangle + 1]];
          volume +=
              ((a[0] as num) *
                      ((b[1] as num) * (c[2] as num) -
                          (b[2] as num) * (c[1] as num)) +
                  (a[1] as num) *
                      ((b[2] as num) * (c[0] as num) -
                          (b[0] as num) * (c[2] as num)) +
                  (a[2] as num) *
                      ((b[0] as num) * (c[1] as num) -
                          (b[1] as num) * (c[0] as num))) /
              6;
        }
        for (var i = 0; i < f.length; i++) {
          final u = f[i], v = f[(i + 1) % f.length];
          if (edgeFaces[u < v ? '$u:$v' : '$v:$u']!.length != 2) closed = false;
        }
      }
      if (volume.abs() < 1e-12) closed = false;
      final faceRefs = <String>[];
      for (final index in component) {
        final f = faces[index];
        final oriented = volume < 0 ? f.reversed : f;
        final points = oriented
            .map((i) => pointRefs.putIfAbsent(i, () => _point(vertices[i])))
            .join(',');
        final loop = _add('IFCPOLYLOOP', '($points)');
        final bound = _add('IFCFACEOUTERBOUND', '$loop,.T.');
        faceRefs.add(_add('IFCFACE', '($bound)'));
      }
      final shell = _add(
        closed ? 'IFCCLOSEDSHELL' : 'IFCOPENSHELL',
        '(${faceRefs.join(',')})',
      );
      if (closed) {
        final brep = _add('IFCFACETEDBREP', shell);
        _brepShells[brep] = shell;
        result.add(('Brep', brep));
      } else {
        result.add((
          'SurfaceModel',
          _add('IFCSHELLBASEDSURFACEMODEL', '($shell)'),
        ));
      }
    }
    return result;
  }

  void _properties(String entity, String id, Map<String, dynamic> values) {
    final properties = <String>[];
    for (final entry in values.entries) {
      if (entry.value == null) continue;
      final value = entry.value;
      final typed = value is bool
          ? 'IFCBOOLEAN(.${value ? 'T' : 'F'}.)'
          : value is num
          ? 'IFCREAL(${_n(value)})'
          : 'IFCTEXT(${_s(value.toString())})';
      properties.add(
        _add('IFCPROPERTYSINGLEVALUE', '${_s(entry.key)},\$,$typed,\$'),
      );
    }
    if (properties.isEmpty) return;
    final pset = _add(
      'IFCPROPERTYSET',
      '${_root('pset:$id', 'Pset_KoToSource')},(${properties.join(',')})',
    );
    _add(
      'IFCRELDEFINESBYPROPERTIES',
      '${_root('properties:$id', '')},($entity),$pset',
    );
  }

  void _material(String entity, String id, Map<String, dynamic> e) {
    final layers = e['layers'] as List<dynamic>? ?? [];
    if (layers.isEmpty) return;
    final refs = <String>[];
    for (final raw in layers) {
      final layer = raw as Map<String, dynamic>;
      final name = layer['material'] as String;
      final material = _materials.putIfAbsent(
        name,
        () => _add('IFCMATERIAL', '${_s(name)}${_ifc4 ? ',\$,\$' : ''}'),
      );
      refs.add(
        _add(
          'IFCMATERIALLAYER',
          '$material,${_n(layer['thickness'] as num)},.F.${_ifc4 ? ',${_s(layer['name'] as String? ?? name)},\$,\$,\$' : ''}',
        ),
      );
    }
    final set = _add(
      'IFCMATERIALLAYERSET',
      '(${refs.join(',')}),${_s(e['typeId'] as String? ?? e['id'] as String)}${_ifc4 ? ',\$' : ''}',
    );
    final usage = _add(
      'IFCMATERIALLAYERSETUSAGE',
      '$set,.${e['layerAxis'] ?? 'AXIS2'}.,.POSITIVE.,${_n(e['layerOffset'] as num? ?? 0)}${_ifc4 ? ',\$' : ''}',
    );
    _add(
      'IFCRELASSOCIATESMATERIAL',
      '${_root('material:$id', '')},($entity),$usage',
    );
  }

  void _type(String entity, String key, Map<String, dynamic> e) {
    final kind = e['kind'] as String;
    if (!const [
      'wall',
      'slab',
      'column',
      'beam',
      'door',
      'window',
      'railing',
      'stair',
    ].contains(kind)) {
      return;
    }
    final sourceType = e['typeId'] as String? ?? '${e['id']}:type';
    final typeKey = '$kind:$sourceType';
    final ref = _types.putIfAbsent(typeKey, () {
      final base = '${_root('type:$typeKey', sourceType)},\$,\$,\$,\$';
      if (kind == 'door' && !_ifc4) {
        return _add(
          'IFCDOORSTYLE',
          '$base,.${e['operation'] ?? 'NOTDEFINED'}.,.NOTDEFINED.,.F.,.F.',
        );
      }
      if (kind == 'window' && !_ifc4) {
        return _add(
          'IFCWINDOWSTYLE',
          '$base,.NOTDEFINED.,.NOTDEFINED.,.F.,.F.',
        );
      }
      if (kind == 'door' || kind == 'window') {
        return _add(
          kind == 'door' ? 'IFCDOORTYPE' : 'IFCWINDOWTYPE',
          '$base,\$,.${kind.toUpperCase()}.,.${kind == 'door' ? e['operation'] ?? 'NOTDEFINED' : 'NOTDEFINED'}.,.F.,\$',
        );
      }
      final typeName = switch (kind) {
        'wall' => 'IFCWALLTYPE',
        'slab' => 'IFCSLABTYPE',
        'column' => 'IFCCOLUMNTYPE',
        'beam' => 'IFCBEAMTYPE',
        'railing' => 'IFCRAILINGTYPE',
        _ => 'IFCSTAIRTYPE',
      };
      // IfcStairType is introduced by IFC4; IFC2x3 keeps the occurrence only.
      if (kind == 'stair' && !_ifc4) return '';
      final pre =
          e['predefined'] ??
          switch (kind) {
            'slab' => 'FLOOR',
            'column' => 'COLUMN',
            'beam' => 'BEAM',
            'railing' => 'GUARDRAIL',
            _ => 'NOTDEFINED',
          };
      return _add(typeName, '$base,\$,.$pre.');
    });
    if (ref.isNotEmpty) {
      (_typeAssignments[typeKey] ??= []).add(entity);
    }
  }
}

String _nullableNumber(dynamic n) => n == null ? '\$' : _n(n as num);
String _n(num n) {
  if (!n.isFinite) throw ArgumentError.value(n, 'coordinate', 'Must be finite');
  if (n.abs() < 1e-12) return '0.';
  final parts = n.toStringAsPrecision(12).split(RegExp('[eE]'));
  var s = parts.first;
  if (s.contains('.')) s = s.replaceFirst(RegExp(r'0+$'), '');
  if (parts.length > 1) return '${s}E${parts[1]}';
  if (s.endsWith('.')) return s;
  if (!s.contains('.') && !s.contains('e') && !s.contains('E')) s += '.';
  return s.replaceAll('e', 'E');
}

String _s(String s) {
  final out = StringBuffer("'");
  for (final unit in s.codeUnits) {
    if (unit == 39) {
      out.write("''");
    } else if (unit >= 32 && unit <= 126 && unit != 92) {
      out.writeCharCode(unit);
    } else {
      out.write(
        '\\X2\\${unit.toRadixString(16).padLeft(4, '0').toUpperCase()}\\X0\\',
      );
    }
  }
  return (out..write("'")).toString();
}
