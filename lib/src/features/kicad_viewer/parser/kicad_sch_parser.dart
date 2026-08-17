import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../pcb_viewer/models/pcb_models.dart';
import 's_expression_parser.dart';

/// Converts KiCad Schematic (.kicad_sch) into a [PcbDocument].
class KicadSchParser {
  /// Parses raw bytes of a .kicad_sch file.
  static PcbDocument parse(Uint8List bytes, {String fileName = 'schematic.kicad_sch'}) {
    final text = _decodeText(bytes);
    return parseText(text, fileName: fileName);
  }

  static String _decodeText(Uint8List bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return latin1.decode(bytes);
    }
  }

  static PcbDocument parseText(String text, {String fileName = 'schematic.kicad_sch'}) {
    final root = SExpressionParser.parse(text);

    final List<PcbCommand> commands = [];
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;

    void updateBounds(Offset p, [double padding = 0]) {
      if (p.dx - padding < minX) minX = p.dx - padding;
      if (p.dx + padding > maxX) maxX = p.dx + padding;
      if (p.dy - padding < minY) minY = p.dy - padding;
      if (p.dy + padding > maxY) maxY = p.dy + padding;
    }

    // 1. Parse Wires
    for (final wire in root.findAllChildren('wire')) {
      final ptsNode = wire.findChild('pts');
      if (ptsNode != null) {
        final xyNodes = ptsNode.findAllChildren('xy');
        if (xyNodes.length >= 2) {
          final x1 = xyNodes[0].getDouble(0) ?? 0.0;
          final y1 = xyNodes[0].getDouble(1) ?? 0.0;
          final x2 = xyNodes[1].getDouble(0) ?? 0.0;
          final y2 = xyNodes[1].getDouble(1) ?? 0.0;

          final p1 = Offset(x1, y1);
          final p2 = Offset(x2, y2);
          updateBounds(p1, 0.2);
          updateBounds(p2, 0.2);

          commands.add(
            PcbCommand.line(
              p1: p1,
              p2: p2,
              aperture: const PcbAperture(id: 0, type: PcbApertureType.circle, dimX: 0.25),
            ),
          );
        }
      }
    }

    // 2. Parse Junctions
    for (final junc in root.findAllChildren('junction')) {
      final atNode = junc.findChild('at');
      if (atNode != null) {
        final x = atNode.getDouble(0) ?? 0.0;
        final y = atNode.getDouble(1) ?? 0.0;
        final pos = Offset(x, y);
        updateBounds(pos, 0.5);

        commands.add(
          PcbCommand.flash(
            p1: pos,
            aperture: const PcbAperture(id: 0, type: PcbApertureType.circle, dimX: 0.9),
          ),
        );
      }
    }

    // 3. Parse Symbols (Components)
    for (final sym in root.findAllChildren('symbol')) {
      final atNode = sym.findChild('at');
      if (atNode != null) {
        final x = atNode.getDouble(0) ?? 0.0;
        final y = atNode.getDouble(1) ?? 0.0;
        final pos = Offset(x, y);
        updateBounds(pos, 5.0);

        // Flash a bounding indicator for the symbol
        commands.add(
          PcbCommand.flash(
            p1: pos,
            aperture: const PcbAperture(id: 0, type: PcbApertureType.rectangle, dimX: 4.0, dimY: 2.5),
          ),
        );
      }
    }

    // 4. Parse Busses and Labels
    for (final bus in root.findAllChildren('bus')) {
      final ptsNode = bus.findChild('pts');
      if (ptsNode != null) {
        final xyNodes = ptsNode.findAllChildren('xy');
        if (xyNodes.length >= 2) {
          final x1 = xyNodes[0].getDouble(0) ?? 0.0;
          final y1 = xyNodes[0].getDouble(1) ?? 0.0;
          final x2 = xyNodes[1].getDouble(0) ?? 0.0;
          final y2 = xyNodes[1].getDouble(1) ?? 0.0;

          final p1 = Offset(x1, y1);
          final p2 = Offset(x2, y2);
          updateBounds(p1, 0.5);
          updateBounds(p2, 0.5);

          commands.add(
            PcbCommand.line(
              p1: p1,
              p2: p2,
              aperture: const PcbAperture(id: 0, type: PcbApertureType.circle, dimX: 0.5),
            ),
          );
        }
      }
    }

    final hasValidBounds = minX.isFinite && minY.isFinite && maxX.isFinite && maxY.isFinite && (maxX > minX || maxY > minY);
    final boundingBox = hasValidBounds
        ? PcbBoundingBox(minX: minX, minY: minY, maxX: maxX, maxY: maxY)
        : PcbBoundingBox.defaultBox;

    return PcbDocument(
      fileName: fileName,
      layerType: PcbLayerType.generic,
      commands: commands,
      drillHoles: const [],
      boundingBox: boundingBox,
    );
  }
}
