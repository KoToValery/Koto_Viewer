import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../models/architect_project.dart';
import '../rendering/architect_vector_scene.dart';
import 'architect_sheet_composer.dart';
import 'architect_drawing_publisher.dart';

class ArchitectPdfExport {
  static const pointsPerMm = 72 / 25.4;
  static Future<Uint8List> export(
    ArchitectProject snapshot,
    List<ArchitectSheet> sheets,
    AppLocalizations l, {
    ArchitectPublicationSources sources = const ArchitectPublicationSources(),
  }) async {
    if (sheets.isEmpty) throw ArgumentError('No sheets');
    final problems = [
      for (final sheet in sheets)
        for (final issue in ArchitectSheetComposer.issues(snapshot, sheet, l))
          '${sheet.number}: $issue',
    ];
    if (problems.isNotEmpty) throw StateError(problems.join('\n'));
    final regular = (await rootBundle.load(
      'assets/fonts/NotoSans-Regular.ttf',
    )).buffer.asUint8List();
    final bold = (await rootBundle.load(
      'assets/fonts/NotoSans-Bold.ttf',
    )).buffer.asUint8List();
    final document = PdfDocument();
    try {
      for (final sheet in sheets) {
        final scene = ArchitectSheetComposer.compose(
          snapshot,
          sheet,
          l,
          sources: sources,
        );
        final section = document.sections!.add();
        section.pageSettings.orientation = sheet.widthMm > sheet.heightMm
            ? PdfPageOrientation.landscape
            : PdfPageOrientation.portrait;
        section.pageSettings.size = Size(
          sheet.widthMm * pointsPerMm,
          sheet.heightMm * pointsPerMm,
        );
        section.pageSettings.margins.all = 0;
        final graphics = section.pages.add().graphics;
        final fonts = <String, PdfTrueTypeFont>{};
        for (final op in scene.operations) {
          final state = graphics.save();
          if (op.clip != null) graphics.setClip(path: _path(op.clip!));
          switch (op) {
            case ArchitectVectorPath():
              final color = _color(op.color);
              graphics.setTransparency(op.color.a);
              graphics.drawPath(
                _path(op.path),
                pen: op.fill ? null : _pen(color, op),
                brush: op.fill ? PdfSolidBrush(color) : null,
              );
            case ArchitectVectorText():
              final isBold = op.weight.value >= 600;
              final key = '${op.size}/$isBold/${op.fontStyle}/${op.decoration}';
              final font = fonts.putIfAbsent(
                key,
                () => PdfTrueTypeFont(
                  isBold ? bold : regular,
                  op.size * pointsPerMm,
                  multiStyle: [
                    if (isBold) PdfFontStyle.bold,
                    if (op.fontStyle == FontStyle.italic) PdfFontStyle.italic,
                    if (op.decoration.contains(TextDecoration.underline))
                      PdfFontStyle.underline,
                  ],
                ),
              );
              graphics.translateTransform(
                op.position.dx * pointsPerMm,
                op.position.dy * pointsPerMm,
              );
              graphics.rotateTransform(op.rotation * 180 / math.pi);
              graphics.drawString(
                op.text,
                font,
                brush: PdfSolidBrush(_color(op.color)),
                bounds: Rect.fromLTWH(0, 0, 10000, op.size * pointsPerMm * 3),
                format: PdfStringFormat(wordWrap: PdfWordWrapType.none),
              );
          }
          graphics.restore(state);
        }
      }
      return Uint8List.fromList(await document.save());
    } finally {
      document.dispose();
    }
  }

  static PdfColor _color(Color color) => PdfColor(
    (color.r * 255).round(),
    (color.g * 255).round(),
    (color.b * 255).round(),
  );

  static PdfPen _pen(PdfColor color, ArchitectVectorPath op) {
    final join = switch (op.strokeJoin) {
      StrokeJoin.miter => PdfLineJoin.miter,
      StrokeJoin.round => PdfLineJoin.round,
      StrokeJoin.bevel => PdfLineJoin.bevel,
    };
    final cap = switch (op.strokeCap) {
      StrokeCap.butt => PdfLineCap.flat,
      StrokeCap.round => PdfLineCap.round,
      StrokeCap.square => PdfLineCap.square,
    };
    final pen = PdfPen(
      color,
      width: math.max(.01, op.width * pointsPerMm),
      lineCap: cap,
      lineJoin: join,
    );
    if (join == PdfLineJoin.miter) {
      pen.miterLimit = op.strokeMiterLimit > 0 ? op.strokeMiterLimit : 4.0;
    }
    return pen;
  }

