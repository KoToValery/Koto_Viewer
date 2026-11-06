import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/icons/app_icon.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../bim_editing/geometry/bim_polygon_geometry.dart';
import '../../bim_editing/interaction/bim_polygon_editor.dart';
import '../../bim_editing/interaction/bim_transform_navigation.dart';
import '../../bim_editing/widgets/bim_editing_viewport.dart';
import '../models/architect_project.dart';
import '../rendering/architect_vector_scene.dart';
import '../rendering/architect_picture_cache.dart';
import '../services/architect_sheet_geometry.dart';
import '../services/architect_sheet_layout.dart';

/// Paper-space editing. Camera gestures share the plan's pointer owner, while
/// temporary edits stay outside document history until explicitly completed.
class ArchitectSheetViewport extends StatefulWidget {
  const ArchitectSheetViewport({
    super.key,
    required this.sheet,
    required this.buildScene,
    this.buildContent,
    this.buildBackground,
    this.buildPaper,
    this.contentRevision,
    this.paperRevision,
    this.selectedId,
    required this.onSelect,
    required this.onMove,
    required this.onOpenSource,
    this.pendingPlacement,
    required this.onPlace,
    required this.onCancelPlacement,
    this.cropMode = false,
    required this.onCrop,
    required this.onCancelCrop,
    this.titleBlock,
    this.drawingLabel,
    this.busy = false,
  });

  final ArchitectSheet sheet;
  final ArchitectVectorScene Function(ArchitectSheet) buildScene;
  final ArchitectVectorScene Function(ArchitectDrawingPlacement)? buildContent;
  final ArchitectVectorScene Function(ArchitectSheet, String)? buildBackground;

  /// Supplying paper and content enables separately retained drawing layers.
  /// Content is requested with an uncropped, unrotated placement at the origin.
  /// Paper operations tagged `sheet-title-block` stay above placed drawings.
  final ArchitectVectorScene Function(ArchitectSheet)? buildPaper;

  /// Changes when source geometry, scale styles, visibility or language changes.
  final Object? contentRevision;

  /// Changes when paper/template metadata changes, independently of selection.
  final Object? paperRevision;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  final ValueChanged<ArchitectDrawingPlacement> onMove, onPlace, onCrop;
  final ValueChanged<String> onOpenSource;
  final ArchitectDrawingPlacement? pendingPlacement;
  final VoidCallback onCancelPlacement, onCancelCrop;
  final bool cropMode, busy;
  final Rect? titleBlock;
  final String Function(ArchitectDrawingPlacement)? drawingLabel;

  @override
  State<ArchitectSheetViewport> createState() => ArchitectSheetViewportState();
}

class ArchitectSheetViewportState extends State<ArchitectSheetViewport> {
  final transform = TransformationController();
  late final BimTransformNavigation navigation = BimTransformNavigation(
    controller: transform,
    readSize: () => _size,
    onResize: (size) {
      final previous = _size;
      _size = size;
      if (previous.isEmpty) {
        fitSheet();
      } else {
        // Toolbars must not reset a user's zoom while entering crop mode.
        navigation.panBy(
          Offset(
            (size.width - previous.width) / 2,
            (size.height - previous.height) / 2,
          ),
        );
      }
    },
    minScale: .005,
    maxScale: 100,
  );
  final _editor = BimPolygonEditor<Offset>(
    pointOf: (point) => point,
    isSnapped: (_) => true,
  );
  Size _size = Size.zero;
  Offset? _down, _pointerDown;
  ArchitectDrawingPlacement? _moving, _moveOriginal, _pending;
  ArchitectDrawingPlacement? _cropOriginal, _cropDraft;
  List<Offset>? _boundary, _gestureBoundary;
  bool _rectangle = true, _invalid = false, _snapping = true;
  bool _dragged = false;
  int? _vertex, _edge;
  double? _guideX, _guideY;
  String? _lastTapId;
  Duration? _lastTapTime;
  ArchitectSheet? _cachedSheet;
  ArchitectVectorScene? _cachedScene;
  String? _cachedActiveId;
  ArchitectVectorScene? _cachedContent;
  ArchitectVectorScene? _paperScene;
  ArchitectVectorScene? _paperForegroundScene;
  final _pictures = ArchitectPictureCache();
  final _titleHeights = <(String, double), double>{};

  @visibleForTesting
  int get debugPictureRecordings => _pictures.recordings;
  @visibleForTesting
  int get debugPictureBytes => _pictures.totalBytes;

