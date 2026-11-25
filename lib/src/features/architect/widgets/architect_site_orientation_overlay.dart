import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kotoview/src/core/icons/app_icon.dart';

import '../../../core/l10n/l10n_extensions.dart';
import '../rendering/architect_snap_helper.dart';
import '../services/architect_site_orientation.dart';
import 'architect_transform_point_input.dart';

/// Phone-first 2-tap overlay for aligning orthogonal building axes (Project
/// North) to an edge on an upright True-North Site Plan geodetic survey.
///
/// Follows the [ArchitectRotationOverlay] archetype (`ArchitectTransformPointInput`
/// keeps pan/pinch navigation and precision-hold snapping active throughout).
class ArchitectSiteOrientationOverlay extends StatefulWidget {
  final Offset Function(Offset) toModel;
  final Offset Function(Offset) toScreen;
  final ArchitectSnapResult Function(Offset raw, bool touch) snap;
  final String? Function(String?) localizeSnap;
  final void Function(Offset pivot, double deltaRad) onApply;
  final void Function(Offset delta, double factor, Offset focal) onNavigate;
  final VoidCallback onCancel;

  const ArchitectSiteOrientationOverlay({
    super.key,
    required this.toModel,
    required this.toScreen,
    required this.snap,
    required this.localizeSnap,
    required this.onApply,
    required this.onNavigate,
    required this.onCancel,
  });

  @override
  State<ArchitectSiteOrientationOverlay> createState() =>
      _ArchitectSiteOrientationOverlayState();
}

