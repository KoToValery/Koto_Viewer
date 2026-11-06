// === SECTION: ARCHITECT DECORATIVE DRAFTING OVERLAY ===
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../core/icons/app_icon.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../models/architect_project.dart';
import '../rendering/architect_2d_painter.dart';
import '../services/architect_command_controller.dart';
import '../services/architect_decorative_geometry.dart';
import '../services/architect_element_tool.dart';
import '../services/architect_projection_editing.dart';
import 'architect_wall_drafting_panel.dart';

class ArchitectDecorativeDraftingOverlay extends StatefulWidget {
  final ArchitectCommandController controller;
  final ArchitectElementTool elementTool;
  final ArchitectTool activeTool;
  final Map<String, Path> paths;
  final Map<String, Path> roofProfiles;
  final Offset origin;
  final Offset right;
  final Offset inward;
  final bool elevation;
  final Offset Function(Offset) toView;
  final Offset Function(Offset) toScreen;
  final void Function(Offset, double, Offset)? onNavigate;
  final double scale;
  final VoidCallback? onOpenStudio;

  const ArchitectDecorativeDraftingOverlay({
    super.key,
    required this.controller,
    required this.elementTool,
    required this.activeTool,
    required this.paths,
    this.roofProfiles = const {},
    required this.origin,
    required this.right,
    required this.inward,
    required this.elevation,
    required this.toView,
    required this.toScreen,
    this.onNavigate,
    required this.scale,
    this.onOpenStudio,
  });

  @override
  State<ArchitectDecorativeDraftingOverlay> createState() =>
      _ArchitectDecorativeDraftingOverlayState();
}

