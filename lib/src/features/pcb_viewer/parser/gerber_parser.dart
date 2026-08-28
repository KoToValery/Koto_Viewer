import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/pcb_models.dart';

/// Pure-Dart Gerber RS-274X Parser.
class GerberParser {
  /// Parses raw Gerber text or bytes into a [PcbDocument].
  static PcbDocument parse(Uint8List bytes, {String fileName = 'layer.gbr'}) {
    final text = _decodeText(bytes);
    return _parseGerberText(text, fileName);
  }

  static String _decodeText(Uint8List bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return latin1.decode(bytes);
    }
  }

  static PcbDocument _parseGerberText(String text, String fileName) {
    final layerType = _detectLayerType(fileName, text);

    // Coordinate format defaults: 4 decimal places, Millimeters
    int xDecimals = 4;
    int yDecimals = 4;
    double unitScale = 1.0; // 1.0 for mm, 25.4 for inches
    double offsetX = 0.0;
    double offsetY = 0.0;

    final Map<int, PcbAperture> apertureTable = {};
    final List<PcbCommand> commands = [];

    PcbAperture? activeAperture;
    bool isDarkPolarity = true;
    bool inRegion = false;
    List<Offset> currentRegionPoints = [];
    List<List<Offset>> currentRegionContours = [];

    String? activePinNumber;
    String? activeNetName;
    String? activeComponentRef;

    Offset currentPoint = Offset.zero;
    int interpMode = 1; // 1 = G01 linear, 2 = G02 CW arc, 3 = G03 CCW arc

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

    final Map<String, _MacroDef> macroDefs = {};

    // Tokenize Gerber: Extended commands (%...%) vs regular commands (...*)
    final List<String> tokens = [];
    final len = text.length;
    int i = 0;
    while (i < len) {
      while (i < len && text.codeUnitAt(i) <= 32) {
        i++;
      }
      if (i >= len) break;

      if (text[i] == '%') {
        final end = text.indexOf('%', i + 1);
        if (end != -1) {
          tokens.add(text.substring(i, end + 1));
          i = end + 1;
        } else {
          tokens.add(text.substring(i));
          break;
        }
      } else {
        final end = text.indexOf('*', i);
        if (end != -1) {
          tokens.add(text.substring(i, end));
          i = end + 1;
        } else {
          tokens.add(text.substring(i));
          break;
        }
      }
    }

    for (String token in tokens) {
      token = token.trim();
      if (token.isEmpty) continue;

      // 1. Extended Commands (%)
      if (token.startsWith('%') && token.endsWith('%')) {
        final extBlock = token.substring(1, token.length - 1).trim();

        // %FSLAX...Y...% -> Format Spec
        if (extBlock.startsWith('FS')) {
          final xMatch = RegExp(r'X(\d)(\d)').firstMatch(extBlock);
          if (xMatch != null) {
            xDecimals = int.tryParse(xMatch.group(2)!) ?? 4;
          }
          final yMatch = RegExp(r'Y(\d)(\d)').firstMatch(extBlock);
          if (yMatch != null) {
            yDecimals = int.tryParse(yMatch.group(2)!) ?? 4;
          }
        }
        // %OFA...B...% -> Offset
        else if (extBlock.startsWith('OF')) {
          final aMatch = RegExp(r'A([+-]?[0-9.]+)').firstMatch(extBlock);
          if (aMatch != null) {
            offsetX = (double.tryParse(aMatch.group(1)!) ?? 0.0) * unitScale;
          }
          final bMatch = RegExp(r'B([+-]?[0-9.]+)').firstMatch(extBlock);
          if (bMatch != null) {
            offsetY = (double.tryParse(bMatch.group(1)!) ?? 0.0) * unitScale;
          }
        }
        // %MOIN% or %MOMM% -> Units
        else if (extBlock.startsWith('MO')) {
          if (extBlock.contains('IN')) {
            unitScale = 25.4; // Convert inches to mm
          } else if (extBlock.contains('MM')) {
            unitScale = 1.0;
          }
        }
        // %LPD% / %LPC% -> Polarity
        else if (extBlock.startsWith('LP')) {
          isDarkPolarity = extBlock.contains('D');
        }
        // %TO.P...% / %TA.PinNumber...% -> Pin Number
        else if (extBlock.startsWith('TO.P') || extBlock.startsWith('TA.PinNumber')) {
          final parts = extBlock.split(',');
          if (parts.length > 1) {
            activePinNumber = parts[1].replaceAll('*', '').trim();
          }
        }
        // %TO.N...% / %TA.Net...% -> Net Name
        else if (extBlock.startsWith('TO.N') || extBlock.startsWith('TA.Net')) {
          final parts = extBlock.split(',');
          if (parts.length > 1) {
            activeNetName = parts[1].replaceAll('*', '').trim();
          }
        }
        // %TO.C...% / %TA.Component...% -> Component RefDes
        else if (extBlock.startsWith('TO.C') || extBlock.startsWith('TA.Component')) {
          final parts = extBlock.split(',');
          if (parts.length > 1) {
            activeComponentRef = parts[1].replaceAll('*', '').trim();
          }
        }
        // %TD...% -> Delete Attribute / Clear active attributes
        else if (extBlock.startsWith('TD')) {
          if (extBlock.contains('P') || extBlock.contains('PinNumber')) {
            activePinNumber = null;
          }
          if (extBlock.contains('N') || extBlock.contains('Net')) {
            activeNetName = null;
          }
          if (extBlock.contains('C') || extBlock.contains('Component')) {
            activeComponentRef = null;
          }
          if (extBlock == 'TD' || extBlock == 'TD*') {
            activePinNumber = null;
            activeNetName = null;
            activeComponentRef = null;
          }
        }
        // %AM<name>*...*% -> Aperture Macro Definition
        else if (extBlock.startsWith('AM')) {
          _parseMacroDef(extBlock, macroDefs);
        }
        // %ADD<id><type>,<modifiers>% -> Aperture Definition
        else if (extBlock.startsWith('AD')) {
          final cleanExt = extBlock.replaceAll('*', '');
          final adMatch = RegExp(r'ADD(\d+)([A-Za-z0-9_]+)(?:,(.*))?').firstMatch(cleanExt);
          if (adMatch != null) {
            final id = int.tryParse(adMatch.group(1)!) ?? 10;
            final typeStr = adMatch.group(2)!.toUpperCase();
            final paramsStr = adMatch.group(3) ?? '';
            final params = paramsStr.split(RegExp(r'[X,]')).where((s) => s.isNotEmpty).map((s) => double.tryParse(s) ?? 0.0).toList();

            PcbApertureType type = PcbApertureType.circle;
            double dimX = 0.5 * unitScale;
            double dimY = 0.0;

            if (typeStr == 'C') {
              type = PcbApertureType.circle;
              dimX = (params.isNotEmpty ? params[0] : 0.5) * unitScale;
            } else if (typeStr == 'R') {
              type = PcbApertureType.rectangle;
              dimX = (params.isNotEmpty ? params[0] : 1.0) * unitScale;
              dimY = (params.length > 1 ? params[1] : dimX) * unitScale;
            } else if (typeStr == 'O') {
              type = PcbApertureType.obround;
              dimX = (params.isNotEmpty ? params[0] : 1.0) * unitScale;
              dimY = (params.length > 1 ? params[1] : dimX) * unitScale;
            } else if (typeStr == 'P') {
              type = PcbApertureType.polygon;
              dimX = (params.isNotEmpty ? params[0] : 1.0) * unitScale;
            } else if (macroDefs.containsKey(typeStr)) {
              // Custom Aperture Macro
              final macro = macroDefs[typeStr]!;
              type = macro.type;
              dimX = macro.dimX * unitScale;
              dimY = macro.dimY * unitScale;
              final pts = macro.polygonPoints
                  ?.map((p) => Offset(p.dx * unitScale, p.dy * unitScale))
                  .toList();
              apertureTable[id] = PcbAperture(
                id: id,
                type: type,
                dimX: dimX,
                dimY: dimY,
                polygonPoints: pts,
              );
              continue;
            } else {
              // Fallback for custom macro names (e.g. PPAD011)
              type = PcbApertureType.obround;
              dimX = (params.isNotEmpty ? params[0] : 1.2) * unitScale;
              dimY = (params.length > 1 ? params[1] : dimX) * unitScale;
            }

            apertureTable[id] = PcbAperture(
              id: id,
              type: type,
              dimX: dimX,
              dimY: dimY,
            );
          }
        }
        continue;
      }

      // 2. G-codes
      if (token.contains('G36')) {
        inRegion = true;
        currentRegionPoints = [];
        currentRegionContours = [[]];
      } else if (token.contains('G37')) {
        inRegion = false;
        final validContours = currentRegionContours.where((c) => c.length >= 3).toList();
        if (validContours.isNotEmpty || currentRegionPoints.length >= 3) {
          commands.add(
            PcbCommand.region(
              regionPoints: List.from(currentRegionPoints),
              regionContours: validContours.isNotEmpty ? validContours : [List.from(currentRegionPoints)],
              isDark: isDarkPolarity,
            ),
          );
        }
        currentRegionPoints.clear();
        currentRegionContours.clear();
      }

      if (token.contains('G01') || token.contains('G1')) {
        interpMode = 1;
      } else if (token.contains('G02') || token.contains('G2')) {
        interpMode = 2;
      } else if (token.contains('G03') || token.contains('G3')) {
        interpMode = 3;
      }

      // 3. Aperture Selection (D10+ or G54D10)
      final dCodeMatch = RegExp(r'(?:G54)?D(\d{2,})').firstMatch(token);
      if (dCodeMatch != null) {
        final id = int.tryParse(dCodeMatch.group(1)!) ?? 10;
        if (apertureTable.containsKey(id)) {
          activeAperture = apertureTable[id];
        }
      }

      // 4. Coordinates parsing (X...Y...I...J...D01/D02/D03)
      double? xVal;
      double? yVal;
      double? iVal;
      double? jVal;
      int? opDCode;

      final xMatch = RegExp(r'X([+-]?\d+)').firstMatch(token);
      if (xMatch != null) {
        final raw = int.tryParse(xMatch.group(1)!) ?? 0;
        xVal = (raw / math.pow(10, xDecimals)) * unitScale + offsetX;
      }

      final yMatch = RegExp(r'Y([+-]?\d+)').firstMatch(token);
      if (yMatch != null) {
        final raw = int.tryParse(yMatch.group(1)!) ?? 0;
        yVal = (raw / math.pow(10, yDecimals)) * unitScale + offsetY;
      }

      // I and J are always incremental, so they don't get the absolute offset!
      final iMatch = RegExp(r'I([+-]?\d+)').firstMatch(token);
      if (iMatch != null) {
        final raw = int.tryParse(iMatch.group(1)!) ?? 0;
        iVal = (raw / math.pow(10, xDecimals)) * unitScale;
      }

      final jMatch = RegExp(r'J([+-]?\d+)').firstMatch(token);
      if (jMatch != null) {
        final raw = int.tryParse(jMatch.group(1)!) ?? 0;
        jVal = (raw / math.pow(10, yDecimals)) * unitScale;
      }

      final dOpMatch = RegExp(r'D0([123])|D([123])(?!\d)').firstMatch(token);
      if (dOpMatch != null) {
        opDCode = int.tryParse(dOpMatch.group(1) ?? dOpMatch.group(2) ?? '');
      }

      final targetPoint = Offset(
        xVal ?? currentPoint.dx,
        yVal ?? currentPoint.dy,
      );

      // Execute Operation D01 (Draw), D02 (Move), D03 (Flash)
      if (opDCode == 1) {
        // Draw Track or Arc
        if (inRegion) {
          if (currentRegionContours.isEmpty) {
            currentRegionContours.add([]);
          }
          if (currentRegionContours.last.isEmpty) {
            currentRegionContours.last.add(currentPoint);
          }
          currentRegionContours.last.add(targetPoint);
          currentRegionPoints.add(targetPoint);
          updateBounds(targetPoint);
        } else {
          final apRadius = (activeAperture?.dimX ?? 0.2) / 2.0;
          updateBounds(currentPoint, apRadius);
          updateBounds(targetPoint, apRadius);

          if (interpMode == 1 || iVal == null || jVal == null) {
            // Linear Line
            commands.add(
              PcbCommand.line(
                p1: currentPoint,
                p2: targetPoint,
                aperture: activeAperture ?? const PcbAperture(id: 0, type: PcbApertureType.circle, dimX: 0.2),
                isDark: isDarkPolarity,
              ),
            );
          } else {
            // Circular Arc
            final center = Offset(currentPoint.dx + iVal, currentPoint.dy + jVal);
            final radius = math.sqrt(iVal * iVal + jVal * jVal);
            final startAngle = math.atan2(currentPoint.dy - center.dy, currentPoint.dx - center.dx);
            final endAngle = math.atan2(targetPoint.dy - center.dy, targetPoint.dx - center.dx);

            commands.add(
              PcbCommand.arc(
                p1: currentPoint,
                p2: targetPoint,
                center: center,
                radius: radius,
                startAngle: startAngle,
                endAngle: endAngle,
                aperture: activeAperture,
                isDark: isDarkPolarity,
              ),
            );
          }
        }
        currentPoint = targetPoint;
      } else if (opDCode == 2) {
        // Pen Up / Move
        currentPoint = targetPoint;
        if (inRegion) {
          if (currentRegionContours.isNotEmpty && currentRegionContours.last.isNotEmpty) {
            currentRegionContours.add([]);
          }
          currentRegionContours.last.add(currentPoint);
          currentRegionPoints.add(currentPoint);
        }
      } else if (opDCode == 3) {
        // Flash Pad
        final flashPoint = targetPoint;
        final apRadius = (activeAperture?.dimX ?? 1.0) / 2.0;
        updateBounds(flashPoint, apRadius);

        commands.add(
          PcbCommand.flash(
            p1: flashPoint,
            aperture: activeAperture ?? const PcbAperture(id: 0, type: PcbApertureType.circle, dimX: 1.0),
            isDark: isDarkPolarity,
            pinNumber: activePinNumber,
            netName: activeNetName,
            componentRef: activeComponentRef,
          ),
        );
        currentPoint = flashPoint;
      } else if (xVal != null || yVal != null) {
        currentPoint = targetPoint;
      }
    }

    final hasValidBounds = minX.isFinite && minY.isFinite && maxX.isFinite && maxY.isFinite && (maxX > minX || maxY > minY);

    final boundingBox = hasValidBounds
        ? PcbBoundingBox(minX: minX, minY: minY, maxX: maxX, maxY: maxY)
        : PcbBoundingBox.defaultBox;

    return PcbDocument(
      fileName: fileName,
      layerType: layerType,
      commands: commands,
      drillHoles: const [],
      boundingBox: boundingBox,
    );
  }

  static void _parseMacroDef(String extBlock, Map<String, _MacroDef> macroDefs) {
    try {
      final nameMatch = RegExp(r'^AM([A-Za-z0-9_]+)\*').firstMatch(extBlock);
      if (nameMatch == null) return;
      final name = nameMatch.group(1)!.toUpperCase();
      final body = extBlock.substring(nameMatch.end);

      // Look for primitive 4 (outline polygon) or 1 (circle) or 20/21 (rect)
      final lines = body.split('*');
      double minX = double.infinity;
      double minY = double.infinity;
      double maxX = -double.infinity;
      double maxY = -double.infinity;

      for (final line in lines) {
        final nums = line.split(',').map((s) => double.tryParse(s.trim())).whereType<double>().toList();
        if (nums.isEmpty) continue;
        final primCode = nums[0].toInt();

        if (primCode == 4 && nums.length >= 3) {
          // 4, exposure, numVertices, x1, y1, x2, y2, ...
          final pts = <Offset>[];
          for (int k = 3; k < nums.length - 1; k += 2) {
            final x = nums[k];
            final y = nums[k + 1];
            pts.add(Offset(x, y));
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
          }
          if (minX.isFinite && maxX.isFinite && minY.isFinite && maxY.isFinite) {
            final w = (maxX - minX).abs();
            final h = (maxY - minY).abs();
            macroDefs[name] = _MacroDef(
              type: PcbApertureType.polygon,
              dimX: w > 0 ? w : 1.0,
              dimY: h > 0 ? h : 1.0,
              polygonPoints: pts,
            );
            return;
          }
        } else if (primCode == 1 && nums.length >= 2) {
          // Circle: 1, exposure, diameter, [cx, cy]
          final diam = nums.length > 2 ? nums[2] : nums[1];
          macroDefs[name] = _MacroDef(type: PcbApertureType.circle, dimX: diam, dimY: diam);
          return;
        } else if ((primCode == 20 || primCode == 21) && nums.length >= 4) {
          // Vector / Center Rectangle: code, exposure, width, height, ...
          final w = nums[2];
          final h = nums[3];
          macroDefs[name] = _MacroDef(type: PcbApertureType.rectangle, dimX: w, dimY: h);
          return;
        }
      }

      if (minX.isFinite && maxX.isFinite && minY.isFinite && maxY.isFinite) {
        final w = (maxX - minX).abs();
        final h = (maxY - minY).abs();
        macroDefs[name] = _MacroDef(
          type: PcbApertureType.obround,
          dimX: w > 0 ? w : 1.0,
          dimY: h > 0 ? h : 1.0,
        );
      }
    } catch (_) {}
  }

  static PcbLayerType _detectLayerType(String fileName, String content) {
    final lower = fileName.toLowerCase();
    final lowerContent = content.substring(0, math.min(content.length, 1000)).toLowerCase();

    // 1. Gerber X2 %TF.FileFunction,...% Metadata Detection
    final fileFuncMatch = RegExp(r'%TF\.FileFunction,([^%*]+)').firstMatch(content);
    if (fileFuncMatch != null) {
      final func = fileFuncMatch.group(1)!.toLowerCase();
      if (func.contains('copper')) {
        if (func.contains('bot') || func.contains('l2') || func.contains('solder')) {
          return PcbLayerType.copperBottom;
        }
        return PcbLayerType.copperTop;
      }
      if (func.contains('soldermask') || func.contains('mask')) {
        if (func.contains('bot')) return PcbLayerType.solderMaskBottom;
        return PcbLayerType.solderMaskTop;
      }
      if (func.contains('legend') || func.contains('silk')) {
        if (func.contains('bot')) return PcbLayerType.silkscreenBottom;
        return PcbLayerType.silkscreenTop;
      }
      if (func.contains('profile')) {
        return PcbLayerType.edgeCuts;
      }
      if (func.contains('nonplated') || func.contains('npth')) {
        if (lower.contains('profile') || lower.contains('edge') || lower.contains('outline')) {
          return PcbLayerType.edgeCuts;
        }
        return PcbLayerType.drill;
      }
      if (func.contains('plated') || func.contains('drill') || func.contains('pth')) {
        return PcbLayerType.drill;
      }
    }

    // 2. Board Outline / Edge Cuts
    if (lower.contains('profile') ||
        lower.contains('edge') ||
        lower.contains('outline') ||
        lower.contains('contour') ||
        lower.contains('border') ||
        lower.contains('mechanical') ||
        lower.endsWith('.gko') ||
        lower.endsWith('.gm1') ||
        lower.endsWith('.gm2') ||
        lower.endsWith('.gm3') ||
        lower.endsWith('.dim') ||
        lower.endsWith('.edge')) {
      return PcbLayerType.edgeCuts;
    }

    // 3. Drill Layers (Gerber X2 / RS-274X Drill Drawings)
    if (lower.contains('drill') ||
        lower.contains('plated') ||
        lower.contains('pth') ||
        lower.contains('npth') ||
        lower.endsWith('.drl') ||
        lower.endsWith('.drd') ||
        lower.endsWith('.xln') ||
        lower.endsWith('.exc')) {
      return PcbLayerType.drill;
    }

    // 4. Top Silkscreen / Legend
    if (lower.contains('f_silk') ||
        lower.contains('top_silk') ||
        lower.contains('topsilk') ||
        lower.contains('silk_top') ||
        lower.contains('silktop') ||
        lower.contains('top silk') ||
        lower.contains('top legend') ||
        lower.endsWith('.gto') ||
        lower.endsWith('.sst') ||
        lower.endsWith('.tsk') ||
        lower.endsWith('.plc')) {
      return PcbLayerType.silkscreenTop;
    }

    // 5. Bottom Silkscreen / Legend
    if (lower.contains('b_silk') ||
        lower.contains('bottom_silk') ||
        lower.contains('bottomsilk') ||
        lower.contains('silk_bot') ||
        lower.contains('silkbot') ||
        lower.contains('bottom silk') ||
        lower.contains('bottom legend') ||
        lower.endsWith('.gbo') ||
        lower.endsWith('.ssb') ||
        lower.endsWith('.bsk') ||
        lower.endsWith('.pls')) {
      return PcbLayerType.silkscreenBottom;
    }

    // 6. Top Solder Mask / Solder Resist
    if (lower.contains('f_mask') ||
        lower.contains('top_mask') ||
        lower.contains('topmask') ||
        lower.contains('mask_top') ||
        lower.contains('masktop') ||
        lower.contains('top solder') ||
        lower.contains('top resist') ||
        lower.endsWith('.gts') ||
        lower.endsWith('.smt') ||
        lower.endsWith('.tsm') ||
        lower.endsWith('.stc')) {
      return PcbLayerType.solderMaskTop;
    }

    // 7. Bottom Solder Mask / Solder Resist
    if (lower.contains('b_mask') ||
        lower.contains('bottom_mask') ||
        lower.contains('bottommask') ||
        lower.contains('mask_bot') ||
        lower.contains('maskbot') ||
        lower.contains('bottom solder') ||
        lower.contains('bottom resist') ||
        lower.endsWith('.gbs') ||
        lower.endsWith('.smb') ||
        lower.endsWith('.bsm') ||
        lower.endsWith('.sts')) {
      return PcbLayerType.solderMaskBottom;
    }

    // 8. Top Copper / Signal (Component Side)
    if (lower.contains('f_cu') ||
        lower.contains('top_copper') ||
        lower.contains('topcopper') ||
        lower.contains('copper_top') ||
        lower.contains('coppertop') ||
        lower.contains('front_cu') ||
        lower.contains('top copper') ||
        lower.contains('component') ||
        lower.endsWith('.gtl') ||
        lower.endsWith('.top') ||
        lower.endsWith('.cmp')) {
      return PcbLayerType.copperTop;
    }

    // 9. Bottom Copper / Signal (Solder Side)
    if (lower.contains('b_cu') ||
        lower.contains('bottom_copper') ||
        lower.contains('bottomcopper') ||
        lower.contains('copper_bot') ||
        lower.contains('copperbot') ||
        lower.contains('back_cu') ||
        lower.contains('bottom copper') ||
        lower.contains('solder') ||
        lower.endsWith('.gbl') ||
        lower.endsWith('.bot') ||
        lower.endsWith('.sol')) {
      return PcbLayerType.copperBottom;
    }

    // Content-based fallback inspection
    if (lowerContent.contains('top silk') || lowerContent.contains('top legend')) {
      return PcbLayerType.silkscreenTop;
    }
    if (lowerContent.contains('bottom silk') || lowerContent.contains('bottom legend')) {
      return PcbLayerType.silkscreenBottom;
    }
    if (lowerContent.contains('top mask') || lowerContent.contains('top solder')) {
      return PcbLayerType.solderMaskTop;
    }
    if (lowerContent.contains('bottom mask') || lowerContent.contains('bottom solder')) {
      return PcbLayerType.solderMaskBottom;
    }
    if (lowerContent.contains('bottom copper') || lowerContent.contains('bottom layer') || lowerContent.contains('solder side')) {
      return PcbLayerType.copperBottom;
    }
    if (lowerContent.contains('top copper') || lowerContent.contains('top layer') || lowerContent.contains('component side') || lowerContent.contains('copper')) {
      return PcbLayerType.copperTop;
    }

    return PcbLayerType.generic;
  }
}

class _MacroDef {
  final PcbApertureType type;
  final double dimX;
  final double dimY;
  final List<Offset>? polygonPoints;

  const _MacroDef({
    required this.type,
    required this.dimX,
    required this.dimY,
    this.polygonPoints,
  });
}

