import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:archive/archive.dart';
import '../models/pcb_models.dart';
import 'gerber_parser.dart';
import 'drill_parser.dart';

/// High-performance parser for multi-layer PCB archives (.ZIP) from Proteus ARES, Altium, KiCad, Eagle, and EasyEDA.
class PcbArchiveParser {
  const PcbArchiveParser._();

  /// Quick heuristic to check if a ZIP archive contains PCB Gerber, Drill, or KiCad files.
  static bool isPcbZip(Uint8List bytes, {String fileName = ''}) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: false);
      for (final file in archive) {
        if (!file.isFile) continue;
        final name = file.name.toLowerCase();
        if (name.startsWith('__macosx') || name.startsWith('.')) continue;

        if (_isPcbFileExtension(name)) {
          return true;
        }

        // Check content header for Gerber/Drill signatures if size is reasonable
        if (file.size > 10 && file.size < 5000000) {
          final sampleBytes = file.content is List<int>
              ? Uint8List.fromList((file.content as List<int>).take(500).toList())
              : Uint8List(0);
          if (sampleBytes.isNotEmpty) {
            final sampleStr = String.fromCharCodes(sampleBytes);
            if (sampleStr.contains('%FS') ||
                sampleStr.contains('%MO') ||
                sampleStr.contains('G04') ||
                sampleStr.contains('M48') ||
                sampleStr.contains('INCH,') ||
                sampleStr.contains('METRIC,')) {
              return true;
            }
          }
        }
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  /// Parses a complete PCB project ZIP archive into a unified [PcbProject].
  static PcbProject parseZip(
    Uint8List bytes, {
    required String archiveName,
    required String filePath,
  }) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    final List<PcbLayerItem> layers = [];
    final List<PcbBomEntry> bomEntries = [];

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;

    void updateGlobalBounds(PcbBoundingBox b) {
      if (b.minX < minX) minX = b.minX;
      if (b.maxX > maxX) maxX = b.maxX;
      if (b.minY < minY) minY = b.minY;
      if (b.maxY > maxY) maxY = b.maxY;
    }

    for (final file in archive) {
      if (!file.isFile) continue;
      final rawName = file.name.replaceAll('\\', '/');
      final baseName = rawName.split('/').last;
      final lower = baseName.toLowerCase();

      // Skip OS metadata
      if (lower.startsWith('__macosx') || lower.startsWith('.') || lower.endsWith('.ds_store')) {
        continue;
      }

      final fileBytes = file.content is List<int>
          ? Uint8List.fromList(file.content as List<int>)
          : Uint8List(0);
      if (fileBytes.isEmpty) continue;

      // 1. Bill of Materials (BOM) & Pick and Place
      if (lower.contains('bom') ||
          lower.contains('bill of material') ||
          lower.contains('parts') ||
          lower.endsWith('.bom') ||
          (lower.endsWith('.csv') && !lower.contains('gerber'))) {
        final parsedBom = _parseBom(fileBytes, baseName);
        if (parsedBom.isNotEmpty) {
          bomEntries.addAll(parsedBom);
        }
        continue;
      }

      // 2. CNC Drill Files (Excellon / NC Drill)
      if (_isDrillFileName(lower) || _isDrillContent(fileBytes)) {
        try {
          final doc = DrillParser.parse(fileBytes, fileName: baseName);
          if (doc.drillHoles.isNotEmpty) {
            updateGlobalBounds(doc.boundingBox);
            layers.add(
              PcbLayerItem(
                fileName: baseName,
                type: PcbLayerType.drill,
                document: doc,
                order: 90,
              ),
            );
          }
        } catch (_) {}
        continue;
      }

      // 3. Gerber RS-274X Layers (Copper, Mask, Silk, Outline)
      if (_isGerberFileName(lower) || _isGerberContent(fileBytes)) {
        try {
          final doc = GerberParser.parse(fileBytes, fileName: baseName);
          if (doc.commands.isNotEmpty || doc.drillHoles.isNotEmpty) {
            updateGlobalBounds(doc.boundingBox);
            final order = _getLayerZOrder(doc.layerType);
            layers.add(
              PcbLayerItem(
                fileName: baseName,
                type: doc.layerType,
                document: doc,
                order: order,
              ),
            );
          }
        } catch (_) {}
        continue;
      }
    }

    // Sort layers by physical stacking Z-order (outline on top, then drills, silk, mask, copper, substrate)
    layers.sort((a, b) => a.order.compareTo(b.order));

    final hasValidBounds = minX.isFinite && minY.isFinite && maxX.isFinite && maxY.isFinite && (maxX > minX || maxY > minY);
    final globalBoundingBox = hasValidBounds
        ? PcbBoundingBox(minX: minX, minY: minY, maxX: maxX, maxY: maxY)
        : PcbBoundingBox.defaultBox;

    final projectName = archiveName.endsWith('.zip')
        ? archiveName.substring(0, archiveName.length - 4)
        : archiveName;

    return PcbProject(
      projectName: projectName,
      sourcePath: filePath,
      layers: layers,
      bomEntries: bomEntries,
      boundingBox: globalBoundingBox,
      viewSide: PcbViewSide.top,
    );
  }

  static bool _isPcbFileExtension(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.gbr') ||
        lower.endsWith('.ger') ||
        lower.endsWith('.gtl') ||
        lower.endsWith('.gbl') ||
        lower.endsWith('.gts') ||
        lower.endsWith('.gbs') ||
        lower.endsWith('.gto') ||
        lower.endsWith('.gbo') ||
        lower.endsWith('.gko') ||
        lower.endsWith('.gm1') ||
        lower.endsWith('.gm2') ||
        lower.endsWith('.gm3') ||
        lower.endsWith('.top') ||
        lower.endsWith('.bot') ||
        lower.endsWith('.smt') ||
        lower.endsWith('.smb') ||
        lower.endsWith('.sst') ||
        lower.endsWith('.ssb') ||
        lower.endsWith('.edge') ||
        lower.endsWith('.drl') ||
        lower.endsWith('.xln') ||
        lower.endsWith('.exc') ||
        lower.endsWith('.drd') ||
        lower.endsWith('.kicad_pcb') ||
        lower.endsWith('.kicad_sch') ||
        lower.endsWith('.kicad_sym') ||
        lower.endsWith('.sch') ||
        lower.endsWith('.brd');
  }

  static bool _isDrillFileName(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.drl') ||
        lower.endsWith('.xln') ||
        lower.endsWith('.exc') ||
        lower.endsWith('.drd') ||
        lower.contains('drill') ||
        lower.contains('plated') ||
        lower.contains('through hole') ||
        lower.contains('pth') ||
        lower.contains('npth');
  }

  static bool _isDrillContent(Uint8List bytes) {
    if (bytes.length < 5) return false;
    final sample = String.fromCharCodes(bytes.take(math.min(bytes.length, 300)));
    return sample.contains('M48') ||
        sample.contains('INCH,') ||
        sample.contains('METRIC,') ||
        (sample.contains('T01') && sample.contains('X'));
  }

  static bool _isGerberFileName(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.gbr') ||
        lower.endsWith('.ger') ||
        lower.endsWith('.gtl') ||
        lower.endsWith('.gbl') ||
        lower.endsWith('.gts') ||
        lower.endsWith('.gbs') ||
        lower.endsWith('.gto') ||
        lower.endsWith('.gbo') ||
        lower.endsWith('.gko') ||
        lower.endsWith('.gm1') ||
        lower.endsWith('.gm2') ||
        lower.endsWith('.gm3') ||
        lower.endsWith('.top') ||
        lower.endsWith('.bot') ||
        lower.endsWith('.smt') ||
        lower.endsWith('.smb') ||
        lower.endsWith('.sst') ||
        lower.endsWith('.ssb') ||
        lower.endsWith('.edge') ||
        lower.endsWith('.art') ||
        lower.endsWith('.pho') ||
        lower.endsWith('.cmp') ||
        lower.endsWith('.sol');
  }

  static bool _isGerberContent(Uint8List bytes) {
    if (bytes.length < 10) return false;
    final sample = String.fromCharCodes(bytes.take(math.min(bytes.length, 400)));
    return sample.contains('%FS') ||
        sample.contains('%MO') ||
        sample.contains('G04') ||
        sample.contains('D10*') ||
        sample.contains('D01*');
  }

  static int _getLayerZOrder(PcbLayerType type) {
    switch (type) {
      case PcbLayerType.copperBottom:
        return 20;
      case PcbLayerType.solderMaskBottom:
        return 30;
      case PcbLayerType.silkscreenBottom:
        return 40;
      case PcbLayerType.copperTop:
        return 50;
      case PcbLayerType.solderMaskTop:
        return 60;
      case PcbLayerType.silkscreenTop:
        return 70;
      case PcbLayerType.drill:
        return 80;
      case PcbLayerType.edgeCuts:
        return 90;
      case PcbLayerType.generic:
        return 55;
    }
  }

  /// Parses CSV or text Bill of Materials (BOM).
  static List<PcbBomEntry> _parseBom(Uint8List bytes, String fileName) {
    final List<PcbBomEntry> entries = [];
    String text;
    try {
      text = utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      text = latin1.decode(bytes);
    }

    final lines = LineSplitter.split(text).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return entries;

    int designatorCol = -1;
    int valueCol = -1;
    int footprintCol = -1;
    int descCol = -1;
    int qtyCol = -1;
    int partCol = -1;

    // Detect delimiter: comma, semicolon, or tab
    String delimiter = ',';
    if (lines.first.contains(';')) {
      delimiter = ';';
    } else if (lines.first.contains('\t')) {
      delimiter = '\t';
    }

    int headerLineIdx = -1;
    for (int i = 0; i < math.min(lines.length, 10); i++) {
      final cols = _splitCsvLine(lines[i], delimiter).map((c) => c.toLowerCase()).toList();
      for (int c = 0; c < cols.length; c++) {
        final col = cols[c];
        if (col.contains('designator') || col.contains('ref') || col.contains('item') || col == 'id') {
          designatorCol = c;
        } else if (col.contains('val') || col.contains('value') || col.contains('device')) {
          valueCol = c;
        } else if (col.contains('footprint') || col.contains('package') || col.contains('pattern')) {
          footprintCol = c;
        } else if (col.contains('desc') || col.contains('comment') || col.contains('name')) {
          descCol = c;
        } else if (col.contains('qty') || col.contains('quantity') || col.contains('count')) {
          qtyCol = c;
        } else if (col.contains('part') || col.contains('mpn') || col.contains('mfr')) {
          partCol = c;
        }
      }
      if (designatorCol != -1 || valueCol != -1) {
        headerLineIdx = i;
        break;
      }
    }

    final startIdx = headerLineIdx != -1 ? headerLineIdx + 1 : 0;
    for (int i = startIdx; i < lines.length; i++) {
      final cols = _splitCsvLine(lines[i], delimiter);
      if (cols.isEmpty) continue;

      String des = designatorCol != -1 && designatorCol < cols.length ? cols[designatorCol] : '';
      String val = valueCol != -1 && valueCol < cols.length ? cols[valueCol] : '';
      String fp = footprintCol != -1 && footprintCol < cols.length ? cols[footprintCol] : '';
      String desc = descCol != -1 && descCol < cols.length ? cols[descCol] : '';
      String part = partCol != -1 && partCol < cols.length ? cols[partCol] : '';
      int qty = 1;
      if (qtyCol != -1 && qtyCol < cols.length) {
        qty = int.tryParse(cols[qtyCol].replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
      }

      if (des.isEmpty && cols.isNotEmpty) {
        des = cols[0];
      }
      if (val.isEmpty && cols.length > 1) {
        val = cols[1];
      }

      if (des.isNotEmpty || val.isNotEmpty) {
        entries.add(
          PcbBomEntry(
            designator: des,
            value: val,
            footprint: fp,
            description: desc,
            quantity: qty > 0 ? qty : 1,
            partNumber: part.isNotEmpty ? part : null,
          ),
        );
      }
    }

    return entries;
  }

  static List<String> _splitCsvLine(String line, String delimiter) {
    final List<String> result = [];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == delimiter && !inQuotes) {
        result.add(buffer.toString().trim().replaceAll('"', ''));
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    result.add(buffer.toString().trim().replaceAll('"', ''));
    return result;
  }
}