class _ArchitectSiteOrientationOverlayState
    extends State<ArchitectSiteOrientationOverlay> {
  Offset? _start;
  Offset? _end;
  Offset? _aim;
  int _quarterTurns = 0;

  bool get _hasSegment =>
      _start != null && _end != null && (_end! - _start!).distance > 1e-6;

  double get _deltaRad => _hasSegment
      ? ArchitectSiteOrientation.deltaToAlignSegment(
          _start!,
          _end!,
          quarterTurns: _quarterTurns,
        )
      : 0.0;

  void _onAim(ArchitectSnapResult snap) {
    if (_hasSegment) return;
    setState(() => _aim = snap.point);
  }

  void _onPick(ArchitectSnapResult snap) {
    final pt = snap.point;
    if (_start == null) {
      setState(() {
        _start = pt;
        _end = null;
        _aim = pt;
      });
      return;
    }
    if (_end == null) {
      if ((pt - _start!).distance < 1e-6) return;
      setState(() {
        _end = pt;
        _aim = pt;
        _quarterTurns = 0;
      });
    }
  }

  void _reset() {
    setState(() {
      _start = null;
      _end = null;
      _aim = null;
      _quarterTurns = 0;
    });
  }

  void _cycle90() {
    setState(() {
      _quarterTurns = (_quarterTurns + 1) % 4;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final hint = _start == null
        ? l.architectSiteOrientStartHint
        : (!_hasSegment
              ? l.architectSiteOrientEndHint
              : l.architectSiteOrientReviewHint);

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _SiteOrientationPreviewPainter(
                start: _start == null ? null : widget.toScreen(_start!),
                end: _end == null ? null : widget.toScreen(_end!),
                aim: _aim == null ? null : widget.toScreen(_aim!),
                quarterTurns: _quarterTurns,
                primary: colors.primary,
                onSurface: colors.onSurface,
                upLabel: l.architectNorthSymbolLetter,
              ),
            ),
          ),
        ),
        if (!_hasSegment)
          Positioned.fill(
            child: ArchitectTransformPointInput(
              key: const ValueKey('architect-site-orientation-input'),
              toModel: widget.toModel,
              toScreen: widget.toScreen,
              snap: widget.snap,
              localizeSnap: widget.localizeSnap,
              onAim: _onAim,
              onPick: _onPick,
              onNavigate: widget.onNavigate,
            ),
          ),
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: Material(
            key: const ValueKey('architect-site-orientation-banner'),
            color: colors.surface,
            elevation: 3,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      AppIcon(
                        AppIconId.compass,
                        size: 18,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          hint,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('architect-site-orientation-close'),
                        tooltip: l.cancel,
                        visualDensity: VisualDensity.compact,
                        onPressed: widget.onCancel,
                        icon: const AppIcon(AppIconId.close, size: 18),
                      ),
                    ],
                  ),
                  if (_hasSegment) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          key: const ValueKey(
                            'architect-site-orientation-rotate90',
                          ),
                          onPressed: _cycle90,
                          icon: const AppIcon(AppIconId.rotate, size: 16),
                          label: Text(l.architectSiteOrientRotate90),
                        ),
                        OutlinedButton.icon(
                          key: const ValueKey(
                            'architect-site-orientation-reset',
                          ),
                          onPressed: _reset,
                          icon: const AppIcon(AppIconId.refresh, size: 16),
                          label: Text(l.architectSiteOrientRetry),
                        ),
                        FilledButton.icon(
                          key: const ValueKey(
                            'architect-site-orientation-apply',
                          ),
                          onPressed: () {
                            final pivot = (_start! + _end!) / 2;
                            widget.onApply(pivot, _deltaRad);
                          },
                          icon: const AppIcon(AppIconId.confirm, size: 16),
                          label: Text(l.applyAction),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SiteOrientationPreviewPainter extends CustomPainter {
  final Offset? start;
  final Offset? end;
  final Offset? aim;
  final int quarterTurns;
  final Color primary;
  final Color onSurface;
  final String upLabel;

  const _SiteOrientationPreviewPainter({
    required this.start,
    required this.end,
    required this.aim,
    required this.quarterTurns,
    required this.primary,
    required this.onSurface,
    required this.upLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = start;
    final e = end ?? aim;
    if (s == null) return;

    final edgePaint = Paint()
      ..color = primary
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;

    if (e != null && (e - s).distance > 2) {
      canvas.drawLine(s, e, edgePaint);
      if (end != null) {
        _paintBuildingAxesPreview(canvas, s, end!);
      }
    }

    final dotFill = Paint()..color = Colors.white;
    final dotStroke = Paint()
      ..color = primary
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    for (final pt in [s, ?end]) {
      canvas.drawCircle(pt, 5.5, dotFill);
      canvas.drawCircle(pt, 5.5, dotStroke);
    }
  }

  void _paintBuildingAxesPreview(Canvas canvas, Offset s, Offset e) {
    final center = (s + e) / 2;
    final dir = e - s;
    final len = dir.distance;
    if (len < 2) return;

    // Direction of future floor-plan +X (horizontal right on Floor ±0.00)
    // in screen coordinates: rotating edge by `-quarterTurns * pi/2`.
    final edgeAngle = math.atan2(dir.dy, dir.dx);
    final xAngle = edgeAngle - (quarterTurns % 4) * (math.pi / 2);
    final ux = Offset(math.cos(xAngle), math.sin(xAngle));
    // Floor-plan "Up" (-Y on Floor ±0.00) is 90° CCW from +X in screen space.
    final uUp = Offset(ux.dy, -ux.dx);

    final gridHalf = math.max(len * 0.75, 90.0).clamp(70.0, 220.0);
    final step = gridHalf / 3;
    final gridPaint = Paint()
      ..color = primary.withValues(alpha: 0.25)
      ..strokeWidth = 1.0;

    for (var i = -3; i <= 3; i++) {
      final d = i * step;
      canvas.drawLine(
        center + uUp * d - ux * gridHalf,
        center + uUp * d + ux * gridHalf,
        gridPaint,
      );
      canvas.drawLine(
        center + ux * d - uUp * gridHalf,
        center + ux * d + uUp * gridHalf,
        gridPaint,
      );
    }

    // Draw bold "Up on Floor ±0.00" arrow
    final arrowLen = math.max(48.0, gridHalf * 0.55);
    final tip = center + uUp * arrowLen;
    final arrowPaint = Paint()
      ..color = primary
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, tip, arrowPaint);
    final head = 10.0;
    canvas.drawLine(tip, tip - uUp * head + ux * (head * 0.55), arrowPaint);
    canvas.drawLine(tip, tip - uUp * head - ux * (head * 0.55), arrowPaint);

    // Draw "+X" axis indicator
    final xTip = center + ux * (arrowLen * 0.75);
    final xPaint = Paint()
      ..color = primary.withValues(alpha: 0.8)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, xTip, xPaint);

    _drawAxisTag(canvas, tip + uUp * 14, '↑ ±0.00', primary);
    _drawAxisTag(canvas, xTip + ux * 14, 'X', onSurface);
  }

  void _drawAxisTag(Canvas canvas, Offset center, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = Rect.fromCenter(
      center: center,
      width: tp.width + 10,
      height: tp.height + 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_SiteOrientationPreviewPainter old) =>
      old.start != start ||
      old.end != end ||
      old.aim != aim ||
      old.quarterTurns != quarterTurns ||
      old.primary != primary;
}