class _ArchitectDecorativeDraftingOverlayState
    extends State<ArchitectDecorativeDraftingOverlay> {
  final List<Offset> _points = [];
  Offset? _cursorView;
  Offset? _snappedPoint;
  bool _isSemiArch = false;
  double _lastScale = 1.0;

  ArchitectProject get _project => widget.controller.project;

  @override
  void didUpdateWidget(covariant ArchitectDecorativeDraftingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeTool != widget.activeTool ||
        oldWidget.elevation != widget.elevation) {
      _points.clear();
      _cursorView = null;
      _snappedPoint = null;
    }
  }

  /// Resolves magnetic vertex/midpoint/orthogonal snap in (X, Z) view coordinates.
  Offset _resolveSnap(Offset rawView) {
    final snapRadius = 12.0 / widget.scale;
    Offset? bestPoint;
    double bestDist = snapRadius;

    // 1. Snap to first drafted point to close polygon
    if (_points.length >= 3) {
      final d = (rawView - _points.first).distance;
      if (d <= snapRadius * 1.3) {
        _snappedPoint = _points.first;
        return _points.first;
      }
    }

    // 2. Snap to vertices and corners of visible projection paths
    for (final path in [...widget.paths.values, ...widget.roofProfiles.values]) {
      final b = path.getBounds();
      for (final corner in [
        b.topLeft,
        b.topRight,
        b.bottomRight,
        b.bottomLeft,
        b.center,
        Offset(b.center.dx, b.top),
        Offset(b.center.dx, b.bottom),
        Offset(b.left, b.center.dy),
        Offset(b.right, b.center.dy),
      ]) {
        final d = (rawView - corner).distance;
        if (d < bestDist) {
          bestDist = d;
          bestPoint = corner;
        }
      }
      for (final metric in path.computeMetrics()) {
        if (metric.length <= 1e-4) continue;
        for (final frac in const [0.0, 0.5, 1.0]) {
          final tangent = metric.getTangentForOffset(metric.length * frac);
          if (tangent == null) continue;
          final d = (rawView - tangent.position).distance;
          if (d < bestDist) {
            bestDist = d;
            bestPoint = tangent.position;
          }
        }
      }
    }

    if (bestPoint != null) {
      _snappedPoint = bestPoint;
      return bestPoint;
    }

    // 3. Orthogonal snap to previous point
    if (_points.isNotEmpty) {
      final last = _points.last;
      final dx = (rawView.dx - last.dx).abs();
      final dy = (rawView.dy - last.dy).abs();
      final orthoTol = 7.0 / widget.scale;
      if (dx < orthoTol && dy > orthoTol) {
        final ortho = Offset(last.dx, rawView.dy);
        _snappedPoint = ortho;
        return ortho;
      }
      if (dy < orthoTol && dx > orthoTol) {
        final ortho = Offset(rawView.dx, last.dy);
        _snappedPoint = ortho;
        return ortho;
      }
    }

    _snappedPoint = null;
    return rawView;
  }

  void _handleTapView(Offset rawView) {
    final pt = _resolveSnap(rawView);

    // Preset placement if a template is active
    final preset = widget.elementTool.activeDecorativePreset;
    if (preset != null &&
        widget.activeTool == ArchitectTool.decorativeProfile) {
      _placePresetAt(pt, preset);
      return;
    }

    switch (widget.activeTool) {
      case ArchitectTool.decorativeProfile:
        if (_points.length >= 3 &&
            (pt - _points.first).distance <= 14.0 / widget.scale) {
          _commitProfile();
          return;
        }
        setState(() {
          _points.add(pt);
          _cursorView = pt;
        });
      case ArchitectTool.decorativeFrame:
      case ArchitectTool.decorativeArc:
      case ArchitectTool.decorativeVoid:
        if (_points.isEmpty) {
          setState(() {
            _points.add(pt);
            _cursorView = pt;
          });
        } else {
          final p1 = _points.first;
          if ((pt - p1).distance >= 0.02) {
            _commitTwoPointTool(p1, pt);
          }
        }
      default:
        break;
    }
  }

  void _placePresetAt(Offset viewPt, ArchitectDecorativeElement preset) {
    final id = ArchitectElementId.next('decor');
    final w = preset.spanLength;
    final h = preset.height;
    final List<Offset> viewContour = [
      for (final p in preset.frontPolygon)
        Offset(viewPt.dx - w / 2 + p.dx, viewPt.dy + p.dy),
    ];
    final created = widget.elevation
        ? ArchitectDecorativeGeometry.createFromElevation(
            id: id,
            project: _project,
            viewOrigin: widget.origin,
            viewRight: widget.right,
            viewInward: widget.inward,
            viewContour: viewContour,
            viewHoles: [
              for (final hole in preset.frontHoles)
                [
                  for (final p in hole)
                    Offset(viewPt.dx - w / 2 + p.dx, viewPt.dy + p.dy),
                ],
            ],
            depth: widget.elementTool.decorativeDepth,
            normalOffset: widget.elementTool.decorativeNormalOffset,
            frameWidth: preset.frameWidth,
            material: widget.elementTool.decorativeMaterial,
            name: preset.name,
          )
        : ArchitectDecorativeGeometry.createFromSection(
            id: id,
            project: _project,
            sectionOrigin: widget.origin,
            sectionRight: widget.right,
            viewProfile: [
              for (final p in preset.sidePolygon)
                Offset(viewPt.dx + p.dx, viewPt.dy + p.dy),
            ],
            spanLength: widget.elementTool.decorativeSpanLength,
            normalOffset: widget.elementTool.decorativeNormalOffset,
            material: widget.elementTool.decorativeMaterial,
            name: preset.name,
          );
    final withProfile = created.element
        .copyWith(
          sidePolygon: preset.sidePolygon,
          sideHoles: preset.sideHoles,
        )
        .withHeight(h);
    widget.controller.execute(
      CreateArchitectDecorativeElement(
        storeyId: created.storeyId,
        element: withProfile,
      ),
    );
  }

  void _commitProfile() {
    if (_points.length < 3) return;
    final id = ArchitectElementId.next('decor');
    final created = widget.elevation
        ? ArchitectDecorativeGeometry.createFromElevation(
            id: id,
            project: _project,
            viewOrigin: widget.origin,
            viewRight: widget.right,
            viewInward: widget.inward,
            viewContour: List<Offset>.from(_points),
            depth: widget.elementTool.decorativeDepth,
            normalOffset: widget.elementTool.decorativeNormalOffset,
            material: widget.elementTool.decorativeMaterial,
          )
        : ArchitectDecorativeGeometry.createFromSection(
            id: id,
            project: _project,
            sectionOrigin: widget.origin,
            sectionRight: widget.right,
            viewProfile: List<Offset>.from(_points),
            spanLength: widget.elementTool.decorativeSpanLength,
            normalOffset: widget.elementTool.decorativeNormalOffset,
            material: widget.elementTool.decorativeMaterial,
          );
    widget.controller.execute(
      CreateArchitectDecorativeElement(
        storeyId: created.storeyId,
        element: created.element,
      ),
    );
    setState(() {
      _points.clear();
      _cursorView = null;
      _snappedPoint = null;
    });
  }

  void _commitTwoPointTool(Offset p1, Offset p2) {
    final rect = Rect.fromPoints(p1, p2);
    if (widget.activeTool == ArchitectTool.decorativeVoid) {
      _commitVoidCutout(rect);
      setState(() {
        _points.clear();
        _cursorView = null;
      });
      return;
    }

    List<Offset> contour;
    double? frameW;
    if (widget.activeTool == ArchitectTool.decorativeFrame) {
      if (rect.width < 0.02 || rect.height < 0.02) return;
      contour = [
        Offset(rect.left, rect.top),
        Offset(rect.right, rect.top),
        Offset(rect.right, rect.bottom),
        Offset(rect.left, rect.bottom),
      ];
      final fw = widget.elementTool.decorativeFrameWidth;
      frameW = (fw > 1e-4 && fw * 2 < math.min(rect.width, rect.height))
          ? fw
          : null;
    } else {
      // Circle or Semicircular Arch
      final radius = (p2 - p1).distance;
      if (radius < 0.02) return;
      if (_isSemiArch) {
        const steps = 20;
        contour = [
          for (var i = 0; i <= steps; i++)
            Offset(
              p1.dx + radius * math.cos(math.pi * (1.0 - i / steps)),
              p1.dy + radius * math.sin(math.pi * (1.0 - i / steps)),
            ),
        ];
      } else {
        const steps = 28;
        contour = [
          for (var i = 0; i < steps; i++)
            Offset(
              p1.dx + radius * math.cos(2 * math.pi * i / steps),
              p1.dy + radius * math.sin(2 * math.pi * i / steps),
            ),
        ];
      }
    }

    final id = ArchitectElementId.next('decor');
    final created = widget.elevation
        ? ArchitectDecorativeGeometry.createFromElevation(
            id: id,
            project: _project,
            viewOrigin: widget.origin,
            viewRight: widget.right,
            viewInward: widget.inward,
            viewContour: contour,
            depth: widget.elementTool.decorativeDepth,
            normalOffset: widget.elementTool.decorativeNormalOffset,
            frameWidth: frameW,
            material: widget.elementTool.decorativeMaterial,
          )
        : ArchitectDecorativeGeometry.createFromSection(
            id: id,
            project: _project,
            sectionOrigin: widget.origin,
            sectionRight: widget.right,
            viewProfile: contour,
            spanLength: widget.elementTool.decorativeSpanLength,
            normalOffset: widget.elementTool.decorativeNormalOffset,
            frameWidth: frameW,
            material: widget.elementTool.decorativeMaterial,
          );
    widget.controller.execute(
      CreateArchitectDecorativeElement(
        storeyId: created.storeyId,
        element: created.element,
      ),
    );
    setState(() {
      _points.clear();
      _cursorView = null;
      _snappedPoint = null;
    });
  }

  void _commitVoidCutout(Rect viewRect) {
    if (viewRect.width < 0.01 || viewRect.height < 0.01) return;
    final center = viewRect.center;
    final hits = ArchitectProjectionEditing.pickAll(
      _project,
      widget.paths,
      center,
      20.0 / widget.scale,
    );
    for (final hitId in hits) {
      final ref = ArchitectProjectionEditing.find(_project, hitId);
      if (ref == null || !ref.isDecorative) continue;
      final decor = ref.storey.decorativeElements.firstWhere(
        (d) => d.id == hitId,
      );
      final bounds = ArchitectDecorativeGeometry.viewBounds(
        ref.storey,
        decor,
        widget.origin,
        widget.right,
      );
      final localHole = [
        Offset(viewRect.left - bounds.left, viewRect.top - bounds.top),
        Offset(viewRect.right - bounds.left, viewRect.top - bounds.top),
        Offset(viewRect.right - bounds.left, viewRect.bottom - bounds.top),
        Offset(viewRect.left - bounds.left, viewRect.bottom - bounds.top),
      ];
      final updated = widget.elevation
          ? decor.copyWith(frontHoles: [...decor.frontHoles, localHole])
          : decor.copyWith(sideHoles: [...decor.sideHoles, localHole]);
      widget.controller.execute(
        UpdateArchitectDecorativeElement(
          storeyId: ref.storey.id,
          element: updated,
        ),
      );
      return;
    }
  }

  Future<void> _promptSegmentLength() async {
    if (_points.isEmpty || _cursorView == null) return;
    final last = _points.last;
    final dir = _cursorView! - last;
    if (dir.distance < 1e-4) return;
    final unit = _project.units;
    double draft = unit.toUnit(dir.distance);
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: SizedBox(
          width: 260,
          child: ArchitectWallDraftingPanel(
            length: draft,
            unit: unit.symbol,
            decimals: _project.distanceDecimals,
            title: ctx.l10n.architectDecorativeLength,
            endLabel: ctx.l10n.save,
            keypadInitiallyOpen: true,
            showContinue: false,
            showDirection: false,
            onLength: (v) => draft = v,
            onEnd: () => Navigator.pop(ctx, draft),
            onContinue: () {},
            onUnlock: () {},
            onCancel: () => Navigator.pop(ctx, null),
          ),
        ),
      ),
    );
    if (result != null && result > 0 && mounted) {
      final lenMetres = unit.fromUnit(result);
      final unitDir = dir / dir.distance;
      final targetPt = last + unitDir * lenMetres;
      if (widget.activeTool == ArchitectTool.decorativeProfile) {
        setState(() {
          _points.add(targetPt);
          _cursorView = targetPt;
        });
      } else {
        _commitTwoPointTool(last, targetPt);
      }
    }
  }

  String _hintText(AppLocalizations l) {
    if (!widget.elevation &&
        widget.activeTool == ArchitectTool.decorativeProfile) {
      return l.architectDecorativeHintSection;
    }
    return switch (widget.activeTool) {
      ArchitectTool.decorativeProfile => l.architectDecorativeHintFacade,
      ArchitectTool.decorativeFrame => l.architectDecorativeHintFrame,
      ArchitectTool.decorativeArc => l.architectDecorativeHintArc,
      ArchitectTool.decorativeVoid => l.architectDecorativeHintVoid,
      _ => l.architectDecorativeHintFacade,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = Theme.of(context).colorScheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        Listener(
          onPointerHover: (event) {
            final viewPt = widget.toView(event.localPosition);
            setState(() {
              _cursorView = _resolveSnap(viewPt);
            });
          },
          onPointerSignal: widget.onNavigate == null
              ? null
              : (event) {
                  if (event is PointerScrollEvent) {
                    widget.onNavigate!(
                      Offset.zero,
                      event.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1,
                      event.localPosition,
                    );
                  }
                },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final rawView = widget.toView(details.localPosition);
              _handleTapView(rawView);
            },
            onScaleStart: (details) {
              _lastScale = 1.0;
              if (details.pointerCount == 1) {
                final rawView = widget.toView(details.localFocalPoint);
                setState(() {
                  _cursorView = _resolveSnap(rawView);
                });
              }
            },
            onScaleUpdate: (details) {
              if (details.pointerCount >= 2) {
                widget.onNavigate?.call(
                  details.focalPointDelta,
                  details.scale / _lastScale,
                  details.localFocalPoint,
                );
                _lastScale = details.scale;
                return;
              }
              final rawView = widget.toView(details.localFocalPoint);
              setState(() {
                _cursorView = _resolveSnap(rawView);
              });
            },
            child: CustomPaint(
              painter: _DecorativeDraftPainter(
                activeTool: widget.activeTool,
                points: _points,
                cursorView: _cursorView,
                snappedPoint: _snappedPoint,
                frameWidth: widget.elementTool.decorativeFrameWidth,
                isSemiArch: _isSemiArch,
                toScreen: widget.toScreen,
                unit: _project.units,
                decimals: _project.distanceDecimals,
              ),
            ),
          ),
        ),

        // Top HUD bar with hint, arch toggle, segment length input, undo/finish
        Positioned(
          top: 8,
          left: 12,
          right: 12,
          child: SafeArea(
            bottom: false,
            child: Center(
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Icon(
                        Icons.architecture,
                        size: 18,
                        color: colors.primary,
                      ),
                      Text(
                        _hintText(l),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (widget.activeTool == ArchitectTool.decorativeArc)
                        FilterChip(
                          visualDensity: VisualDensity.compact,
                          selected: _isSemiArch,
                          label: Text(l.architectToolDecorativeArc),
                          onSelected: (v) => setState(() => _isSemiArch = v),
                        ),
                      if (_points.isNotEmpty && _cursorView != null)
                        ActionChip(
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            _project.formatLength(
                              (_cursorView! - _points.last).distance,
                            ),
                          ),
                          onPressed: _promptSegmentLength,
                        ),
                      if (_points.isNotEmpty)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: l.commandIconUndo,
                          onPressed: () => setState(() {
                            _points.removeLast();
                          }),
                          icon: const AppIcon(AppIconId.undo, size: 18),
                        ),
                      if (_points.length >= 3 &&
                          widget.activeTool == ArchitectTool.decorativeProfile)
                        FilledButton.tonalIcon(
                          key: const ValueKey('decorative-draft-finish'),
                          onPressed: _commitProfile,
                          icon: const AppIcon(AppIconId.confirm, size: 16),
                          label: Text(l.save),
                        ),
                      if (_points.isNotEmpty)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: l.cancel,
                          onPressed: () => setState(() {
                            _points.clear();
                            _cursorView = null;
                          }),
                          icon: const AppIcon(AppIconId.close, size: 18),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DecorativeDraftPainter extends CustomPainter {
  final ArchitectTool activeTool;
  final List<Offset> points;
  final Offset? cursorView;
  final Offset? snappedPoint;
  final double frameWidth;
  final bool isSemiArch;
  final Offset Function(Offset) toScreen;
  final ArchitectUnit unit;
  final int decimals;

  const _DecorativeDraftPainter({
    required this.activeTool,
    required this.points,
    required this.cursorView,
    required this.snappedPoint,
    required this.frameWidth,
    required this.isSemiArch,
    required this.toScreen,
    required this.unit,
    required this.decimals,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = const Color(0xFF00838F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final fillPaint = Paint()
      ..color = const Color(0x2600ACC1)
      ..style = PaintingStyle.fill;

    if (points.isNotEmpty) {
      if (activeTool == ArchitectTool.decorativeProfile) {
        final previewPts = [...points, ?cursorView];
        final screenPts = previewPts.map(toScreen).toList();
        if (screenPts.length >= 3) {
          final poly = Path()..addPolygon(screenPts, true);
          canvas.drawPath(poly, fillPaint);
        }
        for (var i = 0; i + 1 < screenPts.length; i++) {
          canvas.drawLine(screenPts[i], screenPts[i + 1], strokePaint);
        }
        // Closing dashed line preview
        if (screenPts.length >= 3) {
          canvas.drawLine(
            screenPts.last,
            screenPts.first,
            Paint()
              ..color = const Color(0x8800838F)
              ..strokeWidth = 1.2,
          );
        }
        for (var i = 0; i < points.length; i++) {
          final sPt = toScreen(points[i]);
          canvas.drawCircle(
            sPt,
            i == 0 ? 6.0 : 4.0,
            Paint()
              ..color = i == 0
                  ? const Color(0xFF00ACC1)
                  : const Color(0xFF006064),
          );
        }
      } else if ((activeTool == ArchitectTool.decorativeFrame ||
              activeTool == ArchitectTool.decorativeVoid) &&
          cursorView != null) {
        final p1 = points.first;
        final p2 = cursorView!;
        final rectScreen = Rect.fromPoints(toScreen(p1), toScreen(p2));
        final isVoid = activeTool == ArchitectTool.decorativeVoid;
        final path = Path()..addRect(rectScreen);
        if (!isVoid && frameWidth > 1e-4) {
          final rView = Rect.fromPoints(p1, p2);
          if (rView.width > frameWidth * 2 && rView.height > frameWidth * 2) {
            final innerView = rView.deflate(frameWidth);
            final innerScreen = Rect.fromPoints(
              toScreen(innerView.topLeft),
              toScreen(innerView.bottomRight),
            );
            path.fillType = PathFillType.evenOdd;
            path.addRect(innerScreen);
          }
        }
        canvas.drawPath(
          path,
          Paint()
            ..color = isVoid
                ? const Color(0x33D32F2F)
                : const Color(0x2600ACC1),
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = isVoid ? const Color(0xFFD32F2F) : const Color(0xFF00838F)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
        final wMetres = (p2.dx - p1.dx).abs();
        final hMetres = (p2.dy - p1.dy).abs();
        _drawDimensionBadge(
          canvas,
          rectScreen.center,
          '${unit.format(wMetres, decimals: decimals)} × ${unit.format(hMetres, decimals: decimals)}',
        );
      } else if (activeTool == ArchitectTool.decorativeArc &&
          cursorView != null) {
        final center = points.first;
        final radius = (cursorView! - center).distance;
        const steps = 28;
        final viewPts = [
          for (var i = 0; i <= steps; i++)
            if (isSemiArch)
              Offset(
                center.dx + radius * math.cos(math.pi * (1.0 - i / steps)),
                center.dy + radius * math.sin(math.pi * (1.0 - i / steps)),
              )
            else
              Offset(
                center.dx + radius * math.cos(2 * math.pi * i / steps),
                center.dy + radius * math.sin(2 * math.pi * i / steps),
              ),
        ];
        final screenPts = viewPts.map(toScreen).toList();
        final path = Path()..addPolygon(screenPts, true);
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);
        _drawDimensionBadge(
          canvas,
          toScreen(center),
          'R = ${unit.format(radius, decimals: decimals)}',
        );
      }
    }

    // Draw magnetic snap indicator
    if (snappedPoint != null) {
      final at = toScreen(snappedPoint!);
      final snapPaint = Paint()
        ..color = const Color(0xFF00ACC1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawRect(
        Rect.fromCenter(center: at, width: 12, height: 12),
        snapPaint,
      );
      canvas.drawLine(
        at - const Offset(8, 0),
        at + const Offset(8, 0),
        snapPaint,
      );
      canvas.drawLine(
        at - const Offset(0, 8),
        at + const Offset(0, 8),
        snapPaint,
      );
    }
  }

  void _drawDimensionBadge(Canvas canvas, Offset center, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF004D40),
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    final box = Rect.fromCenter(
      center: center,
      width: tp.width + 10,
      height: tp.height + 6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(4)),
      Paint()..color = const Color(0xF0FFFFFF),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(4)),
      Paint()
        ..color = const Color(0xFF00838F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    tp.paint(canvas, Offset(box.left + 5, box.top + 3));
  }

  @override
  bool shouldRepaint(covariant _DecorativeDraftPainter oldDelegate) => true;
}
