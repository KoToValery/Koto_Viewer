import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:archive/archive.dart';
import '../../kicad_viewer/parser/kicad_pcb_parser.dart';
import '../models/pcb_models.dart';
import '../services/pcb_pad_numbering_service.dart';
import 'gerber_parser.dart';
import 'drill_parser.dart';

/// High-performance parser for multi-layer PCB archives (.ZIP) from Proteus ARES, Altium, KiCad, Eagle, and EasyEDA.
class PcbArchiveParser {
  const PcbArchiveParser._();

  /// Quick heuristic to check if a byte stream is a valid ZIP archive.
  static bool isPcbZip(Uint8List bytes, {String fileName = ''}) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: false);
      return archive.isNotEmpty;
    } on ArchiveException catch (_) {
      return false;
    } on FormatException catch (_) {
      return false;
    }
  }

  /// Parses a complete PCB project or multi-file ZIP archive into a unified [PcbProject].
  static PcbProject parseZip(
    Uint8List bytes, {
    required String archiveName,
    required String filePath,
  }) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    final List<PcbLayerItem> layers = [];
    final List<PcbBomEntry> bomEntries = [];
    final List<PcbImageItem> images = [];
    final List<PcbArchiveFileItem> archiveFiles = [];
    final List<PcbArchiveFileItem> model3DFiles = [];
    final List<PcbArchiveFileItem> schematicFiles = [];
    final List<PcbArchiveFileItem> documentFiles = [];
    final List<PcbArchiveFileItem> reportFiles = [];
    final List<PcbArchiveFileItem> assemblyFiles = [];
    final List<PcbArchiveFileItem> sourceCadFiles = [];

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

      final category = classifyFile(rawName, fileBytes);
      final archiveItem = PcbArchiveFileItem(
        fileName: rawName,
        sizeInBytes: fileBytes.length,
        bytes: fileBytes,
        category: category,
      );
      archiveFiles.add(archiveItem);

      switch (category) {
        case PcbFileCategory.image:
          images.add(PcbImageItem(fileName: baseName, bytes: fileBytes));
          break;

        case PcbFileCategory.model3D:
          model3DFiles.add(archiveItem);
          break;

        case PcbFileCategory.schematic:
          schematicFiles.add(archiveItem);
          break;

        case PcbFileCategory.bom:
          final parsedBom = parseBom(fileBytes, baseName);
          if (parsedBom.isNotEmpty) {
            bomEntries.addAll(parsedBom);
          }
          break;

        case PcbFileCategory.assembly:
          assemblyFiles.add(archiveItem);
          break;

        case PcbFileCategory.document:
          documentFiles.add(archiveItem);
          break;

        case PcbFileCategory.sourceCad:
          sourceCadFiles.add(archiveItem);
          break;

        case PcbFileCategory.report:
          reportFiles.add(archiveItem);
          break;

        case PcbFileCategory.gerber2D:
          if (!lower.endsWith('.gbrjob')) {
            try {
              final doc = GerberParser.parse(fileBytes, fileName: baseName);
              if (doc.commands.isNotEmpty || doc.drillHoles.isNotEmpty) {
                updateGlobalBounds(doc.boundingBox);
                final order = _getLayerZOrder(doc.layerType);
                final isAuxiliaryLayer = lower.contains('assembly') ||
                    lower.contains('assy') ||
                    lower.contains('paste') ||
                    lower.contains('pos') ||
                    lower.contains('placement') ||
                    lower.contains('centroid') ||
                    lower.contains('mask') ||
                    lower.contains('soldermask');
                layers.add(
                  PcbLayerItem(
                    fileName: baseName,
                    type: doc.layerType,
                    document: doc,
                    order: order,
                    isVisible: !isAuxiliaryLayer,
                  ),
                );
              }
            } catch (_) {}
          }
          break;

        case PcbFileCategory.drill:
          try {
            final doc = DrillParser.parse(fileBytes, fileName: baseName);
            if (doc.drillHoles.isNotEmpty) {
              updateGlobalBounds(doc.boundingBox);
              layers.add(
                PcbLayerItem(
                  fileName: baseName,
                  type: PcbLayerType.drill,
                  document: doc,
                  order: 80,
                ),
              );
            }
          } catch (_) {}
          break;

        case PcbFileCategory.other:
          break;
      }
    }

    // Fallback: If no Gerber layers found, check if a KiCad PCB file is present
    if (layers.isEmpty) {
      final kicadPcb = sourceCadFiles.where((f) => f.fileName.toLowerCase().endsWith('.kicad_pcb')).firstOrNull;
      if (kicadPcb != null) {
        try {
          final doc = KicadPcbParser.parse(kicadPcb.bytes, fileName: kicadPcb.fileName.split('/').last);
          if (doc.commands.isNotEmpty || doc.drillHoles.isNotEmpty) {
            updateGlobalBounds(doc.boundingBox);
            layers.add(
              PcbLayerItem(
                fileName: kicadPcb.fileName.split('/').last,
                type: doc.layerType,
                document: doc,
                order: 50,
              ),
            );
          }
        } catch (_) {}
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

    final project = PcbProject(
      projectName: projectName,
      sourcePath: filePath,
      layers: layers,
      bomEntries: bomEntries,
      images: images,
      archiveFiles: archiveFiles,
      model3DFiles: model3DFiles,
      schematicFiles: schematicFiles,
      documentFiles: documentFiles,
      reportFiles: reportFiles,
      assemblyFiles: assemblyFiles,
      sourceCadFiles: sourceCadFiles,
      boundingBox: globalBoundingBox,
      viewSide: PcbViewSide.top,
    );

    return PcbPadNumberingService.assignPadNumbers(project);
  }

  /// Classifies an archive file into its logical [PcbFileCategory] based on path, extension, and content.
  static PcbFileCategory classifyFile(String fullPath, [Uint8List? bytes]) {
    final cleanPath = fullPath.replaceAll('\\', '/').toLowerCase();
    final fileName = cleanPath.split('/').last;

    // Skip OS metadata
    if (fileName.startsWith('__macosx') || fileName.startsWith('.') || fileName.endsWith('.ds_store')) {
      return PcbFileCategory.other;
    }

    // 1. Images
    if (_isImageFileName(fileName)) {
      return PcbFileCategory.image;
    }

    // 2. 3D Models
    if (_is3DModelFileName(fileName)) {
      return PcbFileCategory.model3D;
    }

    // 3. Schematics (KiCad schematic, Eagle schematic, or PDF/SVG schematic)
    if (_isSchematicFileName(fileName, cleanPath)) {
      return PcbFileCategory.schematic;
    }

    // 4. Drill files
    if (_isDrillFileName(fileName) || (bytes != null && _isDrillContent(bytes))) {
      return PcbFileCategory.drill;
    }

    // 5. Gerber files
    if (_isGerberFileName(fileName) ||
        fileName.endsWith('.gbrjob') ||
        (bytes != null && _isGerberContent(bytes))) {
      return PcbFileCategory.gerber2D;
    }

    // 6. Assembly / Pick and Place (CPL / Centroid / Position / Netlist)
    if (cleanPath.contains('assembly') ||
        cleanPath.contains('assy') ||
        cleanPath.contains('cpl') ||
        cleanPath.contains('pos') ||
        cleanPath.contains('pick') ||
        cleanPath.contains('placement') ||
        cleanPath.contains('centroid') ||
        fileName.endsWith('.d356') ||
        fileName.endsWith('.ipc')) {
      return PcbFileCategory.assembly;
    }

    // 7. BOM (Bill of Materials)
    if (cleanPath.contains('bom') ||
        cleanPath.contains('bill of material') ||
        cleanPath.contains('bill_of_material') ||
        cleanPath.contains('parts_list') ||
        fileName.endsWith('.bom')) {
      return PcbFileCategory.bom;
    }

    // Generic CSV/Excel tables default to BOM if not categorized above
    if (fileName.endsWith('.csv') ||
        fileName.endsWith('.xlsx') ||
        fileName.endsWith('.xls') ||
        fileName.endsWith('.tsv')) {
      return PcbFileCategory.bom;
    }

    // 8. Documentation (PDFs, SVGs)
    if (fileName.endsWith('.pdf') || fileName.endsWith('.svg')) {
      return PcbFileCategory.document;
    }

    // 9. Source CAD Project
    if (fileName.endsWith('.kicad_pcb') ||
        fileName.endsWith('.kicad_pro') ||
        fileName.endsWith('.kicad_prl') ||
        fileName.endsWith('.kicad_sym') ||
        fileName.endsWith('.kicad_mod') ||
        fileName.endsWith('.kicad_dru') ||
        fileName.endsWith('.brd') ||
        fileName.endsWith('.pcbdoc') ||
        fileName.endsWith('.prjpcb')) {
      return PcbFileCategory.sourceCad;
    }

    // 10. Reports & text notes
    if (fileName.endsWith('.rpt') ||
        fileName.endsWith('.drc') ||
        fileName.endsWith('.log') ||
        fileName.endsWith('.txt') ||
        fileName.endsWith('.md') ||
        fileName.endsWith('.htm') ||
        fileName.endsWith('.html') ||
        fileName.endsWith('.xml') ||
        cleanPath.contains('readme')) {
      return PcbFileCategory.report;
    }

    return PcbFileCategory.other;
  }

  static bool _is3DModelFileName(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.step') ||
        lower.endsWith('.stp') ||
        lower.endsWith('.p21') ||
        lower.endsWith('.stl') ||
        lower.endsWith('.obj') ||
        lower.endsWith('.gltf') ||
        lower.endsWith('.glb') ||
        lower.endsWith('.3mf') ||
        lower.endsWith('.iges') ||
        lower.endsWith('.igs') ||
        lower.endsWith('.wrl') ||
        lower.endsWith('.vrml');
  }

  static bool _isSchematicFileName(String name, String fullPath) {
    final lower = name.toLowerCase();
    final lowerPath = fullPath.toLowerCase();
    if (lower.endsWith('.kicad_sch') || lower.endsWith('.sch') || lower.endsWith('.schdoc')) {
      return true;
    }
    if (lower.endsWith('.pdf') || lower.endsWith('.svg')) {
      return lowerPath.contains('schematic') ||
          lowerPath.contains('sch_') ||
          lowerPath.contains('-sch') ||
          lowerPath.contains('diagram') ||
          lowerPath.contains('circuit');
    }
    return false;
  }

  static bool _isImageFileName(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.gif');
  }


  static bool _isDrillFileName(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.drl') ||
        lower.endsWith('.xln') ||
        lower.endsWith('.exc') ||
        lower.endsWith('.drd');
  }

  static bool _isDrillContent(Uint8List bytes) {
    if (bytes.length < 5) return false;
    final sample = String.fromCharCodes(bytes.take(math.min(bytes.length, 300)));
    return sample.contains('M48') ||
        sample.contains('INCH,') ||
        sample.contains('METRIC,') ||
        (sample.contains('T01') && sample.contains('X') && !sample.contains('%FS') && !sample.contains('G04'));
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
    final sample = String.fromCharCodes(bytes.take(math.min(bytes.length, 500)));
    return sample.contains('%FS') ||
        sample.contains('%MO') ||
        sample.contains('%TF') ||
        sample.contains('G04') ||
        sample.contains('D10*') ||
        sample.contains('D01*') ||
        sample.contains('M02*');
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
  static List<PcbBomEntry> parseBom(Uint8List bytes, String fileName) {
    final List<PcbBomEntry> entries = [];
    String text;
    try {
      text = utf8.decode(bytes, allowMalformed: true);
    } on FormatException catch (_) {
      // Fall back to Latin-1 decoding if UTF-8 fails
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
