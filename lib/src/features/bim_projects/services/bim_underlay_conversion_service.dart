import 'dart:async';
import 'dart:convert';
import '../../structural_designer/analysis/drawing_frame_detector.dart';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../../../core/services/dwg_converter_service.dart';
import '../../../core/services/universal_encoding_service.dart';
import '../../dxf_viewer/binary/kcad_service.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../../dxf_viewer/parser/dxf_parser.dart';
import '../../structural_designer/analysis/wall_axis_detector.dart';
import '../../structural_designer/analysis/slab_envelope_detector.dart';
import '../../structural_designer/analysis/slab_projection_detector.dart';
import '../../structural_designer/models/structural_element.dart';

enum BimConversionStage { converting, analysing, ready }

/// Immutable result owned by its caller until the library publishes a copy.
class BimConversionResult {
  final Directory directory;
  final File sourceFile;
  final File pureKcadFile;
  final File kcadFile;
  final File? dxfFile;
  final String sourceFingerprint;
  const BimConversionResult({
    required this.directory,
    required this.sourceFile,
    required this.pureKcadFile,
    required this.kcadFile,
    this.dxfFile,
    required this.sourceFingerprint,
  });

  Future<void> dispose() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

/// Metadata travels with the binary document, including empty analysis results.
class BimUnderlayMetadata {
  static const key = r'$KOTO_BIM_UNDERLAY';
  static const version = 9;

  static Map<String, dynamic>? read(DxfDocument doc) {
    final raw = doc.headerVars[key];
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw);
      if (value is Map<String, dynamic> &&
          (value['version'] == version ||
              value['version'] == 8 ||
              value['version'] == 7 ||
              value['version'] == 6 ||
              value['version'] == 5 ||
              value['version'] == 4 ||
              value['version'] == 3 ||
              value['version'] == 2 ||
              value['version'] == 1) &&
          value['complete'] == true) {
        return value;
      }
    } catch (_) {
      /* An input header is not trusted processing metadata. */
    }
    return null;
  }

  static List<StructuralGridAxis> axes(DxfDocument doc) =>
      ((read(doc)?['axes'] as List?) ?? [])
          .map(
            (a) => StructuralGridAxis.fromJson(
              Map<String, dynamic>.from(a as Map),
            ),
          )
          .toList();

  static Set<String> generatedLayers(DxfDocument doc) =>
      Set<String>.from((read(doc)?['layers'] as List?) ?? []);

  static const dynamicKey = r'$KOTO_BIM_DYNAMIC_LAYERS';

  static Map<String, String> dynamicLayers(DxfDocument doc) {
    final metadata = read(doc);
    final value = metadata?['dynamicLayers'];
    if (value is Map) return Map<String, String>.from(value);
    try {
      return Map<String, String>.from(
        jsonDecode(doc.headerVars[dynamicKey] ?? '{}') as Map,
      );
    } catch (_) {
      return {};
    }
  }

  static Set<String> dynamicLayerNames(DxfDocument doc) =>
      dynamicLayers(doc).values.toSet();

  static bool dynamicVisible(DxfDocument doc, String kind) {
    final name = dynamicLayers(doc)[kind];
    final layer = doc.layers[name];
    return layer == null || (layer.isVisible && !layer.isFrozen);
  }

  /// Replace owned CAD copies with visibility groups for live model objects.
  /// Original source layers, including BIM-looking names, are never deleted.
  static void ensureDynamicLayers(DxfDocument doc) {
    if (dynamicLayers(doc).isNotEmpty) return;
    final metadata = read(doc);
    if (metadata != null) {
      final wall = metadata['wallLayer'];
      final obsolete = generatedLayers(doc)..remove(wall);
      doc.entities.removeWhere((e) => obsolete.contains(e.layer));
      for (final entities in doc.layoutEntities.values) {
        entities.removeWhere((e) => obsolete.contains(e.layer));
      }
      for (final name in obsolete) {
        doc.layers.remove(name);
      }
      for (final name in (metadata['blocks'] as List? ?? [])) {
        doc.blocks.remove(name);
      }
      metadata['blocks'] = <String>[];
      metadata['hasResults'] = doc.entities.any((e) => e.layer == wall);
      doc.spatialIndex = null;
    }
    String unique(String base) {
      var result = base, i = 1;
      while (doc.layers.keys.any(
        (name) => name.toLowerCase() == result.toLowerCase(),
      )) {
        result = '${base}_${i++}';
      }
      return result;
    }

    final names = {'axes': unique('BIM_Axis'), 'slabs': unique('BIM_Slabs')};
    for (final entry in names.entries) {
      doc.layers[entry.value] = DxfLayer(
        name: entry.value,
        colorIndex: entry.key == 'axes' ? 1 : 7,
      );
    }
    if (metadata != null) {
      metadata['dynamicLayers'] = names;
      metadata['layers'] = [
        if (metadata['wallLayer'] != null) metadata['wallLayer'],
        ...names.values,
      ];
      metadata['visibleLayers'] = metadata['layers'];
      doc.headerVars[key] = jsonEncode(metadata);
    } else {
      doc.headerVars[dynamicKey] = jsonEncode(names);
    }
  }

  static void setFiltered(DxfDocument doc, bool filtered) {
    final metadata = read(doc);
    if (metadata == null) return;
    final generated = generatedLayers(doc);
    final dynamicNames = dynamicLayerNames(doc);
    final visible = Set<String>.from(
      metadata['visibleLayers'] as List? ?? metadata['layers'] as List,
    );
    final original = Map<String, dynamic>.from(metadata['visibility'] as Map);
    // A completed empty result must leave the source visible.
    final hasResults = metadata['hasResults'] == true;
    for (final layer in doc.layers.values) {
      if (dynamicNames.contains(layer.name)) continue;
      layer.isVisible = filtered && hasResults
          ? visible.contains(layer.name)
          : !generated.contains(layer.name) && (original[layer.name] == true);
    }
  }
}

