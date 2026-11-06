import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'architect_export_job.dart';

/// DXF 2013 serialization consumes only plain packets and runs in a worker.
/// Geometry, publication text and clipping are prepared on the caller isolate.
abstract final class ArchitectDxfWriter {
  static Uint8List write(Map<String, Object?> packet) =>
      Uint8List.fromList(utf8.encode(_Document(packet).write()));

  /// Native serialization has no Flutter dependencies. A separate worker can
  /// be killed immediately when a large export is cancelled by the user.
  static Future<Uint8List> writeInWorker(
    Map<String, Object?> packet, {
    bool Function()? isCancelled,
  }) async {
    architectCheckExportCancelled(isCancelled);
    final port = ReceivePort(), result = Completer<Uint8List>();
    result.future.ignore();
    Isolate? worker;
    Timer? cancellation;
    port.listen((message) {
      if (result.isCompleted) return;
      if (message is List && message.length == 2 && message[0] == 1) {
        result.complete(message[1] as Uint8List);
      } else if (message is List && message.length >= 2) {
        result.completeError(
          StateError('${message[0]}'),
          StackTrace.fromString('${message[1]}'),
        );
      } else {
        result.completeError(StateError('DXF_WORKER_RESULT'));
      }
    });
    try {
      worker = await Isolate.spawn(
        _dxfWorker,
        [port.sendPort, packet],
        onError: port.sendPort,
        errorsAreFatal: true,
        debugName: 'architect-dxf',
      );
      if (isCancelled != null) {
        cancellation = Timer.periodic(const Duration(milliseconds: 40), (_) {
          if (!result.isCompleted && isCancelled()) {
            result.completeError(const ArchitectExportCancelled());
          }
        });
      }
      final bytes = await result.future;
      architectCheckExportCancelled(isCancelled);
      return bytes;
    } finally {
      cancellation?.cancel();
      port.close();
      worker?.kill(priority: Isolate.immediate);
    }
  }
}

void _dxfWorker(List<Object?> arguments) {
  final port = arguments[0] as SendPort;
  try {
    port.send([
      1,
      ArchitectDxfWriter.write(arguments[1] as Map<String, Object?>),
    ]);
  } catch (error, stack) {
    port.send([error.toString(), stack.toString()]);
  }
}

class _Tags {
  final values = <Object>[];
  void add(int code, Object value) => values.addAll([code, value]);
  void point(int code, List<double> p, {bool three = false}) {
    add(code, p[0]);
    add(code + 10, p[1]);
    if (three) add(code + 20, p.length > 2 ? p[2] : 0.0);
  }

  void append(_Tags other) => values.addAll(other.values);
  @override
  String toString() {
    final strings = values.map((value) {
      if (value is double) {
        if (!value.isFinite) {
          throw StateError('DXF_NONFINITE_COORDINATE');
        }
        return value == 0 ? '0.0' : value.toString();
      }
      return value.toString().replaceAll('\r', '').replaceAll('\n', ' ');
    });
    return '${strings.join('\r\n')}\r\n';
  }
}

class _Block {
  _Block(this.name, this.record, this.begin, this.end);
  final String name, record, begin, end;
  final entities = _Tags();
}

class _Document {
  _Document(this.packet) {
    for (final name in [
      'VPORT',
      'LTYPE',
      'LAYER',
      'STYLE',
      'VIEW',
      'UCS',
      'APPID',
      'DIMSTYLE',
      'BLOCK_RECORD',
    ]) {
      tables[name] = next();
    }
    root = next();
    layouts = next();
    groups = next();
    modelLayout = next();
    paperLayout = next();
    model = block('*Model_Space');
    paper = block('*Paper_Space');
    for (final name in ['0', 'KOTO_VIEWPORTS']) {
      layer(name);
    }
    for (final name in [
      'Standard',
      'KOTO_REGULAR',
      'KOTO_BOLD',
      'KOTO_ITALIC',
      'KOTO_BOLD_ITALIC',
    ]) {
      styles[name] = next();
    }
  }
  final Map<String, Object?> packet;
  var counter = 0x100;
  String next() => (counter++).toRadixString(16).toUpperCase();
  final tables = <String, String>{};
  final layers = <String, String>{};
  final styles = <String, String>{};
  final blocks = <_Block>[];
  final clippedObjects = _Tags();
  late final String root, layouts, groups, modelLayout, paperLayout;
  late final _Block model, paper;
  String? mainViewport;
  bool get isSheet => packet['sheet'] != null;
  Map<String, Object?> get sheet =>
      (packet['sheet'] as Map<String, Object?>?) ?? const {};
  double get width => (sheet['width'] as num?)?.toDouble() ?? 297;
  double get height => (sheet['height'] as num?)?.toDouble() ?? 210;
  String get sheetName => sheet['name'] as String? ?? 'Layout1';
  int get units => packet['units'] as int;
  String layer(String name) => layers.putIfAbsent(name, next);
  _Block block(String name) {
    final value = _Block(name, next(), next(), next());
    blocks.add(value);
    return value;
  }

