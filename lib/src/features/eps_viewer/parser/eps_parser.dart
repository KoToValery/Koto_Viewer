import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/eps_models.dart';

/// Pure-Dart PostScript & Encapsulated PostScript (.eps) Parser.
class EpsParser {
  /// Parses raw EPS bytes (Binary DOS EPS or ASCII EPS).
  static EpsDocument parse(Uint8List bytes) {
    String postscriptText;

    // Check for Binary DOS EPS Header (magic: 0xC5D0D3C6)
    if (bytes.length >= 30 &&
        bytes[0] == 0xC5 &&
        bytes[1] == 0xD0 &&
        bytes[2] == 0xD3 &&
        bytes[3] == 0xC6) {
      final byteData = ByteData.sublistView(bytes);
      final psOffset = byteData.getUint32(4, Endian.little);
      final psLength = byteData.getUint32(8, Endian.little);

      final end = math.min(bytes.length, psOffset + psLength);
      if (psOffset < bytes.length && end > psOffset) {
        final psBytes = bytes.sublist(psOffset, end);
        postscriptText = _decodeText(psBytes);
      } else {
        postscriptText = _decodeText(bytes);
      }
    } else {
      postscriptText = _decodeText(bytes);
    }

    return _interpretPostScript(postscriptText);
  }

