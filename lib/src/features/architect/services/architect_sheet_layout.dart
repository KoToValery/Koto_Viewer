import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../models/architect_project.dart';
import '../rendering/architect_vector_scene.dart';
import 'architect_sheet_geometry.dart';

class ArchitectSheetFitException implements Exception {}

/// Paper-space layout rules used by insertion, preview and PDF preflight.
class ArchitectSheetLayout {
  static const gapMm = 4.0;
  static String drawingName(
    ArchitectSavedDrawing drawing,
    AppLocalizations l,
  ) => drawing.name.isNotEmpty
      ? drawing.name
      : switch (drawing.kind) {
          ArchitectDrawingKind.plan =>
            drawing.roof ? l.architectRoofPlan : l.architectSheetPlan,
          ArchitectDrawingKind.section => l.architectSectionNumber(
            drawing.sourceNumber,
          ),
          ArchitectDrawingKind.elevation =>
            '${l.architectFacades} ${drawing.sourceNumber}',
        };
  static Rect paper(ArchitectSheet s) =>
      Rect.fromLTWH(0, 0, s.widthMm, s.heightMm);
  static Rect printable(ArchitectSheet s) => paper(s).deflate(s.marginMm);

  static ArchitectSheetTemplate? template(
    ArchitectProject p,
    ArchitectSheet s,
  ) => p.document.templates.where((t) => t.id == s.templateId).firstOrNull;

  static Rect? titleBlock(ArchitectProject p, ArchitectSheet s) {
    final items = template(p, s)?.items;
    if (items == null || items.isEmpty) return null;
    final width = items.map((e) => e.rect.right).reduce(math.max);
    final height = items.map((e) => e.rect.bottom).reduce(math.max);
    return Rect.fromLTWH(
      s.widthMm - s.marginMm - width,
      s.heightMm - s.marginMm - height,
      width,
      height,
    );
  }

  static Rect drawingArea(ArchitectProject p, ArchitectSheet s) {
    final r = printable(s), title = titleBlock(p, s);
    return Rect.fromLTRB(
      r.left,
      r.top,
      r.right,
      title == null ? r.bottom : math.max(r.top, title.top - gapMm),
    );
  }

  /// Maximal rectangular candidates, including the space beside the title block.
  static List<Rect> freeAreas(
    ArchitectProject p,
    ArchitectSheet s,
    AppLocalizations l, {
    String? excludePlacement,
  }) {
    var areas = [printable(s)];
    final used = <Rect>[
      if (titleBlock(p, s) case final block?) block.inflate(gapMm),
      for (final place in s.placements.where(
        (e) => e.id != excludePlacement && ArchitectSheetGeometry.valid(e),
      ))
        occupiedPath(
          place,
          '${place.number}  ${_placementName(p, place, l)}  1:${place.scale}',
        ).getBounds().inflate(gapMm),
    ];
    for (final occupied in used) {
      final next = <Rect>[];
      for (final area in areas) {
        if (!area.overlaps(occupied)) {
          next.add(area);
          continue;
        }
        final cut = area.intersect(occupied);
        // Keep full-height side candidates as well as full-width upper/lower
        // candidates. They may overlap each other, but never the occupied area.
        next.addAll([
          Rect.fromLTRB(area.left, area.top, area.right, cut.top),
          Rect.fromLTRB(area.left, cut.bottom, area.right, area.bottom),
          Rect.fromLTRB(area.left, area.top, cut.left, area.bottom),
          Rect.fromLTRB(cut.right, area.top, area.right, area.bottom),
        ]);
      }
      final candidates = next
          .where((r) => r.isFinite && r.width >= 20 && r.height >= 20)
          .toSet()
          .toList();
      areas = [
        for (final area in candidates)
          if (!candidates.any(
            (other) =>
                other != area &&
                other.left <= area.left &&
                other.top <= area.top &&
                other.right >= area.right &&
                other.bottom >= area.bottom,
          ))
            area,
      ];
    }
    areas.sort((a, b) => (b.width * b.height).compareTo(a.width * a.height));
    return areas;
  }

  static Rect? freeArea(
    ArchitectProject p,
    ArchitectSheet s,
    AppLocalizations l, {
    String? excludePlacement,
  }) => freeAreas(p, s, l, excludePlacement: excludePlacement).firstOrNull;