  String write() {
    final modelEntities = _Tags(), paperEntities = _Tags();
    final views = (packet['views'] as List).cast<Map<String, Object?>>();
    final viewLayers = <String>[];
    for (var index = 0; index < views.length; index++) {
      final source = views[index];
      final prefix = isSheet ? 'KOTO_VIEW_${index + 1}' : '';
      if (isSheet) {
        layer(prefix);
        viewLayers.add(prefix);
        final b = block('KOTO_DRAWING_${index + 1}');
        for (final e
            in (source['entities'] as List).cast<Map<String, Object?>>()) {
          entity(b.entities, e, b.record, prefix: prefix);
        }
        final insert = base('INSERT', model.record, prefix, false);
        insert.add(100, 'AcDbBlockReference');
        insert.add(2, b.name);
        insert.point(10, const [0, 0], three: true);
        modelEntities.append(insert);
      } else {
        for (final e
            in (source['entities'] as List).cast<Map<String, Object?>>()) {
          entity(modelEntities, e, model.record);
        }
      }
    }
    if (isSheet) {
      for (final e
          in (packet['paperEntities'] as List).cast<Map<String, Object?>>()) {
        entity(paperEntities, e, paper.record, paperSpace: true);
      }
      mainViewport = next();
      viewport(
        paperEntities,
        {
          'center': [width / 2, height / 2],
          'width': width,
          'height': height,
          'viewHeight': height,
          'target': [width / 2, height / 2],
          'rotation': 0.0,
        },
        1,
        const [],
        handle: mainViewport,
      );
      final ports = (packet['viewports'] as List).cast<Map<String, Object?>>();
      for (var i = 0; i < ports.length; i++) {
        final v = ports[i];
        String? boundary;
        if (v['crop'] != null) {
          boundary = next();
          entity(
            paperEntities,
            {
              'type': 'polyline',
              'points': v['crop'],
              'closed': true,
              'layer': 'KOTO_VIEWPORTS',
              'color': 0,
              'weight': .13,
            },
            paper.record,
            paperSpace: true,
            handle: boundary,
          );
        }
        viewport(paperEntities, v, i + 2, [
          for (var k = 0; k < viewLayers.length; k++)
            if (k != i)
              for (final entry in layers.entries)
                if (entry.key == viewLayers[k] ||
                    entry.key.startsWith('${viewLayers[k]}_'))
                  entry.value,
        ], boundary: boundary);
      }
    }
    final out = _Tags();
    out.add(0, 'SECTION');
    out.add(2, 'HEADER');
    void header(String name, int code, Object value) {
      out.add(9, name);
      out.add(code, value);
    }

    header(r'$ACADVER', 1, 'AC1027');
    header(r'$DWGCODEPAGE', 3, 'UTF-8');
    header(r'$INSUNITS', 70, units);
    header(r'$MEASUREMENT', 70, units == 1 || units == 2 ? 0 : 1);
    header(r'$TILEMODE', 70, isSheet ? 0 : 1);
    header(r'$CTAB', 1, isSheet ? sheetName : 'Model');
    header(r'$LWDISPLAY', 290, 1);
    header(r'$INSBASE', 10, 0.0);
    out.add(20, 0.0);
    out.add(30, 0.0);
    // All remaining sections are prepared before HANDSEED is emitted.
    final tableSection = tableData();
    final blockSection = blockData();
    final objectSection = objectData();
    header(r'$HANDSEED', 5, (counter + 1).toRadixString(16).toUpperCase());
    out.add(0, 'ENDSEC');
    out.add(0, 'SECTION');
    out.add(2, 'CLASSES');
    out.add(0, 'ENDSEC');
    out.append(tableSection);
    out.append(blockSection);
    out.add(0, 'SECTION');
    out.add(2, 'ENTITIES');
    out.append(modelEntities);
    out.append(paperEntities);
    out.add(0, 'ENDSEC');
    out.append(objectSection);
    out.add(0, 'EOF');
    return out.toString();
  }

