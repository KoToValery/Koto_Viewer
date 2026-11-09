// === SECTION: ARCHITECT CAD POINT PICKER DIALOG ===

import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/icons/app_icon.dart';
import '../../../core/l10n/l10n_extensions.dart';
import '../../bim_projects/controllers/bim_viewport_controller.dart';
import '../../dxf_viewer/models/dxf_models.dart';
import '../../dxf_viewer/rendering/dxf_snap_helper.dart';
import '../rendering/architect_canvas_palette.dart';
import '../rendering/architect_elements_painter_helper.dart';

/// Interactive modal dialog allowing users to pan/zoom a CAD underlay,
/// magnetically snap to axes, intersections, or corners, and choose a base control point.
class ArchitectCadPointPickerDialog extends StatefulWidget {
  final DxfDocument document;
  final String fileName;
  final Offset? initialCadPoint;
  final double unitsPerMeter;

  const ArchitectCadPointPickerDialog({
    super.key,
    required this.document,
    required this.fileName,
    this.initialCadPoint,
    this.unitsPerMeter = 1.0,
  });

  static Future<Offset?> show({
    required BuildContext context,
    required DxfDocument document,
    required String fileName,
    Offset? initialCadPoint,
    double unitsPerMeter = 1.0,
  }) {
    return showDialog<Offset>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => ArchitectCadPointPickerDialog(
        document: document,
        fileName: fileName,
        initialCadPoint: initialCadPoint,
        unitsPerMeter: unitsPerMeter,
      ),
    );
  }

  @override
  State<ArchitectCadPointPickerDialog> createState() =>
      _ArchitectCadPointPickerDialogState();
}

