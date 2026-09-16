import 'dart:convert';
import 'dart:io';
import '../../features/dxf_viewer/models/dxf_models.dart';
import 'universal_encoding_service.dart';

class _DxfPair {
  final int code;
  final String value;
  const _DxfPair(this.code, this.value);
}

/// Service responsible for exporting DXF files, including merging imported DXF drawings
/// (entities, blocks, layers, styles, and line types) and user-added annotations (LEADER + MTEXT)
/// compliant with AutoCAD DXF standards.
class DxfExporterService {
  /// Injects annotations into the DXF content and writes the result to [outputFile].
  /// Backwards-compatible convenience method delegating to [exportMergedDxf].
  static Future<File> saveDxfWithAnnotations({
    required File originalFile,
    required List<DxfAnnotation> annotations,
    required File outputFile,
    double defaultTextHeight = 2.5,
  }) =>
      exportMergedDxf(
        baseFile: originalFile,
        annotations: annotations,
        outputFile: outputFile,
        defaultTextHeight: defaultTextHeight,
      );

  /// Exports a complete DXF file merging [baseFile] with all [importedFiles]
  /// and any user-added [annotations].
  static Future<File> exportMergedDxf({
    required File baseFile,
    List<File> importedFiles = const [],
    List<DxfAnnotation> annotations = const [],
    required File outputFile,
    double defaultTextHeight = 2.5,
  }) async {
    if (importedFiles.isEmpty && annotations.isEmpty) {
      return baseFile.copy(outputFile.path);
    }

    final baseBytes = await baseFile.readAsBytes();
    final baseContent = UniversalEncodingService.decodeBytes(baseBytes);
    final le = baseContent.contains('\r\n') ? '\r\n' : '\n';

    final basePairs = _parsePairs(baseContent);

    // 1. Analyze base drawing handles and $HANDSEED
    int maxHandle = 0;
    int handseedIndex = -1;
    for (int i = 0; i < basePairs.length; i++) {
      final pair = basePairs[i];
      if (pair.code == 9 && pair.value.trim().toUpperCase() == r'$HANDSEED') {
        handseedIndex = i + 1;
      } else if (pair.code == 5) {
        final h = int.tryParse(pair.value.trim(), radix: 16);
        if (h != null && h > maxHandle) {
          maxHandle = h;
        }
      }
    }

    int nextHandle = maxHandle + 1;
    if (handseedIndex != -1 && handseedIndex < basePairs.length) {
      final hs = int.tryParse(basePairs[handseedIndex].value.trim(), radix: 16);
      if (hs != null && hs > nextHandle) {
        nextHandle = hs;
      }
    }

    // 2. Locate base *MODEL_SPACE BLOCK_RECORD handle and table handles
    String modelSpaceHandle = '19';
    String layerTableHandle = '2';
    String styleTableHandle = '3';
    String ltypeTableHandle = '5';
    String blockRecordTableHandle = '1';
    String? basePlotStyleHandle;
    String? baseMaterialHandle;

    final existingLayers = <String>{};
    final existingStyles = <String>{};
    final existingLtypes = <String>{};
    final existingBlockRecords = <String>{};

    bool inTables = false;
    String? currentTable;
    String? currentEntryType;
    String? curBrHandle;

    for (int i = 0; i < basePairs.length; i++) {
      final p = basePairs[i];
      if (p.code == 2 &&
          p.value.trim().toUpperCase() == 'TABLES' &&
          i > 0 &&
          basePairs[i - 1].code == 0 &&
          basePairs[i - 1].value.trim().toUpperCase() == 'SECTION') {
        inTables = true;
      } else if (inTables && p.code == 0 && p.value.trim().toUpperCase() == 'ENDSEC') {
        inTables = false;
        currentTable = null;
        currentEntryType = null;
      } else if (inTables) {
        if (p.code == 2 &&
            i > 0 &&
            basePairs[i - 1].code == 0 &&
            basePairs[i - 1].value.trim().toUpperCase() == 'TABLE') {
          currentTable = p.value.trim().toUpperCase();
          currentEntryType = null;
          // Look ahead for table handle (code 5)
          for (int j = i + 1; j < i + 10 && j < basePairs.length; j++) {
            if (basePairs[j].code == 5) {
              final h = basePairs[j].value.trim();
              if (currentTable == 'LAYER') layerTableHandle = h;
              if (currentTable == 'STYLE') styleTableHandle = h;
              if (currentTable == 'LTYPE') ltypeTableHandle = h;
              if (currentTable == 'BLOCK_RECORD') blockRecordTableHandle = h;
              break;
            }
          }
        } else if (p.code == 0 && p.value.trim().toUpperCase() == 'ENDTAB') {
          currentTable = null;
          currentEntryType = null;
        } else if (currentTable != null) {
          if (p.code == 0) {
            currentEntryType = p.value.trim().toUpperCase();
            if (currentTable == 'BLOCK_RECORD') curBrHandle = null;
          } else if (p.code == 5 && currentTable == 'BLOCK_RECORD' && curBrHandle == null) {
            curBrHandle = p.value.trim();
          } else if (p.code == 390 && currentTable == 'LAYER' && basePlotStyleHandle == null) {
            basePlotStyleHandle = p.value.trim();
          } else if (p.code == 347 && currentTable == 'LAYER' && baseMaterialHandle == null) {
            baseMaterialHandle = p.value.trim();
          } else if (p.code == 2) {
            final name = p.value.trim().toUpperCase();
            if (currentTable == 'LAYER' && currentEntryType == 'LAYER') {
              existingLayers.add(name);
            } else if (currentTable == 'STYLE' && currentEntryType == 'STYLE') {
              existingStyles.add(name);
            } else if (currentTable == 'LTYPE' && currentEntryType == 'LTYPE') {
              existingLtypes.add(name);
            } else if (currentTable == 'BLOCK_RECORD' && currentEntryType == 'BLOCK_RECORD') {
              existingBlockRecords.add(name);
              if (name == '*MODEL_SPACE' && curBrHandle != null) {
                modelSpaceHandle = curBrHandle;
              }
            }
          }
        }
      }
    }

    // 3. Extract and re-index definitions & entities from imported DXF files
    final newBlockRecordPairs = <_DxfPair>[];
    final newLayerPairs = <_DxfPair>[];
    final newStylePairs = <_DxfPair>[];
    final newLtypePairs = <_DxfPair>[];
    final newBlockPairs = <_DxfPair>[];
    final newEntityPairs = <_DxfPair>[];

    for (final impFile in importedFiles) {
      if (!await impFile.exists()) continue;
      final impBytes = await impFile.readAsBytes();
      final impContent = UniversalEncodingService.decodeBytes(impBytes);
      final impPairs = _parsePairs(impContent);

      // A) Extract TABLES (LAYER, STYLE, LTYPE)
      _extractTableFromPairs(
        pairs: impPairs,
        tableName: 'LAYER',
        existingNames: existingLayers,
        targetTableHandle: layerTableHandle,
        defaultPlotStyleHandle: basePlotStyleHandle,
        defaultMaterialHandle: baseMaterialHandle,
        nextHandleProvider: () => (nextHandle++).toRadixString(16).toUpperCase(),
        outPairs: newLayerPairs,
      );

      _extractTableFromPairs(
        pairs: impPairs,
        tableName: 'STYLE',
        existingNames: existingStyles,
        targetTableHandle: styleTableHandle,
        nextHandleProvider: () => (nextHandle++).toRadixString(16).toUpperCase(),
        outPairs: newStylePairs,
      );

      _extractTableFromPairs(
        pairs: impPairs,
        tableName: 'LTYPE',
        existingNames: existingLtypes,
        targetTableHandle: ltypeTableHandle,
        nextHandleProvider: () => (nextHandle++).toRadixString(16).toUpperCase(),
        outPairs: newLtypePairs,
      );

      // B) Extract non-model-space BLOCKS and generate BLOCK_RECORD entries
      _extractBlocksFromPairs(
        pairs: impPairs,
        existingBlockRecords: existingBlockRecords,
        blockRecordTableHandle: blockRecordTableHandle,
        nextHandleProvider: () => (nextHandle++).toRadixString(16).toUpperCase(),
        outBlockRecordPairs: newBlockRecordPairs,
        outBlockPairs: newBlockPairs,
      );

      // C) Extract model-space ENTITIES
      _extractEntitiesFromPairs(
        pairs: impPairs,
        modelSpaceHandle: modelSpaceHandle,
        nextHandleProvider: () => (nextHandle++).toRadixString(16).toUpperCase(),
        outPairs: newEntityPairs,
      );
    }

    // 4. Build annotation entities and ensure MARKUP layer exists
    if (annotations.isNotEmpty) {
      if (!existingLayers.contains('MARKUP')) {
        final markupHandle = (nextHandle++).toRadixString(16).toUpperCase();
        newLayerPairs.addAll([
          const _DxfPair(0, 'LAYER'),
          _DxfPair(5, markupHandle),
          _DxfPair(330, layerTableHandle),
          const _DxfPair(100, 'AcDbSymbolTableRecord'),
          const _DxfPair(100, 'AcDbLayerTableRecord'),
          const _DxfPair(2, 'MARKUP'),
          const _DxfPair(70, '0'),
          const _DxfPair(62, '1'),
          const _DxfPair(6, 'Continuous'),
          if (basePlotStyleHandle != null) _DxfPair(390, basePlotStyleHandle),
          if (baseMaterialHandle != null) ...[
            _DxfPair(347, baseMaterialHandle),
            const _DxfPair(348, '0'),
          ],
        ]);
        existingLayers.add('MARKUP');
      }

      for (final anno in annotations) {
        final tipX = anno.arrowTipCad.dx.toStringAsFixed(4);
        final tipY = anno.arrowTipCad.dy.toStringAsFixed(4);
        final textX = anno.textPosCad.dx.toStringAsFixed(4);
        final textY = anno.textPosCad.dy.toStringAsFixed(4);
        final h = (anno.textHeight ?? defaultTextHeight).toStringAsFixed(4);
        final sanitizedText = anno.text.replaceAll('\\', '\\\\').replaceAll('\n', r'\P');

        int aciColor = 1; // default Red
        if (anno.colorValue == 0xFFFFD600) aciColor = 2; // Yellow
        if (anno.colorValue == 0xFF00E676) aciColor = 3; // Green
        if (anno.colorValue == 0xFF00E5FF) aciColor = 4; // Cyan
        if (anno.colorValue == 0xFFFF4081) aciColor = 6; // Magenta
        if (anno.colorValue == 0xFFFFFFFF) aciColor = 7; // White

        final leaderHandle = (nextHandle++).toRadixString(16).toUpperCase();
        final mtextHandle = (nextHandle++).toRadixString(16).toUpperCase();

        // LEADER entity
        newEntityPairs.addAll([
          const _DxfPair(0, 'LEADER'),
          _DxfPair(5, leaderHandle),
          _DxfPair(330, modelSpaceHandle),
          const _DxfPair(100, 'AcDbEntity'),
          const _DxfPair(8, 'MARKUP'),
          _DxfPair(62, '$aciColor'),
          const _DxfPair(100, 'AcDbLeader'),
          const _DxfPair(71, '1'),
          const _DxfPair(72, '0'),
          const _DxfPair(76, '2'),
          _DxfPair(10, tipX),
          _DxfPair(20, tipY),
          const _DxfPair(30, '0.0'),
          _DxfPair(10, textX),
          _DxfPair(20, textY),
          const _DxfPair(30, '0.0'),
        ]);

        // MTEXT entity
        newEntityPairs.addAll([
          const _DxfPair(0, 'MTEXT'),
          _DxfPair(5, mtextHandle),
          _DxfPair(330, modelSpaceHandle),
          const _DxfPair(100, 'AcDbEntity'),
          const _DxfPair(8, 'MARKUP'),
          _DxfPair(62, '$aciColor'),
          const _DxfPair(100, 'AcDbMText'),
          _DxfPair(10, textX),
          _DxfPair(20, textY),
          const _DxfPair(30, '0.0'),
          _DxfPair(40, h),
          const _DxfPair(71, '1'),
          _DxfPair(1, sanitizedText),
        ]);
      }
    }

    // 5. Assemble merged DXF pair list
    final outPairs = <_DxfPair>[];
    String? curSection;
    String? curTableInOutput;
    bool insertedBlocks = false;
    bool insertedEntities = false;

    int idx = 0;
    while (idx < basePairs.length) {
      final p = basePairs[idx];

      // Track sections
      if (p.code == 2 &&
          idx > 0 &&
          basePairs[idx - 1].code == 0 &&
          basePairs[idx - 1].value.trim().toUpperCase() == 'SECTION') {
        curSection = p.value.trim().toUpperCase();
      } else if (p.code == 0 && p.value.trim().toUpperCase() == 'ENDSEC') {
        // Fallback insertion before ENDSEC of TABLES if BLOCK_RECORD table didn't exist
        if (curSection == 'TABLES' && newBlockRecordPairs.isNotEmpty) {
          outPairs.addAll([
            const _DxfPair(0, 'TABLE'),
            const _DxfPair(2, 'BLOCK_RECORD'),
            _DxfPair(5, blockRecordTableHandle),
            const _DxfPair(100, 'AcDbSymbolTable'),
            ...newBlockRecordPairs,
            const _DxfPair(0, 'ENDTAB'),
          ]);
          newBlockRecordPairs.clear();
        }

        // Insert blocks before ENDSEC of BLOCKS
        if (curSection == 'BLOCKS' && newBlockPairs.isNotEmpty) {
          outPairs.addAll(newBlockPairs);
          newBlockPairs.clear();
          insertedBlocks = true;
        }

        // Insert entities before ENDSEC of ENTITIES
        if (curSection == 'ENTITIES' && newEntityPairs.isNotEmpty) {
          outPairs.addAll(newEntityPairs);
          newEntityPairs.clear();
          insertedEntities = true;
        }

        curSection = null;
        curTableInOutput = null;
      }

      // Track tables
      if (curSection == 'TABLES') {
        if (p.code == 2 &&
            idx > 0 &&
            basePairs[idx - 1].code == 0 &&
            basePairs[idx - 1].value.trim().toUpperCase() == 'TABLE') {
          curTableInOutput = p.value.trim().toUpperCase();
        } else if (p.code == 0 && p.value.trim().toUpperCase() == 'ENDTAB') {
          if (curTableInOutput == 'BLOCK_RECORD' && newBlockRecordPairs.isNotEmpty) {
            outPairs.addAll(newBlockRecordPairs);
            newBlockRecordPairs.clear();
          } else if (curTableInOutput == 'LAYER' && newLayerPairs.isNotEmpty) {
            outPairs.addAll(newLayerPairs);
            newLayerPairs.clear();
          } else if (curTableInOutput == 'STYLE' && newStylePairs.isNotEmpty) {
            outPairs.addAll(newStylePairs);
            newStylePairs.clear();
          } else if (curTableInOutput == 'LTYPE' && newLtypePairs.isNotEmpty) {
            outPairs.addAll(newLtypePairs);
            newLtypePairs.clear();
          }
          curTableInOutput = null;
        }
      }

      // Update $HANDSEED to guarantee it exceeds all newly assigned handles
      if (p.code == 9 && p.value.trim().toUpperCase() == r'$HANDSEED') {
        outPairs.add(p);
        final finalHandseed = (nextHandle + 16).toRadixString(16).toUpperCase();
        outPairs.add(_DxfPair(5, finalHandseed));
        idx += 2;
        continue;
      }

      // If base file had no BLOCKS section, insert it before ENTITIES section
      if (newBlockPairs.isNotEmpty &&
          !insertedBlocks &&
          p.code == 0 &&
          p.value.trim().toUpperCase() == 'SECTION' &&
          idx + 1 < basePairs.length &&
          basePairs[idx + 1].code == 2 &&
          basePairs[idx + 1].value.trim().toUpperCase() == 'ENTITIES') {
        outPairs.addAll([
          const _DxfPair(0, 'SECTION'),
          const _DxfPair(2, 'BLOCKS'),
          ...newBlockPairs,
          const _DxfPair(0, 'ENDSEC'),
        ]);
        newBlockPairs.clear();
        insertedBlocks = true;
      }

      // If base file had no ENTITIES section, insert it before EOF
      if (newEntityPairs.isNotEmpty &&
          !insertedEntities &&
          p.code == 0 &&
          p.value.trim().toUpperCase() == 'EOF') {
        outPairs.addAll([
          const _DxfPair(0, 'SECTION'),
          const _DxfPair(2, 'ENTITIES'),
          ...newEntityPairs,
          const _DxfPair(0, 'ENDSEC'),
        ]);
        newEntityPairs.clear();
        insertedEntities = true;
      }

      outPairs.add(p);
      idx++;
    }

    // 6. Write cleanly to outputFile with constant streaming
    final sink = outputFile.openWrite(encoding: utf8);
    try {
      for (final pair in outPairs) {
        sink.write('${pair.code}$le${pair.value}$le');
      }
      await sink.flush();
    } finally {
      await sink.close();
    }

    return outputFile;
  }

