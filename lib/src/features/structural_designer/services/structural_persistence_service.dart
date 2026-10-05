import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/structural_element.dart';

/// Service responsible for persisting and exporting BiM structural models
/// associated with CAD/DXF drawings.
class StructuralPersistenceService {
  static const String _prefPrefix = 'koto_bim_v1_';

  /// Generates a standardized document storage key from file path or title.
  static String getDocumentKey(String? filePathOrTitle) {
    if (filePathOrTitle == null || filePathOrTitle.trim().isEmpty) {
      return 'default_document';
    }
    // Clean key of invalid characters
    return filePathOrTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  /// Automatically persists the structural project state associated with [documentKey].
  static Future<bool> saveProject({
    required String documentKey,
    required StructuralProject project,
  }) async {
    try {
      final key = getDocumentKey(documentKey);
      final jsonMap = project.toJson();
      final jsonString = jsonEncode(jsonMap);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefPrefix$key', jsonString);
      return true;
    } catch (e) {
      debugPrint('Error saving structural project: $e');
      return false;
    }
  }

  /// Loads previously saved structural project for [documentKey], or returns null if none exists.
  static Future<StructuralProject?> loadProject({
    required String documentKey,
  }) async {
    try {
      final key = getDocumentKey(documentKey);
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('$_prefPrefix$key');
      if (jsonString == null || jsonString.isEmpty) return null;

      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      return StructuralProject.fromJson(jsonMap);
    } catch (e) {
      debugPrint('Error loading structural project: $e');
      return null;
    }
  }

  /// Exports the structural model as a portable BiM JSON document (.bim.json).
  static Future<File> exportToJsonFile({
    required StructuralProject project,
    required String baseName,
    Directory? outputDirectory,
  }) async {
    final dir = outputDirectory ?? await getTemporaryDirectory();
    final cleanName = baseName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
    final file = File('${dir.path}/${cleanName}_structural_model.bim.json');
    final jsonString = const JsonEncoder.withIndent('  ').convert(project.toJson());
    await file.writeAsString(jsonString);
    return file;
  }

  /// Exports the structural project to standard AutoCAD 2000 ASCII DXF format.
  /// Generates layers:
  /// - S-COL: Reinforced concrete columns
  /// - S-WALL: Reinforced concrete shear walls
  /// - S-BEAM: Reinforced concrete beams
  /// - S-SLAB: Slabs and openings
  /// - S-AXIS: Grid axes and bubbles
  static Future<File> exportToDxfFile({
    required StructuralProject project,
    required String baseName,
    double cadUnitsPerMeter = 1.0,
    Directory? outputDirectory,
  }) async {
    final dir = outputDirectory ?? await getTemporaryDirectory();
    final cleanName = baseName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
    final file = File('${dir.path}/${cleanName}_structural.dxf');

    final sb = StringBuffer();

    // 1. DXF Header
    sb.writeln('0\nSECTION\n2\nHEADER\n9\n\$ACADVER\n1\nAC1015'); // AutoCAD 2000
    sb.writeln('0\nENDSEC');

    // 2. DXF Tables (Layers)
    sb.writeln('0\nSECTION\n2\nTABLES\n0\nTABLE\n2\nLAYER\n70\n5');
    void writeLayer(String name, int color) {
      sb.writeln('0\nLAYER\n2\n$name\n70\n0\n62\n$color\n6\nCONTINUOUS');
    }
    writeLayer('S-COL', 2); // Yellow
    writeLayer('S-WALL', 1); // Red
    writeLayer('S-BEAM', 4); // Cyan
    writeLayer('S-SLAB', 3); // Green
    writeLayer('S-AXIS', 6); // Magenta
    sb.writeln('0\nENDTAB\n0\nENDSEC');

    // 3. DXF Entities
    sb.writeln('0\nSECTION\n2\nENTITIES');

    for (final storey in project.storeys) {
      _writeStoreyEntities(sb, storey, cadUnitsPerMeter, (p) => p);
    }

    sb.writeln('0\nENDSEC\n0\nEOF');

    await file.writeAsString(sb.toString());
    return file;
  }

  /// Exports a single storey level's structural model to DXF, optionally transforming
  /// coordinates back into the storey's original local underlay CAD coordinates.
  static Future<File> exportStoreyToDxfFile({
    required StoreyLevel storey,
    required String baseName,
    Offset? cpRef,
    Offset? cpLocal,
    double unitScale = 1.0,
    double cadUnitsPerMeter = 1.0,
    Directory? outputDirectory,
  }) async {
    final dir = outputDirectory ?? await getTemporaryDirectory();
    final cleanName = baseName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
    final file = File('${dir.path}/${cleanName}_structural_storey.dxf');

    final sb = StringBuffer();

    // 1. DXF Header
    sb.writeln('0\nSECTION\n2\nHEADER\n9\n\$ACADVER\n1\nAC1015'); // AutoCAD 2000
    sb.writeln('0\nENDSEC');

    // 2. DXF Tables (Layers)
    sb.writeln('0\nSECTION\n2\nTABLES\n0\nTABLE\n2\nLAYER\n70\n5');
    void writeLayer(String name, int color) {
      sb.writeln('0\nLAYER\n2\n$name\n70\n0\n62\n$color\n6\nCONTINUOUS');
    }
    writeLayer('S-COL', 2); // Yellow
    writeLayer('S-WALL', 1); // Red
    writeLayer('S-BEAM', 4); // Cyan
    writeLayer('S-SLAB', 3); // Green
    writeLayer('S-AXIS', 6); // Magenta
    sb.writeln('0\nENDTAB\n0\nENDSEC');

    // 3. DXF Entities
    sb.writeln('0\nSECTION\n2\nENTITIES');

    Offset toLocal(Offset p) {
      if (cpRef != null && cpLocal != null && unitScale > 0) {
        return (p - cpRef) / unitScale + cpLocal;
      }
      return p;
    }

    _writeStoreyEntities(sb, storey, cadUnitsPerMeter, toLocal);

    sb.writeln('0\nENDSEC\n0\nEOF');

    await file.writeAsString(sb.toString());
    return file;
  }

  static void _writeStoreyEntities(
    StringBuffer sb,
    StoreyLevel storey,
    double cadUnitsPerMeter,
    Offset Function(Offset) tr,
  ) {
    // Columns
    for (final col in storey.columns) {
      final pts = col.polygonVertices.map(tr).toList();
      if (pts.length >= 3) {
        _writeClosedPolyline(sb, pts, 'S-COL', 2);
        final c = tr(col.center);
        _writeText(sb, col.displayName, c.dx, c.dy, 0.25 * cadUnitsPerMeter, 'S-COL');
      }
    }

    // Shear Walls
    for (final wall in storey.shearWalls) {
      final pts = wall.polygonVertices.map(tr).toList();
      if (pts.length >= 4) {
        _writeClosedPolyline(sb, pts, 'S-WALL', 1);
        final mid = tr((wall.start + wall.end) / 2.0);
        _writeText(sb, wall.displayName, mid.dx, mid.dy, 0.25 * cadUnitsPerMeter, 'S-WALL');
      }
    }

    // Beams
    for (final beam in storey.beams) {
      final pts = beam.polygonVertices.map(tr).toList();
      if (pts.length >= 4) {
        _writeClosedPolyline(sb, pts, 'S-BEAM', 4);
      }
    }

    // Slabs
    for (final slab in storey.slabs) {
      final poly = slab.polygon.map(tr).toList();
      if (poly.length >= 3) {
        _writeClosedPolyline(sb, poly, 'S-SLAB', 3);
        for (final op in slab.openings) {
          final opPts = op.map(tr).toList();
          if (opPts.length >= 3) {
            _writeClosedPolyline(sb, opPts, 'S-SLAB', 3);
          }
        }
        final c = tr(slab.centroid);
        final elev = storey.structuralElevationFor(slab);
        final thickCm = (slab.thickness * 100).round();
        _writeText(sb, 'T.O.C. ${elev >= 0 ? "+" : ""}${elev.toStringAsFixed(2)} (d=${thickCm}cm)', c.dx, c.dy, 0.25 * cadUnitsPerMeter, 'S-SLAB');
      }
    }

    // Grid Axes
    for (final axis in storey.gridAxes) {
      final s = tr(axis.start);
      final e = tr(axis.end);
      sb.writeln('0\nLINE\n8\nS-AXIS\n62\n6');
      sb.writeln('10\n${s.dx}\n20\n${s.dy}\n30\n0.0');
      sb.writeln('11\n${e.dx}\n21\n${e.dy}\n31\n0.0');

      final bubbleRadius = 0.40 * cadUnitsPerMeter;
      if (axis.bubbleAtStart) {
        _writeCircle(sb, s.dx, s.dy, bubbleRadius, 'S-AXIS');
        _writeText(sb, axis.name, s.dx, s.dy, 0.30 * cadUnitsPerMeter, 'S-AXIS');
      }
      if (axis.bubbleAtEnd) {
        _writeCircle(sb, e.dx, e.dy, bubbleRadius, 'S-AXIS');
        _writeText(sb, axis.name, e.dx, e.dy, 0.30 * cadUnitsPerMeter, 'S-AXIS');
      }
    }
  }

  /// Prompts system share dialog for exported file.
  static Future<void> shareFile(File file, {String? subject}) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: subject,
    );
  }

  static void _writeClosedPolyline(StringBuffer sb, List<Offset> pts, String layer, int color) {
    sb.writeln('0\nLWPOLYLINE\n8\n$layer\n62\n$color');
    sb.writeln('90\n${pts.length}\n70\n1'); // 70=1 is closed
    for (final p in pts) {
      sb.writeln('10\n${p.dx}\n20\n${p.dy}');
    }
  }

  static void _writeText(StringBuffer sb, String text, double x, double y, double height, String layer) {
    sb.writeln('0\nTEXT\n8\n$layer\n62\n7');
    sb.writeln('10\n$x\n20\n$y\n30\n0.0');
    sb.writeln('40\n$height\n1\n$text\n72\n1\n73\n2'); // Centered
    sb.writeln('11\n$x\n21\n$y\n31\n0.0');
  }

  static void _writeCircle(StringBuffer sb, double cx, double cy, double radius, String layer) {
    sb.writeln('0\nCIRCLE\n8\n$layer\n62\n6');
    sb.writeln('10\n$cx\n20\n$cy\n30\n0.0\n40\n$radius');
  }
}