  _Tags base(
    String type,
    String owner,
    String name,
    bool paperSpace, {
    String? handle,
    String? extension,
  }) {
    layer(name);
    final t = _Tags()
      ..add(0, type)
      ..add(5, handle ?? next());
    if (extension != null) {
      t.add(102, '{ACAD_XDICTIONARY');
      t.add(360, extension);
      t.add(102, '}');
    }
    t.add(330, owner);
    t.add(100, 'AcDbEntity');
    if (paperSpace) {
      t.add(67, 1);
      t.add(410, sheetName);
    }
    t.add(8, name);
    return t;
  }

  void appearance(_Tags t, Map<String, Object?> e) {
    final rgb = e['color'] as int? ?? 0;
    t.add(62, 7);
    if (rgb != 0) t.add(420, rgb);
    final opacity = (e['opacity'] as num?)?.toDouble() ?? 1.0;
    if (opacity < 1) {
      // DXF alpha byte is opacity (0 transparent, 255 opaque), with the
      // explicit-transparency flag. Preserve overlapping fills and labels.
      t.add(440, 0x02000000 | (opacity.clamp(0.0, 1.0) * 255).round());
    }
    final weight = (e['weight'] as num?)?.toDouble() ?? .18;
    const standard = [
      0,
      5,
      9,
      13,
      15,
      18,
      20,
      25,
      30,
      35,
      40,
      50,
      53,
      60,
      70,
      80,
      90,
      100,
      106,
      120,
      140,
      158,
      200,
      211,
    ];
    final target = weight * 100;
    t.add(
      370,
      standard.reduce(
        (a, b) => (a - target).abs() <= (b - target).abs() ? a : b,
      ),
    );
  }