  static List<_DxfPair> _parsePairs(String content) {
    final lines = const LineSplitter().convert(content);
    final pairs = <_DxfPair>[];
    int i = 0;
    while (i < lines.length) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        i++;
        continue;
      }
      final code = int.tryParse(line);
      if (code != null) {
        final val = (i + 1 < lines.length) ? lines[i + 1] : '';
        pairs.add(_DxfPair(code, val));
        i += 2;
      } else {
        i++;
      }
    }
    return pairs;
  }

  static void _extractTableFromPairs({
    required List<_DxfPair> pairs,
    required String tableName,
    required Set<String> existingNames,
    required String targetTableHandle,
    required String Function() nextHandleProvider,
    required List<_DxfPair> outPairs,
    String? defaultPlotStyleHandle,
    String? defaultMaterialHandle,
  }) {
    bool inTargetTable = false;
    List<_DxfPair>? currentEntry;

    void processCurrentEntry() {
      if (currentEntry == null || currentEntry!.isEmpty) return;
      String entryName = '';
      for (final p in currentEntry!) {
        if (p.code == 2) {
          entryName = p.value.trim().toUpperCase();
          break;
        }
      }
      if (entryName.isNotEmpty && !existingNames.contains(entryName)) {
        existingNames.add(entryName);
        final newHandle = nextHandleProvider();
        bool saw390 = false;
        bool saw347 = false;
        for (final p in currentEntry!) {
          if (p.code == 5) {
            outPairs.add(_DxfPair(5, newHandle));
          } else if (p.code == 330) {
            outPairs.add(_DxfPair(330, targetTableHandle));
          } else if (p.code == 390) {
            saw390 = true;
            if (defaultPlotStyleHandle != null) {
              outPairs.add(_DxfPair(390, defaultPlotStyleHandle));
            }
          } else if (p.code == 347) {
            saw347 = true;
            if (defaultMaterialHandle != null) {
              outPairs.add(_DxfPair(347, defaultMaterialHandle));
            }
          } else if (p.code == 348) {
            outPairs.add(const _DxfPair(348, '0'));
          } else if (tableName == 'LAYER' && p.code == 62) {
            // Negative color in DXF LAYER table turns layer OFF. Force imported layers to be ON.
            final col = int.tryParse(p.value.trim());
            if (col != null && col < 0) {
              outPairs.add(_DxfPair(62, '${col.abs()}'));
            } else {
              outPairs.add(p);
            }
          } else if (tableName == 'LAYER' && p.code == 70) {
            // Ensure imported layers are thawed (clear bit 0)
            final flags = int.tryParse(p.value.trim()) ?? 0;
            outPairs.add(_DxfPair(70, '${flags & ~1}'));
          } else {
            outPairs.add(p);
          }
        }
        if (tableName == 'LAYER') {
          if (!saw390 && defaultPlotStyleHandle != null) {
            outPairs.add(_DxfPair(390, defaultPlotStyleHandle));
          }
          if (!saw347 && defaultMaterialHandle != null) {
            outPairs.add(_DxfPair(347, defaultMaterialHandle));
            outPairs.add(const _DxfPair(348, '0'));
          }
        }
      }
      currentEntry = null;
    }

    for (int i = 0; i < pairs.length; i++) {
      final p = pairs[i];
      if (p.code == 2 &&
          p.value.trim().toUpperCase() == tableName &&
          i > 0 &&
          pairs[i - 1].code == 0 &&
          pairs[i - 1].value.trim().toUpperCase() == 'TABLE') {
        inTargetTable = true;
      } else if (inTargetTable && p.code == 0 && p.value.trim().toUpperCase() == 'ENDTAB') {
        inTargetTable = false;
        processCurrentEntry();
      } else if (inTargetTable) {
        if (p.code == 0 && p.value.trim().toUpperCase() == tableName) {
          processCurrentEntry();
          currentEntry = [p];
        } else if (currentEntry != null) {
          currentEntry!.add(p);
        }
      }
    }
  }

  static void _extractBlocksFromPairs({
    required List<_DxfPair> pairs,
    required Set<String> existingBlockRecords,
    required String blockRecordTableHandle,
    required String Function() nextHandleProvider,
    required List<_DxfPair> outBlockRecordPairs,
    required List<_DxfPair> outBlockPairs,
  }) {
    bool inBlocks = false;
    List<_DxfPair>? currentBlock;

    void processCurrentBlock() {
      if (currentBlock == null || currentBlock!.isEmpty) return;
      String blockName = '';
      bool sawBegin = false;
      for (final p in currentBlock!) {
        if (p.code == 100 && p.value.trim() == 'AcDbBlockBegin') {
          sawBegin = true;
        } else if (sawBegin && p.code == 2) {
          blockName = p.value.trim().toUpperCase();
          break;
        }
      }
      if (blockName.isEmpty) {
        for (final p in currentBlock!) {
          if (p.code == 2) {
            blockName = p.value.trim().toUpperCase();
            break;
          }
        }
      }

      if (blockName.isNotEmpty &&
          !blockName.startsWith('*MODEL_SPACE') &&
          !blockName.startsWith('*PAPER_SPACE') &&
          !existingBlockRecords.contains(blockName)) {
        existingBlockRecords.add(blockName);
        final brHandle = nextHandleProvider();

        // 1. Add BLOCK_RECORD entry
        outBlockRecordPairs.addAll([
          const _DxfPair(0, 'BLOCK_RECORD'),
          _DxfPair(5, brHandle),
          _DxfPair(330, blockRecordTableHandle),
          const _DxfPair(100, 'AcDbSymbolTableRecord'),
          const _DxfPair(100, 'AcDbBlockTableRecord'),
          _DxfPair(2, blockName),
          const _DxfPair(70, '0'),
          const _DxfPair(280, '1'),
          const _DxfPair(281, '0'),
        ]);

        // 2. Add re-handled BLOCK, child entities, and ENDBLK
        bool skipEmbedded = false;
        for (final p in currentBlock!) {
          if (p.code == 0) {
            skipEmbedded = false;
            outBlockPairs.add(p);
            final h = nextHandleProvider();
            outBlockPairs.add(_DxfPair(5, h));
            outBlockPairs.add(_DxfPair(330, brHandle));
          } else if (skipEmbedded) {
            continue;
          } else if (p.code == 101 && p.value.trim() == 'Embedded Object') {
            skipEmbedded = true;
            continue;
          } else if (p.code == 5 || p.code == 330 || p.code == 390 || p.code == 347 || p.code == 348) {
            continue;
          } else {
            outBlockPairs.add(p);
          }
        }
      }
      currentBlock = null;
    }

    for (int i = 0; i < pairs.length; i++) {
      final p = pairs[i];
      if (p.code == 2 &&
          p.value.trim().toUpperCase() == 'BLOCKS' &&
          i > 0 &&
          pairs[i - 1].code == 0 &&
          pairs[i - 1].value.trim().toUpperCase() == 'SECTION') {
        inBlocks = true;
      } else if (inBlocks && p.code == 0 && p.value.trim().toUpperCase() == 'ENDSEC') {
        inBlocks = false;
        processCurrentBlock();
      } else if (inBlocks) {
        if (p.code == 0 && p.value.trim().toUpperCase() == 'BLOCK') {
          processCurrentBlock();
          currentBlock = [p];
        } else if (currentBlock != null) {
          currentBlock!.add(p);
        }
      }
    }
  }

  static void _extractEntitiesFromPairs({
    required List<_DxfPair> pairs,
    required String modelSpaceHandle,
    required String Function() nextHandleProvider,
    required List<_DxfPair> outPairs,
  }) {
    bool inEntities = false;
    List<_DxfPair>? currentEntity;

    String? currentParentHandle;

    void processCurrentEntity() {
      if (currentEntity == null || currentEntity!.isEmpty) return;
      bool isPaperSpace = false;
      for (final p in currentEntity!) {
        if (p.code == 67 && p.value.trim() == '1') {
          isPaperSpace = true;
          break;
        }
      }
      if (!isPaperSpace) {
        final entType = currentEntity![0].value.trim().toUpperCase();
        final newHandle = nextHandleProvider();

        // Multi-part entities like POLYLINE own their child VERTEX and SEQEND entities.
        // For POLYLINE, the polyline entity itself is owned by ModelSpace.
        // Its child VERTEX and SEQEND entities must have group 330 pointing to the POLYLINE handle.
        String ownerHandle = modelSpaceHandle;
        if (entType == 'POLYLINE') {
          currentParentHandle = newHandle;
        } else if (entType == 'VERTEX' || entType == 'SEQEND') {
          ownerHandle = currentParentHandle ?? modelSpaceHandle;
        } else {
          currentParentHandle = null;
        }

        for (final p in currentEntity!) {
          if (p.code == 101 && p.value.trim() == 'Embedded Object') {
            // Drop Civil 3D ObjectARX proxy/embedded data that causes eWrongDatabase in plain AutoCAD
            break;
          }
          if (p.code == 0) {
            outPairs.add(p);
            outPairs.add(_DxfPair(5, newHandle));
            outPairs.add(_DxfPair(330, ownerHandle));
          } else if (p.code == 5 || p.code == 330 || p.code == 390 || p.code == 347 || p.code == 348) {
            continue;
          } else {
            outPairs.add(p);
          }
        }

        if (entType == 'SEQEND') {
          currentParentHandle = null;
        }
      }
      currentEntity = null;
    }

    for (int i = 0; i < pairs.length; i++) {
      final p = pairs[i];
      if (p.code == 2 &&
          p.value.trim().toUpperCase() == 'ENTITIES' &&
          i > 0 &&
          pairs[i - 1].code == 0 &&
          pairs[i - 1].value.trim().toUpperCase() == 'SECTION') {
        inEntities = true;
      } else if (inEntities && p.code == 0 && p.value.trim().toUpperCase() == 'ENDSEC') {
        inEntities = false;
        processCurrentEntity();
      } else if (inEntities) {
        if (p.code == 0) {
          processCurrentEntity();
          currentEntity = [p];
        } else if (currentEntity != null) {
          currentEntity!.add(p);
        }
      }
    }
  }
}