  static String _decodeText(Uint8List bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return latin1.decode(bytes);
    }
  }

  static EpsDocument _interpretPostScript(String ps) {
    String? title;
    String? creator;
    String? creationDate;
    EpsBoundingBox boundingBox = EpsBoundingBox.defaultBox;

    final lines = ps.split(RegExp(r'\r?\n'));

    // 1. Extract DSC Comments from header lines
    for (int i = 0; i < math.min(lines.length, 120); i++) {
      final line = lines[i].trim();
      if (line.startsWith('%%BoundingBox:')) {
        final parts = line.substring(14).trim().split(RegExp(r'\s+'));
        if (parts.length >= 4) {
          final x1 = double.tryParse(parts[0]);
          final y1 = double.tryParse(parts[1]);
          final x2 = double.tryParse(parts[2]);
          final y2 = double.tryParse(parts[3]);
          if (x1 != null && y1 != null && x2 != null && y2 != null) {
            boundingBox = EpsBoundingBox(minX: x1, minY: y1, maxX: x2, maxY: y2);
          }
        }
      } else if (line.startsWith('%%HiResBoundingBox:')) {
        final parts = line.substring(19).trim().split(RegExp(r'\s+'));
        if (parts.length >= 4) {
          final x1 = double.tryParse(parts[0]);
          final y1 = double.tryParse(parts[1]);
          final x2 = double.tryParse(parts[2]);
          final y2 = double.tryParse(parts[3]);
          if (x1 != null && y1 != null && x2 != null && y2 != null) {
            boundingBox = EpsBoundingBox(minX: x1, minY: y1, maxX: x2, maxY: y2);
          }
        }
      } else if (line.startsWith('%%Title:')) {
        title = line.substring(8).trim();
      } else if (line.startsWith('%%Creator:')) {
        creator = line.substring(10).trim();
      } else if (line.startsWith('%%CreationDate:')) {
        creationDate = line.substring(15).trim();
      }
    }

    // 2. Tokenize & Interpret PostScript vector commands
    final List<EpsPath> paths = [];
    final List<EpsPathCommand> currentCommands = [];
    final List<double> numStack = [];

    Color currentColor = Colors.black;
    double currentLineWidth = 1.0;
    Offset currentPoint = Offset.zero;

    // Graphics state stack
    final List<_GState> stateStack = [];

    // Clean comments and tokenize
    final tokens = _tokenizePostScript(ps);

    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i];

      final numVal = double.tryParse(token);
      if (numVal != null) {
        numStack.add(numVal);
        continue;
      }

      switch (token) {
        // MoveTo
        case 'moveto':
        case 'm':
          if (numStack.length >= 2) {
            final y = numStack.removeLast();
            final x = numStack.removeLast();
            currentPoint = Offset(x, y);
            currentCommands.add(EpsPathCommand.moveTo(currentPoint));
          }
          break;

        // LineTo
        case 'lineto':
        case 'l':
          if (numStack.length >= 2) {
            final y = numStack.removeLast();
            final x = numStack.removeLast();
            currentPoint = Offset(x, y);
            currentCommands.add(EpsPathCommand.lineTo(currentPoint));
          }
          break;

        // Relative LineTo
        case 'rlineto':
          if (numStack.length >= 2) {
            final dy = numStack.removeLast();
            final dx = numStack.removeLast();
            currentPoint = Offset(currentPoint.dx + dx, currentPoint.dy + dy);
            currentCommands.add(EpsPathCommand.lineTo(currentPoint));
          }
          break;

        // Relative MoveTo
        case 'rmoveto':
          if (numStack.length >= 2) {
            final dy = numStack.removeLast();
            final dx = numStack.removeLast();
            currentPoint = Offset(currentPoint.dx + dx, currentPoint.dy + dy);
            currentCommands.add(EpsPathCommand.moveTo(currentPoint));
          }
          break;

        // Cubic CurveTo
        case 'curveto':
        case 'c':
          if (numStack.length >= 6) {
            final y3 = numStack.removeLast();
            final x3 = numStack.removeLast();
            final y2 = numStack.removeLast();
            final x2 = numStack.removeLast();
            final y1 = numStack.removeLast();
            final x1 = numStack.removeLast();
            currentPoint = Offset(x3, y3);
            currentCommands.add(
              EpsPathCommand.cubicCurveTo(
                Offset(x1, y1),
                Offset(x2, y2),
                Offset(x3, y3),
              ),
            );
          }
          break;

        // ClosePath
        case 'closepath':
        case 'h':
          currentCommands.add(const EpsPathCommand.closePath());
          break;

        // Arc (x y r ang1 ang2 arc)
        case 'arc':
        case 'arcn':
          if (numStack.length >= 5) {
            final ang2 = numStack.removeLast() * math.pi / 180.0;
            final ang1 = numStack.removeLast() * math.pi / 180.0;
            final r = numStack.removeLast();
            final cy = numStack.removeLast();
            final cx = numStack.removeLast();

            final startP = Offset(cx + r * math.cos(ang1), cy + r * math.sin(ang1));
            if (currentCommands.isEmpty) {
              currentCommands.add(EpsPathCommand.moveTo(startP));
            } else {
              currentCommands.add(EpsPathCommand.lineTo(startP));
            }

            // Approximate arc segment with line segments
            final step = (ang2 - ang1) / 12.0;
            for (int s = 1; s <= 12; s++) {
              final a = ang1 + step * s;
              currentCommands.add(EpsPathCommand.lineTo(Offset(cx + r * math.cos(a), cy + r * math.sin(a))));
            }
            currentPoint = Offset(cx + r * math.cos(ang2), cy + r * math.sin(ang2));
          }
          break;

        // Stroke
        case 'stroke':
        case 'S':
          if (currentCommands.isNotEmpty) {
            paths.add(
              EpsPath(
                commands: List.from(currentCommands),
                strokeColor: currentColor,
                strokeWidth: currentLineWidth,
              ),
            );
            currentCommands.clear();
          }
          numStack.clear();
          break;

        // Fill
        case 'fill':
        case 'eofill':
        case 'f':
        case 'F':
          if (currentCommands.isNotEmpty) {
            paths.add(
              EpsPath(
                commands: List.from(currentCommands),
                fillColor: currentColor,
              ),
            );
            currentCommands.clear();
          }
          numStack.clear();
          break;

        // Set RGB Color
        case 'setrgbcolor':
        case 'rg':
        case 'RG':
          if (numStack.length >= 3) {
            final b = (numStack.removeLast() * 255).clamp(0, 255).round();
            final g = (numStack.removeLast() * 255).clamp(0, 255).round();
            final r = (numStack.removeLast() * 255).clamp(0, 255).round();
            currentColor = Color.fromARGB(255, r, g, b);
          }
          break;

        // Set CMYK Color
        case 'setcmykcolor':
        case 'k':
        case 'K':
          if (numStack.length >= 4) {
            final k = numStack.removeLast().clamp(0.0, 1.0);
            final y = numStack.removeLast().clamp(0.0, 1.0);
            final m = numStack.removeLast().clamp(0.0, 1.0);
            final c = numStack.removeLast().clamp(0.0, 1.0);

            final r = ((1.0 - c) * (1.0 - k) * 255).clamp(0, 255).round();
            final g = ((1.0 - m) * (1.0 - k) * 255).clamp(0, 255).round();
            final b = ((1.0 - y) * (1.0 - k) * 255).clamp(0, 255).round();
            currentColor = Color.fromARGB(255, r, g, b);
          }
          break;

        // Set Gray Color
        case 'setgray':
        case 'g':
        case 'G':
          if (numStack.isNotEmpty) {
            final gray = (numStack.removeLast() * 255).clamp(0, 255).round();
            currentColor = Color.fromARGB(255, gray, gray, gray);
          }
          break;

        // Set Line Width
        case 'setlinewidth':
        case 'w':
          if (numStack.isNotEmpty) {
            currentLineWidth = math.max(0.5, numStack.removeLast());
          }
          break;

        // Clear Path
        case 'newpath':
        case 'n':
          currentCommands.clear();
          numStack.clear();
          break;

        // Save State
        case 'gsave':
        case 'q':
          stateStack.add(_GState(currentColor, currentLineWidth));
          break;

        // Restore State
        case 'grestore':
        case 'Q':
          if (stateStack.isNotEmpty) {
            final st = stateStack.removeLast();
            currentColor = st.color;
            currentLineWidth = st.lineWidth;
          }
          break;

        default:
          break;
      }
    }

    final metadata = EpsMetadata(
      title: title,
      creator: creator,
      creationDate: creationDate,
      boundingBox: boundingBox,
      pathCount: paths.length,
    );

    return EpsDocument(metadata: metadata, paths: paths);
  }

  static List<String> _tokenizePostScript(String ps) {
    final List<String> tokens = [];
    final lines = ps.split(RegExp(r'\r?\n'));

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('%')) continue; // Skip comments

      final lineTokens = trimmed.split(RegExp(r'\s+'));
      for (final t in lineTokens) {
        if (t.isNotEmpty) {
          tokens.add(t);
        }
      }
    }

    return tokens;
  }
}

class _GState {
  final Color color;
  final double lineWidth;

  _GState(this.color, this.lineWidth);
}