class _ArchitectCadPointPickerDialogState
    extends State<ArchitectCadPointPickerDialog> {
  final BimViewportController _viewport = BimViewportController();
  bool _initializedFit = false;

  Offset? _selectedCadPoint;
  DxfSnapResult? _hoverSnap;
  Offset? _hoverCadPoint;
  Offset _previousFocal = Offset.zero;

  @override
  void initState() {
    super.initState();
    _selectedCadPoint = widget.initialCadPoint ?? widget.document.bounds.center;
  }

  void _fitToBounds(Size size) {
    if (_initializedFit || size.isEmpty) return;
    _initializedFit = true;
    _viewport.resize(size);
    final bounds = widget.document.bounds;
    if (bounds.isFinite && !bounds.isEmpty) {
      _viewport.fit(bounds, padding: 48);
      if (widget.initialCadPoint != null) {
        // Center on initialCadPoint
        _viewport.panBy(size.center(Offset.zero) - _viewport.toScreen(widget.initialCadPoint!));
      }
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    _previousFocal = details.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    _viewport.navigate(
      previousFocal: _previousFocal,
      focal: details.localFocalPoint,
      scaleFactor: details.scale,
    );
    _previousFocal = details.localFocalPoint;
    _updateHoverAndSnap(details.localFocalPoint);
  }

  void _onPointerHover(PointerHoverEvent event) {
    _updateHoverAndSnap(event.localPosition);
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final zoomFactor = event.scrollDelta.dy < 0 ? 1.15 : 0.85;
      _viewport.navigate(
        previousFocal: event.localPosition,
        focal: event.localPosition,
        scaleFactor: zoomFactor,
      );
      _updateHoverAndSnap(event.localPosition);
    }
  }

  void _updateHoverAndSnap(Offset localScreen) {
    final rawCad = _viewport.toModel(localScreen);
    final toleranceCad = 16.0 / math.max(_viewport.scale, 0.001);
    final snap = DxfSnapHelper.findSnapPoint(
      document: widget.document,
      cadPoint: rawCad,
      toleranceCad: toleranceCad,
      includeIntersections: true,
      allowNearest: true,
    );
    setState(() {
      _hoverCadPoint = rawCad;
      _hoverSnap = snap;
    });
  }

  void _onTapUp(TapUpDetails details) {
    final localScreen = details.localPosition;
    final rawCad = _viewport.toModel(localScreen);
    final toleranceCad = 18.0 / math.max(_viewport.scale, 0.001);
    final snap = DxfSnapHelper.findSnapPoint(
      document: widget.document,
      cadPoint: rawCad,
      toleranceCad: toleranceCad,
      includeIntersections: true,
      allowNearest: true,
    );
    setState(() {
      _selectedCadPoint = snap?.point ?? rawCad;
      _hoverSnap = snap;
    });
  }

  String _formatSnapType(DxfSnapType type, BuildContext context) {
    final l = context.l10n;
    switch (type) {
      case DxfSnapType.intersection:
      case DxfSnapType.apparentIntersection:
        return l.architectUnderlaySnapIntersection;
      case DxfSnapType.endpoint:
        return l.architectUnderlaySnapEndpoint;
      case DxfSnapType.midpoint:
        return l.architectUnderlaySnapMidpoint;
      case DxfSnapType.center:
        return l.architectUnderlaySnapCenter;
      case DxfSnapType.nearest:
      case DxfSnapType.point:
      case DxfSnapType.perpendicular:
      case DxfSnapType.quadrant:
        return l.architectUnderlaySnapNearest;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final media = MediaQuery.of(context);
    final isCompact = media.size.width < 640;

    final dialogContent = Material(
      color: const Color(0xFF131720),
      borderRadius: isCompact ? null : BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // 1. Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1A212E),
              border: Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const AppIcon(
                    AppIconId.newPoint,
                    color: Color(0xFF00E676),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l.architectUnderlayPickPointTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l.cancel,
                  onPressed: () => Navigator.of(context).pop(null),
                  icon: const AppIcon(AppIconId.close, color: Colors.white70),
                ),
              ],
            ),
          ),

          // 2. Preset Chips & Instructions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            color: const Color(0xFF161B26),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.architectUnderlayPickPointInstruction,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF81D4FA),
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  avatar: const AppIcon(AppIconId.newPoint, size: 14),
                  label: Text(
                    l.architectUnderlayPresetOrigin,
                    style: const TextStyle(fontSize: 11),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedCadPoint = Offset.zero;
                    });
                    _viewport.panBy(
                      _viewport.size.center(Offset.zero) -
                          _viewport.toScreen(Offset.zero),
                    );
                  },
                ),
                const SizedBox(width: 6),
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  avatar: const AppIcon(AppIconId.fitView, size: 14),
                  label: Text(
                    l.architectUnderlayPresetCenter,
                    style: const TextStyle(fontSize: 11),
                  ),
                  onPressed: () {
                    final c = widget.document.bounds.center;
                    setState(() {
                      _selectedCadPoint = c;
                    });
                    _viewport.panBy(
                      _viewport.size.center(Offset.zero) - _viewport.toScreen(c),
                    );
                  },
                ),
              ],
            ),
          ),

          // 3. Interactive CAD Canvas
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                _fitToBounds(size);

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Listener(
                      onPointerHover: _onPointerHover,
                      onPointerSignal: _onPointerSignal,
                      child: GestureDetector(
                        onScaleStart: _onScaleStart,
                        onScaleUpdate: _onScaleUpdate,
                        onTapUp: _onTapUp,
                        child: AnimatedBuilder(
                          animation: _viewport,
                          builder: (context, _) => CustomPaint(
                            size: size,
                            painter: _CadPickerPainter(
                              document: widget.document,
                              viewport: _viewport,
                              selectedCadPoint: _selectedCadPoint,
                              hoverSnap: _hoverSnap,
                              hoverCadPoint: _hoverCadPoint,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Top-right Snap Badge
                    if (_hoverSnap != null)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xDD000000),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF00E676),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF00E676),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formatSnapType(_hoverSnap!.type, context),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),

          // 4. Bottom Coordinate Readout & Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF1A212E),
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                if (_selectedCadPoint != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'X: ${_selectedCadPoint!.dx.toStringAsFixed(3)} m   Y: ${_selectedCadPoint!.dy.toStringAsFixed(3)} m',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: Color(0xFF00E676),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ] else
                  const Text(
                    '—',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                  ),
                  child: Text(l.cancel),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _selectedCadPoint != null
                      ? () => Navigator.of(context).pop(_selectedCadPoint)
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00C853),
                    foregroundColor: Colors.white,
                  ),
                  icon: const AppIcon(AppIconId.confirm, size: 16),
                  label: Text(l.architectUnderlayPickPointConfirm),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (isCompact) {
      return Dialog.fullscreen(child: dialogContent);
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 960,
          maxHeight: 740,
        ),
        child: dialogContent,
      ),
    );
  }
}

/// Custom painter for the CAD control point picker dialog.
class _CadPickerPainter extends CustomPainter {
  final DxfDocument document;
  final BimViewportController viewport;
  final Offset? selectedCadPoint;
  final DxfSnapResult? hoverSnap;
  final Offset? hoverCadPoint;