  ArchitectDrawingPlacement? get selected => widget.sheet.placements
      .where((p) => p.id == widget.selectedId)
      .firstOrNull;
  double get pixelsPerMm => transform.value.getMaxScaleOnAxis();
  Offset paperToScreen(Offset point) =>
      MatrixUtils.transformPoint(transform.value, point);
  Offset screenToPaper(Offset point) => transform.toScene(point);

  void fitSheet() {
    if (_size.isEmpty || !mounted) return;
    final sheet = widget.sheet;
    final zoom = math
        .min(
          _size.width / (sheet.widthMm + 24),
          _size.height / (sheet.heightMm + 24),
        )
        .clamp(.005, 100.0);
    transform.value = Matrix4.identity()
      ..translateByDouble(
        (_size.width - sheet.widthMm * zoom) / 2,
        (_size.height - sheet.heightMm * zoom) / 2,
        0,
        1,
      )
      ..scaleByDouble(zoom, zoom, 1, 1);
  }

  @override
  void initState() {
    super.initState();
    _pending = widget.pendingPlacement;
    _startCrop();
  }

  void _startCrop() {
    if (!widget.cropMode || selected == null || selected!.locked) return;
    _cropOriginal = selected;
    _cropDraft = ArchitectSheetGeometry.valid(selected!)
        ? selected
        : selected!.copyWith(clearCrop: true);
    _boundary = ArchitectSheetGeometry.contour(_cropDraft!);
    _rectangle = _cropDraft!.crop == null;
    _invalid = false;
    _vertex = _edge = null;
  }

