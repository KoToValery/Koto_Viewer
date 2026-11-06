import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../models/architect_project.dart';
import '../rendering/architect_vector_scene.dart';
import 'architect_drawing_publisher.dart';
import 'architect_sheet_geometry.dart';
import 'architect_sheet_layout.dart';

class ArchitectSheetComposer {
  static ArchitectVectorScene _sourceScene(
    ArchitectProject p,
    ArchitectDrawingPlacement place,
    ArchitectSavedDrawing drawing,
    AppLocalizations l,
    ArchitectPublicationSources sources,
    Map<Object, ArchitectVectorScene>? drawingScenes,
  ) {
    final effectiveDrawing = drawing.copyWith(
      visibility: {...drawing.visibility, ...place.visibilityOverrides},
    );
    final key = ArchitectDrawingPublisher.sceneKey(
      effectiveDrawing,
      place.scale,
      l,
      sources: sources,
    );
    ArchitectVectorScene build() => ArchitectDrawingPublisher.build(
      p,
      effectiveDrawing,
      place.scale,
      l,
      sources: sources,
    );
    return drawingScenes?.putIfAbsent(key, build) ?? build();
  }

  /// Uncropped, title-free content in sheet coordinates. An editing gesture can
  /// reuse this layer with a live clip/translation without recording the sheet
  /// or its thousands of source operations again on every pointer movement.
  static ArchitectVectorScene placementContent(
    ArchitectProject p,
    ArchitectDrawingPlacement place,
    AppLocalizations l, {
    ArchitectPublicationSources sources = const ArchitectPublicationSources(),
    Map<Object, ArchitectVectorScene>? drawingScenes,
  }) {
    final drawing = p.document.drawings
        .where((d) => d.id == place.drawingId)
        .firstOrNull;
    if (drawing == null ||
        !ArchitectDrawingPublisher.hasSource(p, drawing) ||
        !ArchitectSheetGeometry.valid(place.copyWith(clearCrop: true))) {
      return const ArchitectVectorScene([], 1);
    }
    final canvas = ArchitectVectorCanvas();
    final unit = 1000 / place.scale;
    canvas.translate(place.frame.left, place.frame.top);
    canvas.rotate(place.rotation * math.pi / 180);
    canvas.translate(-place.anchor.dx * unit, -place.anchor.dy * unit);
    _sourceScene(p, place, drawing, l, sources, drawingScenes).paint(canvas);
    return ArchitectVectorScene(canvas.operations, 1);
  }

  static String drawingName(ArchitectSavedDrawing d, AppLocalizations l) =>
      ArchitectSheetLayout.drawingName(d, l);
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
  static List<String> issues(
    ArchitectProject p,
    ArchitectSheet sheet,
    AppLocalizations l,
  ) => [
    if (missingSources(p, sheet).isNotEmpty) l.architectSheetMissingSource,
    ...ArchitectSheetLayout.issues(
      p,
      sheet,
      l,
      drawingNames: {
        for (final d in p.document.drawings) d.id: drawingName(d, l),
      },
    ),
  ];
  static ArchitectVectorScene compose(
    ArchitectProject p,
    ArchitectSheet sheet,
    AppLocalizations l, {
    bool allowMissing = false,
    bool previewOutsideSheet = false,
    Set<String> excludePlacements = const {},
    ArchitectPublicationSources sources = const ArchitectPublicationSources(),
    Map<Object, ArchitectVectorScene>? drawingScenes,
  }) {
    if (!allowMissing) {
      final blockers = issues(p, sheet, l);
      if (blockers.isNotEmpty) throw StateError(blockers.join('\n'));
    }
    final canvas = ArchitectVectorCanvas();
    canvas.sources(const {}, 'sheet-paper');
    if (!previewOutsideSheet) {
      canvas.clipRect(Rect.fromLTWH(0, 0, sheet.widthMm, sheet.heightMm));
    }
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
      if (excludePlacements.contains(place.id)) continue;
      canvas.sources(const {}, 'sheet');
      if (!ArchitectSheetGeometry.valid(place)) {
        final origin = place.frame.topLeft;
        text(
          l.architectSheetInvalid,
          origin.dx.isFinite && origin.dy.isFinite
              ? origin
              : Offset(sheet.marginMm, sheet.marginMm),
          2.2,
          color: Colors.red,
        );
        continue;
      }
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
      final scene = _sourceScene(p, place, drawing, l, sources, drawingScenes);
      final unit = 1000 / place.scale;
      canvas.save();
      canvas.clipPath(ArchitectSheetGeometry.clipPath(place));
      canvas.translate(place.frame.left, place.frame.top);
      canvas.rotate(place.rotation * math.pi / 180);
      canvas.translate(-place.anchor.dx * unit, -place.anchor.dy * unit);
      scene.paint(canvas);
      canvas.restore();
      canvas.sources(const {}, 'sheet');
      if (place.showTitle) {
        final title =
            '${place.number}  ${drawingName(drawing, l)}  1:${place.scale}';
        final tp = ArchitectSheetLayout.textPainter(
          title,
          2.2,
          place.frame.width,
        );
        tp.paint(canvas, place.frame.bottomLeft + const Offset(0, 1));
      }
    }
    final template = p.document.templates
        .where((e) => e.id == sheet.templateId)
        .firstOrNull;
    if (template != null && template.items.isNotEmpty) {
      canvas.sources(const {}, 'sheet-title-block');
      final width = template.items.map((e) => e.rect.right).reduce(math.max);
      final height = template.items.map((e) => e.rect.bottom).reduce(math.max);
      final origin = Offset(
        sheet.widthMm - sheet.marginMm - width,
        sheet.heightMm - sheet.marginMm - height,
      );
      canvas.drawRect(
        Rect.fromLTWH(origin.dx, origin.dy, width, height),
        Paint()..color = Colors.white,
      );
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
        final value = ArchitectSheetLayout.fieldValue(p, sheet, item, l);
        if (value.isEmpty) continue;
        final tp = ArchitectSheetLayout.textPainter(
          value,
          item.textMm,
          r.width - 2,
        );
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