  void entity(
    _Tags out,
    Map<String, Object?> e,
    String owner, {
    bool paperSpace = false,
    String prefix = '',
    String? handle,
  }) {
    final type = e['type'] as String;
    final role = e['layer'] as String? ?? '0';
    final name = prefix.isEmpty || role == 'KOTO_VIEWPORTS'
        ? role
        : '${prefix}_$role';
    final masks = e['clipPolygons'] as List?;
    if (type == 'text' && masks != null) {
      if (masks.isEmpty) return;
      // An ordinary editable MTEXT lives in a block. A native SPATIAL_FILTER
      // clips its INSERT, including glyphs crossing the source's own mask.
      final textBlock = block('KOTO_TEXT_${blocks.length}');
      entity(
        textBlock.entities,
        {...e}..remove('clipPolygons'),
        textBlock.record,
        prefix: prefix,
      );
      for (final raw in masks) {
        final polygon = (raw as List).map(_point).toList();
        if (polygon.length < 3) continue;
        final insert = next(),
            extension = next(),
            filter = next(),
            spatial = next();
        final t = base(
          'INSERT',
          owner,
          name,
          paperSpace,
          handle: insert,
          extension: extension,
        );
        t.add(100, 'AcDbBlockReference');
        t.add(2, textBlock.name);
        t.point(10, const [0, 0], three: true);
        out.append(t);
        void dictionary(String id, String parent, String key, String value) {
          clippedObjects.add(0, 'DICTIONARY');
          clippedObjects.add(5, id);
          clippedObjects.add(330, parent);
          clippedObjects.add(100, 'AcDbDictionary');
          clippedObjects.add(280, 1);
          clippedObjects.add(281, 1);
          clippedObjects.add(3, key);
          clippedObjects.add(350, value);
        }

        dictionary(extension, insert, 'ACAD_FILTER', filter);
        dictionary(filter, extension, 'SPATIAL', spatial);
        clippedObjects.add(0, 'SPATIAL_FILTER');
        clippedObjects.add(5, spatial);
        clippedObjects.add(102, '{ACAD_REACTORS');
        clippedObjects.add(330, filter);
        clippedObjects.add(102, '}');
        clippedObjects.add(330, filter);
        clippedObjects.add(100, 'AcDbFilter');
        clippedObjects.add(100, 'AcDbSpatialFilter');
        clippedObjects.add(70, polygon.length);
        for (final p in polygon) {
          clippedObjects.point(10, p);
        }
        clippedObjects.point(210, const [0, 0, 1], three: true);
        clippedObjects.point(11, const [0, 0, 0], three: true);
        clippedObjects.add(71, 1);
        clippedObjects.add(72, 0);
        clippedObjects.add(73, 0);
        const identity = [
          1.0,
          0.0,
          0.0,
          0.0,
          0.0,
          1.0,
          0.0,
          0.0,
          0.0,
          0.0,
          1.0,
          0.0,
        ];
        for (var matrix = 0; matrix < 2; matrix++) {
          for (final value in identity) {
            clippedObjects.add(40, value);
          }
        }
      }
      return;
    }
    final kind = switch (type) {
      'text' => 'MTEXT',
      'hatch' => 'HATCH',
      _ => 'LWPOLYLINE',
    };
    final t = base(kind, owner, name, paperSpace, handle: handle);
    appearance(t, e);
    if (type == 'text') {
      t.add(100, 'AcDbMText');
      t.point(10, _point(e['at']), three: true);
      t.add(40, e['height']!);
      t.add(41, e['width']!);
      t.add(71, 1);
      t.add(72, 1);
      t.add(7, e['style'] ?? 'KOTO_REGULAR');
      // An explicit direction vector avoids differing historical meanings of
      // MTEXT group 50 in CAD APIs versus exchanged DXF files.
      final angle = ((e['rotation'] as num?)?.toDouble() ?? 0) * math.pi / 180;
      t.point(11, [math.cos(angle), math.sin(angle), 0], three: true);
      var text = (e['text'] as String)
          .replaceAll('\\', r'\\')
          .replaceAll('{', r'\{')
          .replaceAll('}', r'\}')
          .replaceAll('\n', r'\P');
      if (e['underline'] == true) text = r'\L' + text + r'\l';
      if (e['overline'] == true) text = r'\O' + text + r'\o';
      if (e['strike'] == true) text = r'\K' + text + r'\k';
      // Stay under both the character and legacy byte limits, preserving each
      // complete Unicode scalar even for long Cyrillic annotations.
      final chunks = <String>[];
      var chunk = <int>[], bytes = 0;
      for (final rune in text.runes) {
        final length = rune < 128
            ? 1
            : rune < 2048
            ? 2
            : rune < 65536
            ? 3
            : 4;
        if (bytes + length > 240) {
          chunks.add(String.fromCharCodes(chunk));
          chunk = [];
          bytes = 0;
        }
        chunk.add(rune);
        bytes += length;
      }
      chunks.add(String.fromCharCodes(chunk));
      for (var i = 0; i < chunks.length; i++) {
        t.add(i + 1 == chunks.length ? 1 : 3, chunks[i]);
      }
    } else if (type == 'hatch') {
      t.add(100, 'AcDbHatch');
      t.point(10, const [0, 0], three: true);
      t.point(210, const [0, 0, 1], three: true);
      final pattern = (e['pattern'] as List?) ?? const [];
      t.add(2, pattern.isEmpty ? 'SOLID' : 'KOTO_DETAIL');
      t.add(70, pattern.isEmpty ? 1 : 0);
      t.add(71, 0);
      final loops = (e['loops'] as List).cast<Map<String, Object?>>();
      t.add(91, loops.length);
      for (final loop in loops) {
        final points = (loop['points'] as List).map(_point).toList();
        t.add(92, loop['outer'] == true ? 3 : 2);
        t.add(72, 0);
        t.add(73, 1);
        t.add(93, points.length);
        for (final point in points) {
          t.point(10, point);
        }
        t.add(97, 0);
      }
      t.add(75, 0);
      t.add(76, pattern.isEmpty ? 1 : 2);
      if (pattern.isNotEmpty) {
        t.add(52, 0.0);
        t.add(41, 1.0);
        t.add(77, 0);
        t.add(78, pattern.length);
        for (final raw in pattern) {
          final line = (raw as List).cast<num>();
          t.add(53, line[0]);
          t.add(43, line[1]);
          t.add(44, line[2]);
          t.add(45, line[3]);
          t.add(46, line[4]);
          t.add(79, 2);
          t.add(49, line[5]);
          t.add(49, line[6]);
        }
      }
      t.add(98, 0);
    } else {
      t.add(100, 'AcDbPolyline');
      final points = (e['points'] as List).map(_point).toList();
      t.add(90, points.length);
      t.add(70, e['closed'] == true ? 1 : 0);
      for (final p in points) {
        t.point(10, p);
      }
    }
    final ids = (e['sources'] as List?)?.cast<String>() ?? const [];
    if (ids.isNotEmpty) {
      t.add(1001, 'KOTO');
      for (final id in ids) {
        t.add(1000, id);
      }
    }
    out.append(t);
  }