  @override
  void didUpdateWidget(covariant ArchitectSheetViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A source, locale or annotation profile may change without replacing the
    // sheet object. The parent owns those source-scene cache dependencies.
    _cachedSheet = null;
    if (widget.paperRevision == null ||
        oldWidget.paperRevision != widget.paperRevision ||
        !identical(oldWidget.sheet, widget.sheet) ||
        oldWidget.pendingPlacement != widget.pendingPlacement) {
      _paperScene = null;
      _paperForegroundScene = null;
    }
    if (oldWidget.contentRevision != widget.contentRevision) _pictures.clear();
    final changedSheet = oldWidget.sheet.id != widget.sheet.id;
    if (!identical(oldWidget.sheet, widget.sheet)) {
      _clearGesture();
      if (oldWidget.cropMode && widget.cropMode) {
        _clearCrop();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onCancelCrop();
        });
      }
    }
    if (oldWidget.pendingPlacement?.id != widget.pendingPlacement?.id) {
      _pending = widget.pendingPlacement;
    }
    if (!widget.cropMode) {
      _clearCrop();
    } else if (!oldWidget.cropMode) {
      _startCrop();
    }
    if (changedSheet ||
        oldWidget.sheet.widthMm != widget.sheet.widthMm ||
        oldWidget.sheet.heightMm != widget.sheet.heightMm) {
      WidgetsBinding.instance.addPostFrameCallback((_) => fitSheet());
    }
  }

  void _clearCrop() {
    _cropOriginal = _cropDraft = null;
    _boundary = null;
    _invalid = false;
    _vertex = _edge = null;
  }

  void _clearGesture() {
    _editor.cancel();
    _moving = _moveOriginal = null;
    _down = _pointerDown = null;
    _gestureBoundary = null;
    _guideX = _guideY = null;
    _dragged = false;
  }

  void _cancelGesture() {
    if (!mounted) return;
    setState(() {
      if (_gestureBoundary != null && _cropOriginal != null) {
        _boundary = _gestureBoundary;
        _cropDraft = ArchitectSheetGeometry.withContour(
          _cropOriginal!,
          _boundary!,
          rectangle: _rectangle,
        );
        _invalid = false;
      }
      _clearGesture();
    });
  }

  String _label(ArchitectDrawingPlacement p) =>
      widget.drawingLabel?.call(p) ?? '${p.number}  1:${p.scale}';

  double _titleWidth(ArchitectDrawingPlacement place) =>
      (place.frame.width * 1000000).round() / 1000000;

  Rect? _titleRect(ArchitectDrawingPlacement place) {
    if (!place.showTitle) return null;
    final label = _label(place), width = _titleWidth(place);
    final key = (label, width);
    if (_titleHeights.length >= 512 && !_titleHeights.containsKey(key)) {
      _titleHeights.remove(_titleHeights.keys.first);
    }
    final height = _titleHeights.putIfAbsent(
      key,
      () => ArchitectSheetLayout.titleHeight(label, width),
    );
    return Rect.fromLTWH(
      place.frame.left,
      place.frame.bottom,
      place.frame.width,
      height,
    );
  }

  bool _hit(ArchitectDrawingPlacement p, Offset point) {
    if (!ArchitectSheetGeometry.valid(p)) {
      return p.frame.isFinite && !p.frame.isEmpty && p.frame.contains(point);
    }
    return ArchitectSheetGeometry.clipPath(p).contains(point) ||
        (_titleRect(p)?.contains(point) ?? false);
  }

  (List<double>, List<double>) _targets() {
    final s = widget.sheet, block = widget.titleBlock;
    return (
      [
        s.marginMm,
        s.widthMm - s.marginMm,
        s.widthMm / 2,
        if (block != null) ...[block.left, block.center.dx, block.right],
        for (final p in s.placements.where(
          (p) => p.id != widget.selectedId,
        )) ...[p.frame.left, p.frame.center.dx, p.frame.right],
      ],
      [
        s.marginMm,
        s.heightMm - s.marginMm,
        s.heightMm / 2,
        if (block != null) ...[block.top, block.center.dy, block.bottom],
        for (final p in s.placements.where(
          (p) => p.id != widget.selectedId,
        )) ...[p.frame.top, p.frame.center.dy, p.frame.bottom],
      ],
    );
  }

  (double, double?) _snapAxis(List<double> targets, List<double> edges) {
    var best = 8 / pixelsPerMm;
    var delta = 0.0;
    double? guide;
    for (final target in targets) {
      for (final edge in edges) {
        if ((target - edge).abs() < best) {
          best = (target - edge).abs();
          delta = target - edge;
          guide = target;
        }
      }
    }
    return (delta, guide);
  }

  Offset _snapPoint(Offset point) {
    _guideX = _guideY = null;
    if (!_snapping) return point;
    final (xs, ys) = _targets();
    final x = _snapAxis(xs, [point.dx]);
    final y = _snapAxis(ys, [point.dy]);
    _guideX = x.$2;
    _guideY = y.$2;
    return point + Offset(x.$1, y.$1);
  }

  ArchitectDrawingPlacement _snapFrame(ArchitectDrawingPlacement place) {
    _guideX = _guideY = null;
    if (!_snapping) return place;
    final (xs, ys) = _targets();
    final r = place.frame;
    final x = _snapAxis(xs, [r.left, r.center.dx, r.right]);
    final y = _snapAxis(ys, [r.top, r.center.dy, r.bottom]);
    _guideX = x.$2;
    _guideY = y.$2;
    return place.copyWith(frame: r.shift(Offset(x.$1, y.$1)));
  }

  void _pointerDownEvent(PointerDownEvent event) {
    if (widget.busy) return;
    final point = screenToPaper(event.localPosition);
    _down = point;
    _pointerDown = event.localPosition;
    _dragged = false;
    if (_pending != null) {
      setState(
        () => _pending = _snapFrame(
          _pending!.copyWith(
            frame: _pending!.frame.shift(point - _pending!.frame.topLeft),
          ),
        ),
      );
      return;
    }
    if (_boundary != null) {
      final started = _editor.start(
        _cropOriginal!.id,
        _boundary!,
        point,
        pixelsPerMm,
        mode: BimPolygonEdgeMode.move,
        offsetLengthPx: 36,
      );
      if (started) {
        setState(() {
          _gestureBoundary = List.of(_boundary!);
          _vertex = _editor.edge ? null : _editor.index;
          _edge = _editor.edge ? _editor.index : null;
          _invalid = false;
        });
      }
      return;
    }
    final p = selected;
    if (p != null && !p.locked && _hit(p, point)) {
      _moveOriginal = p;
      _moving = p;
    }
  }

  void _previewCrop(Offset point) {
    final original = _gestureBoundary!;
    List<Offset>? next;
    if (_rectangle) {
      final bounds = (Path()..addPolygon(original, true)).getBounds();
      final target = _snapPoint(_editor.leaderOrigin! + point - _down!);
      var left = bounds.left, right = bounds.right;
      var top = bounds.top, bottom = bounds.bottom;
      final index = _editor.index!;
      if (_editor.edge) {
        switch (index) {
          case 0:
            top = target.dy;
          case 1:
            right = target.dx;
          case 2:
            bottom = target.dy;
          case 3:
            left = target.dx;
        }
      } else {
        if (index == 0 || index == 3) left = target.dx;
        if (index == 1 || index == 2) right = target.dx;
        if (index == 0 || index == 1) top = target.dy;
        if (index == 2 || index == 3) bottom = target.dy;
      }
      if (right > left && bottom > top) {
        final r = Rect.fromLTRB(left, top, right, bottom);
        next = [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft];
      }
    } else {
      _editor.update(point, _snapPoint, 0);
      if (!_editor.invalid) next = _editor.preview;
    }
    _invalid = next == null || !BimPolygonGeometry.valid(next);
    if (!_invalid) {
      _boundary = List.of(next!);
      _cropDraft = ArchitectSheetGeometry.withContour(
        _cropOriginal!,
        _boundary!,
        rectangle: _rectangle,
      );
    }
  }

  void _pointerMoveEvent(PointerMoveEvent event) {
    if (widget.busy || _down == null) return;
    final point = screenToPaper(event.localPosition);
    _dragged |= (event.localPosition - _pointerDown!).distance > 4;
    setState(() {
      if (_pending != null) {
        _pending = _snapFrame(
          _pending!.copyWith(
            frame: _pending!.frame.shift(point - _pending!.frame.topLeft),
          ),
        );
      } else if (_editor.active) {
        _previewCrop(point);
      } else if (_moveOriginal != null) {
        _moving = _snapFrame(
          _moveOriginal!.copyWith(
            frame: _moveOriginal!.frame.shift(point - _down!),
          ),
        );
      }
    });
  }

  void _pointerHoverEvent(PointerHoverEvent event) {
    if (_pending == null || widget.busy) return;
    final point = screenToPaper(event.localPosition);
    setState(
      () => _pending = _snapFrame(
        _pending!.copyWith(
          frame: _pending!.frame.shift(point - _pending!.frame.topLeft),
        ),
      ),
    );
  }

  Future<void> _selectAt(Offset point, Duration time) async {
    final hits = widget.sheet.placements.reversed
        .where((p) => _hit(p, point))
        .toList();
    String? id;
    if (hits.length > 1) {
      final l = context.l10n;
      id = await showDialog<String>(
        context: context,
        builder: (c) => SimpleDialog(
          title: Text(l.architectSheetSelectDrawing),
          children: [
            for (final p in hits)
              SimpleDialogOption(
                key: ValueKey('architect-sheet-candidate-${p.id}'),
                onPressed: () => Navigator.pop(c, p.id),
                child: Text(_label(p)),
              ),
          ],
        ),
      );
      if (!mounted || id == null) return;
    } else {
      id = hits.firstOrNull?.id;
    }
    if (id != null &&
        id == _lastTapId &&
        _lastTapTime != null &&
        time - _lastTapTime! < const Duration(milliseconds: 350)) {
      _lastTapId = null;
      widget.onOpenSource(hits.firstWhere((p) => p.id == id).drawingId);
    } else {
      _lastTapId = id;
      _lastTapTime = time;
      widget.onSelect(id);
    }
  }

  void _pointerUpEvent(PointerUpEvent event) {
    if (widget.busy || _down == null) return;
    final pending = _pending, moved = _moving;
    final editingCrop = _boundary != null;
    final dragged = _dragged;
    final point = screenToPaper(event.localPosition);
    setState(_clearGesture);
    if (pending != null) {
      widget.onPlace(pending);
    } else if (!editingCrop) {
      if (moved != null && dragged) {
        widget.onMove(moved);
      } else {
        _selectAt(point, event.timeStamp);
      }
    }
  }

  void _changeMode(bool rectangle) {
    setState(() {
      _editor.cancel();
      if (rectangle) {
        final r = (Path()..addPolygon(_boundary!, true)).getBounds();
        _boundary = [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft];
      }
      _rectangle = rectangle;
      _invalid = false;
      _vertex = _edge = null;
      _cropDraft = ArchitectSheetGeometry.withContour(
        _cropOriginal!,
        _boundary!,
        rectangle: rectangle,
      );
    });
  }

  void _addPoint() {
    final index = _edge ?? _vertex ?? 0;
    final next = BimPolygonGeometry.insertMidpoint(_boundary!, index);
    if (next == null) return;
    setState(() {
      _boundary = next;
      _rectangle = false;
      _edge = null;
      _vertex = index + 1;
      _invalid = false;
      _cropDraft = ArchitectSheetGeometry.withContour(_cropOriginal!, next);
    });
  }

  void _removePoint() {
    if (_vertex == null) return;
    final next = BimPolygonGeometry.removeVertex(_boundary!, _vertex!);
    if (next == null) return;
    setState(() {
      _boundary = next;
      _rectangle = false;
      _vertex = _edge = null;
      _invalid = false;
      _cropDraft = ArchitectSheetGeometry.withContour(_cropOriginal!, next);
    });
  }

  ArchitectSheet _shownSheet() => widget.sheet.copyWith(
    placements: [
      for (final p in widget.sheet.placements)
        if (_moving?.id == p.id)
          _moving!
        else if (_cropDraft?.id == p.id)
          _cropDraft!
        else
          p,
      ?_pending,
    ],
  );

  bool _visible(ArchitectDrawingPlacement place, Rect view) {
    final title = _titleRect(place);
    return view.overlaps(place.frame) ||
        (title != null && view.overlaps(title));
  }

  Object _contentKey(ArchitectDrawingPlacement place) {
    final visibility = place.visibilityOverrides.keys.toList()..sort();
    return (
      widget.contentRevision ?? widget.buildContent,
      place.drawingId,
      place.scale,
      [
        for (final key in visibility) '$key:${place.visibilityOverrides[key]}',
      ].join('/'),
    );
  }

  ArchitectCachedPicture _contentPicture(ArchitectDrawingPlacement place) =>
      _pictures.obtain(
        _contentKey(place),
        () => widget.buildContent!(
          place.copyWith(
            frame: Rect.fromLTWH(0, 0, place.frame.width, place.frame.height),
            anchor: Offset.zero,
            rotation: 0,
            clearCrop: true,
          ),
        ),
      );

  ArchitectCachedPicture _titlePicture(ArchitectDrawingPlacement place) {
    // Rect.shift can change the last floating-point bit of width. Such paper
    // differences must not lay out an unchanged title during a drag.
    final label = _label(place);
    final width = _titleWidth(place);
    return _pictures.obtain(('title', label, width), () {
      final canvas = ArchitectVectorCanvas();
      ArchitectSheetLayout.textPainter(
        label,
        2.2,
        width,
      ).paint(canvas, const Offset(0, 1));
      return ArchitectVectorScene(canvas.operations, 1);
    });
  }

  Widget _display(
    ArchitectSheet shown,
    bool layered,
    ArchitectDrawingPlacement? active,
    ArchitectDrawingPlacement? original,
  ) {
    final matrix = transform.value;
    final inverse = Matrix4.inverted(matrix);
    final view = MatrixUtils.transformRect(inverse, Offset.zero & _size);
    final optimized = widget.buildPaper != null && widget.buildContent != null;
    _pictures.beginFrame();
    final layers = <Widget>[];
    ArchitectCachedPicture? content, activeTitle;
    if (optimized) {
      if (_paperScene == null) {
        final paper = widget.buildPaper!(shown);
        final foreground = paper.operations
            .where((op) => op.role == 'sheet-title-block')
            .toList(growable: false);
        _paperScene = foreground.isEmpty
            ? paper
            : ArchitectVectorScene(
                paper.operations
                    .where((op) => op.role != 'sheet-title-block')
                    .toList(growable: false),
                paper.denominator,
              );
        _paperForegroundScene = foreground.isEmpty
            ? null
            : ArchitectVectorScene(foreground, paper.denominator);
      }
      final paper = _pictures.obtain(_paperScene!, () => _paperScene!);
      if (view.overlaps(paper.bounds)) {
        layers.add(
          _PaperDisplayLayer(
            rect: paper.bounds,
            matrix: matrix,
            child: CustomPaint(
              painter: _RecordedScenePainter(
                paper,
                origin: paper.bounds.topLeft,
              ),
            ),
          ),
        );
      }
      for (final place in shown.placements) {
        if (!_visible(place, view)) continue;
        final drawing = _contentPicture(place);
        layers.add(
          _PaperDisplayLayer(
            key: ValueKey('sheet-content-${place.id}'),
            rect: place.frame,
            matrix: matrix,
            child: ClipPath(
              clipper: _PlacementCropClipper(place),
              child: CustomPaint(
                painter: _PlacementContentPainter(drawing, place),
              ),
            ),
          ),
        );
        if (place.showTitle) {
          final title = _titlePicture(place);
          final rect = _titleRect(place)!;
          layers.add(
            _PaperDisplayLayer(
              key: ValueKey('sheet-title-${place.id}'),
              rect: rect,
              matrix: matrix,
              child: CustomPaint(painter: _RecordedScenePainter(title)),
            ),
          );
        }
      }
      // The title block is composed after drawings for print, and retains the
      // same order while temporary placements overlap it in the editor.
      if (_paperForegroundScene case final foregroundScene?) {
        final foreground = _pictures.obtain(
          foregroundScene,
          () => foregroundScene,
        );
        if (view.overlaps(foreground.bounds)) {
          layers.add(
            _PaperDisplayLayer(
              key: const ValueKey('sheet-title-block'),
              rect: foreground.bounds,
              matrix: matrix,
              child: CustomPaint(
                painter: _RecordedScenePainter(
                  foreground,
                  origin: foreground.bounds.topLeft,
                ),
              ),
            ),
          );
        }
      }
    } else {
      final background = _pictures.obtain(_cachedScene!, () => _cachedScene!);
      if (view.overlaps(background.bounds)) {
        layers.add(
          _PaperDisplayLayer(
            rect: background.bounds,
            matrix: matrix,
            child: CustomPaint(
              painter: _RecordedScenePainter(
                background,
                origin: background.bounds.topLeft,
              ),
            ),
          ),
        );
      }
      if (layered && active != null && _visible(active, view)) {
        content = _pictures.obtain(_cachedContent!, () => _cachedContent!);
        if (active.showTitle) activeTitle = _titlePicture(active);
      }
    }
    _pictures.endFrame();
    layers.add(
      Positioned.fill(
        child: CustomPaint(
          key: const ValueKey('architect-sheet-canvas'),
          painter: _SheetViewportPainter(
            sheet: shown,
            matrix: matrix,
            selectedId: widget.selectedId,
            crop: _boundary,
            rectangle: _rectangle,
            invalid: _invalid,
            vertex: _vertex,
            edge: _edge,
            guideX: _guideX,
            guideY: _guideY,
            pendingId: _pending?.id,
            color: Theme.of(context).colorScheme.primary,
            content: content,
            contentOffset: layered && _cropOriginal == null
                ? active!.frame.topLeft - original!.frame.topLeft
                : Offset.zero,
            activePlacement: content == null ? null : active,
            activeTitle: activeTitle,
          ),
        ),
      ),
    );
    return ColoredBox(
      color: const Color(0xffe5e7eb),
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: layers,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final previewing =
        _moving != null || _cropDraft != null || _pending != null;
    final shown = previewing ? _shownSheet() : widget.sheet;
    final original = _moveOriginal ?? _cropOriginal ?? widget.pendingPlacement;
    final active = _moving ?? _cropDraft ?? _pending;
    final layered =
        original != null && active != null && widget.buildContent != null;
    final optimized = widget.buildPaper != null && widget.buildContent != null;
    if (optimized) {
      // Individual source display lists are reused independently of sheet frames.
    } else if (layered) {
      if (!identical(_cachedSheet, widget.sheet) ||
          _cachedActiveId != original.id) {
        _cachedSheet = widget.sheet;
        _cachedActiveId = original.id;
        _cachedScene =
            widget.buildBackground?.call(shown, original.id) ??
            widget.buildScene(
              widget.sheet.copyWith(
                placements: [
                  for (final p in widget.sheet.placements)
                    if (p.id != original.id) p,
                ],
              ),
            );
        _cachedContent = widget.buildContent!(original);
      }
    } else if (!identical(_cachedSheet, shown) || _cachedActiveId != null) {
      _cachedActiveId = null;
      _cachedSheet = shown;
      _cachedScene = widget.buildScene(shown);
    }
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          if (widget.cropMode) {
            widget.onCancelCrop();
          } else if (_pending != null) {
            widget.onCancelPlacement();
          } else {
            _cancelGesture();
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: BimEditingViewport(
              controller: navigation,
              inputKey: const ValueKey('architect-sheet-viewport-input'),
              interactionKey: (
                widget.sheet.id,
                widget.selectedId,
                widget.cropMode,
                widget.pendingPlacement?.id,
                widget.busy,
              ),
              singlePointerPan: true,
              isDraggingHandle: () =>
                  _moving != null || _editor.active || _pending != null,
              onToolDown: _pointerDownEvent,
              onToolMove: _pointerMoveEvent,
              onToolHover: _pointerHoverEvent,
              onToolUp: _pointerUpEvent,
              onToolCancel: _cancelGesture,
              child: AnimatedBuilder(
                animation: transform,
                builder: (_, _) => _display(shown, layered, active, original),
              ),
            ),
          ),
          if (_boundary != null)
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                IconButton(
                                  key: const ValueKey(
                                    'architect-sheet-crop-rectangle',
                                  ),
                                  tooltip: l.architectSheetCropRectangle,
                                  isSelected: _rectangle,
                                  onPressed: () => _changeMode(true),
                                  icon: const AppIcon(AppIconId.rectangle),
                                ),
                                IconButton(
                                  key: const ValueKey(
                                    'architect-sheet-crop-polygon',
                                  ),
                                  tooltip: l.architectSheetCropPolygon,
                                  isSelected: !_rectangle,
                                  onPressed: () => _changeMode(false),
                                  icon: const AppIcon(AppIconId.polygon),
                                ),
                                IconButton(
                                  key: const ValueKey(
                                    'architect-sheet-crop-add-point',
                                  ),
                                  tooltip: l.architectSheetCropAddPoint,
                                  onPressed: _addPoint,
                                  icon: const AppIcon(AppIconId.newPoint),
                                ),
                                IconButton(
                                  key: const ValueKey(
                                    'architect-sheet-crop-remove-point',
                                  ),
                                  tooltip: l.architectSheetCropRemovePoint,
                                  onPressed:
                                      _vertex != null && _boundary!.length > 3
                                      ? _removePoint
                                      : null,
                                  icon: const AppIcon(AppIconId.remove),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('architect-sheet-crop-cancel'),
                          tooltip: l.architectSheetCancel,
                          onPressed: widget.onCancelCrop,
                          icon: const AppIcon(AppIconId.close),
                        ),
                        IconButton.filled(
                          key: const ValueKey('architect-sheet-crop-save'),
                          tooltip: l.architectSheetSave,
                          onPressed: _invalid || _cropDraft == null
                              ? null
                              : () => widget.onCrop(_cropDraft!),
                          icon: const AppIcon(AppIconId.confirm),
                        ),
                      ],
                    ),
                    if (_invalid)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          l.architectSheetCropInvalid,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (_pending != null)
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Row(
                    children: [
                      Expanded(child: Text(l.architectSheetPlaceHint)),
                      IconButton(
                        key: const ValueKey('architect-sheet-place-cancel'),
                        tooltip: l.architectSheetCancel,
                        onPressed: widget.onCancelPlacement,
                        icon: const AppIcon(AppIconId.close),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Material(
              borderRadius: BorderRadius.circular(24),
              child: IconButton(
                key: const ValueKey('architect-sheet-snap'),
                tooltip: l.architectSheetSnap,
                isSelected: _snapping,
                onPressed: () => setState(() {
                  _snapping = !_snapping;
                  _guideX = _guideY = null;
                }),
                icon: const AppIcon(AppIconId.magnet),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pictures.dispose();
    transform.dispose();
    super.dispose();
  }
}

/// The native layer transform moves retained display lists without asking the
/// source painter to record again. Bounds include off-sheet staged drawings.
class _PaperDisplayLayer extends StatelessWidget {
  const _PaperDisplayLayer({
    super.key,
    required this.rect,
    required this.matrix,
    required this.child,
  });
  final Rect rect;
  final Matrix4 matrix;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (rect.isEmpty || !rect.isFinite) return const SizedBox.shrink();
    return Transform(
      transform: matrix,
      alignment: Alignment.topLeft,
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: rect.width,
        maxWidth: rect.width,
        minHeight: rect.height,
        maxHeight: rect.height,
        child: Transform.translate(
          offset: rect.topLeft,
          child: RepaintBoundary(child: SizedBox.expand(child: child)),
        ),
      ),
    );
  }
}

class _RecordedScenePainter extends CustomPainter {
  _RecordedScenePainter(this.entry, {this.origin = Offset.zero});
  final ArchitectCachedPicture entry;
  final Offset origin;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(-origin.dx, -origin.dy);
    canvas.drawPicture(entry.picture);
  }

  @override
  bool shouldRepaint(covariant _RecordedScenePainter old) =>
      !identical(entry, old.entry) || origin != old.origin;
}

