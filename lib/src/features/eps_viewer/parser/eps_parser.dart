import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/eps_models.dart';

/// 2D Affine Transformation Matrix for PostScript CTM (Current Transformation Matrix).
class _AffineMatrix {
  final double a; // scale X / cos
  final double b; // shear Y / sin
  final double c; // shear X / -sin
  final double d; // scale Y / cos
  final double tx; // translation X
  final double ty; // translation Y

  const _AffineMatrix(this.a, this.b, this.c, this.d, this.tx, this.ty);

  static const identity = _AffineMatrix(1.0, 0.0, 0.0, 1.0, 0.0, 0.0);

  Offset transform(Offset pt) {
    return Offset(
      a * pt.dx + c * pt.dy + tx,
      b * pt.dx + d * pt.dy + ty,
    );
  }

  // Multiplies this matrix by another (this * other)
  _AffineMatrix multiply(_AffineMatrix o) {
    return _AffineMatrix(
      a * o.a + c * o.b,
      b * o.a + d * o.b,
      a * o.c + c * o.d,
      b * o.c + d * o.d,
      a * o.tx + c * o.ty + tx,
      b * o.tx + d * o.ty + ty,
    );
  }

  _AffineMatrix translate(double dx, double dy) {
    return multiply(_AffineMatrix(1.0, 0.0, 0.0, 1.0, dx, dy));
  }

  _AffineMatrix scale(double sx, double sy) {
    return multiply(_AffineMatrix(sx, 0.0, 0.0, sy, 0.0, 0.0));
  }

  _AffineMatrix rotate(double angleRad) {
    final cosA = math.cos(angleRad);
    final sinA = math.sin(angleRad);
    return multiply(_AffineMatrix(cosA, sinA, -sinA, cosA, 0.0, 0.0));
  }
}

class _GState {
  final Color color;
  final double lineWidth;
  final _AffineMatrix ctm;

  const _GState(this.color, this.lineWidth, this.ctm);
}

