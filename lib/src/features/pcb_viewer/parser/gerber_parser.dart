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

    final Map<int, PcbAperture> apertureTable = {};
    final List<PcbCommand> commands = [];

    PcbAperture? activeAperture;
    bool isDarkPolarity = true;
    bool inRegion = false;
    List<Offset> currentRegionPoints = [];

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

    // Clean lines and split by '*' delimiter
    final rawTokens = text.replaceAll('\r', '').split('*');

    for (String token in rawTokens) {
      token = token.trim();
      if (token.isEmpty) continue;

      // 1. Extended Commands (%)
      if (token.startsWith('%')) {
        final extBlock = token.replaceAll('%', '').trim();

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
        // %ADD<id><type>,<modifiers>% -> Aperture Definition
        else if (extBlock.startsWith('AD')) {
          final adMatch = RegExp(r'ADD(\d+)([A-Za-z]+)(?:,(.*))?').firstMatch(extBlock);
          if (adMatch != null) {
            final id = int.tryParse(adMatch.group(1)!) ?? 10;
            final typeStr = adMatch.group(2)!.toUpperCase();
            final paramsStr = adMatch.group(3) ?? '';
            final params = paramsStr.split('X').map((s) => double.tryParse(s) ?? 0.0).toList();

            PcbApertureType type = PcbApertureType.circle;
            double dimX = 0.5;
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
      } else if (token.contains('G37')) {
        inRegion = false;
        if (currentRegionPoints.length >= 3) {
          commands.add(
            PcbCommand.region(
              regionPoints: List.from(currentRegionPoints),
              isDark: isDarkPolarity,
            ),
          );
        }
        currentRegionPoints.clear();
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

      final xMatch = RegExp(r'X(-?\d+)').firstMatch(token);
      if (xMatch != null) {
        final raw = int.tryParse(xMatch.group(1)!) ?? 0;
        xVal = (raw / math.pow(10, xDecimals)) * unitScale;
      }

      final yMatch = RegExp(r'Y(-?\d+)').firstMatch(token);
      if (yMatch != null) {
        final raw = int.tryParse(yMatch.group(1)!) ?? 0;
        yVal = (raw / math.pow(10, yDecimals)) * unitScale;
      }

      final iMatch = RegExp(r'I(-?\d+)').firstMatch(token);
      if (iMatch != null) {
        final raw = int.tryParse(iMatch.group(1)!) ?? 0;
        iVal = (raw / math.pow(10, xDecimals)) * unitScale;
      }

      final jMatch = RegExp(r'J(-?\d+)').firstMatch(token);
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
          if (currentRegionPoints.isEmpty) {
            currentRegionPoints.add(currentPoint);
          }
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

  static PcbLayerType _detectLayerType(String fileName, String content) {
    final lower = fileName.toLowerCase();
    final lowerContent = content.substring(0, math.min(content.length, 500)).toLowerCase();

    // 1. Board Outline / Edge Cuts
    if (lower.contains('edge') ||
        lower.contains('outline') ||
        lower.contains('contour') ||
        lower.contains('border') ||
        lower.contains('mechanical') ||
        lower.contains('profile') ||
        lower.endsWith('.gko') ||
        lower.endsWith('.gm1') ||
        lower.endsWith('.gm2') ||
        lower.endsWith('.gm3') ||
        lower.endsWith('.dim')) {
      return PcbLayerType.edgeCuts;
    }

    // 2. Top Silkscreen / Legend
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

    // 3. Bottom Silkscreen / Legend
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

    // 4. Top Solder Mask / Solder Resist
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

    // 5. Bottom Solder Mask / Solder Resist
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

    // 6. Top Copper / Signal (Component Side)
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

    // 7. Bottom Copper / Signal (Solder Side)
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