  static String _placementName(
    ArchitectProject p,
    ArchitectDrawingPlacement place,
    AppLocalizations l,
  ) {
    final drawing = p.document.drawings
        .where((d) => d.id == place.drawingId)
        .firstOrNull;
    return drawing == null ? '' : drawingName(drawing, l);
  }

  static Rect? titleRect(ArchitectDrawingPlacement place, String title) =>
      place.showTitle
      ? Rect.fromLTWH(
          place.frame.left,
          place.frame.bottom,
          place.frame.width,
          titleHeight(title, place.frame.width),
        )
      : null;

  static Path occupiedPath(ArchitectDrawingPlacement place, String title) {
    final path = ArchitectSheetGeometry.clipPath(place);
    if (titleRect(place, title) case final rect?) path.addRect(rect);
    return path;
  }

  static bool _overlaps(Path a, Path b) {
    if (!a.getBounds().overlaps(b.getBounds())) return false;
    final intersection = Path.combine(
      PathOperation.intersect,
      a,
      b,
    ).getBounds();
    return intersection.width > .00001 && intersection.height > .00001;
  }

  static String fieldValue(
    ArchitectProject p,
    ArchitectSheet s,
    ArchitectTitleItem item,
    AppLocalizations l,
  ) => switch (item.field) {
    ArchitectTitleField.text => item.text,
    ArchitectTitleField.project => p.name,
    ArchitectTitleField.drawing =>
      s.name.isEmpty ? l.architectSheetName : s.name,
    ArchitectTitleField.number => s.number,
    ArchitectTitleField.author => s.author,
    ArchitectTitleField.date => s.date,
    ArchitectTitleField.scale => switch (s.placements
        .map((e) => e.scale)
        .toSet()) {
      final scales when scales.length == 1 => '1:${scales.single}',
      final scales when scales.isEmpty => '—',
      _ => l.architectSheetMixedScales,
    },
  };

