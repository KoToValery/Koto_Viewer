import 'dart:math' as math;
import 'dart:ui';

import '../../../core/services/cad_text_decoder.dart';
import '../models/dxf_models.dart';
import '../rendering/dxf_math.dart';
import '../rendering/dxf_quadtree.dart';

/// Adapts native DWG objects to the viewer's existing in-memory CAD classes.
/// DxfDocument is their historical class name, not a file conversion step.
class DwgDocumentAdapter {
  static DxfDocument decode(Map<String, dynamic> source) {
    if (source['protocol'] != 1 || source['source'] != 'DWG') {
      throw const FormatException('Unsupported native drawing protocol');
    }
    final layers = <String, DxfLayer>{};
    for (final value in _list(source['layers'])) {
      final layer = _map(value), flags = _map(layer['flags']);
      final color = _color(layer['color']);
      final name = layer['name'] as String;
      layers[name] = DxfLayer(
        name: name,
        colorIndex: color.$1 ?? 7,
        trueColor: color.$2,
        lineweight: _weight(layer['line_weight']),
        lineType: layer['line_type'] as String?,
        isFrozen: flags['frozen'] == true,
        isVisible: flags['frozen'] != true && flags['off'] != true,
      );
    }
    final styles = <String, DxfTextStyle>{};
    for (final value in _list(source['text_styles'])) {
      final style = _map(value);
      final name = style['name'] as String;
      styles[name] = DxfTextStyle(
        name: name,
        heightScale: _number(style['height']) > 0
            ? _number(style['height'])
            : 1,
        fontFile: style['font_file'] as String?,
        isVertical: style['is_vertical'] == true,
      );
    }
    final dims = <String, DxfDimStyle>{};
    for (final value in _list(source['dim_styles'])) {
      final d = _map(value), name = d['name'] as String;
      dims[name] = DxfDimStyle(
        name: name,
        dimScale: _number(d['dimscale'], 1),
        dimAsz: _number(d['dimasz'], 2.5),
        dimExo: _number(d['dimexo']),
        dimExe: _number(d['dimexe']),
        dimTxt: _number(d['dimtxt'], 2.5),
        dimTsz: _number(d['dimtsz']),
        dimGap: _number(d['dimgap']),
        dimBlk: d['dimblk_name'] as String?,
      );
    }
    final lineTypes = <String, List<double>>{};
    for (final value in _list(source['line_types'])) {
      final line = _map(value);
      lineTypes[line['name'] as String] = _list(line['elements']).map((
        element,
      ) {
        // The viewer stores alternating positive dash/gap lengths, like the
        // DXF LTYPE reader. Native CAD gaps are negative and zero means a dot.
        final length = _number(_map(element)['length']);
        return length == 0 ? 1.8 : length.abs();
      }).toList();
    }
    final layoutNames = <String, String>{};
    for (final value in _list(source['layouts'])) {
      final layout = _map(value);
      layoutNames['${layout['block_record']}'] =
          layout['name'] as String? ?? 'Layout1';
    }
    final blocks = <String, DxfBlock>{};
    final entities = <DxfEntity>[];
    final attributes = _map(source['attributes']);
    for (final value in _list(source['blocks'])) {
      final block = _map(value);
      final name = block['name'] as String;
      final lowerName = name.toLowerCase();
      final model = lowerName == '*model_space';
      final paper = lowerName.startsWith('*paper_space');
      final layout = model
          ? 'Model'
          : layoutNames['${block['handle']}'] ?? 'Layout1';
      final content = <DxfEntity>[];
      for (final object in _list(block['entities'])) {
        final entity = _entity(
          _map(object),
          paper: paper,
          layout: layout,
          attributes: attributes,
        );
        if (entity != null) content.add(entity);
        if (entity is DxfInsert) {
          for (final attribute in entity.attributes) {
            if (!attribute.isInvisible && attribute.textEntity != null) {
              content.add(attribute.textEntity!);
            }
          }
        }
      }
      blocks[name] = DxfBlock(
        name: name,
        basePoint: _point(block['base_point']),
        entities: model || paper ? [] : content,
      );
      if (model || paper) entities.addAll(content);
    }
    final stats = <String, int>{};
    for (final entity in entities) {
      stats.update(entity.typeName, (n) => n + 1, ifAbsent: () => 1);
    }
    final usedLayers = {
      for (final entity in entities) entity.layer,
      for (final block in blocks.values)
        for (final entity in block.entities) entity.layer,
    };
    layers.removeWhere(
      (key, _) => usedLayers.isNotEmpty && !usedLayers.contains(key),
    );
    for (final layer in usedLayers) {
      layers.putIfAbsent(layer, () => DxfLayer(name: layer));
    }
    final header = _map(source['header']);
    final modelBounds = [
      for (final entity in entities)
        if (!entity.isPaperSpace)
          (entity: entity, bounds: entity.getBoundingBox(blocks)),
    ];
    final vars = <String, String>{
      r'$INSUNITS': '${header['insertion_units'] ?? 0}',
      r'$MEASUREMENT': '${header['measurement'] ?? 0}',
      r'$LTSCALE': '${header['linetype_scale'] ?? 1}',
      r'$PDMODE': '${header['point_display_mode'] ?? 0}',
      r'$PDSIZE': '${header['point_display_size'] ?? 0}',
      r'$CELTSCALE': '${header['current_entity_linetype_scale'] ?? 1}',
      r'$DIMASZ': '${header['dim_arrow_size'] ?? 2.5}',
      r'$DIMSCALE': '${header['dim_scale'] ?? 1}',
    };
    final doc = DxfDocument(
      layers: layers,
      blocks: blocks,
      entities: entities,
      headerVars: vars,
      textStyles: styles,
      dimStyles: dims,
      lineTypes: lineTypes,
      bounds: _bounds(modelBounds.map((entry) => entry.bounds), header),
      entityStats: stats,
    );
    doc.spatialIndex = DxfQuadTree.buildFromEntityBounds(modelBounds, doc.bounds);
    return doc;
  }

