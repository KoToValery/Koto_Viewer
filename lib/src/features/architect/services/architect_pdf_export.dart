import 'dart:math' as math;
import 'dart:ui';
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
                pen: op.fill
                    ? null
                    : (PdfPen(
                        color,
                        width: math.max(.01, op.width * pointsPerMm),
                      )..lineJoin = PdfLineJoin.round),
                brush: op.fill ? PdfSolidBrush(color) : null,
              );
            case ArchitectVectorText():
              final isBold = op.weight.value >= 600;
              final key = '${op.size}/$isBold';
              final font = fonts.putIfAbsent(
                key,
                () => PdfTrueTypeFont(
                  isBold ? bold : regular,
                  op.size * pointsPerMm,
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

  /// Curves remain vector polylines with at most .2 mm chord length. This is
  /// independent of screen zoom and preserves contour winding and holes.
  static PdfPath _path(Path path) {
    final result = PdfPath(
      fillMode: path.fillType == PathFillType.evenOdd
          ? PdfFillMode.alternate
          : PdfFillMode.winding,
    );
    for (final contour in path.computeMetrics()) {
      if (contour.length == 0) continue;
      result.startFigure();
      final points = <Offset>[contour.getTangentForOffset(0)!.position];
      final steps = math.max(1, (contour.length / .2).ceil());
      for (var i = 1; i <= steps; i++) {
        final next = contour
            .getTangentForOffset(contour.length * i / steps)!
            .position;
        if (points.length > 1) {
          final a = points[points.length - 2], b = points.last;
          final ab = b - a, bc = next - b;
          if ((ab.dx * bc.dy - ab.dy * bc.dx).abs() < 1e-7 &&
              ab.dx * bc.dx + ab.dy * bc.dy >= 0) {
            points.removeLast();
          }
        }
        points.add(next);
      }
      for (var i = 1; i < points.length; i++) {
        result.addLine(points[i - 1] * pointsPerMm, points[i] * pointsPerMm);
      }
      if (contour.isClosed) result.closeFigure();
    }
    return result;
  }
}
