import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../../../core/services/dwg_converter_service.dart';
import '../../../core/services/universal_encoding_service.dart';
import '../../dxf_viewer/binary/kcad_service.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../../dxf_viewer/parser/dxf_parser.dart';
import '../../structural_designer/analysis/structural_underlay_filter.dart';
import '../../structural_designer/analysis/wall_axis_detector.dart';
import '../../structural_designer/analysis/slab_envelope_detector.dart';
import '../../structural_designer/models/structural_element.dart';
import 'dxf_document_transformer.dart';

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
  static const version = 1;

  static Map<String, dynamic>? read(DxfDocument doc) {
    final raw = doc.headerVars[key];
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw);
      if (value is Map<String, dynamic> &&
          value['version'] == version &&
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

  static void setFiltered(DxfDocument doc, bool filtered) {
    final metadata = read(doc);
    if (metadata == null) return;
    final generated = generatedLayers(doc);
    final original = Map<String, dynamic>.from(metadata['visibility'] as Map);
    // A completed empty result must leave the source visible.
    final hasResults = metadata['hasResults'] == true;
    for (final layer in doc.layers.values) {
      layer.isVisible = filtered && hasResults
          ? generated.contains(layer.name)
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
  final detected = WallAxisDetector.detect(doc);
  final envelope = SlabEnvelopeDetector.detect(detected);
  final candidates = unique('BIM_Slab_Candidates', doc.layers.keys);
  final assumed = unique('BIM_Slab_Assumed_Gaps', doc.layers.keys);
  final slabLayers = StructuralUnderlayFilter.detectSlabLayers(
    doc,
  ).detectedLayers.toSet();
  final additions = <DxfEntity>[];
  final generatedBlocks = <String>[];
  for (final gap in envelope.assumedGaps) {
    additions.add(
      DxfLine(p1: gap.start, p2: gap.end, layer: assumed, colorIndex: 1),
    );
  }
  for (final ring in envelope.contours) {
    for (var i = 0; i < ring.length; i++) {
      additions.add(
        DxfLine(
          p1: ring[i],
          p2: ring[(i + 1) % ring.length],
          layer: candidates,
          colorIndex: 30,
        ),
      );
    }
  }
  for (final segment in {
    ...detected.wallContourSegments,
    ...detected.closureSegments,
  }) {
    additions.add(DxfLine(p1: segment.$1, p2: segment.$2, layer: walls));
  }
  // Clone only slab branches, keeping INSERT transforms and original definitions.
  DxfEntity? slabCopy(DxfEntity entity, bool inherited, Set<String> stack) {
    final selected = inherited || slabLayers.contains(entity.layer);
    if (entity is DxfInsert) {
      if (stack.contains(entity.blockName)) {
        throw FormatException('Cyclic block: ${entity.blockName}');
      }
      final block = doc.blocks[entity.blockName];
      if (block == null) {
        if (selected) {
          throw FormatException('Missing slab block: ${entity.blockName}');
        }
        return null;
      }
      final children = block.entities
          .map((e) => slabCopy(e, selected, {...stack, entity.blockName}))
          .whereType<DxfEntity>()
          .toList();
      if (children.isEmpty) return null;
      final name = unique('KOTO_BIM_SLAB', doc.blocks.keys);
      doc.blocks[name] = DxfBlock(
        name: name,
        basePoint: block.basePoint,
        entities: children,
      );
      generatedBlocks.add(name);
      return DxfInsert(
        blockName: name,
        insertPoint: entity.insertPoint,
        scaleX: entity.scaleX,
        scaleY: entity.scaleY,
        scaleZ: entity.scaleZ,
        rotationDeg: entity.rotationDeg,
        rowCount: entity.rowCount,
        colCount: entity.colCount,
        rowSpacing: entity.rowSpacing,
        colSpacing: entity.colSpacing,
        attributes: entity.attributes,
        layer: slabs,
        colorIndex: entity.colorIndex,
        trueColor: entity.trueColor,
      );
    }
    if (!selected) return null;
    final copy = DxfDocumentTransformer.copyToLayer(entity, slabs);
    if (copy.layer != slabs) {
      throw UnsupportedError('Slab entity: ${entity.typeName}');
    }
    return copy;
  }

  for (final entity in List<DxfEntity>.of(doc.entities)) {
    if (entity.isPaperSpace) continue;
    final copy = slabCopy(entity, false, {});
    if (copy != null) additions.add(copy);
  }
  doc.layers[walls] = DxfLayer(
    name: walls,
    colorIndex: 7,
    customLineweight: 0.30,
  );
  doc.layers[slabs] = DxfLayer(name: slabs, colorIndex: 7);
  if (envelope.contours.isNotEmpty) {
    doc.layers[candidates] = DxfLayer(name: candidates, colorIndex: 30);
  }
  if (envelope.assumedGaps.isNotEmpty) {
    doc.layers[assumed] = DxfLayer(name: assumed, colorIndex: 1);
  }
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
    'layers': [
      walls,
      slabs,
      if (envelope.contours.isNotEmpty) candidates,
      if (envelope.assumedGaps.isNotEmpty) assumed,
    ],
    'slabEnvelope': envelope.toJson(),
    'blocks': generatedBlocks,
    'visibility': originalVisibility,
    'axes': axes.map((a) => a.toJson()).toList(),
  });
  BimUnderlayMetadata.setFiltered(doc, true);
  return doc.toIsolateSafe();
}