  static DxfEntity? _entity(
    Map<String, dynamic> wrapper, {
    required bool paper,
    required String layout,
    required Map<String, dynamic> attributes,
  }) {
    if (wrapper.length != 1) {
      throw const FormatException('Invalid native entity');
    }
    final type = wrapper.keys.single;
    var e = _map(wrapper.values.single);
    if (const {
      'Block',
      'BlockEnd',
      'Seqend',
      'AttributeEntity',
    }.contains(type)) {
      return null;
    }
    var dimensionType = '';
    if (type == 'Dimension') {
      dimensionType = e.keys.single;
      e = _map(e.values.single);
    }
    final base = _map(e['base']);
    final common = _map(e['common'] ?? base['common']);
    final color = _color(common['color']);
    final normal = _map(e['normal'] ?? base['normal']);
    final ocs = normal.isEmpty
        ? OcsTransform.identity
        : OcsTransform.fromExtrusion(
            _number(normal['x']),
            _number(normal['y']),
            _number(normal['z'], 1),
          );
    Offset projected(dynamic value) {
      final v = _map(value);
      return ocs.toWcs2D(
        _number(v['x']),
        _number(v['y']),
        _number(v['z'], _number(e['elevation'])),
      );
    }

    DxfEntity make(Function constructor, Map<Symbol, dynamic> geometry) =>
        Function.apply(constructor, [], {
              #layer: common['layer'] ?? '0',
              #colorIndex: color.$1,
              #trueColor: color.$2,
              #lineType: common['linetype'] as String?,
              #lineWeight: _weight(common['line_weight']),
              #lineTypeScale: _number(common['linetype_scale'], 1),
              #isPaperSpace: paper,
              #layoutName: paper ? layout : 'Model',
              ...geometry,
            })
            as DxfEntity;
    switch (type) {
      case 'Line':
        return make(DxfLine.new, {
          #p1: _point(e['start']),
          #p2: _point(e['end']),
        });
      case 'Point':
        return make(DxfPoint.new, {#point: _point(e['location'])});
      case 'Circle':
        return make(DxfCircle.new, {
          #center: projected(e['center']),
          #radius: _number(e['radius']),
        });
      case 'Arc':
        final angles = ocs.transformArcAngles(
          _degrees(e['start_angle']),
          _degrees(e['end_angle']),
        );
        return make(DxfArc.new, {
          #center: projected(e['center']),
          #radius: _number(e['radius']),
          #startAngleDeg: angles.startAngleDeg,
          #endAngleDeg: angles.endAngleDeg,
        });
      case 'Ellipse':
        return make(DxfEllipse.new, {
          #center: _point(e['center']),
          #majorAxisEndOffset: _point(e['major_axis']),
          #minorRatio: _number(e['minor_axis_ratio'], 1),
          #startParam: _number(e['start_parameter']),
          #endParam: _number(e['end_parameter'], 2 * math.pi),
        });
      case 'LwPolyline':
      case 'Polyline2D':
      case 'Polyline':
      case 'Polyline3D':
        final vertices = _list(e['vertices']).map((value) {
          final v = _map(value), location = v['location'] ?? v['position'];
          final p = type == 'Polyline' || type == 'Polyline3D'
              ? _point(location)
              : projected(location);
          return DxfPolylineVertex(
            x: p.dx,
            y: p.dy,
            bulge: ocs.transformBulge(_number(v['bulge'])),
            startWidth: _number(v['start_width']),
            endWidth: _number(v['end_width']),
          );
        }).toList();
        if (type == 'LwPolyline') {
          return make(DxfLwPolyline.new, {
            #vertices: vertices,
            #isClosed: e['is_closed'] == true,
            #elevation: _number(e['elevation']),
          });
        }
        return make(DxfPolyline.new, {
          #vertices: vertices,
          #isClosed: (_bits(e['flags']) & 1) != 0,
          #flags: _bits(e['flags']),
          #is3D: type == 'Polyline' || type == 'Polyline3D',
        });
      case 'Spline':
        return make(DxfSpline.new, {
          #degree: e['degree'] as int? ?? 3,
          #controlPoints: _list(e['control_points']).map(_point).toList(),
          #fitPoints: _list(e['fit_points']).map(_point).toList(),
          #knots: _list(e['knots']).map(_number).toList(),
          #weights: _list(e['weights']).map(_number).toList(),
          #isClosed: (_bits(e['flags']) & 1) != 0,
          #isRational: (_bits(e['flags']) & 4) != 0,
        });
      case 'Text':
        return make(DxfText.new, {
          #text: _clean(e['value']),
          #insertPoint: projected(e['insertion_point']),
          #alignPoint: e['alignment_point'] == null
              ? null
              : projected(e['alignment_point']),
          #height: _number(e['height'], 2.5),
          #rotationDeg: ocs.angleToWcs(_degrees(e['rotation'])),
          #hAlign: _horizontal(e['horizontal_alignment']),
          #vAlign: _vertical(e['vertical_alignment']),
          #style: e['style'],
          #isInvisible: common['invisible'] == true,
        });
      case 'MText':
        final raw = e['value'] as String? ?? '';
        final match = RegExp(r'\\W([0-9.]+)').firstMatch(raw);
        return make(DxfMText.new, {
          #rawText: raw,
          #cleanText: CadTextDecoder.multiline(raw),
          #insertPoint: _point(e['insertion_point']),
          #height: _number(e['height'], 2.5),
          #rotationDeg: _degrees(e['rotation']),
          #refWidth: _number(e['rectangle_width']),
          #style: e['style'],
          #attachmentPoint: _attachment(e['attachment_point']),
          #widthFactor: double.tryParse(match?.group(1) ?? '') ?? 1.0,
          #directionVector: e['dwg_x_direction'] == null
              ? null
              : _point(e['dwg_x_direction']),
          #lineSpacingFactor: _number(e['line_spacing_factor'], 1),
        });
      case 'Insert':
        return make(DxfInsert.new, {
          #blockName: e['block_name'],
          #insertPoint: projected(e['insert_point']),
          #scaleX: _number(e['x_scale'], 1),
          #scaleY: _number(e['y_scale'], 1),
          #scaleZ: _number(e['z_scale'], 1),
          #rotationDeg: ocs.angleToWcs(_degrees(e['rotation'])),
          #rowCount: e['row_count'] ?? 1,
          #colCount: e['column_count'] ?? 1,
          #rowSpacing: _number(e['row_spacing']),
          #colSpacing: _number(e['column_spacing']),
          #attributes:
              [
                    ..._list(e['attributes']),
                    ..._list(attributes['${common['handle']}']),
                  ]
                  .map((a) => _attribute(_map(a), paper: paper, layout: layout))
                  .toList(),
        });
      case 'Solid':
        return make(DxfSolid.new, {
          #p0: projected(e['first_corner']),
          #p1: projected(e['second_corner']),
          #p2: projected(e['third_corner']),
          #p3: projected(e['fourth_corner']),
        });
      case 'Hatch':
        final pattern = _map(e['pattern']);
        return make(DxfHatch.new, {
          #boundaryPaths: _hatchPaths(e, ocs),
          #patternName: pattern['name'] ?? 'SOLID',
          #isSolid: e['is_solid'] == true,
          #patternScale: _number(e['pattern_scale'], 1),
          #patternAngle: _degrees(e['pattern_angle']),
          #patternLines: _list(pattern['lines']).map((value) {
            final line = _map(value);
            return DxfHatchPatternLine(
              angle: _degrees(line['angle']),
              basePoint: _point(line['base_point']),
              offset: _point(line['offset']),
              dashes: _list(line['dash_lengths']).map(_number).toList(),
            );
          }).toList(),
        });
      case 'Wipeout':
        final insertion = _point(e['insertion_point']);
        final u = _point(e['u_vector']), v = _point(e['v_vector']);
        final size = _map(e['size']);
        final width = _number(size['x'], 1), height = _number(size['y'], 1);
        final raw = _list(e['clip_boundary_vertices']).map(_point).toList();
        final clipped = e['clipping_enabled'] != false && raw.length >= 2;
        var boundary = clipped
            ? raw
            : [
                Offset(-width / 2, -height / 2),
                Offset(width / 2, -height / 2),
                Offset(width / 2, height / 2),
                Offset(-width / 2, height / 2),
              ];
        if (boundary.length == 2) {
          final a = boundary.first, b = boundary.last;
          boundary = [a, Offset(b.dx, a.dy), b, Offset(a.dx, b.dy)];
        }
        Offset world(Offset p) =>
            insertion + u * (p.dx + width / 2) + v * (height / 2 - p.dy);
        final loops = <List<Offset>>[boundary.map(world).toList()];
        if (clipped && e['clip_mode'] == 'Inside') {
          loops.insert(0, [
            insertion,
            insertion + u * width,
            insertion + u * width + v * height,
            insertion + v * height,
          ]);
        }
        // Native WIPEOUT uses image pixel coordinates, with the V axis down.
        // The renderer shares polygon storage with hatches but keeps mask semantics.
        return make(DxfHatch.new, {
          #boundaryPaths: common['invisible'] == true
              ? <List<Offset>>[]
              : loops,
          #isWipeout: true,
          #isSolid: true,
        });
      case 'Dimension':
        final kinds = {
          'Linear': 0,
          'Aligned': 1,
          'Angular2Ln': 2,
          'Diameter': 3,
          'Radius': 4,
          'Angular3Pt': 5,
          'Ordinate': 6,
          'Arc': 8,
          'LargeRadial': 9,
        };
        return make(DxfDimension.new, {
          #dimType:
              (kinds[dimensionType] ?? 0) |
              32 |
              (base['text_user_positioned'] == true ? 128 : 0) |
              (dimensionType == 'Ordinate' && e['is_ordinate_type_x'] == true
                  ? 64
                  : 0),
          #defPoint1: _point(base['definition_point']),
          #defPoint2: e['first_point'] == null
              ? null
              : _point(e['first_point']),
          #defPoint3: e['second_point'] == null
              ? null
              : _point(e['second_point']),
          #textPoint: _point(base['text_middle_point']),
          #rotationDeg: _degrees(e['rotation']),
          #textOverride:
              base['user_text'] ??
              ((base['text'] as String? ?? '').isEmpty ? null : base['text']),
          #blockName: base['block_name'],
          #styleName: base['style_name'],
        });
      case 'Leader':
        return make(DxfLeader.new, {
          #vertices: _list(e['vertices']).map(_point).toList(),
          #hasArrowhead: e['arrow_enabled'] == true,
        });
      case 'MultiLeader':
        final context = _map(e['context']);
        final roots = _list(context['leader_roots']).map(_map).toList();
        final root = roots.isEmpty ? <String, dynamic>{} : roots.first;
        final raw = context['text_string'] as String? ?? '';
        return make(DxfMLeader.new, {
          #leaderLines: [
            for (final r in roots)
              for (final line in _list(r['lines']))
                _list(_map(line)['points']).map(_point).toList(),
          ],
          #connectionPoint: root.isEmpty
              ? null
              : _point(root['connection_point']),
          #doglegDirection: root.isEmpty ? null : _point(root['direction']),
          #doglegLength: _number(
            root['landing_distance'],
            _number(e['dogleg_length']),
          ),
          #textPosition: _point(context['text_location']),
          #rawText: raw,
          #cleanText: CadTextDecoder.multiline(raw),
          #textHeight: _number(context['text_height'], 2.5),
          #textWidth: _number(context['text_width']),
          #hasArrowhead: _number(e['arrowhead_size']) > 0,
          #arrowheadSize: _number(e['arrowhead_size'], 2.5),
        });
      case 'Viewport':
        return make(DxfViewport.new, {
          #center: _point(e['center']),
          #width: _number(e['width']),
          #height: _number(e['height']),
          #viewCenter: _point(e['view_center']),
          #viewHeight: _number(e['view_height']),
          #viewportId: e['id'] ?? 1,
          #twistAngleDeg: _degrees(e['twist_angle']),
          #status: _map(e['status'])['is_off'] == true ? 0 : 1,
        });
      case 'AttributeDefinition':
        return make(DxfAttdef.new, {
          #tag: e['tag'] ?? '',
          #text: _clean(e['default_value'] ?? e['value']),
          #prompt: e['prompt'],
          #insertPoint: projected(e['insertion_point']),
          #alignPoint: e['alignment_point'] == null
              ? null
              : projected(e['alignment_point']),
          #hAlign: _horizontal(e['horizontal_alignment']),
          #vAlign: _vertical(e['vertical_alignment']),
          #height: _number(e['height'], 2.5),
          #rotationDeg: _degrees(e['rotation']),
          #style: e['text_style'],
          #flags: _bits(e['flags']),
        });
      default:
        throw FormatException('Unsupported native DWG entity: $type');
    }
  }

  static DxfAttribute _attribute(
    Map<String, dynamic> e, {
    required bool paper,
    required String layout,
  }) {
    final common = _map(e['common']), color = _color(common['color']);
    final normal = _map(e['normal']);
    final ocs = normal.isEmpty
        ? OcsTransform.identity
        : OcsTransform.fromExtrusion(
            _number(normal['x']),
            _number(normal['y']),
            _number(normal['z'], 1),
          );
    Offset point(dynamic value) {
      final p = _map(value);
      return ocs.toWcs2D(_number(p['x']), _number(p['y']), _number(p['z']));
    }

    final text = DxfText(
      tag: e['tag'] as String? ?? '',
      text: _clean(e['value']),
      insertPoint: point(e['insertion_point']),
      alignPoint: point(e['alignment_point']),
      height: _number(e['height'], 2.5),
      rotationDeg: ocs.angleToWcs(_degrees(e['rotation'])),
      hAlign: _horizontal(e['horizontal_alignment']),
      vAlign: _vertical(e['vertical_alignment']),
      style: e['text_style'] as String?,
      isInvisible: (_bits(e['flags']) & 1) != 0,
      layer: common['layer'] as String? ?? '0',
      colorIndex: color.$1,
      trueColor: color.$2,
      lineWeight: _weight(common['line_weight']),
      lineType: common['linetype'] as String?,
      lineTypeScale: _number(common['linetype_scale'], 1),
      isPaperSpace: paper,
      layoutName: paper ? layout : 'Model',
    );
    return DxfAttribute(
      tag: text.tag!,
      value: text.text,
      insertPoint: text.insertPoint,
      alignPoint: text.alignPoint,
      height: text.height,
      rotationDeg: text.rotationDeg,
      hAlign: text.hAlign,
      vAlign: text.vAlign,
      style: text.style,
      isInvisible: text.isInvisible,
      isConstant: (_bits(e['flags']) & 2) != 0,
      textEntity: text,
    );
  }

  static List<List<Offset>> _hatchPaths(
    Map<String, dynamic> hatch,
    OcsTransform ocs,
  ) {
    final paths = <List<Offset>>[];
    for (final raw in _list(hatch['paths'])) {
      final points = <Offset>[];
      for (final rawEdge in _list(_map(raw)['edges'])) {
        final edge = _map(rawEdge),
            kind = edge.keys.single,
            e = _map(edge.values.single);
        final part = <Offset>[];
        if (kind == 'Line') {
          part.addAll([_point(e['start']), _point(e['end'])]);
        } else if (kind == 'Polyline') {
          final vertices = _list(e['vertices']).map(_map).toList();
          for (var i = 0; i < vertices.length; i++) {
            final v = vertices[i], next = vertices[(i + 1) % vertices.length];
            part.addAll(
              DxfMath.generateBulgeArcPoints(
                _point(v),
                _point(next),
                _number(v['z']),
              ),
            );
          }
        } else if (kind == 'CircularArc' || kind == 'EllipticArc') {
          final center = _point(e['center']);
          final major = kind == 'CircularArc'
              ? Offset(_number(e['radius']), 0)
              : _point(e['major_axis_endpoint']);
          final ratio = kind == 'CircularArc'
              ? 1.0
              : _number(e['minor_axis_ratio'], 1);
          final start = _number(e['start_angle']);
          var sweep = _number(e['end_angle']) - start;
          if (e['counter_clockwise'] != false && sweep <= 0) {
            sweep += 2 * math.pi;
          }
          if (e['counter_clockwise'] == false && sweep >= 0) {
            sweep -= 2 * math.pi;
          }
          final count = (sweep.abs() / (math.pi / 32)).ceil().clamp(2, 256);
          for (var i = 0; i <= count; i++) {
            final angle = start + sweep * i / count;
            part.add(
              center +
                  major * math.cos(angle) +
                  Offset(-major.dy, major.dx) * (ratio * math.sin(angle)),
            );
          }
        } else if (kind == 'Spline') {
          final controls = _list(e['control_points']);
          part.addAll(
            DxfMath.evaluateSpline(
              e['degree'] as int? ?? 3,
              controls.map(_point).toList(),
              knots: _list(e['knots']).map(_number).toList(),
              weights: e['rational'] == true
                  ? controls.map((p) => _number(_map(p)['z'], 1)).toList()
                  : null,
            ),
          );
        } else {
          throw FormatException('Unknown native hatch edge: $kind');
        }
        points.addAll(
          part.map((p) => ocs.toWcs2D(p.dx, p.dy, _number(hatch['elevation']))),
        );
      }
      if (points.isNotEmpty) paths.add(points);
    }
    return paths;
  }

  static Rect _bounds(
    Iterable<Rect?> entityBounds,
    Map<String, dynamic> header,
  ) {
    var boxes = [
      for (final box in entityBounds)
        if (box != null && box.isFinite) box,
    ];
    if (boxes.isEmpty) return const Rect.fromLTWH(0, 0, 100, 100);
    final min = _point(header['model_space_extents_min']),
        max = _point(header['model_space_extents_max']);
    final extents = Rect.fromPoints(min, max);
    if (extents.isFinite && !extents.isEmpty) {
      final paddedExtents = extents.inflate(math.max(extents.longestSide * .1, 10));
      final filtered = boxes.where(paddedExtents.overlaps).toList();
      if (filtered.length >= 3 && filtered.length * 4 >= boxes.length) {
        boxes = filtered;
      }
    }
    final bounds = boxes.reduce((a, b) => a.expandToInclude(b));
    return Rect.fromCenter(
      center: bounds.center,
      width: math.max(bounds.width, 1),
      height: math.max(bounds.height, 1),
    );
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }
  static List<dynamic> _list(dynamic value) => value is List ? value : [];
  static double _number(dynamic value, [double fallback = 0]) =>
      value is num ? value.toDouble() : fallback;
  static Offset _point(dynamic value) {
    final v = _map(value);
    return Offset(_number(v['x']), _number(v['y']));
  }

  static double _degrees(dynamic value) => _number(value) * 180 / math.pi;
  static int _bits(dynamic value) {
    if (value is int) return value;
    final flags = _map(value);
    return flags['bits'] as int? ??
        ((flags['invisible'] == true ? 1 : 0) |
            (flags['constant'] == true ? 2 : 0));
  }

  static double? _weight(dynamic value) {
    final n = _map(value)['Value'];
    return n is num && n >= 0 ? n / 100 : null;
  }

  static (int?, int?) _color(dynamic value) {
    if (value == 'ByLayer') return (256, null);
    if (value == 'ByBlock') return (0, null);
    final color = _map(value);
    if (color['Index'] is int) return (color['Index'] as int, null);
    final rgb = _map(color['Rgb']);
    return rgb.isEmpty
        ? (null, null)
        : (
            null,
            0xff000000 |
                (rgb['r'] as int) << 16 |
                (rgb['g'] as int) << 8 |
                (rgb['b'] as int),
          );
  }

  static int _horizontal(dynamic value) =>
      const {
        'Left': 0,
        'Center': 1,
        'Right': 2,
        'Aligned': 3,
        'Middle': 4,
        'Fit': 5,
      }[value] ??
      0;
  static int _vertical(dynamic value) =>
      const {'Baseline': 0, 'Bottom': 1, 'Middle': 2, 'Top': 3}[value] ?? 0;
  static int _attachment(dynamic value) =>
      const {
        'TopLeft': 1,
        'TopCenter': 2,
        'TopRight': 3,
        'MiddleLeft': 4,
        'MiddleCenter': 5,
        'MiddleRight': 6,
        'BottomLeft': 7,
        'BottomCenter': 8,
        'BottomRight': 9,
      }[value] ??
      1;
  static String _clean(dynamic value) =>
      CadTextDecoder.single(value as String? ?? '');
}
