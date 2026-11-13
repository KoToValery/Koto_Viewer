import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extensions.dart';
import '../services/architect_ellipse_draft.dart';
import 'architect_canvas_hint.dart';

class ArchitectEllipseDraftOverlay extends StatelessWidget {
  final ArchitectEllipseDraft draft;
  final Offset Function(Offset) toScreen;
  const ArchitectEllipseDraftOverlay({
    super.key,
    required this.draft,
    required this.toScreen,
  });

  @override
  Widget build(BuildContext context) {
    if (draft.ready) return const SizedBox.shrink();
    final l = context.l10n;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _AxesPainter(draft, toScreen)),
          ),
          Positioned(
            top: 60,
            left: 8,
            right: 8,
            child: Align(
              alignment: Alignment.topLeft,
              child: ArchitectCanvasHint(
                key: const ValueKey('ellipse-draft-step'),
                message: draft.center == null
                    ? l.architectEllipsePickCenter
                    : draft.axisEnd == null
                    ? l.architectEllipsePickFirstAxis
                    : l.architectEllipsePickSecondAxis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AxesPainter extends CustomPainter {
  final ArchitectEllipseDraft draft;
  final Offset Function(Offset) toScreen;
  _AxesPainter(this.draft, this.toScreen);
  @override
  void paint(Canvas canvas, Size size) {
    if (draft.center == null) return;
    final c = toScreen(draft.center!);
    final a = toScreen(draft.axisEnd ?? draft.cursor ?? draft.center!);
    final paint = Paint()
      ..color = const Color(0xff777777)
      ..strokeWidth = 1;
    canvas.drawLine(c, a, paint);
    canvas.drawLine(c - const Offset(4, 0), c + const Offset(4, 0), paint);
    canvas.drawLine(c - const Offset(0, 4), c + const Offset(0, 4), paint);
    if (draft.axisEnd != null) {
      final u = draft.direction;
      final r = Offset(-u.dy, u.dx) * draft.radiusY;
      canvas.drawLine(
        toScreen(draft.center! - r),
        toScreen(draft.center! + r),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AxesPainter oldDelegate) => true;
}
