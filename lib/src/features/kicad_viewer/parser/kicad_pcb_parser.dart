import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../pcb_viewer/models/pcb_models.dart';
import 's_expression_parser.dart';

/// Converts KiCad PCB (.kicad_pcb) into a standard [PcbDocument].
class KicadPcbParser {
  /// Parses raw bytes of a .kicad_pcb file.
  static PcbDocument parse(Uint8List bytes, {String fileName = 'board.kicad_pcb'}) {
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

  static PcbDocument parseText(String text, {String fileName = 'board.kicad_pcb'}) {
    final root = SExpressionParser.parse(text);

    final List<PcbCommand> commands = [];
    final List<PcbDrillHole> drillHoles = [];

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

    // 1. Parse Segments (Tracks)
    for (final seg in root.findAllChildren('segment')) {
      final startNode = seg.findChild('start');
      final endNode = seg.findChild('end');
      final widthNode = seg.findChild('width');

      if (startNode != null && endNode != null) {
        final x1 = startNode.getDouble(0) ?? 0.0;
        final y1 = startNode.getDouble(1) ?? 0.0;
        final x2 = endNode.getDouble(0) ?? 0.0;
        final y2 = endNode.getDouble(1) ?? 0.0;
        final width = widthNode?.getDouble(0) ?? 0.25;

        final p1 = Offset(x1, y1);
        final p2 = Offset(x2, y2);

        updateBounds(p1, width / 2.0);
        updateBounds(p2, width / 2.0);

        commands.add(
          PcbCommand.line(
            p1: p1,
            p2: p2,
            aperture: PcbAperture(
              id: 0,
              type: PcbApertureType.circle,
              dimX: width,
            ),
          ),
        );
      }
    }

    // 2. Parse Arcs
    for (final arc in root.findAllChildren('arc')) {
      final startNode = arc.findChild('start');
      final midNode = arc.findChild('mid');
      final endNode = arc.findChild('end');
      final widthNode = arc.findChild('width');

      if (startNode != null && endNode != null) {
        final x1 = startNode.getDouble(0) ?? 0.0;
        final y1 = startNode.getDouble(1) ?? 0.0;
        final x2 = endNode.getDouble(0) ?? 0.0;
        final y2 = endNode.getDouble(1) ?? 0.0;
        final width = widthNode?.getDouble(0) ?? 0.25;

        final p1 = Offset(x1, y1);
        final p2 = Offset(x2, y2);
        updateBounds(p1, width / 2.0);
        updateBounds(p2, width / 2.0);

        // Approximate arc with center calculation or line
        final center = Offset((x1 + x2) / 2.0, (y1 + y2) / 2.0);
        final radius = (p2 - p1).distance / 2.0;

        commands.add(
          PcbCommand.arc(
            p1: p1,
            p2: p2,
            center: center,
            radius: radius,
            startAngle: 0.0,
            endAngle: math.pi,
            aperture: PcbAperture(id: 0, type: PcbApertureType.circle, dimX: width),
          ),
        );
      }
    }

    // 3. Parse Vias
    for (final via in root.findAllChildren('via')) {
      final atNode = via.findChild('at');
      final sizeNode = via.findChild('size');
      final drillNode = via.findChild('drill');

      if (atNode != null) {
        final x = atNode.getDouble(0) ?? 0.0;
        final y = atNode.getDouble(1) ?? 0.0;
        final size = sizeNode?.getDouble(0) ?? 0.8;
        final drill = drillNode?.getDouble(0) ?? 0.4;

        final pos = Offset(x, y);
        updateBounds(pos, size / 2.0);

        // Pad flash
        commands.add(
          PcbCommand.flash(
            p1: pos,
            aperture: PcbAperture(id: 0, type: PcbApertureType.circle, dimX: size),
          ),
        );

        // Drill hole
        drillHoles.add(
          PcbDrillHole(position: pos, diameterMm: drill, toolId: 1),
        );
      }
    }

    // 4. Parse Footprints (SMD & THT Pads)
    for (final fp in root.findAllChildren('footprint')) {
      final atNode = fp.findChild('at');
      final fpX = atNode?.getDouble(0) ?? 0.0;
      final fpY = atNode?.getDouble(1) ?? 0.0;
      final fpRot = (atNode?.getDouble(2) ?? 0.0) * math.pi / 180.0;

      for (final pad in fp.findAllChildren('pad')) {
        final padAt = pad.findChild('at');
        final padSize = pad.findChild('size');
        final padDrill = pad.findChild('drill');

        final relX = padAt?.getDouble(0) ?? 0.0;
        final relY = padAt?.getDouble(1) ?? 0.0;

        // Apply footprint rotation
        final worldX = fpX + relX * math.cos(fpRot) - relY * math.sin(fpRot);
        final worldY = fpY + relX * math.sin(fpRot) + relY * math.cos(fpRot);
        final padPos = Offset(worldX, worldY);

        final sizeW = padSize?.getDouble(0) ?? 1.2;
        final sizeH = padSize?.getDouble(1) ?? sizeW;

        updateBounds(padPos, math.max(sizeW, sizeH) / 2.0);

        // Pad shape
        PcbApertureType shape = PcbApertureType.rectangle;
        final typeStr = pad.values.isNotEmpty ? pad.values.first.toLowerCase() : '';
        if (typeStr.contains('circle') || pad.values.contains('circle')) {
          shape = PcbApertureType.circle;
        } else if (typeStr.contains('roundrect') || pad.values.contains('roundrect')) {
          shape = PcbApertureType.obround;
        }

        commands.add(
          PcbCommand.flash(
            p1: padPos,
            aperture: PcbAperture(
              id: 0,
              type: shape,
              dimX: sizeW,
              dimY: sizeH,
            ),
          ),
        );

        // If through-hole, add drill hole
        if (padDrill != null) {
          final drillDiam = padDrill.getDouble(0) ?? 0.8;
          drillHoles.add(
            PcbDrillHole(position: padPos, diameterMm: drillDiam, toolId: 2),
          );
        }
      }
    }

    // 5. Parse Graphic Lines (Edge.Cuts, Silkscreen, etc.)
    for (final grLine in root.findAllChildren('gr_line')) {
      final startNode = grLine.findChild('start');
      final endNode = grLine.findChild('end');
      final widthNode = grLine.findChild('width');

      if (startNode != null && endNode != null) {
        final x1 = startNode.getDouble(0) ?? 0.0;
        final y1 = startNode.getDouble(1) ?? 0.0;
        final x2 = endNode.getDouble(0) ?? 0.0;
        final y2 = endNode.getDouble(1) ?? 0.0;
        final width = widthNode?.getDouble(0) ?? 0.15;

        final p1 = Offset(x1, y1);
        final p2 = Offset(x2, y2);
        updateBounds(p1, width / 2.0);
        updateBounds(p2, width / 2.0);

        commands.add(
          PcbCommand.line(
            p1: p1,
            p2: p2,
            aperture: PcbAperture(id: 0, type: PcbApertureType.circle, dimX: width),
          ),
        );
      }
    }

    // 6. Parse Zones (Copper Pours)
    for (final zone in root.findAllChildren('zone')) {
      final poly = zone.findChild('polygon');
      final ptsNode = poly?.findChild('pts');

      if (ptsNode != null) {
        final List<Offset> regionPoints = [];
        for (final xy in ptsNode.findAllChildren('xy')) {
          final x = xy.getDouble(0);
          final y = xy.getDouble(1);
          if (x != null && y != null) {
            final pt = Offset(x, y);
            regionPoints.add(pt);
            updateBounds(pt);
          }
        }
        if (regionPoints.length >= 3) {
          commands.add(PcbCommand.region(regionPoints: regionPoints));
        }
      }
    }

    final hasValidBounds = minX.isFinite && minY.isFinite && maxX.isFinite && maxY.isFinite && (maxX > minX || maxY > minY);

    final boundingBox = hasValidBounds
        ? PcbBoundingBox(minX: minX, minY: minY, maxX: maxX, maxY: maxY)
        : PcbBoundingBox.defaultBox;

    return PcbDocument(
      fileName: fileName,
      layerType: PcbLayerType.copperTop,
      commands: commands,
      drillHoles: drillHoles,
      boundingBox: boundingBox,
    );
  }
}