  _CadPickerPainter({
    required this.document,
    required this.viewport,
    this.selectedCadPoint,
    this.hoverSnap,
    this.hoverCadPoint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    // 1. Subtle background grid
    _paintGrid(canvas, size);

    // 2. CAD entities
    canvas.save();
    canvas.translate(viewport.translation.dx, viewport.translation.dy);
    canvas.scale(viewport.scale);

    ArchitectElementsPainterHelper.drawUnderlay(
      canvas: canvas,
      palette: const ArchitectCanvasPalette.dark(),
      underlayDoc: document,
      zoomScale: viewport.scale,
      layerVisibility: const {},
      visibleRect: viewport.visibleRect.inflate(30.0 / viewport.scale),
    );

    canvas.restore();

    // 3. Hover snap marker
    if (hoverSnap != null) {
      final screenPt = viewport.toScreen(hoverSnap!.point);
      _paintSnapMarker(canvas, screenPt, hoverSnap!.type);
    }

    // 4. Selected base control point marker
    if (selectedCadPoint != null) {
      final screenPt = viewport.toScreen(selectedCadPoint!);
      _paintSelectedTarget(canvas, screenPt);
    }

    canvas.restore();
  }

  void _paintGrid(Canvas canvas, Size size) {
    const double gridSize = 40.0;
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1.0;

    final startX = viewport.translation.dx % gridSize;
    for (double x = startX; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    final startY = viewport.translation.dy % gridSize;
    for (double y = startY; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  void _paintSnapMarker(Canvas canvas, Offset screenPt, DxfSnapType type) {
    final strokePaint = Paint()
      ..color = const Color(0xFF00E676)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    const double s = 8.0;
    switch (type) {
      case DxfSnapType.intersection:
      case DxfSnapType.apparentIntersection:
        // Draw an X
        canvas.drawLine(
          screenPt + const Offset(-s, -s),
          screenPt + const Offset(s, s),
          strokePaint,
        );
        canvas.drawLine(
          screenPt + const Offset(-s, s),
          screenPt + const Offset(s, -s),
          strokePaint,
        );
      case DxfSnapType.endpoint:
        // Draw square
        canvas.drawRect(
          Rect.fromCenter(center: screenPt, width: s * 2, height: s * 2),
          strokePaint,
        );
      case DxfSnapType.midpoint:
        // Draw triangle
        final path = Path()
          ..moveTo(screenPt.dx, screenPt.dy - s)
          ..lineTo(screenPt.dx + s, screenPt.dy + s)
          ..lineTo(screenPt.dx - s, screenPt.dy + s)
          ..close();
        canvas.drawPath(path, strokePaint);
      case DxfSnapType.center:
        // Draw circle
        canvas.drawCircle(screenPt, s, strokePaint);
      case DxfSnapType.nearest:
      case DxfSnapType.point:
      case DxfSnapType.perpendicular:
      case DxfSnapType.quadrant:
        // Draw diamond
        final path = Path()
          ..moveTo(screenPt.dx, screenPt.dy - s)
          ..lineTo(screenPt.dx + s, screenPt.dy)
          ..lineTo(screenPt.dx, screenPt.dy + s)
          ..lineTo(screenPt.dx - s, screenPt.dy)
          ..close();
        canvas.drawPath(path, strokePaint);
    }
  }

  void _paintSelectedTarget(Canvas canvas, Offset screenPt) {
    // Outer glowing ring
    final glowPaint = Paint()
      ..color = const Color(0xFF00E676).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(screenPt, 16.0, glowPaint);

    final ringPaint = Paint()
      ..color = const Color(0xFF00E676)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(screenPt, 10.0, ringPaint);

    // Inner crosshairs
    const double arm = 18.0;
    final crossPaint = Paint()
      ..color = const Color(0xFF00E676)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawLine(
      screenPt + const Offset(-arm, 0),
      screenPt + const Offset(-4, 0),
      crossPaint,
    );
    canvas.drawLine(
      screenPt + const Offset(4, 0),
      screenPt + const Offset(arm, 0),
      crossPaint,
    );
    canvas.drawLine(
      screenPt + const Offset(0, -arm),
      screenPt + const Offset(0, -4),
      crossPaint,
    );
    canvas.drawLine(
      screenPt + const Offset(0, 4),
      screenPt + const Offset(0, arm),
      crossPaint,
    );

    // Center dot
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(screenPt, 3.0, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _CadPickerPainter oldDelegate) => true;
}
