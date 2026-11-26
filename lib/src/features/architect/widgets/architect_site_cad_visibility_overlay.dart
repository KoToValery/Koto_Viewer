import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extensions.dart';
import '../../bim_editing/geometry/bim_coordinate_frame.dart';
import '../../bim_editing/interaction/bim_viewport_controller.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../../dxf_viewer/rendering/dxf_snap_helper.dart';
import '../models/architect_underlay_models.dart';
import '../rendering/architect_cad_underlay_renderer.dart';
import '../rendering/architect_canvas_palette.dart';
import '../rendering/architect_snap_helper.dart';
import '../services/architect_cad_entity_visibility.dart';
import '../services/architect_underlay_clip.dart';
import 'architect_transform_point_input.dart';

class ArchitectSiteCadVisibilityOverlay extends StatefulWidget {
  final DxfDocument source;
  final ArchitectCadUnderlayConfig config;
  final BimCoordinateFrame frame;
  final BimViewportController viewport;
  final ArchitectCanvasPalette palette;
  final void Function(int index, bool hidden) onChange;
  final VoidCallback onClose;

  const ArchitectSiteCadVisibilityOverlay({
    super.key,
    required this.source,
    required this.config,
    required this.frame,
    required this.viewport,
    required this.palette,
    required this.onChange,
    required this.onClose,
  });

  @override
  State<ArchitectSiteCadVisibilityOverlay> createState() => _VisibilityState();
}

class _VisibilityState extends State<ArchitectSiteCadVisibilityOverlay> {
  bool _showHidden = false;
  List<DxfEntity> _hover = const [], _choices = const [];
  int _choice = 0;

  DxfEntity? get _selected => _choices.isEmpty ? null : _choices[_choice];
  List<Offset>? get _mask =>
      widget.config.hasActiveMask ? widget.config.maskPolygon : null;

  DxfDocument get _target => _showHidden
      ? ArchitectCadEntityVisibility.hidden(
          widget.source,
          widget.config.siteHiddenEntities,
        )
      : ArchitectCadEntityVisibility.visible(
          widget.source,
          widget.config.siteHiddenEntities,
        );

  void _clear() {
    _hover = _choices = const [];
    _choice = 0;
  }

  ArchitectSnapResult _aim(Offset point, bool touch) {
    final doc = _target;
    if (ArchitectUnderlayClip.contains(_mask, point)) {
      doc.orBuildSpatialIndex;
      _hover = DxfSnapHelper.hitTestEntities(
        document: doc,
        cadPoint: widget.frame.toCad(point),
        toleranceCad:
            (touch ? 12 : 8) *
            widget.frame.unitsPerMeter /
            widget.viewport.scale,
        layerVisibility: widget.config.layerOverrides,
      );
    } else {
      _hover = const [];
    }
    return ArchitectSnapResult(point: point);
  }

  void _apply() {
    final selected = _selected;
    if (selected == null) return;
    final index = ArchitectCadEntityVisibility.indexOf(widget.source, selected);
    setState(_clear);
    if (index != null) widget.onChange(index, !_showHidden);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final selected = _selected;
    final highlighted = selected ?? _hover.firstOrNull;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _VisibilityPreview(
                viewport: widget.viewport,
                frame: widget.frame,
                palette: widget.palette,
                config: widget.config,
                hidden: _showHidden ? _target : null,
                highlight: highlighted == null
                    ? null
                    : ArchitectCadEntityVisibility.selected(
                        widget.source,
                        highlighted,
                      ),
                highlightColor: colors.primary,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: ArchitectTransformPointInput(
            key: const ValueKey('architect-site-cad-visibility-input'),
            toModel: widget.viewport.toModel,
            toScreen: widget.viewport.toScreen,
            snap: _aim,
            localizeSnap: (_) => null,
            onAim: (_) => setState(() {}),
            onPick: (_) => setState(() => _choices = _hover),
            pickingEnabled: selected == null,
            singlePointerPan: true,
            onNavigate: (delta, factor, focal) => widget.viewport.navigate(
              previousFocal: focal - delta,
              focal: focal,
              scaleFactor: factor,
            ),
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(10),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _showHidden
                              ? l.architectSitePickHiddenCad
                              : l.architectSitePickVisibleCad,
                        ),
                      ),
                      IconButton(
                        key: const ValueKey(
                          'architect-site-cad-visibility-close',
                        ),
                        tooltip: l.close,
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      FilterChip(
                        key: const ValueKey('architect-site-cad-show-hidden'),
                        label: Text(l.architectSiteShowHiddenCad),
                        selected: _showHidden,
                        onSelected: (value) => setState(() {
                          _clear();
                          _showHidden = value;
                        }),
                      ),
                      if (_choices.length > 1)
                        TextButton(
                          onPressed: () => setState(
                            () => _choice = (_choice + 1) % _choices.length,
                          ),
                          child: Text(l.architectSiteNextCadEntity),
                        ),
                      if (selected != null) ...[
                        IconButton(
                          tooltip: l.cancel,
                          onPressed: () => setState(_clear),
                          icon: const Icon(Icons.clear),
                        ),
                        FilledButton(
                          key: const ValueKey(
                            'architect-site-cad-visibility-apply',
                          ),
                          onPressed: _apply,
                          child: Text(
                            _showHidden
                                ? l.architectSiteRestoreCad
                                : l.architectSiteHideCad,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VisibilityPreview extends CustomPainter {
  final BimViewportController viewport;
  final BimCoordinateFrame frame;
  final ArchitectCanvasPalette palette;
  final ArchitectCadUnderlayConfig config;
  final DxfDocument? hidden, highlight;
  final Color highlightColor;

  _VisibilityPreview({
    required this.viewport,
    required this.frame,
    required this.palette,
    required this.config,
    required this.hidden,
    required this.highlight,
    required this.highlightColor,
  }) : super(repaint: viewport);

  @override
  void paint(Canvas canvas, Size size) {
    if (hidden == null && highlight == null) return;
    canvas.save();
    viewport.applyToCanvas(canvas);
    if (config.hasActiveMask) {
      canvas.clipPath(Path()..addPolygon(config.maskPolygon!, true));
    }
    void paint(DxfDocument document, Color color) {
      if (document.entities.isEmpty) return;
      paintArchitectCadUnderlay(
        canvas: canvas,
        size: size,
        document: document,
        frame: frame,
        visibleModel: viewport.visibleRect,
        viewportScale: viewport.scale,
        palette: palette,
        visibility: config.layerOverrides,
        overlayColor: color,
      );
    }

    if (hidden != null) {
      paint(hidden!, palette.foreground(Colors.grey).withValues(alpha: .68));
    }
    if (highlight != null) paint(highlight!, highlightColor);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_VisibilityPreview old) =>
      old.hidden != hidden ||
      old.highlight != highlight ||
      old.frame != frame ||
      old.config != config ||
      old.highlightColor != highlightColor ||
      old.palette.isDark != palette.isDark;
}