  static ArchitectTextPainter textPainter(
    String text,
    double capMm,
    double width,
  ) => ArchitectTextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'ArchitectNoto',
        fontSize: capMm / ArchitectDrawingScale.fontCapRatio,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: math.max(.1, width));

  static double titleHeight(String title, double width) =>
      textPainter(title, 2.2, width).height + 1;

  static bool _contains(Rect outer, Rect inner) =>
      inner.left >= outer.left - .01 &&
      inner.top >= outer.top - .01 &&
      inner.right <= outer.right + .01 &&
      inner.bottom <= outer.bottom + .01;

  /// Returns localized, actionable blockers; crops inside a valid frame are
  /// intentional and are not errors. Empty cells and zero-size rules are valid.
  static List<String> issues(
    ArchitectProject p,
    ArchitectSheet s,
    AppLocalizations l, {
    Map<String, String> drawingNames = const {},
  }) {
    final messages = <String>{};
    if (!s.widthMm.isFinite ||
        !s.heightMm.isFinite ||
        !s.marginMm.isFinite ||
        s.widthMm <= 0 ||
        s.heightMm <= 0 ||
        s.marginMm < 0 ||
        s.marginMm * 2 >= math.min(s.widthMm, s.heightMm)) {
      return [l.architectSheetInvalid];
    }
    final bounds = printable(s), block = titleBlock(p, s);
    final t = template(p, s);
    if (t == null) messages.add(l.architectSheetMissingTemplate);
    if (block != null && !_contains(bounds, block)) {
      messages.add(l.architectSheetTemplateOverflow);
    }
    for (final item in t?.items ?? <ArchitectTitleItem>[]) {
      final value = fieldValue(p, s, item, l);
      if (!item.rect.isFinite ||
          item.rect.width < 0 ||
          item.rect.height < 0 ||
          !item.textMm.isFinite ||
          item.textMm <= 0 ||
          item.rect.left < 0 ||
          item.rect.top < 0) {
        messages.add(l.architectSheetInvalid);
      } else if (value.isNotEmpty &&
          (item.rect.width <= 2 ||
              textPainter(value, item.textMm, item.rect.width - 2).height + 2 >
                  item.rect.height)) {
        messages.add(l.architectSheetTemplateOverflow);
      }
    }
    final occupied = <Path>[];
    for (final place in s.placements) {
      final source = p.document.drawings
          .where((d) => d.id == place.drawingId)
          .firstOrNull;
      if (!ArchitectSheetGeometry.valid(place)) {
        messages.add(l.architectSheetInvalid);
        continue;
      }
      final name = drawingNames[place.drawingId] ?? source?.name ?? '';
      final title = '${place.number}  $name  1:${place.scale}';
      final path = occupiedPath(place, title);
      if (!_contains(bounds, path.getBounds())) {
        messages.add(l.architectSheetOutside);
      }
      if (block != null && _overlaps(path, Path()..addRect(block))) {
        messages.add(l.architectSheetTitleOverlap);
      }
      if (occupied.any((other) => _overlaps(other, path))) {
        messages.add(l.architectSheetOverlap);
      }
      occupied.add(path);
    }
    return messages.toList();
  }

  /// Try every candidate; prefer retaining the largest drawing scale.
  static ArchitectDrawingPlacement fitAreas(
    ArchitectDrawingPlacement place,
    List<Rect> areas,
    ArchitectVectorScene Function(int scale) build, {
    required String Function(int scale) title,
  }) {
    ArchitectDrawingPlacement? best;
    final scenes = <int, ArchitectVectorScene>{};
    for (final area in areas) {
      try {
        final candidate = fit(
          place,
          area,
          (scale) => scenes.putIfAbsent(scale, () => build(scale)),
          title: title,
        );
        if (best == null || candidate.scale < best.scale) best = candidate;
      } on ArchitectSheetFitException {
        // A narrow candidate can fail while another candidate still fits.
      }
    }
    if (best == null) throw ArchitectSheetFitException();
    return best;
  }

  /// Scale changes regenerate annotation sizes. The caller rebuilds the scene
  /// at each proposed scale rather than shrinking already laid out lettering.
  static ArchitectDrawingPlacement fit(
    ArchitectDrawingPlacement place,
    Rect area,
    ArchitectVectorScene Function(int scale) build, {
    required String Function(int scale) title,
  }) {
    if (!area.isFinite ||
        area.width <= gapMm ||
        area.height <= gapMm ||
        place.scale <= 0) {
      throw ArchitectSheetFitException();
    }
    var scale = place.scale;
    final scenes = <int, ArchitectVectorScene>{};
    ArchitectVectorScene sceneAt(int value) =>
        scenes.putIfAbsent(value, () => build(value));
    late ArchitectVectorScene scene;
    late double titleMm;
    final radians = place.rotation * math.pi / 180;
    Offset rotate(Offset p, double angle) => Offset(
      p.dx * math.cos(angle) - p.dy * math.sin(angle),
      p.dx * math.sin(angle) + p.dy * math.cos(angle),
    );
    Rect rotatedBounds(ArchitectVectorScene scene) =>
        (Path()..addPolygon([
              for (final point in [
                scene.bounds.topLeft,
                scene.bounds.topRight,
                scene.bounds.bottomRight,
                scene.bounds.bottomLeft,
              ])
                rotate(point, radians),
            ], true))
            .getBounds();
    for (var attempt = 0; attempt < 8; attempt++) {
      titleMm = place.showTitle ? titleHeight(title(scale), area.width) : 0;
      if (titleMm + gapMm >= area.height) throw ArchitectSheetFitException();
      scene = sceneAt(scale);
      final bounds = rotatedBounds(scene);
      final factor = math.max(
        (bounds.width + gapMm) / area.width,
        (bounds.height + gapMm) / math.max(1.0, area.height - titleMm),
      );
      if (factor <= 1.001) break;
      final minimum = (scale * factor).ceil();
      final next =
          ArchitectDrawingScale.presets
              .where((n) => n >= minimum)
              .firstOrNull ??
          minimum;
      scale = next;
    }
    scene = sceneAt(scale);
    final bounds = rotatedBounds(scene);
    titleMm = place.showTitle ? titleHeight(title(scale), area.width) : 0;
    if (bounds.width + gapMm > area.width + .01 ||
        bounds.height + gapMm + titleMm > area.height + .01) {
      throw ArchitectSheetFitException();
    }
    final titleWidth = place.showTitle
        ? textPainter(title(scale), 2.2, double.infinity).width
        : 0.0;
    final width = math.max(
      bounds.width + gapMm,
      math.min(area.width, titleWidth),
    );
    return place.copyWith(
      clearCrop: true,
      scale: scale,
      frame: Rect.fromLTWH(area.left, area.top, width, bounds.height + gapMm),
      anchor:
          rotate(
            bounds.topLeft - const Offset(gapMm / 2, gapMm / 2),
            -radians,
          ) *
          (scale / 1000),
    );
  }
}