  void viewport(
    _Tags out,
    Map<String, Object?> v,
    int id,
    List<String> frozen, {
    String? boundary,
    String? handle,
  }) {
    final t = base(
      'VIEWPORT',
      paper.record,
      'KOTO_VIEWPORTS',
      true,
      handle: handle,
    );
    t.add(100, 'AcDbViewport');
    t.point(10, _point(v['center']), three: true);
    t.add(40, v['width']!);
    t.add(41, v['height']!);
    t.add(68, id == 1 ? 1 : id);
    t.add(69, id);
    t.point(12, const [0, 0]);
    t.point(13, const [0, 0]);
    t.point(14, const [10, 10]);
    t.point(15, const [10, 10]);
    t.point(16, const [0, 0, 1], three: true);
    t.point(17, _point(v['target']), three: true);
    t.add(42, 50.0);
    t.add(43, 0.0);
    t.add(44, 0.0);
    t.add(45, v['viewHeight']!);
    t.add(50, 0.0);
    t.add(51, v['rotation'] ?? 0.0);
    t.add(72, 100);
    for (final layer in frozen) {
      t.add(331, layer);
    }
    t.add(90, 32768 | 16384 | (boundary == null ? 0 : 65536));
    if (boundary != null) t.add(340, boundary);
    t.add(281, 0);
    t.add(71, 0);
    t.add(74, 0);
    t.point(110, const [0, 0, 0], three: true);
    t.point(111, const [1, 0, 0], three: true);
    t.point(112, const [0, 1, 0], three: true);
    t.add(79, 0);
    t.add(146, 0.0);
    t.add(282, 0);
    out.append(t);
  }

  _Tags tableData() {
    final out = _Tags()
      ..add(0, 'SECTION')
      ..add(2, 'TABLES');
    void table(String name, int count, void Function(_Tags, String) build) {
      final id = tables[name]!;
      out.add(0, 'TABLE');
      out.add(2, name);
      out.add(5, id);
      out.add(330, '0');
      out.add(100, 'AcDbSymbolTable');
      out.add(70, count);
      build(out, id);
      out.add(0, 'ENDTAB');
    }

    void record(
      _Tags t,
      String type,
      String id,
      String owner,
      String subtype,
      String name,
    ) {
      t.add(0, type);
      t.add(type == 'DIMSTYLE' ? 105 : 5, id);
      t.add(330, owner);
      t.add(100, 'AcDbSymbolTableRecord');
      t.add(100, subtype);
      t.add(2, name);
    }

    table('VPORT', 1, (t, o) {
      record(t, 'VPORT', next(), o, 'AcDbViewportTableRecord', '*Active');
      t.add(70, 0);
      t.point(10, const [0, 0]);
      t.point(11, const [1, 1]);
      t.point(12, const [0, 0]);
      t.point(16, const [0, 0, 1], three: true);
      t.point(17, const [0, 0, 0], three: true);
      t.add(40, 1000.0);
      t.add(41, 1.34);
      t.add(42, 50.0);
      t.add(43, 0.0);
      t.add(44, 0.0);
      t.add(50, 0.0);
      t.add(51, 0.0);
    });
    table('LTYPE', 3, (t, o) {
      for (final n in ['ByBlock', 'ByLayer', 'Continuous']) {
        record(t, 'LTYPE', next(), o, 'AcDbLinetypeTableRecord', n);
        t.add(70, 0);
        t.add(3, n);
        t.add(72, 65);
        t.add(73, 0);
        t.add(40, 0.0);
      }
    });
    table('LAYER', layers.length, (t, o) {
      for (final e in layers.entries) {
        record(t, 'LAYER', e.value, o, 'AcDbLayerTableRecord', e.key);
        t.add(70, 0);
        t.add(62, 7);
        t.add(6, 'Continuous');
        t.add(290, e.key == 'KOTO_VIEWPORTS' ? 0 : 1);
        t.add(370, -3);
      }
    });
    table('STYLE', styles.length, (t, o) {
      for (final e in styles.entries) {
        record(t, 'STYLE', e.value, o, 'AcDbTextStyleTableRecord', e.key);
        t.add(70, 0);
        t.add(40, 0.0);
        t.add(41, 1.0);
        t.add(50, e.key.contains('ITALIC') ? 15.0 : 0.0);
        t.add(71, 0);
        t.add(42, 2.5);
        t.add(
          3,
          e.key.contains('BOLD') ? 'NotoSans-Bold.ttf' : 'NotoSans-Regular.ttf',
        );
        t.add(4, '');
      }
    });
    for (final name in ['VIEW', 'UCS']) {
      table(name, 0, (t, o) {});
    }
    table('APPID', 2, (t, o) {
      for (final n in ['ACAD', 'KOTO']) {
        record(t, 'APPID', next(), o, 'AcDbRegAppTableRecord', n);
        t.add(70, 0);
      }
    });
    table('DIMSTYLE', 1, (t, o) {
      record(t, 'DIMSTYLE', next(), o, 'AcDbDimStyleTableRecord', 'Standard');
      t.add(70, 0);
      t.add(40, 1.0);
      t.add(140, 2.5);
      t.add(340, styles['Standard']!);
    });
    table('BLOCK_RECORD', blocks.length, (t, o) {
      for (final b in blocks) {
        record(t, 'BLOCK_RECORD', b.record, o, 'AcDbBlockTableRecord', b.name);
        if (b == model) t.add(340, modelLayout);
        if (b == paper) t.add(340, paperLayout);
        t.add(70, 0);
        t.add(280, 1);
        t.add(281, 0);
      }
    });
    out.add(0, 'ENDSEC');
    return out;
  }

