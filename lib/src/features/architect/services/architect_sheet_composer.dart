import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../models/architect_project.dart';
import '../rendering/architect_vector_scene.dart';
import 'architect_drawing_publisher.dart';

class ArchitectSheetComposer {
  static String drawingName(ArchitectSavedDrawing d, AppLocalizations l) =>
      d.name.isNotEmpty
      ? d.name
      : switch (d.kind) {
          ArchitectDrawingKind.plan =>
            d.roof ? l.architectRoofPlan : l.architectSheetPlan,
          ArchitectDrawingKind.section => l.architectSectionNumber(
            d.sourceNumber,
          ),
          ArchitectDrawingKind.elevation =>
            '${l.architectFacades} ${d.sourceNumber}',
        };
  static String sheetName(ArchitectSheet s, AppLocalizations l) =>
      s.name.isEmpty ? l.architectSheetName : s.name;
  static List<String> missingSources(
    ArchitectProject p,
    ArchitectSheet sheet,
  ) => [
    for (final place in sheet.placements)
      if (!p.document.drawings.any(
        (d) =>
            d.id == place.drawingId &&
            ArchitectDrawingPublisher.hasSource(p, d),
      ))
        place.number,
  ];
  static ArchitectVectorScene compose(
    ArchitectProject p,
    ArchitectSheet sheet,
    AppLocalizations l, {
    bool allowMissing = false,
    ArchitectPublicationSources sources = const ArchitectPublicationSources(),
  }) {
    final missing = missingSources(p, sheet);
    if (missing.isNotEmpty && !allowMissing) {
      throw StateError(l.architectSheetMissingSource);
    }
    final canvas = ArchitectVectorCanvas();
    canvas.clipRect(Rect.fromLTWH(0, 0, sheet.widthMm, sheet.heightMm));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, sheet.widthMm, sheet.heightMm),
      Paint()..color = Colors.white,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        sheet.marginMm,
        sheet.marginMm,
        sheet.widthMm - 2 * sheet.marginMm,
        sheet.heightMm - 2 * sheet.marginMm,
      ),
      Paint()
        ..color = const Color(0xFF606060)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .18,
    );
    void text(
      String value,
      Offset point,
      double size, {
      Color color = Colors.black,
    }) => canvas.text(
      value,
      point,
      TextStyle(
        fontFamily: 'ArchitectNoto',
        fontSize: size / ArchitectDrawingScale.fontCapRatio,
        color: color,
      ),
      null,
      ArchitectAnnotationRole.ordinary,
    );
    for (final place in sheet.placements) {
      final drawing = p.document.drawings
          .where((d) => d.id == place.drawingId)
          .firstOrNull;
      if (drawing == null || !ArchitectDrawingPublisher.hasSource(p, drawing)) {
        text(
          l.architectSheetMissingSource,
          place.frame.topLeft,
          2.2,
          color: Colors.red,
        );
        continue;
      }
      final scene = ArchitectDrawingPublisher.build(
        p,
        drawing,
        place.scale,
        l,
        sources: sources,
      );
      final unit = 1000 / place.scale;
      canvas.save();
      canvas.clipRect(place.frame);
      canvas.translate(place.frame.left, place.frame.top);
      canvas.rotate(place.rotation * math.pi / 180);
      canvas.translate(-place.anchor.dx * unit, -place.anchor.dy * unit);
      scene.paint(canvas);
      canvas.restore();
      if (place.showTitle) {
        text(
          '${place.number}  ${drawingName(drawing, l)}  1:${place.scale}',
          place.frame.bottomLeft + const Offset(0, 1),
          2.2,
        );
      }
    }
    final template = p.document.templates
        .where((e) => e.id == sheet.templateId)
        .firstOrNull;
    if (template != null && template.items.isNotEmpty) {
      final width = template.items.map((e) => e.rect.right).reduce(math.max);
      final height = template.items.map((e) => e.rect.bottom).reduce(math.max);
      final origin = Offset(
        sheet.widthMm - sheet.marginMm - width,
        sheet.heightMm - sheet.marginMm - height,
      );
      final scales = sheet.placements.map((e) => e.scale).toSet();
      for (final item in template.items) {
        final r = item.rect.shift(origin);
        if (item.border) {
          canvas.drawRect(
            r,
            Paint()
              ..color = Colors.black
              ..style = PaintingStyle.stroke
              ..strokeWidth = .18,
          );
        }
        final value = switch (item.field) {
          ArchitectTitleField.text => item.text,
          ArchitectTitleField.project => p.name,
          ArchitectTitleField.drawing => sheetName(sheet, l),
          ArchitectTitleField.number => sheet.number,
          ArchitectTitleField.scale =>
            scales.length == 1
                ? '1:${scales.single}'
                : scales.isEmpty
                ? '—'
                : l.architectSheetMixedScales,
          ArchitectTitleField.author => sheet.author,
          ArchitectTitleField.date => sheet.date,
        };
        final tp = ArchitectTextPainter(
          text: TextSpan(
            text: value,
            style: TextStyle(
              fontFamily: 'ArchitectNoto',
              fontSize: item.textMm / ArchitectDrawingScale.fontCapRatio,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: math.max(1, r.width - 2));
        final overflow =
            tp.height + 2 > r.height ||
            width > sheet.widthMm - 2 * sheet.marginMm ||
            height > sheet.heightMm - 2 * sheet.marginMm;
        if (overflow && !allowMissing) {
          throw StateError(l.architectSheetTemplateOverflow);
        }
        // Keep all title-block content; long values wrap and the editor exposes
        // cell dimensions so the author can enlarge the template.
        var y = r.top + 1;
        var start = 0;
        for (final line in tp.computeLineMetrics()) {
          final boundary = tp.getLineBoundary(TextPosition(offset: start));
          final end = boundary.end.clamp(start, value.length);
          text(
            value.substring(start, end).replaceAll('\n', ''),
            Offset(r.left + 1, y),
            item.textMm,
            color: overflow ? Colors.red : Colors.black,
          );
          y += line.height;
          start = end;
          if (start < value.length && value[start] == '\n') start++;
        }
      }
    }
    return ArchitectVectorScene(canvas.operations, 1);
  }
}
