import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../models/architect_project.dart';
import '../rendering/architect_2d_painter.dart';
import '../rendering/architect_vector_scene.dart';
import '../rendering/architect_elements_painter_helper.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../../bim_projects/models/bim_coordinate_frame.dart';
import '../widgets/architect_building_sections_screen.dart';
import '../widgets/architect_elevations_screen.dart';
import 'architect_building_section.dart';
import 'architect_building_elevation.dart';

class ArchitectPublicationSources {
  final Map<String, DxfDocument> underlays;
  final Map<String, bool> visibility;
  final BimCoordinateFrame frame;
  const ArchitectPublicationSources({
    this.underlays = const {},
    this.visibility = const {},
    this.frame = const BimCoordinateFrame(),
  });
}

/// Shared scene generation for the working print preview, sheet and PDF.
class ArchitectDrawingPublisher {
  static final _cache = Expando<Map<String, ArchitectVectorScene>>();
  static bool hasSource(ArchitectProject p, ArchitectSavedDrawing drawing) =>
      switch (drawing.kind) {
        ArchitectDrawingKind.plan => p.storeys.any(
          (s) => s.id == drawing.sourceId,
        ),
        ArchitectDrawingKind.section => p.sections.any(
          (s) => s.id == drawing.sourceId,
        ),
        ArchitectDrawingKind.elevation => p.elevations.any(
          (s) => s.id == drawing.sourceId,
        ),
      };