  /// Extracts vector polylines while preserving exact sharp corner intersections
  /// and keeping smooth curves within at most 0.005 mm chord deviation.
  @visibleForTesting
  static List<({List<Offset> points, bool closed})> extractPathContours(
    Path path, {
    double curveTolerance = .005,
    double cornerTolerance = .0005,
  }) {
    final result = <({List<Offset> points, bool closed})>[];
    for (final contour in path.computeMetrics()) {
      final totalLength = contour.length;
      if (totalLength <= 1e-7) continue;
      final raw = <Offset>[];
      Offset at(double d) => contour.getTangentForOffset(d)!.position;

      void flatten(double a, double b, int depth) {
        final span = b - a;
        final p = at(a), q = at(b), delta = q - p;
        final chord = delta.distance;
        double error(Offset r) => chord < 1e-12
            ? (r - p).distance
            : ((r - p).dx * delta.dy - (r - p).dy * delta.dx).abs() / chord;
        final ta = contour.getTangentForOffset(a);
        final tb = contour.getTangentForOffset(b);
        if (ta == null || tb == null) {
          raw.add(p);
          return;
        }
        final tm = contour.getTangentForOffset((a + b) * .5);
        final s25 = at(a + span * .25);
        final s50 = at((a + b) * .5);
        final s75 = at(a + span * .75);
        final dotEnds =
            ta.vector.dx * tb.vector.dx + ta.vector.dy * tb.vector.dy;
        final dotMid = tm == null
            ? 1.0
            : ta.vector.dx * tm.vector.dx + ta.vector.dy * tm.vector.dy;
        if ((span - chord).abs() < curveTolerance &&
            dotEnds > .999 &&
            dotMid > .999 &&
            error(s25) < curveTolerance &&
            error(s50) < curveTolerance &&
            error(s75) < curveTolerance) {
          raw.add(p);
          return;
        }
        final cross =
            ta.vector.dx * tb.vector.dy - ta.vector.dy * tb.vector.dx;
        if (cross.abs() > 1e-9) {
          final along = (delta.dx * tb.vector.dy - delta.dy * tb.vector.dx) / cross;
          final corner = p + ta.vector * along;
          final leg1 = (corner - p).distance;
          final leg2Vec = q - corner;
          final leg2 = leg2Vec.distance;
          final forwardEnd =
              leg2Vec.dx * tb.vector.dx + leg2Vec.dy * tb.vector.dy;
          Offset predicted(double d) => d <= leg1
              ? p + ta.vector * d
              : corner + tb.vector * (d - leg1);
          if (along >= -1e-6 &&
              forwardEnd >= -1e-6 &&
              (leg1 + leg2 - span).abs() < cornerTolerance &&
              (s25 - predicted(span * .25)).distance < cornerTolerance &&
              (s50 - predicted(span * .5)).distance < cornerTolerance &&
              (s75 - predicted(span * .75)).distance < cornerTolerance) {
            raw.addAll([p, corner]);
            return;
          }
        }
        if (depth >= 16 ||
            span <= .002 ||
            (chord > 0 &&
                (span - chord).abs() < curveTolerance &&
                dotEnds > .99 &&
                error(s25) < curveTolerance &&
                error(s50) < curveTolerance &&
                error(s75) < curveTolerance)) {
          raw.add(p);
          return;
        }
        final m = (a + b) * .5;
        flatten(a, m, depth + 1);
        flatten(m, b, depth + 1);
      }

      flatten(0, totalLength, 0);
      raw.add(at(totalLength));

      final clean = <Offset>[];
      for (final p in raw) {
        if (clean.isNotEmpty && (p - clean.last).distance < 1e-5) continue;
        while (clean.length >= 2) {
          final a = clean[clean.length - 2], b = clean.last;
          final ab = b - a, bc = p - b;
          final scale = math.max(ab.distance, bc.distance);
          if ((ab.dx * bc.dy - ab.dy * bc.dx).abs() > 1e-6 * scale ||
              ab.dx * bc.dx + ab.dy * bc.dy < 0) {
            break;
          }
          clean.removeLast();
        }
        clean.add(p);
      }

      if (contour.isClosed) {
        if (clean.length > 1 && (clean.last - clean.first).distance < 1e-4) {
          clean.removeLast();
        }
        while (clean.length >= 3) {
          final abFirst = clean.first - clean.last;
          final bcFirst = clean[1] - clean.first;
          final scaleFirst = math.max(abFirst.distance, bcFirst.distance);
          if ((abFirst.dx * bcFirst.dy - abFirst.dy * bcFirst.dx).abs() <=
                  1e-6 * scaleFirst &&
              abFirst.dx * bcFirst.dx + abFirst.dy * bcFirst.dy >= 0) {
            clean.removeAt(0);
            continue;
          }
          final abLast = clean.last - clean[clean.length - 2];
          final bcLast = clean.first - clean.last;
          final scaleLast = math.max(abLast.distance, bcLast.distance);
          if ((abLast.dx * bcLast.dy - abLast.dy * bcLast.dx).abs() <=
                  1e-6 * scaleLast &&
              abLast.dx * bcLast.dx + abLast.dy * bcLast.dy >= 0) {
            clean.removeLast();
            continue;
          }
          break;
        }
      }

      if (clean.length >= 2) {
        result.add((points: clean, closed: contour.isClosed));
      }
    }
    return result;
  }

  /// Curves remain smooth vector polylines within 0.005 mm chord deviation
  /// while polygonal corners preserve exact vertices without chamfering.
  static PdfPath _path(Path path) {
    final result = PdfPath(
      fillMode: path.fillType == PathFillType.evenOdd
          ? PdfFillMode.alternate
          : PdfFillMode.winding,
    );
    for (final contour in extractPathContours(path)) {
      if (contour.closed && contour.points.length >= 3) {
        result.addPolygon([
          for (final p in contour.points) p * pointsPerMm,
        ]);
      } else {
        result.startFigure();
        for (var i = 1; i < contour.points.length; i++) {
          result.addLine(
            contour.points[i - 1] * pointsPerMm,
            contour.points[i] * pointsPerMm,
          );
        }
        if (contour.closed) result.closeFigure();
      }
    }
    return result;
  }
}