class _PlacementContentPainter extends CustomPainter {
  _PlacementContentPainter(this.entry, this.place);
  final ArchitectCachedPicture entry;
  final ArchitectDrawingPlacement place;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.rotate(place.rotation * math.pi / 180);
    final unit = 1000 / place.scale;
    canvas.translate(-place.anchor.dx * unit, -place.anchor.dy * unit);
    canvas.drawPicture(entry.picture);
  }

  @override
  bool shouldRepaint(covariant _PlacementContentPainter old) =>
      !identical(entry, old.entry) ||
      place.rotation != old.place.rotation ||
      place.anchor != old.place.anchor ||
      place.scale != old.place.scale;
}

class _PlacementCropClipper extends CustomClipper<Path> {
  _PlacementCropClipper(this.place);
  final ArchitectDrawingPlacement place;
  @override
  Path getClip(Size size) =>
      Path()..addPolygon(ArchitectSheetGeometry.localContour(place), true);
  @override
  bool shouldReclip(covariant _PlacementCropClipper old) =>
      place.frame.size != old.place.frame.size ||
      !identical(place.crop, old.place.crop);
}

class _SheetViewportPainter extends CustomPainter {
  _SheetViewportPainter({
    required this.sheet,
    required this.matrix,
    required this.selectedId,
    required this.crop,
    required this.rectangle,
    required this.invalid,
    required this.vertex,
    required this.edge,
    required this.guideX,
    required this.guideY,
    required this.pendingId,
    required this.color,
    this.content,
    this.contentOffset = Offset.zero,
    this.activePlacement,
    this.activeTitle,
  });
  final ArchitectSheet sheet;
  final Matrix4 matrix;
  final String? selectedId, pendingId;
  final List<Offset>? crop;
  final bool rectangle, invalid;
  final int? vertex, edge;
  final double? guideX, guideY;
  final Color color;
  final ArchitectCachedPicture? content;
  final Offset contentOffset;
  final ArchitectDrawingPlacement? activePlacement;
  final ArchitectCachedPicture? activeTitle;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.transform(matrix.storage);
    if (content != null && activePlacement != null) {
      canvas.save();
      canvas.clipPath(ArchitectSheetGeometry.clipPath(activePlacement!));
      canvas.translate(contentOffset.dx, contentOffset.dy);
      canvas.drawPicture(content!.picture);
      canvas.restore();
      if (activeTitle != null) {
        canvas.save();
        canvas.translate(
          activePlacement!.frame.left,
          activePlacement!.frame.bottom,
        );
        canvas.drawPicture(activeTitle!.picture);
        canvas.restore();
      }
    }
    final zoom = matrix.getMaxScaleOnAxis();
    final visiblePaper = MatrixUtils.transformRect(
      Matrix4.inverted(matrix),
      Offset.zero & size,
    );
    for (final p in sheet.placements) {
      if (!visiblePaper.overlaps(p.frame)) continue;
      final selected = p.id == selectedId || p.id == pendingId;
      canvas.drawPath(
        ArchitectSheetGeometry.clipPath(p),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = selected ? color : const Color(0xff9ca3af)
          ..strokeWidth = (selected ? 1.5 : .6) / zoom,
      );
    }
    if (guideX != null || guideY != null) {
      final inverse = Matrix4.inverted(matrix);
      final view = MatrixUtils.transformRect(inverse, Offset.zero & size);
      final pen = Paint()
        ..color = color
        ..strokeWidth = 1 / zoom;
      if (guideX != null) {
        canvas.drawLine(
          Offset(guideX!, view.top),
          Offset(guideX!, view.bottom),
          pen,
        );
      }
      if (guideY != null) {
        canvas.drawLine(
          Offset(view.left, guideY!),
          Offset(view.right, guideY!),
          pen,
        );
      }
    }
    final points = crop;
    if (points != null) {
      final pen = Paint()
        ..color = invalid ? const Color(0xffb91c1c) : color
        ..strokeWidth = 1.5 / zoom
        ..style = PaintingStyle.stroke;
      canvas.drawPath(Path()..addPolygon(points, true), pen);
      for (var i = 0; i < points.length; i++) {
        final midpoint = (points[i] + points[(i + 1) % points.length]) / 2;
        for (final (origin, handle, chosen, isVertex) in [
          (
            points[i],
            BimPolygonEditor.offsetVertexHandle(points, i, zoom, 36),
            vertex == i,
            true,
          ),
          (
            midpoint,
            BimPolygonEditor.offsetEdgeHandle(points, i, zoom, 36),
            edge == i,
            false,
          ),
        ]) {
          canvas.drawLine(
            origin,
            handle,
            Paint()
              ..color = pen.color.withValues(alpha: .55)
              ..strokeWidth = .75 / zoom,
          );
          final fill = Paint()..color = chosen ? pen.color : Colors.white;
          final radius = (isVertex ? 4.5 : 3.5) / zoom;
          canvas.drawCircle(handle, radius, fill);
          canvas.drawCircle(handle, radius, pen);
          if (isVertex) {
            canvas.drawRect(
              Rect.fromCenter(
                center: origin,
                width: 6 / zoom,
                height: 6 / zoom,
              ),
              Paint()..color = Colors.white,
            );
            canvas.drawRect(
              Rect.fromCenter(
                center: origin,
                width: 6 / zoom,
                height: 6 / zoom,
              ),
              pen,
            );
          } else {
            canvas.drawCircle(origin, 3 / zoom, Paint()..color = Colors.white);
            canvas.drawCircle(origin, 3 / zoom, pen);
          }
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SheetViewportPainter oldDelegate) => true;
}