  _Tags blockData() {
    final out = _Tags()
      ..add(0, 'SECTION')
      ..add(2, 'BLOCKS');
    for (final b in blocks) {
      final t = base('BLOCK', b.record, '0', false, handle: b.begin)
        ..add(100, 'AcDbBlockBegin')
        ..add(2, b.name)
        ..add(70, 0)
        ..point(10, const [0, 0], three: true)
        ..add(3, b.name)
        ..add(1, '');
      out.append(t);
      out.append(b.entities);
      out.append(
        base('ENDBLK', b.record, '0', false, handle: b.end)
          ..add(100, 'AcDbBlockEnd'),
      );
    }
    out.add(0, 'ENDSEC');
    return out;
  }

  _Tags objectData() {
    final out = _Tags()
      ..add(0, 'SECTION')
      ..add(2, 'OBJECTS');
    void dict(String id, String owner, Map<String, String> entries) {
      out.add(0, 'DICTIONARY');
      out.add(5, id);
      out.add(330, owner);
      out.add(100, 'AcDbDictionary');
      out.add(281, 1);
      for (final e in entries.entries) {
        out.add(3, e.key);
        out.add(350, e.value);
      }
    }

    dict(root, '0', {'ACAD_GROUP': groups, 'ACAD_LAYOUT': layouts});
    dict(groups, root, {});
    dict(layouts, root, {'Model': modelLayout, sheetName: paperLayout});
    void layout(String id, String name, int order, String record) {
      out.add(0, 'LAYOUT');
      out.add(5, id);
      out.add(330, layouts);
      out.add(100, 'AcDbPlotSettings');
      out.add(1, '');
      out.add(4, 'KOTO_${width}x$height');
      out.add(6, '');
      for (final code in [40, 41, 42, 43]) {
        out.add(code, 0.0);
      }
      out.add(44, width);
      out.add(45, height);
      for (final c in [46, 47, 48, 49, 140, 141]) {
        out.add(c, 0.0);
      }
      out.add(142, 1.0);
      out.add(143, 1.0);
      out.add(70, 672);
      out.add(72, 1);
      out.add(73, 0);
      out.add(74, 5);
      out.add(7, '');
      out.add(75, 16);
      out.add(76, 0);
      out.add(77, 2);
      out.add(78, 300);
      out.add(147, 1.0);
      out.add(148, 0.0);
      out.add(149, 0.0);
      out.add(100, 'AcDbLayout');
      out.add(1, name);
      out.add(70, 1);
      out.add(71, order);
      out.point(10, const [0, 0]);
      out.point(11, [width, height]);
      out.point(12, const [0, 0, 0], three: true);
      out.point(14, const [0, 0, 0], three: true);
      out.point(15, [width, height, 0], three: true);
      out.add(146, 0.0);
      out.point(13, const [0, 0, 0], three: true);
      out.point(16, const [1, 0, 0], three: true);
      out.point(17, const [0, 1, 0], three: true);
      out.add(76, 1);
      out.add(330, record);
      if (order == 1 && mainViewport != null) out.add(331, mainViewport!);
    }

    layout(modelLayout, 'Model', 0, model.record);
    layout(paperLayout, sheetName, 1, paper.record);
    out.append(clippedObjects);
    out.add(0, 'ENDSEC');
    return out;
  }
}

List<double> _point(Object? value) =>
    (value as List).map((n) => (n as num).toDouble()).toList();