  static ArchitectVectorScene build(
    ArchitectProject p,
    ArchitectSavedDrawing drawing,
    int denominator,
    AppLocalizations l, {
    ArchitectPublicationSources sources = const ArchitectPublicationSources(),
  }) {
    if (!hasSource(p, drawing)) {
      throw StateError('Missing drawing source: ${drawing.id}');
    }
    final key =
        '${drawing.id}/$denominator/${l.localeName}/${drawing.visibility}/${identityHashCode(sources.underlays[drawing.sourceId])}/${sources.frame.hashCode}/${sources.visibility}';
    final cache = _cache[p] ??= {};
    if (cache.containsKey(key)) return cache[key]!;
    final scope = ArchitectTextScope(
      p.document,
      drawing.sourceKey,
      denominator,
      8000 / denominator,
      units: p.units,
      decimals: p.distanceDecimals,
      publication: true,
    );
    final ids = <String>{};
    void collect(Object? value) {
      if (value is Map) {
        if (value['id'] is String) ids.add(value['id'] as String);
        for (final v in value.values) {
          collect(v);
        }
      }
      if (value is List) {
        for (final v in value) {
          collect(v);
        }
      }
    }

    collect(p.toJson()['storeys']);
    final canvas = ArchitectVectorCanvas(sourceIds: ids);
    scope.run(() {
      final scaled = p.copyWith(
        gridAxes: drawing.visibility['axes'] == false ? [] : p.gridAxes,
        dimensionScale: ArchitectDimensionScale.values.firstWhere(
          (s) => s.denominator == denominator,
        ),
      );
      if (drawing.kind == ArchitectDrawingKind.plan) {
        var plan = scaled.copyWith(activeStoreyId: drawing.sourceId);
        final s = plan.activeStorey;
        final visible = drawing.visibility;
        plan = plan.updateActiveStorey(
          s.copyWith(
            zones: visible['zones'] == false ? [] : s.zones,
            dimensions: visible['dimensions'] == false ? [] : s.dimensions,
            annotations: visible['annotations'] == false ? [] : s.annotations,
            elevationMarkers: visible['markers'] == false
                ? []
                : s.elevationMarkers,
          ),
        );
        if (visible['axes'] == false) plan = plan.copyWith(gridAxes: []);
        canvas.scale(1000 / denominator);
        if (drawing.visibility['underlay'] != false &&
            sources.underlays[drawing.sourceId] != null) {
          canvas.save();
          canvas.scale(1 / sources.frame.unitsPerMeter);
          canvas.translate(-sources.frame.origin.dx, -sources.frame.origin.dy);
          ArchitectElementsPainterHelper.drawUnderlay(
            canvas: canvas,
            underlayDoc: sources.underlays[drawing.sourceId],
            zoomScale: scope.renderScale / sources.frame.unitsPerMeter,
            layerVisibility: {
              ...sources.visibility,
              for (final e in drawing.visibility.entries.where(
                (e) => e.key.startsWith('cad:'),
              ))
                e.key.substring(4): e.value,
            },
          );
          canvas.restore();
        }
        Architect2dPainter(
          project: plan,
          l10n: l,
          layer: ArchitectPaintLayer.model,
          paintGrid: false,
          activeTool: ArchitectTool.select,
          zoomScale: scope.renderScale,
        ).paint(canvas, const Size(10000, 10000));
      } else {
        final Rect bounds;
        final CustomPainter painter;
        if (drawing.kind == ArchitectDrawingKind.section) {
          final cut = scaled.sections.firstWhere(
            (s) => s.id == drawing.sourceId,
          );
          final geometry = ArchitectBuildingSection.build(
            scaled,
            cut,
          ).forView(cut);
          final data = ArchitectSectionDrawing(
            scaled,
            cut,
            geometry,
            l,
            const ColorScheme.light(),
            null,
            'ArchitectNoto',
          );
          bounds = data.bounds;
          painter = ArchitectBuildingSectionPainter(
            data,
            bounds.center,
            scope.renderScale,
          );
        } else {
          final view = scaled.elevations.firstWhere(
            (s) => s.id == drawing.sourceId,
          );
          final geometry = ArchitectBuildingElevation.build(scaled, view);
          bounds = geometry.bounds;
          painter = ArchitectFacadePainter(
            geometry,
            bounds.center,
            scope.renderScale,
            fontFamily: 'ArchitectNoto',
          );
        }
        final side =
            math.max(bounds.width, bounds.height) * scope.renderScale + 1000;
        canvas.translate(
          bounds.center.dx * 1000 / denominator - side / 16,
          -bounds.center.dy * 1000 / denominator - side / 16,
        );
        canvas.scale(1 / 8);
        painter.paint(canvas, Size.square(side));
        // View-local manual dimensions, annotations and markers are already
        // maintained separately from the 3D model; render through the same plan
        // annotation pipeline using the established negative-elevation frame.
        final manual = drawing.kind == ArchitectDrawingKind.section
            ? scaled.sections
                  .firstWhere((s) => s.id == drawing.sourceId)
                  .drawing
                  .reflectedHorizontally(
                    scaled.sections
                        .firstWhere((s) => s.id == drawing.sourceId)
                        .length,
                  )
            : scaled.elevations
                  .firstWhere((s) => s.id == drawing.sourceId)
                  .drawing;
        final overlay = scaled.copyWith(
          activeStoreyId: 'publication',
          storeys: [
            ArchitectStorey(
              id: 'publication',
              name: '',
              dimensions: drawing.visibility['dimensions'] == false
                  ? []
                  : manual.dimensions,
              annotations: drawing.visibility['annotations'] == false
                  ? []
                  : manual.annotations,
              elevationMarkers: drawing.visibility['markers'] == false
                  ? []
                  : manual.elevationMarkers,
              cadPrimitives: manual.cadPrimitives,
            ),
          ],
          gridAxes: [],
          sections: [],
          elevations: [],
          clearNorthSymbol: true,
        );
        final overlayCanvas = ArchitectVectorCanvas(sourceIds: ids)
          ..scale(1000 / denominator);
        Architect2dPainter(
          project: overlay,
          l10n: l,
          layer: ArchitectPaintLayer.model,
          paintGrid: false,
          activeTool: ArchitectTool.select,
          zoomScale: scope.renderScale,
        ).paint(overlayCanvas, const Size(10000, 10000));
        canvas.operations.addAll(overlayCanvas.operations);
      }
    });
    return cache[key] = ArchitectVectorScene(
      List.unmodifiable(canvas.operations),
      denominator,
    );
  }
}

class ArchitectStyledPainter extends CustomPainter {
  final CustomPainter inner;
  final ArchitectTextScope scope;
  ArchitectStyledPainter(this.inner, this.scope) : super(repaint: inner);
  @override
  void paint(Canvas canvas, Size size) =>
      scope.run(() => inner.paint(canvas, size));
  @override
  bool shouldRepaint(covariant ArchitectStyledPainter oldDelegate) => true;
}