class BimUnderlayConversionService {
  // Bound expensive drawing analysis to one job, including multiple wizards.
  static Future<void> _queue = Future<void>.value();

  static Future<BimConversionResult> convert(
    File source, {
    void Function(BimConversionStage)? onProgress,
    bool Function()? isCancelled,
  }) {
    final result = _queue.then((_) async {
      if (isCancelled?.call() == true) throw StateError('Conversion cancelled');
      return _convert(source, onProgress: onProgress, isCancelled: isCancelled);
    });
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  static Future<BimConversionResult> _convert(
    File source, {
    void Function(BimConversionStage)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final ext = source.path.split('.').last.toLowerCase();
    if (!{'dwg', 'dxf', 'kcad'}.contains(ext)) {
      throw UnsupportedError('Expected DWG, DXF or KCAD');
    }
    final dir = await Directory.systemTemp.createTemp('koto_bim_conversion_');
    try {
      onProgress?.call(BimConversionStage.converting);
      final original = await source.copy('${dir.path}/source.$ext');
      final fingerprint = (await sha256.bind(original.openRead()).first)
          .toString();
      File? dxf;
      if (ext == 'dwg') {
        // The converter cache keys include the basename, size and mtime.
        // A content-derived name avoids collisions between unrelated inputs.
        final converterInput = await original.copy(
          '${dir.path}/$fingerprint.dwg',
        );
        final converted = await DwgConverterService.convertDwgToDxf(
          converterInput.uri.toFilePath(),
        );
        dxf = await File(converted).copy('${dir.path}/source.dxf');
        await converterInput.delete();
      } else if (ext == 'dxf') {
        dxf = original;
      }
      final document = ext == 'kcad'
          ? await KcadService.loadKcadFile(original)
          : await compute(_parseSourceDxf, dxf!.path);
      // KCAD input may itself be a previously baked underlay. Strip only owned
      // generated objects and restore original visibility before reprocessing.
      final previous = BimUnderlayMetadata.read(document);
      if (previous != null) {
        BimUnderlayMetadata.setFiltered(document, false);
        final owned = BimUnderlayMetadata.generatedLayers(document);
        document.entities.removeWhere((e) => owned.contains(e.layer));
        for (final entities in document.layoutEntities.values) {
          entities.removeWhere((e) => owned.contains(e.layer));
        }
        for (final layer in owned) {
          document.layers.remove(layer);
        }
        for (final block in (previous['blocks'] as List? ?? [])) {
          document.blocks.remove(block);
        }
        document.headerVars.remove(BimUnderlayMetadata.key);
      }
      final pure = File('${dir.path}/pure.kcad');
      await KcadService.exportKcadFile(document, pure.path);
      if (isCancelled?.call() == true) throw StateError('Conversion cancelled');
      onProgress?.call(BimConversionStage.analysing);
      final processed = await compute(_analyse, document.toIsolateSafe());
      if (isCancelled?.call() == true) throw StateError('Conversion cancelled');
      final baked = File('${dir.path}/working.kcad');
      await KcadService.exportKcadFile(processed, baked.path);
      final check = await KcadService.loadKcadFile(baked);
      if (BimUnderlayMetadata.read(check) == null) {
        throw StateError('KCAD validation failed');
      }
      onProgress?.call(BimConversionStage.ready);
      return BimConversionResult(
        directory: dir,
        sourceFile: original,
        pureKcadFile: pure,
        kcadFile: baked,
        dxfFile: dxf,
        sourceFingerprint: fingerprint,
      );
    } catch (_) {
      await dir.delete(recursive: true);
      rethrow;
    }
  }
}

DxfDocument _parseSourceDxf(String path) {
  final content = UniversalEncodingService.decodeBytes(
    File(path).readAsBytesSync(),
  );
  if (!RegExp(r'^\s*0\s*\r?\n\s*EOF\s*$', multiLine: true).hasMatch(content) ||
      !RegExp(
        r'^\s*0\s*\r?\n\s*SECTION\s*$',
        multiLine: true,
      ).hasMatch(content)) {
    throw const FormatException('Invalid or unsupported DXF');
  }
  return DxfParser.parseString(content).toIsolateSafe();
}

DxfDocument _analyse(DxfDocument doc) {
  final originalVisibility = {
    for (final l in doc.layers.values) l.name: l.isVisible,
  };
  String unique(String base, Iterable<String> existing) {
    final names = existing.map((s) => s.toLowerCase()).toSet();
    var name = base;
    var i = 1;
    while (names.contains(name.toLowerCase())) {
      name = '${base}_${i++}';
    }
    return name;
  }

  final walls = unique('BIM_Walls', doc.layers.keys);
  final slabs = unique('BIM_Slabs', doc.layers.keys);
  final analysisDoc = DrawingFrameDetector.withoutFrames(doc);
  final detected = WallAxisDetector.detect(analysisDoc);
  final envelope = SlabEnvelopeDetector.detect(detected, document: analysisDoc);
  final projections = SlabProjectionDetector.detect(
    analysisDoc,
    envelope,
    detected.detectedScale,
    wallLayers: detected.selectedWallPairs
        .expand((p) => [p.segmentA.sourceLayer, p.segmentB.sourceLayer])
        .toSet(),
  );
  final axisLayer = unique('BIM_Axis', doc.layers.keys);
  final additions = <DxfEntity>[];
  for (final segment in {
    ...detected.wallContourSegments,
    ...detected.closureSegments,
  }) {
    additions.add(DxfLine(p1: segment.$1, p2: segment.$2, layer: walls));
  }
  doc.layers[walls] = DxfLayer(
    name: walls,
    colorIndex: 7,
    customLineweight: 0.30,
  );
  doc.layers[slabs] = DxfLayer(name: slabs, colorIndex: 7);
  doc.layers[axisLayer] = DxfLayer(name: axisLayer, colorIndex: 1);
  doc.entities.addAll(additions);
  final model = doc.layoutEntities['Model'];
  if (model != null && !identical(model, doc.entities)) model.addAll(additions);
  doc.spatialIndex = null;
  final axes = WallAxisDetector.convertToStructuralGridAxes(
    detected.snappedCenterlines,
    scale: detected.detectedScale,
    isBulgarian: false,
  );
  doc.headerVars[BimUnderlayMetadata.key] = jsonEncode({
    'version': BimUnderlayMetadata.version,
    'complete': true,
    'hasResults': additions.isNotEmpty,
    'wallsFound': detected.hasWallsFound,
    'wallLayer': walls,
    'layers': [walls, slabs, axisLayer],
    'visibleLayers': [walls, slabs, axisLayer],
    'dynamicLayers': {'axes': axisLayer, 'slabs': slabs},
    'slabEnvelope': envelope.toJson(),
    'slabProjections': projections.map((p) => p.toJson()).toList(),
    'blocks': <String>[],
    'visibility': originalVisibility,
    'axes': axes.map((a) => a.toJson()).toList(),
  });
  BimUnderlayMetadata.setFiltered(doc, false);
  return doc.toIsolateSafe();
}