/// Pure-Dart PostScript & Encapsulated PostScript (.eps) Parser with full 2D CTM support.
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
    String? orientation;
    EpsBoundingBox? dscBoundingBox;

    final lines = ps.split(RegExp(r'\r?\n'));

    // 1. Extract DSC Comments from header lines
    for (int i = 0; i < math.min(lines.length, 150); i++) {
      final line = lines[i].trim();
      if (line.startsWith('%%BoundingBox:')) {
        final parts = line.substring(14).trim().split(RegExp(r'\s+'));
        if (parts.length >= 4) {
          final x1 = double.tryParse(parts[0]);
          final y1 = double.tryParse(parts[1]);
          final x2 = double.tryParse(parts[2]);
          final y2 = double.tryParse(parts[3]);
          if (x1 != null && y1 != null && x2 != null && y2 != null) {
            dscBoundingBox = EpsBoundingBox(minX: x1, minY: y1, maxX: x2, maxY: y2);
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
            dscBoundingBox = EpsBoundingBox(minX: x1, minY: y1, maxX: x2, maxY: y2);
          }
        }
      } else if (line.startsWith('%%Orientation:')) {
        orientation = line.substring(14).trim();
      } else if (line.startsWith('%%PageOrientation:')) {
        orientation = line.substring(18).trim();
      } else if (line.startsWith('%%Title:')) {
        title = line.substring(8).trim();
      } else if (line.startsWith('%%Creator:')) {
        creator = line.substring(10).trim();
      } else if (line.startsWith('%%CreationDate:')) {
        creationDate = line.substring(15).trim();
      }
    }

    // 2. Tokenize & Interpret PostScript vector commands with CTM
    final List<EpsPath> paths = [];
    final List<EpsPathCommand> currentCommands = [];
    final List<double> numStack = [];

    Color currentColor = Colors.black;
    double currentLineWidth = 1.0;
    _AffineMatrix ctm = _AffineMatrix.identity;
    Offset currentPoint = Offset.zero;

    // Graphics state stack
    final List<_GState> stateStack = [];

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
            final raw = Offset(x, y);
            currentPoint = ctm.transform(raw);
            currentCommands.add(EpsPathCommand.moveTo(currentPoint));
          }
          break;

        // LineTo
        case 'lineto':
        case 'l':
          if (numStack.length >= 2) {
            final y = numStack.removeLast();
            final x = numStack.removeLast();
            final raw = Offset(x, y);
            currentPoint = ctm.transform(raw);
            currentCommands.add(EpsPathCommand.lineTo(currentPoint));
          }
          break;

        // Relative LineTo
        case 'rlineto':
          if (numStack.length >= 2) {
            final dy = numStack.removeLast();
            final dx = numStack.removeLast();
            final delta = ctm.transform(Offset(dx, dy)) - ctm.transform(Offset.zero);
            currentPoint = Offset(currentPoint.dx + delta.dx, currentPoint.dy + delta.dy);
            currentCommands.add(EpsPathCommand.lineTo(currentPoint));
          }
          break;

        // Relative MoveTo
        case 'rmoveto':
          if (numStack.length >= 2) {
            final dy = numStack.removeLast();
            final dx = numStack.removeLast();
            final delta = ctm.transform(Offset(dx, dy)) - ctm.transform(Offset.zero);
            currentPoint = Offset(currentPoint.dx + delta.dx, currentPoint.dy + delta.dy);
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

            final p1 = ctm.transform(Offset(x1, y1));
            final p2 = ctm.transform(Offset(x2, y2));
            final p3 = ctm.transform(Offset(x3, y3));
            currentPoint = p3;
            currentCommands.add(EpsPathCommand.cubicCurveTo(p1, p2, p3));
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
            final isCcw = token == 'arc';
            final ang2Deg = numStack.removeLast();
            final ang1Deg = numStack.removeLast();
            final r = numStack.removeLast();
            final cy = numStack.removeLast();
            final cx = numStack.removeLast();

            final ang1 = ang1Deg * math.pi / 180.0;
            final ang2 = ang2Deg * math.pi / 180.0;

            final startRaw = Offset(cx + r * math.cos(ang1), cy + r * math.sin(ang1));
            final startPt = ctm.transform(startRaw);

            if (currentCommands.isEmpty) {
              currentCommands.add(EpsPathCommand.moveTo(startPt));
            } else {
              currentCommands.add(EpsPathCommand.lineTo(startPt));
            }

            // Approximate arc segment
            double deltaAngle = ang2 - ang1;
            if (isCcw && deltaAngle < 0) deltaAngle += 2 * math.pi;
            if (!isCcw && deltaAngle > 0) deltaAngle -= 2 * math.pi;

            const int steps = 16;
            for (int s = 1; s <= steps; s++) {
              final a = ang1 + (deltaAngle * s / steps);
              final raw = Offset(cx + r * math.cos(a), cy + r * math.sin(a));
              currentCommands.add(EpsPathCommand.lineTo(ctm.transform(raw)));
            }
            final endRaw = Offset(cx + r * math.cos(ang2), cy + r * math.sin(ang2));
            currentPoint = ctm.transform(endRaw);
          }
          break;

        // RectFill / RectStroke (x y w h rectfill / rectstroke)
        case 'rectfill':
        case 'rectstroke':
          if (numStack.length >= 4) {
            final h = numStack.removeLast();
            final w = numStack.removeLast();
            final y = numStack.removeLast();
            final x = numStack.removeLast();

            final p1 = ctm.transform(Offset(x, y));
            final p2 = ctm.transform(Offset(x + w, y));
            final p3 = ctm.transform(Offset(x + w, y + h));
            final p4 = ctm.transform(Offset(x, y + h));

            final rectCmds = [
              EpsPathCommand.moveTo(p1),
              EpsPathCommand.lineTo(p2),
              EpsPathCommand.lineTo(p3),
              EpsPathCommand.lineTo(p4),
              const EpsPathCommand.closePath(),
            ];

            if (token == 'rectfill') {
              paths.add(EpsPath(commands: rectCmds, fillColor: currentColor));
            } else {
              paths.add(EpsPath(commands: rectCmds, strokeColor: currentColor, strokeWidth: currentLineWidth));
            }
          }
          break;

        // 2D Transformations on CTM
        case 'translate':
          if (numStack.length >= 2) {
            final dy = numStack.removeLast();
            final dx = numStack.removeLast();
            ctm = ctm.translate(dx, dy);
          }
          break;

        case 'scale':
          if (numStack.length >= 2) {
            final sy = numStack.removeLast();
            final sx = numStack.removeLast();
            ctm = ctm.scale(sx, sy);
          }
          break;

        case 'rotate':
          if (numStack.isNotEmpty) {
            final angleDeg = numStack.removeLast();
            ctm = ctm.rotate(angleDeg * math.pi / 180.0);
          }
          break;

        case 'concat':
        case 'cm':
          if (numStack.length >= 6) {
            final ty = numStack.removeLast();
            final tx = numStack.removeLast();
            final d = numStack.removeLast();
            final c = numStack.removeLast();
            final b = numStack.removeLast();
            final a = numStack.removeLast();
            ctm = ctm.multiply(_AffineMatrix(a, b, c, d, tx, ty));
          }
          break;

        case 'setmatrix':
          if (numStack.length >= 6) {
            final ty = numStack.removeLast();
            final tx = numStack.removeLast();
            final d = numStack.removeLast();
            final c = numStack.removeLast();
            final b = numStack.removeLast();
            final a = numStack.removeLast();
            ctm = _AffineMatrix(a, b, c, d, tx, ty);
          }
          break;

        // Stack helpers
        case 'pop':
          if (numStack.isNotEmpty) numStack.removeLast();
          break;
        case 'dup':
          if (numStack.isNotEmpty) numStack.add(numStack.last);
          break;
        case 'exch':
          if (numStack.length >= 2) {
            final top = numStack.removeLast();
            final sec = numStack.removeLast();
            numStack.add(top);
            numStack.add(sec);
          }
          break;
        case 'neg':
          if (numStack.isNotEmpty) {
            numStack.add(-numStack.removeLast());
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
          stateStack.add(_GState(currentColor, currentLineWidth, ctm));
          break;

        // Restore State
        case 'grestore':
        case 'Q':
          if (stateStack.isNotEmpty) {
            final st = stateStack.removeLast();
            currentColor = st.color;
            currentLineWidth = st.lineWidth;
            ctm = st.ctm;
          }
          break;

        default:
          break;
      }
    }

    // 3. Compute tight bounding box from parsed paths if DSC box is missing/invalid
    EpsBoundingBox finalBoundingBox;
    if (paths.isNotEmpty) {
      double minX = double.infinity;
      double minY = double.infinity;
      double maxX = -double.infinity;
      double maxY = -double.infinity;

      for (final p in paths) {
        for (final cmd in p.commands) {
          if (cmd.type == EpsCommandType.closePath) continue;
          final pts = [cmd.p1, if (cmd.p2 != null) cmd.p2!, if (cmd.p3 != null) cmd.p3!];
          for (final pt in pts) {
            if (pt.dx < minX) minX = pt.dx;
            if (pt.dx > maxX) maxX = pt.dx;
            if (pt.dy < minY) minY = pt.dy;
            if (pt.dy > maxY) maxY = pt.dy;
          }
        }
      }

      if (minX.isFinite && minY.isFinite && maxX.isFinite && maxY.isFinite) {
        if (dscBoundingBox == null || dscBoundingBox.width <= 0 || dscBoundingBox.height <= 0) {
          finalBoundingBox = EpsBoundingBox(minX: minX, minY: minY, maxX: maxX, maxY: maxY);
        } else {
          // If paths extend outside DSC bounding box, union them
          final unionMinX = math.min(minX, dscBoundingBox.minX);
          final unionMinY = math.min(minY, dscBoundingBox.minY);
          final unionMaxX = math.max(maxX, dscBoundingBox.maxX);
          final unionMaxY = math.max(maxY, dscBoundingBox.maxY);
          finalBoundingBox = EpsBoundingBox(
            minX: unionMinX,
            minY: unionMinY,
            maxX: unionMaxX,
            maxY: unionMaxY,
          );
        }
      } else {
        finalBoundingBox = dscBoundingBox ?? EpsBoundingBox.defaultBox;
      }
    } else {
      finalBoundingBox = dscBoundingBox ?? EpsBoundingBox.defaultBox;
    }

    final metadata = EpsMetadata(
      title: title,
      creator: creator,
      creationDate: creationDate,
      orientation: orientation,
      boundingBox: finalBoundingBox,
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

      // Replace brackets/parentheses delimiters with spaces for easy tokenization
      final cleanLine = trimmed
          .replaceAll('[', ' ')
          .replaceAll(']', ' ')
          .replaceAll('{', ' ')
          .replaceAll('}', ' ');

      final lineTokens = cleanLine.split(RegExp(r'\s+'));
      for (final t in lineTokens) {
        if (t.isNotEmpty) {
          tokens.add(t);
        }
      }
    }

    return tokens;
  }
}
