import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/hpgl_models.dart';
import 'package:kotoview/src/core/services/universal_encoding_service.dart';

/// Pure-Dart HP-GL Plotter (.plt, .hpgl) Parser.
class HpglParser {
  /// Parses raw bytes of an HPGL file.
  static HpglDocument parse(Uint8List bytes, {String fileName = 'drawing.plt'}) {
    final text = _decodeText(bytes);
    return parseText(text, fileName: fileName);
  }

  static String _decodeText(Uint8List bytes) {
    return UniversalEncodingService.decodeBytes(bytes);
  }

  static HpglDocument parseText(String text, {String fileName = 'drawing.plt'}) {
    final List<HpglElement> elements = [];
    final Set<int> usedPens = {};

    int currentPen = 1;
    double currentLineWidth = 1.0;
    bool isPenDown = false;
    bool isAbsolute = true;

    Offset currentPos = Offset.zero;
    List<Offset> currentPolyline = [];

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;

    void updateBounds(Offset p) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }

    void flushPolyline() {
      if (currentPolyline.length >= 2) {
        elements.add(
          HpglElement(
            points: List.from(currentPolyline),
            color: HpglPenPalette.getPenColor(currentPen, true),
            lineWidth: currentLineWidth,
          ),
        );
      }
      currentPolyline.clear();
    }

    // Split commands by semicolon or newline
    final commands = text.replaceAll('\r', '').split(RegExp(r'[;\n]'));

    for (String cmd in commands) {
      cmd = cmd.trim();
      if (cmd.isEmpty) continue;

      final upper = cmd.toUpperCase();

      // IN (Initialize)
      if (upper.startsWith('IN')) {
        flushPolyline();
        isPenDown = false;
        isAbsolute = true;
        currentPos = Offset.zero;
      }
      // SP (Select Pen)
      else if (upper.startsWith('SP')) {
        flushPolyline();
        final penNumStr = upper.substring(2).trim();
        currentPen = int.tryParse(penNumStr) ?? 1;
        usedPens.add(currentPen);
      }
      // PW (Pen Width)
      else if (upper.startsWith('PW')) {
        final wStr = upper.substring(2).trim();
        final w = double.tryParse(wStr);
        if (w != null && w > 0) {
          currentLineWidth = w;
        }
      }
      // PA (Plot Absolute)
      else if (upper.startsWith('PA')) {
        isAbsolute = true;
        final args = _extractNumbers(upper.substring(2));
        _processCoordinates(
          args,
          isAbsolute: true,
          isPenDown: isPenDown,
          currentPos: currentPos,
          currentPolyline: currentPolyline,
          updateBounds: updateBounds,
          onNewPos: (p) => currentPos = p,
        );
      }
      // PR (Plot Relative)
      else if (upper.startsWith('PR')) {
        isAbsolute = false;
        final args = _extractNumbers(upper.substring(2));
        _processCoordinates(
          args,
          isAbsolute: false,
          isPenDown: isPenDown,
          currentPos: currentPos,
          currentPolyline: currentPolyline,
          updateBounds: updateBounds,
          onNewPos: (p) => currentPos = p,
        );
      }
      // PU (Pen Up)
      else if (upper.startsWith('PU')) {
        flushPolyline();
        isPenDown = false;
        final args = _extractNumbers(upper.substring(2));
        if (args.isNotEmpty) {
          _processCoordinates(
            args,
            isAbsolute: isAbsolute,
            isPenDown: false,
            currentPos: currentPos,
            currentPolyline: currentPolyline,
            updateBounds: updateBounds,
            onNewPos: (p) => currentPos = p,
          );
        }
      }
      // PD (Pen Down)
      else if (upper.startsWith('PD')) {
        isPenDown = true;
        final args = _extractNumbers(upper.substring(2));
        if (args.isEmpty) {
          currentPolyline.add(currentPos);
        } else {
          if (currentPolyline.isEmpty) {
            currentPolyline.add(currentPos);
          }
          _processCoordinates(
            args,
            isAbsolute: isAbsolute,
            isPenDown: true,
            currentPos: currentPos,
            currentPolyline: currentPolyline,
            updateBounds: updateBounds,
            onNewPos: (p) => currentPos = p,
          );
        }
      }
      // CI (Circle)
      else if (upper.startsWith('CI')) {
        flushPolyline();
        final rStr = upper.substring(2).trim();
        final r = double.tryParse(rStr);
        if (r != null && r > 0) {
          final List<Offset> circlePts = [];
          for (int step = 0; step <= 36; step++) {
            final angle = step * 2.0 * math.pi / 36.0;
            final pt = Offset(currentPos.dx + r * math.cos(angle), currentPos.dy + r * math.sin(angle));
            circlePts.add(pt);
            updateBounds(pt);
          }
          elements.add(
            HpglElement(
              points: circlePts,
              color: HpglPenPalette.getPenColor(currentPen, true),
              lineWidth: currentLineWidth,
              isClosed: true,
            ),
          );
        }
      }
      // EA / ER (Edge Rectangle)
      else if (upper.startsWith('EA') || upper.startsWith('ER')) {
        flushPolyline();
        final isRel = upper.startsWith('ER');
        final args = _extractNumbers(upper.substring(2));
        if (args.length >= 2) {
          final targetX = isRel ? currentPos.dx + args[0] : args[0];
          final targetY = isRel ? currentPos.dy + args[1] : args[1];

          final rectPts = [
            currentPos,
            Offset(targetX, currentPos.dy),
            Offset(targetX, targetY),
            Offset(currentPos.dx, targetY),
            currentPos,
          ];
          for (final p in rectPts) {
            updateBounds(p);
          }

          elements.add(
            HpglElement(
              points: rectPts,
              color: HpglPenPalette.getPenColor(currentPen, true),
              lineWidth: currentLineWidth,
              isClosed: true,
            ),
          );
        }
      }
    }

    flushPolyline();

    final hasValidBounds = minX.isFinite && minY.isFinite && maxX.isFinite && maxY.isFinite && (maxX > minX || maxY > minY);
    final boundingBox = hasValidBounds
        ? HpglBoundingBox(minX: minX, minY: minY, maxX: maxX, maxY: maxY)
        : HpglBoundingBox.defaultBox;

    return HpglDocument(
      fileName: fileName,
      elements: elements,
      boundingBox: boundingBox,
      penCount: math.max(1, usedPens.length),
    );
  }

  static void _processCoordinates(
    List<double> args, {
    required bool isAbsolute,
    required bool isPenDown,
    required Offset currentPos,
    required List<Offset> currentPolyline,
    required void Function(Offset) updateBounds,
    required void Function(Offset) onNewPos,
  }) {
    Offset pos = currentPos;

    for (int i = 0; i + 1 < args.length; i += 2) {
      final x = args[i];
      final y = args[i + 1];

      if (isAbsolute) {
        pos = Offset(x, y);
      } else {
        pos = Offset(pos.dx + x, pos.dy + y);
      }

      updateBounds(pos);

      if (isPenDown) {
        currentPolyline.add(pos);
      }
    }

    onNewPos(pos);
  }

  static List<double> _extractNumbers(String text) {
    final List<double> nums = [];
    final matches = RegExp(r'[-+]?[0-9]*\.?[0-9]+').allMatches(text);
    for (final m in matches) {
      final val = double.tryParse(m.group(0)!);
      if (val != null) {
        nums.add(val);
      }
    }
    return nums;
  }
}
