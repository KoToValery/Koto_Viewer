import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../pcb_viewer/models/pcb_models.dart';
import 's_expression_parser.dart';

class _LibSymbolDef {
  final String id;
  final List<List<Offset>> polylines = [];
  final List<Rect> rectangles = [];
  final List<(Offset, double)> circles = [];
  final List<(Offset, Offset, Offset)> arcs = [];
  final List<(Offset, double, double, String, String)> pins = []; // pos, angleDeg, length, number, name

  _LibSymbolDef(this.id);
}

/// Converts KiCad Schematic (.kicad_sch and legacy .sch) into a [PcbDocument].
class KicadSchParser {
  /// Parses raw bytes of a .kicad_sch or .sch file.
  static PcbDocument parse(Uint8List bytes, {String fileName = 'schematic.kicad_sch'}) {
    final text = _decodeText(bytes);
    return parseText(text, fileName: fileName);
  }

  static String _decodeText(Uint8List bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } on FormatException catch (_) {
      return latin1.decode(bytes);
    }
  }

  static PcbDocument parseText(String text, {String fileName = 'schematic.kicad_sch'}) {
    if (text.trimLeft().startsWith('EESchema Schematic File')) {
      return _parseLegacySch(text, fileName: fileName);
    }
    return _parseKicadSch(text, fileName: fileName);
  }

  static PcbDocument _parseKicadSch(String text, {String fileName = 'schematic.kicad_sch'}) {
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

    // 1. Parse Symbol Library Definitions (lib_symbols)
    final Map<String, _LibSymbolDef> libSymbols = {};
    final libSymbolsNode = root.findChild('lib_symbols');
    if (libSymbolsNode != null) {
      for (final symNode in libSymbolsNode.findAllChildren('symbol')) {
        final symId = symNode.values.isNotEmpty ? symNode.values.first : '';
        if (symId.isEmpty) continue;
        final def = _LibSymbolDef(symId);

        void extractShapes(SExpNode node) {
          // Polylines
          for (final poly in node.findAllChildren('polyline')) {
            final ptsNode = poly.findChild('pts');
            if (ptsNode != null) {
              final pts = <Offset>[];
              for (final xy in ptsNode.findAllChildren('xy')) {
                final x = xy.getDouble(0);
                final y = xy.getDouble(1);
                if (x != null && y != null) {
                  pts.add(Offset(x, y));
                }
              }
              if (pts.length >= 2) def.polylines.add(pts);
            }
          }

          // Rectangles
          for (final rectNode in node.findAllChildren('rectangle')) {
            final start = rectNode.findChild('start');
            final end = rectNode.findChild('end');
            if (start != null && end != null) {
              final x1 = start.getDouble(0) ?? 0.0;
              final y1 = start.getDouble(1) ?? 0.0;
              final x2 = end.getDouble(0) ?? 0.0;
              final y2 = end.getDouble(1) ?? 0.0;
              def.rectangles.add(Rect.fromPoints(Offset(x1, y1), Offset(x2, y2)));
            }
          }

          // Circles
          for (final circNode in node.findAllChildren('circle')) {
            final center = circNode.findChild('center');
            final radius = circNode.findChild('radius');
            if (center != null && radius != null) {
              final cx = center.getDouble(0) ?? 0.0;
              final cy = center.getDouble(1) ?? 0.0;
              final r = radius.getDouble(0) ?? 1.0;
              def.circles.add((Offset(cx, cy), r));
            }
          }

          // Arcs
          for (final arcNode in node.findAllChildren('arc')) {
            final sNode = arcNode.findChild('start');
            final mNode = arcNode.findChild('mid');
            final eNode = arcNode.findChild('end');
            if (sNode != null && mNode != null && eNode != null) {
              final s = Offset(sNode.getDouble(0) ?? 0, sNode.getDouble(1) ?? 0);
              final m = Offset(mNode.getDouble(0) ?? 0, mNode.getDouble(1) ?? 0);
              final e = Offset(eNode.getDouble(0) ?? 0, eNode.getDouble(1) ?? 0);
              def.arcs.add((s, m, e));
            }
          }

          // Pins
          for (final pinNode in node.findAllChildren('pin')) {
            final atNode = pinNode.findChild('at');
            final lenNode = pinNode.findChild('length');
            final nameNode = pinNode.findChild('name');
            final numNode = pinNode.findChild('number');

            if (atNode != null) {
              final px = atNode.getDouble(0) ?? 0.0;
              final py = atNode.getDouble(1) ?? 0.0;
              final pRot = atNode.getDouble(2) ?? 0.0;
              final pLen = lenNode?.getDouble(0) ?? 2.54;
              final pName = nameNode?.values.isNotEmpty == true ? nameNode!.values.first : '';
              final pNum = numNode?.values.isNotEmpty == true ? numNode!.values.first : '';

              def.pins.add((Offset(px, py), pRot, pLen, pNum, pName));
            }
          }

          // Recursively check nested sub-symbols (units)
          for (final sub in node.findAllChildren('symbol')) {
            extractShapes(sub);
          }
        }

        extractShapes(symNode);
        libSymbols[symId] = def;
        // Also map without library prefix (e.g. Device:R -> R)
        if (symId.contains(':')) {
          libSymbols[symId.split(':').last] = def;
        }
      }
    }

    // 2. Parse Wires
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
          updateBounds(p1, 0.3);
          updateBounds(p2, 0.3);

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

    // 3. Parse Busses
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
          updateBounds(p1, 0.6);
          updateBounds(p2, 0.6);

          commands.add(
            PcbCommand.line(
              p1: p1,
              p2: p2,
              aperture: const PcbAperture(id: 0, type: PcbApertureType.circle, dimX: 0.6),
            ),
          );
        }
      }
    }

    // 4. Parse Junctions
    for (final junc in root.findAllChildren('junction')) {
      final atNode = junc.findChild('at');
      if (atNode != null) {
        final x = atNode.getDouble(0) ?? 0.0;
        final y = atNode.getDouble(1) ?? 0.0;
        final pos = Offset(x, y);
        updateBounds(pos, 0.6);

        commands.add(
          PcbCommand.flash(
            p1: pos,
            aperture: const PcbAperture(id: 0, type: PcbApertureType.circle, dimX: 0.9),
          ),
        );
      }
    }

    // 5. Parse Top-Level Symbols (Components on Schematic)
    for (final sym in root.findAllChildren('symbol')) {
      // Skip symbols inside lib_symbols (only top-level instances have lib_id or at)
      final libIdNode = sym.findChild('lib_id');
      final atNode = sym.findChild('at');
      if (atNode == null) continue;

      final posX = atNode.getDouble(0) ?? 0.0;
      final posY = atNode.getDouble(1) ?? 0.0;
      final rotDeg = atNode.getDouble(2) ?? 0.0;
      final mirrorNode = sym.findChild('mirror');
      final mirrorVal = mirrorNode?.values.isNotEmpty == true ? mirrorNode!.values.first.toLowerCase() : '';
      final mirrorX = mirrorVal == 'x';
      final mirrorY = mirrorVal == 'y';

      final pos = Offset(posX, posY);
      updateBounds(pos, 5.0);

      final libId = libIdNode?.values.isNotEmpty == true ? libIdNode!.values.first : '';
      final def = libSymbols[libId] ?? (libId.contains(':') ? libSymbols[libId.split(':').last] : null);

      Offset transform(Offset local) {
        double lx = local.dx;
        double ly = local.dy;
        if (mirrorX) lx = -lx;
        if (mirrorY) ly = -ly;
        final rad = rotDeg * math.pi / 180.0;
        final rx = lx * math.cos(rad) - ly * math.sin(rad);
        final ry = lx * math.sin(rad) + ly * math.cos(rad);
        return Offset(posX + rx, posY + ry);
      }

      if (def != null) {
        // Draw polylines
        for (final poly in def.polylines) {
          for (int i = 0; i < poly.length - 1; i++) {
            final p1 = transform(poly[i]);
            final p2 = transform(poly[i + 1]);
            updateBounds(p1, 0.2);
            updateBounds(p2, 0.2);
            commands.add(
              PcbCommand.line(
                p1: p1,
                p2: p2,
                aperture: const PcbAperture(id: 0, type: PcbApertureType.circle, dimX: 0.2),
              ),
            );
          }
        }

        // Draw rectangles
        for (final rect in def.rectangles) {
          final p1 = transform(rect.topLeft);
          final p2 = transform(rect.topRight);
          final p3 = transform(rect.bottomRight);
          final p4 = transform(rect.bottomLeft);
          updateBounds(p1, 0.2);
          updateBounds(p3, 0.2);

          commands.add(PcbCommand.line(p1: p1, p2: p2, aperture: const PcbAperture(id: 0, type: PcbApertureType.circle, dimX: 0.2)));
          commands.add(PcbCommand.line(p1: p2, p2: p3, aperture: const PcbAperture(id: 0, type: PcbApertureType.circle, dimX: 0.2)));
          commands.add(PcbCommand.line(p1: p3, p2: p4, aperture: const PcbAperture(id: 0, type: PcbApertureType.circle, dimX: 0.2)));
          commands.add(PcbCommand.line(p1: p4, p2: p1, aperture: const PcbAperture(id: 0, type: PcbApertureType.circle, dimX: 0.2)));
        }

        // Draw circles
        for (final circ in def.circles) {
          final center = transform(circ.$1);
          final r = circ.$2;
          updateBounds(center, r);
          commands.add(
            PcbCommand.arc(
              p1: center + Offset(r, 0),
              p2: center + Offset(r, 0),
              center: center,
              radius: r,
              startAngle: 0.0,
              endAngle: 2 * math.pi,
              aperture: const PcbAperture(id: 0, type: PcbApertureType.circle, dimX: 0.2),
            ),
          );
        }

        // Draw arcs
        for (final arc in def.arcs) {
          final s = transform(arc.$1);
          final m = transform(arc.$2);
          final e = transform(arc.$3);
          updateBounds(s, 0.2);
          updateBounds(m, 0.2);
          updateBounds(e, 0.2);
          commands.add(PcbCommand.line(p1: s, p2: m, aperture: const PcbAperture(id: 0, type: PcbApertureType.circle, dimX: 0.2)));
          commands.add(PcbCommand.line(p1: m, p2: e, aperture: const PcbAperture(id: 0, type: PcbApertureType.circle, dimX: 0.2)));
        }

        // Draw pins
        for (final pin in def.pins) {
          final pinLocalPos = pin.$1;
          final pinRotDeg = pin.$2;
          final pinLen = pin.$3;
          final pinNum = pin.$4;

          final pPin = transform(pinLocalPos);
          // Calculate pin direction
          final pinAngleRad = pinRotDeg * math.pi / 180.0;
          final pinLocalEnd = pinLocalPos + Offset(math.cos(pinAngleRad) * pinLen, math.sin(pinAngleRad) * pinLen);
          final pEnd = transform(pinLocalEnd);

          updateBounds(pPin, 0.2);
          updateBounds(pEnd, 0.2);

          commands.add(
            PcbCommand.line(
              p1: pPin,
              p2: pEnd,
              aperture: const PcbAperture(id: 0, type: PcbApertureType.circle, dimX: 0.2),
            ),
          );

          if (pinNum.isNotEmpty) {
            commands.add(
              PcbCommand.text(
                p1: pPin,
                text: pinNum,
                fontSize: 1.1,
              ),
            );
          }
        }
      } else {
        // Fallback indicator when lib_symbols is missing
        commands.add(
          PcbCommand.flash(
            p1: pos,
            aperture: const PcbAperture(id: 0, type: PcbApertureType.rectangle, dimX: 4.0, dimY: 2.5),
          ),
        );
      }

      // Properties (Reference designator & Value)
      for (final prop in sym.findAllChildren('property')) {
        final propName = prop.values.isNotEmpty ? prop.values.first : '';
        final propVal = prop.values.length > 1 ? prop.values[1] : '';
        final propAt = prop.findChild('at');

        if ((propName == 'Reference' || propName == 'Value') && propVal.isNotEmpty && propVal != '~') {
          Offset propPos = pos;
          double propRot = 0.0;
          if (propAt != null) {
            final px = propAt.getDouble(0);
            final py = propAt.getDouble(1);
            if (px != null && py != null) {
              propPos = Offset(px, py);
            }
            propRot = (propAt.getDouble(2) ?? 0.0) * math.pi / 180.0;
          } else {
            propPos = pos + (propName == 'Reference' ? const Offset(0, -3.5) : const Offset(0, 3.5));
          }

          updateBounds(propPos, 2.0);
          commands.add(
            PcbCommand.text(
              p1: propPos,
              text: propVal,
              fontSize: 1.4,
              rotation: propRot,
            ),
          );
        }
      }
    }

    // 6. Parse Schematic Text, Labels, and Global Labels
    for (final labelNode in root.findAllChildren('label')) {
      final name = labelNode.values.isNotEmpty ? labelNode.values.first : '';
      final atNode = labelNode.findChild('at');
      if (name.isNotEmpty && atNode != null) {
        final x = atNode.getDouble(0) ?? 0.0;
        final y = atNode.getDouble(1) ?? 0.0;
        final rot = (atNode.getDouble(2) ?? 0.0) * math.pi / 180.0;
        final pos = Offset(x, y);
        updateBounds(pos, 2.0);
        commands.add(PcbCommand.text(p1: pos, text: name, fontSize: 1.3, rotation: rot));
      }
    }

    for (final gLabel in root.findAllChildren('global_label')) {
      final name = gLabel.values.isNotEmpty ? gLabel.values.first : '';
      final atNode = gLabel.findChild('at');
      if (name.isNotEmpty && atNode != null) {
        final x = atNode.getDouble(0) ?? 0.0;
        final y = atNode.getDouble(1) ?? 0.0;
        final rot = (atNode.getDouble(2) ?? 0.0) * math.pi / 180.0;
        final pos = Offset(x, y);
        updateBounds(pos, 2.5);

        // Global label marker
        commands.add(
          PcbCommand.flash(
            p1: pos,
            aperture: const PcbAperture(id: 0, type: PcbApertureType.circle, dimX: 0.6),
          ),
        );
        commands.add(PcbCommand.text(p1: pos + const Offset(1.0, 0), text: name, fontSize: 1.4, rotation: rot));
      }
    }

    for (final hLabel in root.findAllChildren('hierarchical_label')) {
      final name = hLabel.values.isNotEmpty ? hLabel.values.first : '';
      final atNode = hLabel.findChild('at');
      if (name.isNotEmpty && atNode != null) {
        final x = atNode.getDouble(0) ?? 0.0;
        final y = atNode.getDouble(1) ?? 0.0;
        final rot = (atNode.getDouble(2) ?? 0.0) * math.pi / 180.0;
        final pos = Offset(x, y);
        updateBounds(pos, 2.5);
        commands.add(PcbCommand.text(p1: pos, text: name, fontSize: 1.3, rotation: rot));
      }
    }

    for (final textNode in root.findAllChildren('text')) {
      final str = textNode.values.isNotEmpty ? textNode.values.first : '';
      final atNode = textNode.findChild('at');
      if (str.isNotEmpty && atNode != null) {
        final x = atNode.getDouble(0) ?? 0.0;
        final y = atNode.getDouble(1) ?? 0.0;
        final rot = (atNode.getDouble(2) ?? 0.0) * math.pi / 180.0;
        final pos = Offset(x, y);
        updateBounds(pos, 3.0);
        commands.add(PcbCommand.text(p1: pos, text: str, fontSize: 1.5, rotation: rot));
      }
    }

    // 7. Parse Standalone Graphic Shapes (polyline, rectangle, circle, arc on schematic)
    for (final poly in root.findAllChildren('polyline')) {
      final ptsNode = poly.findChild('pts');
      if (ptsNode != null) {
        final pts = ptsNode.findAllChildren('xy').map((xy) {
          final x = xy.getDouble(0) ?? 0.0;
          final y = xy.getDouble(1) ?? 0.0;
          return Offset(x, y);
        }).toList();
        for (int i = 0; i < pts.length - 1; i++) {
          updateBounds(pts[i], 0.2);
          updateBounds(pts[i + 1], 0.2);
          commands.add(PcbCommand.line(p1: pts[i], p2: pts[i + 1], aperture: const PcbAperture(id: 0, type: PcbApertureType.circle, dimX: 0.25)));
        }
      }
    }

    for (final rectNode in root.findAllChildren('rectangle')) {
      final start = rectNode.findChild('start');
      final end = rectNode.findChild('end');
      if (start != null && end != null) {
        final x1 = start.getDouble(0) ?? 0.0;
        final y1 = start.getDouble(1) ?? 0.0;
        final x2 = end.getDouble(0) ?? 0.0;
        final y2 = end.getDouble(1) ?? 0.0;
        final p1 = Offset(x1, y1);
        final p2 = Offset(x2, y1);
        final p3 = Offset(x2, y2);
        final p4 = Offset(x1, y2);
        updateBounds(p1, 0.2);
        updateBounds(p3, 0.2);
        commands.add(PcbCommand.line(p1: p1, p2: p2, aperture: const PcbAperture(id: 0, type: PcbApertureType.circle, dimX: 0.25)));
        commands.add(PcbCommand.line(p1: p2, p2: p3, aperture: const PcbAperture(id: 0, type: PcbApertureType.circle, dimX: 0.25)));
        commands.add(PcbCommand.line(p1: p3, p2: p4, aperture: const PcbAperture(id: 0, type: PcbApertureType.circle, dimX: 0.25)));
        commands.add(PcbCommand.line(p1: p4, p2: p1, aperture: const PcbAperture(id: 0, type: PcbApertureType.circle, dimX: 0.25)));
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

  /// Parses legacy KiCad 5 (.sch) files
  static PcbDocument _parseLegacySch(String text, {required String fileName}) {
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

    const milToMm = 0.0254;
    final lines = text.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // Wire
      if (line.startsWith('Wire Wire Line') || line.startsWith('Wire Bus Line')) {
        if (i + 1 < lines.length) {
          final coordLine = lines[++i].trim();
          final parts = coordLine.split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            final x1 = (double.tryParse(parts[0]) ?? 0.0) * milToMm;
            final y1 = (double.tryParse(parts[1]) ?? 0.0) * milToMm;
            final x2 = (double.tryParse(parts[2]) ?? 0.0) * milToMm;
            final y2 = (double.tryParse(parts[3]) ?? 0.0) * milToMm;
            final p1 = Offset(x1, y1);
            final p2 = Offset(x2, y2);
            updateBounds(p1, 0.3);
            updateBounds(p2, 0.3);
            commands.add(PcbCommand.line(p1: p1, p2: p2, aperture: const PcbAperture(id: 0, type: PcbApertureType.circle, dimX: 0.25)));
          }
        }
      }
      // Connection (Junction)
      else if (line.startsWith('Connection ~')) {
        final parts = line.split(RegExp(r'\s+'));
        if (parts.length >= 4) {
          final x = (double.tryParse(parts[2]) ?? 0.0) * milToMm;
          final y = (double.tryParse(parts[3]) ?? 0.0) * milToMm;
          final pos = Offset(x, y);
          updateBounds(pos, 0.6);
          commands.add(PcbCommand.flash(p1: pos, aperture: const PcbAperture(id: 0, type: PcbApertureType.circle, dimX: 0.9)));
        }
      }
      // Component
      else if (line.startsWith(r'$Comp')) {
        String ref = '';
        String val = '';
        Offset pos = Offset.zero;
        while (i + 1 < lines.length && !lines[i + 1].trim().startsWith(r'$EndComp')) {
          i++;
          final cLine = lines[i].trim();
          if (cLine.startsWith('P ')) {
            final parts = cLine.split(RegExp(r'\s+'));
            if (parts.length >= 3) {
              pos = Offset((double.tryParse(parts[1]) ?? 0.0) * milToMm, (double.tryParse(parts[2]) ?? 0.0) * milToMm);
            }
          } else if (cLine.startsWith('F 0 ')) {
            final m = RegExp(r'"(.*?)"').firstMatch(cLine);
            if (m != null) ref = m.group(1)!;
          } else if (cLine.startsWith('F 1 ')) {
            final m = RegExp(r'"(.*?)"').firstMatch(cLine);
            if (m != null) val = m.group(1)!;
          }
        }
        updateBounds(pos, 4.0);
        commands.add(PcbCommand.flash(p1: pos, aperture: const PcbAperture(id: 0, type: PcbApertureType.rectangle, dimX: 4.0, dimY: 2.5)));
        if (ref.isNotEmpty) {
          commands.add(PcbCommand.text(p1: pos + const Offset(0, -3.0), text: ref, fontSize: 1.4));
        }
        if (val.isNotEmpty) {
          commands.add(PcbCommand.text(p1: pos + const Offset(0, 3.0), text: val, fontSize: 1.4));
        }
      }
      // Text Label
      else if (line.startsWith('Text HLabel') || line.startsWith('Text GLabel') || line.startsWith('Text Label')) {
        final parts = line.split(RegExp(r'\s+'));
        if (parts.length >= 4) {
          final x = (double.tryParse(parts[2]) ?? 0.0) * milToMm;
          final y = (double.tryParse(parts[3]) ?? 0.0) * milToMm;
          final pos = Offset(x, y);
          if (i + 1 < lines.length) {
            final labelText = lines[++i].trim();
            updateBounds(pos, 2.0);
            commands.add(PcbCommand.text(p1: pos, text: labelText, fontSize: 1.3));
          }
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

